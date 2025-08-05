local Utils = require("utils")
local Debug = require("game_debug")
local anim8 = require("libraries/anim8")
local wf = require "libraries/windfield"
local flashShader = require("libraries/flashshader")
local Loot = require("loot")

local Enemy = {}
Enemy.__index = Enemy

local enemyIDCounter = 0
local defaultDropChance = 0.5

function Enemy:new(passedWorld, name, x, y, width, height, xVel, yVel, health, speed, baseDamage, xpAmount, spriteImage)
    enemyIDCounter = enemyIDCounter + 1
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
        xpAmount = xpAmount or 10,
        
        enemyID = enemyIDCounter,

        spriteSheet = spriteImage, -- add sprite later on, possibly in main.lua find a test sprite to use
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
        isMoving = false,

        isFlashing = false,
        flashTimer = 0,
        flashDuration = 0.12, -- seconds, tweak as needed

        isKnockedBack = false,
        knockbackTimer = 0
    }

    Debug.debugPrint("DEBUG: Enemy:new - Instance name:", instance.name, " Health:", instance.health, "Speed:", instance.speed, "Type of speed:", type(instance.speed), 
    "Damage:", instance.baseDamage)
    setmetatable(instance, {__index = Enemy}) -- Enemy methods and fields/data will get looked up

    -- if sprite then
    --     local success, image_or_error = pcall(function() return love.graphics.newImage(sprite) end)
    --     if success then
    --         instance.spriteSheet = image_or_error -- This is your first line: self.spriteSheet = ...
    --         Debug.debugPrint("Enemy spritesheet loaded successfully from:", sprite)

    --         local frameWidth = instance.spriteSheet:getWidth() / 3  -- Width of one animation frame
    --         local frameHeight = instance.spriteSheet:getHeight() / 4 -- Height of one animation frame

    --         instance.width = frameWidth
    --         instance.height = frameHeight
    --         Debug.debugPrint(string.format("Enemy frame dimensions set: W=%.1f, H=%.1f", instance.width, instance.height))

    --         local grid = anim8.newGrid(frameWidth, frameHeight, 
    --                                    instance.spriteSheet:getWidth(), instance.spriteSheet:getHeight())

    --         instance.animations.idle = anim8.newAnimation(grid('1-3', 1), 0.30)
    --         instance.animations.walk = anim8.newAnimation(grid('1-3', 2), 0.30)
    --         instance.animations.death = anim8.newAnimation(grid('1-3', 4), 0.1)

    --         if instance.animations.death then
    --             instance.animations.death:onLoop(function(anim) anim:pauseAtEnd() end)
    --         end

    --         -- Set the initial animation to play
    --         instance.currentAnimation = instance.animations.idle 
    --         if instance.currentAnimation then
    --             Debug.debugPrint("Enemy animations created. Default animation set to 'idle'.")
    --         else
    --             Debug.debugPrint("Warning: Could not set default animation 'idle'. Check animation definition.")
    --         end

    --         else
    --             Debug.debugPrint(string.format("ERROR: Failed to load enemy spritesheet from path '%s'. Error: %s", sprite, tostring(image_or_error)))
    --         end

    --         else
    --             Debug.debugPrint("DEBUG: No spritesheet path provided for enemy:", instance.name)
    -- end

    if instance.spriteSheet then
        local frameWidth = instance.spriteSheet:getWidth() / 3 -- Width of one animation frame
        local frameHeight = instance.spriteSheet:getHeight() / 4 -- Height of one animation frame

        instance.width = frameWidth
        instance.height = frameHeight
        Debug.debugPrint(string.format("Enemy frame dimensions set: W=%.1f, H=%.1f", instance.width, instance.height))

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
            Debug.debugPrint("Enemy animations created. Default animation set to 'idle'.")
        else
            Debug.debugPrint("Warning: Could not set default animation 'idle'. Check animation definition.")
        end
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

