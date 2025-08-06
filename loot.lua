local Particle = require("particle")

function createShardDrop(x, y)
    return {
        type = "shard",
        image = love.graphics.newImage("sprites/magicite-shard.png"),
        x = x, y = y
        -- TODO: add bounce and particles
    }
end

-- Remove dropped item
function removeDroppedItem(item)
    if not item then return end -- defensive nil check

    -- use once attached to global particle system
    -- if item.particle then
    --     for i = #globalParticleSystems, 1, -1 do
    --         if globalParticleSystems[i] == item.particle then
    --             table.remove(globalParticleSystems, i)
    --             break
    --         end
    --     end
    --     item.particle = nil
    -- end

    -- if item.particle then
    --     for i = #itemDropSystems, 1, -1 do
    --         if itemDropSystems[i] == item.particle then
    --             table.remove(itemDropSystems, i)
    --             break
    --         end
    --     end
    --     item.particle = nil
    -- end

    -- Return the ps to the pool if it exists
    if item.particle then
        Particle.returnItemIndicator(item.particle)
        item.particle = nil
    end

    -- remove item/weapon from the droppedItems table
    for i = #droppedItems, 1, -1 do
        if droppedItems[i] == item then
            table.remove(droppedItems, i)
            break
        end
    end
end

-- convert weapons into droppable items
-- logic related to spawning, managing, and picking up lootable items
function createWeaponDropFromInstance(weapon, x, y)
  return {
    name = weapon.name,
    image = weapon.image,
    weaponType = weapon.weaponType,
    rarity = weapon.rarity,
    baseSpeed = weapon.baseSpeed,
    baseFireRate = weapon.baseFireRate or weapon.fireRate or 2,
    projectileClass = weapon.projectileClass,
    baseDamage = weapon.baseDamage,
    knockback = weapon.knockback,
    baseRange = weapon.baseRange,
    level = weapon.level or 1,
    id = weapon.id,
    x = x,
    y = y,
    type = weapon.type --  or "weapon"
  }
end

return {
  createWeaponDropFromInstance = createWeaponDropFromInstance,
  removeDroppedItem = removeDroppedItem,
  createShardDrop = createShardDrop
}