local Particle = {}

-- image cache to avoid redundant/repeated image loading
local _imgCache = {}

-- pool sparks for projecticles, better performance
local pools = { baseSpark = {} }

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
    else
        return Particle.baseSpark() -- use baseSpark to create ps
    end
end

-- 
function Particle.returnBaseSpark(ps)
    ps:stop()
    ps:reset()
    table.insert(pools.baseSpark, ps)
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

    -- particles emitted per second
    -- ps:setEmissionRate(isBurst and 0 or 80) -- disable continuous if isBurst
    ps:setEmissionRate(80) -- continuous

    -- particle size transition from 50%-120% size
    -- ps:setSizes(0.5, 1.2)
    ps:setSizes(3, 12)

    -- particle emission angle = 360 degrees
    ps:setSpread(math.pi * 2) -- 360° burst

    -- speed range for particles as they are emitted, high value = particles move away from emitter faster
    ps:setSpeed(20, 60)

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

function Particle:load()
end

return Particle