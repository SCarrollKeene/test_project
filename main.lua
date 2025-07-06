local Player = require("player")
local PlayerRespawn = require("playerrespawn")
local Enemy = require("enemy")
local Portal = require("portal")
local Particle = require("particle")
local Blob = require("blob")
local Walls = require("walls")
local MapLoader = require("maploader")
local LevelManager = require("levelmanager")
local WaveManager = require("wavemanager")
local Loading = require("loading")
local sti = require("libraries/sti")
local Projectile = require("projectile")
local wf = require("libraries/windfield")
local Gamestate = require("libraries/hump/gamestate")
local Camera = require("libraries/hump/camera")
-- local camera = require("camera")
local SaveSystem = require("save_game_data")
local Debug = require("game_debug")


local cam = Camera()
cam:zoomTo(1.5)

-- current run data and persistent game data
local runData = {
    currentRoom = 1,
    cleared = false,
    clearedRooms = {},
    playerHealth = 100,
    inventory = {}
}

local metaData = {
    unlockedCharacters = {},
    permanentUpgrades = {},
    highScore = 0
}

-- optional, preloader for particle images. I think the safeloading in particle.lua should be good for now
-- Particle.preloadImages()

-- for testing purposes, loading the safe room map after entering portal
local saferoomMap

-- game state definitions
local playing = {}
local paused = {}
local safeRoom = {}
local gameOver = {}

local projectiles = {}
local player = Player -- create new player instance, change player.lua to a constructor pattern if you want multiple players

-- local enemyPool = {} -- time to attempt enemy pooling

local enemies = {} -- enemies table to house all active enemies

-- define enemy types and configurations in configuration table
local randomBlobs = { 
    { name = "Black Blob", spritePath = "sprites/slime_black.png", health = 60, speed = 50, baseDamage = 5 },
    { name = "Blue Blob", spritePath = "sprites/slime_blue.png", health = 120, speed = 70, baseDamage = 10 }, 
    { name = "Violet Blob", spritePath = "sprites/slime_violet.png", health = 180, speed = 90, baseDamage = 15 } 
}

local portal = nil -- set portal to nil initially, won't exist until round is won by player
local playerScore = 0
local scoreFont = 0

globalParticleSystems = {}

local pendingRoomTransition = false

-- fade variables for room transitions
local fadeAlpha = 0         -- 0 = fully transparent, 1 = fully opaque
local fading = false        -- Is a fade in progress?
local fadeDirection = 1     -- 1 = fade in (to black), -1 = fade out (to transparent)
local fadeDuration = 0.5    -- Duration of fade in seconds
local fadeHoldDuration = 0.5   -- Length of hold in seconds (adjust as needed)
local fadeHoldTimer = 0
local fadeTimer = 0
local nextState = nil       -- The state to switch to after fade

-- move into its own file later on, possibly
function incrementPlayerScore(points)
    if type(points) == "number" then
        playerScore = playerScore + points
        print("SCORE: Player score increased by", points, ". New score:", playerScore)
    else
        print("ERROR: Invalid points value passed to incrementPlayerScore:", points)
    end
end
_G.incrementPlayerScore = incrementPlayerScore -- Make it accessible globally for Utils.lua

-- Debug to test table loading and enemy functions for taking damage, dying and score increment
function love.keypressed(key)
    if key == "r" and player.isDead then
        PlayerRespawn.respawnPlayer(player, world, metaData, playerScore) -- encapsulate metadata and player score to main.lua only
        return -- prevent other keys from utilizing r
    end

    if key == "space" and not player.isDead then
        player:dash()
    end

    if key == "escape" then
        love.event.quit()
    end

    -- enable debug mode
    Debug.keypressed(key)

    if key == "e" then
        spawnRandomEnemy()
    end

    -- debugs

    -- Particle debug toggle
    if key == "p" then
        Debug.traceParticles = not Debug.traceParticles
        print("[PARTICLE TRACE]: ", Debug.traceParticles and "ON" or "OFF")
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

