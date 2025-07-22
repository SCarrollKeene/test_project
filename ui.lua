local Particle = require("particle")
local RARITY_COLORS = Particle.RARITY_COLORS

local UI = {}

function UI.drawWeaponComparison(current, candidate)
    local startX, startY, pad = 400, 200, 22
    local panelW, panelH, panelSpacing = 260, 180, 40
    local borderW = 4

    -- Helper to draw weapon panel (used for both current and candidate)
    local function drawWeaponPanel(weapon, x, y, label, isEquipped)
        local rarity = (weapon.rarity or "common"):lower()
        local borderColor = RARITY_COLORS[rarity] or RARITY_COLORS.common

        -- Draw background panel (semi-opaque dark)
        love.graphics.setColor(0.13, 0.13, 0.13, 0.92)
        love.graphics.rectangle("fill", x, y, panelW, panelH, 14, 14)

        -- Draw rarity border
        love.graphics.setLineWidth(borderW)
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
        love.graphics.rectangle("line", x, y, panelW, panelH, 14, 14)

        -- Draw weapon label, name, and stats
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, x + 10, y + 10)
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
        love.graphics.printf(" (" .. rarity .. ")", x + 10, y + 36, panelW - 20)
        love.graphics.setColor(1, 1, 1, 1)

        -- Distinguish between actual and base damage
        local dmgValue = tostring(weapon.damage)
        local fireRateValue = tostring(weapon.fireRate)
        local speedValue = tostring(weapon.speed)

        love.graphics.print("Damage: " .. dmgValue, x + 10, y + 66)
        love.graphics.print("Fire rate: " .. fireRateValue, x + 10, y + 96)
        love.graphics.print("Speed: " .. speedValue, x + 10, y + 126)
    end

    -- Draw current weapon (left) and candidate (right)
    drawWeaponPanel(current, startX, startY, current.name or "????", true)
    drawWeaponPanel(candidate, startX + panelW + panelSpacing, startY, candidate.name or "????", false)

    -- Draw instructions below
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Press [E] to Equip   [Q] to Skip", startX, startY + panelH + 32)
end

return UI