function Enemy:reset(x, y, blob, img)
    assert(img, "[ENEMY:RESET] Tried to reset enemy with nil image!")
    self.x = x
    self.y = y
    self.name = blob.name
    self.health = blob.health
    self.speed = blob.speed
    self.baseDamage = blob.baseDamage
    self.xpAmount = blob.xpAmount
    self.spriteSheet = img
    self.isDead = false
    self.toBeRemoved = false
    self.isFlashing = false

     -- Reinitialize animations safely
    if img then  -- Use the new img parameter instead of self.spriteSheet
        self.spriteSheet = img
        local frameWidth = math.floor(self.spriteSheet:getWidth() / 3)
        local frameHeight = math.floor(self.spriteSheet:getHeight() / 4)
        local grid = anim8.newGrid(frameWidth, frameHeight, 
                                  self.spriteSheet:getWidth(), 
                                  self.spriteSheet:getHeight())
        self.width = frameWidth
        self.height = frameHeight
        self.animations = {
            idle = anim8.newAnimation(grid('1-3', 1), 0.30),
            walk = anim8.newAnimation(grid('1-3', 2), 0.30),
            death = anim8.newAnimation(grid('1-3', 4), 0.1)
        }
        
        if self.animations.death then
            self.animations.death:onLoop(function(anim) anim:pauseAtEnd() end)
        end
        
        self.currentAnimation = self.animations.idle
        -- call new animations start at frame 1
    else
        -- Debug.debugPrint("[ENEMY:RESET] No image provided for: " .. self.name)
        self.animations = {}
        self.currentAnimation = nil
    end

    -- Reinitialize collider
    local colliderWidth = self.width
    local colliderHeight = self.height
    if not self.collider then
        self:load()
        -- -- Create collider centered at (self.x, self.y)
        -- self.collider = self.world:newBSGRectangleCollider(
        --     self.x - colliderWidth / 2,
        --     self.y - colliderHeight / 2,
        --     colliderWidth,
        --     colliderHeight,
        --     10
        -- )
        -- self.collider:setFixedRotation(true)
        -- self.collider:setUserData(self)
        -- self.collider:setCollisionClass('enemy')
        -- self.collider:setObject(self)
    else
        -- Move collider's center to (x, y)
        self.collider:setPosition(x, y)
        self.collider:setActive(true)
    end
end

-- function Enemy.getEnemyPool()
--     return #enemyPool -- Return the enemy pool, or an empty table if not set
-- end

function Enemy:load()
    local colliderHeight = self.height
    local colliderWidth = self.width
    -- set it up with self so each enemy instance has their own collider
    self.collider = self.world:newBSGRectangleCollider(
        self.x - colliderWidth/2, 
        self.y - colliderHeight/2, 
        colliderWidth, 
        colliderHeight, 
        10
    )
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- associate enemy obj w/ collider
    Debug.debugPrint("DEBUG: ENEMY collider created with W: "..self.width.."and H: "..self.height)
    self.collider:setCollisionClass('enemy')
    -- self.collider:setMask('player', 'wall') -- Enemies collide with player, walls
    self.collider:setObject(self)
end

function Enemy:setTarget(Player)
    self.target = Player -- sets the player instance as the enemy target
end

function Enemy:isNearPlayer(buffer)
    buffer = buffer or 500
    if not self.target then return false end
    local dx = self.x - self.target.x
    local dy = self.y - self.target.y
    local distanceSquared = dx * dx + dy * dy
    return distanceSquared <= buffer * buffer
end

function Enemy:AILogic(dt)
    if not self.target then return end

    -- AI: Decide movement direction/velocity
    if self.target then
        -- Calculate direction vector from self to target
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y

        -- Normalize the direction vector (to get a unit vector)
        local distance = math.sqrt(dx*dx + dy*dy)

        if distance > 0.1 then -- Only move if not already at the target's exact position
            self.isMoving = true
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
end