function spawnRandomEnemy(x, y, cache, enemyTypes)
    print("[FROM SPAWNRANDOMENEMY POOL] Total enemies:", #enemyPool) -- debug preloaded pool status
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
        print("[SPAWNRANDOMENEMY] No valid enemy types to spawn, using all random blobs.")
        availableBlobs = randomBlobs -- Use all blobs if none match the filter
    end

    -- select random enemy from filtered list
    local randomBlobIndex = love.math.random(1, #availableBlobs) -- Pick a random blob type from available blobs
    local randomBlob = availableBlobs[randomBlobIndex] -- Get a random blob configuration

    -- Check if the image is already cached
    local img = enemyCache[randomBlob.spritePath]
     if not img then
        print("MISSING IMAGE FOR: ", randomBlob.name, "at path:", randomBlob.spritePath)
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
            print("[POOL REUSE] Reactivating as:", randomBlob.name)
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
        randomBlob.health, randomBlob.speed, randomBlob.baseDamage, img)

    -- configure new_enemy to target player
    newEnemy:setTarget(player)

    -- add newEnemy into enemies table
    table.insert(enemies, newEnemy)
    -- add newly created enemies into the pool as well
    table.insert(enemyPool, newEnemy)

    newEnemy.spriteIndex = randomIndex -- Store sprite index for rendering
    print("[NEW ENEMY from Spawn Random Enemy] Created:", randomBlob.name)

    -- debug
    print(string.format("[SPAWN] Spawned at: %s at x=%.1f, y=%.1f", randomBlob.name, spawnX, spawnY))

    -- if wave.boss then
    --     spawnBossEnemy()
    --     return
    -- end
end

-- based on window coords
-- function spawnPortal()
--     local portalX = love.graphics.getWidth() / 2
--     local portalY = love.graphics.getHeight() / 2
--     portal = Portal:new(world, portalX, portalY)
--     print("A portal has spawned! Traverse to " ..runData.currentRoom.. " room.")
-- end

-- based on [Player collider] recreated at map coords:
function spawnPortal()
    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    local portalX = mapW / 2
    local portalY = mapH / 2
    portal = Portal:new(world, portalX, portalY)
    print("A portal has spawned! Traverse to " ..runData.currentRoom.. " room.")
end


function roomComplete()
    runData.cleared = true
    spawnPortal() -- TODO: maybe, revisit later 6/20/25
    print("Room " ..runData.currentRoom.. " completed!")
end

function love.load()
    world = wf.newWorld(0, 0)
    -- initialize first
    wallColliders = {}
    enemyPool = {} -- initialize enemy pool

    -- load player save data
    -- TODO: implement save game and load game logic later on 6/20/25
    -- local save = SaveSystem.loadGame()
    -- if save then
    --     runData = save.run
    --     metaData = save.meta
    -- else
    --     runData = createNewRun()
    --     metaData = loadDefaultMeta()
    -- end

    -- collision classes must load into the world first, per order of operations/how content is loaded, I believe
    world:addCollisionClass('player', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'player')
    -- stops enemies from colliding/getting stuck on one another
    world:addCollisionClass('enemy', {ignores = {'enemy'}})
    print("DEBUG: main.lua: Added collision class - " .. 'enemy')
    -- ignore enemy/enemy collider when dashing
    world:addCollisionClass('player_dashing', {ignores = {'enemy'}})
    print("DEBUG: main.lua: Added collision class - " .. 'player_dashing')
    world:addCollisionClass('projectile', {ignores = {'projectile'}})
    print("DEBUG: main.lua: Added collision class - " .. 'projectile')
    world:addCollisionClass('wall', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'wall')
    world:addCollisionClass('portal', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'portal')
    -- You can also define interactions here

    local mage_spritesheet_path = "sprites/mage-NESW.png"
    local dash_spritesheet_path = "sprites/dash.png"
    local death_spritesheet_path = "sprites/soulsplode.png"
    Projectile.loadAssets()
    player:load(world, mage_spritesheet_path, dash_spritesheet_path, death_spritesheet_path)

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
    
            print(string.format("COLLISION: %s vs %s", a.type, b.type))

            -- Handle Player-Enemy interactions
            if player and not player.isDead then
                if not player.isInvincible then
                    player:takeDamage(
                        enemy.baseDamage,
                        metaData,
                        playerScore
                    )
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
                portal_obj.sounds.portal:play()
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
                
                --print(string.format("PLAYER-ENEMY COLLISION: Projectile (owner: %s, damage: %.2f) vs Enemy (%s, health: %.2f)",
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
            dataB:destroySelf() -- destroy projectile on wall collision
        elseif (dataB and dataB.type == "wall" and dataA and dataA.type == "projectile") then
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

    -- Preload 100 enemies into enemy pool
    for i = 1, 100 do
        local randomIndex = math.random(1, #randomBlobs) -- Pick a random blob type
        local randomBlob = randomBlobs[randomIndex] -- Get a random blob configuration
        local e = Enemy:new(world, randomBlob.name, 0, 0, 32, 32, nil, nil, 100, 50, 10, nil)
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
    scoreFont = love.graphics.newFont(30)

    -- register gamestate events and start game in playing state
    -- Gamestate.registerEvents({
    --     leave = function()
    --         globalParticleSystems = {}
    --     end
    -- })
    Gamestate.registerEvents()
    Gamestate.switch(Loading, world, playing, randomBlobs)
end

-- Entering playing gamestate
function playing:enter(previous_state, world, enemyImageCache, mapCache)
    print("[PLAYING:ENTER] Entered playing gamestate")
    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache

    -- may need this when I revisit refactoring the spatial grid to
    -- scale based off of map dimensions, leave commented out for now 7/4/25
    -- wallColliders = {}
    -- for _, wall in ipairs(currentWalls) do
    --     table.insert(wallColliders, wall)
    -- end

    -- always load map for current combat level
    -- local level = LevelManager.levels[LevelManager.currentLevel]
    -- currentMap, currentWalls = MapLoader.load(level.map, world)
    
    -- local mapW = currentMap.width * currentMap.tilewidth
    -- local mapH = currentMap.height * currentMap.tileheight

    -- >> SPATIAL PARTIONING GRID START 7/1/25 <<

    -- TODO: revisit making spatial grid scale based on the map width and height
    -- right now its not clearing colliders correctly between :enter and :leave states
    -- reverted back to using hard coded dimensions for the time being 7/4/25
    self.gridCellSize = 400 -- Each cell is 200x200 pixels, tweak for performance.
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

    LevelManager:loadLevel(LevelManager.currentLevel, enemyImageCache, projectiles)

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

    -- reset for each new Room
    runData.cleared = false

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
    -- print("[Player collider] recreated at:", player.x, player.y)

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    -- map coords
    player.x = mapW / 4
    player.y = mapH / 3
    --print("[Player collider] recreated at map coords:", mapW, mapY)

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

     -- Enemy batching
    -- for _, batch in pairs(self.enemyBatches) do
    --     batch:clear()
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
    print("[DRAW DEBUG]: Individual enemies to draw:", individualCount)

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
    print("[PLAYING:LEAVE] playing leave called")

    print("Walls before cleanup:", #wallColliders)
    for _, collider in ipairs(wallColliders) do
        if not collider:isDestroyed() then
        collider:destroy()
        end
    end
    wallColliders = {}
    print("Walls after cleanup:", #wallColliders)

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
    print("Leaving playing state, cleaning up resources.")
    -- save game after clearing initial room
    SaveSystem.saveGame(runData, metaData)
end

function love.update(dt)
    -- moved all logic into func playing:update(dt) because I'm utilizing hump.gamestate
end

function playing:update(dt)
    print("playing:update")
    -- After player:update(dt, mapW, mapH) or player:update(dt)
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local px, py = player.x, player.y

    -- Clamp the camera so it doesn't scroll past the map edges
    local camX = math.max(w/2 / cam.scale, math.min(px, mapW - w/2 / cam.scale))
    local camY = math.max(h/2 / cam.scale, math.min(py, mapH - h/2 / cam.scale))
    cam:lookAt(camX, camY)

    -- Needed to resolve Box2D locking when trying to create new colliders during the physics being updated
    if self.pendingLevelLoad then
        LevelManager:loadLevel(self.pendingLevelLoad)
        self.pendingLevelLoad = nil
        return  -- Skip rest of update this frame
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

    -- NOTE: I need collision detection before I can continue and the logic for player attacks, enemy attacking player, getting damage values from projectile.damage
    -- and calling the appropriate dealDamage function
    -- AND updating projectile direction control by player : UPDATE: works now for player attacking enemy

    -- change enemy to a diff name to not conflict or be confused with enemy module 6/1/25
    -- old enemy update loop
    -- for i, enemy in ipairs(enemies) do
    --     enemy:update(dt) -- update handles movement towards its target, the player
    --    print("DEBUG: SUCCESS, Enemies table size NOW:", #enemies)
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
                    enemy:update(dt) -- This is the expensive AI update call
                end
            end
        end
    end
-- >> END OF NEW LOOP 7/1/25 <<

    if #enemies == 0 and not portal then
        spawnPortal()
        print("DEBUG: No enemies in table. Attempting to spawn portal.")
    else
        print("DEBUG: Attempting to update:", #enemies, "enemies in table.")
    end

    -- if particle systems exists, update it
    for i = #globalParticleSystems, 1, -1 do
        local ps = globalParticleSystems[i]
        ps:update(dt)

        -- remove inactive particle systems
        -- switched 'and' to 'or' as this removes particles between transitions
        -- may need to revisit once we start adding other particle 
        if ps:getCount() == 0 or not ps:isActive() then
            table.remove(globalParticleSystems, i)
            print("REMOVED INACTIVE PARTICLE SYSTEM")
        end
    end

    -- particle culling
    if #globalParticleSystems > 100 then
        -- remove oldest particles systems first
        local toRemove = #globalParticleSystems - 100
        for i = 1, toRemove do
            table.remove(globalParticleSystems, 1)
        end
        print("Culled", toRemove, "Particle systems")
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
        if not player.isDead and button == 1 then
            sounds.blip:play() -- play projectile blip on mouse click
        end

        if not player.isDead and love.mouse.isDown(1) then
            print("DEBUG: left mouse click detected")
            local mx, my = cam:worldCoords(love.mouse.getX(), love.mouse.getY())
            local angle = math.atan2(
                -- love.mouse.getY() - player.y, 
                -- love.mouse.getX() - player.x
                my - player.y, 
                mx - player.x
            )
            print("DEBUG: calculated angle: ", angle)

            -- create projectiles with angle and speed
            local newProjectile = Projectile.getProjectile(world, player.x, player.y, angle, 200, 10, player)
            print("DEBUG: player.weapon.shoot() CREATED a projectile\n", "x:", player.x, "y:", player.y, "angle:", angle, "speed:", 600, "\nplayer base dmg:", player.baseDamage, "player weapon dmg:", player.weapon.damage)

            if newProjectile then
                print("Projectile created at x", newProjectile.x, "y:", newProjectile.y)
                table.insert(projectiles, newProjectile)
                print("DEBUG: SUCCESS, Projectile table size NOW:", #projectiles)
            else
                print("DEBUG: FAILED, returned NIL, Cooldown might be active or other issue in shoot.")
            end
        end
    end

    if #projectiles == 0 then
        print("DEBUG: No projectiles in table to update.")
    else
        print("DEBUG: Attempting to update", #projectiles, "projectiles.")
    end

    -- Update projectiles so that they move over time, not working bro... 5/25/25 it's working now, logic was not in the right place
    for i = #projectiles, 1, -1 do
        print("DEBUG: Accessing projectile at index", i, "to call update.")
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
                        -- print("DEBUG: Removing projectile index:", i)
                        -- Collider already destroyed in beginContact if it hit something
                        table.remove(projectiles, i)
                    end
                end
            print("DEBUG: Projectile at index", i, "is nil or has no update method.")
    end

    -- after collision handling
    -- add logic to handle removing dead enemies from the 'enemies' table if enemy:die() sets a flag
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e and e.toBeRemoved then -- Check the flag set in Enemy:die()
            -- Collider should have been destroyed in Enemy:die()
            table.remove(enemies, i)
            print("DEBUG: Removed " .. (e.name or "enemy") .. " from table.")
            -- check if room is cleared and turn room cleared flag to true
            if #enemies == 0 and not runData.cleared then
                roomComplete(runData.currentRoom)
            end
        end
    end

    world:update(dt)

    -- Projectile cleanup (maybe move to projectile.lua later on)
    -- for i = #projectiles, 1, -1 do
    --     local p = projectiles[i]
    --     if p.toBeRemoved then
    --         -- if p.collider then
    --         --     p.collider:destroy()
    --         --     -- p.collider = nil, possibly not needed anymore since walls has metadata of type 'wall'
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
            print("DEBUG: Removed projectile at index", i, "from projectiles table.")
        end
    end

    if self.waveManager then
        self.waveManager:update(dt, function(enemyTypes)
            -- Pass enemyTypes to spawner
            LevelManager:spawnRandomInZone(self.enemyImageCache, enemyTypes)
        end)
        
        -- Wave completion check
        if self.waveManager.active and #enemies == 0 and not portal then
            roomComplete()
        end
    end

    player.weapon:update(dt)
end

function love.draw()
    -- moved all logic into func playing:draw() because I'm utilizing hump.gamestate
end

function playing:draw()
    print("playing:draw")

    -- Calculate camera offset and scale
    local camX, camY = cam:position()
    local scale = cam.scale or 1
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

    cam:attach()
            
        if not player.isDead then
            player:draw()
        end

        -- draw enemies
        for _, enemy in ipairs(enemies) do
            if not enemy.toBeRemoved then
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
                self.projectileBatch:add(p.x, p.y, 0, 1, 1, p.width/2, p.height/2)
            else
                print("WARN: Invalid projectile position", p.x, p.y)
            end
        end
        love.graphics.draw(self.projectileBatch)
        print("Projectiles in batch:", self.projectileBatch:getCount())

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
                            print("WARN: Missing animation for", enemy.name)
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

        -- function love.keypressed(key)
        --     if key == "z" then
        --         sounds.music:stop()
        --     end
        -- end

        Debug.draw(projectiles, enemies, globalParticleSystems, self.projectileBatch, Projectile.getPoolSize)
        Debug.drawEnemyTracking(enemies, player)
        Debug.drawCollisions(world)
        Debug.drawColliders(wallColliders, player, portal)
        Debug.drawSpatialGrid(self.spatialGrid, self.gridCellSize, self.gridWidth, self.gridHeight, cam)

        love.graphics.setBlendMode("add") -- for visibility
        -- draw particles systems last after other entities
        for _, ps in ipairs(globalParticleSystems) do
            love.graphics.draw(ps)
        end
        love.graphics.setBlendMode("alpha") -- reset to normal

        if fading and fadeAlpha > 0 then
            love.graphics.setColor(0, 0, 0, fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1, 1, 1, 1)
        end

    cam:detach()

     -- Display player score
     -- debate change to an event system or callback function later when enemy dies or check for when the enemy is dead
    if scoreFont then
        love.graphics.setFont(scoreFont)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Set color to white for text
    love.graphics.print("ROOM " .. tostring(LevelManager.currentLevel - 1), 20, 50)
    love.graphics.print("Health: " .. player.health, 20,80)
    love.graphics.print("Score: " .. playerScore, 20, 110)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 140)
    love.graphics.print("Memory (KB): " .. math.floor(collectgarbage("count")), 20, 640)
end

function safeRoom:enter(previous_state, world, enemyImageCache, mapCache)
    print("[SAFEROOM:ENTER] entered saferoom gamestate")
    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache
    self.currentMap = currentMap

    print("Entering safe room")

    -- passing in its map and walls, which is world, because of colliders
    -- its not a combat level so this is how safe rooms and other rooms will handle
    -- being loaded 6/22/25
    currentMap, currentWalls = MapLoader.load("saferoommap", world)

    for _, wall in ipairs(currentWalls) do
        table.insert(wallColliders, wall)
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
    -- print("[Player collider] recreated at:", player.x, player.y)

    local mapW = currentMap.width * currentMap.tilewidth
    local mapH = currentMap.height * currentMap.tileheight
    -- map coords
    player.x = mapW / 4
    player.y = mapH / 3

    if player.collider then
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    -- firefly funhouse lol, just particles
    for i = 1, 20 do
        local x = love.math.random(mapW * 0.2, mapW * 0.8) -- choose position logic
        local y = love.math.random(mapH * 0.2, mapH * 0.8)
        Particle.spawnFirefly(x, y)
    end

--     for i = 1, 20 do -- adjust number of fireflies
--     local ps = Particle.firefly()
--     if ps then
--         -- Randomize position for each firefly
--         local mapW = currentMap.width * currentMap.tilewidth
--         local mapH = currentMap.height * currentMap.tileheight
--         -- local x = love.math.random(mapW * 0.2, mapW * 0.8)
--         -- local y = love.math.random(mapH * 0.2, mapH * 0.8)
--         local x = love.graphics.getWidth() / 3
--         local y = love.graphics.getHeight() / 3
--         ps:setPosition(x, y) -- calls fireflies at random positions in the room
--         ps:start()
--         table.insert(globalParticleSystems, ps) -- global particle systm to update all active particles
--         print("Total firefly systems:", #globalParticleSystems)
--     end
--   end
--   print("Created firefly particle system:", ps)

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
        print("[SAFEROOM portal] created at", portal.x, portal.y)
    end

    -- prepare to load next level
    LevelManager.currentLevel = LevelManager.currentLevel

end

function safeRoom:leave()
    print("[SAFEROOM:LEAVE] saferoom leave called")
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
    print("Leaving safeRoom state, cleaning up resources.")
    -- save game after clearing initial room
    SaveSystem.saveGame(runData, metaData)
end

function safeRoom:update(dt)
    if saferoomMap then saferoomMap:update(dt) end
    
    -- cam update
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- update player and other entities
    player:update(dt, mapW, mapH)
    local px, py = player.x, player.y

    -- Clamp the camera so it doesn't scroll past the map edges
    local camX = math.max(w/2 / cam.scale, math.min(px, mapW - w/2 / cam.scale))
    local camY = math.max(h/2 / cam.scale, math.min(py, mapH - h/2 / cam.scale))
    cam:lookAt(camX, camY)

    -- update physics world AFTER all positions are set
    if world then world:update(dt) end

    Particle.updateFireflies(dt)

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
    print("safeRoom:draw")

        -- Draw safe room background
        --if currentMap then currentMap:draw() end
        -- love.graphics.setColor(0.2, 0.5, 0.3, 1)
        -- love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Calculate camera offset and scale
    local camX, camY = cam:position()
    local scale = cam.scale or 1
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

    -- Set the background color for the safe room
        love.graphics.setColor(0.7, 0.8, 1) -- Cool blue tint

    cam:attach()
        
        -- Draw player
        player:draw()

        -- if exists, draw it
        if portal then
            portal:draw()
        end

    love.graphics.setBlendMode("add") -- for visibility
    -- draw particles systems last after other entities
    for _, ps in ipairs(globalParticleSystems) do
        love.graphics.draw(ps)
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
    Debug.drawParticleTraces(globalParticleSystems)
    Particle.drawFireflies()

    cam:detach()
    -- Safe room UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(scoreFont)
    love.graphics.print("SAFE ROOM", 20, 50)
    love.graphics.print("Health: " .. player.health, 20,80)
    love.graphics.print("Score: " .. playerScore, 20, 110)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 140)
    -- love.graphics.print("Particles alive:", ps:getCount(), 20, 170)
    love.graphics.print("Memory (KB): " .. math.floor(collectgarbage("count")), 20, 640)
end

-- refactor some of this code eventually TODO: add level manager
-- especially since I need to account for loading different maps
-- 6/17/2025

-- TODO: make ESC key global for quiting no matter what game state they are in
function love.quit()
    -- save game on quit
    SaveSystem.saveGame(runData, metaData)
end