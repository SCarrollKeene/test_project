local Weapon = require("weapon")
local Projectile = require("projectile")
local Utils = require("utils")
local anim8 = require("libraries/anim8")
local wf = require("libraries/windfield")
local flashShader = require("libraries/flashshader")
local SaveSystem = require("save_game_data")

local Player = {} -- one global player object based on current singleton setup, but local to the module making it not global in use
Player.__index = Player -- reference for methods from instances

function Player:load(passedWorld, sprite_path, dash_sprite_path, death_sprite_path)
    love.graphics.setDefaultFilter("nearest", "nearest")

    self.name = "Player"
    self.level = self.level or 1
    self.experience = self.experience or 0
    self.x = 60
    self.y = love.graphics.getHeight() / 3
    self.width = 32
    self.height = 32
    self.type = "player"
    self.world = passedWorld

    self.frameWidth = 32
    self.frameHeight = 32

    self.spriteSheet = nil
    -- self.dashSpriteSheet = love.graphics.newImage("sprites/dash.png")
    -- self.soulsplodeSheet = love.graphics.newImage("sprites/soulsplode.png")
    self.animations = {}
    self.currentAnimation = nil

    -- flags for death and removal upon death
    self.isDead = false
    -- self.isExploding = false

    -- dash logic
    self.isDashing = false  -- flag to use in movement to switch between regular movement vs dashing
    self.dashSpeed = 900  -- Adjust based on preference
    self.dashDuration = 0.15  -- Dash lasts 0.15 seconds
    self.dashCooldown = 0.5  -- Time before player can dash again
    self.dashTimer = 0
    self.dashCooldownTimer = 0
    self.lastDashDirection = {x = 0, y = 0}

    -- flashing properties for when the player takes damage
    self.isFlashing = false
    self.flashTimer = 0
    self.flashDuration = 0.12
    self.flashInterval = 0.1

    -- flags for invincibilty frames after damage and isFlashing
    self.isInvincible = false
    self.invincibleDuration = 1.0
    self.invincibleTimer = 0

    -- for player inventory between runs
    self.inventory = {}
    -- self.weaponSlots = { nil, nil }
    self.equippedSlot = self.equippedSlot or 1

    -- Load player sprite sheet if path provided (following enemy.lua pattern)
    if sprite_path then
        local success, image_or_error = pcall(function() return love.graphics.newImage(sprite_path) end)
        if success then
            self.spriteSheet = image_or_error
            print("Player spritesheet loaded successfully from:", sprite_path)
            
            -- Calculate frame dimensions (like enemy.lua does)
            -- Based on mage-NESW.jpg, it appears to be 3 columns (frames per direction) and 4 rows (directions)
            local frameWidth = self.spriteSheet:getWidth() / 3   -- 3 frames per direction
            local frameHeight = self.spriteSheet:getHeight() / 4 -- 4 directions (down, left, right, up)
            
            self.width = frameWidth
            self.height = frameHeight
            print(string.format("Player frame dimensions set: W=%.1f, H=%.1f", self.width, self.height))
            
            -- Create anim8 grid (following enemy.lua pattern exactly)
            self.grid = anim8.newGrid(frameWidth, frameHeight, 
                                       self.spriteSheet:getWidth(), self.spriteSheet:getHeight())          
        

        self.animations.idle = anim8.newAnimation(self.grid('1-3', 3), 0.2) -- Example
        -- self.animations.death = anim8.newAnimation(self.deathGrid('1-8', 1), 0.08, 'pauseAtEnd')
        self.animations.down = anim8.newAnimation(self.grid('1-3', 3), 0.2) -- Example, adjust frames
        self.animations.up = anim8.newAnimation(self.grid('1-3', 1), 0.2)   -- Example, adjust frames
        self.animations.left = anim8.newAnimation(self.grid('1-3', 4), 0.2) -- Example, adjust frames
        self.animations.right = anim8.newAnimation(self.grid('1-3', 2), 0.2)-- Example, adjust frames
        -- self.animations.dash = anim8.newAnimation(self.dashGrid('1-6', 1), 0.2, 'pauseAtEnd') -- adjust speed for 6 frames 

        -- Add print statements to check if each animation object was created
        print("Idle animation object:", tostring(self.animations.idle))
        print("Up animation object:", tostring(self.animations.up))
        print("Down animation object:", tostring(self.animations.down))
        print("Left animation object:", tostring(self.animations.left))
        print("Right animation object:", tostring(self.animations.right))
        -- etc.

        self.currentAnimation = self.animations.idle
            if self.currentAnimation then
                print("Player animations created. Default animation set to 'idle'.")
            else
                print("Warning: Could not set default animation 'idle'. Check animation definition.")
            end
            else
                print(string.format("ERROR: Failed to load player spritesheet from path '%s'. Error: %s", sprite_path, tostring(image_or_error)))
            end
            else
                print("DEBUG: No spritesheet path provided for player:", self.name)
    end
     -- Load dash sprite sheet
    if dash_sprite_path then
        local success, image_or_error = pcall(function() return love.graphics.newImage(dash_sprite_path) end)
        if success then
            self.dashSpriteSheet = image_or_error
            print("Dash spritesheet loaded successfully from:", dash_sprite_path)
            
            -- Set up dash animation (6 frames, 1 row)
            local dashFrameWidth = self.dashSpriteSheet:getWidth() / 6
            local dashFrameHeight = self.dashSpriteSheet:getHeight()
            self.dashGrid = anim8.newGrid(dashFrameWidth, dashFrameHeight,
                self.dashSpriteSheet:getWidth(), self.dashSpriteSheet:getHeight())
            self.animations.dash = anim8.newAnimation(self.dashGrid('1-6', 1), 0.08)
            
        else
            print("ERROR: Failed to load dash spritesheet:", tostring(image_or_error))
        end
    end
    
    -- Load death sprite sheet
    if death_sprite_path then
        local success, image_or_error = pcall(function() return love.graphics.newImage(death_sprite_path) end)
        if success then
            self.soulsplodeSheet = image_or_error
            print("Death spritesheet loaded successfully from:", death_sprite_path)
            
            -- Set up death animation (8 frames, 1 row)
            local deathFrameWidth = self.soulsplodeSheet:getWidth() / 8
            local deathFrameHeight = self.soulsplodeSheet:getHeight()
            self.deathGrid = anim8.newGrid(deathFrameWidth, deathFrameHeight,
                self.soulsplodeSheet:getWidth(), self.soulsplodeSheet:getHeight())
            self.animations.death = anim8.newAnimation(self.deathGrid('1-8', 1), 0.08, 'pauseAtEnd')
            
        else
            print("ERROR: Failed to load death spritesheet:", tostring(image_or_error))
        end
    end

    self.collider = self.world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 10)
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- link player collider back to player
    self.collider:setCollisionClass('player')
    self.collider:setObject(self)

    self.baseDamage = 1
    self.damageGrowth = { min = 1, max = 4 }
    self.health = 100
    self.speed = 300
    self.xVel = 0
    self.yVel = 0

    -- eventually replace self.weapon with a table that has multiple weapon slots
    -- self.weaponSlots = {[1] = weaponSlotA, [2] = weaponSlotB } -- TODO: how many active slots do I want? 7/16/25
    -- don't forget to add to all runData logic to make sure this persists later throughout main and the save game data resetRun func
    -- use an integar variable in equippedSlot refactor

    -- data only snapshot of weapon in player inventory
    if self.weapon then
    table.insert(self.inventory, {
        name = self.weapon.name,
        image = self.weapon.image,
        weaponType = self.weapon.weaponType,
        fireRate = self.weapon.fireRate,
        projectileClass = self.weapon.projectileClass,
        baseDamage = self.weapon.baseDamage,
        level = self.weapon.level
    })
    end

    -- if no weapon in inventory, create a new weapon and insert into inventory, please work
    if not self.weapon then
        -- default equipped weapon: name, image, weaponType, fireRate, projectileClass, baseDamage and level class params/args from Weapon class
        self.weapon = Weapon:new("Fire crystal", Weapon.image, "Crystal", 2, Projectile, 10, 1)
    end

    if #self.inventory == 0 then
        table.insert(self.inventory, {
            name = self.weapon.name,
            image = self.weapon.image,
            weaponType = self.weapon.weaponType,
            fireRate = self.weapon.fireRate,
            projectileClass = self.weapon.projectileClass,
            baseDamage = self.weapon.baseDamage,
            level = self.weapon.level
        })
        self.equippedSlot = 1
    end