function Enemy:update(dt, frameCount) 
    -- update animations even on skipped frames
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end

    -- frame count/slicing
    if not self.enemyID then
        Debug.debugPrint("[ERROR] enemyID is nil for", tostring(self.name))
        return
    end

    -- throttle enemy AI logic
    local id = self.enemyID or 1
    local throttle = 2
    if math.fmod(id, throttle) ~= math.fmod(frameCount, throttle) then
        return
    end

    -- self:move(dt)
    if self.isKnockedBack then
        self.knockbackTimer = self.knockbackTimer - dt
        if self.knockbackTimer <= 0 then
            self.isKnockedBack = false
        end
        return -- Skip normal AI movement logic while knocked back
    end

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
        Debug.debugPrint("UPDATE_NO_COLLIDER: self is", tostring(self), "name:", (self and self.name or "N/A"))
        return 
    end -- If collider somehow got removed early

     -- Update current animation (if it exists)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end

    Debug.debugPrint("DEBUG: Enemy:update: " .. "Name:", self.name, "Speed:", self.speed, "Type of speed:", type(self.speed), "Damage:", self.baseDamage)

        -- Switch animation based on state
        if self.isMoving and self.animations and self.animations.walk and self.currentAnimation ~= self.animations.walk then
            self.currentAnimation = self.animations.walk
        elseif not self.isMoving and self.animations and self.animations.idle and self.currentAnimation ~= self.animations.idle then
            self.currentAnimation = self.animations.idle
        end
    -- Enemy.collider:setLinearVelocity(self.xVel, self.yVel)

    -- self.world:update(dt)

    -- update these based on its collider AFTER world:update() 5/30/25
    -- consider updating x, y in a seperate 'post_physics_update' or before drawing
    -- self.x = self.collider:getX()
    -- self.y = self.collider:getY()

    self.x, self.y = self.collider:getPosition()
    -- local cur_x, cur_y = self.collider:getPosition()
    -- self.x = cur_x
    -- self.y = cur_y

    if self.currentAnimation and self.currentAnimation.update then
        self.currentAnimation:update(dt)
    end

    -- pursue
    if self:isNearPlayer(500) then
        self:AILogic(dt)
    else
        self.collider:setLinearVelocity(0, 0)
        self.isMoving = false
        -- idle
        if self.animations and self.animations.idle then
            self.currentAnimation = self.animations.idle
        end
    end
end

function Enemy:draw()
    if self.currentAnimation and self.spriteSheet then
        if self.isFlashing then
            love.graphics.setShader(flashShader)
            flashShader:send("WhiteFactor", 1.0)
        end
        
        -- Draw centered: self.x, self.y are center; anim8 draws from top-left by default
        -- So, we need to offset by half the frame width/height.
        -- self.width and self.height should be the frame dimensions.

        -- Draw normally (batched or individual)
        self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)

        if self.isFlashing then
            love.graphics.setShader() -- ensures that only the enemy flashes
        end

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
end

-- take damage, deal damage and direction
function Enemy:takeDamage(dmg, killer)
    if self.isDead or self.isFlashing then return end -- no more damage taken if dead or if already flashing

    self.isFlashing = true
    self.flashTimer = self.flashDuration

    -- Utils.takeDamage(self, dmg)
    self.health = self.health - dmg
    Debug.debugPrint(self.name .. " was hit! Flash on hit activated")
    Debug.debugPrint(string.format("%s took %.2f damage. Health is now %.2f", self.name, dmg, self.health))
    if self.health <= 0 then
        self:die(killer)
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

function Enemy:die(killer)
    if self.isDead then return end

    Debug.debugPrint(self.name .. " almost dead, preparing to call Utils.die()!")
    self.isDead = true

    Utils.die(self, killer)

    if math.random() < (self.shardDropChance or defaultDropChance) then
        table.insert(droppedItems, Loot.createShardDrop(self.x, self.y))
    end

    if self.collider then
        Debug.debugPrint("Attempting to destroy collider for: " .. self.name)
        self.collider:destroy()
        self.collider = nil -- set collider to nil
        Debug.debugPrint(self.name .. " collider is destroyed!")
    else
        Debug.debugPrint(self.name .. "had no collider or it was already nil.")
    end
    -- death animation and effects go here
    if self.animations and self.animations.death then
        self.currentAnimation = self.animations.death
        self.currentAnimation:resume() -- Make sure it plays
    end

    self.toBeRemoved = true -- flag for removal from 'enemies' table in main.lua
    Debug.debugPrint(self.name .. " flagged for removal!")
    -- remove from world and/or active enemy table
end

function Enemy:getName()
    return self.name
end

function Enemy:Taunt()
    Debug.debugPrint("I am the enemy!")
end

return Enemy

-- use tables to store and manage multiple enemy instances. Iterate through table to update and draw each enemy
-- randomize enemy spawn patterns, makes things less predictable. Either love.math.random (love.math.RandomSeed(os.time())) for resutl variety
-- FUTURE, difficulty scaling