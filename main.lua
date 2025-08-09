local player = require("player")
local PlayerRespawn = require("playerrespawn")
local Enemy = require("enemy")
local projectiles = require("projectile_store")
local Loot = require("loot")
local Portal = require("portal")
local Particle = require("particle")
local Blob = require("blob")
local Walls = require("walls")
local MapLoader = require("maploader")
local LevelManager = require("levelmanager")
local WaveManager = require("wavemanager")
local Loading = require("loading")
local Assets = require("assets")
local PopupManager = require("popupmanager")
local UI = require("ui")
local sti = require("libraries/sti")
local Weapon = require("weapon")
local Cooldown = require("cooldown")
local Projectile = require("projectile")
local wf = require("libraries/windfield")
local Gamestate = require("libraries/hump/gamestate")
local playing = require("states/playing")
local safeRoom = require("states/safeRoom")
local pause_menu = require("states/pause_menu")
local Camera = require("libraries/hump/camera")
local Moonshine = require("libraries.moonshine")
local CamManager = require("cam_manager")
local Utils = require("utils")
local data_store = require("data_store")
local SaveSystem = require("save_game_data")
local Debug = require("game_debug")

-- virtual resolution
local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 768

local gameCanvas -- off-screen drawing surface
local scaleX, scaleY, offsetX, offsetY -- variables for scaling and positioning

popupManager = PopupManager:new() 

-- optional, preloader for particle images. I think the safeloading in particle.lua should be good for now
-- Particle.preloadImages()

-- for testing purposes, loading the safe room map after entering portal
local saferoomMap

-- game state definitions
local gameOver = {}

droppedItems = droppedItem or {} -- global table to manage dropped items, such as weapons
local selectedItemToCompare = nil

local enemies = {} -- enemies table to house all active enemies

-- define enemy types and configurations in configuration table
local randomBlobs = { 
    { name = "Black Blob", spritePath = "sprites/slime_black.png", health = 60, speed = 50, baseDamage = 5, xpAmount = 10 },
    { name = "Blue Blob", spritePath = "sprites/slime_blue.png", health = 120, speed = 70, baseDamage = 10, xpAmount = 15 }, 
    { name = "Violet Blob", spritePath = "sprites/slime_violet.png", health = 180, speed = 90, baseDamage = 15, xpAmount = 25 } 
}

local portal = nil -- set portal to nil initially, won't exist until round is won by player
local playerScore = 0
local scoreFont = 0

globalParticleSystems = {}

local pendingRoomTransition = false
local recycleFocusedItem = nil
local recycleHoldTime = 0
local recycleThreshold = 1.0
local recycleProgress = 0

-- fade variables for room transitions
local fadeAlpha = 0         -- 0 = fully transparent, 1 = fully opaque
local fading = false        -- Is a fade in progress?
local fadeDirection = 1     -- 1 = fade in (to black), -1 = fade out (to transparent)
local fadeDuration = 0.5    -- Duration of fade in seconds
local fadeHoldDuration = 0.5   -- Length of hold in seconds (adjust as needed)
local fadeHoldTimer = 0
local fadeTimer = 0
local nextState = nil       -- The state to switch to after fade

-- take damage on screen variables
local damageFlashTimer = 0
local DAMAGE_FLASH_DURATION = 0.3 -- 0.3 seconds

function triggerDamageFlash()
    damageFlashTimer = DAMAGE_FLASH_DURATION
end

-- move into its own file later on, possibly
function incrementPlayerScore(points)
    if type(points) == "number" then
        playerScore = playerScore + points
        Debug.debugPrint("SCORE: Player score increased by", points, ". New score:", playerScore)
    else
        Debug.debugPrint("ERROR: Invalid points value passed to incrementPlayerScore:", points)
    end
end
_G.incrementPlayerScore = incrementPlayerScore -- Make it accessible globally for Utils.lua

