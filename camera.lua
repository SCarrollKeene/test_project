local Camera = require("libraries/hump/camera")

local cam = nil -- Local module camera instance

return {
    init = function(x, y, zoom)
        zoom = zoom or 1.5
        cam = Camera(x, y, zoom)
        cam.smoother = Camera.smooth.damped(3)
        return cam
    end,

    update = function(x, y, mapW, mapH)
        if not cam then return end
        
        local screen_w, screen_h = love.graphics.getDimensions()
        local zoom = cam.scale
        local visible_w = mapW
        local visible_h = mapH
        
        -- Clamp camera to map boundaries
        local camX = math.max(visible_w/2, math.min(x, mapW - visible_w/2))
        local camY = math.max(visible_h/2, math.min(y, mapH - visible_h/2))
        
        cam:lockPosition(camX, camY) -- Actually move camera
    end,

    draw = function(drawFunction)
        if not cam then return end
        cam:attach()
        drawFunction()
        cam:detach()
    end,

    worldToCamera = function(x, y)
        return cam:worldToCamera(x, y)
    end,

    getPosition = function()
        return cam:position()
    end,

    getScale = function()
        return cam.scale
    end
}