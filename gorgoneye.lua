local Assets = require("assets")
local CamManager = require("cam_manager")
local UI = require("ui")
local Utils = require("utils")
local Enemy = require("enemy")
local EnemyAI = require("enemy_ai")
local Projectile = require("projectile")
local projectiles = require("projectile_store")
local Debug = require("game_debug")
local anim8 = require("libraries/anim8")
local wf = require("libraries/windfield")
local flashShader = require("libraries/flashshader")
local Loot = require("loot")

local Gorgoneye = {}
Gorgoneye.__index = Gorgoneye

setmetatable(Gorgoneye, { __index = Enemy })

local defaultDropChance = 0.5
local potionDropChance = 0.10

function Gorgoneye:new(fields)
    fields = fields or {}

    local spr = fields.spriteSheet or Assets.images.gorgoneye
    assert(spr, "Gorgoneye spriteSheet is nil!")

    -- Animmation dimensions 1x4 grid
    local frameWidth, frameHeight = 36, 36
    local sheetW, sheetH = 36, 144

    -- Use the base Enemy constructor
    local instance = Enemy:new {
        world = fields.world,
        name = fields.name or "Gorgoneye",
        x = fields.x or 0,
        y = fields.y or 0,
        width = frameWidth,
        height = frameHeight,
        maxHealth = fields.maxHealth or 80,
        health = fields.maxHealth or 80,
        speed = fields.speed or 30,
        baseDamage = fields.baseDamage or 20,    -- baseDamage
        xpAmount = fields.xpAmount or 30,
        spriteSheet = spr
    }
    setmetatable(instance, Gorgoneye)

    -- Gorgoneye AI state
    instance.xVel = 0
    instance.yVel = 0

    instance.enemyType = "gorgoneye"

    instance.patrolRange      = 120
    instance.patrolOriginXPos = x or 0
    instance.patrolDirection  = 1
    instance.player           = nil
    instance.awarenessRange   = 200
    instance.shootInterval    = 2.2
    instance.shootCooldown    = 0

    instance.spriteSheet      = spr
    instance.width            = frameWidth
    instance.height           = frameHeight

    -- Gorgoneye animations: 4 facing, 1 frame each
    local grid = anim8.newGrid(frameWidth, frameHeight, sheetW, sheetH)
    instance.animations = {
        left  = anim8.newAnimation(grid(1, 1), 1),
        right = anim8.newAnimation(grid(1, 2), 1),
        down  = anim8.newAnimation(grid(1, 3), 1),
        up    = anim8.newAnimation(grid(1, 4), 1),
    }
    instance.currentAnimation = instance.animations.left

    return instance
end

function Gorgoneye:reset(x, y, def, img)
    assert(img, "[GORGONEYE:RESET] Tried to reset enemy with nil image!")
    --print("Resetting Gorgoneye with spriteSheet:", img, "Width:", img:getWidth(), "Height:", img:getHeight())

    -- Pool-respawn logic, which matches your Enemy.reset pattern
    -- Base logic: core vars, collider from Enemy base class
    self:baseReset(x, y, def, img)

    -- Gorgoneye specific movement, animations, AI logic
    self.xVel = 0
    self.yVel = 0

    if img then
        self.spriteSheet = img
        local frameWidth, frameHeight, sheetW, sheetH = 36, 36, 36, 144
        local grid = anim8.newGrid(frameWidth, frameHeight, sheetW, sheetH)

        self.width = frameWidth
        self.height = frameHeight
        self.animations = {
            left  = anim8.newAnimation(grid(1, 1), 1),
            right = anim8.newAnimation(grid(1, 2), 1),
            down  = anim8.newAnimation(grid(1, 3), 1),
            up    = anim8.newAnimation(grid(1, 4), 1),
        }

        if self.animations.death then
            self.animations.death:onLoop(function(anim) anim:pauseAtEnd() end)
        end
        self.currentAnimation = self.animations.left
        -- TODO: reset AI logic state 8/19/25

        self.patrolRange = 120
        self.patrolOriginXPos = x
        self.patrolDirection  = 1
        self.player = nil
        
        self.awarenessRange = 200
        self.shootInterval = 2.2
        self.shootCooldown = 0

    else
        -- Debug.debugPrint("[ENEMY:RESET] No image provided for: " .. self.name)
        self.animations = {}
        self.currentAnimation = nil
    end
    -- Reinitialized collider from base Enemy class
end

function Gorgoneye:load()
    -- Create collider for this enemy type
    local colliderHeight = self.height
    local colliderWidth = self.width
    self.collider = self.world:newBSGRectangleCollider(
        self.x - colliderWidth/2, 
        self.y - colliderHeight/2, 
        colliderWidth, colliderHeight, 
        10
    )
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self)
    --print("DEBUG: GORGONEYE collider created with W: "..self.width.." and H: "..self.height)
    self.collider:setCollisionClass('enemy')
    self.collider:setObject(self)
end

function Gorgoneye:setTarget(player)
    self.target = player
    self.player = player
end

