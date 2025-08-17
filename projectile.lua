local Utils = require("utils")
local wf = require("libraries/windfield")
local Timer = require("libraries/hump/timer")
local Particle = require("particle")

local Projectile = {}
Projectile.__index = Projectile -- points back at the table itself, is used when you set the metatable of an obj

Projectile.image = nil

if sounds and sounds.blip then
    sounds.blip:play()
end

-- time to attempt adding pooling, because optimization that's why
local pool = {}
Projectile.pool = pool -- expose the pool table for external access

local MAX_POOL_SIZE = 60 -- limit projectile pool size, doesn't seem to be doing its job at the moment, jk it might be 6/22/25

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
    local toRemove = {} -- excess pooled inactive projectiles marked for removal

    for i = #pool, 1, -1 do
        if not pool[i].active then
            inactiveCount = inactiveCount + 1
            if inactiveCount > MAX_POOL_SIZE then
                print("[CLEANUP] MAX POOL SIZE IS LESS THAN INACTIVE COUNT")
                -- Return particle to global pool
                if pool[i].particleTrail then
                    Particle.returnBaseSpark(pool[i].particleTrail)
                    -- pool[i].particleTrail = nil
                end
                table.insert(toRemove, i)
                print("[CLEANUP] CLEANUP REMOVED PROJ FROM POOL")
            end
        end
    end

    -- second pass through removed marked projectiles,
    -- removes excess inactive projs, prevents bloat under stress,
    -- tries to maintain effeciency
    -- for _, i in ipairs(toRemove) do
    --     table.remove(pool, i)
    --     print(string.format("[CLEANUP] Cleanup called at: %.2f seconds", timerValue))
    -- end

     -- Remove in reverse order to preserve indices
    for i = #toRemove, 1, -1 do
        local index = toRemove[i]
        table.remove(pool, index)
    end

    print(string.format("[CLEANUP] Removed %d inactive projectiles at %.2f seconds", #toRemove, timerValue))

    -- Additionally, clean particles for remaining inactive ones
    for i = #pool, 1, -1 do
        if not pool[i].active and pool[i].particleTrail then
            pool[i].particleTrail:reset()
            pool[i].particleTrail:stop()
        end
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

function Projectile:initializeTrailPosition(offset)
    offset = offset or 12
    if self.angle and self.x and self.y and self.particleTrail then
        local trailX = self.x - math.cos(self.angle) * offset
        local trailY = self.y - math.sin(self.angle) * offset
        self.particleTrail:setPosition(trailX, trailY)
        self.particleTrail:emit(1) -- initial burst
    end
end

-- constructor function, if you wanted to create multiple projectiles with different methods/data
function Projectile:new(world, x, y, angle, speed, radius, damage, owner, level, knockback, maxRange)
    local self = {
        level = level or 1,
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
        knockback = knockback or 0,
        maxRange = maxRange or 600,
        distanceTravled = 0,
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

    if self.particleTrail then
        -- trail behind the Projectile
        self:initializeTrailPosition()

        -- table.insert(globalParticleSystems, self.particleTrail) -- insert particles into global table
        table.insert(globalParticleSystems, { ps = self.particleTrail, type = "particleTrail", radius = 16 } ) -- context-based pooling
    end

    return self
end

function Projectile.loadAssets()
    local success, img = pcall(love.graphics.newImage, "sprites/fireball.png")
    if success then
        Projectile.image = img
        --print("[PROJECTILE] image loaded successfully from:", img)
    else
        print("[PROJECTILE] image error:", img)
        Projectile.image = love.graphics.newImage(1, 1) -- 1x1 white pixel
    end
end

function Projectile:destroySelf()
     print("[DESTROY SELF] collision at:", self.x, self.y)
    if self.isDestroyed then return end -- Prevent multiple destructions

    print(string.format("[DESTROY] - Destroying projectile (Owner: %s)",
     (self.owner and self.owner.name) or "Unknown"))

    if type(self.deactivate) == "function" then
        self:deactivate() -- Deactivate the projectile particles
    end
    -- self:deactivate() -- Deactivate the projectile particles

    -- Remove the collider if it exists
    if self.collider and not self.collider:isDestroyed() then
        self.collider:destroy()
        self.collider = nil -- possibly not needed anymore since walls has metadata of type 'wall'
    end

    self.isDestroyed = true -- Add a flag to prevent re-entry

    -- Return particles to pool safely
    if self.particleTrail then
        Particle.returnBaseSpark(self.particleTrail)
        --self.particleTrail = nil
        self.particleTrail:stop() -- Stop the particle system
    end
end

function Projectile:onHitEnemy(enemy)
    if self.isDestroyed then return end
    
    print(string.format("[ON HIT] - Projectile (Owner: %s) hit Enemy: %s", 
        (self.owner and self.owner.name) or "Unknown", 
         (enemy and enemy.name) or "Unknown Enemy"))

    -- applying damage based on owner
    if self.owner and self.owner.dealDamage then
        Utils.dealDamage(self.owner, enemy, self.damage, self.owner) -- self.owner, 1. owner 2. who gets credit for the kill
    -- Direct damage fallback if owner not set
    elseif enemy and enemy.takeDamage then
        enemy:takeDamage(self.damage, self.owner)
    end

    -- check for and apply knockback
    if self.owner and self.owner.weapon and self.knockback and self.knockback > 0 and self.owner.weapon.level >= 5 then
        local angle = math.atan2(enemy.y - self.y, enemy.x - self.x)
        Utils.applyKnockback(enemy, self.owner.weapon.knockback, angle)
    end

    -- impact particles on projectile collision
    local particleImpact = Particle.getOnImpactEffect()
    if particleImpact then
        -- impact particles
        particleImpact:setPosition(self.x, self.y)
        particleImpact:emit(10) -- however many particles you want in the impact burst
        -- table.insert(globalParticleSystems, particleImpact)
        table.insert(globalParticleSystems, { ps = particleImpact, type = "impactEffect", radius = 32 } ) -- context-based pooling
    end
    
    -- Unified destruction sequence
    -- self:deactivate() -- Deactivate the projectile
    self:destroySelf() -- Call the generic cleanup, :destroySelf()
end

-- function Projectile:load()

-- end

-- function Projectile.preload(count)
--     for i = 1, count do
--         local proj = Projectile:new(0, 0, 0, 0, 0, nil)
--         proj.active = false
--         proj.collider:setActive(false)
--         table.insert(pool, proj)
--     end
-- end

function Projectile:update(dt)
    if self.isDestroyed then return end  -- Critical safety check if marked for removal
    -- print(string.format("Projectile: angle=%.2f, speed=%.2f", self.angle, self.speed))
    if not self.collider then
        self.toBeRemoved = true -- handle collider being destroyed
        print("Projectile:update - Collider is nil for this projectile. Skipping further update.")
        return -- Exit the function if the collider is nil
    end

    -- self.ax = self.x + math.cos(self.angle) * self.speed * dt
    -- self.by = self.y + math.sin(self.angle) * self.speed * dt
    -- self.x = self.ax
    -- self.y = self.by
    self.x, self.y = self.collider:getPosition()

    -- Track distance traveled
    local dx = self.x - (self.prevX or self.x)
    local dy = self.y - (self.prevY or self.y)
    local dist = math.sqrt(dx * dx + dy * dy)
    self.distanceTraveled = (self.distanceTraveled or 0) + dist
    self.prevX = self.x
    self.prevY = self.y

    if self.distanceTraveled >= (self.maxRange or 600) then
        print("[PROJECTILE RANGE EXCEEDED] Destroying projectile.")
        -- TODO: destroy or remove particle effect so it isn't happening after the projectile is gone 8/6/25
        self:destroySelf()
        return
    end

    -- Check if projectile is off-screen
    -- TODO: I don't think this actually works after I redid a lot of the projectile methods, retest 8/6/25
    -- UPDATE: It works if the projectile is beyond the map walls, works when walls don't exist or are broken 8/12/25
     if self.x + self.radius < 0 or self.x - self.radius > love.graphics.getWidth() or
       self.y + self.radius < 0 or self.y - self.radius > love.graphics.getHeight() then
        print(string.format("[OFF SCREEN] Projectile (owner: %s) off-screen, destroying", (self.owner and self.owner.name) or "Unknown"))
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

function Projectile.getProjectile(world, x, y, angle, speed, damage, owner, knockback, maxRange)
    for _, p in ipairs(pool) do
        if not p.active then -- skip destroyed projectiles
            print("[REUSE] Reusing inactive projectile, was destroyed:", p.isDestroyed)
            p:reactivate(world, x, y, angle, speed, damage, owner, knockback, maxRange)
            return p
        end
    end
     print("[EXPAND POOL] Creating new projectile")

     -- Fallback: Expand pool if needed
    local newProj = Projectile:new(world, x, y, angle, speed, 10, damage, owner, knockback, maxRange)
    newProj.active = true
    newProj:reactivate(world, x, y, angle, speed, damage, owner, knockback, maxRange)
    table.insert(pool, newProj)
    return newProj
end

-- debug methods for optimization
function Projectile.getPoolSize()
    return #pool
end

-- get state for resued projectiles after deactivation
function Projectile.getStats()
  local active, inactive = 0, 0
  for _, p in ipairs(pool) do
    if p.active then active = active + 1 else inactive = inactive + 1 end
  end
  return active, inactive
end

function Projectile:reactivate(world, x, y, angle, speed, damage, owner, knockback, maxRange)
    -- to turn this baby back on, its essentially just the collider table with its collider props set again
    print("[REACTIVATE] Reactivating projectiles and particles state:", self)
    self.world = world
    self.x = x
    self.y = y
    self.image = Projectile.image
    self.angle = angle
    self.speed = speed
    self.damage = damage
    self.knockback = knockback or 0
    self.maxRange = maxRange or self.maxRange or 600
    self.distanceTraveled = 0
    self.prevX = x
    self.prevY = y
    self.owner = owner
    self.type = "projectile"
    self.isDestroyed = false -- reset destroyed state
    self.toBeRemoved = false -- reset removal flag
    self.active = true -- set active flag to true

     -- Remove invalid collider reference
    if self.collider and self.collider:isDestroyed() then
        self.collider = nil
    end

    -- recreate collider if it doesn't exist or is destroyed
    if not self.collider then
        self.collider = world:newBSGRectangleCollider(x, y, self.width, self.height, 10)
        self.collider:setFixedRotation(true)
        self.collider:setSensor(true)
        self.collider:setUserData(self)
        self.collider:setCollisionClass('projectile')
    else
        -- If the collider already exists, just update its position and velocity
        self.collider:setPosition(x, y)
        self.collider:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end

    -- reactivate existing baseSpark particle system
    -- Reset particles system
    if self.particleTrail then
        -- Return existing particle if it's still active
            --Particle.returnBaseSpark(self.particleTrail)
        self.particleTrail:reset()
        self.particleTrail:start()
    else
        -- Get new particles if missing
        self.particleTrail = Particle.getBaseSpark()
        -- table.insert(globalParticleSystems, { ps = self.particleTrail, type = "particleTrail", radius = 16 })
    end  

    -- Initialize particle position
    self:initializeTrailPosition()

    -- table.insert(globalParticleSystems, self.particleTrail)
    table.insert(globalParticleSystems, { ps = self.particleTrail, type = "particleTrail", radius = 16 } ) -- context-based pooling
end

function Projectile:deactivate()
    print("[DEACTIVATE] Deactivated projectile", self)

    self.active = false
    self.toBeRemoved = true

    if self.particleTrail then
        self.particleTrail:stop()
        self.particleTrail:reset() -- reset the baseSpark particle system
    end
end

return Projectile