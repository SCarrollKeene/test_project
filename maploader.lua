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
    -- Manually create Windfield colliders for collision layers
--     for _, layer in ipairs(map.layers) do
--         if layer.type == "objectgroup" and layer.name == "collision" then
--             for _, obj in ipairs(layer.objects) do
--                 if obj.shape == "rectangle" then
--                     local collider = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
--                     collider:setType('static')
--                     collider:setCollisionClass('wall')
--                 end
--             end
--         end
--     end
--     return map


    -- Create wall colliders from the Tiled info being retrieved from walls.lua
    local walls = Walls.load(world, map)

    -- returns map and walls
    return map, walls
end

return MapLoader