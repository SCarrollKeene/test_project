local Gamestate = require("libraries/hump/gamestate")

local pause_menu = {}

function pause_menu:enter(from_state)
    self.previous_state = from_state
end

function pause_menu:draw()
    if self.previous_state and self.previous_state.draw then
        self.previous_state:draw()
    end

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    local font = love.graphics.newFont(56)
    love.graphics.setFont(font)
    local text = "Paused"
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight(text)
    love.graphics.print(text, (love.graphics.getWidth() - textWidth) / 2, (love.graphics.getHeight() - textHeight) / 2)
end

function pause_menu:keypressed(key)
    -- TODO: when I implement controller support, update this to handle respective input 8/8/25
    if key == "p" then
        Gamestate.pop() -- return to gameplay
    end
end

return pause_menu