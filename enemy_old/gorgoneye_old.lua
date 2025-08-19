-- local Assets = require("assets")
-- local Utils = require("utils")
-- local Enemy = require("enemy")
-- local EnemyAI = require("enemy_ai")
-- local Projectile = require("projectile")
-- local Debug = require("game_debug")
-- local anim8 = require("libraries/anim8")
-- local wf = require "libraries/windfield"
-- local flashShader = require("libraries/flashshader")
-- local Loot = require("loot")

-- local Gorgoneye = {}
-- Gorgoneye.__index = Gorgoneye

-- setmetatable(Gorgoneye, { __index = Enemy })
-- -- Gorgoneye.super = Enemy

-- function Gorgoneye:new(world, name, x, y, width, height, health, speed, baseDamage, xpAmount, spriteSheet)
--     local spr = spriteSheet or Assets.images.gorgoneye
--      -- Safety check for nil image
--     assert(spr, "Gorgoneye spriteSheet is nil!")

--     -- Get the dimensions
--     local sheetW, sheetH = 36, 144
--     -- local cols, rows = 3, 1
--     assert(sheetW == 36 and sheetH == 144, "Expected gorgoneye-tileset.png to be 108x36, but got " .. sheetW .. "x" .. sheetH)

--     local frameWidth = 36
--     local frameHeight = 36

--     local instance = Enemy.new(
--         world,
--         name or "Gorgoneye",
--         x or 0,
--         y or 0,
--         frameWidth,
--         frameHeight,
--         0,
--         0,
--         health or 80,
--         speed or 30,
--         baseDamage or 20,
--         xpAmount or 30,
--         spr
--     )

--     Debug.debugPrint("DEBUG: Enemy:new - Instance name:", instance.name,
--         " Health:", instance.maxHealth,
--         "Speed:", instance.speed,
--         "Type of speed:", type(instance.speed), 
--         "Damage:", instance.baseDamage
--     )
--     setmetatable(instance, Gorgoneye) -- Gorgoneye methods and fields/data will get looked up

--     local grid = anim8.newGrid(frameWidth, frameHeight, sheetW, sheetH)
--     instance.animations = {
--         left = anim8.newAnimation(grid(1, 1), 1),  -- Top row
--         right = anim8.newAnimation(grid(1, 2), 1),   -- Second row
--         down = anim8.newAnimation(grid(1, 3), 1),   -- Third row
--         up = anim8.newAnimation(grid(1, 4), 1),   -- Bottom row
--     }
--     instance.currentAnimation = instance.animations.left

--     -- Gorgoneye-specific fields
--     instance.patrolRange = 120
--     instance.patrolOriginXPos = x
--     instance.patrolDirection = 1
--     instance.player = nil

--     instance.awarenessRange = 200
--     instance.shootInterval = 2.2
--     instance.shootCooldown = 0

--     instance.spriteSheet = spr
--     instance.width = frameWidth
--     instance.height = frameHeight

--     return instance

-- end

-- function Gorgoneye:reset(x, y, blob, img)
--     -- Assign standard fields from pooling
--     self.x = x
--     self.y = y
--     self.name = blob.name
--     self.health = blob.health
--     self.speed = blob.speed
--     self.baseDamage = blob.baseDamage
--     self.xpAmount = blob.xpAmount
--     self.spriteSheet = img or Assets.images.gorgoneye
--     self.isDead = false
--     self.toBeRemoved = false
--     self.isFlashing = false
--     self.xVel = 0
--     self.yVel = 0

--     -- Setup frame and sheet sizes (fixed for this tileset)
--     local frameWidth = 36
--     local frameHeight = 36
--     local sheetW = 36
--     local sheetH = 144

--     -- Safety check for real image dimensions (optional but good for debug)
--     -- Uncomment if desired:
--     -- assert(
--     --     (self.spriteSheet:getWidth() == sheetW and self.spriteSheet:getHeight() == sheetH),
--     --     "Expected gorgoneye-tileset.png to be "..sheetW.."x"..sheetH..
--     --     ", but got "..self.spriteSheet:getWidth().."x"..self.spriteSheet:getHeight()
--     -- )

--     -- Set up new animation grid and direction-based frames
--     local grid = anim8.newGrid(frameWidth, frameHeight, sheetW, sheetH)
--     self.animations = {
--         left  = anim8.newAnimation(grid(1, 1), 1),   -- Top row
--         right = anim8.newAnimation(grid(1, 2), 1),   -- 2nd row
--         down  = anim8.newAnimation(grid(1, 3), 1),   -- 3rd row
--         up    = anim8.newAnimation(grid(1, 4), 1),   -- 4th row
--     }
--     self.currentAnimation = self.animations.left
--     self.width = frameWidth
--     self.height = frameHeight

