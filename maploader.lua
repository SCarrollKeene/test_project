local sti = require ("libraries/sti")

local MapLoader = {}

function MapLoader.load(mapName, world)
    local map = sti("maps/" .. mapName .. ".lua")
    -- Manually create Windfield colliders for collision layers
    for _, layer in ipairs(map.layers) do
        if layer.type == "objectgroup" and layer.name == "collision" then
            for _, obj in ipairs(layer.objects) do
                if obj.shape == "rectangle" then
                    local collider = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
                    collider:setType('static')
                    collider:setCollisionClass('wall')
                end
            end
        end
    end
    return map
end

return MapLoader