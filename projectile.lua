local Utils = require("utils")
local wf = require("libraries/windfield")
local Particle = require("particle")

local Projectile = {}
Projectile.__index = Projectile -- points back at the table itself, is used when you set the metatable of an obj

sounds = {}
sounds.blip = love.audio.newSource("sounds/blip.wav", "static")

Projectile.image = nil

-- time to attempt adding pooling, because optimization that's why
local pool = {}

local MAX_POOL_SIZE = 50 -- limit projectile pool size, doesn't seem to be doing its job at the moment, jk it might be 6/22/25

local cleanupTimer = 0

local newCreateCount = 0

function Projectile.getNewCreateCount()
    return newCreateCount
end

function Projectile.getCleanUpTimer()
    return cleanupTimer or 0 -- return 0 if NIL
end

function Projectile.cleanPool(timerValue)
    print("[CLEANUP] Function entered")
    local inactiveCount = 0
    local toRemove = {} -- pooled projectiles marked for removal

    for i = #pool, 1, -1 do
        if not pool[i].active then
            inactiveCount = inactiveCount + 1
            if inactiveCount > MAX_POOL_SIZE then
                print("[CLEANUP] MAX POOL SIZE IS LESS THAN INACTIVE COUNT")
                table.remove(toRemove, i)
                print("[CLEANUP] CLEANUP REMOVED PROJ FROM POOL")
            end
        end
    end

    -- second pass through removed marked projectiles,
    -- removes excess inactive projs, prevents bloat under stress,
    -- tries to maintain effeciency
    for _, i in ipairs(toRemove) do
        table.remove(pool, i)
        print(string.format("[CLEANUP] Cleanup called at: %.2f seconds", timerValue))
    end
end

function Projectile.updatePool(dt)
    cleanupTimer = cleanupTimer + dt
    if cleanupTimer >= 10 then
        local currentTimer = cleanupTimer  -- Every 10 seconds
        Projectile.cleanPool(currentTimer)
        cleanupTimer = 0
    end
end

-- constructor function, if you wanted to create multiple projectiles with different methods/data
function Projectile:new(world, x, y, angle, speed, radius, damage, owner)
    local self = {
        newCreateCount = newCreateCount + 1,
        x = x,
        y = y,
        angle = angle,
        speed = speed or 300,
        radius = radius or 10,
        image = Projectile.image,
        width = 20,
        height = 20,
        damage = damage or 10, -- store damage
        world = world,
        owner = owner, --store the owner of the shot projectile, in this case, the player
        ignoreTarget = owner,
        
        type = "projectile",

        toBeRemoved = false, -- flag to eventually remove projectiles/enemy
        toBeDestroyed = false, -- flag for projectile to handle its own destruction on contact with things like walls

        particleTrail = Particle.getBaseSpark()
    }
    
    setmetatable(self, {__index = Projectile}) -- Projectile methods and fields/data will get looked up

    -- Debug before creating collider
    print("DEBUG Projectile:new - Creating collider with:")
    print("  x:", self.x, "y:", self.y)
    print("  width:", self.width, "type:", type(self.width))
    print("  height:", self.height, "type:", type(self.height))

    if type(self.width) ~= "number" or type(self.height) ~= "number" then
        error("Projectile dimensions are not numbers! Width: " .. tostring(self.width) .. ", Height: " .. tostring(self.height))
    end
    if self.width <= 0 or self.height <= 0 then
         error("Projectile dimensions must be positive! Width: " .. tostring(self.width) .. ", Height: " .. tostring(self.height))
    end

    self.collider = world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 10) -- collider creation for projectile instances
    self.collider:setFixedRotation(true) -- don't rotate
    self.collider:setSensor(true) -- act as sensor to detect hits
    self.collider:setUserData(self) -- associate projectile to its collider
    self.collider:setCollisionClass('projectile')
    self.collider:setObject(self)
    -- self.collider:setMask('enemy') -- Projectiles only care about hitting enemies

    if self.particleTrail then
        -- trail behind the Projectile
        local offset = 10
        local trailX = self.x - math.cos(self.angle) * offset
        local trailY = self.y - math.sin(self.angle) * offset

        self.particleTrail:setPosition(trailX, trailY)
        self.particleTrail:emit(1) -- initial burst
        table.insert(globalParticleSystems, self.particleTrail) -- insert particles into global table
    end

    return self
end

function Projectile.loadAssets()
    local success, img = pcall(love.graphics.newImage, "sprites/orb_red.png")
    if success then
        Projectile.image = img
        print("PROJECTILE image loaded successfully from:", img)
    else
        print("Projectile image error:", img)
        Projectile.image = love.graphics.newImage(1, 1) -- 1x1 white pixel
    end
end

function Projectile:destroySelf()
    if self.isDestroyed then return end -- Prevent multiple destructions

    print(string.format("Projectile:destroySelf - Destroying projectile (Owner: %s)", (self.owner and self.owner.name) or "Unknown"))
    if self.collider then
        self.collider:destroy()
        self.collider = nil
    end

    self.toBeRemoved = true
    self.isDestroyed = true -- Add a flag to prevent re-entry

    -- stop emitting
    -- TODO #1: debate remove from global particle system table
    -- TODO #2: do not remove from globalps from here if I want particles to fade out
    if self.particleTrail then
        -- stop emitting
        -- self.particleTrail:setEmissionRate(0)
        self.particleTrail:stop()-- Stop emitting and reset if needed

        -- If using pooling, return it:
        Timer.after(1.0, function() -- wait for particle to fade
            Particle.returnBaseSpark(self.particleTrail)
        -- If not pooling, just set to nil
        -- self.particleTrail = nil
        end)
    end
