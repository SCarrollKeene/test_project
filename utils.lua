local Utils = {}

-- logic used in both player and enemy
-- create and require Utils in ..blob1.health..
-- maintainability and reduce redundancy

function Utils.takeDamage(target, dmg)
  target.health = target.health - dmg
    if target.health <= 0 then
        Utils.die(target)
    end
end

function Utils.dealDamage(attacker, target, dmg)
    print("UTILS DEBUG: " .. attacker.name .. " dealt " .. dmg .. " damage to " .. target.name)
    if target and target.takeDamage then
        target:takeDamage(dmg)
    end
end

function Utils.die(target)
    if target and target.name then
        print(target.name .. " has died!")
    -- Additional death logic here
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