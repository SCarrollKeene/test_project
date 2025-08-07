local Assets = require("assets")
local Particle = require("particle")
local RARITY_COLORS = Particle.RARITY_COLORS

local UI = {}

local function printOutlined(text, x, y, outlineColor, textColor)
    local oc = outlineColor or {0,0,0,1}
    local tc = textColor or {1,1,1,1}
    -- Outline (draw in 8 directions)
    love.graphics.setColor(oc)
    love.graphics.print(text, x-1, y-1)
    love.graphics.print(text, x+1, y-1)
    love.graphics.print(text, x-1, y+1)
    love.graphics.print(text, x+1, y+1)
    love.graphics.print(text, x-1, y)
    love.graphics.print(text, x+1, y)
    love.graphics.print(text, x, y-1)
    love.graphics.print(text, x, y+1)
    -- Main text
    love.graphics.setColor(tc)
    love.graphics.print(text, x, y)
end

function UI.drawWaveCounter(waveNum, totalWaves, x, y)
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(love.graphics.newFont(22))
    local text = "Wave: " .. waveNum
    love.graphics.printf(text, x, y, 200, "left")
end

function UI.drawWaveTimer(timeLeft, x, y)
    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.setColor(1,1,1,1)
    local t = math.max(0, math.floor(timeLeft))
    local min = math.floor(t/60)
    local sec = t % 60
    local text = string.format("Time: %02d:%02d", min, sec)
    love.graphics.printf(text, x, y, 180, "left")
end

function UI.drawShardCounter(x, y, metaData)
    local icon = Assets.images.shard
    if not icon then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(icon, x, y, 0, 1.5, 1.5)  -- Adjust scale for visibility (1.5x)
    love.graphics.printf("x " .. tostring(metaData.shards or 0), x + 40, y + 8, 100, "left")
end

function UI.drawEquippedWeaponOne(x, y, player, size)
    local weapon = player.weapon
    if not weapon or not weapon.image then return end

    -- Configurable visual design
    local bgColor = {0.13, 0.13, 0.13, 0.92}     -- background
    local borderColor = {0.8, 0.58, 0.16, 1.0}   -- border
    local borderWidth = 2
    size = size or 52                            -- slightly larger for weapons if desired

    -- Background (rounded rectangle)
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, size, size, size/3, size/3)

    -- Border
    love.graphics.setLineWidth(borderWidth)
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, size, size, size/3, size/3)

    -- Draw weapon icon centered in badge
    love.graphics.setColor(1, 1, 1, 1)
    local padding = size * 0.20
    love.graphics.draw(
        weapon.image,
        x + padding,
        y + padding,
        0,
        (size - 2 * padding) / weapon.image:getWidth(),
        (size - 2 * padding) / weapon.image:getHeight()
    )
end

function UI.drawWeaponComparison(current, candidate)
    if not current or current.type ~= "weapon" or not candidate or candidate.type ~= "weapon" then
        return
    end

    local startX, startY, pad = 400, 200, 22
    local panelW, panelH, panelSpacing = 260, 220, 40
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
        local rangeValue = tostring(weapon.range)

        love.graphics.print("Damage: " .. dmgValue, x + 10, y + 76)
        love.graphics.print("Fire rate: " .. fireRateValue, x + 10, y + 106)
        love.graphics.print("Speed: " .. speedValue, x + 10, y + 136)
        love.graphics.print("Range: " .. rangeValue, x + 10, y + 166)
    end

    -- Draw current weapon (left) and candidate (right)
    drawWeaponPanel(current, startX, startY, current.name or "????", true)
    drawWeaponPanel(candidate, startX + panelW + panelSpacing, startY, candidate.name or "????", false)

    -- Draw instructions below
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    local rightCardX = startX + panelW + panelSpacing
    local messageWidth = love.graphics.getFont():getWidth("Press [E] to Equip Hold [Q] to Recycle")
    local messageX = rightCardX + (panelW - messageWidth) / 2
    local paddingBottom = 16
    printOutlined("Press [E] to Equip Hold [Q] to Recycle", rightCardX, startY + panelH + paddingBottom)

end

return UI
