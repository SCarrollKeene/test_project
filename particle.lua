Particle = {}

-- image cache to avoid redundant/repeated image loading
local _imgCache = {}

-- pool list for various ps systems, better performance
local pools = { baseSpark = {}, fireflies = {}, onImpactEffect = {}, onDeath = {}, itemIndicator = {}, portalGlow = {} }

local MAX_POOL_SIZE = {
    baseSpark = 100,
    fireflies = 150,
    onImpactEffect = 100,
    onDeath = 100,
    itemIndicator = 60,
    portalGlow = 150
} -- limit particle pool for each table
-- 7/19/25 later on, add prints (or optional UI overlay) 
-- showing real-time peak pool usage for each effect type,
-- so you can balance MAX_POOL_SIZE based on actual gameplay demand,
-- not just estimates.

-- Safe loading: if images are missing and try to crash the game, pcall returns an error
local function getImage(path)
    if not _imgCache[path] then
        print("LOADING PARTICLE IMAGE: ", path)
        local success, img = pcall(love.graphics.newImage, path)
        if not success then
            print("PARTICLE IMAGE ERROR: ", img)
            return nil
        end
        _imgCache[path] = img
    end
    return _imgCache[path]
end

function Particle.baseSpark()
    local particleImage = getImage("sprites/particle.png")
    if not particleImage then 
        print("ERROR: particle.png NOT FOUND!")
        return nil 
    end -- nomore updates from here if not img

    -- ps == particleSystem
    local ps = love.graphics.newParticleSystem(particleImage, 50)

    ps:setParticleLifetime(0.2, 0.5)
    ps:setEmissionRate(0) -- start at 0 for projectiles

    ps:setSizes(0.5, 2.5)

    -- particle emission angle = 360 degrees
    ps:setSpread(math.pi * 2) -- 360° burst

    -- speed range for particles as they are emitted, high value = particles move away from emitter faster
    ps:setSpeed(10, 50)

    -- particle size randomness
    ps:setSizeVariation(1)
    -- random acceleration, x = -20 - 20 pixels a second squared
    ps:setLinearAcceleration(-30, 30)

    -- color transition from white to transparent
    ps:setColors(1, 0.1, 0, 1, 1, 0.4, 0, 0) -- Start: red with a hint of orange, End: orange transparent
    return ps
end

function Particle.getBaseSpark()
    if #pools.baseSpark > 0 then
        local ps = table.remove(pools.baseSpark)
        ps:reset() -- clear particles
        ps:start() -- enable emits
        return ps
    elseif #pools.baseSpark < MAX_POOL_SIZE.baseSpark then
        return Particle.baseSpark() -- use baseSpark to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

function Particle.returnBaseSpark(ps)
    if #pools.baseSpark < MAX_POOL_SIZE.baseSpark then
        ps:stop()
        ps:reset()
        table.insert(pools.baseSpark, ps)
    end
end

-- set isBurst == true when called in portal.lua
function Particle.portalGlow(isBurst)
    local particleImage = getImage("sprites/particle.png")
    if not particleImage then 
        print("ERROR: particle.png NOT FOUND!")
        return nil 
    end -- nomore updates from here if not img

    -- ps == particleSystem
    -- particle texture, particle buffer size
    local ps = love.graphics.newParticleSystem(particleImage, 200)
    print("[Particles] Portal system created")
    print("[Particles] Image:", particleImage and "Loaded" or "MISSING")

    -- sets particle lifespan range (in seconds)
    ps:setParticleLifetime(0.6, 1.2)

    -- particles emitted per second, the higher it is the more dense it gets
    -- ps:setEmissionRate(isBurst and 0 or 80) -- disable continuous if isBurst
    ps:setEmissionRate(80) -- continuous
    ps:setEmissionArea("ellipse", 40, 40) -- trying to add a swirl or motion to the portal

    -- particle size transition from 50%-120% size
    -- ps:setSizes(0.5, 1.2)
    ps:setSizes(3, 12)

    -- particle emission angle = 360 degrees
    ps:setSpread(math.pi * 2) -- 360° burst

    -- speed range for particles as they are emitted, high value = particles move away from emitter faster
    ps:setSpeed(20, 60)

    -- spin effect for portal, fast and different directional spin, I hope it works
    ps:setSpin(-2.0, 2.0)

    -- particle acceleration force
    ps:setLinearAcceleration(-50, -50, 50, 50)
    -- ps:setLinearAcceleration(-50, 50)

    -- particle color = blue (RGBA)
    -- ps:setColors(0.3, 0.7, 1, 1, 0.3, 0.7, 1, 0)
    -- ps:setColors(1, 0.3, 0, 1,  1, 0.8, 0, 0.8)  -- Bright orange
    ps:setColors(0.2, 0.8, 0.7, 1, 0.1, 0.6, 0.5, 0) -- teal green : Slightly darker teal, but transparent

    -- burst area for portal
    if isBurst then
        ps:emit(50) -- initial burst
    end
    return ps