end

function Player:addExperience(xpAmount)
    self.experience = self.experience + xpAmount
    while self.experience >= self:getXPToNextLevelUp() do
        self.experience = self.experience - self:getXPToNextLevelUp()
        self:onLevelUp()
    end
end

function Player:getXPToNextLevelUp()
    return math.floor(20 * math.pow(1.5, self.level - 1)) -- exponential growth, I think, in math.pow(1.5)
end

function Player:onLevelUp()
    local percent = love.math.random(self.damageGrowth.min, self.damageGrowth.max) / 100
    self.level = self.level + 1

    -- come back to add increases to stats, effects, etc
    self.health = self.health + math.floor(self.health * 0.07)
    self.baseDamage = self.baseDamage + math.floor(self.baseDamage * percent)
    self.speed = self.speed + math.floor(self.speed * 0.03)
end

function Player:update(dt, mapW, mapH)
    -- Handle dash cooldown
    if self.dashCooldownTimer > 0 then
        self.dashCooldownTimer = self.dashCooldownTimer - dt
        if self.dashCooldownTimer < 0 then self.dashCooldownTimer = 0 end
    end

    -- Handle dashing
    if self.isDashing then
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then
            self.isDashing = false
            -- Stop dash, reset to normal speed (or zero velocity)
            if self.collider then
                self.collider:setLinearVelocity(0, 0)
                --set player collider back to 'player' after dashing
                self.collider:setCollisionClass('player')
            end
        end
    end

    -- condition to switch to dashing anim and back to idle
    if self.isDashing and self.animations.dash then
        if self.currentAnimation ~= self.animations.dash then
            self.currentAnimation = self.animations.dash
            self.currentAnimation:gotoFrame(1)
            print("----------SWITCH TO DASH ANIMATION----------")
        end
    elseif self.currentAnimation == self.animations.dash and not self.isDashing then
        self.currentAnimation = self.animations.idle
        print("----------SWITCH TO IDLE ANIMATION----------")
    end

    if self.isDead then
        -- Only update death animation and effects
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return  -- Skip all other updates
    end

    self:move(dt)

    if self.isFlashing then
    self.flashTimer = self.flashTimer - dt
        if self.flashTimer <= 0 then
            self.isFlashing = false
            self.flashTimer = 0
        end
    end

    if self.isInvincible then
        self.invincibleTimer = self.invincibleTimer - dt
         print(string.format("[INVINCIBLE] Timer: %.2f/%s", 
            self.invincibleTimer, 
            tostring(self.invincibleDuration)))
        if self.invincibleTimer <= 0 then
            self.isInvincible = false
            self.invincibleTimer = 0
        end
    end

    if self.currentAnimation then
        self.currentAnimation:update(dt) -- updates current sprite active animation
    end

    if self.isDead then
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return -- Skip all normal update logic if dead
    end

    if self.collider then
        self.x, self.y = self.collider:getPosition()
    end

    self:checkBoundaries(mapW, mapH) --change to reflect collider now: checkBoundaries(self.x, self,y) 6/1/25

    if self.weapon then
        self.weapon:update(dt)
    end
