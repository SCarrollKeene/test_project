local Tileset = require("tileset")
local wf = require("libraries/windfield")

local Map = {}

function Map:load(world)
    -- self.data = {
    --     { 1, 2, 3, 4 },
    --     { 5, 6, 7, 8 },
    --     { 9, 10, 11, 12 },
    --     { 13, 14, 15, 16 }
    -- }

    -- self.data = {}
    -- for row = 1, 11 do
    --     self.data[row] = {}
    --     for col = 1, 20 do
    --         -- Example: alternate between tile 1 and 2, or use math.random(1,16) for variety
    --         self.data[row][col] = ((row + col) % 16) + 1
    --     end
    -- end

    self.data = {} -- sets up empty table where the map layout will be stored
    local rows = 11 -- defines number of rows based on the width of 720
    local cols = 20 -- defines number of columns based on the height of 1280

    -- Use the tile dimensions from the loaded tileset.lua
    -- These should be available after Tileset:load() has been called in main.lua
    local tile_width = Tileset.tileWidth
    local tile_height = Tileset.tileHeight

    -- safety check, but I need to make sure this is in tileset.lua instead 5/30/25
    if not tile_width or not tile_height then
        print("ERROR: in Map:load - Tileset.tileWidth or Tileset.tileHeight not set. Using default values.")
        tile_width = tile_width or 64 -- Default fallback
        tile_height = tile_height or 64 -- Default fallback
    end

    print(string.format("Map:load - Using tile_width: %.1f, tile_height: %.1f", tile_width, tile_height))

    for row = 1, rows do -- loops through all rows
        self.data[row] = {}
        for col = 1, cols do -- loops through all columns
            -- store the tile value of 5 or twelve, wall or floor
            local tile_value
            if row == 1 or row == rows or col == 1 or col == cols then -- checks if current tile is on the border (first or last row, first or last column!)
                self.data[row][col] = 5  -- Wall tile
                tile_value = 5
            else
                self.data[row][col] = 12  -- Floor tile
                tile_value = 12
            end

             -- If the tile is a wall, create a physical collider for it
            if tile_value == 5 then -- Assuming 5 represents a wall tile
                -- Calculate the top-left position of the tile
                local top_left_x = (col - 1) * tile_width
                local top_left_y = (row - 1) * tile_height
                
                -- Windfield's newRectangleCollider usually expects center coordinates
                local center_x = top_left_x + tile_width / 2
                local center_y = top_left_y + tile_height / 2
                
                if not world then
                    print("ERROR in Map:load - world is nil! Cannot create wall colliders.")
                    -- If world is nil, we cannot proceed with creating colliders for this tile.
                    -- We'll skip to the next iteration of the inner loop.
                    goto continue_inner_loop 
                end

                 print(string.format("Map:load - Creating wall collider at center x:%.1f, y:%.1f (tile col:%d, row:%d)", center_x, center_y, col, row))
                local wall_collider = world:newRectangleCollider(center_x, center_y, tile_width, tile_height)
                wall_collider:setType('static') -- Walls are immovable
                wall_collider:setCollisionClass('wall') -- Assign to the 'wall' collision class
                wall_collider:setUserData({ type = "wall" }) -- IMPORTANT: Identify this collider as a 'wall' type
                                                            -- This 'type' field will be used in main.lua's beginContact
                
                ::continue_inner_loop:: -- Label for the goto statement
            end
        end
    end
    print("Map:load finished processing map data and creating the wall colliders.")

end

return Map