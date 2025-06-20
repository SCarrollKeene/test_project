local MapLoader = require("maploader")

local LevelManager = {
    currentLevel = 1,
    levels = {
        { map = "room1", enemies = 3, boss = false },
        { map = "room2", enemies = 5, boss = false },
        { map = "room3", enemies = 7, boss = true }
    }
}

function LevelManager:loadLevel(index)
    -- each level recieves an index
    self.currentLevel = index
    local level = self.levels[index]

    -- load map, associate global world to map
    currentMap = MapLoader.load(level.map, world)

    -- clear existing enemies
    enemies = {}

    -- spawn enemies
    for i = 1, level.enemies do
        spawnRandomEnemy()
    end

    -- need to make boss to go with boss logic
    if level.boss then
        spawnBossEnemy()
    end
end

return LevelManager