local sti = require("libraries/sti")
local Walls = require("walls")

local MapLoader = {}

-- function MapLoader.load(mapName, world)
--     -- map load safety check
--     if not world then
--         print("ERROR: world is nil in MapLoader.load")
--         return nil
--     end

--     local map = sti("maps/" .. mapName .. ".lua")

--     -- Create wall colliders from the Tiled info being retrieved from walls.lua
--     local walls = Walls.load(world, map)

--     -- returns map and walls
--     return map, walls
-- end

function MapLoader.parse(mapName)
    local filePath = "maps/" .. mapName .. ".lua"
    local map = sti(filePath)

    local wallData = {}
    if map.layers["Walls"] and map.layers["Walls"].objects then
        for _, obj in ipairs(map.layers["Walls"].objects) do
            table.insert(wallData, {
                x = obj.x,
                y = obj.y,
                width = obj.width,
                height = obj.height
            })
        end
    end
    return map, wallData
end

-- Only this function creates colliders when you need them
function MapLoader.instantiateWalls(world, wallData)
    local colliders = {}
    for _, w in ipairs(wallData) do
        local collider = world:newRectangleCollider(w.x, w.y, w.width, w.height)
        collider:setType("static")
        collider:setCollisionClass('wall')
        collider:setUserData({ type = "wall" })
        table.insert(colliders, collider)
    end
    return colliders
end

return MapLoader