end

function Player:move(dt)
    if self.isDashing then return end -- Don't process normal movement while dashing

    if self.isDead then return end -- stop all input once dead

    self.xVel = 0 
    self.yVel = 0 -- reset velocities for play/collider movement
    local newAnimation = nil
    local isMoving = false

    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        -- self.y = self.y - self.speed * dt
        self.yVel = -self.speed
        newAnimation = self.animations.up
        isMoving = true
    elseif love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        -- self.y = self.y + self.speed * dt
        self.yVel = self.speed
        newAnimation = self.animations.down
        isMoving = true
    end

    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        -- self.x = self.x - self.speed * dt
        self.xVel = -self.speed
        newAnimation = self.animations.left
        isMoving = true
    elseif love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        -- self.x = self.x + self.speed * dt
        self.xVel = self.speed
        newAnimation = self.animations.right
        isMoving = true
    end

    -- if love.keyboard.isDown("escape") then
    --     love.event.quit()
    -- end

    if isMoving == true then
        -- probably move entire movement logic in here
        local isMoving = true
        print('Player is moving.')
    end

    -- handle the speed up that happens when moving diagnolly, idk if this actually works yet lol 6/1/25
    -- might need 2 flags, one for x and y movement/moving instead
    if isMoving == true then
        local diagonalMovement = 1 / math.sqrt(2)
        self.xVel = self.xVel * diagonalMovement
        self.yVel = self.yVel * diagonalMovement
        print('DIAGONAL MOVEMENT: ' .. diagonalMovement) -- it's working, speed is .7071
    end

    -- utilizing velocity on the collider
    if self.collider then
        self.collider:setLinearVelocity(self.xVel, self.yVel)
        print('Player collider is set!')
    else
        print('DEBUG: Player collider is NIL in Player:move()!')
    end

    -- Animation switching (following enemy.lua pattern)
    if isMoving and newAnimation and self.currentAnimation ~= newAnimation then
        self.currentAnimation = newAnimation
        print("Switched to animation:", newAnimation == self.animations.up and "up" or 
            newAnimation == self.animations.down and "down" or
            newAnimation == self.animations.left and "left" or
            newAnimation == self.animations.right and "right" or "unknown" or
            newAnimation == self.animations.dash and "space" )
    elseif not isMoving and self.animations and self.animations.idle and self.currentAnimation ~= self.animations.idle then
        self.currentAnimation = self.animations.idle
        print("Player switched to idle.")
    end
