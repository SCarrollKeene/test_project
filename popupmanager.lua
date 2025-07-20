local PopupManager = {}
PopupManager.__index = PopupManager

function PopupManager:new()
    local self = {
        popups = {},
        defaultFont = love.graphics.newFont(12),
        defaultColor = {1, 1, 1, 1},
        defaultDuration = 1.0,
        defaultVy = -50
    }
    setmetatable(self, {__index = PopupManager})
    return self
end

function PopupManager:add(text, x, y, color, duration, vy, delay)
    table.insert(self.popups, {
        text = text,
        x = x,
        y = y,
        baseY = y,
        color = color or self.defaultColor,
        duration = duration or self.defaultDuration,
        delay = delay or 0,
        visible = delay == 0,
        timer = 0,
        vy = vy or self.defaultVy -- upward velocity in px/sec
    })
end

function PopupManager:update(dt)
    for i = #self.popups, 1, -1 do
        local popup = self.popups[i]

        if not popup.visible then
            popup.delay = popup.delay - dt
            if popup.delay <= 0 then
                popup.delay = 0
                popup.visible = true
            end
        elseif popup.visible then
            popup.timer = popup.timer + dt
            popup.y = popup.y + popup.vy * dt
            popup.color[4] = 1 - (popup.timer / popup.duration) -- alpha fades out

            if popup.timer >= popup.duration then
                table.remove(self.popups, i)
            end
        end
    end
end

function PopupManager:draw()
    love.graphics.setFont(self.defaultFont)
    for _, popup in ipairs(self.popups) do
        if popup.visible then
            love.graphics.setColor(popup.color)
            love.graphics.printf(popup.text, popup.x - 100, popup.y, 200, "center")
        end
    end
    love.graphics.setColor(1, 1, 1, 1) -- reset color
end

return PopupManager