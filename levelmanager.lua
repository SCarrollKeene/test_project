local MapLoader = require("maploader")

local LevelManager = {
    currentLevel = 1,
    levels = {
        { map = "room1", enemies = 3, boss = false,
        spawns = {
            -- defining fixed positions for enemy spawn
            { x = 800, y = 200 },
            { x = 700, y = 300 },
            { x = 600, y = 400 }
        } },
        { map = "room2", enemies = 5, boss = false,
    spawns = {
            { x = 800, y = 200 },
            { x = 700, y = 300 },
            { x = 600, y = 400 },
            { x = 550, y = 450 },
            { x = 450, y = 550 }
        } },
        { map = "room3", enemies = 7, boss = true }
    }
}

function LevelManager:loadLevel(index)
    -- each level recieves an index
    self.currentLevel = index
    local level = self.levels[index]

    -- load map, associate global world to map
    currentMap = MapLoader.load(level.map, world)

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

    -- Spawn enemies using level-specific positions
    for _, spawnPos in ipairs(self.levels[index].spawns) do
        spawnRandomEnemy(spawnPos.x, spawnPos.y) -- Fixed positions
    end
    
    -- Spawn remaining enemies randomly
    local remaining = self.levels[index].enemies - #self.levels[index].spawns
    for i = 1, remaining do
        spawnRandomEnemy() -- Random positions
    end

    -- need to make boss to go with boss logic
    if level.boss then
        spawnBossEnemy()
    end
end

return LevelManager