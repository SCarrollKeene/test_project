local Assets = require("assets")
local CamManager = require("cam_manager")
local UI = require("ui")
local Utils = require("utils")
local Enemy = require("enemy")
local EnemyAI = require("enemy_ai")
local Debug = require("game_debug")
local anim8 = require("libraries/anim8")
local wf = require("libraries/windfield")
local flashShader = require("libraries/flashshader")
local Loot = require("loot")

local Blob = {}
Blob.__index = Blob

setmetatable(Blob, { __index = Enemy })

local defaultDropChance = 0.5
local potionDropChance = 0.10

function Blob:new(fields)
    fields = fields or {}

    local spr = fields.spriteSheet or Assets.images.slime_black or love.graphics.newImage(fields.spritePath or "sprites/slime_black.png")
    assert(spr, "Blob spriteSheet is nil!")

    -- Animmation dimensions 3x4 grid
    local frameWidth  = spr:getWidth() / 3
    local frameHeight = spr:getHeight() / 4

    local instance = Enemy:new {
        world = fields.world,
        name = fields.name or "Blob",
        x = fields.x or 0,
        y = fields.y or 0,
        width = frameWidth,
        height = frameHeight,
        maxHealth = fields.maxHealth or 60,
        health = fields.maxHealth or 60,
        speed = fields.speed or 50,
        baseDamage = fields.baseDamage or 5,
        xpAmount = fields.xpAmount or 10,
        spriteSheet = spr
    }
    setmetatable(instance, Blob)

    -- blob specific fields
    instance.enemyType = "blob"

    instance.flashDuration = 0.12
    instance.isFlashing = false
    instance.flashTimer = 0

    instance.spriteSheet = spr
    instance.width = frameWidth
    instance.height = frameHeight

    -- Blob animations
    local grid = anim8.newGrid(frameWidth, frameHeight, spr:getWidth(), spr:getHeight())
    instance.animations = {
        idle  = anim8.newAnimation(grid('1-3', 1), 0.3),
        walk  = anim8.newAnimation(grid('1-3', 2), 0.3),
        death = anim8.newAnimation(grid('1-3', 4), 0.10),
    }
    if instance.animations.death then
        instance.animations.death:onLoop(function(anim) anim:pauseAtEnd() end)
    end
    instance.currentAnimation = instance.animations.idle
    
    return instance
end

function Blob:reset(x, y, def, img)
    assert(img, "[BLOB:RESET] Tried to reset enemy with nil image!")
    print("Resetting Blob with spriteSheet:", img, "Width:", img:getWidth(), "Height:", img:getHeight())

    -- Pool reuse logic
    -- Base logic: core vars, collider from Enemy base class
    self:baseReset(x, y, def, img)

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
    -- Reinitialized collider from base Enemy class
end

-- function Enemy.getEnemyPool()
--     return #enemyPool -- Return the enemy pool, or an empty table if not set
-- end

function Blob:load()
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
    Debug.debugPrint("DEBUG: BLOB collider created with W: "..self.width.."and H: "..self.height)
    self.collider:setCollisionClass('enemy')
    self.collider:setObject(self)
end

-- Inherit methods from Enemy: Enemy:setTarget, Enemy:update, Enemy:takeDamage, Enemy:isNearTarget

function Blob:update(dt, frameCount) 
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
        if self.currentAnimation then
            self.currentAnimation:update(dt)
            -- When animation is finished, remove enemy
            if self.currentAnimation.status == "paused" then
                self.toBeRemoved = true
            end
        else
            self.toBeRemoved = true -- Fallback: no animation to play
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
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end

    Debug.debugPrint("DEBUG: Blob:update: " .. "Name:", self.name, "Speed:", self.speed, "Type of speed:", type(self.speed), "Damage:", self.baseDamage)

        -- Switch animation based on state
        if self.isMoving and self.animations and self.animations.walk and self.currentAnimation ~= self.animations.walk then
            self.currentAnimation = self.animations.walk
        elseif not self.isMoving and self.animations and self.animations.idle and self.currentAnimation ~= self.animations.idle then
            self.currentAnimation = self.animations.idle
        end

    if self.collider then
        self.x, self.y = self.collider:getPosition()
    else
        Debug.debugPrint("[BLOB] UPDATE: getPosition failed because collider is nil for "..tostring(self.name))
        return -- skip to movement logic below
    end


    if self.currentAnimation and self.currentAnimation.update then
        self.currentAnimation:update(dt)
    end

    -- pursue target
    if self:isNearPlayer(500) then
        EnemyAI.pursueTarget(self, dt)
    else
        self.collider:setLinearVelocity(0, 0)
        self.isMoving = false
        -- idle
        if self.animations and self.animations.idle then
            self.currentAnimation = self.animations.idle
        end
    end
end

function Blob:draw()
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
        love.graphics.setColor(0,0.7,0.8,0.7)
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
function Blob:die(killer)
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

return Blob
