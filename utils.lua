local Particle = require("particle")

local Utils = {}

-- logic used in both player and enemy
-- create and require Utils in ..blob1.health..
-- maintainability and reduce redundancy

-- Weighted rarity definition
local RARITY_WEIGHTS = {
  common = 55,
  uncommon = 25,
  rare = 12,
  epic = 5,
  legendary = 2,
  exotic = 0.7,
  mythic = 0.3
}

-- Optionally make this a field of Utils if you want to change weights at runtime
Utils.RARITY_WEIGHTS = RARITY_WEIGHTS

function Utils.pickRandomRarity()
  local total = 0
  for _, w in pairs(Utils.RARITY_WEIGHTS) do
    total = total + w
  end
  local rnd = math.random() * total
  local cumulative = 0
  for k, w in pairs(Utils.RARITY_WEIGHTS) do
    cumulative = cumulative + w
    if rnd <= cumulative then return k end
  end
  return "common" -- fallback
end

function Utils.adjustRarityWeightsForLevel(level)
  -- This simple version boosts rarer tiers after level 10, adjust as needed
  Utils.RARITY_WEIGHTS.rare = level > 10 and 17 or 12 -- increase spawn chance
  Utils.RARITY_WEIGHTS.epic = level > 10 and 8 or 5 -- else keep chances low for early game lvls
  -- You can add other tuning or scaling here for late-game drops if desired
end

function Utils.isIdenticalWeapon(a, b)
    return a and b and a.id == b.id
end

function Utils.isSameWeaponForLevelUp(a, b)
    return a and b
       and a.name == b.name
       and a.weaponType == b.weaponType
       and (a.rarity or "common"):lower() == (b.rarity or "common"):lower()
end

function Utils.isSameWeapon(weaponA, weaponB)
    return weaponA and weaponB 
    and weaponA.name == weaponB.name
    and weaponA.weaponType == weaponB.weaponType
    and (weaponA.rarity or "common"):lower() == (weaponB.rarity or "common"):lower()
end

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

-- bounding box test between entity's AABB and current cam viewport
function Utils.isAABBInView(cam, x, y, w, h)
    local camX, camY = cam:position()
    local viewW, viewH = love.graphics.getWidth() / cam.scale, love.graphics.getHeight() / cam.scale
    local left, right = camX - viewW / 2, camX + viewW / 2
    local top, bottom = camY - viewH / 2, camY + viewH / 2
    -- Add a small buffer to draw things slightly off-screen for smooth entry/exit
    -- adjust 50-100px to tweak smoothness
    local buffer = 32

    return x + w > left - buffer and 
            x < right + buffer and 
            y + h > top - buffer and 
            y < bottom + buffer
end

-- function isPlayerActive()
--   return player and not player.isDead and player.collider
-- end

function Utils.takeDamage(target, dmg)
  target.health = target.health - dmg
    if target.health <= 0 then
        Utils.die(target)
    end
end

function Utils.dealDamage(attacker, target, dmg, killer)
    if attacker == target then return end -- prevent hurting self
    print("UTILS DEBUG: " .. attacker.name .. " dealt " .. dmg .. " damage to " .. target.name)
    if target.takeDamage then
        target:takeDamage(dmg, killer)
    end
end

function Utils.applyKnockback(target, force, angle)
    if target and target.collider and not target.isDead then
        local xVel = math.cos(angle) * force
        local yVel = math.sin(angle) * force
        target.collider:setLinearVelocity(xVel, yVel)
        target.isKnockedBack = true
        target.knockbackTimer = 0.1 -- timer if you want to pause target
        print(string.format("[KNOCKBACK] Applied %.1f force at angle %.2f (%.1f, %.1f)", force, angle, xVel, yVel)) -- Debug info
    end
end

function Utils.die(target, killer)
    if target and target.name then
        print(target.name .. " has died!")

    -- Additional death logic here

    -- grant XP on enemy death
    if target.type == "enemy" and killer and killer.addExperience then
        killer:addExperience(target.xpAmount or 10)
    end

    if killer then
        print("[CURRENT XP] Killer XP: " .. tostring(killer.experience) .. ".")
    else
        print("[CURRENT XP] Enemy is killer, player is dead.")
    end

    print("[XP GAIN] recieved " .. tostring(target.xpAmount) .. ".")

    if killer then
        print("[NEW XP] Killer XP: " .. tostring(killer.experience) .. ".")
    end

    -- when an entity dies
    local deathEffect = Particle.getOnDeathEffect()
    if deathEffect then
        print("[DeathEffect] Activated PS ID:", tostring(deathEffect))
        deathEffect:setPosition(target.x, target.y)
        deathEffect:emit(40)
        -- table.insert(globalParticleSystems, deathEffect)
        table.insert(globalParticleSystems, { ps = deathEffect, type = "deathEffect", radius = 32 } ) -- context-based pooling
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

function Utils.clearAllEnemies()
    -- Remove from enemies table
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e.isDead = true         -- Mark as dead for pooling
        e.toBeRemoved = true    -- Just in case your removal elsewhere uses this
        table.remove(enemies, i)
    end

    -- Deactivate pooled enemies
    if enemyPool then
        for i, e in ipairs(enemyPool) do
            e.isDead = true
            e.toBeRemoved = true
        end
    end
end

function Utils.collectAllShards(metaData, player)
    for i = #droppedItems, 1, -1 do
        local item = droppedItems[i]
        if item.type == "shard" then
            metaData.shards = (metaData.shards or 0) + 1
            -- TODO: make this popup work 8/5/25
            if popupManager and player then
                popupManager:add("+1 shard!", player.x, player.y - 32, {1,1,1,1}, 1.1, -25, 0)
            end
            table.remove(droppedItems, i)
        end
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