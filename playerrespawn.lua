-- playerrespawn.lua, for testing purposes only!!! 6/11/25
local PlayerRespawn = {}

function PlayerRespawn.respawnPlayer(player, world)
    -- Reset player state
    player.x = 60
    player.y = love.graphics.getHeight() / 3
    player.health = 100
    player.isDead = false
    player.isFlashing = false
    player.flashTimer = 0

    player.isInvincible = true
    player.invincibleTimer = player.invincibleDuration

    -- Reset animation
    if player.animations and player.animations.idle then
        player.currentAnimation = player.animations.idle
    end

    -- Re-create collider if missing
    if not player.collider then
        player.collider = world:newBSGRectangleCollider(player.x, player.y, player.width, player.height, 10)
        player.collider:setFixedRotation(true)
        player.collider:setUserData(player)
        player.collider:setCollisionClass('player')
        player.collider:setObject(player)
    else
        player.collider:setPosition(player.x, player.y)
        player.collider:setLinearVelocity(0, 0)
    end

    print("Player respawned at ("..player.x..","..player.y..") and is invincible for " .. tostring(player.invincibleDuration) .. " seconds!")
end

return PlayerRespawn