function Gorgoneye:updateAI(dt)
    if not self.player then return end
    local dx, dy = self.x - self.player.x, self.y - self.player.y
    local playerDist = math.sqrt(dx*dx + dy*dy)
    if playerDist <= self.awarenessRange then
        -- Shoot at player, but don't chase!
        EnemyAI.shootAtPlayer(self, dt, projectiles)
        self.xVel = self.xVel or 0
        self.yVel = self.yVel or 0
    else
        -- Patrol logic
        EnemyAI.patrolArea(self, dt, self.patrolRange, nil, "both")
    end
end

function Gorgoneye:update(dt, frameCount)
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

    if self.isKnockedBack then
        self.knockbackTimer = self.knockbackTimer - dt
        if self.knockbackTimer <= 0 then
            self.isKnockedBack = false
        end
        return -- Skip normal AI movement logic while knocked back
    end

    if self.isDead then
        if self.currentAnimation then
            self.currentAnimation:update(dt)
            if self.currentAnimation.status == "paused" then
                self.toBeRemoved = true
            end
        else
            self.toBeRemoved = true
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

    if not self:checkActiveByCamera(CamManager.camera) then
        return -- exit if not active/visible
    end

    if not self.collider then 
        Debug.debugPrint("UPDATE_NO_COLLIDER: self is", tostring(self), "name:", (self and self.name or "N/A"))
        return 
    end -- If collider somehow got removed early

    -- Update current animation (if it exists)
    -- if self.currentAnimation then
    --     self.currentAnimation:update(dt)
    -- end
    self.x, self.y = self.collider:getPosition()

    -- Facing direction (set animation)
    -- if self.xVel ~= 0 or self.yVel ~= 0 then
    --     local facing
    --     if math.abs(self.xVel) > math.abs(self.yVel) then
    --         facing = self.xVel > 0 and 'right' or 'left'
    --     else
    --         facing = self.yVel > 0 and 'down' or 'up'
    --     end
    --     if facing and self.animations[facing] then
    --         self.currentAnimation = self.animations[facing]
    --     end
    -- end   
    local vx, vy = self.collider:getLinearVelocity()
    if math.abs(vx) > 1 or math.abs(vy) > 1 then
        local facing
        if math.abs(vx) > math.abs(vy) then
            facing = vx > 0 and 'right' or 'left'
        else
            facing = vy > 0 and 'down' or 'up'
        end
        if facing and self.animations[facing] then
            self.currentAnimation = self.animations[facing]
        end
    end

    -- Gorgoneye-specific AI, pursue and shoot player
    self:updateAI(dt)
end

function Gorgoneye:draw()
    if self.spriteSheet and self.currentAnimation then
        if self.isFlashing and not self.isDead then
            love.graphics.setShader(flashShader)
            flashShader:send("WhiteFactor", 1.0)
        end

        self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
        if self.isFlashing and not self.isDead then
            love.graphics.setShader()
        end
    else
        love.graphics.setColor(1,0,0,0.6)
        love.graphics.circle("fill", self.x, self.y, (self.width or 32)/2)
        love.graphics.setColor(1,1,1,1)
    end
    -- enemy health bar
    if not self.isDead then
        local barWidth = 32
        local barHeight = 5
        local yOffset = self.height / 2 - 12  -- tweak offset to sit just above head
        UI.drawEnemyHealthBar(self, self.x - barWidth/2, self.y - yOffset, barWidth, barHeight)
    end
end

-- overrides Enemy:die and add loot drop logic here
function Gorgoneye:die(killer)
    if self.isDead then return end

    Debug.debugPrint(self.name .. " is dead, preparing to call Utils.die()!")
    self.isDead = true

    -- death animation and effects go here
    local soulsplodeImg = Assets.images.soulsplode
    if soulsplodeImg then
        local frameCount = 8 -- Adjust according to how many frames are in "soulsplode.png"
        local frameWidth = soulsplodeImg:getWidth() / frameCount
        local frameHeight = soulsplodeImg:getHeight()
        local anim8 = require("libraries/anim8")
        local grid = anim8.newGrid(frameWidth, frameHeight, soulsplodeImg:getWidth(), soulsplodeImg:getHeight())
        self.animations.soulsplode = anim8.newAnimation(grid('1-' .. frameCount, 1), 0.09, "pauseAtEnd")
        self.currentAnimation = self.animations.soulsplode
        self.spriteSheet = soulsplodeImg
        self.width = frameWidth
        self.height = frameHeight
        self.currentAnimation:gotoFrame(1)
        self.currentAnimation:resume()
    end

    if self.collider then
        Debug.debugPrint("Attempting to destroy collider for: " .. self.name)
        self.collider:destroy()
        self.collider = nil -- set collider to nil
        Debug.debugPrint(self.name .. " collider is destroyed!")
    else
        Debug.debugPrint(self.name .. "had no collider or it was already nil.")
    end

    Utils.die(self, killer)
    
    if math.random() < (self.shardDropChance or defaultDropChance) then
        table.insert(droppedItems, Loot.createShardDrop(self.x, self.y))
    end

    if math.random() < potionDropChance then
        table.insert(droppedItems, Loot.createPotionDrop(self.x, self.y))
    end

    -- self.toBeRemoved = true -- flag for removal from 'enemies' table in main.lua
    Debug.debugPrint(self.name .. " flagged for removal!")
    -- remove from world and/or active enemy table
end

return Gorgoneye