end

function Particle.getPortalGlow()
    if #pools.portalGlow > 0 then
        local ps = table.remove(pools.portalGlow)
        ps:reset()
        ps:start()
        return ps
    else
        return Particle.portalGlow()
    end
end

function Particle.returnPortalGlow(ps)
    if #pools.portalGlow < (MAX_POOL_SIZE.portalGlow) then
        ps:stop()
        ps:reset()
        table.insert(pools.portalGlow, ps)
    end
end

function Particle.firefly()
    local particleImage = getImage("sprites/circle-particle.png")
    if not particleImage then 
        print("ERROR: circle-particle.png NOT FOUND!")
        return nil 
    end -- nomore updates from here if not img

    local ps = love.graphics.newParticleSystem(particleImage, 200)
    ps:setParticleLifetime(4, 8) -- Wisps live longer
    ps:setEmissionRate(20)            -- low: Gentle, sparse emission, high: swarms
    ps:setEmissionArea("uniform", 100, 60) -- 100x60 grid, emit randomly in this grid
    ps:setEmitterLifetime(-1) -- infinite continuous emission
    ps:setSizes(0.1, 0.2)            -- Start small, grow a bit
    ps:setSizeVariation(1)           -- variation if you want different firefly sizes
    ps:setSpread(math.pi * 2)        -- 360° emission
    ps:setSpeed(8, 18)              -- Slow, gentle drifting movement
    ps:setLinearAcceleration(-6, -6, 6, 6) -- Gentle random drift
    ps:setSpin(-0.2, 0.2)            -- Subtle rotation

    -- Color: yellow-green glow, fading to transparent
    ps:setColors(
        0.8, 1.0, 0.5, 1.0,   -- Start: bright yellow-green, opaque
        0.7, 1.0, 0.3, 0.4,   -- Middle: greener, semi-transparent
        0.2, 0.8, 1.0, 0.0    -- End: blueish, fully transparent
    )
    return ps
end

function Particle.getFirefly()
    if #pools.fireflies > 0 then
        local ps = table.remove(pools.fireflies)
        ps:reset()
        ps:start()
        return ps
    elseif #pools.fireflies < MAX_POOL_SIZE.fireflies then
        return Particle.firefly() -- use fireflies to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

-- refactor into globalParticleSystems later
function Particle.spawnFirefly(x, y)
    local ps = Particle.getFirefly()
    if ps then
        ps:setPosition(x, y)
        ps:start()
        table.insert(globalParticleSystems, { ps = ps, type = "firefly", radius = 60 })
    end
end

function Particle.returnFirefly(ps)
    if #pools.fireflies < MAX_POOL_SIZE.fireflies then
        ps:stop()
        ps:reset()
        table.insert(pools.fireflies, ps)
    end
end

function Particle.itemIndicator()
    if #pools.itemIndicator > 0 then
        local ps = table.remove(pools.itemIndicator)
        ps:reset()
        ps:start()
        return ps
    end

    local particleImage = getImage("sprites/circle-particle.png")
    if not particleImage then
        print("ERROR: circle-particle.png NOT FOUND!")
        return nil
    end -- nomore updates from here if not img)

    local ps = love.graphics.newParticleSystem(particleImage, 100)
    ps:setParticleLifetime(2, 4)
    ps:setEmissionRate(20)
    ps:setSizes(0.2, 0.5)
    ps:setSizeVariation(1)
    ps:setSpread(math.pi * 2)
    ps:setSpeed(6, 18)
    ps:setLinearAcceleration(-4, -4, 4, 4)

    ps:setColors(1, 1, 0.5, 0.7,
                 1, 1, 0.2, 0
    )
    return ps
end

