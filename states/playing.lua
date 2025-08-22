local Assets = require("assets")
local Collision = require("collision")
local Gamestate = require("libraries/hump/gamestate")
local LevelManager = require("levelmanager")
local MapLoader = require("maploader")
local WaveManager = require("wavemanager")
local player = require("player")
local ENEMY_CLASSES = require("enemy_registry")
local Enemy = require("enemy")
local enemyTypes = require("enemytypes")
local PlayerRespawn = require("playerrespawn")
local projectiles = require("projectile_store")
local UI = require("ui")
local Moonshine = require("libraries.moonshine")
local PopupManager = require("popupmanager")
local Loot = require("loot")
local Portal = require("portal")
local Particle = require("particle")
local Weapon = require("weapon")
local Projectile = require("projectile")
local Debug = require("game_debug")
local Utils = require("utils")
local CamManager = require("cam_manager")
local data_store = require("data_store")
local SaveSystem = require("save_game_data")

scoreFont = love.graphics.newFont(20)

local playing = {}
local enemies = {} -- enemies table to house all active enemies

popupManager = PopupManager:new()

droppedItems = droppedItem or {} -- global table to manage dropped items, such as weapons
local selectedItemToCompare = nil

local portal = nil -- set portal to nil initially, won't exist until round is won by player
local pendingPortalSpawn = false

local pendingRoomTransition = false

-- for testing purposes, loading the safe room map after entering portal
local saferoomMap

local recycleFocusedItem = nil
local recycleHoldTime = 0
local recycleThreshold = 1.0
local recycleProgress = 0

-- fade variables for room transitions
-- local fadeAlpha = 0         -- 0 = fully transparent, 1 = fully opaque
-- local fading = false        -- Is a fade in progress?
-- local fadeDirection = 1     -- 1 = fade in (to black), -1 = fade out (to transparent)
-- local fadeDuration = 0.5    -- Duration of fade in seconds
-- local fadeHoldDuration = 0.5   -- Length of hold in seconds (adjust as needed)
-- local fadeHoldTimer = 0
-- local fadeTimer = 0
-- local nextState = nil       -- The state to switch to after fade

-- move into its own file later on, possibly
function incrementPlayerScore(points)
    if type(points) == "number" then
        data_store.runData.score = data_store.runData.score + points
        Debug.debugPrint("SCORE: Player score increased by", points, ". New score:", data_store.runData.score)
    else
        Debug.debugPrint("ERROR: Invalid points value passed to incrementPlayerScore:", points)
    end
end
_G.incrementPlayerScore = incrementPlayerScore -- Make it accessible globally for Utils.lua

-- take damage on screen variables
local damageFlashTimer = 0
local DAMAGE_FLASH_DURATION = 0.3 -- 0.3 seconds

function triggerDamageFlash()
    damageFlashTimer = DAMAGE_FLASH_DURATION
end

