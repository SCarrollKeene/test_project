local Gamestate = require("libraries/hump/gamestate")
local LevelManager = require("levelmanager")
local MapLoader = require("maploader")
local player = require("player")
local projectiles = require("projectile_store")
local UI = require("ui")
local Weapon = require("weapon")
local Projectile = require("projectile")
local Debug = require("game_debug")
local Utils = require("utils")
local CamManager = require("cam_manager")
local data_store = require("data_store")

local safeRoom = {}

function safeRoom:keypressed(key)
    if key == "p" then
        Gamestate.push(pause_menu)
    end
end

function safeRoom:enter(previous_state, world, enemyImageCache, mapCache)
    Debug.debugPrint("[SAFEROOM:ENTER] entered saferoom gamestate")

    -- clear dropped items
    droppedItems = {}

    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache
    self.currentMap = currentMap

    -- stop projectile sound while in the saferoom
    if sounds and sounds.blip then
        sounds.blip:stop()
    end

    -- passing in its map and walls, which is world, because of colliders
    -- its not a combat level so this is how safe rooms and other rooms will handle
    -- being loaded 6/22/25
    currentMap = mapCache["maps/saferoommap.lua"]
    currentWalls = currentMap.layers['Walls'].objects

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    CamManager.setMap(mapW, mapH)
    CamManager.camera:attach()

    for _, wall in ipairs(currentWalls) do
        table.insert(wallColliders, wall)
    end

    -- restore player stats and inventory
    player.inventory = Utils.deepCopy(data_store.runData.inventory)
    player.equippedSlot = data_store.runData.equippedSlot
    player.health = data_store.runData.playerHealth or 100
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

    if portal then
        portal:destroy()  -- This should destroy both the collider and the object
        portal = nil
    end

    -- portal to next room/level
    if not portal then
        --portal = Portal:new(world, love.graphics.getWidth()/2, love.graphics.getHeight()/2)
        portal = Portal:new(world, mapW / 2, mapH / 2)
        Debug.debugPrint("[SAFEROOM portal] created at", portal.x, portal.y)
    end

    -- prepare to load next level
    LevelManager.currentLevel = LevelManager.currentLevel

end

function safeRoom:leave()
    Debug.debugPrint("[SAFEROOM:LEAVE] saferoom leave called")
    -- stop music, clear temp tables/objects, destroy portals, etc
     -- Add wall cleanup:
    for _, collider in ipairs(wallColliders) do
        if not collider:isDestroyed() then
        collider:destroy()
        end
    end
    wallColliders = {}

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
    data_store.runData.playerLevel = player.level
    data_store.runData.playerExperience = player.experience
    data_store.runData.playerBaseDamage = player.baseDamage
    data_store.runData.playerSpeed = player.speed

    -- save game after clearing initial room
    SaveSystem.saveGame()
end

function safeRoom:update(dt)
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

    if fading then
        -- SUPPOSED to clear particles when starting fade out
        -- globalParticleSystems = {}
        if fadeDirection == 1 and nextState == playing then
        end

        if fadeDirection == 1 then
            -- Fade out (to black)
            fadeTimer = fadeTimer + dt
            fadeAlpha = math.min(fadeTimer / fadeDuration, 1)
            if fadeAlpha >= 1 then
                -- Fade out complete, start hold
                fadeHoldTimer = 0
                fadeDirection = 0    -- 0 indicates hold phase
            end
        elseif fadeDirection == 0 then
            -- Hold phase (fully black)
            fadeHoldTimer = fadeHoldTimer + dt
            fadeAlpha = 1
            if fadeHoldTimer >= fadeHoldDuration then
                -- Hold complete, switch state and start fade in
                Gamestate.switch(nextState, unpack(nextStateParams))
                globalParticleSystems = {} -- testing for now
                fadeDirection = -1
                fadeTimer = 0
            end
        elseif fadeDirection == -1 then
            -- Fade in (from black)
            fadeTimer = fadeTimer + dt
            fadeAlpha = 1 - math.min(fadeTimer / fadeDuration, 1)
            if fadeAlpha <= 0 then
                fading = false
                fadeAlpha = 0
            end
        end
        return -- halt other updates during fade
    end

    if pendingRoomTransition then
        fading = true
        fadeDirection = 1
        fadeTimer = 0
        nextState = safeRoom
        pendingRoomTransition = false
        return
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
    local camX, camY = CamManager:position()
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
                    CamManager,
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

    if fading and fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    Debug.draw(projectiles, enemies, globalParticleSystems) -- Draws debug overlay
    Debug.drawCollisions(world)
    Debug.drawColliders(wallColliders, player, portal)

    popupManager:draw()
    CamManager.camera:detach()
    -- Safe room UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(scoreFont)
    
    UI.drawEquippedWeaponOne(20, 20, player, 44)
    UI.drawShardCounter(80, 20)
    love.graphics.print("Health: " .. player.health, 20, 80)
    love.graphics.print("Level: " .. player.level or 1, 20, 110)

    local xpNext = player:getXPToNextLevelUp()
    love.graphics.print("XP: " .. player.experience .. " / " .. xpNext, 20, 140)

    local percent = math.floor((player.experience / xpNext) * 100)
    love.graphics.print("Level Progress: " .. percent .. "%", 20, 170)
    love.graphics.print("Score: " .. playerScore, 20, 200)

    love.graphics.print("FPS: " .. love.timer.getFPS(), 1100, 20)
    love.graphics.print("Memory (KB): " .. math.floor(collectgarbage("count")), 20, 700)
    love.graphics.print("SAFE ROOM", 1100, 700)
end

return safeRoom