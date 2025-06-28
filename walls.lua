local wf = require("libraries/windfield")

Walls = {}

function Walls.load(world, map)
    -- optimize wall creation at the start, if world or map is missing, exit function early and return an empty table
    if not world or not map then return {} end

    local walls = {}
    if map and map.layers["Walls"] then
        for i, obj in ipairs(map.layers["Walls"].objects) do
            -- pull wall info from object layer for walls from the Tiled map data
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            -- static so walls don't move
            wall:setType('static')
            wall:setCollisionClass('wall')
            wall:setUserData({ type = 'wall' }) -- Add metadata
            -- insert wall data into walls table
            table.insert(walls, wall)
        end
    end
    return walls
end

return Walls

-- TODO: this probably needs to get moved into map.lua, eventually 6/22/25