-- Debug to test table loading and enemy functions for taking damage, dying and score increment
function love.keypressed(key)
    if key == "r" and player.isDead then
        PlayerRespawn.respawnPlayer(player, world, data_store.metaData, playerScore) -- encapsulate data_store.metaData and player score to main.lua only
        return -- prevent other keys from utilizing r
    end

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

    if key == "space" and not player.isDead then
        player:dash()
    end

    if key == "escape" then
        love.event.quit()
    end

    -- enable debug mode
    Debug.keypressed(key)

    if key == "f" then
        spawnRandomEnemy()
    end

    -- debugs

    -- Particle debug toggle
    if key == "p" then
        Debug.traceParticles = not Debug.traceParticles
        Debug.debugPrint("[PARTICLE TRACE]: ", Debug.traceParticles and "ON" or "OFF")
    end

    if key == "f1" then  -- Stress test
        for i=1, 100 do
            spawnRandomEnemy(love.math.random(100, 700), love.math.random(100, 500))
        end
        player.weapon.fireRate = 0.01  -- Rapid fire
    end

    if key == "f5" then
        Debug.showWalls = not Debug.showWalls
    end

    if Gamestate.current() == safeRoom then
        return -- Prevent any attack actions in safe room
    end
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
                elseif item.type == "weapon" then
                    player.canPickUpItem = item
                    selectedItemToCompare = item
                end
            end
        end
    end
end

