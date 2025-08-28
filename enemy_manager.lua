local EnemyManager = {}

EnemyManager.targetFps = 60 -- FPS to maintain, testing 60 and 120
EnemyManager.aiThrottleStep = 1 -- no initial throttling
local throttleCheckTimer = 0 -- periodic timer to check performance

function EnemyManager.monitorPerformanceAndAdapt(dt)
    throttleCheckTimer = throttleCheckTimer + dt
    local fps = love.timer.getFPS()
    if throttleCheckTimer > 0.5 then -- check more often
        if fps < 30 then
            EnemyManager.aiThrottleStep = math.max(8, EnemyManager.aiThrottleStep + 2)
        elseif fps < EnemyManager.targetFps - 5 then
            EnemyManager.aiThrottleStep = math.max(2, EnemyManager.aiThrottleStep + 1)
        elseif fps > EnemyManager.targetFps + 5 and EnemyManager.aiThrottleStep > 1 then
            EnemyManager.aiThrottleStep = EnemyManager.aiThrottleStep - 1
        end
        throttleCheckTimer = 0
    end
end

return EnemyManager
