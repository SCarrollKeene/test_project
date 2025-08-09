local HumpCamera = require("libraries/hump/camera")

-- Create the camera instance and store it in a table
-- so you can "require" it in other files.
local Cam = {
    camera = HumpCamera(),
    scale = 1.5,
    mapWidth = 1280, -- Default map width
    mapHeight = 768 -- Default map height
}

-- Set initial zoom/scale
Cam.camera:zoomTo(Cam.scale)

-- Function to set the map boundaries for the camera
function Cam.setMap(mapWidth, mapHeight)
    Cam.mapWidth = mapWidth
    Cam.mapHeight = mapHeight
    -- You can also automatically set bounds here if the camera needs it
end

-- Update the camera position based on the player position
function Cam:follow(targetX, targetY)
    -- Clamp the target position to the map boundaries
    local halfWidth = (love.graphics.getWidth() / 2) / self.scale
    local halfHeight = (love.graphics.getHeight() / 2) / self.scale

    local clampedX = math.max(halfWidth, math.min(targetX, self.mapWidth - halfWidth))
    local clampedY = math.max(halfHeight, math.min(targetY, self.mapHeight - halfHeight))
    
    self.camera:lookAt(clampedX, clampedY)
end

return Cam