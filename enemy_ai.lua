local Projectile = require("projectile")

local EnemyAI = {}

function EnemyAI.pursueTarget(self, dt)
    if not self.target then return end

    -- AI: Decide movement direction/velocity
    if self.target then
        -- Calculate direction vector from self to target
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y

        -- Normalize the direction vector (to get a unit vector)
        local distance = math.sqrt(dx*dx + dy*dy)

        if distance > 0.1 then -- Only move if not already at the target's exact position
            self.isMoving = true
            local dirX = dx / distance
            local dirY = dy / distance

            -- Update position based on direction and speed
            -- self.x = self.x + dirX * self.speed * dt
            -- self.y = self.y + dirY * self.speed * dt

            self.collider:setLinearVelocity(dirX * self.speed, dirY * self.speed)
        else
            self.collider:setLinearVelocity(0, 0)
        end
    else
        self.collider:setLinearVelocity(0, 0)
    end
    -- Alternatively, if you prefer using xVel/yVel:
    -- self.xVel = dirX * self.speed
    -- self.yVel = dirY * self.speed

    -- No target? Default behavior (e.g., patrol, stay idle, or move randomly)
    -- For now, if no target, it will not move based on target logic.
    -- You could, for example, make it move slowly to the left:
        
    -- self.x = self.x - (self.speed * 0.25) * dt
    -- self.xvel = (self.speed * 0.25) * dt
end

function EnemyAI.patrolarea(enemy, dt, patrolRange, onPlayerNear)
    enemy.patrolOriginXPos = enemy.patrolOriginXPos or enemy.x -- x pos of enemy
    enemy.patrolDirection = enemy.patrolDirection or 1 -- direction to patrol next

    local minXPos = enemy.patrolOriginXPos - patrolRange
    local maxXPos = enemy.patrolOriginXPos + patrolRange

    -- patrol movement
    if enemy.x <= minXPos then
        enemy.patrolDirection = 1
    elseif enemy.x >= maxXPos then
        enemy.patrolDirection = -1
    end
    enemy.x = enemy.x + (enemy.speed * enemy.patrolDirection * dt)

    -- player and enemy prox check
    if enemy.player and onPlayerNear then
        local dx = enemy.player.x - enemy.x
        local dy = enemy.player.y - enemy.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist <= (enemy.awarenessRange or 200) then
            onPlayerNear(enemy, dt)
        end
    end
end

-- shoot-at-player action
function EnemyAI.shootAtPlayer(enemy, dt)
    enemy.shootCooldown = (enemy.shootCooldown or 0) - dt
    if enemy.shootCooldown <= 0 then
        local dx = enemy.player.x - enemy.x
        local dy = enemy.player.y - enemy.y
        local angle = math.atan2(dy, dx)
        Projectile.getProjectile(enemy.world, enemy.x, enemy.y, angle, 250, enemy.baseDamage or 15, enemy)
        enemy.shootCooldown = enemy.shootInterval or 1.5
    end
end

return EnemyAI