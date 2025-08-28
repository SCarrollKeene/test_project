local CamManager = require("cam_manager")
local Projectile = require("projectile")  -- Assuming you have a Projectile module
-- move to a utilities folder later

local Debug = {}

Debug.mode = false  -- Global debug mode flag
Debug.showWalls = false  -- Flag to show wall colliders
Debug.traceParticles = false
Debug.showSpatialGrid = false
Debug.showAllPhysicsFixtures = false

function Debug.keypressed(key)
    if key == "t" and not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        Debug.mode = not Debug.mode
        print("[DEBUG MODE]: ", Debug.mode and "ON" or "OFF")

        Debug.showAllPhysicsFixtures = not Debug.showAllPhysicsFixtures
        print("[DEBUG] All Physics Fixtures: ", Debug.showAllPhysicsFixtures and "ON" or "OFF")
        Debug.drawAllPhysicsFixtures(world)
    end

    if (key == "t" or key == "T") and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        Debug.showSpatialGrid = not Debug.showSpatialGrid
        print("[DEBUG] Spatial Grid: ", Debug.showSpatialGrid and "ON" or "OFF")
        Debug.drawSpatialGrid(world)
    end
end

function Debug.debugPrint(...)
    if Debug.mode then
        print(...)
    end
end

function Debug.draw(projectiles, enemies, globalParticleSystems, projectileBatch, enemyPool)
    if not Debug.mode then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Active projectiles: " .. #projectiles, 20, 170)
    love.graphics.print("Projectile pool size: " .. Projectile.getPoolSize(), 20, 200)
    love.graphics.print("New proj creation: " .. Projectile.getNewCreateCount(), 20, 230)
    love.graphics.print("Particle Systems: " .. #globalParticleSystems, 20, 260)
    love.graphics.print("Enemies: " .. #enemies, 20, 290)
    local poolSize = type(enemyPool) == "table" and #enemyPool or 0
    love.graphics.print("Enemy pool size: " .. poolSize, 20, 320)
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
    if type(enemyPool) == "table" then
        for _, e in ipairs(enemyPool) do
            if e.isDead then deadCount = deadCount + 1 end
        end
    end
    love.graphics.print("Reusable enemies: " .. deadCount, 20, 380)
end

-- supposed to draw all collisions in the world, but its not working as intended
function Debug.drawCollisions(world)
    if not Debug.mode then return end
    world:draw()
end

-- color code colliders
function Debug.drawColliders(wallColliders, player, portal)
    if not Debug.mode then return end
    if not Debug.showWalls then return end

    -- Draw wall colliders as red rectangles
    love.graphics.setColor(1, 0, 0, 0.5)
    for _, wall in ipairs(wallColliders) do
        if wall and wall.getBoundingBox then
            local x, y, w, h = wall:getBoundingBox()
            love.graphics.rectangle("line", x, y, w, h)
        end
    end

    -- Draw player collider as green rectangle
    if player and player.collider and player.collider.getBoundingBox then
        local x, y, w, h = player.collider:getBoundingBox()
        love.graphics.setColor(0, 1, 0, 0.5)
        love.graphics.rectangle("line", x, y, w, h)
    end

    -- Draw portal collider as blue rectangle
    if portal and portal.collider and portal.collider.getBoundingBox then
        local x, y, w, h = portal.collider:getBoundingBox()
        love.graphics.setColor(0, 0, 1, 0.5)
        love.graphics.rectangle("line", x, y, w, h)
    end

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
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

-- to visualize the spatial grid in main.lua
function Debug.drawSpatialGrid(world, navX, navY, navW, navH, grid, cellSize, gridWidth, gridHeight, mapW, mapH)
    if not Debug.showSpatialGrid then return end

    -- Defensive: bail if any arg is missing/not a table
    if type(grid) ~= "table" or not cellSize or not gridWidth or not gridHeight then return end

    if not navX or not navY or not mapW or not mapH then
        print("SpatialGrid ERROR: nav bounds or map size is nil!")
        return
    end

    print(string.format("Drawing spatial grid at navX=%d navY=%d navW=%d navH=%d cellSize=%d gridW=%d gridH=%d",
    navX, navY, navW, navH, cellSize, gridWidth, gridHeight))

    love.graphics.setColor(1, 1, 0, 0.3) -- Yellow, semi-transparent

    for x = 1, gridWidth do
        if grid[x] ~= nil then -- defensive check for if x is nil
            for y = 1, gridHeight do
                local cellX = navX + (x - 1) * cellSize
                local cellY = navY + (y - 1) * cellSize
                -- Only draw if the cell fits the map
                if cellX + cellSize > navX and cellX < navX + navW then
                    --cellY + cellSize > navY and cellY < navY + navH then
                    --love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize)
                    
                    -- Calculate clipped width/height so the cell doesn't draw past the nav area
                    local w = math.min(cellSize, (navX + navW) - cellX)
                    local h = math.min(cellSize, (navY + navH) - cellY)
                    love.graphics.rectangle("line", cellX, cellY, w, h)
                    -- Optionally, show entity count in each cell:
                    if grid[x][y] ~= nil and #grid[x][y] > 0 then
                        love.graphics.setColor(1, 0, 0, 0.7)
                        love.graphics.print(tostring(#grid[x][y]), cellX + 4, cellY + 4)
                        love.graphics.setColor(1, 1, 0, 0.3)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function Debug.drawAllPhysicsFixtures(world)
    if not Debug.showAllPhysicsFixtures then return end

    for _, body in ipairs(world:getBodies()) do
        for _, fixture in ipairs(body:getFixtures()) do
            local shape = fixture:getShape()
            if shape:typeOf("PolygonShape") then
                local points = {body:getWorldPoints(shape:getPoints())}
                love.graphics.setColor(1, 0, 1, 0.3) -- Magenta for visibility
                love.graphics.polygon("line", points)
            elseif shape:typeOf("CircleShape") then
                local x, y = body:getWorldPoints(shape:getPoint())
                love.graphics.setColor(1, 0, 1, 0.3)
                love.graphics.circle("line", x, y, shape:getRadius())
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Debug