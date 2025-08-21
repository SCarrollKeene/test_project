local Debug = require("game_debug")
local Particle = require("particle")
local Gamestate = require("libraries/hump/gamestate")
local LevelManager = require("levelmanager")
local enemyTypes = require("enemytypes")
local data_store = require("data_store")

local Collision = {}

function Collision.beginContact(a, b, coll, ctx)
        local dataA = a:getUserData() -- both Should be the projectile/enemy data
        local dataB = b:getUserData() -- based on the collision check if statement below
        local projectile, enemy, wall, player

        -- make function local to prevent overwriting similar outer variables
        local function handlePlayerCollisionEvents(a, b)
            -- Add defensive NIL checks
            -- made collision handler resilient to incomplete (user) collision data
            if not a or not b or not a.type or not b.type then
                return
            end
            local player, enemy
            -- Check for Player/Enemy collision
            if (a.type == "player" and b.type == "enemy") then
                player, enemy = a, b 
            elseif (b.type == "player" and a.type == "enemy") then
                player, enemy = b, a
            else
                return -- exit if not player/enemy collision
            end
    
            Debug.debugPrint(string.format("COLLISION: %s vs %s", a.type, b.type))

            -- Handle Player-Enemy interactions
            if player and not player.isDead then
                if not player.isInvincible then
                    player:takeDamage(enemy.baseDamage, data_store.runData.score)
                end
            end
        end

        -- Player-Portal collision
        local player_obj, portal_obj
        if dataA and dataA.type == "player" and dataB and dataB.type == "portal" then
            player_obj, portal_obj = dataA, dataB
        elseif dataB and dataB.type == "player" and dataA and dataA.type == "portal" then
            player_obj, portal_obj = dataB, dataA
        end
        
        if player_obj and portal_obj then
            if ctx.portal and ctx.portal.cooldownActive then
                ctx.sounds.ghost:play() -- portal

                print("Gamestate.current() is", tostring(Gamestate.current()))
                print("ctx.playingState is", tostring(ctx.playingState))
                print("ctx.safeRoomState is", tostring(ctx.safeRoomState))

                if Gamestate.current() == ctx.playingState then
                    ctx.nextState = ctx.safeRoomState
                    ctx.nextStateParams = {ctx.world, ctx.enemyPool, ctx.enemyImageCache, ctx.mapCache, ctx.playingState, ctx.projectileBatches} -- pass saferooms cache
                elseif Gamestate.current() == ctx.safeRoomState then
                    -- LevelManager:loadLevel(LevelManager.currentLevel + 1)
                    LevelManager.currentLevel = LevelManager.currentLevel + 1
                    ctx.nextState = ctx.playingState 
                    ctx.nextStateParams = {ctx.world, ctx.enemyPool, ctx.enemyImageCache, ctx.mapCache, ctx.safeRoomState, ctx.projectileBatches}
                end

                ctx.pendingRoomTransition = true
                ctx.fading = true
                ctx.fadeDirection = 1
                ctx.fadeTimer = 0  
                if ctx.portal then
                    ctx.portal:destroy()
                    ctx.portal = nil
                end
            end
        end

        -- execute function
        handlePlayerCollisionEvents(dataA, dataB)

        -- Check for Projectile-Enemy collision
        if dataA and dataA.damage and dataA.owner and dataB and dataB.health and not dataB.damage then -- Heuristic eval: projectile has damage, enemy has health but not damage field
            projectile = dataA
            enemy = dataB
        elseif dataB and dataB.damage and dataB.owner and dataA and dataA.health and not dataA.damage then
            projectile = dataB
            enemy = dataA
        end

        -- Ignore Player-Enemy collision in safe room
        if Gamestate.current() == safeRoom and 
        (a.type == "player" and b.type == "enemy") then
            return -- Ignore damage
        end

        -- Handle Projectile-Enemy collision
        if projectile and enemy and not enemy.isDead then -- Ensure enemy isn't already marked dead
            -- beginContact starts
            -- update when enemy can also launch projectiles 5/30/25
            if projectile and enemy and projectile.owner ~= enemy then
                
                --Debug.debugPrint(string.format("PLAYER-ENEMY COLLISION: Projectile (owner: %s, damage: %.2f) vs Enemy (%s, health: %.2f)",
                -- (projectile.owner and projectile.owner.name) or "Unknown", projectile.damage, enemy.name, enemy.health))
                
                projectile:onHitEnemy(enemy) -- Projectile handles its collision consequence
                -- enemy:takeDamage(projectile.damage) -- Enemy's own method is called
            end

            -- Projectile cleanup/removal logic (destroy collider, flag for removal)
            -- subject to removal as this is being handled by enemy's die() function logic
            -- I like the way this handles collider removal, its removed immediately upon contact 5/30/25
            -- if projectile.collider then
            --     projectile.collider:destroy() -- Destroy projectile collider
            --     projectile.collider = nil
            -- end
            -- projectile.toBeRemoved = true -- Flag projectile for removal from table
        end

        -- Check for Projectile-Wall collision
        if (dataA and dataA.type == "wall" and dataB and dataB.type == "projectile") then
            local proj = dataB.reference or dataB
            -- impact projectile effect
            local particleImpact = Particle.getOnImpactEffect()
            if particleImpact and proj then
                particleImpact:setPosition(proj.x, proj.y)
                particleImpact:emit(8)
                -- table.insert(globalParticleSystems, particleImpact)
                table.insert(ctx.globalParticleSystems, { ps = particleImpact, type = "impactEffect", radius = 32 } ) -- Context-based pooling
            end
            proj:destroySelf() -- destroy projectile on wall collision
        elseif (dataB and dataB.type == "wall" and dataA and dataA.type == "projectile") then
            local proj = dataA.reference or dataA
            -- impact projectile effect
            local particleImpact = Particle.getOnImpactEffect()
            if particleImpact and proj then
                particleImpact:setPosition(proj.x, proj.y)
                particleImpact:emit(8)
                -- table.insert(globalParticleSystems, particleImpact)
                table.insert(ctx.globalParticleSystems, { ps = particleImpact, type = "impactEffect", radius = 32 } ) -- Context-based pooling
            end
            proj:destroySelf() -- destroy projectile on wall collision
            -- One is wall, one is projectile
            -- local projectile = dataA.type and dataA or dataB
             -- projectile:destroySelf()  -- destroy projectile on wall collision
            -- dataB:deactivate() -- deactivate projectile
            -- projectile:destroySelf() -- destroy projectile
        end

        -- Destroy projectile collider and remove from table
        -- projectile.toBeRemoved = true -- flag for removal from the projectiles table
        -- if projectile.collider then 
        --     projectile.collider:destroy() 
        --     projectile.collider = nil -- set projectile collider to nil after projectile is destroyed because its no longer active
        -- end
end

return Collision