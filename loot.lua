-- Remove dropped item
function removeDroppedItem(item)
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