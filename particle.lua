local Particle = {}

-- image cache to avoid redundant/repeated image loading
local _imgCache = {}

-- pool sparks for projecticles, better performance
local pools = { baseSpark = {}, itemIndicator = {} }

local fireflySystems = {}

local MAX_POOL_SIZE = 50 -- limit particle pool

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
    -- ps:setColors(1, 1, 1, 1, 1, 1, 1, 0) -- fade to be transparent
    ps:setColors(1, 0.1, 0, 1, 1, 0.4, 0, 0) -- Start: red with a hint of orange, End: orange transparent
    return ps
end

function Particle.getBaseSpark()
    if #pools.baseSpark > 0 then
        local ps = table.remove(pools.baseSpark)
        ps:reset() -- clear particles
        ps:start() -- enable emits
        return ps
    elseif #pools.baseSpark < MAX_POOL_SIZE then
        return Particle.baseSpark() -- use baseSpark to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

-- 
function Particle.returnBaseSpark(ps)
    if #pools.baseSpark < MAX_POOL_SIZE then
        ps:stop()
        ps:reset()
        -- table.insert(pools.baseSpark, ps)
    -- else
        -- ps:release() -- destroy if particle pool is full
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
        -- ps:setEmissionArea("uniform", 50, 50)
        ps:emit(30) -- initial burst
    end
    return ps
end

function Particle.firefly()
    local particleImage = getImage("sprites/circle-particle.png")
    if not particleImage then 
        print("ERROR: circle-particle.png NOT FOUND!")
        return nil 
    end -- nomore updates from here if not img

    local ps = love.graphics.newParticleSystem(particleImage, 50)
    ps:setParticleLifetime(4, 8) -- Wisps live longer
    ps:setEmissionRate(20)            -- low: Gentle, sparse emission, high: swarms
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

-- refactor into globalParticleSystems later
function Particle.spawnFirefly(x, y)
    local ps = Particle.firefly()
    if ps then
        ps:setPosition(x, y)
        ps:start()
        table.insert(fireflySystems, ps)
    end
end

function Particle.updateFireflies(dt)
    for i = #fireflySystems, 1, -1 do
        local ps = fireflySystems[i]
        ps:update(dt)
        if ps:getCount() == 0 or not ps:isActive() then
            table.remove(fireflySystems, i)
        end
    end
end

function Particle.drawFireflies()
    love.graphics.setBlendMode("add")
    for _, ps in ipairs(fireflySystems) do
        love.graphics.draw(ps)
    end
    love.graphics.setBlendMode("alpha")
end

function Particle.clearFireflies()
    fireflySystems = {}
end

function Particle.getFireflyCount()
    return #fireflySystems
end

function Particle.itemIndicator()
    local particleImage = getImage("sprites/circle-particle.png")
    if not particleImage then 
        print("ERROR: circle-particle.png NOT FOUND!")
        return nil 
    end -- nomore updates from here if not img)

    local ps = love.graphics.newParticleSystem(particleImage, 50)
    ps:setParticleLifetime(4, 8)
    ps:setEmissionRate(40)
    ps:setSizes(4, 8)
    ps:setSizeVariation(1)
    ps:setSpread(math.pi * 2)
    ps:setSpeed(6, 18)
    ps:setLinearAcceleration(-4, -4, 4, 4)

    ps:setColors(1,1,1,1,1,1,1,1)
    
    -- )

    return ps
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
    end

    local ps = love.graphics.newParticleSystem(particleImage, 50)
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
    elseif #pools.itemIndicator < MAX_POOL_SIZE then
        return Particle.itemIndicator() -- use itemIndicator to create ps
    else
        return nil -- skip particle creation if pool is full
    end
end

function Particle.returnItemIndicator(ps)
    if #pools.itemIndicator < MAX_POOL_SIZE then
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

function Particle:load()
end

return Particle