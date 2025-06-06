local Enemy = require("enemy")
anim8 = require 'libraries/anim8'

local Blob = {}
Blob.__index = Blob -- when metatable is 'Blob' instance, lookups in 'Blob' itself

-- class level inheritance, moved out of Blob:new() to avoid redundancy so it's only executed once, not on every instance creation
setmetatable(Blob, {__index = Enemy}) -- Enemy methods and fields/data will get looked up and inherited into Blob table

function Blob:new(name, x, y) -- x and y for enemy spawn positon in main.lua
    local blob_width = 40
    local blob_height = 40
    local blob_health = 80
    local blob_speed = 20
    local blob_baseDamage = 4
    local self = Enemy:new(name or "Blob", x, y, blob_width, blob_height, 0, 0, blob_health, blob_speed, blob_baseDamage, nil)
    -- instance to class relationship
    setmetatable(self, Blob) -- connects 'Blob' instances in main.lua to the Blob class to find defined methods

     print("DEBUG: Blob:new - self.speed is", self.speed, "Type:", type(self.speed))
    local speed_val = self.speed -- Store it
    print("STORED BLOB VAL:", speed_val) -- Print stored val
    -- add attack, test inheritance by calling an enemy function with blob and printing the results
    
    -- self.spriteSheet = love.graphics.newImage("sprites/evilblob.png")
    -- self.grid = anim8.newGrid(9, 1, self.spriteSheet:getWidth(), self.spriteSheet:getHeight())
    -- self.anim = anim8.newAnimation(self.grid('1-9', 1), 0.2)

    print("DEBUG: Blob:new - Self name:", self.name, "Speed:", self.speed, "Type of speed:", type(self.speed))
    return self
end

function Blob:load()
    -- love.graphics.setDefaultFilter("nearest", "nearest")
    self.collider = self.world:newBSGRectangleCollider(self.x, self.y, self.width, self.height, 50) -- Using Blob's dimensions
    self.collider:setFixedRotation(true)
    self.collider:setUserData(self) -- associate blob obj w/ collider
    self.collider:setObject(self)
    print("DEBUG: BLOB collider created with W: "..self.width.."and H: "..self.height)

    -- self.width = 40
    -- self.height = 40
    
    --  -- Ensure self.world is valid and is the SHARED world
    -- if not self.world then
    --     print("ERROR: Blob:load - self.world is nil! Cannot create collider.")
    --     return
    -- end
    -- if not self.world.newBSGRectangleCollider then -- Basic check if it's a Windfield world
    --      print("ERROR: Blob:load - self.world does not seem to be a valid Windfield world.")
    --      return
    -- end
end

function Blob:update(dt)
    print("DEBUG: Blob:update - Self name:", self.name, "Speed:", self.speed, "Type of speed:", type(self.speed))
    Enemy.update(self, dt) -- 1. calls Enemy update method, pass in Blob instance (self), allow blob to utilize/reuse common update logic from Enemy - Polymorphism!
    -- Enemy:update(self, dt) -- doesn't work as it's passing Enemy before the colon back to itself so it effectively sees Enemy.update(Enemy, self, dt)
    -- self.anim:update(dt) -- 2. and add its own common logic such as this line here
end

function Blob:draw()
    -- Enemy.draw(self) -- called from superclass, Enemy
    -- self.anim:draw(self.spriteSheet, self.x, self.y)
    -- world.draw()
    -- love.graphics.setColor(1, 0, 0, 0.5)
    -- love.graphics.circle("fill", self.x, self.y, self.width, self.height)
    -- love.graphics.setColor(1, 1, 1, 1)
    -- self.world:draw()
end

function Blob:Taunt()
    print(self.name.." mumbles, I am the Black Blob!")
end

return Blob

-- maybe consider moving various enemy types and instances into an enemy table?
-- ex: table.insert(enemies, blob)