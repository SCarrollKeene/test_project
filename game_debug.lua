local cam = require("camera")
local Projectile = require("projectile")  -- Assuming you have a Projectile module
-- move to a utilities folder later

local Debug = {}

Debug.mode = false  -- Global debug mode flag

function Debug.keypressed(key)
    if key == "t" then
        Debug.mode = not Debug.mode
        print("[DEBUG MODE]: ", Debug.mode and "ON" or "OFF")
    end
end

function Debug.draw(projectiles, enemies, globalParticleSystems, projectileBatch)
    if not Debug.mode then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Active projectiles: " .. #projectiles, 20, 170)
    love.graphics.print("Projectile pool size: " .. Projectile.getPoolSize(), 20, 200)
    love.graphics.print("New proj creation: " .. Projectile.getNewCreateCount(), 20, 230)
    love.graphics.print("Particle Systems: " .. #globalParticleSystems, 20, 260)
    love.graphics.print("Enemies: " .. #enemies, 20, 290)
    love.graphics.print("Enemy pool size: " .. #enemyPool, 20, 320)
    love.graphics.print(string.format("Next cleanup in: %.1f", math.max(0, 10 - Projectile.getCleanUpTimer())), 20, 350)
    -- Projectile batch info
    local batchActive = projectileBatch and "YES" or "NO"
    love.graphics.print("Projectile Batch Active: " .. batchActive, 20, 410)
     local batched = 0
    local individual = 0
    for _, enemy in ipairs(enemies) do
        if not enemy.toBeRemoved then
            if enemy.isFlashing then individual = individual + 1
            else batched = batched + 1 end
        end
    end
    love.graphics.print("Batched Enemies: " .. batched, 20, 440)
    love.graphics.print("Individual Enemies: " .. individual, 20, 470)
    love.graphics.print("Draw Calls: " .. love.graphics.getStats().drawcalls, 20, 500)
    -- love.graphics.print("Flashing Enemies: " .. #toDrawIndividually, 20, 500)
    local active, inactive = Projectile.getStats()
    love.graphics.print("Projectiles: "..active.." active, "..inactive.." inactive", 20, 530)


     -- Show reuse stats
    local deadCount = 0
    for _, e in ipairs(enemyPool) do
        if e.isDead then deadCount = deadCount + 1 end
    end
    love.graphics.print("Reusable enemies: " .. deadCount, 20, 380)
end

-- supposed to draw all collisions in the world, but its not working as intended
function Debug.drawCollisions(world)
    if not Debug.mode then return end
    world:draw()
end

-- Draw enemy tracking lines (if enabled)
function Debug.drawEnemyTracking(enemies, player)
    if not Debug.mode then return end

    for _, enemy in ipairs(enemies) do
        if enemy.target and enemy.target == player then
            love.graphics.setColor(1, 0, 0)
            love.graphics.line(enemy.x, enemy.y, player.x, player.y)
            love.graphics.setColor(1, 1, 1)
        end
    end
end

return Debug