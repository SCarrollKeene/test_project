local Assets = require("assets")
local Particle = require("particle")
local RARITY_COLORS = Particle.RARITY_COLORS

local UI = {}

function UI.drawShardCounter(x, y, metaData)
    local icon = Assets.images.shard
    if not icon then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(icon, x, y, 0, 1.5, 1.5)  -- Adjust scale for visibility (1.5x)
    love.graphics.printf("x " .. tostring(metaData.shards or 0), x + 40, y + 8, 100, "left")
end

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

        -- Draw the weapon image
        if weapon.image then
            -- Set image dimensions (adjust to fit card design)
            local imgW, imgH = 48, 48
            -- Offset for image placement within the card panel
            local imgX = x + 10
            local imgY = y + 15
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(weapon.image, imgX, imgY, 0, imgW 
                / weapon.image:getWidth(), imgH 
                / weapon.image:getHeight())
        end

        -- Draw weapon label, name, and stats
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, x + 80, y + 10)
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
        love.graphics.printf(" (" .. rarity .. ")", x + 70, y + 36, panelW - 20)
        love.graphics.setColor(1, 1, 1, 1)

        -- Distinguish between actual and base damage
        local dmgValue = tostring(weapon.damage)
        local fireRateValue = tostring(weapon.fireRate)
        local speedValue = tostring(weapon.speed)

        love.graphics.print("Damage: " .. dmgValue, x + 10, y + 76)
        love.graphics.print("Fire rate: " .. fireRateValue, x + 10, y + 106)
        love.graphics.print("Speed: " .. speedValue, x + 10, y + 136)
    end

    -- Draw current weapon (left) and candidate (right)
    drawWeaponPanel(current, startX, startY, current.name or "????", true)
    drawWeaponPanel(candidate, startX + panelW + panelSpacing, startY, candidate.name or "????", false)

    -- Draw instructions below
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Press [E] to Equip   [Q] to Skip", startX, startY + panelH + 32)
end

return UI
