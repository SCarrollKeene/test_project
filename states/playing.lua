local Gamestate = require("libraries/hump/gamestate")
local LevelManager = require("levelmanager")
local MapLoader = require("maploader")
local WaveManager = require("wavemanager")
local player = require("player")
local projectiles = require("projectile_store")
local UI = require("ui")
local Weapon = require("weapon")
local Projectile = require("projectile")
local Debug = require("game_debug")
local Utils = require("utils")
local CamManager = require("cam_manager")
local data_store = require("data_store")

local playing = {}

function playing:keypressed(key)
    if key == "p" then
        Gamestate.push(pause_menu)
    end
end

function playing:enter(previous_state, world, enemyImageCache, mapCache, randomBlobs)
    Debug.debugPrint("[PLAYING:ENTER] Entered playing gamestate")

    -- clear dropped items
    droppedItems = {}

    self.previous_state = previous_state
    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache
    self.randomBlobs = randomBlobs
    
    -- may need this when I revisit refactoring the spatial grid to
    -- scale based off of map dimensions, leave commented out for now 7/4/25
    -- wallColliders = {}
    -- for _, wall in ipairs(currentWalls) do
    --     table.insert(wallColliders, wall)
    -- end

    -- always load map for current combat level
    local level = LevelManager.levels[LevelManager.currentLevel]
    currentMap = mapCache["maps/" .. level.map .. ".lua"]
    currentWalls = currentMap.layers['Walls'].objects
    
    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    CamManager.setMap(mapW, mapH)
    CamManager.camera:attach()

    -- >> SPATIAL PARTIONING GRID START 7/1/25 <<

    -- TODO: revisit making spatial grid scale based on the map width and height
    -- right now its not clearing colliders correctly between :enter and :leave states
    -- reverted back to using hard coded dimensions for the time being 7/4/25
    self.gridCellSize = 425 -- Each cell is 200x200 pixels, tweak for performance.
    self.gridWidth = math.ceil(1280 / self.gridCellSize) -- Grid dimensions for your map
    self.gridHeight = math.ceil(768 / self.gridCellSize)
    self.spatialGrid = {} -- This will hold all the enemies, sorted into cells.
    
    -- Pre-populate the grid with empty tables to avoid errors
    for x = 1, self.gridWidth do
        self.spatialGrid[x] = {}
        for y = 1, self.gridHeight do
            self.spatialGrid[x][y] = {}
        end
    end

    -- >> SPATIAL PARTIONING GRID END 7/1/25 <<

    LevelManager:loadLevel(LevelManager.currentLevel, enemyImageCache)

     -- Initialize wave manager
    local levelData = LevelManager.levels[LevelManager.currentLevel]
    self.waveManager = WaveManager.new(levelData)

    self.projectileBatch = love.graphics.newSpriteBatch(Projectile.image, 1000)  -- 1000 = initial capacity

     -- Initialize enemy batches for current enemy file
    self.enemyBatches = {}
    
    for _, blob in ipairs(randomBlobs) do
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
end

