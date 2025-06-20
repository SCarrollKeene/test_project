local Particle = require("particle")

local Portal = {}
Portal.__index = Portal -- reference for methods from other portal instances

-- main portal safe rooms
-- portal upside down rooms
-- portal evil rooms
-- rare portal rooms
-- hidden bossfights that appear in regular rooms
-- probably hide hidden bossfights behind flag
-- that players need to clear the game at least once

-- portal constructor
function Portal:new(world, x, y)
    local instance = {
        x = x,
        y = y,
        width = 64,
        height = 64,
        type = "portal",
        world = world,
        isActive = true,
        animationTimer = 0,
        ps = Particle.portalGlow(true) -- true only if emission burst
    }
    
    -- set position after Portal table creation
    instance.ps:setPosition(instance.x, instance.y)
    table.insert(globalParticleSystems, instance.ps)

    print("Portal particles created:", instance.ps ~= nil)
    if instance.ps then
        print("Portal particle count:", instance.ps:getCount())
    end

    setmetatable(instance, Portal)
    instance:load()
    return instance
end

function Portal:load()
    -- Create collider for portal
    self.collider = self.world:newBSGRectangleCollider(
        self.x - self.width/2, 
        self.y - self.height/2, 
        self.width, 
        self.height, 
        10
    )
    self.collider:setUserData(self)
    self.collider:setCollisionClass('portal')
    self.collider:setSensor(true)  -- Portal doesn't block movement
end

function Portal:update(dt)
    self.ps:moveTo(self.x, self.y)
    -- self.ps:update(dt)
    self.animationTimer = self.animationTimer + dt
end

function Portal:draw()
    if not self.isActive then return end
    
    if self.ps then
        -- center particles at portal center
        self.ps:setPosition(self.x, self.y)
        love.graphics.draw(self.ps)
    end
    
    -- Simple animated portal effect
    local pulse = math.sin(self.animationTimer * 4) * 0.3 + 0.7
    love.graphics.setColor(0.3, 0.7, 1.0, pulse)
    love.graphics.circle("fill", self.x, self.y, 30)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.print("Particles: " ..self.ps:getCount(), self.x, self.y - 40)
end

function Portal:destroy()
    if self.collider then
        self.collider:destroy()
        self.collider = nil
    end
    self.isActive = false

    -- flag particle system to stop once portal is destroyed
    if self.ps then 
        self.ps:stop()
        self.ps = nil
    end
    -- debate adding globalps table to remove particles unles I want them to linger for longer
end

return Portal