-- Spawn a weapon drop
function spawnWeaponDrop(name, image, weaponType, rarity, baseSpeed, fireRate, projectileClass, baseDamage, projectileImage, knockback, baseRange, x, y, level, id, type)
  local weaponDrop = {
    name = name,
    image = image,
    weaponType = weaponType,
    rarity = rarity,
    baseSpeed = baseSpeed,
    fireRate = fireRate,
    projectileClass = projectileClass,
    baseDamage = baseDamage,
    projectileImage = projectileImage,
    knockback = knockback,
    baseRange = baseRange,
    x = x,
    y = y,
    level = level or 1,
    id = id or (love.math.random(1, 99999999) .. "-" .. tostring(os.time())),
    baseY = y,
    hoverTime = 0,
    type = type
  } 
  Debug.debugPrint("[SPAWN WEAPON DROP] Name: ".. weaponDrop.name .. " weaponType: " .. weaponDrop.weaponType .."speed: ".. weaponDrop.baseSpeed .. " fire rate: " .. weaponDrop.fireRate .. " base damage: " .. weaponDrop.baseDamage)
    Debug.debugPrint("Created item particle:", weaponDrop.particle)
   --Debug.debugPrint("itemDropSystems count after insert:", #itemDropSystems)

  --weaponDrop.particle = Particle.itemIndicator()
  weaponDrop.particle = Particle.getItemIndicator(weaponDrop.rarity)
    -- Debug.debugPrint("Created item particle:", weaponDrop.particle)
    -- Debug.debugPrint("itemDropSystems count after insert:", #itemDropSystems)
    assert(weaponDrop.particle, "[FAILED] to create item indicator particle")
    if weaponDrop.particle then
        weaponDrop.particle:setPosition(weaponDrop.x, weaponDrop.y)
        weaponDrop.particle:start()
        Debug.debugPrint("[WEAPONDROP PARTICLE] Started particle at position:", weaponDrop.x, weaponDrop.y)
        -- table.insert(globalParticleSystems, weaponDrop.particle)
        -- table.insert(itemDropSystems, weaponDrop.particle)
        Debug.debugPrint("[WEAPONDROP PARTICLE] Created item particle:", weaponDrop.particle)
        weaponDrop.particle:emit(10) -- initial burst on drop
        table.insert(globalParticleSystems, { ps = weaponDrop.particle, type = "itemIndicator", radius = 24 } ) -- context-based pooling

    end
  table.insert(droppedItems, weaponDrop)
  Debug.debugPrint("[Dropped items table] contains: ", #droppedItems .. "items.")
  return weaponDrop -- reference to new weapondrop
end

-- Pick up weapon
function equipWeapon(weaponToEquip)
    -- if player.weapon and player.weapon.weaponType == weaponToEquip.weaponType then
    if Utils.isSameWeaponForLevelUp(player.weapon, weaponToEquip) then

        -- Level up!
        player.weapon:levelUp(player)

        -- Remove the item from droppedItems
        Loot.removeDroppedItem(weaponToEquip)

        -- update player inventory
        player:updateEquipmentInventory()
        return
    end
        -- Drop current weapon if it exists
        if player.weapon then
            local drop = createWeaponDropFromInstance(player.weapon, player.x, player.y)
            table.insert(droppedItems, drop)
        end

        -- pick up new weapon
        player.weapon = Weapon:new(
            weaponToEquip.name,
            weaponToEquip.image,
            weaponToEquip.weaponType,
            weaponToEquip.rarity,
            weaponToEquip.baseSpeed,
            weaponToEquip.baseFireRate,
            weaponToEquip.projectileClass,
            weaponToEquip.baseDamage,
            weaponToEquip.projectileImage,
            weaponToEquip.knockback,
            weaponToEquip.baseRange,
            weaponToEquip.level,
            weaponToEquip.id
        )

        -- TODO: write some frigin equippedSlot logic, i think

        -- Sync inventory to ensure equipped weapon entry is up to date
        player:updateEquipmentInventory()

        -- Remove item from droppedItems...
        Loot.removeDroppedItem(weaponToEquip)
end

function updateDroppedItems(dt)
    for i = #droppedItems, 1, -1 do
        local item = droppedItems[i]
        -- Animate shards "flying" to player
        if item.type == "shard" and item.isAnimating then
            item.collectTimer = item.collectTimer + dt
            local t = math.min(item.collectTimer / item.collectDuration, 1)
            -- Smoothstep for acceleration
            local t2 = t * t * (3 - 2 * t)
            item.x = item.startX + (player.x - item.startX) * t2
            item.y = item.startY + (player.y - item.startY) * t2
            -- Optionally fade/scale/etc here for visuals
            if t >= 1 then
                -- Shard reached player
                data_store.metaData.shards = (data_store.metaData.shards or 0) + 1
                local offset = (item.target.height or 32) / 2 + 18
                -- TODO: this popup isn't working, need to debug more 8/6/25
                if popupManager and item.target then
                    print("Adding ther friggin shard popup at", item.target.x, item.target.y, "time:", love.timer.getTime())
                    popupManager:add("+1 shard!", item.target.x, item.target.y - offset, {1,1,1,1}, 1.1, -25, 0)
                end
                table.remove(droppedItems, i)
            end
        else
            -- Idle hover animation
            if item.baseY then
                item.hoverTime = (item.hoverTime or 0) + dt
                local amplitude = 5
                local speed = 2 * math.pi
                item.y = item.baseY + amplitude * math.sin(speed * item.hoverTime)
                if item.particle then
                    item.particle:setPosition(item.x, item.y)
                    item.particle:update(dt)
                end
            end
        end
    end
end

function checkPlayerPickups()
    local pickupRadius = 12

    for i = #droppedItems, 1, -1 do
        local item = droppedItems[i]
        if item and item.x and item.y then
            local dx = player.x - item.x
            local dy = player.y - item.y
            local distSq = dx * dx + dy * dy
            if distSq <= pickupRadius * pickupRadius then
                if item.type == "shard" then
                    data_store.metaData.shards = (data_store.metaData.shards or 0) + 1
                    Debug.debugPrint("[SHARD PICKUP] Total shards: " .. tostring(data_store.metaData.shards))
                    if popupManager and player then
                        popupManager:add("+1 shard!", player.x, player.y - 34, {1,1,1,1}, 1.1, -25, 0)
                    end
                    Loot.removeDroppedItem(item)
                    SaveSystem.saveGame()
                    -- TODO: sounds for shard pickups
                elseif item.type == "health potion" then
                    if player.health < player.maxHealth then
                        local healing = 10
                        player.health = math.min(player.health + healing, player.maxHealth)

                        local healPS = Particle.getHealEffect()
                        if healPS then
                            healPS:setPosition(player.x, player.y - 12) -- slightly above center
                            healPS:start()
                            healPS:emit(18) -- number of particles, tweak to taste
                            table.insert(globalParticleSystems, { ps = healPS, type = "healEffect", radius = 38 })
                        end

                        if popupManager and player then
                            popupManager:add("+" .. healing .. " HP!", player.x, player.y - 34, {0,1,0,1}, 1.1, -25, 0)
                        end
                        Loot.removeDroppedItem(item)
                        SaveSystem.saveGame()
                        -- TODO: sounds for potion heal / health full scenaraios
                    else
                        if popupManager and player then
                            popupManager:add("Health Full", player.x, player.y - 34, {1,1,1,1}, 1.1, -25, 0)
                        end
                    end
                elseif item.type == "weapon" then
                    player.canPickUpItem = item
                    selectedItemToCompare = item
                end
            end
        end
    end
end

-- function playing:spawnRandomEnemy(x, y, availableEnemyTypes)
--     Debug.debugPrint("[FROM SPAWNRANDOMENEMY POOL] Total enemies:", #self.enemyPool) -- debug preloaded pool status
--     Debug.debugPrint("AvailableEnemyTypes:", availableEnemyTypes) -- works if you pass in an enemy type as a 3rd param in spawnRandomEnemy
--     if type(availableEnemyTypes) == "table" then for i,v in ipairs(availableEnemyTypes) do print("  ",i,v) end end

--     local state = Gamestate.current()

--     -- 6/20/25 no spawning in safe rooms!
--     if state == safeRoomState then return end

--     local enemyCache = self.enemyImageCache or {} -- Use the current state's enemy image cache, not global

--     -- Pick a random enemy type from the enemyTypes configuration table
--     -- local randomIndex = math.random(1, #enemyTypes) -- picks a random index between 1-3
--     -- local randomBlob = enemyTypes[randomIndex] -- returns a random blob from the table

--     -- Filter based on enemyTypes if provided
--     --local availableBlobs = {}
--     local allEnemyTypes = self.allEnemyTypes or enemyTypes
--     local availableEnemyVariants = Utils.getAvailableEnemyVariants(allEnemyTypes, availableEnemyTypes)
    
--     -- if AvailableEnemyTypes and #AvailableEnemyTypes > 0 then
--     --     -- create a filtered list of available blobs based on enemyTypes
--     --     for _, blob in ipairs(enemyTypes) do
--     --         for _, allowedType in ipairs(AvailableEnemyTypes) do
--     --             if blob.name == allowedType then
--     --                 table.insert(availableBlobs, blob)
--     --                 break -- Exit inner loop if match found
--     --             end
--     --         end
--     --     end
--     -- else
--     --     -- If no specific types provided, use all available blobs
--     --     availableBlobs = enemyTypes
--     -- end

--     -- fall back to all types if filtered list is empty
--     if availableEnemyVariants and #availableEnemyVariants == 0 then
--         Debug.debugPrint("[SPAWNRANDOMENEMY] No valid enemy types to spawn, using all random blobs.")
--         availableEnemyVariants = Utils.getAvailableEnemyVariants(allEnemyTypes) -- Use all enemyTypes if none match the filter
--     end

--     -- select random enemy from filtered list
--     local pickedIndex = love.math.random(1, #availableEnemyVariants) -- Pick a random blob type from available blobs
--     local enemyDef = availableEnemyVariants[pickedIndex] -- Get a random blob configuration

--     -- Check if the image is already cached
--     local img = enemyCache[enemyDef.spritePath]
--      if not img then
--         Debug.debugPrint("MISSING IMAGE FOR: ", enemyDef.name, "at path:", enemyDef.spritePath)
--         return -- Exit if image is missing
--     end

--     -- BEGIN POOL logic
--     -- Try to reuse from pool
--     for i, e in ipairs(self.enemyPool) do
--         if e.isDead then
--             -- if e.name == "Gorgoneye" then
--             --     e:reset(x, y, enemyDef, img)
--             -- else
--                 e:reset(x or love.math.random(32, love.graphics.getWidth() - 32),
--                         y or love.math.random(32, love.graphics.getHeight() - 32),
--                         enemyDef, img)
--             -- end
--             e:setTarget(player)
--             e.isDead = false
--             e.toBeRemoved = false
--             table.insert(enemies, e)
--             Debug.debugPrint("[POOL REUSE] Reactivating as:", enemyDef.name)
--             return
--         end
--     end
--     -- END POOL LOGIC

--     -- Get random position within screen bounds
--     -- minimum width and height from enemy to be used in calculating random x/y spawn points
--     local enemy_width, enemy_height = 32, 32  -- Default, or use actual frame size
--     local spawnX = x or love.math.random(enemy_width, love.graphics.getWidth() or 800 - enemy_width)
--     local spawnY = y or love.math.random(enemy_height, love.graphics.getHeight()or 600 - enemy_height)

--     -- IF no pool THEN create new enemy instance
--     -- Create the enemy instance utilizing the enemyDef variable to change certain enemy variables like speed, health, etc
--     local newEnemy
--     -- if enemyDef.name == "Gorgoneye" then
--     --     newEnemy = Gorgoneye:new(
--     --         world, enemyDef.name, spawnX, spawnY, enemy_width, enemy_height,
--     --         enemyDef.health, enemyDef.speed, enemyDef.baseDamage, enemyDef.xpAmount, img)
--     -- else
--         newEnemy = Enemy:new(
--             world, enemyDef.name, spawnX, spawnY, enemy_width, enemy_height, nil, nil, 
--             enemyDef.maxHealth, enemyDef.speed, enemyDef.baseDamage, enemyDef.xpAmount, img)
--     -- end
    
--     -- configure new_enemy to target player
--     newEnemy:setTarget(player)

--     -- add newEnemy into enemies table
--     table.insert(enemies, newEnemy)
--     -- add newly created enemies into the pool as well
--     table.insert(self.enemyPool, newEnemy)

--     newEnemy.spriteIndex = pickedIndex -- Store sprite index for rendering
--     Debug.debugPrint("[NEW ENEMY from Spawn Random Enemy] Created:", enemyDef.name)

--     -- debug
--     Debug.debugPrint(string.format("[SPAWN] Spawned at: %s at x=%.1f, y=%.1f", enemyDef.name, spawnX, spawnY))

--     -- if wave.boss then
--     --     spawnBossEnemy()
--     --     return
--     -- end
-- end

function playing:spawnRandomEnemy(x, y, availableEnemyTypes)
    -- Debug for spawn intent
    Debug.debugPrint("[FROM SPAWNRANDOMENEMY POOL] Total enemies:", #self.enemyPools)
    Debug.debugPrint("AvailableEnemyTypes:", availableEnemyTypes)
    if type(availableEnemyTypes) == "table" then
        for i, v in ipairs(availableEnemyTypes) do print("  ", i, v) end
    end

    -- Do NOT spawn in safe rooms
    local state = Gamestate.current()
    if state == safeRoomState then return end

    -- Determine set of allowed enemy VARIANT configs to pick from (stat/config selection)
    local allEnemyTypes = self.allEnemyTypes or enemyTypes
    local variants = Utils.getAvailableEnemyVariants(allEnemyTypes, availableEnemyTypes)
    if not variants or #variants == 0 then
        Debug.debugPrint("[SPAWNRANDOMENEMY] No valid enemy types, using all as fallback.")
        variants = Utils.getAvailableEnemyVariants(allEnemyTypes)
    end

    -- Select a random enemy config variant from allowed
    local idx = love.math.random(1, #variants)
    local config = variants[idx]

    -- Lookup the logic class from the registry. Fallback to Enemy if not found.
    local logicClass = ENEMY_CLASSES[config.name] or ENEMY_CLASSES["default"] or Enemy

    -- Use cached image
    local img = (self.enemyImageCache or {})[config.spritePath]
    if not img then
        Debug.debugPrint("MISSING IMAGE FOR:", config.name, "at path:", config.spritePath)
        return
    end

    -- calculate area and pool
    local w = config.width
    local h = config.height
    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight

    local poolName = config.poolName or config.type or config.name:lower() -- decide actual method/field
    local pool = self.enemyPools[poolName]
    if not pool then
        pool = {}
        self.enemyPools[poolName] = pool
    end

    local spawnX = x or love.math.random(w, mapW - w)
    local spawnY = y or love.math.random(h, mapH - h)

    -- try to reuse a dead enemy from their respective pool
    for _, e in ipairs(pool) do
        if e.isDead then
            if e.reset then
                e:reset(spawnX, spawnY, config, img)
                e:setTarget(player)
                e.isDead = false
                e.toBeRemoved = false
                table.insert(enemies, e)
                Debug.debugPrint("[POOL REUSE] Reactivated as:", config.name)
                return
            end
        end
    end

    -- Create a new enemy using the logic class from the registry
    -- if no pool reuse exists
    
    local newEnemy = logicClass:new({
        world = world,
        name = config.name,
        x = spawnX,
        y = spawnY,
        width = w,
        height = h,
        maxHealth = config.maxHealth,
        health = config.maxHealth,
        speed = config.speed,
        baseDamage = config.baseDamage,
        xpAmount = config.xpAmount,
        spriteSheet = img,
        spritePath = config.spritePath
    })
    -- configure new enemy
    newEnemy:setTarget(player)
    newEnemy.isDead = false
    newEnemy.toBeRemoved = false

    -- make enemy active in world and trackable by pool
    table.insert(enemies, newEnemy)
    table.insert(pool, newEnemy)
    newEnemy.spriteIndex = idx
    Debug.debugPrint("[NEW ENEMY from Spawn Random Enemy] Created:", config.name)
    Debug.debugPrint(string.format("[SPAWN POOL EXPAND] Spawned at: %s at x=%.1f, y=%.1f", config.name, spawnX, spawnY))
end

-- based on [Player collider] recreated at map coords:
function playing:spawnPortal()
    -- local portalX = love.graphics.getWidth() / 2
    local mapW = currentMap.width * currentMap.tilewidth
    -- local portalY = love.graphics.getHeight() / 2
    local mapH = currentMap.height * currentMap.tileheight
    local portalX = mapW / 2
    local portalY = mapH / 2
    portal = Portal:new(world, portalX, portalY)
    self.stateContext.portal = portal
end

function playing:roomComplete()
    data_store.runData.cleared = true
    pendingPortalSpawn = true
    self:spawnPortal() -- TODO: maybe, revisit later 6/20/25
    Debug.debugPrint("Room " ..data_store.runData.currentRoom.. " completed!")
end

function playing:keypressed(key)
    -- if key == "e" and player.canPickUpItem then
    --         player:addItem(player.canPickUpItem) -- add item to player inventory
    --         selectedItemToCompare = player.canPickUpItem
    --         equipWeapon(player.canPickUpItem) -- equip item/weapon
    --         player.weapon:levelUp(player) -- weapon level up
    --         Loot.removeDroppedItem(player.canPickUpItem) -- remove picked up item from world
    --         player.canPickUpItem = nil -- safety check / error prevention
           
    --     -- After level up, if mult weapons in inventory, update the matching entry for equipped weapon
    --     player:updateEquipmentInventory()
    -- end

    -- if key == "e" and selectedItemToCompare then
    --         player:addItem(selectedItemToCompare) -- add item to player inventory
    --         -- selectedItemToCompare = player.canPickUpItem
    --         equipWeapon(selectedItemToCompare) -- equip item/weapon
    --         player.weapon:levelUp(player) -- weapon level up
    --         Loot.removeDroppedItem(selectedItemToCompare) -- remove picked up item from world
    --         -- player.canPickUpItem = nil -- safety check / error prevention
    --         selectedItemToCompare = nil
    --     -- After level up, if mult weapons in inventory, update the matching entry for equipped weapon
    --     player:updateEquipmentInventory()
    -- end

    if key == "e" and selectedItemToCompare then
        -- player:addItem(selectedItemToCompare)
        equipWeapon(selectedItemToCompare)
        Loot.removeDroppedItem(selectedItemToCompare)
        selectedItemToCompare = nil
        player.canPickUpItem = nil
        player:updateEquipmentInventory()
    end

    -- if key == "q" and selectedItemToCompare then
    --     selectedItemToCompare = nil -- Cancel/skip weapon swap
    -- end

    if key == "t" then
        popupManager:add("Test Popup!", player.x, player.y - 32, {1,1,1,1}, 1.25, -30, 0.25)
    end

    -- fire crystal level up test
    if key == "z" then
        if not player or player.isDead then
            Debug.debugPrint("Cannot drop item: player is nil or dead")
            return
        end
        Utils.adjustRarityWeightsForLevel(player.level)
    
        -- Define Fire Crystal properties
        local fireCrystalName = "Fire Crystal"
        local fireCrystalImage = Weapon.image -- Make sure Weapon.loadAssets() is called at startup
        local fireCrystalWeaponType = "Crystal"
        local fireCrystalRarity = Weapon.pickRandomRarity(Utils.RARITY_WEIGHTS)
        local fireCrystalBaseSpeed = 200
        local fireCrystalBaseFireRate = 2
        local fireCrystalProjectileClass = Projectile
        local fireCrystalBaseDamage = 10
        local fireCrystalProjectileImage = Weapon.projectileImage
        local fireCrystalKnockback = 0
        local fireCrystalBaseRange = 200
        local fireCrystalLevel = 1
        local fireCrystalID = (love.math.random(1, 99999999) .. "-" .. tostring(os.time()))
        local fireCrystalType = "weapon"

        local offset = 20
        local angle = player.facingAngle or 0
        local dropX = player.x + math.cos(angle) * offset
        local dropY = player.y + math.sin(angle) * offset

        -- Create a new Fire Crystal drop
        -- local fireCrystal = Loot.createWeaponDropFromInstance({
        --     name = fireCrystalName,
        --     image = fireCrystalImage,
        --     weaponType = fireCrystalType,
        --     fireRate = fireCrystalFireRate,
        --     projectileClass = fireCrystalProjectileClass,
        --     baseDamage = fireCrystalBaseDamage,
        --     level = fireCrystalLevel
        -- }, dropX, dropY)
        -- table.insert(droppedItems, weaponDrop)

        -- call spawnWeaponDrop to drop a Fire Crystal with particles
        local fireCrystal = spawnWeaponDrop(
            fireCrystalName,
            fireCrystalImage,
            fireCrystalWeaponType,
            fireCrystalRarity,
            fireCrystalBaseSpeed,
            fireCrystalBaseFireRate,
            fireCrystalProjectileClass,
            fireCrystalBaseDamage,
            fireCrystalProjectileImage,
            fireCrystalKnockback,
            fireCrystalBaseRange,
            dropX,
            dropY,
            fireCrystalLevel,
            fireCrystalID,
            fireCrystalType
        )
    end
    -- KEEP THIS, ILL NEED IT LATER
    -- drop held weapon 20 pixels in front of player
    -- if key == "q" and player.weapon then
    --     local offset = 20 -- pixels in front of player
    --     local angle = player.facingAngle or 0 -- if you track facing direction
    --     local dropX = player.x + math.cos(angle) * offset
    --     local dropY = player.y + math.sin(angle) * offset
    --     local drop = Loot.createWeaponDropFromInstance(player.weapon, dropX, dropY)
    --     Debug.debugPrint("Dropped items count:", #droppedItems)
    --     -- local drop = Loot.createWeaponDropFromInstance(player.weapon, player.x, player.y)
    --     table.insert(droppedItems, drop)
    --     player.weapon = nil -- Remove weapon from player
    --     -- Debug.debugPrint("Dropping weapon at:", dropX, dropY, "Image:", tostring(player.weapon.image))
    -- end

    if key == "f" then
        self:spawnRandomEnemy()
    end

    -- 100 enemy stress test
    if key == "f1" then
        for i=1, 100 do
            self:spawnRandomEnemy(love.math.random(100, 700), love.math.random(100, 500))
        end
        player.weapon.fireRate = 0.01  -- Rapid fire
    end
end

function playing:enter(previous_state, world, enemyPools, enemyImageCache, mapCache, safeRoomState, projectileBatches)
    local count = 0
    for _, pool in pairs(enemyPools) do
        count = count + #pool
    end
    assert(count > 0, "No enemies preloaded in any pool!")

    Debug.debugPrint("[PLAYING:ENTER] Entered playing gamestate")
    -- print("[DEBUG] playing:enter, safeRoomState is", tostring(safeRoomState))

    -- stateless, clean approach without needing g variables
    local stateContext = {}

    self.previous_state = previous_state
    self.world = world
    self.enemyPools = enemyPools or {
        blob = {},
        gorgoneye = {}
    }
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache
    self.projectileBatches = projectileBatches
    self.allEnemyTypes = enemyTypes

    -- print("[PLAYING:ENTER] Pool received. #self.enemyPool = " .. tostring(#self.enemyPool))

    -- local total = #self.enemyPool
    -- local gorgoneyeCount = 0
    -- for _, enemy in ipairs(self.enemyPool) do
    --         if enemy.name == "Gorgoneye" or getmetatable(enemy) == Gorgoneye then
    --             gorgoneyeCount = gorgoneyeCount + 1
    --         end
    --     end
    --     print("Enemy Pool: Total enemies =", total, ", Gorgoneyes =", gorgoneyeCount)

    -- debug for what enemies are in the pool
    -- local counts = {}
    -- for _, e in ipairs(self.enemyPools) do
    --     local n = e.name or "UNKNOWN"
    --     counts[n] = (counts[n] or 0) + 1
    -- end
    -- for k, v in pairs(counts) do
    --     print("Pool holds", v, k)
    -- end

    -- local dead, alive = 0, 0
    -- for _, e in ipairs(self.enemyPool) do
    --     if e.isDead then dead = dead + 1 else alive = alive + 1 end
    -- end
    -- print(string.format("EnemyPool status: %d dead = reusable, %d alive (pre-spawn)", dead, alive))

    -- build the context table for collision.lua
    self.stateContext = {
        portal = portal,
        enemyPool = enemyPools,
        enemyImageCache = enemyImageCache,
        mapCache = mapCache,

        pendingRoomTransition = false,
        fading = false,
        fadeDirection = 1,
        fadeHoldTimer = 0,
        fadeDuration = 0.5,
        fadeHoldDuration = 0.5,
        fadeTimer = 0,
        fadeAlpha = 0,
        nextState = nil,
        nextStateParams = nil,

        world = world,
        globalParticleSystems = globalParticleSystems,
        sounds = sounds,

        playingState = self,
        safeRoomState = safeRoomState,

        incrementPlayerScore = incrementPlayerScore
    }

    -- set callbaks for collision detection
    -- world:setCallbacks(Collision.beginContact, nil, nil, nil)
    world:setCallbacks(function(a, b, coll)
        Collision.beginContact(a, b, coll, self.stateContext)
    end)

    -- clear dropped items
    droppedItems = {}
    
    -- may need this when I revisit refactoring the spatial grid to
    -- scale based off of map dimensions, leave commented out for now 7/4/25
    -- wallColliders = {}
    -- for _, wall in ipairs(currentWalls) do
    --     table.insert(wallColliders, wall)
    -- end

    -- Destroy old physics colliders
    for _, collider in ipairs(wallColliders) do
        if collider.destroy and not collider:isDestroyed() then
            collider:destroy()
        end
    end

    -- Clear/reset old wall colliders table
    wallColliders = {}
    currentWalls = {}   

    -- always load map for current combat level
    -- local level = LevelManager.levels[LevelManager.currentLevel] -- remove in playing:enter
    -- local cachedMap = self.mapCache["maps/" .. level.map .. ".lua"] -- remove in playing:enter

    -- Defensive check for bad cache load
    -- if not cachedMap or not cachedMap.map then
    --     error(string.format("[CRITICAL] Map missing in cache for level '%s'", tostring(level.map)))
    -- end
    -- if not cachedMap.wallData then
    --     error(string.format("[CRITICAL] Walls missing in cache for level '%s'", tostring(level.map)))
    -- end

    -- currentMap = cachedMap.map -- remove in playing:enter
    -- currentWalls = MapLoader.instantiateWalls(world, cachedMap.wallData) -- remove in playing:enter

    -- Populate wall colliders from the newly loaded/current walls 
    -- for _, wall in ipairs(currentWalls) do -- remove in playing:enter
    --     table.insert(wallColliders, wall)
    -- end

    -- print("[DEBUG] Entered play state, room:", level.map, "#walls:", #wallColliders)
    -- for i, wall in ipairs(wallColliders) do
    --     if wall.getBoundingBox then
    --         local x, y, w, h = wall:getBoundingBox()
    --         print(string.format(" wall %d: x=%.1f y=%.1f w=%.1f h=%.1f", i, x, y, w, h))
    --     end
    -- end

    -- if not currentMap or not currentMap.width or not currentMap.tilewidth then
    --     error("[CRITICAL] Map or its dimensions missing for: " .. tostring(level.map))
    -- end

    -- Debug check before calculating mapW/mapH
    -- if not currentMap then
    --     print("[DEBUG] currentMap is NIL!")
    -- elseif not currentMap.width then
    --     print("[DEBUG] currentMap.width is NIL!")
    -- elseif not currentMap.tilewidth then
    --     print("[DEBUG] currentMap.tilewidth is NIL!")
    -- else
    --     print(string.format(
    --         "[DEBUG] currentMap loaded: width=%s, tilewidth=%s, height=%s, tileheight=%s",
    --         tostring(currentMap.width),
    --         tostring(currentMap.tilewidth),
    --         tostring(currentMap.height),
    --         tostring(currentMap.tileheight)
    --     ))
    -- end

    LevelManager:loadLevel(LevelManager.currentLevel, self.mapCache, self)
    
    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    local enemyCount = #enemies
    print("Enemy count: " .. enemyCount)

    -- print("[DEBUG] currentMap:", currentMap, 
    --   "width:", currentMap and currentMap.width, 
    --   "tilewidth:", currentMap and currentMap.tilewidth)

    CamManager.setMap(mapW, mapH)
    --CamManager.camera:attach()

    -- >> ADAPTIVE SPATIAL PARTIONING GRID START 7/1/25 <<

    local function getAdaptiveGridCellSize(mapWidth, mapHeight, entityCount)
        -- tweak thresholds and cell sizes to performance needs
        if entityCount and entityCount > 200 then
            return 575
        elseif mapWidth > 2000 or mapHeight > 1200 then
            return 475
        elseif entityCount and entityCount > 100 then
            return 425
        else
            return 300 -- fallback
        end
    end

    -- TODO: revisit making spatial grid scale based on the map width and height
    -- right now its not clearing colliders correctly between :enter and :leave states
    -- reverted back to using hard coded dimensions for the time being 7/4/25
    -- self.gridCellSize = 425 -- Each cell is 200x200 pixels, tweak for performance.
    self.gridCellSize = getAdaptiveGridCellSize(mapW, mapH, enemyCount) -- Each cell is 200x200 pixels, tweak for performance.
    --self.gridWidth = math.ceil(1280 / self.gridCellSize) -- Grid dimensions for your map
    self.gridWidth = math.ceil(mapW / self.gridCellSize) -- Grid dimensions for your map
    --self.gridHeight = math.ceil(768 / self.gridCellSize)
    self.gridHeight = math.ceil(mapH / self.gridCellSize)
    self.spatialGrid = {} -- This will hold all the enemies, sorted into cells.
    
    -- Pre-populate the grid with empty tables to avoid errors
    for x = 1, self.gridWidth do
        self.spatialGrid[x] = {}
        for y = 1, self.gridHeight do
            self.spatialGrid[x][y] = {}
        end
    end

    -- >> ADAPTIVE SPATIAL PARTIONING GRID END 7/1/25 <<

     -- Initialize wave manager
    local levelData = LevelManager.levels[LevelManager.currentLevel]
    self.waveManager = WaveManager.new(levelData)

    -- Initialize projectile batch
    -- self.projectileBatch = love.graphics.newSpriteBatch(Projectile.image, 1000)  -- 1000 = initial capacity
    self.projectileBatches = {}
    -- Only create SpriteBatches for to-be-used images
    self.projectileBatches["fireball"] = love.graphics.newSpriteBatch(Assets.images.fireball, 500)
    self.projectileBatches["gorgoneye_shot"] = love.graphics.newSpriteBatch(Assets.images.gorgoneye_shot, 500)
    -- TODO: add more as needed per new projectile types

     -- Initialize enemy batches for current enemy file
    self.enemyBatches = {}
    
    for _, blob in ipairs(enemyTypes) do
        local img = enemyImageCache[blob.spritePath]
        if img then
            self.enemyBatches[img] = love.graphics.newSpriteBatch(img, 200) -- 200 = initial capacity
        end
    end

    -- reset cleared flag for each new room
    data_store.runData.cleared = false

    -- restore player stats and inventory
    player.inventory = Utils.deepCopy(data_store.runData.inventory)
    player.equippedSlot = data_store.runData.equippedSlot
    player.health = (data_store.runData and data_store.runData.playerHealth) or 100
    player.maxHealth = (data_store.runData and data_store.runData.playerMaxHealth) or 100
    player.level = data_store.runData.playerLevel or 1
    player.experience = data_store.runData.playerExperience or 0
    player.baseDamage = data_store.runData.playerBaseDamage or 1
    player.speed = data_store.runData.playerSpeed or 300

    -- reconstruct equipped weapon from player inventory table
    if player.equippedSlot and player.inventory[player.equippedSlot] then
        local w = player.inventory[player.equippedSlot]
        player.weapon = Weapon:new(
            w.name,
            w.image,
            w.weaponType,
            w.rarity,
            w.baseSpeed,
            w.baseFireRate,
            w.projectileClass,
            w.baseDamage,
            w.projectileImage,
            w.knockback,
            w.baseRange,
            w.level,
            w.id,
            w.type
        )
    end

    -- destroy collider to make sure its in the right position
    if player.collider then
        player.collider:destroy()
        player.collider = nil
    end
    player:load(world, player.mage_spritesheet_path, player.dash_spritesheet_path, player.death_spritesheet_path) -- creates a new player collider at the correct position in the current world

    -- Reset player position and state
    -- window coords
    -- player.x = 140
    -- player.y = love.graphics.getHeight() / 3
    -- Debug.debugPrint("[Player collider] recreated at:", player.x, player.y)

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    -- map coords
    player.x = mapW / 4
    player.y = mapH / 3
    --Debug.debugPrint("[Player collider] recreated at map coords:", mapW, mapY)

    if player.collider then
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    -- Recreate collider if missing
    -- if not player.collider then
    --     player:load(world)  
    -- end
    
    -- Spawn initial enemies if needed
    -- if #enemies == 0 then
    --     spawnRandomEnemy()
    -- end

    -- Reload enemy animations
    -- for i, enemy in ipairs(enemies) do
    --     if enemy.spriteSheet then
    --         enemy.currentAnimation = enemy.animations.idle
    --         -- enemy.currentAnimation:reset()
    --     end
    -- end

     -- Single draw call for batching all enemies of same type
    for _, batch in pairs(self.enemyBatches) do
        batch:clear()
        for _, enemy in ipairs(enemies) do
            if enemy.spriteSheet == batch.texture then
                batch:addQuad(quad, enemy.x, enemy.y)
            end
        end
        love.graphics.draw(batch)
    end

    local toDrawIndividually = {} -- Table to hold enemies that need to be drawn individually (flashing or fallback)

    local individualCount = #toDrawIndividually
    Debug.debugPrint("[DRAW DEBUG]: Individual enemies to draw:", individualCount)

    for _, enemy in ipairs(enemies) do
        if not enemy.toBeRemoved and enemy.spriteSheet and enemy.currentAnimation then
            if enemy.isFlashing then
                table.insert(toDrawIndividually, enemy)
            else
                local batch = self.enemyBatches[enemy.spriteSheet]
                if batch and enemy.currentAnimation.getFrame then
                    local quad = enemy.currentAnimation:getFrame()
                    batch:add(quad, enemy.x, enemy.y, 0, 1, 1, enemy.width/2, enemy.height/2)
                else
                    table.insert(toDrawIndividually, enemy)
                end
            end
        end
    end
    
    -- Draw batched enemies
    for _, batch in pairs(self.enemyBatches) do
        love.graphics.draw(batch)
    end
    
    -- Draw individual enemies (flashing or fallback)
    for _, enemy in ipairs(toDrawIndividually) do
        if enemy.currentAnimation and enemy.spriteSheet then
            if enemy.isFlashing then
                love.graphics.setShader(flashShader)
                flashShader:send("WhiteFactor", 1.0)
            else
                love.graphics.setShader()
            end
            enemy.currentAnimation:draw(enemy.spriteSheet, enemy.x, enemy.y, 0, 1, 1, enemy.width/2, enemy.height/2)
            love.graphics.setShader() -- Reset shader
        else
            -- Fallback drawing for enemies without animation
            enemy:draw()
        end
    end

    
    -- fading logic test, TODO: fix fading logic into saferoom AGAIN 8/21/25
    self.stateContext.fading = true
    self.stateContext.fadeDirection = -1  -- fade in (from black)
    self.stateContext.fadeTimer = 0
    self.stateContext.fadeAlpha = 1
end

function playing:leave()
    -- stop music, clear temp tables/objects, destroy portals, etc
    print("[PLAYING:LEAVE] playing leave called")

    print("Walls before cleanup:", #wallColliders, "currentWalls:", #currentWalls)
    for _, collider in ipairs(wallColliders) do
        if not collider:isDestroyed() then
            collider:destroy()
        else
            print("[PLAYING:LEAVE] Collider already destroyed:", collider)
        end
    end
    wallColliders = {}
    currentWalls = {}
    print("Walls after cleanup:", #wallColliders, "currentWalls:", #currentWalls)

    -- clear particles
    globalParticleSystems = {}

    -- destroy any remaining player/enemy colliders
    for _, enemy in ipairs(enemies) do
        if enemy.collider then enemy.collider:destroy() end
    end

    projectiles = {} -- clear projectiles table

    -- need to destroy any remaining projectile colliders on :leave()

    -- destroy current remaining portal
    if portal then
        portal:destroy();
        portal = nil
    end

    -- reset flags
    pendingRoomTransition = false
    Debug.debugPrint("Leaving playing state, cleaning up resources.")

    -- copy current weapon stats to data_store.runData
    player:updateEquipmentInventory()
    -- synch to data_store.runData
    data_store.runData.inventory = Utils.deepCopy(player.inventory)
    data_store.runData.equippedSlot = player.equippedSlot
    data_store.runData.playerHealth = player.health
    data_store.runData.playerMaxHealth = player.maxHealth
    data_store.runData.playerLevel = player.level
    data_store.runData.playerExperience = player.experience
    data_store.runData.playerBaseDamage = player.baseDamage
    data_store.runData.playerSpeed = player.speed

    -- save game after clearing initial room
    SaveSystem.saveGame()
end

function playing:update(dt)
    Debug.debugPrint("playing:update")
    -- small GC step every frame to keep frame times smooth
    collectgarbage("step", 5)

    if love.keyboard.isDown("q") and selectedItemToCompare then
        if not recycleFocusedItem then
            recycleFocusedItem = selectedItemToCompare
            recycleHoldTime = 0
        end

        recycleHoldTime = (recycleHoldTime or 0) + dt
        if recycleHoldTime >= recycleThreshold and recycleFocusedItem then
            -- possibly change to coins later 8/7/25
            Loot.recycleWeaponDrop(recycleFocusedItem, data_store.metaData, player)
            selectedItemToCompare = nil -- Skip
            player.canPickUpItem = nil
            recycleFocusedItem = nil
            recycleHoldTime = 0
            -- TODO: recycle logic for shards/coins here 8/7/25
            -- On recycling, add shards to player's total
            -- remove the item
            -- particle effect for recycling
            -- progress bar for recycle
        end
    else
        recycleFocusedItem = nil
        recycleHoldTime = 0
    end

    -- progress bar for recycle time
    if recycleHoldTime and recycleFocusedItem then
        recycleProgress = math.min(recycleHoldTime / recycleThreshold, 1)
    else
        recycleProgress = 0
    end

    -- frame count
    local frameCount = self.frameCount
    self.frameCount = (self.frameCount or 0) + 1
    
    -- After player:update(dt, mapW, mapH) or player:update(dt)
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    -- local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    CamManager.setMap(mapW, mapH) -- Set map boundaries for the camera
    --CamManager.camera:attach() -- Attach the camera to the LOVE2D graphics system

    -- If player.x or player.y is nil, set them to map center
    if player.x == nil or player.y == nil then
        player.x = mapW / 2
        player.y = mapH / 2
    end

    --local px, py = player.x, player.y

    -- Clamp the camera so it doesn't scroll past the map edges
    local scale = CamManager.scale or 1
    -- local camX = math.max(w/2 / scale, math.min(px, mapW - w/2 / scale))
    -- local camY = math.max(h/2 / scale, math.min(py, mapH - h/2 / scale))
    -- CamManager.lookAt(camX, camY)

    if self.pendingLevelLoad then
        LevelManager:loadLevel(self.pendingLevelLoad)
        self.pendingLevelLoad = nil
        return  -- Skip rest of update this frame
    end

    popupManager:update(dt)

    -- Handle on screen damage taken flash timer
    if damageFlashTimer > 0 then
        damageFlashTimer = damageFlashTimer - dt
    end

    if self.stateContext.pendingRoomTransition then
        self.stateContext.fading = true
        self.stateContext.fadeDirection = 1
        self.stateContext.fadeTimer = 0
        self.stateContext.pendingRoomTransition = false
        return
    end

    if self.stateContext.fading then
        if self.stateContext.fadeDirection == 1 then
            -- Fade out (to black)
            self.stateContext.fadeTimer = self.stateContext.fadeTimer + dt
            self.stateContext.fadeAlpha = math.min(self.stateContext.fadeTimer / self.stateContext.fadeDuration, 1)
            if self.stateContext.fadeAlpha >= 1 then
                -- Fade out complete, start hold
                self.stateContext.fadeHoldTimer = 0
                self.stateContext.fadeDirection = 0    -- 0 indicates hold phase
            end
        elseif self.stateContext.fadeDirection == 0 then
            -- Hold phase (fully black)
            self.stateContext.fadeHoldTimer = self.stateContext.fadeHoldTimer + dt
            self.stateContext.fadeAlpha = 1
            if self.stateContext.fadeHoldTimer >= self.stateContext.fadeHoldDuration then
                -- Hold complete, switch state and start fade in
                print("Next state:", tostring(self.stateContext.nextState))
                Gamestate.switch(self.stateContext.nextState, unpack(self.stateContext.nextStateParams))
                globalParticleSystems = {} -- testing for now, SUPPOSED to clear particles when starting fade out
                -- self.stateContext.fadeDirection = -1
                -- self.stateContext.fadeTimer = 0
            end
        elseif self.stateContext.fadeDirection == -1 then
            -- Fade in (from black)
            self.stateContext.fadeTimer = self.stateContext.fadeTimer + dt
            self.stateContext.fadeAlpha = 1 - math.min(self.stateContext.fadeTimer / self.stateContext.fadeDuration, 1)
            if self.stateContext.fadeAlpha <= 0 then
                self.stateContext.fading = false
                self.stateContext.fadeAlpha = 0
            end
        end

        if self.stateContext.fadeDirection ~= -1 then
            return -- halt other updates during fade
        end
    end

    if not player.isDead then
        local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
        local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
        player:update(dt, mapW, mapH)
    end

    -- Update cam to follow player
    CamManager:follow(player.x, player.y)

    -- if player is dead in grid cell
    if player and not player.isDead and player.x and player.y then
    -- return -- skip spatial enemy checks when player is invalid

        -- update droppable loot/items
        updateDroppedItems(dt)
        checkPlayerPickups()

        local pickupRange = 24  -- Adjust as needed
        player.canPickUpItem = nil  -- Reset each frame

        for i, item in ipairs(droppedItems) do
            local dx = player.x - item.x
            local dy = player.y - item.y

            if math.sqrt(dx * dx + dy * dy) <= pickupRange then
            -- Determine if this item should be auto-picked up or compared
                if player.weapon and Utils.isSameWeaponForLevelUp(player.weapon, item) then
                    -- Auto pickup logic
                    --player:addItem(item)
                    equipWeapon(item) -- Optional: levelUp logic if needed
                    --Loot.removeDroppedItem(item)
                    --player:updateEquipmentInventory()
                else
                    -- Set it as a candidate for comparison UI menu
                    player.canPickUpItem = item -- Store the reference for prompt and pickup
                    selectedItemToCompare = item
                end
                break -- Only prompt for the first item in range
            end
        end

        if not player.canPickUpItem then
            selectedItemToCompare = nil
        end
end

    -- NOTE: I need collision detection before I can continue and the logic for player attacks, enemy attacking player, getting damage values from projectile.damage
    -- and calling the appropriate dealDamage function
    -- AND updating projectile direction control by player : UPDATE: works now for player attacking enemy

    -- change enemy to a diff name to not conflict or be confused with enemy module 6/1/25
    -- old enemy update loop
    -- for i, enemy in ipairs(enemies) do
    --     enemy:update(dt) -- update handles movement towards its target, the player
    --    Debug.debugPrint("DEBUG: SUCCESS, Enemies table size NOW:", #enemies)
    -- end

    -- >> START OF NEW LOOP ENEMY UPDATE LOGIC 7/1/25 <<

    -- 1. Clear the grid from the previous frame
    for x = 1, self.gridWidth do
        for y = 1, self.gridHeight do
            self.spatialGrid[x][y] = {}
        end
    end

    -- 2. Populate the grid with the current positions of all enemies
    for _, enemy in ipairs(enemies) do
        local gridX = math.floor(enemy.x / self.gridCellSize) + 1
        local gridY = math.floor(enemy.y / self.gridCellSize) + 1

        -- Ensure the enemy is within the grid bounds before inserting
        if gridX >= 1 and gridX <= self.gridWidth and gridY >= 1 and gridY <= self.gridHeight then
            table.insert(self.spatialGrid[gridX][gridY], enemy)
        end
    end

    -- 3. Determine the player's grid cell
    local playerGridX = math.floor(player.x / self.gridCellSize) + 1
    local playerGridY = math.floor(player.y / self.gridCellSize) + 1

    -- 4. Only update enemies in the player's cell and the 8 neighboring cells
    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkX = playerGridX + dx
            local checkY = playerGridY + dy

            -- Make sure the neighboring cell is valid
            if checkX >= 1 and checkX <= self.gridWidth and checkY >= 1 and checkY <= self.gridHeight then
                -- This is a "hot" cell, so update every enemy inside it
                for _, enemy in ipairs(self.spatialGrid[checkX][checkY]) do
                    enemy:update(dt, self.frameCount) -- This is the expensive AI update call
                end
            end
        end
    end
-- >> END OF NEW LOOP 7/1/25 <<

    -- Debug: List alive/active enemies
    -- print("[DEBUG] Alive enemies:", #enemies)
    -- for i, e in ipairs(enemies) do
    --     if not e.isDead and not e.toBeRemoved then
    --         print(string.format(
    --             "  #%d - Name: %s | HP: %s | Pos: (%.1f, %.1f)",
    --             i,
    --             tostring(e.name),
    --             tostring(e.health),
    --             e.x or -1,
    --             e.y or -1
    --         ))
    --     else
    --         print(string.format(
    --             "  #%d - Name: %s isDead=%s toBeRemoved=%s",
    --             i,
    --             tostring(e.name),
    --             tostring(e.isDead),
    --             tostring(e.toBeRemoved)
    --         ))
    --     end
    -- end

    -- if #enemies == 0 and not portal then
    --     spawnPortal()
    --     Debug.debugPrint("DEBUG: No enemies in table. Attempting to spawn portal.")
    -- else
    --     Debug.debugPrint("DEBUG: Attempting to update:", #enemies, "enemies in table.")
    -- end

    -- -- if particle systems exists, update it
    -- for i = #globalParticleSystems, 1, -1 do
    --     local ps = globalParticleSystems[i]
    --     ps:update(dt)

    --     -- remove inactive particle systems
    --     -- switched 'and' to 'or' as this removes particles between transitions
    --     -- may need to revisit once we start adding other particle 
    --     if ps:getCount() == 0 or not ps:isActive() then
    --         table.remove(globalParticleSystems, i)
    --         Particle.returnBaseSpark(ps)
    --         Particle.returnItemIndicator(ps)
    --         Particle.returOnImpactEffect(ps)
    --         Particle.returnOnDeathEffect(ps)
    --         Debug.debugPrint("REMOVED INACTIVE PARTICLE SYSTEM")
    --     end
    -- end

    -- Defensive check: remove any invalid entries before updating/drawing
    for i = #globalParticleSystems, 1, -1 do
        local entry = globalParticleSystems[i]
        if type(entry) ~= "table" or not entry.ps then
            Debug.debugPrint("[ERROR] Invalid entry in globalParticleSystems at index", i, entry)
            table.remove(globalParticleSystems, i)
        end
    end

    -- if particle systems exists, update it
    for i = #globalParticleSystems, 1, -1 do
        local entry = globalParticleSystems[i]   -- entry is a table: { ps = ..., type = ... }
        local ps = entry.ps

        if not ps then
            Debug.debugPrint("[UPDATE ERROR] Removing nil ps from globalParticleSystems at index", i)
            table.remove(globalParticleSystems, i)
        else
            ps:update(dt)
        end

        -- remove inactive particle systems
        -- switched 'and' to 'or' as this removes particles between transitions
        -- may need to revisit once we start adding other particle 
        if ps:getCount() == 0 or not ps:isActive() then
            table.remove(globalParticleSystems, i)
            if entry.type == "impactEffect" then
                Particle.returOnImpactEffect(ps)
            elseif entry.type == "firefly" then
                Particle.returnFirefly(ps)
            elseif entry.type == "deathEffect" then
                Particle.returnOnDeathEffect(ps)
            elseif entry.type == "particleTrail" then
                Particle.returnBaseSpark(ps)
            elseif entry.type == "itemIndicator" then
                Particle.returnItemIndicator(ps)
            elseif entry.type == "portalGlow" then
                Particle.returnPortalGlow(ps)
            end
            Debug.debugPrint("REMOVED INACTIVE PARTICLE SYSTEM")
        end
    end

    -- particle culling if over cap
    local ps_cap = 100
    if #globalParticleSystems > ps_cap then
        -- remove oldest particles systems first
        local toRemove = #globalParticleSystems - ps_cap
        for i = 1, toRemove do
            table.remove(globalParticleSystems, 1)
        end
        Debug.debugPrint("Culled", toRemove, "Particle systems")
    end

    -- trying to make particle pool management performant
    -- cleans up pool every 10 seconds, keeps pool at or below max pool size
    Projectile.updatePool(dt)

    -- Reduce physics updates during stress
    -- if love.timer.getFPS() < 30 then
    --     world:update(dt * 0.5)  -- Half-speed physics
    -- else
    --     world:update(dt)
    -- end

    -- if portal exists, update it
    if portal then
        portal:update(dt)
    end

    -- Handle shooting
    -- feels like a global action, maybe move this into main? or a sound file, hmm 5/29/25
    function love.mousepressed(x, y, button, istouch, presses)
        if Gamestate.current() ~= self.stateContext.safeRoomState and not player.isDead and button == 1 then
            sounds.blip:play() -- play projectile blip on mouse click
        end

        if not player.isDead and love.mouse.isDown(1) then
            Debug.debugPrint("DEBUG: left mouse click detected")
            local mx, my = CamManager.camera:worldCoords(love.mouse.getX(), love.mouse.getY())
            local angle = math.atan2(
                -- love.mouse.getY() - player.y, 
                -- love.mouse.getX() - player.x
                my - player.y, 
                mx - player.x
            )
            Debug.debugPrint("DEBUG: calculated angle: ", angle)

            -- REWRITE TIME FOR THE 3rd TIME, I think..
            -- local weapon = player.weaponSlots[player.equippedSlot]
            local weapon = player.weapon
            
            if weapon then
                local damage = weapon:getDamage() or 10
                local speed = weapon:getProjectileSpeed() or 200
                -- create projectiles with angle and speed
                local newProjectile = Projectile.getProjectile(world, player.x, player.y, angle, speed, damage, player, Assets.images.fireball, player.weapon.knockback, player.weapon.range)

               --Debug.debugPrint("DEBUG: player.weapon.shoot() CREATED a projectile\n", "x:", player.x, "y:", player.y, "angle:", angle, "speed:", 600, "\nplayer base dmg:", player.baseDamage, "player weapon dmg:", player.weapon.damage)
                if newProjectile then
                    Debug.debugPrint("Projectile created at x", newProjectile.x, "y:", newProjectile.y)
                table.insert(projectiles, newProjectile)
                    Debug.debugPrint("DEBUG: SUCCESS, Projectile table size NOW:", #projectiles)
                else
                    Debug.debugPrint("DEBUG: FAILED, returned NIL, Cooldown might be active or other issue in shoot.")
                end
            end
        end
    end

    if #projectiles == 0 then
        Debug.debugPrint("DEBUG: No projectiles in table to update.")
    else
        Debug.debugPrint("DEBUG: Attempting to update", #projectiles, "projectiles.")
    end

    -- Update projectiles so that they move over time, not working bro... 5/25/25 it's working now, logic was not in the right place
    for i = #projectiles, 1, -1 do
        Debug.debugPrint("DEBUG: Accessing projectile at index", i, "to call update.")
                local p = projectiles[i]
                p:update(dt) -- proj position update
                if p.toBeRemoved then
                    table.remove(projectiles, i) -- remove projectiles from the projectiles table if they're flagged toBeRemoved
                -- check to remove projectiles if projectiles are off screen

                if p.x + (p.width or p.radius) < 0 or p.x - (p.width or p.radius) > love.graphics.getWidth()
                or p.y + (p.height or p.radius) < 0 or p.y - (p.height or p.radius) > love.graphics.getHeight() then
                    if p.collider then 
                        p.collider:destroy() 
                    end
                        table.remove(projectiles, i)
                    elseif p.toBeRemoved then -- Check flag set in beginContact
                        -- Debug.debugPrint("DEBUG: Removing projectile index:", i)
                        -- Collider already destroyed in beginContact if it hit something
                        table.remove(projectiles, i)
                    end
                end
            Debug.debugPrint("DEBUG: Projectile at index", i, "is nil or has no update method.")
    end

    -- after collision handling
    -- add logic to handle removing dead enemies from the 'enemies' table if enemy:die() sets a flag
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e and e.toBeRemoved then -- Check the flag set in Enemy:die()
            -- Collider should have been destroyed in Enemy:die()
            table.remove(enemies, i)
            print("[PLAYING UPDATE]: Removed " .. (e.name or "enemy") .. " from table.")
            -- check if room is cleared and turn room cleared flag to true
            -- if #enemies == 0 and not data_store.runData.cleared then -- Moved to Utils as part of the clearAllEnemies function
            --     roomComplete()
            -- end
        end
    end

    world:update(dt)

    -- Projectile cleanup (maybe move to projectile.lua later on)
    -- for i = #projectiles, 1, -1 do
    --     local p = projectiles[i]
    --     if p.toBeRemoved then
    --         -- if p.collider then
    --         --     p.collider:destroy()
    --         --     -- p.collider = nil, possibly not needed anymore since walls has data_store.metaData of type 'wall'
    --         -- end
    --         table.remove(projectiles, i)
    --     else
    --         p:update(dt) -- Update projectile position
    --         -- Off-screen check
    --         if p.x + p.width < 0 or p.x - p.width > love.graphics.getWidth() or 
    --             p.y + p.height < 0 or p.y - p.height > love.graphics.getHeight() then
    --             p:destroySelf()
    --         end
    --     end
    -- end

    -- Projectile cleanup v.2 6/29/25
    for i = #projectiles, 1, -1 do
        local p = projectiles[i]
        -- p:update(dt)

        if p.isDestroyed then
            table.remove(projectiles, i)
            Debug.debugPrint("DEBUG: Removed projectile at index", i, "from projectiles table.")
        end
    end

    if self.waveManager and self.waveManager.active then
        self.waveManager:update(dt, function(enemyTypes)
            -- Pass enemyTypes to spawner
            LevelManager:spawnRandomInZone(self, enemyTypes)
        end)

        -- after per-enemy removal loop, potential baackup check for room completion
        if (not self.waveManager or not self.waveManager.active) 
        and #enemies == 0 and not data_store.runData.cleared then
            self:roomComplete()
        end
        
        -- Wave completion check
        if self.waveManager and self.waveManager.isFinished and not data_store.runData.cleared and not self.shardPopupDelay then
            Utils.clearAllEnemies(enemies, self.enemyPools)
            -- test and refine later
            -- Utils.shrinkEnemyPool(self.enemyPools.blob, 70)
            -- Utils.shrinkEnemyPool(self.enemyPools.gorgoneye, 70)
            -- for poolType, pool in pairs(self.enemyPools) do
            --     Utils.shrinkEnemyPool(pool, 300)
            -- end
            Utils.collectAllShards(data_store.metaData, player)
            self.shardPopupDelay = 0.7
        end

        if self.shardPopupDelay then
            self.shardPopupDelay = self.shardPopupDelay - dt
            if self.shardPopupDelay <= 0 then
                self:roomComplete()
                self.shardPopupDelay = nil
            end
        end
    end

    if player.weapon then
        player.weapon:update(dt)
    end
end

function playing:draw()
    Debug.debugPrint("playing:draw")

    -- Calculate camera offset and scale
    local camX, camY = CamManager.camera:position()
    local scale = CamManager.scale or 1
    local tx = camX - love.graphics.getWidth() / 2 / scale
    local ty = camY - love.graphics.getHeight() / 2 / scale

    -- draw map first, player should load on top of map
    if currentMap then
        local mapW = currentMap.width * currentMap.tilewidth
        local mapH = currentMap.height * currentMap.tileheight
        tx = math.max(0, math.min(tx, mapW - love.graphics.getWidth() / scale))
        ty = math.max(0, math.min(ty, mapH - love.graphics.getHeight() / scale))
        -- Clamp tx/ty as above
        currentMap:draw(-tx, -ty, scale, scale)
    end

    CamManager.camera:attach()   
        if not player.isDead then
            player:draw()
        end

        -- draw and cull droppable loot/items
        for _, item in ipairs(droppedItems) do
            if Utils.isAABBInView(
                CamManager.camera,
                item.x - (item.width or 16) / 2,
                item.y - (item.height or 16) / 2,
                item.width or 16,
                item.height or 16
            ) then
                if item.image then
                    love.graphics.draw(item.image, item.x, item.y)
                end
                if item.particle then
                    love.graphics.draw(item.particle)
                end
            end
        end
        
        -- draw drop weapon/item particles, not necessary for pool
        -- Particle.drawItemDropParticles()
        -- Debug.debugPrint("Drawing item drop particles, count:", #itemDropSystems)

        -- draw droppable loot/items particles
        -- for _, item in ipairs(droppedItems) do
        --     if item.particle then
        --         love.graphics.draw(item.particle)
        --     end
        -- end

        -- if player.canPickUpItem then
        --     local prompt = "Press E to pick up " .. (player.canPickUpItem.name or "Weapon")
        --     love.graphics.setColor(1, 1, 1, 1)
        --     love.graphics.print(prompt, player.x - 40, player.y - 50)
        -- end

        -- draw enemies
        for _, enemy in ipairs(enemies) do
            if not enemy.toBeRemoved and Utils.isAABBInView(
                CamManager.camera,
                enemy.x - enemy.width/2,
                enemy.y - enemy.height/2,
                enemy.width, enemy.height
            ) then
                enemy:draw()
            end
        end

        -- check to draw shot projectiles
        -- for _, p in ipairs(projectiles) do
        --     p:draw()
        -- end

        -- new projectile batching for all projectile types
        for _, batch in pairs(self.projectileBatches) do
            batch:clear()
        end

        -- Projectile batching
        -- self.projectileBatch:clear()
        -- for _, p in ipairs(projectiles) do
        --         -- Verify position is numeric
        --         if type(p.x) == "number" and type(p.y) == "number" then
        --         -- For a circular projectile, use radius; for sprite, use width/height
        --         local projW = p.width  or (p.radius and p.radius * 2) or 10
        --         local projH = p.height or (p.radius and p.radius * 2) or 10

        --         local left = p.x - projW/2
        --         local top  = p.y - projH/2

        --         if Utils.isAABBInView(CamManager.camera, left, top, projW, projH) then
        --             self.projectileBatch:add(p.x, p.y, 0, 1, 1, p.width/2, p.height/2)
        --             -- Debug.debugPrint("Projectile batched at position:", p.x, p.y)
        --         else
        --             -- Debug.debugPrint("Projectile culled at position:", p.x, p.y)
        --         end
        --     else
        --         -- Debug.debugPrint("[WARN] Invalid projectile position", p.x, p.y)
        --     end
        -- end
        -- love.graphics.draw(self.projectileBatch)
        -- Debug.debugPrint("Total projectiles in batch:", self.projectileBatch:getCount())

        -- new projectiles batching
        for _, p in ipairs(projectiles) do
            -- Detect image name, default to "fireball" if missing
            local imgName = p.imageName
            if not imgName and p.image == Assets.images.gorgoneye_shot then
                imgName = "gorgoneye_shot"
            elseif not imgName or p.image == Assets.images.fireball then
                imgName = "fireball"
            end
            local batch = self.projectileBatches and self.projectileBatches[imgName]
            if batch and type(p.x) == "number" and type(p.y) == "number" and not p.toBeRemoved then
                local projW = p.width or (p.radius and p.radius * 2) or 10
                local projH = p.height or (p.radius and p.radius * 2) or 10
                local ox, oy = projW/2, projH/2
                batch:add(p.x, p.y, 0, 1, 1, ox, oy)
            end
        end

        for _, batch in pairs(self.projectileBatches) do
            love.graphics.draw(batch)
        end

        -- Enemy rendering
        for _, batch in pairs(self.enemyBatches) do
            batch:clear()
        end

        -- Enemy batching
        for _, batch in pairs(self.enemyBatches) do batch:clear() end

        local toDrawIndividually = {}
        for _, enemy in ipairs(enemies) do
            if not enemy.toBeRemoved and enemy.spriteSheet then
                if enemy.isFlashing then
                    table.insert(toDrawIndividually, enemy)
                else
                    local batch = self.enemyBatches[enemy.spriteSheet]
                    if batch then
                        -- SAFEGUARD: Check if animation exists and has getFrame
                        if enemy.currentAnimation and enemy.currentAnimation.getFrame then
                            local quad = enemy.currentAnimation:getFrame()
                            batch:add(quad, enemy.x, enemy.y, 0, 1, 1, enemy.width/2, enemy.height/2)
                        else
                            Debug.debugPrint("WARN: Missing animation for", enemy.name)
                            table.insert(toDrawIndividually, enemy)  -- Fallback to individual draw
                        end
                    else
                        table.insert(toDrawIndividually, enemy)
                    end
                end
            end
        end

        -- Draw batched enemies
        for _, batch in pairs(self.enemyBatches) do
            love.graphics.draw(batch)
        end

        -- Draw individual enemies (flashing or fallback) WITH SHADER SUPPORT
        for _, enemy in ipairs(toDrawIndividually) do
            enemy:draw()  -- This handles the animation drawing, hopefully with flashshader still intact
        end

        -- draw portal
        if portal then
            portal:draw()
        end
        
        Debug.draw(projectiles, enemies, globalParticleSystems, self.projectileBatches, self.enemyPools)
        Debug.drawEnemyTracking(enemies, player)
        Debug.drawCollisions(world)
        Debug.drawColliders(wallColliders, player, portal)
        Debug.drawAllPhysicsFixtures(world)
        Debug.drawSpatialGrid(self.spatialGrid, self.gridCellSize, self.gridWidth, self.gridHeight, CamManager)

        love.graphics.setBlendMode("add") -- for visibility
        -- draw particles systems last after other entities
        -- for _, ps in ipairs(globalParticleSystems) do
        --     love.graphics.draw(ps)
        -- end
        
        -- clean up sweep defensive nil check to make sure ps != nil or a raw nil is the result
        for i = #globalParticleSystems, 1, -1 do
            local entry = globalParticleSystems[i]
            if type(entry) ~= "table" or not entry.ps then
                Debug.debugPrint("[CLEANUP] Removing invalid entry from globalParticleSystems at index", i)
                table.remove(globalParticleSystems, i)
            end
        end

        for _, entry in ipairs(globalParticleSystems) do
            local ps = entry.ps
            if ps then
                local x, y = ps:getPosition()
                -- Use entry.radius or default to 48 if not set
                local effectRadius = entry.radius or 48
                if Utils.isAABBInView(
                        CamManager.camera,
                        x - effectRadius,
                        y - effectRadius,
                        effectRadius * 2,
                        effectRadius * 2
                ) then
                    love.graphics.draw(ps) -- context-based pooling
                else
                    Debug.debugPrint(string.format("[CULL] Particle system at (%.1f, %.1f) not drawn.", x, y))
                end
            else
                Debug.debugPrint("[DRAW ERROR] Skipping nil ps in globalParticleSystems", entry)
            end
        end
        love.graphics.setBlendMode("alpha") -- reset to normal

        popupManager:draw()
    CamManager.camera:detach()

    -- Draw damage flash in bottom corners
    if damageFlashTimer > 0 then
        local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
        local radius = 0
        local rectW, rectH = 140, 90
        local alpha = damageFlashTimer / DAMAGE_FLASH_DURATION
        love.graphics.setColor(1, 0.1, 0.1, 0.5 * alpha) -- Red
        love.graphics.rectangle("fill", 0, screenH - rectH, rectW, rectH, radius, radius)
        love.graphics.setColor(1, 0.1, 0.1, 0.5 * alpha) -- Red
        love.graphics.rectangle("fill", screenW - 140, screenH - rectH, rectW, rectH, radius, radius)
        love.graphics.setColor(1, 1, 1, 1)
    end

     -- Display player score
     -- debate change to an event system or callback function later when enemy dies or check for when the enemy is dead
    if scoreFont then
        love.graphics.setFont(scoreFont)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Set color to white for text
    
    UI.drawEquippedWeaponOne(20, 110, player, 44)
    UI.drawShardCounter(80, 110)
    if self.waveManager then
        UI.drawWaveCounter(self.waveManager.currentWave, #self.waveManager.waves, love.graphics.getWidth() / 2, 20)
        UI.drawWaveTimer(self.waveManager.waveTimeLeft or 0, love.graphics.getWidth() / 2, 50)
    end
    -- love.graphics.print("Health: " .. player.health, 20, 80)
    UI.drawPlayerHealthBar(20, 20, 24, player, love.timer.getDelta())

    -- local xpNext = player:getXPToNextLevelUp()
    --love.graphics.print("XP: " .. player.experience .. " / " .. xpNext, 20, 140)
    UI.drawPlayerXPBar(20, 50, 24, player, love.timer.getDelta())
    love.graphics.print("Level: " .. player.level or 1, 20, 80)

    --local percent = math.floor((player.experience / xpNext) * 100)
    --love.graphics.print("Level Progress: " .. percent .. "%", 20, 170)
    love.graphics.print("Score: " .. Utils.getScore(), 20, 160)
    
    -- love.graphics.print("Equipped Slot: " .. (player.equippedSlot or "None"), 20, 170)

    if player.weapon then -- this may no longer be necessary 8/17/25
    -- if player.canPickUpItem then
    --     love.graphics.print("Pickup Weapon type: " .. tostring(player.canPickUpItem.weaponType), 20, 490)
    -- end
        love.graphics.print("Range: " .. player.weapon.range, 20, 400)
        love.graphics.print("Equipped Weapon type: " .. player.weapon.weaponType, 20, 430)
        love.graphics.print("Rarity: " .. player.weapon.rarity, 20, 460)
        love.graphics.print("Knockback: " .. player.weapon.knockback, 20, 490)
        love.graphics.print("Weapon: " .. player.weapon.name, 20, 520)
        love.graphics.print("Speed: " .. player.weapon.speed, 20, 550)
        love.graphics.print("Fire rate: " .. player.weapon.fireRate, 20, 580)
        love.graphics.print("Damage: " .. player.weapon.damage, 20, 610)
        love.graphics.print("Cooldown: " .. string.format("%.2f", player.weapon.cooldown.time), 20, 640)
        love.graphics.print("Weapon level: " .. tostring(player.weapon.level or 1), 20, 670)
    end

    love.graphics.print("FPS: " .. love.timer.getFPS(), 1100, 20)
    love.graphics.print("Memory (KB): " .. math.floor(collectgarbage("count")), 20, 700)
    love.graphics.print("ROOM " .. tostring(LevelManager.currentLevel - 1), 1100, 700)

    -- weapon comparison draw logic
    if selectedItemToCompare and selectedItemToCompare.type == "weapon" then
        -- weapon instance for comparison
        local candidateWeapon = Weapon:new(
        selectedItemToCompare.name,
        selectedItemToCompare.image,
        selectedItemToCompare.weaponType,
        selectedItemToCompare.rarity,
        selectedItemToCompare.baseSpeed,
        selectedItemToCompare.baseFireRate,
        selectedItemToCompare.projectileClass,
        selectedItemToCompare.baseDamage,
        selectedItemToCompare.projectileImage,
        selectedItemToCompare.knockback,
        selectedItemToCompare.baseRange,
        selectedItemToCompare.level,
        selectedItemToCompare.id
    )

    UI.drawWeaponComparison(player.weapon, candidateWeapon, recycleProgress)
    end

    if self.stateContext.fading and self.stateContext.fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, self.stateContext.fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return playing