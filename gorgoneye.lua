local Assets = require("assets")
local Utils = require("utils")
local Enemy = require("enemy")
local EnemyAI = require("enemy_ai")
local Projectile = require("projectile")
local Debug = require("game_debug")
local anim8 = require("libraries/anim8")
local wf = require "libraries/windfield"
local flashShader = require("libraries/flashshader")
local Loot = require("loot")

local Gorgoneye = {}
Gorgoneye.__index = Gorgoneye

setmetatable(Gorgoneye, { __index = Enemy })
-- Gorgoneye.super = Enemy

function Gorgoneye:new(world, name, x, y, width, height, health, speed, baseDamage, xpAmount, spriteSheet)
    local spr = spriteSheet or Assets.images.gorgoneye
     -- Safety check for nil image
    assert(spr, "Gorgoneye spriteSheet is nil!")

    -- Get the dimensions
    local sheetW, sheetH = spr:getWidth(), spr:getHeight()
    local cols, rows = 3, 1
    assert(sheetW == 96 and sheetH == 32, "Expected gorgoneye-tileset.png to be 96x32, but got " .. sheetW .. "x" .. sheetH)
    assert(sheetW % cols == 0, "Width must be divisible by 3")
    assert(sheetH % rows == 0, "Height must be divisible by 1")

    local frameWidth = sheetW / cols  -- 32
    local frameHeight = sheetH / rows -- 32

    local instance = Enemy.new(
        world,
        name or "Gorgoneye",
        x or 0,
        y or 0,
        frameWidth,
        frameHeight,
        0,
        0,
        health or 80,
        speed or 30,
        baseDamage or 20,
        xpAmount or 30,
        spr
    )

    Debug.debugPrint("DEBUG: Enemy:new - Instance name:", instance.name,
        " Health:", instance.health,
        "Speed:", instance.speed,
        "Type of speed:", type(instance.speed), 
        "Damage:", instance.baseDamage
    )
    setmetatable(instance, Gorgoneye) -- Gorgoneye methods and fields/data will get looked up

    local grid = anim8.newGrid(frameWidth, frameHeight, sheetW, sheetH)
    instance.animations = {
        idle = anim8.newAnimation(grid('1-3', 1), 0.2)
    }
    instance.currentAnimation = instance.animations.idle

    -- Gorgoneye-specific fields
    instance.patrolRange = 120
    instance.patrolOriginXPos = x
    instance.patrolDirection = 1
    instance.player = nil

    instance.awarenessRange = 200
    instance.shootInterval = 2.2
    instance.shootCooldown = 0

    instance.spriteSheet = spr
    instance.width = frameWidth
    instance.height = frameHeight

    return instance

end

function Gorgoneye:load()
    local colliderHeight = self.height
    local colliderWidth = self.width
    -- set it up with self so each enemy instance has their own collider
    self.collider = self.world:newBSGRectangleCollider(self.x - colliderWidth/2, self.y - colliderHeight/2, colliderWidth, colliderHeight, 10)
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- associate enemy obj w/ collider
    print("DEBUG: GORGONEYE collider created with W: "..self.width.."and H: "..self.height)
    self.collider:setCollisionClass('enemy')
    self.collider:setObject(self)
end

function Gorgoneye:setTarget(player)
    self.target = player
    self.player = player
end

function Gorgoneye:update(dt, frameCount)
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

    if self.isKnockedBack then
        self.knockbackTimer = self.knockbackTimer - dt
        if self.knockbackTimer <= 0 then
            self.isKnockedBack = false
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

    -- Gargoyle behavior: patrol unless player is near; shoot if in range
    local shootPlayerInRange = function(enemy, dt)
        -- EnemyAI.shootAtPlayer expects .player, .shootCooldown, .shootInterval, and .world to exist
        EnemyAI.shootAtPlayer(enemy, dt)
    end

    EnemyAI.patrolarea(self, dt, self.patrolRange, shootPlayerInRange)

    -- Update animation and position
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
    if self.collider then
        self.x, self.y = self.collider:getPosition()
    end
end

function Gorgoneye:draw()
    love.graphics.setColor(1, 0, 0, 0.2)
    love.graphics.rectangle("fill", self.x-self.width/2, self.y-self.height/2, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)

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
        -- fallback circle if no sprite
        love.graphics.setColor(1,0,0,0.6)
        love.graphics.circle("fill", self.x, self.y, (self.width or 32)/2)
        love.graphics.setColor(1,1,1,1)
    end
end

return Gorgoneye