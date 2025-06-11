local Weapon = require("weapon")
local Projectile = require("projectile")
local Utils = require("utils")
local anim8 = require "libraries/anim8"
local wf = require "libraries/windfield"
local flashShader = require "libraries/flashshader"

local Player = {} -- one global player object based on current singleton setup, but local to the module making it not global in use
Player.__index = Player -- rereference for methods from instances

function Player:load(passedWorld, sprite_path)
    love.graphics.setDefaultFilter("nearest", "nearest")

    self.name = "Player"
    self.x = 60
    self.y = love.graphics.getHeight() / 3
    self.width = 32
    self.height = 32
    self.type = "player"
    self.world = passedWorld

    self.frameWidth = 32
    self.frameHeight = 32

    self.spriteSheet = nil
    self.animations = {}
    self.currentAnimation = nil

    -- flags for death and removal upon death
    self.isDead = false

    self.isFlashing = false
    self.flashTimer = 0
    self.flashDuration = 0.12
    self.flashInterval = 0.1

    -- flags for invincibilty frames after damage and isFlashing

    self.isInvincible = false
    self.invincibleDuration = 1.0
    self.invincibleTimer = 0

    -- Load sprite sheet if path provided (following enemy.lua pattern exactly)
    if sprite_path then
        local success, image_or_error = pcall(function() return love.graphics.newImage(sprite_path) end)
        if success then
            self.spriteSheet = image_or_error
            print("Player spritesheet loaded successfully from:", sprite_path)
            
            -- Calculate frame dimensions (like enemy.lua does)
            -- Based on mage-NESW.jpg, it appears to be 4 columns (frames per direction) and 4 rows (directions)
            local frameWidth = self.spriteSheet:getWidth() / 3   -- 4 frames per direction
            local frameHeight = self.spriteSheet:getHeight() / 4 -- 4 directions (down, left, right, up)
            
            self.width = frameWidth
            self.height = frameHeight
            print(string.format("Player frame dimensions set: W=%.1f, H=%.1f", self.width, self.height))
            
            -- Create anim8 grid (following enemy.lua pattern exactly)
            self.grid = anim8.newGrid(frameWidth, frameHeight, 
                                       self.spriteSheet:getWidth(), self.spriteSheet:getHeight())
        
        self.animations.idle = anim8.newAnimation(self.grid('1-3', 3), 0.2) -- Example
        self.animations.down = anim8.newAnimation(self.grid('1-3', 3), 0.2) -- Example, adjust frames
        self.animations.up = anim8.newAnimation(self.grid('1-3', 1), 0.2)   -- Example, adjust frames
        self.animations.left = anim8.newAnimation(self.grid('1-3', 4), 0.2) -- Example, adjust frames
        self.animations.right = anim8.newAnimation(self.grid('1-3', 2), 0.2)-- Example, adjust frames

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

    self.collider = self.world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 10)
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- link player collider back to player
    self.collider:setCollisionClass('player')
    self.collider:setObject(self)

    self.baseDamage = 1
    self.health = 100
    self.speed = 300
    self.xVel = 0
    self.yVel = 0
    self.weapon = Weapon:new(2, Projectile, 15) -- fireRate, projectileClass, baseDamage class params/args from Weapon class
end

function Player:update(dt)
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
        if self.invincibleTimer <= 0 then
            self.isInvincible = false
            self.invincibleTimer = 0
        end
    end

    if self.currentAnimation then
        self.currentAnimation:update(dt) -- updates current sprite active animation
    end

    if self.collider then
        self.x, self.y = self.collider:getPosition()
    end

    self:checkBoundaries() --change to reflect collider now: checkBoundaries(self.x, self,y) 6/1/25
    self.weapon:update(dt)
end

function Player:move(dt)
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

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end

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
            newAnimation == self.animations.right and "right" or "unknown")
    elseif not isMoving and self.animations and self.animations.idle and self.currentAnimation ~= self.animations.idle then
        self.currentAnimation = self.animations.idle
        print("Player switched to idle.")
    end
end

function Player:checkBoundaries()
    local newX, newY = self.x, self.y
    local halfWidth = self.width / 2
    local halfHeight = self.height / 2

    if self.x - halfWidth < 0 then newX = halfWidth end
    if self.x + halfWidth > love.graphics.getWidth() then newX = love.graphics.getWidth() - halfWidth end
    if self.y - halfHeight < 0 then newY = halfHeight end
    if self.y + halfHeight > love.graphics.getHeight() then newY = love.graphics.getHeight() - halfHeight end

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
    world:draw()
    if self.isFlashing then
        love.graphics.setShader(flashShader)
            flashShader:send("WhiteFactor", 1.0)
    elseif self.isInvincible then
        local time = love.timer.getTime()
        local alpha = math.floor(time / self.flashInterval) % 2 == 0 and 0.4 or 0.8
        love.graphics.setColor(1, 1, 1, alpha) -- transparent  
    end
        love.graphics.setColor(1, 1, 1, 1) -- Normal (full color)

    if self.currentAnimation and self.spriteSheet then
        love.graphics.setColor(1, 1, 1, 1)
        self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
    elseif self.spriteSheet then
        -- Fallback: draw whole sheet if no currentAnimation
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(self.spriteSheet, self.x - self.spriteSheet:getWidth()/2, self.y - self.spriteSheet:getHeight()/2)
    else
        -- fallback to rectangle if animation/spritesheet fails
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
    end

    -- Draw your sprite as usual:
    self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)

    love.graphics.setColor(1, 1, 1, 1) -- color reset
    love.graphics.setShader()
end

-- take damage, deal damage and direction
function Player:takeDamage(dmg)
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
        self.die(self)
    end
end

-- build target logic and implement into player and enemy 5/26/25
function Player:dealDamage(target, dmg)
    Utils.dealDamage(self, target, dmg)
end

function Player:die()
    if self.isDead then return end

    self.isDead = true

    Utils.die(self)
    -- print("You are dead!/nGame Over.")
    -- remove from world and/or active enemy table
    if self.collider then
        print("Attempting to destroy collider for: " .. self.name)
        self.collider:destroy()
        self.collider = nil -- set collider to nil
        print(self.name .. " collider is destroyed!")
    else
        print(self.name .. "had no collider or it was already nil.")
    end
    -- death animation and effects go here
    if self.animations and self.animations.death then
        self.currentAnimation = self.animations.death
        self.currentAnimation:resume() -- Make sure it plays
    end
end

return Player

-- The player/enemy might have other attributes (like strength, skill levels, buffs, debuffs) that modify the base damage from the weapon or projectile.
-- The calculation final_dmg = weapon_dmg + attacker_bonus_dmg would happen in player.lua or enemy.lua before calling the shared utility.