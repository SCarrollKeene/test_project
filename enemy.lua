local Utils = require("utils")
local anim8 = require("libraries/anim8")
local wf = require "libraries/windfield"
local flashShader = require "libraries/flashshader"

local Enemy = {}
Enemy.__index = Enemy

function Enemy:new(passedWorld, name, x, y, width, height, xVel, yVel, health, speed, baseDamage, sprite)
    local instance = {
        name = name or "Enemy",
        x = x or 0,
        y = y or 0,
        width = width or 25,
        height = height or 25,
        xVel = xVel or 0,
        yVel = yVel or 0,
        health = health or 40,
        speed = speed or 40,
        baseDamage = baseDamage or 5,

        spriteSheet = nil, -- add sprite later on, possibly in main.lua find a test sprite to use
        animations = {},
        currentAnimation = nil,

        timer = 0,
        rate = 0.5,

        type = "enemy",

        -- passing global world from main.lua
        world = passedWorld,

        -- flags for death and removal upon death
        isDead = false,
        toBeRemoved = false,

        isFlashing = false,
        flashTimer = 0,
        flashDuration = 0.12 -- seconds, tweak as needed
    }

    print("DEBUG: Enemy:new - Instance name:", instance.name, " Health:", instance.health, "Speed:", instance.speed, "Type of speed:", type(instance.speed), 
    "Damage:", instance.baseDamage)
    setmetatable(instance, {__index = Enemy}) -- Enemy methods and fields/data will get looked up

    if sprite then
        local success, image_or_error = pcall(function() return love.graphics.newImage(sprite) end)
        if success then
            instance.spriteSheet = image_or_error -- This is your first line: self.spriteSheet = ...
            print("Enemy spritesheet loaded successfully from:", sprite)

            local frameWidth = instance.spriteSheet:getWidth() / 3  -- Width of one animation frame
            local frameHeight = instance.spriteSheet:getHeight() / 4 -- Height of one animation frame

            instance.width = frameWidth
            instance.height = frameHeight
            print(string.format("Enemy frame dimensions set: W=%.1f, H=%.1f", instance.width, instance.height))

            local grid = anim8.newGrid(frameWidth, frameHeight, 
                                       instance.spriteSheet:getWidth(), instance.spriteSheet:getHeight())

            instance.animations.idle = anim8.newAnimation(grid('1-3', 1), 0.30)
            instance.animations.walk = anim8.newAnimation(grid('1-3', 2), 0.30)
            instance.animations.death = anim8.newAnimation(grid('1-3', 4), 0.1)

            if instance.animations.death then
                instance.animations.death:onLoop(function(anim) anim:pauseAtEnd() end)
            end

            -- Set the initial animation to play
            instance.currentAnimation = instance.animations.idle 
            if instance.currentAnimation then
                print("Enemy animations created. Default animation set to 'idle'.")
            else
                print("Warning: Could not set default animation 'idle'. Check animation definition.")
            end

            else
                print(string.format("ERROR: Failed to load enemy spritesheet from path '%s'. Error: %s", sprite, tostring(image_or_error)))
            end

            else
                print("DEBUG: No spritesheet path provided for enemy:", instance.name)
    end

    -- Call this AFTER sprite is loaded and width/height are potentially updated
    instance:load() -- initialize the collider instance after creating the instance? Is it done like this for other colliders? -- need to revisit this 5/28/25
    return instance

end

-- Needs functionality like drawing the enemy on screen and jumping/attacking
-- Chasing - move towards player x/y coordinates by comparing both of their x/y posiitons
-- State machine / behavior tree: idle, pursuing, patrolling, attacking and DEBUG: FAILED, returned NIL, Cooldown might be active or other issue in shoot.
-- Enable enemies the ability to perceive their environment, query player position in order to determine actions like movement direction/attacking
-- Obstacle collision and avoidance, bump.lua
-- Line of Sight (LOS), navigate around obstacles, check for walls/gaps, example: MP_potential_step (like in Gamemaker) or tile based pathfinding

function Enemy:load()
    local colliderHeight = self.height * 0.8 -- used to reduce blob collider height
    local colliderWidth = self.width * 0.7
    local yOffset = 4
    local xOffset = 4
    -- set it up with self so each enemy instance has their own collider
    self.collider = self.world:newBSGRectangleCollider(
        self.x + (self.width - colliderWidth)/2, 
        self.y + (self.height - colliderHeight)/2, 
        colliderWidth, 
        colliderHeight, 
        10
    )

    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- associate enemy obj w/ collider
    self.collider:setObject(self)
    print("DEBUG: ENEMY collider created with W: "..self.width.."and H: "..self.height)
    
    self.collider:setCollisionClass('enemy')
    -- self.collider:setMask('player', 'wall') -- Enemies collide with player, walls
end

function Enemy:setTarget(Player)
    self.target = Player -- sets the player instance as the enemy target
end

