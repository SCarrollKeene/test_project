local Player = require("player")
local PlayerRespawn = require("playerrespawn")
local Enemy = require("enemy")
local Portal = require("portal")
local Particle = require("particle")
local Blob = require("blob")
local Tileset = require("tileset")
local Map = require("map")
local Walls = require("walls")
local MapLoader = require("maploader")
local LevelManager = require("levelmanager")
local Loading = require("loading")
local sti = require("libraries/sti")
local Projectile = require("projectile")
local wf = require("libraries/windfield")
local Gamestate = require("libraries/hump/gamestate")
local SaveSystem = require("save_game_data")
local Debug = require("game_debug")

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
local room2Map

-- game state definitions
local playing = {}
local paused = {}
local safeRoom = {}
local gameOver = {}

local projectiles = {}
local player = Player -- create new player instance, change player.lua to a constructor pattern if you want multiple players
-- local world = wf.newWorld(0, 0) -- where physics objects exist, maybe move to love.load later, still learning how this connects everything
-- local worldCollider = world:newRectangleCollider(350, 100, 80, 80)

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

    -- debug
    if key == "f1" then  -- Stress test
        for i=1, 100 do
            spawnRandomEnemy(love.math.random(100, 700), love.math.random(100, 500))
        end
        player.weapon.fireRate = 0.01  -- Rapid fire
    end

    if Gamestate.current() == safeRoom then
        return -- Prevent any attack actions in safe room
    end
end

