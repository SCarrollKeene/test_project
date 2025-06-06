local Tileset = {}
Tileset.__index = Tileset

function Tileset:new()
    local self = setmetatable({}, Tileset)
    return self
end

function Tileset:load()
    self.image = love.graphics.newImage("assets/FieldsTilesetTest.png")
    self.tileWidth = 64
    self.tileHeight = 64
    self.quads = {}

    self.imgWidth = self.image:getWidth()
    self.imgHeight = self.image:getHeight()
    self.columns = self.imgWidth / self.tileWidth
    self.rows = self.imgHeight / self.tileHeight

    for y = 0, self.rows - 1 do
        for x = 0, self.columns - 1 do
            local quad = love.graphics.newQuad(
                x * self.tileWidth, 
                y * self.tileHeight,
                self.tileWidth,
                self.tileHeight,
                self.imgWidth,
                self.imgHeight
            )
            table.insert(self.quads, quad)
        end
    end
end

return Tileset