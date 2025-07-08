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

    if item.particle then
        for i = #itemDropSystems, 1, -1 do
            if itemDropSystems[i] == item.particle then
                table.remove(itemDropSystems, i)
                break
            end
        end
        item.particle = nil
    end

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
    baseFireRate = weapon.baseFireRate,
    fireRate = weapon.fireRate,
    projectileClass = weapon.projectileClass,
    baseDamage = baseDamage or weapon.damage, -- or baseDamage if you store it
    level = weapon.level,
    x = x,
    y = y
  }
end

return {
  createWeaponDropFromInstance = createWeaponDropFromInstance,
  removeDroppedItem = removeDroppedItem
}