--     -- Gorgoneye-specific fields
--     self.patrolRange = 120
--     self.patrolOriginXPos = x
--     self.patrolDirection = 1
--     self.player = nil
--     self.awarenessRange = 200
--     self.shootInterval = 2.2
--     self.shootCooldown = 0

--     -- Reset physics collider
--     if not self.collider then
--         self:load()
--     else
--         self.collider:setPosition(x, y)
--         self.collider:setActive(true)
--     end

--     print("[RESET] Gorgoneye reset at", x, y)
-- end

-- function Gorgoneye:load()
--     local colliderHeight = self.height
--     local colliderWidth = self.width
--     -- set it up with self so each enemy instance has their own collider
--     self.collider = self.world:newBSGRectangleCollider(self.x - colliderWidth/2, self.y - colliderHeight/2, colliderWidth, colliderHeight, 10)
--     self.collider:setFixedRotation(true)
--     self.collider:setUserData(self) -- associate enemy obj w/ collider
--     print("DEBUG: GORGONEYE collider created with W: "..self.width.."and H: "..self.height)
--     self.collider:setCollisionClass('enemy')
--     self.collider:setObject(self)
-- end

-- function Gorgoneye:setTarget(player)
--     self.target = player
--     self.player = player
-- end

-- function Gorgoneye:updateAI(dt)
--     local playerDist = math.sqrt((self.x - self.player.x)^2 + (self.y - self.player.y)^2)
--     if playerDist <= self.awarenessRange then
--         -- Shoot at player, but don't chase!
--         EnemyAI.shootAtPlayer(self, dt)
--         -- Optionally pause or minimal movement
--         self.xVel = 0
--         self.yVel = 0
--     else
--         -- Patrol logic
--         EnemyAI.patrolarea(self, dt, self.patrolRange)
--     end
-- end

-- function Gorgoneye:update(dt, frameCount)
--     print("[DEBUG] Gorgoneye:update is running!")
--     if self.isDead then
--         if self.currentAnimation then
--             self.currentAnimation:update(dt)
--             if self.currentAnimation.status == "paused" then
--                 self.toBeRemoved = true
--             end
--         else
--             self.toBeRemoved = true
--         end
--         return
--     end

--     if self.isKnockedBack then
--         self.knockbackTimer = self.knockbackTimer - dt
--         if self.knockbackTimer <= 0 then
--             self.isKnockedBack = false
--         end
--         return
--     end

--     if self.isFlashing then
--         self.flashTimer = self.flashTimer - dt
--         if self.flashTimer <= 0 then
--             self.isFlashing = false
--             self.flashTimer = 0
--         end
--     end

--     -- Gargoyle behavior: patrol unless player is near; shoot if in range
--     --local shootPlayerInRange = function(enemy, dt)
--         -- EnemyAI.shootAtPlayer expects .player, .shootCooldown, .shootInterval, and .world to exist
--     --    EnemyAI.shootAtPlayer(enemy, dt)
--     --end

--     -- Call custom AI routine:
--     self:updateAI(dt)

--     if self.xVel ~= 0 or self.yVel ~= 0 then
--         local facing
--         if math.abs(self.xVel) > math.abs(self.yVel) then
--             facing = self.xVel > 0 and 'right' or 'left'
--         else
--             facing = self.yVel > 0 and 'down' or 'up'
--         end
--         if facing and self.animations[facing] then
--             self.currentAnimation = self.animations[facing]
--         end
--         print("xVel:", self.xVel, "yVel:", self.yVel)
--     end
    
--     -- Update animation and position
--     if self.currentAnimation then
--         self.currentAnimation:update(dt)
--     end
--     if self.collider then
--         self.x, self.y = self.collider:getPosition()
--     end
-- end

-- function Gorgoneye:draw()
--     if self.spriteSheet and self.currentAnimation then
--         if self.isFlashing and not self.isDead then
--             love.graphics.setShader(flashShader)
--             flashShader:send("WhiteFactor", 1.0)
--         end

--         self.currentAnimation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1, self.width/2, self.height/2)
--         if self.isFlashing and not self.isDead then
--             love.graphics.setShader()
--         end
--     else
--         -- fallback circle if no sprite
--         love.graphics.setColor(1,0,0,0.6)
--         love.graphics.circle("fill", self.x, self.y, (self.width or 32)/2)
--         love.graphics.setColor(1,1,1,1)
--     end
-- end

-- return Gorgoneye