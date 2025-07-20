local Cooldown = require("cooldown")

local Weapon = {}

Weapon.image = nil

-- implement leveling system
-- a base max level to start with
-- stat boosts on level up
-- debate how projectiles and leveling play a role in level ups
-- elemental / status effects
-- saving/loaidng for persisten weapon levels
-- need to build an inventory screen or at least a UI for weapons held

function Weapon:new(name, image, weaponType, baseSpeed, fireRate, projectileClass, baseDamage, knockback, level)
    level = level or 1

    -- print("Cooldown duration:", 1 / fireRate)
    local self = {
        name = name or "Fire crystal",
        image = image or Weapon.image,
        weaponType = weaponType or "Crystal",
        level = level, -- scale stats based on level
        baseDamage = baseDamage or 10, --store base damage OR default to 10
        knockback = knockback or 0,
        baseSpeed = 200,
        fireRate = fireRate,
        baseFireRate = fireRate + (level - 1) * 0.05,
        cooldown = Cooldown:new(1 / (fireRate - (level - 1) * 0.05)), -- convert fireRate to cooldown duration. duration and time are params/args from the cooldown object/table
        projectileClass = projectileClass -- projectileClass to spawn, return to this
        --projectileSpeedBonus = 1
    }

    setmetatable(self, {__index = Weapon}) -- point back at weapon table, Weapon methods and fields/data will get looked up
    self:recalculateStats() -- recalculate weapon level and stats on each pickup IF its the same weapon
    return self
end

function Weapon:update(dt)
    self.cooldown:update(dt)
end

function Weapon:levelUp()
    -- Auto-level up
    self.level = self.level + 1
    -- Recalculate stats based on new level reached
    self:recalculateStats()
end

function Weapon:recalculateStats()
    self.damage = (self.baseDamage or 10) + (self.level - 1) * 2
    self.baseSpeed = (self.baseSpeed or 200) + (self.level - 1) * 0.3
    self.fireRate = self.baseFireRate + (self.level - 1) * 0.05
    self.cooldown = Cooldown:new(1 / self.fireRate)
    self.projectileSpeedBonus = 1 + 0.1 * (self.level - 1)

    -- special/status effects
    if self.level < 5 then
        self.knockback = 0
    elseif self.level == 5 then
        self.knockback = 140
    else 
        self.knockback = 140 * (1 + 0.10 * (self.level - 5))
    end
end

function Weapon:getProjectileSpeed()
    return self.baseSpeed + (self.projectileSpeedBonus or 0)
end

function Weapon.loadAssets()
    local success, img = pcall(love.graphics.newImage, "sprites/crystal.png")
    if success then
        Weapon.image = img
        print("[WEAPON] image loaded successfully from:", img)
    else
        print("[WEAPON] image error:", img)
        Weapon.image = love.graphics.newImage(1, 1) -- 1x1 white pixel
    end
end

function Weapon:shoot(world, x, y, angle, speed, owner)
    if owner.isDead then return nil end -- extra safety measure to not fire projectile if owner is dead
    
    print("Shoot called, is cooldown ready?")
    if self.cooldown:isReady() then
        print("DEBUG: cooldown is ready", self.cooldown, "Cooldown time:", self.cooldown.time)
        self.cooldown:reset()
        local proj_width = 10
        local proj_height = 10
        local proj_dmg = self:getDamage()
        local proj_corners = 10
        local proj_radius = self.radius or 10
        local proj_speed = self:getProjectileSpeed()
        local proj_knockback = self.knockback

        if not self.projectileClass or not self.projectileClass.new then
            error("Weapon's projectileClass is not set or has no :new() method!")
        end

        return self.projectileClass:new(world, x, y, angle, proj_speed, proj_radius, proj_dmg, owner, proj_knockback)
    end
    return nil -- return nil if cooldown isn't ready
end

function Weapon:getDamage()
  return self.damage
end

return Weapon