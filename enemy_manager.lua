local EnemyManager = {}

EnemyManager.targetFps = 60
EnemyManager.aiThrottleStep = 1
local throttleCheckTimer = 0

function EnemyManager.monitorPerformanceAndAdapt(dt)
  throttleCheckTimer = throttleCheckTimer + dt
  if throttleCheckTimer > 2 then -- check every 2 seconds
    local fps = love.timer.getFPS()
    if fps < EnemyManager.targetFps - 5 then
      EnemyManager.aiThrottleStep = EnemyManager.aiThrottleStep + 1
    elseif fps > EnemyManager.targetFps + 5 and EnemyManager.aiThrottleStep > 1 then
      EnemyManager.aiThrottleStep = EnemyManager.aiThrottleStep - 1
    end
    throttleCheckTimer = 0
  end
end

return EnemyManager
