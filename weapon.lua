local Cooldown = require("cooldown")

local Weapon = {}

Weapon.RARITY_ORDER = {
  "common", "uncommon", "rare", "epic", "legendary", "exotic", "mythic"
}

-- TODO: consider unique passive effects or weapon mods in addition to stat boosts (e.g., burn, freeze, shockwaves, lifesteal, or on-hit explosions)
Weapon.RARITY_STAT_MULTIPLIERS = {
  common    = { damage = 1.00, speed = 1.00, fireRate = 1.00 },
  uncommon  = { damage = 1.15, speed = 1.05, fireRate = 1.07 },
  rare      = { damage = 1.30, speed = 1.10, fireRate = 1.15 },
  epic      = { damage = 1.50, speed = 1.16, fireRate = 1.24 },
  legendary = { damage = 1.75, speed = 1.23, fireRate = 1.33 },
  exotic    = { damage = 2.05, speed = 1.31, fireRate = 1.43 },
  mythic    = { damage = 2.40, speed = 1.40, fireRate = 1.55 }
}

Weapon.image = nil

-- implement leveling system
-- a base max level to start with
-- stat boosts on level up
-- debate how projectiles and leveling play a role in level ups
-- elemental / status effects
-- saving/loaidng for persisten weapon levels
-- need to build an inventory screen or at least a UI for weapons held

function Weapon:new(name, image, weaponType, rarity, baseSpeed, baseFireRate, projectileClass, baseDamage, knockback, level, id)

    local self = {
        name = name or "Fire Crystal",
        image = image or Weapon.image,
        weaponType = weaponType or "Crystal",
        rarity = rarity or "common",
        baseDamage = baseDamage or 10, --store base damage OR default to 10
        knockback = knockback or 0,
        speed = nil,
        baseSpeed = baseSpeed or 200,
        fireRate = nil,
        baseFireRate = baseFireRate or 2,
        cooldown = nil, -- convert fireRate to cooldown duration. duration and time are params/args from the cooldown object/table
        projectileClass = projectileClass, -- projectileClass to spawn, return to this
        --projectileSpeedBonus = 1
        level = level or 1, -- scale stats based on level
        id = id or love.math.random(1, 99999999) .. "-" .. tostring(os.time()) -- use a UUID lib later
    }

    setmetatable(self, {__index = Weapon}) -- point back at weapon table, Weapon methods and fields/data will get looked up
    self:recalculateStats() -- recalculate weapon level and stats on each pickup IF its the same weapon
    return self
end

function Weapon:update(dt)
    self.cooldown:update(dt)
end

function Weapon:levelUp(player)
    local oldDamage = self.damage or 0
    local oldFireRate = self.fireRate or 0
    local oldSpeed = self.speed or 0

    -- Auto-level up
    self.level = self.level + 1
    -- Recalculate stats based on new level reached
    self:recalculateStats()

    -- NEW values vs old values
    local dmgIncrease = self.damage - oldDamage
    local fireRateIncrease = self.fireRate - oldFireRate
    local speedIncrease = self.speed - oldSpeed

    local dmgPct = oldDamage > 0 and (dmgIncrease / oldDamage) * 100 or 0
    local fireRatePct = oldFireRate > 0 and (fireRateIncrease / oldFireRate) * 100 or 0
    local speedPct = oldSpeed > 0 and (speedIncrease / oldSpeed) * 100 or 0

    local px, py = player.x or 0, player.y or 0
    local offset = (player.height or 32) / 2 + 18

    if popupManager then
        popupManager:add("Weapon up!", px, py - offset)
        popupManager:add(string.format("+%.1f%% Damage", dmgPct), px, py - offset, {1, 0.6, 0.2, 1}, 1.0, nil, 0.5)
        popupManager:add(string.format("+%.1f%% Fire rate", fireRatePct), px, py - offset, {0.2, 1, 0.2, 1}, 1.0, nil, 0.25)
        popupManager:add(string.format("+%.1f%% Speed", speedPct), px, py - offset, {0.4, 0.8, 1, 1}, 1.0, nil, 0.75)
    else
        print("[WEAPON LEVEL UP POPUP] PopupManager is nil in Weapon:levelUp()")
    end
end

function Weapon:recalculateStats()
    local rarity = self.rarity or "common"
    local multipliers = Weapon.RARITY_STAT_MULTIPLIERS[rarity] or Weapon.RARITY_STAT_MULTIPLIERS.common

    self.damage = ((self.baseDamage or 10) + (self.level - 1) * 2) * (multipliers.damage or 1)
    self.speed = ((self.baseSpeed or 200) + (self.level - 1) * 0.3) * (multipliers.speed or 1)
    self.fireRate = (self.baseFireRate + (self.level - 1) * 0.05) * (multipliers.fireRate or 1)
    self.cooldown = Cooldown:new(1 / self.fireRate)
    self.projectileSpeedBonus = (1 + 0.1 * (self.level - 1)) * (multipliers.speed or 1)

    -- special/status effects
    if self.level < 5 then
        self.knockback = 0
    elseif self.level == 5 then
        self.knockback = 140
    else 
        self.knockback = 140 * (1 + 0.10 * (self.level - 5))
    end
end

function Weapon.pickRandomRarity(rarityWeights)
    rarityWeights = rarityWeights or {}
    local total = 0

    for _, weight in pairs(rarityWeights) do
        total = total + weight
    end

    local rnd = math.random() * total
    local cumulative = 0

    for rarity, weight in pairs(rarityWeights) do
        cumulative = cumulative + weight
        if rnd <= cumulative then
            return rarity
        end
    end
    return "common" -- fallback
end


function Weapon:getProjectileSpeed()
    return self.speed
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