function Particle.getItemIndicator()
    if #pools.itemIndicator > 0 then
        local ps = table.remove(pools.itemIndicator)
        ps:reset() -- clear particles
        ps:start() -- enable emits
        return ps
    elseif #pools.itemIndicator < MAX_POOL_SIZE.itemIndicator then
        return Particle.itemIndicator() -- use itemIndicator to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

function Particle.returnItemIndicator(ps)
    if #pools.itemIndicator < MAX_POOL_SIZE.itemIndicator then
        ps:stop()
        ps:reset()
        table.insert(pools.itemIndicator, ps)
    end
end

-- used to clear on gamestate transitions
function Particle.clearItemIndicatorPool()
    pools.itemIndicator = {}
end

-- for debugging and measuring pool size
function Particle.getItemIndicatorPoolSize()
    return #pools.itemIndicator
end

-- for impact on walls, enemy, etc
function Particle.onImpactEffect()
    if #pools.onImpactEffect > 0 then
        local ps = table.remove(pools.onImpactEffect)
        ps:reset()
        ps:start()
        return ps
    end

    local particleImage = getImage("sprites/particle.png")
    if not particleImage then
        print("ERROR: particle.png NOT FOUND!")
        return nil
    end -- No further setup if image is missing

    local ps = love.graphics.newParticleSystem(particleImage, 30)
    ps:setParticleLifetime(0.2, 0.4)
    ps:setEmissionRate(0) -- Usually emit burst manually
    ps:setEmissionArea("ellipse", 12, 12) -- splash effect on impact
    ps:setSizes(1, 6)
    ps:setSizeVariation(0.7)
    ps:setSpread(math.pi * 2)
    ps:setSpeed(80, 180)
    -- ps:setLinearAcceleration(-20, -20, 20, 20)
    ps:setColors(
        1, 0.85, 0.2, 0.8,   -- bright yellow/orange, mostly opaque
        1, 0.6, 0.1, 0.2     -- fades to orange, transparent
    )
    return ps
end

function Particle.getOnImpactEffect()
    if #pools.onImpactEffect > 0 then
        local ps = table.remove(pools.onImpactEffect)
        ps:reset() -- clear particles
        ps:start() -- enable emits
        return ps
    elseif #pools.onImpactEffect < MAX_POOL_SIZE.onImpactEffect then
        return Particle.onImpactEffect() -- use onImpactEffect to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

function Particle.returOnImpactEffect(ps)
    if #pools.onImpactEffect < MAX_POOL_SIZE.onImpactEffect then
        ps:stop() -- stop emission
        ps:reset() -- clear particles
        table.insert(pools.onImpactEffect, ps)
    end
end

-- for player and enemy death
function Particle.onDeathEffect()
    if #pools.onDeath > 0 then
        local ps = table.remove(pools.onDeath)
        ps:reset()
        ps:start()
        return ps
    end

    local particleImage = getImage("sprites/particle.png")
    if not particleImage then
        print("ERROR: particle.png NOT FOUND!")
        return nil
    end -- No further setup if image is missing

    local ps = love.graphics.newParticleSystem(particleImage, 30)
    ps:setParticleLifetime(0.2, 0.4) -- longer life to make sure each ps persists
    ps:setEmissionRate(0) -- Emit burst manually in Utils.dies
    ps:setEmissionArea("ellipse", 10, 10)
    ps:setSizes(1, 6)
    ps:setSizeVariation(0.7)
    ps:setSpread(math.pi * 2)
    ps:setSpeed(80, 180)
    -- ps:setLinearAcceleration(-20, -20, 20, 20)
    ps:setColors(
        1, 0, 0, 1,    -- bright red
        1, 0.3, 0, 0   -- fades to orange, transparent
    )
    return ps
end

function Particle.getOnDeathEffect()
    if #pools.onDeath > 0 then
        local ps = table.remove(pools.onDeath)
        print("[DeathEffect] Reusing PS:", tostring(ps))
        ps:reset()
        ps:start()
        return ps
    elseif #pools.onDeath < MAX_POOL_SIZE.onDeath then
        return Particle.onDeathEffect()
    else
        print("[DeathEffect] Pool empty, spawning new deathEffect!")
        return nil
    end
end

function Particle.returnOnDeathEffect(ps)
    if #pools.onDeath < MAX_POOL_SIZE.onDeath then
        ps:stop()
        ps:reset()
        table.insert(pools.onDeath, ps)
    end
end

function Particle:load()
end

return Particle