local Debug = require("game_debug")

local Enemy = {}
Enemy.__index = Enemy

local enemyIDCounter = 0

function Enemy:new(fields)
    enemyIDCounter = enemyIDCounter + 1
    fields = fields or {}
    local instance = setmetatable({}, self)
    -- Set up basic fields; children can add/override as needed!
    instance.name = fields.name or "Enemy"
    instance.x = fields.x or 0
    instance.y = fields.y or 0
    instance.width = fields.width or 32
    instance.height = fields.height or 32
    instance.maxHealth = fields.maxHealth or 40
    instance.health = fields.maxHealth or 40
    instance.speed = fields.speed or 40
    instance.baseDamage = fields.baseDamage or 5
    instance.xpAmount = fields.xpAmount or 10

    instance.enemyID = enemyIDCounter

    instance.type = "enemy"

    -- passing global world from main.lua
    instance.world = fields.world

    -- flags for death and removal upon death
    instance.isDead = false
    instance.toBeRemoved = false
    instance.isMoving = false

    instance.isFlashing = false
    instance.flashTimer = 0
    instance.flashDuration = 0.12 -- seconds, tweak as needed

    instance.isKnockedBack = false
    instance.knockbackTimer = 0

    if instance.load then
        instance:load()
    end
    return instance
end

-- base :reset method
function Enemy:baseReset(x, y, def, img)
    self.world = world or self.world
    self.x = x
    self.y = y
    self.name = def.name or self.name
    self.maxHealth = def.maxHealth or def.health or self.maxHealth
    self.health = self.maxHealth
    self.speed = def.speed or self.speed   -- fallback to previous speed if not in def
    self.baseDamage = def.baseDamage or self.baseDamage
    self.xpAmount = def.xpAmount or self.xpAmount
    self.spriteSheet = img or self.spriteSheet
    self.isDead = false
    self.toBeRemoved = false
    self.isFlashing = false
    self.flashTimer = 0 
    self.knockbackTimer = 0 
    self.isKnockedBack = false

    -- if missing, load; else move to x,y
    if not self.collider then
        self:load()
    else
        self.collider:setPosition(x, y)
        self.collider:setActive(true)
    end

    self.target = player
end

-- Collider setup: can be overridden, but works for most rectangular enemies
function Enemy:load()
    if not self.world then error("Enemy:load missing world context") end
    local w, h = self.width, self.height
    self.collider = self.world:newBSGRectangleCollider(self.x - w/2, self.y - h/2, w, h, 10)
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self)
    self.collider:setCollisionClass("enemy")
end

-- Attach a target (usually player)
function Enemy:setTarget(target)
    self.target = target -- sets the player instance as the enemy target
end

function Enemy:isNearPlayer(buffer)
    buffer = buffer or 500
    if not self.target then return false end
    local dx = self.x - self.target.x
    local dy = self.y - self.target.y
    local distanceSquared = dx * dx + dy * dy
    return distanceSquared <= buffer * buffer
end

-- Stub: children override
function Enemy:update(dt, frameCount) end

-- Stub: children override (provide their own sprite or animation draws)
function Enemy:draw()
    love.graphics.setColor(1, 0, 0, 0.7)
    love.graphics.circle("fill", self.x, self.y, (self.width or 32) / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- take damage, deal damage and direction
function Enemy:takeDamage(dmg, killer)
    if self.isDead or self.isFlashing then return end -- no more damage taken if dead or if already flashing

    self.isFlashing = true
    self.flashTimer = self.flashDuration

    -- Utils.takeDamage(self, dmg)
    self.health     = self.health - dmg
    Debug.debugPrint(string.format("%s took %.2f damage. Flash activated. Health is now %.2f", self.name, dmg, self.health))
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

-- function Enemy:die(killer)
--     if self.isDead then return end
--     -- Child will call drop logic, animation, etc!
--     self.isDead = true
--     if self.collider then 
--         self.collider:destroy()
--         self.collider = nil
--     end
-- end

function Enemy:getName()
    return self.name
end

function Enemy:Taunt()
    Debug.debugPrint("I am the enemy!")
end

return Enemy