function spawnRandomEnemy(x, y, cache, enemyTypes)
    Debug.debugPrint("[FROM SPAWNRANDOMENEMY POOL] Total enemies:", #enemyPool) -- debug preloaded pool status
    local state = Gamestate.current()

    -- 6/20/25 no spawning in safe rooms!
    if state == safeRoom then return end

    local enemyCache = cache or (state and state.enemyImageCache) or {} -- Use the current state's enemy image cache, not global

    -- Pick a random enemy type from the randomBlobs configuration table
    local randomIndex = math.random(1, #randomBlobs) -- picks a random index between 1-3
    local randomBlob = randomBlobs[randomIndex] -- returns a random blob from the table

    -- Filter based on enemyTypes if provided
    local availableBlobs = {}
    if enemyTypes  and #enemyTypes > 0 then
        -- create a filtered list of available blobs based on enemyTypes
        for _, blob in ipairs(randomBlobs) do
            for _, allowedType in ipairs(enemyTypes) do
                if blob.name == allowedType then
                    table.insert(availableBlobs, blob)
                    break -- Exit inner loop if match found
                end
            end
        end
    else
        -- If no specific types provided, use all available blobs
        availableBlobs = randomBlobs
    end

    -- fall back to all types if filtered list is empty
    if #availableBlobs == 0 then
        Debug.debugPrint("[SPAWNRANDOMENEMY] No valid enemy types to spawn, using all random blobs.")
        availableBlobs = randomBlobs -- Use all blobs if none match the filter
    end

    -- select random enemy from filtered list
    local randomBlobIndex = love.math.random(1, #availableBlobs) -- Pick a random blob type from available blobs
    local randomBlob = availableBlobs[randomBlobIndex] -- Get a random blob configuration

    -- Check if the image is already cached
    local img = enemyCache[randomBlob.spritePath]
     if not img then
        Debug.debugPrint("MISSING IMAGE FOR: ", randomBlob.name, "at path:", randomBlob.spritePath)
        return -- Exit if image is missing
    end

    -- BEGIN POOL logic
    -- Try to reuse from pool
    for i, e in ipairs(enemyPool) do
        if e.isDead then
            e:reset(x or love.math.random(32, love.graphics.getWidth() - 32),
                    y or love.math.random(32, love.graphics.getHeight() - 32),
                    randomBlob, img)
            e:setTarget(player)
            e.isDead = false
            e.toBeRemoved = false
            table.insert(enemies, e)
            Debug.debugPrint("[POOL REUSE] Reactivating as:", randomBlob.name)
            return
        end
    end
    -- END POOL LOGIC

    -- Get random position within screen bounds
    -- minimum width and height from enemy to be used in calculating random x/y spawn points
    local enemy_width, enemy_height = 32, 32  -- Default, or use actual frame size
    local spawnX = x or love.math.random(enemy_width, love.graphics.getWidth() or 800 - enemy_width)
    local spawnY = y or love.math.random(enemy_height, love.graphics.getHeight()or 600 - enemy_height)

    -- IF no pool THEN create new enemy instance
    -- Create the enemy instance utilizing the randomBlob variable to change certain enemy variables like speed, health, etc
    local newEnemy = Enemy:new(
        world, randomBlob.name, spawnX, spawnY, enemy_width, enemy_height, nil, nil, 
        randomBlob.health, randomBlob.speed, randomBlob.baseDamage, randomBlob.xpAmount, img)

    -- configure new_enemy to target player
    newEnemy:setTarget(player)

    -- add newEnemy into enemies table
    table.insert(enemies, newEnemy)
    -- add newly created enemies into the pool as well
    table.insert(enemyPool, newEnemy)

    newEnemy.spriteIndex = randomIndex -- Store sprite index for rendering
    Debug.debugPrint("[NEW ENEMY from Spawn Random Enemy] Created:", randomBlob.name)

    -- debug
    Debug.debugPrint(string.format("[SPAWN] Spawned at: %s at x=%.1f, y=%.1f", randomBlob.name, spawnX, spawnY))

    -- if wave.boss then
    --     spawnBossEnemy()
    --     return
    -- end
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
    Debug.debugPrint("A portal has spawned! Traverse to " ..data_store.runData.currentRoom.. " room.")
end

function roomComplete()
    data_store.runData.cleared = true
    pendingPortalSpawn = true
    spawnPortal() -- TODO: maybe, revisit later 6/20/25
    Debug.debugPrint("Room " ..data_store.runData.currentRoom.. " completed!")
end

function love.load()
    -- Initialize the game canvas with virtual resolution
    gameCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- Set default filter for crisp pixel art scaling (optional, but good for pixel games)
    -- love.graphics.setDefaultFilter("nearest", "nearest")

    -- Call initial game setup
    love.window.setMode(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, { resizable = true, fullscreen = false, vsync = true }) -- Ensure window is resizable
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    world = wf.newWorld(0, 0)
    -- initialize first
    wallColliders = {}
    enemyPool = {} -- initialize enemy pool

    -- load player save data
    -- TODO: implement save game and load game logic later on 6/20/25
    -- local save = SaveSystem.loadGame()
    -- if save then
    --     data_store.runData = save.run
    --     data_store.metaData = save.meta
    -- else
    --     data_store.runData = createNewRun()
    --     data_store.metaData = loadDefaultMeta()
    -- end

    -- collision classes must load into the world first, per order of operations/how content is loaded, I believe
    world:addCollisionClass('player', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'player')
    -- stops enemies from colliding/getting stuck on one another
    world:addCollisionClass('enemy', {ignores = {'enemy'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'enemy')
    -- ignore enemy/enemy collider when dashing
    world:addCollisionClass('player_dashing', {ignores = {'enemy'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'player_dashing')
    world:addCollisionClass('projectile', {ignores = {'projectile'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'projectile')
    world:addCollisionClass('wall', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'wall')
    world:addCollisionClass('portal', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'portal')
    -- You can also define interactions here

    local mage_spritesheet_path = "sprites/mage-NESW.png"
    local dash_spritesheet_path = "sprites/dash.png"
    local death_spritesheet_path = "sprites/soulsplode.png"
    Projectile.loadAssets()
    Weapon.loadAssets()
    Assets.load()
    player:load(world, mage_spritesheet_path, dash_spritesheet_path, death_spritesheet_path)
    local testImage = love.graphics.newImage("sprites/circle-particle.png")
    Debug.debugPrint("Test image loaded:", testImage)

    -- In love.load(), after first load:
    player.mage_spritesheet_path = mage_spritesheet_path
    player.dash_spritesheet_path = dash_spritesheet_path
    player.death_spritesheet_path = death_spritesheet_path

    function beginContact(a, b, coll)
        local dataA = a:getUserData() -- both Should be the projectile/enemy data
        local dataB = b:getUserData() -- based on the collision check if statement below
        local projectile, enemy, wall, player

        -- make function local to prevent overwriting similar outer variables
        local function handlePlayerCollisionEvents(a, b)
            -- Add defensive NIL checks
            -- made collision handler resilient to incomplete (user) collision data
            if not a or not b or not a.type or not b.type then
                return
            end
            local player, enemy
            -- Check for Player/Enemy collision
            if (a.type == "player" and b.type == "enemy") then
                player, enemy = a, b 
            elseif (b.type == "player" and a.type == "enemy") then
                player, enemy = b, a
            else
                return -- exit if not player/enemy collision
            end
    
            Debug.debugPrint(string.format("COLLISION: %s vs %s", a.type, b.type))

            -- Handle Player-Enemy interactions
            if player and not player.isDead then
                if not player.isInvincible then
                    player:takeDamage(enemy.baseDamage, playerScore)
                end
            end
        end

        -- Player-Portal collision
        local player_obj, portal_obj
        if dataA and dataA.type == "player" and dataB and dataB.type == "portal" then
            player_obj, portal_obj = dataA, dataB
        elseif dataB and dataB.type == "player" and dataA and dataA.type == "portal" then
            player_obj, portal_obj = dataB, dataA
        end
        
        if player_obj and portal_obj then
            if portal and portal.cooldownActive then
                sounds.ghost:play() -- portal
                if Gamestate.current() == playing then
                    nextState = safeRoom
                    nextStateParams = {world, enemyImageCache, mapCache} -- pass saferooms cache, may rename this enemyImageCache variable later on
                elseif Gamestate.current() == safeRoom then
                    -- LevelManager:loadLevel(LevelManager.currentLevel + 1)
                    LevelManager.currentLevel = LevelManager.currentLevel + 1
                    nextState = Loading -- switch to loading screen before loading next level
                    nextStateParams = {world, playing, randomBlobs} -- randomBlobs = enemy types
                end

                pendingRoomTransition = true
                fading = true
                fadeDirection = 1
                fadeTimer = 0  
                if portal then
                    portal:destroy()
                    portal = nil
                end
            end
        end

        -- execute function
        handlePlayerCollisionEvents(dataA, dataB)

        -- Check for Projectile-Enemy collision
        if dataA and dataA.damage and dataA.owner and dataB and dataB.health and not dataB.damage then -- Heuristic eval: projectile has damage, enemy has health but not damage field
            projectile = dataA
            enemy = dataB
        elseif dataB and dataB.damage and dataB.owner and dataA and dataA.health and not dataA.damage then
            projectile = dataB
            enemy = dataA
        end

        -- Ignore Player-Enemy collision in safe room
        if Gamestate.current() == safeRoom and 
        (a.type == "player" and b.type == "enemy") then
            return -- Ignore damage
        end

        -- Handle Projectile-Enemy collision
        if projectile and enemy and not enemy.isDead then -- Ensure enemy isn't already marked dead
            -- beginContact starts
            -- update when enemy can also launch projectiles 5/30/25
            if projectile and enemy and projectile.owner ~= enemy then
                
                --Debug.debugPrint(string.format("PLAYER-ENEMY COLLISION: Projectile (owner: %s, damage: %.2f) vs Enemy (%s, health: %.2f)",
                -- (projectile.owner and projectile.owner.name) or "Unknown", projectile.damage, enemy.name, enemy.health))
                
                projectile:onHitEnemy(enemy) -- Projectile handles its collision consequence
                -- enemy:takeDamage(projectile.damage) -- Enemy's own method is called
            end

            -- Projectile cleanup/removal logic (destroy collider, flag for removal)
            -- subject to removal as this is being handled by enemy's die() function logic
            -- I like the way this handles collider removal, its removed immediately upon contact 5/30/25
            -- if projectile.collider then
            --     projectile.collider:destroy() -- Destroy projectile collider
            --     projectile.collider = nil
            -- end
            -- projectile.toBeRemoved = true -- Flag projectile for removal from table
        end

        -- Check for Projectile-Wall collision
        if (dataA and dataA.type == "wall" and dataB and dataB.type == "projectile") then
            -- impact projectile effect
            local particleImpact = Particle.getOnImpactEffect()
            if particleImpact then
                particleImpact:setPosition(dataB.x, dataB.y)
                particleImpact:emit(8)
                -- table.insert(globalParticleSystems, particleImpact)
                table.insert(globalParticleSystems, { ps = particleImpact, type = "impactEffect", radius = 32 } ) -- Context-based pooling
            end
            dataB:destroySelf() -- destroy projectile on wall collision
        elseif (dataB and dataB.type == "wall" and dataA and dataA.type == "projectile") then
            -- impact projectile effect
            local particleImpact = Particle.getOnImpactEffect()
            if particleImpact then
                particleImpact:setPosition(dataA.x, dataA.y)
                particleImpact:emit(8)
                -- table.insert(globalParticleSystems, particleImpact)
                table.insert(globalParticleSystems, { ps = particleImpact, type = "impactEffect", radius = 32 } ) -- Context-based pooling
            end
            dataA:destroySelf() -- destroy projectile on wall collision
            -- One is wall, one is projectile
            -- local projectile = dataA.type and dataA or dataB
             -- projectile:destroySelf()  -- destroy projectile on wall collision
            -- dataB:deactivate() -- deactivate projectile
            -- projectile:destroySelf() -- destroy projectile
        end

        -- Destroy projectile collider and remove from table
        -- projectile.toBeRemoved = true -- flag for removal from the projectiles table
        -- if projectile.collider then 
        --     projectile.collider:destroy() 
        --     projectile.collider = nil -- set projectile collider to nil after projectile is destroyed because its no longer active
        -- end
    end

    world:setCallbacks(beginContact, nil, nil, nil) -- We only need beginContact for this

    -- declare for enemy pool use
    local enemyImageCache = enemyImageCache or {} -- Use the provided cache or an empty table

    -- Preload all enemy images
    for _, blob in ipairs(randomBlobs) do
        if not enemyImageCache[blob.spritePath] then
            enemyImageCache[blob.spritePath] = love.graphics.newImage(blob.spritePath)
        end
    end

    -- Preload 200 enemies into enemy pool
    for i = 1, 200 do
        local randomIndex = math.random(1, #randomBlobs) -- Pick a random blob type
        local randomBlob = randomBlobs[randomIndex] -- Get a random blob configuration
        local img = enemyImageCache[randomBlob.spritePath]
        local e = Enemy:new(world, randomBlob.name, 0, 0, 32, 32, nil, nil, randomBlob.health, randomBlob.speed, randomBlob.baseDamage, 0, img)
        e.isDead = true -- Mark as reusable
        table.insert(enemyPool, e)
    end
    
    -- Preload 100 projectiles into the correct pool
    -- for i = 1, 100 do
    --     local proj = Projectile:new(world, 0, 0, 0, 0, 0, nil)
    --     proj.active = true -- make preloaded projectiles active
    --     proj.collider:setActive(false)
    -- table.insert(Projectile.pool, proj)
    -- end

    -- sounds = {}
    -- sounds.music = love.audio.newSource("sounds/trance_battle_bpm140.mp3", "stream")
    -- sounds.music:setLooping(true)
    -- sounds.music:play()

    scoreFont = love.graphics.newFont(20)

    -- TODO: register gamestate events and start game in playing state
    -- Gamestate.registerEvents({
    --     leave = function()
    --         globalParticleSystems = {}
    --     end
    -- })
    Gamestate.registerEvents()
    Gamestate.switch(Loading, world, playing, randomBlobs, projectiles)

    -- Call love.resize to set up initial scaling
    love.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.resize(w, h)
    -- called when the window is resized
    local aspectRatio = VIRTUAL_WIDTH / VIRTUAL_HEIGHT
    local windowAspectRatio = w / h

    if windowAspectRatio > aspectRatio then
        -- Window is wider than our virtual resolution aspect ratio (pillarboxing)
        scaleY = h / VIRTUAL_HEIGHT
        scaleX = scaleY
        offsetX = (w - VIRTUAL_WIDTH * scaleX) / 2
        offsetY = 0
    else
        -- Window is taller than our virtual resolution aspect ratio (letterboxing)
        scaleX = w / VIRTUAL_WIDTH
        scaleY = scaleX
        offsetX = 0
        offsetY = (h - VIRTUAL_HEIGHT * scaleY) / 2
    end
end

function love.update(dt)
    -- moved all logic into func playing:update(dt) because I'm utilizing hump.gamestate
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
end



function love.draw()
    -- moved all logic into func playing:draw() because I'm utilizing hump.gamestate

    -- Set the render target to your gameCanvas
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.1, 0.1, 0.1, 1) -- Clear the canvas (e.g., to a dark grey)

    -- Reset the render target to the screen
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1) -- Clear the actual screen to black (for letter/pillarboxing)

    -- Draw the gameCanvas to the actual screen, scaled and offset
    love.graphics.draw(gameCanvas, offsetX, offsetY, 0, scaleX, scaleY)
end

-- TODO: make ESC key global for quiting no matter what game state they are in
function love.quit()
    -- save game on quit
    SaveSystem.saveGame()
end