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

function Debug.draw(projectiles, enemies, globalParticleSystems)
    if not Debug.mode then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 140)
    love.graphics.print("Active projectiles: " .. #projectiles, 20, 170)
    love.graphics.print("Pool size: " .. Projectile.getPoolSize(), 20, 200)
    love.graphics.print("New proj creation: " .. Projectile.getNewCreateCount(), 20, 230)
    love.graphics.print("Particle Systems: " .. #globalParticleSystems, 20, 260)
    love.graphics.print("Enemies: " .. #enemies, 20, 290)
    love.graphics.print("Enemy pool size: " .. #enemyPool, 20, 320)
    love.graphics.print(string.format("Next cleanup in: %.1f", math.max(0, 10 - Projectile.getCleanUpTimer())), 20, 350)

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