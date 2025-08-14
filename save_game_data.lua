local data_store = require("data_store")
local Serpent = require("libraries/serpent")
serpent = Serpent

local SaveSystem = {}

function SaveSystem.saveGame()
    -- serialize with serpent, then save data
    local data = {
        run = data_store.runData,
        meta = data_store.metaData
    }
    -- utilize serpent for serialization
    local serialized = serpent.block(data)

    local tempPath = "save_temp.dat"
    local savePath = "save.dat"

    -- error handling
    local success, err = pcall(function()
        -- Write to temporary file first
        love.filesystem.write(tempPath, serialized)

        -- write to a temp file, TODO: change to actual path after testing
        love.filesystem.write("tempPath", serialized)

        -- atomic replacement of save data
        if love.filesystem.getInfo(savePath) then
            love.filesystem.remove(savePath) -- delete previous save data
        end
        -- copy temp data to final/actual save data
        love.filesystem.write(savePath, love.filesystem.read(tempPath))
        love.filesystem.remove(tempPath) -- clean out temp data

        -- backup save data
        if love.filesystem.getInfo(savePath) then
        love.filesystem.write(savePath .. ".bak", love.filesystem.read(savePath))
end
    end)

    if not success then
        print("SAVE ERROR:" ..err)
        return false
    end
    return true
end

function SaveSystem.loadGame()
    if love.filesystem.getInfo("save.dat") then
        local data = love.filesystem.read("save.dat")
        local loaded = serprent.load(data) --deserialize data using serpent
        data_store.runData = loaded.run or {}
        data_store.metaData = loaded.meta or {}
        return loaded
    end
    return nil
end

-- revisit later on how to clean this up to only reset current run data, but not entire game save
function SaveSystem.resetRun()
    -- Reset run-specific data only
    data_store.runData = {
        currentRoom = 1,
        cleared = false,
        clearedRooms = {},
        playerHealth = 100,
        playerMaxHealth = 100,
        inventory = {},
        equippedSlot = 1,
        playerLevel = 1,
        playerExperience = 0,
        playerBaseDamage = 1,
        playerSpeed = 300
    }

    -- Save reset state immediately
    SaveSystem.saveGame()
end

return SaveSystem