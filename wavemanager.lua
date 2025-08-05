local WaveManager = {}
WaveManager.__index = WaveManager

function WaveManager.new(levelData)
    local defaultWaveDuration = 20
    local initialDuration = (levelData.waves and levelData.waves[1] and levelData.waves[1].duration) or defaultWaveDuration
    return setmetatable({
        currentWave = 1,
        waves = levelData.waves,
        spawnTimer = 0,
        spawnedCount = 0,
        lastSpawnTime = nil,
        active = true,
        waveTimeLeft = initialDuration,

        isFinished = false,
    }, WaveManager)
end

function WaveManager:update(dt, spawnFunction)
    if not self.active or not self.waves or self.currentWave > #self.waves then return end
    
    local wave = self.waves[self.currentWave]
    if not wave then return end -- nil safety check

    -- Staggered spawning logic for optimization
    self.spawnTimer = self.spawnTimer + dt
    local spawnCooldown = wave.spawnInterval or 0.1  -- 100ms between spawns (adjust as needed)
    
    if self.spawnTimer >= wave.delay and self.spawnedCount < wave.enemyCount then
        if self.lastSpawnTime == nil or (self.spawnTimer - self.lastSpawnTime) >= spawnCooldown then
            spawnFunction(wave.enemyTypes)
            self.spawnedCount = self.spawnedCount + 1
            self.lastSpawnTime = self.spawnTimer
        end
    end

    -- Check if all enemies for the wave have been spawned AND defeated
    -- if self.spawnedCount >= wave.enemyCount and #enemies == 0 then
    --     self:nextWave()
    -- end
    -- Only move to next wave if timer is up
    self.waveTimeLeft = math.max(0, self.waveTimeLeft - dt)
    if self.waveTimeLeft <= 0 then
        if self.currentWave < #self.waves then
            self:nextWave()
        else
            if not self.isFinished then
                self.isFinished = true
            end
        end
    end
end

function WaveManager:nextWave()
    self.currentWave = self.currentWave + 1
    self.spawnedCount = 0
    self.spawnTimer = 0
    self.active = self.currentWave <= #self.waves

    local offset = (player and player.height or 32) / 2 + 18
    local nextWave = self.waves[self.currentWave]
    local defaultWaveDuration = 20

    if nextWave then
        self.waveTimeLeft = nextWave.duration or defaultWaveDuration  -- Reset to next wave duration
    else
        self.waveTimeLeft = 0  -- No more waves, set to 0
    end

    -- TODO: make this popup work 8/5/25
    if popupManager and player and nextWave then
        popupManager:add("Wave " .. self.currentWave .. " Begins!", player.x, player.y - offset, {1,1,1,1}, 1.25, -30, 0.25)
    end

     if not self.active then
        print("ALL WAVES COMPLETED")
    end
end

return WaveManager
