local MapLoader = require("maploader")
local projectiles = require("projectile_store")

local function buildCombatWaves(includeBoss)
    local waves = {}
    local baseEnemyCount = 3
    local baseDuration = 20
    local maxDuration = 60

    for i = 1, 5 do
        -- Progressive enemy count and staggered interval
        local enemyCount = baseEnemyCount + (i - 1) * 2  -- e.g., 3, 5, 7, 9, 11
        local spawnInterval = math.max(0.6 - (i - 1) * 0.08, 0.15)  -- Faster spawns later
        local duration = (i == 5) and maxDuration or (baseDuration + math.random(0, 20))

        table.insert(waves, {
            enemyCount = enemyCount,
            delay = 1.2,
            spawnInterval = spawnInterval,
            enemyTypes = nil,  -- All types; set if you want restrictions per wave
            boss = false,
            duration = duration,
        })
    end

    -- Optionally add a boss wave
    if includeBoss then
        table.insert(waves, {
            enemyCount = 1,
            delay = 3.0,
            spawnInterval = 1.2,
            enemyTypes = {"Boss"},  -- Only boss type
            boss = true,
            duration = maxDuration + 30,
        })
    end

    return waves
end

local LevelManager = {
    currentLevel = 1,
    levels = {
        { 
            map = "room0", 
            -- waves stress test
            -- waves = {
            --     { enemyCount = 50, delay = 1.0, spawnInterval = 0.2, enemyTypes = nil, boss = false }
            -- },

            -- enemy spawns per wave, seconds between waves, ms between each spawn, nil means random enemy type, no boss in this level
            --waves = {},
            -- enemies = 3, 
            -- boss = false,
            waves = buildCombatWaves(false), -- No boss here
            --{
                -- { enemyCount = 3, delay = 1.0, spawnInterval = 0.2, enemyTypes = {"Black Blob"}, boss = false },
                -- { enemyCount = 6, delay = 2.0, spawnInterval = 0.2, enemyTypes = nil, boss = false },
                -- { enemyCount = 9, delay = 3.0, spawnInterval = 0.2, enemyTypes = nil, boss = false },
                -- { enemyCount = 10, delay = 3.0, spawnInterval = 0.2, enemyTypes = nil, boss = false },
                -- { enemyCount = 10, delay = 3.0, spawnInterval = 0.2, enemyTypes = nil, boss = false },
            -- },
            spawns = {
                -- defining fixed positions for enemy spawn
                { x = 800, y = 200 },
                { x = 700, y = 300 },
                { x = 600, y = 400 }
            }
        },
        { 
            map = "room1", 
            waves = buildCombatWaves(false),
            -- enemies = 3, 
            -- boss = false,
            spawns = {
                -- defining fixed positions for enemy spawn
                { x = 800, y = 200 },
                { x = 700, y = 300 },
                { x = 600, y = 400 }
            } 
        },
        { 
            map = "room2",
            waves = buildCombatWaves(false), 
            --enemies = 3, 
            --boss = false,
            spawns = {
                { x = 800, y = 200 },
                { x = 750, y = 250 },
                { x = 700, y = 300 },
                { x = 650, y = 350 },
                { x = 600, y = 550 }
            } 
        },
        { 
            map = "room3",
            waves = buildCombatWaves(false), 
            --enemies = 3, 
            --boss = false,
            spawns = {} 
        },
        { 
            map = "room4",
            waves = buildCombatWaves(false), 
            --enemies = 3, 
            --boss = false,
            spawns = {
                { x = 800, y = 200 },
                { x = 750, y = 250 },
                { x = 700, y = 300 }
                -- { x = 600, y = 350 },
                -- { x = 650, y = 400 },
                -- { x = 650, y = 450 },
                -- { x = 650, y = 200 },
                -- { x = 600, y = 250 },
                -- { x = 600, y = 300 },
                -- { x = 600, y = 350 }
            } 
        }
    }
}