end

function Projectile:onHitEnemy(enemy_collided_with)
    if self.isDestroyed then return end

    print(string.format("Projectile:onHitEnemy - Projectile (Owner: %s) hit Enemy: %s", 
        (self.owner and self.owner.name) or "Unknown", 
        (enemy_collided_with and enemy_collided_with.name) or "Unknown Enemy"))

    -- applying damage
    if self.owner and self.owner.dealDamage then
        Utils.dealDamage(self.owner, enemy_collided_with, self.damage)
    elseif enemy_collided_with and enemy_collided_with.takeDamage then
        enemy_collided_with:takeDamage(self.damage)
    end
    
    self:destroySelf() -- Call the generic cleanup, :destroySelf()
end

-- alter this later if enemies will also launch projectiles
-- this could possibly be a utils function later
function Projectile:onHitEnemy(enemy_target)
    if self.owner and self.owner.dealDamage then
        Utils.dealDamage(self.owner, enemy_target, self.damage)
    elseif enemy_target and enemy_target.takeDamage then
        print("Projectile hit enemy, directly calling enemy:takeDamage.")
        enemy_target:takeDamage(self.damage) -- Fallback if owner not set 
    end
end

function Projectile:load()
    -- if we needed to load sounds and images
    -- preload projecticles at start of game
    for i = 1, 100 do
        local proj = Projectile:new(world, 0, 0, 0, 0, 0, nil)
        proj.active = false
        proj.collider:setActive(false) -- disable physics
        table.insert(projectilePool, proj)
    end
end

function Projectile:update(dt)
    print("Projectile:updated(dt) triggered")
    print(string.format("Projectile: angle=%.2f, speed=%.2f", self.angle, self.speed))
    -- Add this check:
    if not self.collider then
        self.toBeRemoved = true -- handle collider being destroyed
        print("Projectile:update - Collider is nil for this projectile. Skipping further update.")
        return -- Exit the function if the collider is nil
    end

    print(string.format("Projectile: angle=%.2f, speed=%.2f", self.angle, self.speed))

    -- self.ax = self.x + math.cos(self.angle) * self.speed * dt
    -- self.by = self.y + math.sin(self.angle) * self.speed * dt
    -- self.x = self.ax
    -- self.y = self.by
    self.x, self.y = self.collider:getPosition()

    -- Check if projectile is off-screen
     if self.x + self.radius < 0 or self.x - self.radius > love.graphics.getWidth() or
       self.y + self.radius < 0 or self.y - self.radius > love.graphics.getHeight() then
        self:destroySelf()
        return -- exit immediately after destroy
    end

     -- projectile initial velocity
    self.xVel = math.cos(self.angle) * self.speed
    self.yVel = math.sin(self.angle) * self.speed

    self.collider:setLinearVelocity(self.xVel, self.yVel)

    -- self.velx = math.cos(self.angle) * self.speed -- calculate horizontal velocity
    -- self.vely = math.sin(self.angle) * self.speed -- calculate vertical velocity
    -- self.x = self.x + self.velx * dt
    -- self.y = self.y + self.vely * dt
    -- print("x"..self.x, "y"..self.y)

    if self.particleTrail then
        self.particleTrail:setPosition(self.x, self.y)
        self.particleTrail:emit(1) -- emit 1 per frame
        -- self.particleTrail:update(dt)
    end
    
end

function Projectile:draw()
    -- love.graphics.setColor(1, 0, 0)
    -- love.graphics.circle("fill", self.x, self.y, self.radius)
    -- love.graphics.setColor(1, 1, 1)
    if self.toBeRemoved then return end

    if self.image then
        local imgWidth = self.image:getWidth()
        local imgHeight = self.image:getHeight()
        love.graphics.draw(self.image, self.x - imgWidth / 2, self.y - imgHeight / 2)
    else
        -- Fallback: Draw debug shape
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", self.x, self.y, 10)
        love.graphics.setColor(1, 1, 1)
    end 
end

function Projectile.getProjectile(world, x, y, angle, speed, damage, owner)
    for _, p in ipairs(pool) do
        if not p.active then
            p:reactivate(world, x, y, angle, speed, damage, owner)
            return p
        end
    end

     -- Fallback: Expand pool if needed
    local newProj = Projectile:new(world, x, y, angle, speed, 10, damage, owner)
    newProj.active = true
    newProj:reactivate(world, x, y, angle, speed, damage, owner)
    table.insert(pool, newProj)
    return newProj
end

-- debug methods for optimization
function Projectile.getPoolSize()
    return #pool
end

function Projectile:reactivate(world, x, y, angle, speed, damage, owner)
    -- to turn this baby back on, its essentially just the collider table with its collider props set again
    self.world = world
    self.x = x
    self.y = y
    self.image = Projectile.image
    self.angle = angle
    self.speed = speed
    self.damage = damage
    self.owner = owner
    self.toBeRemoved = false
    self.active = true

    if not self.collider then
        self.collider = world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 10)
        self.collider:setFixedRotation(true)
        self.collider:setSensor(true)
        self.collider:setUserData(self)
        self.collider:setCollisionClass('projectile')
    else
        self.collider:setPosition(x, y)
        self.collider:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end
end

function Projectile:deactivate()
    self.active = false
    self.toBeRemoved = true
    if self.collider then
        self.collider:setActive(false)
    end
    if self.particleTrail then
        self.particleTrail:stop()
    end
end

return Projectile