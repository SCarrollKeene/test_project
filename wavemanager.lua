local WaveManager = {}
WaveManager.__index = WaveManager

function WaveManager.new(levelData)
    return setmetatable({
        currentWave = 1,
        waves = levelData.waves,
        spawnTimer = 0,
        spawnedCount = 0,
        lastSpawnTime = nil,
        active = true
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
    if self.spawnedCount >= wave.enemyCount and #enemies == 0 then
        self:nextWave()
    end
end

function WaveManager:nextWave()
    self.currentWave = self.currentWave + 1
    self.spawnedCount = 0
    self.spawnTimer = 0
    self.active = self.currentWave <= #self.waves

     if not self.active then
        print("ALL WAVES COMPLETED")
    end
end

return WaveManager
