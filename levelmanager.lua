local MapLoader = require("maploader")

local LevelManager = {
    currentLevel = 1,
    levels = {
        { 
            map = "room1", 
            enemies = 3, 
            boss = false,
            spawns = {
                -- defining fixed positions for enemy spawn
                { x = 800, y = 200 },
                { x = 700, y = 300 },
                { x = 600, y = 400 }
            } 
        },
        { 
            map = "room2", 
            enemies = 5, 
            boss = false,
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
            enemies = 7, 
            boss = false,
            spawns = {} 
        },
        { 
            map = "room4", 
            enemies = 10, 
            boss = false,
            spawns = {
                { x = 800, y = 200 },
                { x = 750, y = 250 },
                { x = 700, y = 300 },
                { x = 600, y = 350 },
                { x = 650, y = 400 },
                { x = 650, y = 450 },
                { x = 650, y = 200 },
                { x = 600, y = 250 },
                { x = 600, y = 300 },
                { x = 600, y = 350 }
            } 
        }
    }
}

function LevelManager:loadLevel(index, enemyImageCache, projectiles)
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

    -- initialize from spawns table in levels or an empty table if a spawns table is missing
    local spawns = level.spawns or {}

    -- Spawn enemies using level-specific positions
    for _, spawnPos in ipairs(spawns) do
        spawnRandomEnemy(spawnPos.x, spawnPos.y, enemyImageCache) -- Fixed positions
    end
    
    -- Spawn remaining enemies randomly (enemies in a level - index of spawns (ex: room1 has 3 enemies, 3 spawn points))
    local remaining = level.enemies - #spawns
    for i = 1, remaining do
        spawnRandomEnemy() -- Random positions
    end

    -- need to make boss to go with boss logic
    if level.boss then
        spawnBossEnemy()
    end

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

return LevelManager