function Enemy:update(dt)
    -- self:move(dt)
    if self.isDead then
         if self.animations and self.animations.death and self.currentAnimation ~= self.animations.death then
            self.currentAnimation = self.animations.death
            if self.currentAnimation then self.currentAnimation:resume() end
        end
        if self.currentAnimation then
            self.currentAnimation:update(dt)
            -- If death animation finished, you might set toBeRemoved = true here or another flag
        end
        return
    end

    if self.isFlashing then
    self.flashTimer = self.flashTimer - dt
        if self.flashTimer <= 0 then
            self.isFlashing = false
            self.flashTimer = 0
        end
    end

    if not self.collider then 
        print("UPDATE_NO_COLLIDER: self is", tostring(self), "name:", (self and self.name or "N/A"))
        return 
    end -- If collider somehow got removed early

     -- Update current animation (if it exists)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end

    print("DEBUG: Enemy:update - Self name:", self.name, "Speed:", self.speed, "Type of speed:", type(self.speed), "Damage:", self.baseDamage)

    local isMoving = false
    -- AI: Decide movement direction/velocity
    if self.target then
        -- Calculate direction vector from self to target
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y

        -- Normalize the direction vector (to get a unit vector)
        local distance = math.sqrt(dx*dx + dy*dy)

        if distance > 0.1 then -- Only move if not already at the target's exact position
            isMoving = true
            local dirX = dx / distance
            local dirY = dy / distance

            -- Update position based on direction and speed
            -- self.x = self.x + dirX * self.speed * dt
            -- self.y = self.y + dirY * self.speed * dt

            self.collider:setLinearVelocity(dirX * self.speed, dirY * self.speed)
        else
            self.collider:setLinearVelocity(0, 0)
        end

        else
            self.collider:setLinearVelocity(0, 0)
        end
            -- Alternatively, if you prefer using xVel/yVel:
            -- self.xVel = dirX * self.speed
            -- self.yVel = dirY * self.speed

        -- No target? Default behavior (e.g., patrol, stay idle, or move randomly)
        -- For now, if no target, it will not move based on target logic.
        -- You could, for example, make it move slowly to the left:
        
        -- self.x = self.x - (self.speed * 0.25) * dt
        -- self.xvel = (self.speed * 0.25) * dt
        -- Switch animation based on state
        if isMoving and self.animations and self.animations.walk and self.currentAnimation ~= self.animations.walk then
            self.currentAnimation = self.animations.walk
        elseif not isMoving and self.animations and self.animations.idle and self.currentAnimation ~= self.animations.idle then
            self.currentAnimation = self.animations.idle
        end
    -- Enemy.collider:setLinearVelocity(self.xVel, self.yVel)

    -- self.world:update(dt)

    -- update these based on its collider AFTER world:update() 5/30/25
    -- consider updating x, y in a seperate 'post_physics_update' or before drawing
    -- self.x = self.collider:getX()
    -- self.y = self.collider:getY()

    -- self.x, self.y = self.collider:getPosition()
    local cur_x, cur_y = self.collider:getPosition()
    self.x = cur_x
    self.y = cur_y

    self.currentAnimation:update(dt)
end

--  function Enemy:move(dt)
--      self.x = self.x - self.speed * dt -- move left
--      self.x = self.x + self.speed * dt -- move right 
--      self.y = self.y - self.speed * dt -- move up
--      self.y = self.y + self.speed * dt -- move down
--  end

function Enemy:draw()
    if self.currentAnimation and self.spriteSheet then
        if self.isFlashing then
        love.graphics.setShader(flashShader)
            flashShader:send("WhiteFactor", 1.0)
        else
            love.graphics.setShader()
        end
        love.graphics.setColor(1,1,1,1) -- Ensure sprite is drawn with full color
        -- Draw centered: self.x, self.y are center; anim8 draws from top-left by default
        -- So, we need to offset by half the frame width/height.
        -- self.width and self.height should be the frame dimensions.
        self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)

        love.graphics.setShader() -- Always reset after drawing

    elseif self.spriteSheet then
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(self.spriteSheet, self.x - self.spriteSheet:getWidth()/2, self.y - self.spriteSheet:getHeight()/2)
    else
        -- love.graphics.push()
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.circle("fill", self.x, self.y, self.width, self.height)
    end
        love.graphics.setColor(1, 1, 1, 1) -- color reset
        -- love.graphics.pop()
        -- self.world:draw()
end

-- take damage, deal damage and direction
function Enemy:takeDamage(dmg)
    if self.isDead then return end -- no more damage taken if dead

    self.isFlashing = true
    self.flashTimer = self.flashDuration

    -- Utils.takeDamage(self, dmg)
    self.health = self.health - dmg
    print(string.format("%s took %.2f damage. Health is now %.2f", self.name, dmg, self.health))
    if self.health <= 0 then
        self:die()
    end
end

-- build target logic and implement into player and enemy 5/26/25
function Enemy:dealDamage(target, dmg)
    Utils.dealDamage(self, target, dmg)

    -- moved this to Utils.dealDamage
    -- if target and target.takeDamage() then
    --     target:takeDamage(dmg)
    -- end
end

function Enemy:die()
    if self.isDead then return end

    print(self.name .. " almost dead, preparing to call Utils.die()!")
    self.isDead = true

    Utils.die(self)

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

    self.toBeRemoved = true -- flag for removal from 'enemies' table in main.lua
    print(self.name .. " flagged for removal!")
    -- remove from world and/or active enemy table
end

function Enemy:getName()
    return self.name
end

function Enemy:Taunt()
    print("I am the enemy!")
end

return Enemy

-- use tables to store and manage multiple enemy instances. Iterate through table to update and draw each enemy
-- randomize enemy spawn patterns, makes things less predictable. Either love.math.random (love.math.RandomSeed(os.time())) for resutl variety
-- FUTURE, difficulty scaling