end

function Player:checkBoundaries(mapW, mapH)
    local mapW = currentMap and currentMap.width * currentMap.tilewidth or love.graphics.getWidth()
    local mapH = currentMap and currentMap.height * currentMap.tileheight or love.graphics.getHeight()
    local newX, newY = self.x, self.y
    local halfWidth = self.width / 2
    local halfHeight = self.height / 2

    -- clamp player to map boundaries
    if self.x - halfWidth < 0 then newX = halfWidth end
    --if self.x + halfWidth > love.graphics.getWidth() then newX = love.graphics.getWidth() - halfWidth end
    if self.x + halfWidth > mapW then newX = mapW - halfWidth end
    if self.y - halfHeight < 0 then newY = halfHeight end
    -- if self.y + halfHeight > love.graphics.getHeight() then newY = love.graphics.getHeight() - halfHeight end
    if self.y + halfHeight > mapH then newY = mapH - halfHeight end

    if newX ~= self.x or newY ~= self.y then
        self.x = newX
        self.y = newY
        if self.collider then
            self.collider:setPosition(self.x, self.y)
            self.collider:setLinearVelocity(0,0) -- Stop movement if hitting boundary
        end
    end
    -- potentially apply corrections by teleporting the collider: self.collider:setPosition(newX, newY) if it goes out of bounds.
