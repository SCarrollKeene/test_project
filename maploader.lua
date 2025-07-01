local sti = require("libraries/sti")
local Walls = require("walls")

local MapLoader = {}

function MapLoader.load(mapName, world)
    -- map load safety check
    if not world then
        print("ERROR: world is nil in MapLoader.load")
        return nil
    end

    local map = sti("maps/" .. mapName .. ".lua")

    -- Create wall colliders from the Tiled info being retrieved from walls.lua
    local walls = Walls.load(world, map)

    -- returns map and walls
    return map, walls
end

return MapLoader