function LevelManager:loadLevel(index, enemyImageCache)
    -- each level recieves an index
    self.currentLevel = index
    local level = self.levels[index]

    -- Destroy previous walls first
    for _, collider in ipairs(wallColliders) do
        -- if not collider:isDestroyed() then
            collider:destroy()
        -- end
    end

    -- Reset global wall collider tracker
    wallColliders = {}

    -- clear existing enemies, good practice
    enemies = {}
    
     -- Load new map
    currentMap, currentWalls = MapLoader.load(level.map, world)

    -- load map AND walls, associate global world to map
    -- currentMap, currentWalls = MapLoader.load(level.map, world)

    -- load all new enemy instances into one table
    -- local new_enemies = { enemy1, blueBlob, violetBlob }

    -- iterate through elements of new_enemies table, set the player as the target for all enemies, 
    -- enemy assigned actual value of the enemy object itself at an index
    -- i is assigned mumerical index of the current element starting at 1, cause, Lua
    -- for i, enemy in ipairs(new_enemies) do
    --     enemy:setTarget(player)
    --     table.insert(enemies, enemy)
    --     print("DEBUG:".."Added enemy " .. i .. " (" .. (enemy.name or "enemy") .. ") to table. Target set!")
    -- end

    -- Add new walls to tracker
    for _, wall in ipairs(currentWalls) do
        table.insert(wallColliders, wall)
    end

    self.spawnZones = {} -- Reset enemy spawn zones for the new level
    if currentMap.layers["EnemySpawns"] then
        for _, zone in ipairs(currentMap.layers["EnemySpawns"].objects) do
            -- Create spawn zones for enemies
            table.insert(self.spawnZones, {
                x = zone.x,
                y = zone.y,
                width = zone.width,
                height = zone.height
            })
        end
    end

    -- initialize from spawns table in levels or an empty table if a spawns table is missing
    local spawns = level.spawns or {}

    if level.waves then
        -- Spawn enemies using level-specific positions
        for _, spawnPos in ipairs(spawns) do
            spawnRandomEnemy(spawnPos.x, spawnPos.y, enemyImageCache) -- Fixed positions
        end
    else
        -- Spawn enemies using level-specific positions
        for _, spawnPos in ipairs(spawns) do
            spawnRandomEnemy(spawnPos.x, spawnPos.y, enemyImageCache) -- Fixed positions
        end

        local remaining = level.enemies - #spawns
        for i = 1, remaining do
            spawnRandomEnemy() -- Random positions
        end
        
        if level.boss then
            spawnBossEnemy() -- Spawn boss if defined in level
        end
    end
    
    -- Spawn remaining enemies randomly (enemies in a level - index of spawns (ex: room1 has 3 enemies, 3 spawn points))
    -- local remaining = level.enemies - #spawns
    -- for i = 1, remaining do
    --     spawnRandomEnemy() -- Random positions
    -- end

    -- -- need to make boss to go with boss logic
    -- if level.boss then
    --     spawnBossEnemy()
    -- end

    projectilePool = {}

    -- Reset existing enemies
    for i, enemy in ipairs(enemies) do
        if enemy.spriteSheet and enemy.animations then
            enemy.currentAnimation = enemy.animations.idle
            if enemy.currentAnimation then
                enemy.currentAnimation:reset()
            end
        end
    end

    -- destroy any remaining prjectiles on level load
    for i = #projectiles, 1, -1 do
        projectiles[i]:destroySelf()
        table.remove(projectiles, i)
    end
end

function LevelManager:spawnRandomInZone(enemyImageCache, enemyTypes)
    if #self.spawnZones == 0 then return end

    local zone = self.spawnZones[love.math.random(#self.spawnZones)]
    local x = zone.x + love.math.random(0, zone.w)
    local y = zone.y + love.math.random(0, zone.h)

    spawnRandomEnemy(x, y, enemyImageCache, enemyTypes)
end

return LevelManager