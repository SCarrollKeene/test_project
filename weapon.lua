local Cooldown = require("cooldown")

local Weapon = {}

function Weapon:new(fireRate, projectileClass, baseDamage)

    print("Cooldown duration:", 1 / fireRate)
    local self = {
        damage = baseDamage or 10, --store base damage OR default to 10
        cooldown = Cooldown:new(1 / fireRate), -- convert fireRate to cooldown duration. duration and time are params/args from the cooldown object/table
        projectileClass = projectileClass -- projectileClass to spawn, return to this
    }

    setmetatable(self, {__index = Weapon}) -- point back at weapon table, Weapon methods and fields/data will get looked up
    return self
end

function Weapon:update(dt)
    self.cooldown:update(dt)
end

function Weapon:shoot(world, x, y, angle, speed, owner)
    if owner.isDead then return nil end -- extra safety measure to not fire projectile if owner is dead
    
    print("Shoot called, is cooldown ready?")
    if self.cooldown:isReady() then
        print("DEBUG: cooldown is ready", self.cooldown, "Cooldown time:", self.cooldown.time)
        self.cooldown:reset()
        local proj_width = 10
        local proj_height = 10
        local proj_dmg = self.damage or 5
        local proj_corners = 10
        local proj_radius = self.radius or 10

        if not self.projectileClass or not self.projectileClass.new then
            error("Weapon's projectileClass is not set or has no :new() method!")
        end

        return self.projectileClass:new(world, x, y, angle, speed, proj_radius, proj_dmg, owner) -- creates a new projectile class, gotta wrap my head around this one, how should radius work here?...
    end
    return nil -- return nil if cooldown isn't ready
end

function Weapon:getDamage()
  return self.damage
end

return Weapon