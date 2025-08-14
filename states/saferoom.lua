local Collision = require("collision")
local Gamestate = require("libraries/hump/gamestate")
local LevelManager = require("levelmanager")
local MapLoader = require("maploader")
local player = require("player")
local Enemy = require("enemy")
local enemyTypes = require("enemytypes")
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

local safeRoom = {}

popupManager = PopupManager:new()

droppedItems = droppedItem or {} -- global table to manage dropped items, such as weapons
local selectedItemToCompare = nil

local portal = nil -- set portal to nil initially, won't exist until round is won by player

local pendingRoomTransition = false
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
function spawnWeaponDrop(name, image, weaponType, rarity, baseSpeed, fireRate, projectileClass, baseDamage, knockback, baseRange, x, y, level, id, type)
  local weaponDrop = {
    name = name,
    image = image,
    weaponType = weaponType,
    rarity = rarity,
    baseSpeed = baseSpeed,
    fireRate = fireRate,
    projectileClass = projectileClass,
    baseDamage = baseDamage,
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
                        if popupManager and player then
                            popupManager:add("+" .. healing .. " HP!", player.x, player.y - 34, {0,1,0,1}, 1.1, -25, 0)
                        end
                        Loot.removeDroppedItem(item)
                        SaveSystem.saveGame()
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

-- based on [Player collider] recreated at map coords:
function spawnPortal()
    -- local portalX = love.graphics.getWidth() / 2
    local mapW = currentMap.width * currentMap.tilewidth
    -- local portalY = love.graphics.getHeight() / 2
    local mapH = currentMap.height * currentMap.tileheight
    local portalX = mapW / 2
    local portalY = mapH / 2
    portal = Portal:new(world, portalX, portalY)
    self.stateContext.portal = portal
end

function safeRoom:roomComplete()
    data_store.runData.cleared = true
    pendingPortalSpawn = true
    spawnPortal() -- TODO: maybe, revisit later 6/20/25
    Debug.debugPrint("Room " ..data_store.runData.currentRoom.. " completed!")
end

function safeRoom:keypressed(key)
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

    if Gamestate.current() == safeRoom then
        return -- Prevent any attack actions in safe room
    end
end

function safeRoom:enter(previous_state, world, enemyPool, enemyImageCache, mapCache, playingState)
    Debug.debugPrint("[SAFEROOM:ENTER] entered saferoom gamestate")
    print("[DEBUG] safeRoom:enter, playingState is", tostring(playingState))

    -- stateless, clean approach without needing g variables
    local stateContext = {}

    self.world = world
    self.enemyPool = enemyPool
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache
    self.currentMap = currentMap

    -- build the context table for collision.lua
    self.stateContext = {
        portal = portal,
        enemyPool = enemyPool,
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

        playingState = playingState,
        safeRoomState = self,

        incrementPlayerScore = incrementPlayerScore
    }

    -- set callbaks for collision detection
    -- world:setCallbacks(Collision.beginContact, nil, nil, nil)
    world:setCallbacks(function(a, b, coll)
        Collision.beginContact(a, b, coll, self.stateContext)
    end)

    -- clear dropped items
    droppedItems = {}

    -- stop projectile sound while in the saferoom
    if sounds and sounds.blip then
        sounds.blip:stop()
    end

    -- Destroy old physics colliders
    for _, collider in ipairs(wallColliders) do
        if collider.destroy and not collider:isDestroyed() then
            collider:destroy()
        end
    end

    -- Clear/reset old wall colliders table
    wallColliders = {}
    currentWalls = {}

    -- passing in its map and walls, which is world, because of colliders
    -- its not a combat level so this is how safe rooms and other rooms will handle
    -- being loaded 6/22/25

    local cachedMap = self.mapCache["maps/saferoommap.lua"]

    -- Defensive check for bad cache load
    if not cachedMap or not cachedMap.map then
        error("[CRITICAL] saferoom Map missing in cache")
    end
    if not cachedMap.wallData then
        error("[CRITICAL] saferoom Walls missing in cache")
    end

    currentMap = cachedMap.map
    currentWalls = MapLoader.instantiateWalls(world, cachedMap.wallData)

    -- Populate wall colliders from the newly loaded/current walls
    for _, wall in ipairs(currentWalls) do
        table.insert(wallColliders, wall)
    end

    for i, wall in ipairs(wallColliders) do
        if wall.getBoundingBox then
            local x, y, w, h = wall:getBoundingBox()
            print(string.format(" wall %d: x=%.1f y=%.1f w=%.1f h=%.1f", i, x, y, w, h))
        end
    end

    if not currentMap.width or not currentMap.tilewidth then
        error("[CRITICAL] SafeRoom map dimensions missing!")
    end

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

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight

    -- print("[DEBUG] currentMap:", currentMap, 
    --   "width:", currentMap and currentMap.width, 
    --   "tilewidth:", currentMap and currentMap.tilewidth)

    CamManager.setMap(mapW, mapH)
    --CamManager.camera:attach()

    -- restore player stats and inventory
    player.inventory = Utils.deepCopy(data_store.runData.inventory)
    player.equippedSlot = data_store.runData.equippedSlot
    player.health = (data_store.runData and data_store.runData.playerHealth) or 100
    player.maxHealth = (data_store.runData and data_store.runData.playerMaxHealth)  or 100
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
    -- player.x = 140
    -- player.y = love.graphics.getHeight() / 3
    -- Debug.debugPrint("[Player collider] recreated at:", player.x, player.y)

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    CamManager.setMap(mapW, mapH)
    -- CamManager.camera:attach()

    -- map coords
    player.x = mapW / 4
    player.y = mapH / 3

    if player.collider then
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    -- firefly funhouse lol, just particles
    for i = 1, 20 do
        local x = love.math.random(mapW * 0.2, mapW * 0.8) -- position x
        local y = love.math.random(mapH * 0.2, mapH * 0.8) -- position y
        Particle.spawnFirefly(x, y)
    end

    -- Recreate collider if missing
    -- if not player.collider then
    --     player:load(world)  
    -- end

    -- create store/shop logic

    -- add some NPC

    -- a way for the player to heal

    -- destroy any remaining active projectiles on level load in list
    for i = #projectiles, 1, -1 do
        projectiles[i]:destroySelf()
        table.remove(projectiles, i)
    end

    -- reset ALL projectiles in the pool, active and inactive
    for i = #Projectile.pool, 1, -1 do
        Projectile.pool[i]:destroySelf()
        table.remove(Projectile.pool, i)
    end

    -- clear projectile particle effect while in saferoom
    -- TODO: Not working as intended, revisit later 8/13/25
    for i = #globalParticleSystems, 1, -1 do
        local entry = globalParticleSystems[i]
        if entry.type == "particleTrail" or entry.type == "impactEffect" then
            table.remove(globalParticleSystems, i)
        end
    end

    if portal then
        portal:destroy()  -- This should destroy both the collider and the object
        portal = nil
    end

    -- portal to next room/level
    if not portal then
        --portal = Portal:new(world, love.graphics.getWidth()/2, love.graphics.getHeight()/2)
        portal = Portal:new(world, mapW / 2, mapH / 2)
        self.stateContext.portal = portal
        self.createPortalAfterFade = true
    end

    -- prepare to load next level
    LevelManager.currentLevel = LevelManager.currentLevel

    -- fading logic test
    self.stateContext.fading = true
    self.stateContext.fadeDirection = -1  -- fade in (from black)
    self.stateContext.fadeTimer = 0
    self.stateContext.fadeAlpha = 1
end

function safeRoom:leave()
    Debug.debugPrint("[SAFEROOM:LEAVE] saferoom leave called")
    -- stop music, clear temp tables/objects, destroy portals, etc
     -- Add wall cleanup:
    print("Walls before cleanup:", #wallColliders, "currentWalls:", #currentWalls)
    for _, collider in ipairs(wallColliders) do
        if not collider:isDestroyed() then
            collider:destroy()
        else
            print("[SAFEROOM:LEAVE] Collider already destroyed:", collider)
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

    -- destroy current remaining portal
    if portal then
        portal:destroy()
        portal = nil
    end

    -- reset flags
    pendingRoomTransition = false
    Debug.debugPrint("Leaving safeRoom state, cleaning up resources.")

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

function safeRoom:update(dt)
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

    if saferoomMap then saferoomMap:update(dt) end
    
    -- CamManager update
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- update player and other entities
    player:update(dt, mapW, mapH)
    --local px, py = player.x, player.y
    CamManager:follow(player.x, player.y)

    -- Clamp the camera so it doesn't scroll past the map edges
    -- local camX = math.max(w/2 / CamManager.scale, math.min(px, mapW - w/2 / CamManager.scale))
    -- local camY = math.max(h/2 / CamManager.scale, math.min(py, mapH - h/2 / CamManager.scale))
    -- CamManager:lookAt(camX, camY)

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
        if not entry.ps then
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

    popupManager:update(dt)

    -- update physics world AFTER all positions are set
    if world then world:update(dt) end

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

    if self.createPortalAfterFade and not self.stateContext.fading then
        portal = Portal:new(world, mapW / 2, mapH / 2)
        self.stateContext.portal = portal
        self.createPortalAfterFade = false
    end

    -- if not player.isDead then
    --     player:update(dt)
    -- end
    if not player.isDead then
        local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
        local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
        player:update(dt, mapW, mapH)
    end

    -- add other safe room specific logic

    -- safe room music

    -- interaction sounds

    if portal then
        portal:update(dt)
    end
end

function safeRoom:draw()
    Debug.debugPrint("safeRoom:draw")

        -- Draw safe room background
        --if currentMap then currentMap:draw() end
        -- love.graphics.setColor(0.2, 0.5, 0.3, 1)
        -- love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

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

        -- Set the background color for the safe room
        -- love.graphics.setColor(0.7, 0.8, 1) -- Cool blue tint
        -- love.graphics.rectangle("fill", 
        --     CamManager.x - love.graphics.getWidth() / 2 / CamManager.scale, 
        --     CamManager.y - love.graphics.getHeight() / 2 / CamManager.scale, 
        --     love.graphics.getWidth() / CamManager.scale, 
        --     love.graphics.getHeight() / CamManager.scale
        -- )
        -- love.graphics.setColor(1, 1, 1, 1)
        
        -- Draw player
        player:draw()

        -- if exists, draw it
        if portal then
            portal:draw()
        end

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

    Debug.draw(projectiles, enemies, globalParticleSystems) -- Draws debug overlay
    Debug.drawCollisions(world)
    Debug.drawColliders(wallColliders, player, portal)
    Debug.drawAllPhysicsFixtures(world)

    popupManager:draw()
    CamManager.camera:detach()
    -- Safe room UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(scoreFont)
    
    UI.drawEquippedWeaponOne(20, 60, player, 44)
    UI.drawShardCounter(80, 60)
    UI.drawPlayerHealthBar(20, 20, 32, player, love.timer.getDelta())
    -- love.graphics.print("Health: " .. player.health, 20, 80)
    love.graphics.print("Level: " .. player.level or 1, 20, 110)

    local xpNext = player:getXPToNextLevelUp()
    love.graphics.print("XP: " .. player.experience .. " / " .. xpNext, 20, 140)

    local percent = math.floor((player.experience / xpNext) * 100)
    love.graphics.print("Level Progress: " .. percent .. "%", 20, 170)
    love.graphics.print("Score: " .. Utils.getScore(), 20, 200)

    love.graphics.print("FPS: " .. love.timer.getFPS(), 1100, 20)
    love.graphics.print("Memory (KB): " .. math.floor(collectgarbage("count")), 20, 700)
    love.graphics.print("SAFE ROOM", 1100, 700)

    if self.stateContext.fading and self.stateContext.fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, self.stateContext.fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return safeRoom