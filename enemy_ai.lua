local Assets = require("assets")
local Projectile = require("projectile")
local projectiles = require("projectile_store")

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

function EnemyAI.patrolArea(enemy, dt, patrolRange, onPlayerNear, direction)
    -- enemy.patrolOriginXPos = enemy.patrolOriginXPos or enemy.x -- x pos of enemy
    -- enemy.patrolDirection = enemy.patrolDirection or 1 -- direction to patrol next

    -- local minXPos = enemy.patrolOriginXPos - patrolRange
    -- local maxXPos = enemy.patrolOriginXPos + patrolRange

    -- -- current collider position
    -- local x, y = enemy.x, enemy.y
    -- if enemy.collider then
    --     x, y = enemy.collider:getPosition()
    -- end

    -- -- patrol movement
    -- if x <= minXPos then
    --     enemy.patrolDirection = 1
    -- elseif x >= maxXPos then
    --     enemy.patrolDirection = -1
    -- end

    -- -- physics based movement using setLinearVelocity
    -- if enemy.collider then
    --     enemy.collider:setLinearVelocity(enemy.speed * enemy.patrolDirection, 0)
    -- end

    direction = direction or "horizontal"

    if direction == "horizontal" then
        enemy.patrolOriginXPos = enemy.patrolOriginXPos or enemy.x
        enemy.patrolDirection = enemy.patrolDirection or 1
        local minXPos = enemy.patrolOriginXPos - patrolRange
        local maxXPos = enemy.patrolOriginXPos + patrolRange
        local x = enemy.x
        if enemy.collider then x = enemy.collider:getX() end
        if x <= minXPos then
            enemy.patrolDirection = 1
        elseif x >= maxXPos then
            enemy.patrolDirection = -1
        end
        if enemy.collider then
            enemy.collider:setLinearVelocity(enemy.speed * enemy.patrolDirection, 0)
        end

    elseif direction == "vertical" then
        enemy.patrolOriginYPos = enemy.patrolOriginYPos or enemy.y
        enemy.patrolVDirection = enemy.patrolVDirection or 1
        local minYPos = enemy.patrolOriginYPos - patrolRange
        local maxYPos = enemy.patrolOriginYPos + patrolRange
        local y = enemy.y
        if enemy.collider then y = enemy.collider:getY() end
        if y <= minYPos then
            enemy.patrolVDirection = 1
        elseif y >= maxYPos then
            enemy.patrolVDirection = -1
        end
        if enemy.collider then
            enemy.collider:setLinearVelocity(0, enemy.speed * enemy.patrolVDirection)
        end

    elseif direction == "both" then
        -- Horizontal setup
        enemy.patrolOriginXPos = enemy.patrolOriginXPos or enemy.x
        enemy.patrolDirection  = enemy.patrolDirection or 1
        local minXPos = enemy.patrolOriginXPos - patrolRange
        local maxXPos = enemy.patrolOriginXPos + patrolRange
        local x = enemy.x
        if enemy.collider then x = enemy.collider:getX() end
        if x <= minXPos then
            enemy.patrolDirection = 1
        elseif x >= maxXPos then
            enemy.patrolDirection = -1
        end

        -- Vertical setup
        enemy.patrolOriginYPos = enemy.patrolOriginYPos or enemy.y
        enemy.patrolVDirection = enemy.patrolVDirection or 1
        local minYPos = enemy.patrolOriginYPos - patrolRange
        local maxYPos = enemy.patrolOriginYPos + patrolRange
        local y = enemy.y
        if enemy.collider then y = enemy.collider:getY() end
        if y <= minYPos then
            enemy.patrolVDirection = 1
        elseif y >= maxYPos then
            enemy.patrolVDirection = -1
        end

        -- Apply both x and y velocity
        if enemy.collider then
            enemy.collider:setLinearVelocity(
                enemy.speed * enemy.patrolDirection,
                enemy.speed * enemy.patrolVDirection
            )
        end
    end

    -- player and enemy prox check
    if enemy.player and onPlayerNear then
        local dx = enemy.player.x - x
        local dy = enemy.player.y - y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist <= (enemy.awarenessRange or 200) then
            if enemy.collider then
                enemy.collider:setLinearVelocity(0, 0)
            end
            onPlayerNear(enemy, dt)
        end
    end
end

-- shoot-at-player action
function EnemyAI.shootAtPlayer(enemy, dt, projectiles)
    enemy.shootCooldown = (enemy.shootCooldown or 0) - dt
    if enemy.shootCooldown <= 0 then
        local x = enemy.x
        local y = enemy.y
        if enemy.collider then
            x, y = enemy.collider:getPosition()
        end

        local dx = enemy.player.x - x
        local dy = enemy.player.y - y
        local angle = math.atan2(dy, dx)
        local projectile = Projectile.getProjectile(enemy.world, enemy.x, enemy.y, angle, 250, enemy.baseDamage or 15, enemy, Assets.images.gorgoneye_shot, nil, nil)
        if projectile then
            table.insert(projectiles, projectile)
            print("Shooting: assigned image", projectile.image, projectile)
        end
        enemy.shootCooldown = enemy.shootInterval or 1.5
    end

    if enemy.collider then
        enemy.collider:setLinearVelocity(0, 0)
    end
end

return EnemyAI