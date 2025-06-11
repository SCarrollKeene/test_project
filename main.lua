local Player = require("player")
local Enemy = require("enemy")
local Blob = require("blob")
local Tileset = require("tileset")
local Map = require("map")
local Projectile = require("projectile")
local wf = require("libraries/windfield")

local projectiles = {}
local player = Player -- create new player instance, change player.lua to a constructor pattern if you want multiple players
-- local world = wf.newWorld(0, 0) -- where physics objects exist, maybe move to love.load later, still learning how this connects everything
-- local worldCollider = world:newRectangleCollider(350, 100, 80, 80)

local enemies = {} -- enemies table to house all active enemies
local playerScore = 0
local scoeFont = 0

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
    if key == "escape" then
        love.event.quit()
    end

    if key == "e" then
        spawnRandomEnemy()
    end
end

function spawnRandomEnemy()
    -- CONCEPT 6/3/25, UPDATE 6/3/25 IT WORKS, had to google some things lol
    -- load enemy types into table
    -- iterate through table
    -- randomize the enemeis that are picked in that table
    -- randomize where they are placed after being picked out of table

    -- Use the correct sprite path
    local slime_spritesheet_path = "sprites/slime_black.png"
    local blueblob_spritesheet_path = "sprites/slime_blue.png"
    local violetblob_spritesheet_path = "sprites/slime_violet.png"

    -- define enemy types and configurations
    local randomBlobs = { 
        { name = "Black Blob", spritePath = slime_spritesheet_path, health = 60, speed = 50, baseDamage = 5 },
        { name = "Blue Blob", spritePath = blueblob_spritesheet_path, health = 120, speed = 70, baseDamage = 10 }, 
        { name = "Violet Blob", spritePath = violetblob_spritesheet_path, health = 180, speed = 90, baseDamage = 15 } 
    }

    -- Pick a random enemy type from the randomBlobs configuration table
    local randomIndex = math.random(1, #randomBlobs) -- picks a random index
    print(#randomBlobs) -- returns number of entries in the #randomBlobs table
    local randomBlob = randomBlobs[randomIndex] -- returns a random blob from the table

    -- Get random position within screen bounds
    -- minimum width and height from enemy to be used in calculating random x/y spawn points
    local enemy_width, enemy_height = 32, 32  -- Default, or use actual frame size
    local x = love.math.random(enemy_width, love.graphics.getWidth() - enemy_width)
    local y = love.math.random(enemy_height, love.graphics.getHeight() - enemy_height)
    
    -- Create the enemy instance utilizing the randomBlob variable to change certain enemy variables like speed, health, etc
    local newEnemy = Enemy:new(world, randomBlob.name, x, y, enemy_width, enemy_height, nil, nil, randomBlob.health, randomBlob.speed, randomBlob.baseDamage, randomBlob.spritePath)

    -- configure new_enemy to target player
    newEnemy:setTarget(player)

    -- add newEnemy into enemies table
        table.insert(enemies, newEnemy)

    -- debug
    print(string.format("DEBUG: %s at x=%.1f, y=%.1f", randomBlob.name, x, y))
end

function love.load()
    world = wf.newWorld(0, 0)
    -- collision classes must load into the world first, per order of operations/how content is loaded, I believe
    world:addCollisionClass('player', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'player')
    world:addCollisionClass('enemy', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'enemy')
    world:addCollisionClass('projectile', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'projectile')
    world:addCollisionClass('wall', {ignores = {}})
    print("DEBUG: main.lua: Added collision class - " .. 'wall')
    -- You can also define interactions here

    if world.collisionClassesSet then
        print("DEBUG main.lua: Calling world:collisionClassesSet()")
        world:collisionClassesSet()
    elseif world.generateCategoriesMasks then
        print("DEBUG main.lua: Calling world:generateCategoriesMasks()")
        world:generateCategoriesMasks()
    else
        print("ERROR main.lua: Neither collisionClassesSet nor generateCategoriesMasks found on world object directly!")
        -- This would be very problematic and might indicate an incomplete Windfield setup or version issue.
    end

    Tileset:load()
    Map:load(world) -- idk if I need to pass world to may, this seems contingent upon Map creating the colliders, revisit
    
    local mage_spritesheet_path = "sprites/mage-NESW.png"
    Player:load(world, mage_spritesheet_path)
    -- Player:load(world, death_spritesheet_path)
    -- Blob:load()

    local slime_spritesheet_path = "sprites/slime_black.png"
    enemy1 = Enemy:new(world, "Black Blob", 800, 200, 32, 32, nil, nil, 60, 50, 5, slime_spritesheet_path)

    --enemy1 = Enemy:new(world, name, 800, 200) -- revisit how to pass in only the args that I want 5/30/25

    local blueblob_spritesheet_path = "sprites/slime_blue.png"
    blueBlob = Enemy:new(world, "Blue Blob", 700, 300, 32, 32, nil, nil, 120, 70, 10, blueblob_spritesheet_path)

    local violetblob_spritesheet_path = "sprites/slime_violet.png"
    violetBlob = Enemy:new(world, "Violet Blob", 750, 250, 32, 32, nil, nil, 180, 90, 15, violetblob_spritesheet_path)

    -- enemy1:setTarget(player)
    -- blueBlob:setTarget(player)
    -- violetBlob:setTarget(player)

    -- table.insert(enemies, enemy1)
    -- table.insert(enemies, blueBlob)
    -- table.insert(enemies, violetBlob)

    -- print(enemy1:getName().." in table")
    -- print(blueBlob:getName().." in table")
    -- print(violetBlob:getName().." in table")

    -- enemy1:Taunt()
    --blob1:Taunt() -- method override not working 5/28/25

    -- load all new enemy instances into one table
    local new_enemies = { enemy1, blueBlob, violetBlob }

    -- iterate through elements of new_enemies table, set the player as the target for all enemies, 
    -- enemy assigned actual value of the enemy object itself at an index
    -- i is assigned mumerical index of the current element starting at 1, cause, Lua
    for i, enemy in ipairs(new_enemies) do
        enemy:setTarget(player)
        table.insert(enemies, enemy)
        print("DEBUG:".."Added enemy " .. i .. " (" .. (enemy.name or "enemy") .. ") to table. Target set!")
    end

    function beginContact(a, b, coll)
        local dataA = a:getUserData() -- both Should be the projectile/enemy data
        local dataB = b:getUserData() -- based on the collision check if statement below
        local projectile, enemy, wall, player

        -- make function local to prevent overwriting similar outer variables
        local function handlePlayerEnemyCollision(a, b)
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
                    player:takeDamage(enemy.baseDamage)
                end
            end
        end

        -- execute function
        handlePlayerEnemyCollision(dataA, dataB)

        -- Check for Projectile-Enemy collision
        if dataA and dataA.damage and dataA.owner and dataB and dataB.health and not dataB.damage then -- Heuristic eval: projectile has damage, enemy has health but not damage field
            projectile = dataA
            enemy = dataB
        elseif dataB and dataB.damage and dataB.owner and dataA and dataA.health and not dataA.damage then
            projectile = dataB
            enemy = dataA
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
end

function love.update(dt)
    print("update")
    player:update(dt)
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

    if #enemies == 0 then
        print("DEBUG: No enemies in table.")
    else
        print("DEBUG: Attempting to update:", #enemies, "enemies in table.")
    end

    -- add logic to handle removing dead enemies from the 'enemies' table if enemy:die() sets a flag

    -- Handle shooting
    -- feels like a global action, maybe move this into main? or a sound file, hmm 5/29/25
    function love.mousepressed(x, y, button, istouch, presses)
        if not player.isDead and button == 1 then
            sounds.blip:play()
        end
    end

    if not player.isDead and love.mouse.isDown(1) then
        print("DEBUG: left mouse click detected")
        local angle = math.atan2(
            love.mouse.getY() - player.y, 
            love.mouse.getX() - player.x
        )
        print("DEBUG: calculated angle: ", angle)

        -- create projectiles with angle and speed
        local newProjectile = player.weapon:shoot(world, player.x, player.y, angle, 200, player)
        print("DEBUG: player.weapon.shoot() CREATED a projectile\n", "x:", player.x, "y:", player.y, "angle:", angle, "speed:", 600, "\nplayer base dmg:", player.baseDamage, "player weapon dmg:", player.weapon.damage)
            if newProjectile then
                print("Projectile created at x", newProjectile.x, "y:", newProjectile.y)
                table.insert(projectiles, newProjectile)
                print("DEBUG: SUCCESS, Projectile table size NOW:", #projectiles)
            else
                print("DEBUG: FAILED, returned NIL, Cooldown might be active or other issue in shoot.")
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
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e and e.toBeRemoved then -- Check the flag set in Enemy:die()
            -- Collider should have been destroyed in Enemy:die()
            table.remove(enemies, i)
            print("DEBUG: Removed " .. (e.name or "enemy") .. " from table.")
        end
    end

    world:update(dt)
    player.weapon:update(dt)
end

function love.draw()
    print("draw")
    world:draw()
    print(Tileset.image)
        -- draw map first, player should load on top of map
        for row = 1, #Map.data do
            for col = 1, #Map.data[row] do
                local tileIndex = Map.data[row][col]
                    if tileIndex > 0 then  -- skip empty tiles if 0 = empty
                            love.graphics.draw(
                            Tileset.image,
                            Tileset.quads[tileIndex],
                            (col - 1) * Tileset.tileWidth,
                            (row - 1) * Tileset.tileHeight
                        )
                    end
            end
        end
        
    player:draw()
    -- Iterate through the 'enemies' table to draw active enemies:
    for _, active_enemy in ipairs(enemies) do
        if active_enemy and active_enemy.draw then -- Check if it exists and has a draw method
            active_enemy:draw()
        end
    end

    for _, p in ipairs(projectiles) do
        p:draw()
    end

    -- function love.keypressed(key)
    --     if key == "z" then
    --         sounds.music:stop()
    --     end
    -- end

     -- Display player score
     -- debate change to an event system or callback function later when enemy dies or check for when the enemy is dead
    if scoreFont then
        love.graphics.setFont(scoreFont)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Set color to white for text
    love.graphics.print("Score: " .. playerScore, 30, 30)
    love.graphics.print("Press 'e' on keyboard to spawn more enemies.", 30, 60)
end