function playing:leave()
    -- stop music, clear temp tables/objects, destroy portals, etc
    Debug.debugPrint("[PLAYING:LEAVE] playing leave called")

    Debug.debugPrint("Walls before cleanup:", #wallColliders)
    for _, collider in ipairs(wallColliders) do
        if not collider:isDestroyed() then
        collider:destroy()
        end
    end
    wallColliders = {}
    Debug.debugPrint("Walls after cleanup:", #wallColliders)

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
    data_store.runData.playerLevel = player.level
    data_store.runData.playerExperience = player.experience
    data_store.runData.playerBaseDamage = player.baseDamage
    data_store.runData.playerSpeed = player.speed

    -- save game after clearing initial room
    SaveSystem.saveGame()
end

function playing:update(dt)
    Debug.debugPrint("playing:update")
    -- frame count
    local frameCount = self.frameCount
    self.frameCount = (self.frameCount or 0) + 1
    
    -- After player:update(dt, mapW, mapH) or player:update(dt)
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    -- local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    CamManager.setMap(mapW, mapH) -- Set map boundaries for the camera
    CamManager.camera:attach() -- Attach the camera to the LOVE2D graphics system

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

    if fading then
        -- SUPPOSED to clear particles when starting fade out
        if fadeDirection == 1 and nextState == playing then
            globalParticleSystems = {}
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
        if Gamestate.current() ~= safeRoom and not player.isDead and button == 1 then
            sounds.blip:play() -- play projectile blip on mouse click
        end

        if not player.isDead and love.mouse.isDown(1) then
            Debug.debugPrint("DEBUG: left mouse click detected")
            local mx, my = CamManager.worldCoords(love.mouse.getX(), love.mouse.getY())
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
                local newProjectile = Projectile.getProjectile(world, player.x, player.y, angle, speed, damage, player, player.weapon.knockback, player.weapon.range)

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
            Debug.debugPrint("DEBUG: Removed " .. (e.name or "enemy") .. " from table.")
            -- check if room is cleared and turn room cleared flag to true
            -- if #enemies == 0 and not data_store.runData.cleared then
            --     roomComplete(data_store.runData.currentRoom)
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
            LevelManager:spawnRandomInZone(self.enemyImageCache, enemyTypes)
        end)
        
        -- Wave completion check
        if self.waveManager and self.waveManager.isFinished and not data_store.runData.cleared and not self.shardPopupDelay then
            Utils.clearAllEnemies()
            Utils.collectAllShards(data_store.metaData, player)
            self.shardPopupDelay = 0.7
            --roomComplete()
        end

        if self.shardPopupDelay then
            self.shardPopupDelay = self.shardPopupDelay - dt
            if self.shardPopupDelay <= 0 then
                roomComplete()
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
    local camX, camY = CamManager.position()
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

    CamManager.attach()   
        if not player.isDead then
            player:draw()
        end

        -- draw and cull droppable loot/items
        for _, item in ipairs(droppedItems) do
            if Utils.isAABBInView(
                CamManager,
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
                CamManager,
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

        -- draw projectiles using sprite batch for performance

        -- Projectile batching
        self.projectileBatch:clear()
        for _, p in ipairs(projectiles) do
                -- Verify position is numeric
                if type(p.x) == "number" and type(p.y) == "number" then
                -- For a circular projectile, use radius; for sprite, use width/height
                local projW = p.width  or (p.radius and p.radius * 2) or 10
                local projH = p.height or (p.radius and p.radius * 2) or 10

                local left = p.x - projW/2
                local top  = p.y - projH/2

                if Utils.isAABBInView(CamManager, left, top, projW, projH) then
                    self.projectileBatch:add(p.x, p.y, 0, 1, 1, p.width/2, p.height/2)
                    -- Debug.debugPrint("Projectile batched at position:", p.x, p.y)
                else
                    -- Debug.debugPrint("Projectile culled at position:", p.x, p.y)
                end
            else
                -- Debug.debugPrint("[WARN] Invalid projectile position", p.x, p.y)
            end
        end
        love.graphics.draw(self.projectileBatch)
        -- Debug.debugPrint("Total projectiles in batch:", self.projectileBatch:getCount())

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
        
        Debug.draw(projectiles, enemies, globalParticleSystems, self.projectileBatch, Projectile.getPoolSize)
        Debug.drawEnemyTracking(enemies, player)
        Debug.drawCollisions(world)
        Debug.drawColliders(wallColliders, player, portal)
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

        popupManager:draw()
    CamManager.camera.detach()

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
    
    UI.drawEquippedWeaponOne(20, 20, player, 44)
    UI.drawShardCounter(80, 20)
    if self.waveManager then
        UI.drawWaveCounter(self.waveManager.currentWave, #self.waveManager.waves, love.graphics.getWidth() / 2, 20)
        UI.drawWaveTimer(self.waveManager.waveTimeLeft or 0, love.graphics.getWidth() / 2, 50)
    end
    love.graphics.print("Health: " .. player.health, 20, 80)
    love.graphics.print("Level: " .. player.level or 1, 20, 110)

    local xpNext = player:getXPToNextLevelUp()
    love.graphics.print("XP: " .. player.experience .. " / " .. xpNext, 20, 140)

    local percent = math.floor((player.experience / xpNext) * 100)
    love.graphics.print("Level Progress: " .. percent .. "%", 20, 170)
    love.graphics.print("Score: " .. playerScore, 20, 200)
    
    -- love.graphics.print("Equipped Slot: " .. (player.equippedSlot or "None"), 20, 170)

    if player.weapon then
    if player.canPickUpItem then
        love.graphics.print("Pickup Weapon type: " .. tostring(player.canPickUpItem.weaponType), 20, 490)
    end
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
        selectedItemToCompare.knockback,
        selectedItemToCompare.baseRange,
        selectedItemToCompare.level,
        selectedItemToCompare.id
    )

    UI.drawWeaponComparison(player.weapon, candidateWeapon, recycleProgress)
    end
end

return playing