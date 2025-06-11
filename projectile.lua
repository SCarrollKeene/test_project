local Utils = require("utils")
local wf = require "libraries/windfield"

local Projectile = {}
Projectile.__index = Projectile -- points back at the table itself, is used when you set the metatable of an obj

sounds = {}
local image = love.graphics.newImage("sprites/orb_red.png")
sounds.blip = love.audio.newSource("sounds/blip.wav", "static")

-- constructor function, if you wanted to create multiple projectiles with different methods/data
function Projectile:new(world, x, y, angle, speed, radius, damage, owner)
    local self = {
        x = x,
        y = y,
        angle = angle,
        speed = speed or 300,
        radius = radius or 10,
        width = radius * 2,
        height = radius * 2,
        damage = damage or 10, -- store damage
        world = world,
        owner = owner, --store the owner of the shot projectile, in this case, the player
        ignoreTarget = owner,
        orbSprite = image,

        type = "projectile",

        toBeRemoved = false, -- flag to eventually remove projectiles/enemy
        toBeDestroyed = false -- flag for projectile to handle its own destruction on contact with things like walls
    }
    
    setmetatable(self, {__index = Projectile}) -- Projectile methods and fields/data will get looked up

    -- Debug before creating collider
    print("DEBUG Projectile:new - Creating collider with:")
    print("  x:", self.x, "y:", self.y)
    print("  width:", self.width, "type:", type(self.width))
    print("  height:", self.height, "type:", type(self.height))

    if type(self.width) ~= "number" or type(self.height) ~= "number" then
        error("Projectile dimensions are not numbers! Width: " .. tostring(self.width) .. ", Height: " .. tostring(self.height))
    end
    if self.width <= 0 or self.height <= 0 then
         error("Projectile dimensions must be positive! Width: " .. tostring(self.width) .. ", Height: " .. tostring(self.height))
    end

    self.collider = world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 10) -- collider creation for projectile instances
    self.collider:setFixedRotation(true) -- don't rotate
    self.collider:setSensor(true) -- act as sensor to detect hits
    self.collider:setUserData(self) -- associate projectile to its collider
    self.collider:setCollisionClass('projectile')
    self.collider:setObject(self)
    -- self.collider:setMask('enemy') -- Projectiles only care about hitting enemies

    return self
end

function Projectile:destroySelf()
    if self.isDestroyed then return end -- Prevent multiple destructions

    print(string.format("Projectile:destroySelf - Destroying projectile (Owner: %s)", (self.owner and self.owner.name) or "Unknown"))
    if self.collider then
        self.collider:destroy()
        self.collider = nil
    end
    self.toBeRemoved = true
    self.isDestroyed = true -- Add a flag to prevent re-entry
end

function Projectile:onHitEnemy(enemy_collided_with)
    if self.isDestroyed then return end

    print(string.format("Projectile:onHitEnemy - Projectile (Owner: %s) hit Enemy: %s", 
        (self.owner and self.owner.name) or "Unknown", 
        (enemy_collided_with and enemy_collided_with.name) or "Unknown Enemy"))

    -- applying damage
    if self.owner and self.owner.dealDamage then
        Utils.dealDamage(self.owner, enemy_collided_with, self.damage)
    elseif enemy_collided_with and enemy_collided_with.takeDamage then
        enemy_collided_with:takeDamage(self.damage)
    end
    
    self:destroySelf() -- Call the generic cleanup, :destroySelf()
end

-- alter this later if enemies will also launch projectiles
-- this could possibly be a utils function later
function Projectile:onHitEnemy(enemy_target)
    if self.owner and self.owner.dealDamage then
        Utils.dealDamage(self.owner, enemy_target, self.damage)
    elseif enemy_target and enemy_target.takeDamage then
        print("Projectile hit enemy, directly calling enemy:takeDamage.")
        enemy_target:takeDamage(self.damage) -- Fallback if owner not set 
    end
end

function Projectile:load()
    -- if we needed to load sounds and images
end

function Projectile:update(dt)
    print("Projectile:updated(dt) triggered")
    print(string.format("Projectile: angle=%.2f, speed=%.2f", self.angle, self.speed))
    -- Add this check:
    if not self.collider then
        self.toBeRemoved = true -- handle collider being destroyed
        print("Projectile:update - Collider is nil for this projectile. Skipping further update.")
        return -- Exit the function if the collider is nil
    end

    print(string.format("Projectile: angle=%.2f, speed=%.2f", self.angle, self.speed))

    -- self.ax = self.x + math.cos(self.angle) * self.speed * dt
    -- self.by = self.y + math.sin(self.angle) * self.speed * dt
    -- self.x = self.ax
    -- self.y = self.by
    self.x, self.y = self.collider:getPosition()

    -- Check if projectile is off-screen
     if self.x + self.radius < 0 or self.x - self.radius > love.graphics.getWidth() or
       self.y + self.radius < 0 or self.y - self.radius > love.graphics.getHeight() then
        self:destroySelf()
        return -- exit immediately after destroy
    end

     -- projectile initial velocity
    self.xVel = math.cos(self.angle) * self.speed
    self.yVel = math.sin(self.angle) * self.speed

    self.collider:setLinearVelocity(self.xVel, self.yVel)

    -- self.velx = math.cos(self.angle) * self.speed -- calculate horizontal velocity
    -- self.vely = math.sin(self.angle) * self.speed -- calculate vertical velocity
    -- self.x = self.x + self.velx * dt
    -- self.y = self.y + self.vely * dt
    -- print("x"..self.x, "y"..self.y)
    
end

function Projectile:draw()
    -- love.graphics.setColor(1, 0, 0)
    -- love.graphics.circle("fill", self.x, self.y, self.radius)
    -- love.graphics.setColor(1, 1, 1)
    if self.toBeRemoved then 
        return 
    end

    love.graphics.draw(self.orbSprite, self.x - self.width / 2, self.y - self.height / 2)
end

return Projectile