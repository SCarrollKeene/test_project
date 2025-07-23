local Debug = require("game_debug")

local Cooldown = {}
-- Cooldown.__index = Cooldown 

function Cooldown:new(duration, time)

    local self = {
        duration = duration,
        time = 0 -- ready to fire projectile
    }

    setmetatable(self, {__index = Cooldown}) -- point back at cooldown table, Cooldown methods and fields/data will get looked up
    return self
end

function Cooldown:update(dt)
    self.time = math.max(self.time - dt, 0)
    Debug.debugPrint("DEBUG: update time:", self.time)
end

function Cooldown:isReady()
    return self.time <= 0
end

function Cooldown:reset()
    self.time = self.duration
end

return Cooldown