function spawnRandomEnemy(x, y, cache)
    local state = Gamestate.current()
    local enemyCache = cache or state.enemyImageCache or {} -- Use the current state's enemy image cache, not global

    -- 6/20/25 no spawning in safe rooms!
    if Gamestate.current() == safeRoom then return end

    -- CONCEPT 6/3/25, UPDATE 6/3/25 IT WORKS, had to google some things lol

    -- Pick a random enemy type from the randomBlobs configuration table
    local randomIndex = math.random(1, #randomBlobs) -- picks a random index between 1-3
    local randomBlob = randomBlobs[randomIndex] -- returns a random blob from the table

    -- Get random position within screen bounds
    -- minimum width and height from enemy to be used in calculating random x/y spawn points
    local enemy_width, enemy_height = 32, 32  -- Default, or use actual frame size
    local spawnX = x or love.math.random(enemy_width, love.graphics.getWidth() or 800 - enemy_width)
    local spawnY = y or love.math.random(enemy_height, love.graphics.getHeight()or 600 - enemy_height)

    local img = enemyCache[randomBlob.spritePath]
    if not img then
        print("MISSING IMAGE FOR: ", randomBlob.name, "at path:", randomBlob.spritePath)
    end

    -- Create the enemy instance utilizing the randomBlob variable to change certain enemy variables like speed, health, etc
    local newEnemy = Enemy:new(
        world, randomBlob.name, spawnX, spawnY, enemy_width, enemy_height, nil, nil, 
        randomBlob.health, randomBlob.speed, randomBlob.baseDamage, img)

    -- configure new_enemy to target player
    newEnemy:setTarget(player)

    -- add newEnemy into enemies table
        table.insert(enemies, newEnemy)

    newEnemy.spriteIndex = randomIndex -- Store sprite index for rendering

    -- debug
    print(string.format("[SPAWN] Spawned at: %s at x=%.1f, y=%.1f", randomBlob.name, spawnX, spawnY))
end

function spawnPortal()
    local portalX = love.graphics.getWidth() / 2
    local portalY = love.graphics.getHeight() / 2
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
    world:addCollisionClass('projectile', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'projectile')
    world:addCollisionClass('wall', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'wall')
    world:addCollisionClass('portal', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'portal')
    -- You can also define interactions here

    Tileset:load()
    Map:load(world) -- idk if I need to pass world to may, this seems contingent upon Map creating the colliders, revisit
    
    local mage_spritesheet_path = "sprites/mage-NESW.png"
    local dash_spritesheet_path = "sprites/dash.png"
    local death_spritesheet_path = "sprites/soulsplode.png"
    Projectile.loadAssets()
    Player:load(world, mage_spritesheet_path, dash_spritesheet_path, death_spritesheet_path)
    -- Player:load(world, death_spritesheet_path)

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
                
                print(string.format("Collision: Projectile (owner: %s, damage: %.2f) vs Enemy (%s, health: %.2f)",
                (projectile.owner and projectile.owner.name) or "Unknown", projectile.damage, enemy.name, enemy.health))
                
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
        if (dataA and dataA.type == "wall" and dataB and dataB.damage) or
            (dataB and dataB.type == "wall" and dataA and dataA.damage) then
            -- One is wall, one is projectile
            local projectile = dataA.damage and dataA or dataB

            if projectile.collider then
                local px, py = projectile.collider:getPosition()
                print(string.format("COLLISION: Projectile vs Wall at: ".. "PX: " .. "(%.1f) " .. "PY :" .. "(%.1f)", px, py))
            else
                print("COLLISION: Projectile vs Wall (collider already destroyed)")
            end

            -- Destroy projectile collider and remove from table
            projectile.toBeRemoved = true -- flag for removal from the projectiles table
            if projectile.collider then 
                projectile.collider:destroy() 
                projectile.collider = nil -- set projectile collider to nil after projectile is destroyed because its no longer active
            end
        end
    end

    world:setCallbacks(beginContact, nil, nil, nil) -- We only need beginContact for this

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
    print("Entered playing gamestate")
    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache

    LevelManager:loadLevel(LevelManager.currentLevel, enemyImageCache)

    -- DEFER level loading to next frame
    --vself.pendingLevelLoad = LevelManager.currentLevel

    -- reset for each new Room
    runData.cleared = false
    -- Reset player position and state
    player.x = 140
    player.y = love.graphics.getHeight() / 3

    if player.collider then
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    -- Recreate collider if missing
    if not player.collider then
        player:load(world)  
    end
    
    -- Spawn initial enemies if needed
    -- if #enemies == 0 then
    --     spawnRandomEnemy()
    -- end

    -- Reload enemy animations
    for i, enemy in ipairs(enemies) do
        if enemy.spriteSheet then
            enemy.currentAnimation = enemy.animations.idle
            -- enemy.currentAnimation:reset()
        end
    end
end

function playing:leave()
    -- stop music, clear temp tables/objects, destroy portals, etc
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
    -- if pendingRoomTransition then
    --     Gamestate.switch(safeRoom)
    --     pendingRoomTransition = false
    --     return -- prevents any further update logic
    -- end

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
        player:update(dt)
    end
    -- enemy1:update(dt)
    -- blob1:update(dt)

    -- NOTE: I need collision detection before I can continue and the logic for player attacks, enemy attacking player, getting damage values from projectile.damage
    -- and calling the appropriate dealDamage function
    -- AND updating projectile direction control by player : UPDATE: works now for player attacking enemy

    -- change enemy to a diff name to not conflict or be confused with enemy module 6/1/25
    for i, enemy in ipairs(enemies) do
        enemy:update(dt) -- update handles movement towards its target, the player
       print("DEBUG: SUCCESS, Enemies table size NOW:", #enemies)
    end

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
            local angle = math.atan2(
                love.mouse.getY() - player.y, 
                love.mouse.getX() - player.x
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
    player.weapon:update(dt)
end

function love.draw()
    -- moved all logic into func playing:draw() because I'm utilizing hump.gamestate
end

function playing:draw()
    print("playing:draw")
    -- draw map first, player should load on top of map
    if currentMap then currentMap:draw() end
        
    if not player.isDead then
        player:draw()
    end

    for _, enemy in ipairs(enemies) do
        if not enemy.toBeRemoved then
            enemy:draw()
        end
    end

    -- check to draw shot projectiles
    for _, p in ipairs(projectiles) do
        p:draw()
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

    Debug.draw(projectiles, enemies, globalParticleSystems) -- Draws debug overlay
    Debug.drawEnemyTracking(enemies, player)

    love.graphics.setBlendMode("add") -- for visibility
    -- draw particles systems last after other entities
    for _, ps in ipairs(globalParticleSystems) do
        love.graphics.draw(ps)
    end
    love.graphics.setBlendMode("alpha")

    if fading and fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

     -- Display player score
     -- debate change to an event system or callback function later when enemy dies or check for when the enemy is dead
    if scoreFont then
        love.graphics.setFont(scoreFont)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Set color to white for text
    love.graphics.print("ROOM " .. tostring(LevelManager.currentLevel), 20, 50)
    love.graphics.print("Health: " .. player.health, 20,80)
    love.graphics.print("Score: " .. playerScore, 20, 110)
    -- for _, wall in ipairs(currentWalls) do
    --     love.graphics.rectangle("line", wall:getX(), wall:getY(), wall:getWidth(), wall:getHeight())
    -- end
    Debug.drawCollisions(world)
end

function safeRoom:enter(previous_state, world, enemyImageCache, mapCache)
    self.world = world
    self.enemyImageCache = enemyImageCache
    self.mapCache = mapCache

    print("Entering safe room")

    -- passing in its map and walls, which is world, because of colliders
    -- its not a combat level so this is how safe rooms and other rooms will handle
    -- being loaded 6/22/25
    currentMap, currentWalls = MapLoader.load("saferoommap", world)

    for _, wall in ipairs(currentWalls) do
        table.insert(wallColliders, wall)
    end
    
    player.x = 140
    player.y = love.graphics.getHeight() / 2

    if player.collider then
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    -- Recreate collider if missing
    if not player.collider then
        player:load(world)  
    end

    -- need to check if projectile collider exists, if not, recreate it
    -- need to also make sure that remaining projectile colliders are destroyed on :leave()
    -- if not projectile.collider then
    --     -- Recreate projectile collider if missing
    --     Projectile.loadAssets() -- Ensure assets are loaded before creating projectiles
    --     Projectile.createCollider(world, player.x, player.y) -- Create a new collider for the projectile
    -- end

    -- need to check for, update and draw projectiles again

    -- create store/shop logic

    -- add some NPC

    -- a way for the player to heal

    projectiles = {} -- Clear existing projectiles

    -- portal to room2
    if not portal then
        portal = Portal:new(world, love.graphics.getWidth()/2, love.graphics.getHeight()/2)
        print("Safe room portal created")
    end

    -- prepare to load next level
    LevelManager.currentLevel = LevelManager.currentLevel
end

function safeRoom:leave()
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
        portal:destroy();
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
    if world then world:update(dt) end
    player:update(dt)

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
        player:update(dt)
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

    -- Set the background color for the safe room
    -- love.graphics.setColor(0.7, 0.8, 1) -- Cool blue tint
    -- Draw safe room background
    if currentMap then currentMap:draw() end
    -- love.graphics.setColor(0.2, 0.5, 0.3, 1)
    -- love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
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
    love.graphics.setBlendMode("alpha")

    if fading and fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha) -- Black fade; use (1,1,1,fadeAlpha) for white
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    Debug.draw(projectiles, enemies, globalParticleSystems) -- Draws debug overlay

    -- Safe room UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(scoreFont)
    love.graphics.print("SAFE ROOM", 20, 50)
    love.graphics.print("Health: " .. player.health, 20,80)
    love.graphics.print("Score: " .. playerScore, 20, 110)
    Debug.drawCollisions(world)
end

-- refactor some of this code eventually TODO: add level manager
-- especially since I need to account for loading different maps
-- 6/17/2025

-- function room2:enter()
--     print("Entering room 2")
--     room2Map = MapLoader.load("room2", world)

--     -- reset for each new Room
--     runData.currentRoom = runData.currentRoom + 1
--     runData.cleared = false

--     player.x = 140
--     player.y = love.graphics.getHeight() / 3
--     if player.collider then
--         player.collider:setPosition(player.x, player.y)
--         player.collider:setLinearVelocity(0, 0)
--     end

--     -- need to check for, update and draw projectiles again

--     -- spawn some random enemies
--     for i = 1, 5 do
--         spawnRandomEnemy()
--     end

--     -- portal reset
--     portal = nil
-- end

-- function room2:leave()
--     -- stop music, clear temp tables/objects, destroy portals, etc

--     -- clear particles
--     globalParticleSystems = {}

--     -- destroy current remaining portal
--     if portal then
--         portal:destroy();
--         portal = nil
--     end

--     -- reset flags
--     pendingRoomTransition = false
--     print("Leaving room 2 state, cleaning up resources.")
--     -- save game after clearing initial room
--     SaveSystem.saveGame(runData, metaData)
-- end

-- function room2:update(dt)
--     if room2 then room2Map:update(dt) end
--     if world then world:update(dt) end
--     player:update(dt)

--     -- update spawned enemies in room 2
--     for i, enemy in ipairs(enemies) do
--         enemy:update(dt)
--     end

--     if #enemies == 0 and not portal then
--         spawnPortal() -- spawn portal when enemies have been defeaated
--         print("Room 2 CLEARED. Portal spawned.")
--     end

--     if pendingRoomTransition then
--         fading = true
--         fadeDirection = 1
--         fadeTimer = 0
--         nextState = safeRoom
--         pendingRoomTransition = false
--     end
--     -- if fading then
--     --     -- SUPPOSED to clear particles when starting fade out
--     --     if fadeDirection == 1 and nextState == playing then
--     --         globalParticleSystems = {}
--     --     end

--     --     if fadeDirection == 1 then
--     --         -- Fade out (to black)
--     --         fadeTimer = fadeTimer + dt
--     --         fadeAlpha = math.min(fadeTimer / fadeDuration, 1)
--     --         if fadeAlpha >= 1 then
--     --             -- Fade out complete, start hold
--     --             fadeHoldTimer = 0
--     --             fadeDirection = 0    -- 0 indicates hold phase
--     --         end
--     --     elseif fadeDirection == 0 then
--     --         -- Hold phase (fully black)
--     --         fadeHoldTimer = fadeHoldTimer + dt
--     --         fadeAlpha = 1
--     --         if fadeHoldTimer >= fadeHoldDuration then
--     --             -- Hold complete, switch state and start fade in
--     --             Gamestate.switch(nextState)
--     --             fadeDirection = -1
--     --             fadeTimer = 0
--     --         end
--     --     elseif fadeDirection == -1 then
--     --         -- Fade in (from black)
--     --         fadeTimer = fadeTimer + dt
--     --         fadeAlpha = 1 - math.min(fadeTimer / fadeDuration, 1)
--     --         if fadeAlpha <= 0 then
--     --             fading = false
--     --             fadeAlpha = 0
--     --         end
--     --     end
--     --     return -- halt other updates during fade
--     -- end

--     -- if not player.isDead then
--     --     player:update(dt)
--     -- end

--     if portal then
--         portal:update(dt)
--     end
-- end

-- function room2:draw()
--     -- draw room
--     if room2Map then room2Map:draw() end

--     -- Draw player
--     if player then
--         player:draw()
--     end

--     -- draw spawned enemeis in room 2
--     for _, enemy in ipairs(enemies) do
--         if enemy.draw then enemy:draw() end
--     end

--     -- if portal exists, draw it
--     if portal and portal.draw then
--         portal:draw()
--     end

--     -- Room 2 room UI
--     love.graphics.setColor(1, 1, 1, 1)
--     love.graphics.setFont(scoreFont)
--     love.graphics.print("ROOM 2", 30, 50)
--     love.graphics.print("Press 'R' to start next round", 30, 80)
--     love.graphics.print("Health: " .. player.health, 30, 110)
--     love.graphics.print("Score: " .. playerScore, 30, 140)
--     love.graphics.print("Enemies: " .. #enemies, 30, 170)
-- end


-- TODO: make ESC key global for quiting no matter what game state they are in
function love.quit()
    -- save game on quit
    SaveSystem.saveGame(runData, metaData)
end