end

function Player:draw()
    -- world:draw()
    -- Reset color and shader before setting new ones (optional, but good practice)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()

    if self.isFlashing then
        love.graphics.setShader(flashShader)
            flashShader:send("WhiteFactor", 1.0)
            -- love.graphics.setColor(1, 1, 1, 1)
    elseif self.isInvincible then
        local time = love.timer.getTime()
        local alpha = math.floor(time / self.flashInterval) % 2 == 0 and 0.4 or 0.8
        love.graphics.setColor(1, 1, 1, alpha) -- transparent  
        -- love.graphics.setShader()
    end
    -- else
    --     love.graphics.setColor(1, 1, 1, 1) -- Normal (full color)
    --     love.graphics.setShader()
    -- end

    -- if self.currentAnimation and self.spriteSheet then
    --     -- love.graphics.setColor(1, 1, 1, 1)
    --     self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    -- elseif self.spriteSheet then
    --     -- Fallback: draw whole sheet if no currentAnimation
    --     -- love.graphics.setColor(1,1,1,1)
    --     love.graphics.draw(self.spriteSheet, self.x - self.spriteSheet:getWidth()/2, self.y - self.spriteSheet:getHeight()/2)
    -- else
    --     -- fallback to rectangle if animation/spritesheet fails
    --     -- love.graphics.setColor(1, 1, 1, 1)
    --     love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
    -- end

    -- -- dash drawing
    -- if self.currentAnimation == self.animations.dash and self.dashSpriteSheet then
    --     self.currentAnimation:draw(self.dashSpriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    -- elseif self.spriteSheet then
    --     self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    -- else
    --     love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
    -- end

    -- -- death drawing
    -- if self.currentAnimation == self.animations.death and self.soulsplodeSheet then
    --     self.currentAnimation:draw(self.soulsplodeSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    -- elseif self.spriteSheet then
    --     self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    -- else
    --     love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
    -- end
    local sheet = self.spriteSheet
    if self.currentAnimation == self.animations.dash then
        sheet = self.dashSpriteSheet
    elseif self.currentAnimation == self.animations.death then
        sheet = self.soulsplodeSheet
    end

    if self.currentAnimation and sheet then
        self.currentAnimation:draw(sheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    elseif self.spriteSheet then
        love.graphics.draw(self.spriteSheet, self.x - self.spriteSheet:getWidth()/2, self.y - self.spriteSheet:getHeight()/2)
    else
        love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
    end
    -- Draw your sprite as usual:
    -- self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)

    love.graphics.setColor(1, 1, 1, 1) -- color reset
    love.graphics.setShader()
end

-- dash logic
function Player:dash()
    -- Only allow dashing if not already dashing and cooldown is over
    if self.isDashing or self.dashCooldownTimer > 0 then return end

    -- Determine dash direction based on current movement or last input
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") or love.keyboard.isDown("up")    then dy = dy - 1 end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down")  then dy = dy + 1 end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left")  then dx = dx - 1 end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = dx + 1 end

    -- If no direction pressed, dash in last moved direction
    if dx == 0 and dy == 0 then
        dx, dy = self.lastDashDirection.x, self.lastDashDirection.y
    else
        self.lastDashDirection.x, self.lastDashDirection.y = dx, dy
    end

    -- Normalize direction
    local length = math.sqrt(dx*dx + dy*dy)
    if length == 0 then return end -- Can't dash with no direction
    dx, dy = dx / length, dy / length

    -- Set dash state
    self.isDashing = true
    self.dashTimer = self.dashDuration
    self.dashCooldownTimer = self.dashCooldown

    -- Set dash velocity
    if self.collider then
        -- set to dashing collider, phase through enemies
        -- self.type = 'player_dashing'
        self.collider:setCollisionClass('player_dashing')
        self.collider:setLinearVelocity(dx * self.dashSpeed, dy * self.dashSpeed)
    end
end

-- take damage, deal damage and direction
function Player:takeDamage(dmg, metaData, playerScore)
    print("DAMAGE TRIGGERED")
    if self.isDead or self.isInvincible then return end -- no more damage taken if dead

     -- maybe move this into Utils take damage later
     -- look into state machines 6/11/25
    self.isFlashing = true
    self.flashTimer = self.flashDuration

    self.isInvincible = true
    self.invincibleTimer = self.invincibleDuration

    self.health = self.health - dmg
    print(string.format("%s took %.2f damage. Health is now %.2f", self.name, dmg, self.health))
    print(string.format("Invincible: %s | Timer: %.2f", tostring(self.invincible), self.invincibleTimer))
    -- Utils.takeDamage(self, dmg)
    if self.health <= 0 then
        self:die(metaData, playerScore)
    end
end

-- build target logic and implement into player and enemy 5/26/25
function Player:dealDamage(target, dmg)
    Utils.dealDamage(self, target, dmg)
end

function Player:die(metaData, playerScore)
    metaData.highScore = math.max(metaData.highScore, playerScore)

    SaveSystem.highScore = math.max(metaData.highScore, playerScore)
    SaveSystem.resetRun(runData, metaData)  -- Reset current run
    -- Gamestate.switch(gameOver) -- TODO: implement gameOver gamestate

    if self.isDead then return end

    self.isDead = true
    self.isInvincible = false
    self.isFlashing = false

    Utils.die(self)
    print("You are dead!/nGame Over.")

    -- remove from world and/or active enemy table
    if self.collider then
        print("Attempting to destroy collider for: " .. self.name)
        self.collider:setLinearVelocity(0, 0) -- stops collider from moving if player dies while moving
        self.collider:destroy()
        self.collider = nil -- set collider to nil
        print(self.name .. " collider is destroyed!")
    else
        print(self.name .. "had no collider or it was already nil.")
    end

    -- death animation and effects go here
    if self.animations and self.animations.death then
        self.currentAnimation = self.animations.death
        self.currentAnimation:gotoFrame(1)
        self.currentAnimation:resume() -- Make sure it plays
    end

    -- drop loot on death
    local drop = Loot.createWeaponDropFromInstance(player.weapon, dropX, dropY)
    table.insert(droppedItems, drop)

     -- Set death timer for game over transition
    self.deathTimer = 2.0  -- x seconds to show death animation, change based on sprite/animation
end

function Player:addItem(item)
    table.insert(self.inventory, item)
end

function Player:dropItem(item)
    -- find and drop item/weapon from inventory
    for i, invItem in ipairs(self.inventory) do
        -- if inventory item equals an item/weapon in player inventory then remove from table
        if invItem == item then
            table.remove(self.inventory, i)
            break -- get out of loop, your work here is done
        end
    end
    -- spawn item into the world at players feet, for now
    Loot.createWeaponDropFromInstance(item, self.x, self.y)
end

-- call on pickups, level ups, shop upgrades, modifiers/buffs and scripted events
function Player:updateEquipmentInventory()
    if not self.weapon then return end

    for i, item in ipairs(self.inventory) do
    if item.name == self.weapon.name and item.weaponType == self.weapon.weaponType then
        item.level = self.weapon.level
        item.baseDamage = self.weapon.baseDamage
        item.fireRate = self.weapon.fireRate
        -- revisit to add other fields as I see fit
        break
    end
end

end

function Player:triggerGameOver()
    -- Transition to game over screen, restart, or respawn, etc
    print("Game Over! Final Score: " .. playerScore)
    -- Add in game over logic
end

return Player

-- The player/enemy might have other attributes (like strength, skill levels, buffs, debuffs) that modify the base damage from the weapon or projectile.
-- The calculation final_dmg = weapon_dmg + attacker_bonus_dmg would happen in player.lua or enemy.lua before calling the shared utility.