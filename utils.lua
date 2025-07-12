local Particle = require("particle")

local Utils = {}

-- logic used in both player and enemy
-- create and require Utils in ..blob1.health..
-- maintainability and reduce redundancy

-- used to copy rundata, make sure player inventory persists through room transitions
-- seen tables is a common fix for deep copy functions in lua and other languages
function Utils.deepCopy(orig, seen) -- seen table used internally
    seen = seen or {} -- seen table maps original tables to their copies
    -- local orig_type = type(orig)
    -- before copying a table, checks if it's already been copied 
    -- If so, it reuses the copy instead of recursing again
    if type(orig) ~= 'table' then return orig end -- if orig is not a table, return as is
    if seen[orig] then return seen[orig] end -- if already copied, return previously created copy
    local copy = {}
    seen[orig] = copy -- associates orig with its copy to the seen table
    for k, v in next, orig, nil do -- iterates over k-v pair in orig
        copy[Utils.deepCopy(k, seen)] = Utils.deepCopy(v, seen) -- recursively deep copies k-v pair and assigns them to the new copy table
    end

    setmetatable(copy, Utils.deepCopy(getmetatable(orig), seen)) -- if orig has a metatable, recursively deep-copies it and assigns it to the new table
    return copy -- retuns fully deep copied copy table
end

function Utils.takeDamage(target, dmg)
  target.health = target.health - dmg
    if target.health <= 0 then
        Utils.die(target)
    end
end

function Utils.dealDamage(attacker, target, dmg)
    if attacker == target then return end -- prevent hurting self
    print("UTILS DEBUG: " .. attacker.name .. " dealt " .. dmg .. " damage to " .. target.name)
    if target.takeDamage then
        target:takeDamage(dmg)
    end
end

function Utils.die(target)
    if target and target.name then
        print(target.name .. " has died!")

    -- Additional death logic here

    -- when an entity dies
    local deathEffect = Particle.getOnDeathEffect()
    if deathEffect then
        deathEffect:setPosition(target.x, target.y)
        deathEffect:emit(20)
        table.insert(globalParticleSystems, deathEffect)
    end

    -- increment score on each enemy kill
    if target.type == "enemy" then
        if _G.incrementPlayerScore then
            _G.incrementPlayerScore(1)
        else
            print("ERROR: _G.incrementPlayerScore function not found in main.lua to award points for kills.")
        end
    end

    else
        print("Utils.die() was called with an invalid or nameless target.")
    end
end

function checkCircularCollision(obj1, obj2)
  if not obj1 or not obj2 or not obj1.radius or not obj2.radius then return false end
  local dx = obj1.x - obj2.x
  local dy = obj1.y - obj2.y
  local distanceSquared = dx*dx + dy*dy
  local sumOfRadii = obj1.radius + obj2.radius
  return distanceSquared <= sumOfRadii * sumOfRadii
end

return Utils