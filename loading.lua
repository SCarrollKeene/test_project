local Assets = require("assets")
local Gamestate = require("libraries/hump/gamestate")
local MapLoader = require("maploader")
local Enemy = require("enemy")
local enemyTypes = require("enemytypes")
local ENEMY_CLASSES = require("enemy_registry")
local Particle = require("particle")

local Loading = {}

sounds = sounds or {}

local assets = {
    images = {
        "sprites/mage-NESW.png",
        "sprites/dash.png",
        "sprites/slime_black.png",
        "sprites/slime_blue.png",
        "sprites/slime_violet.png",
    },
    maps = {
        "maps/room0.lua",
        "maps/room1.lua",
        "maps/room2.lua",
        "maps/room3.lua",
        "maps/room4.lua",
        "maps/saferoommap.lua"
    },
    sounds = {
        "sounds/ghost.wav",
        "sounds/blip.wav"
    },
    modules = {
        "levelmanager",
        "player",
        "enemy",
        "portal",
        "walls"
    }
}

function Loading:enter(previous_state, world, playing_state, safeRoom_state)

    -- load player save data
    -- TODO: implement save game and load game logic later on 6/20/25
    -- TODO: add a main menu, move this to a “Continue” or “New Game” selector
    -- local save = SaveSystem.loadGame()
    -- if save then
    --     data_store.runData = save.run
    --     data_store.metaData = save.meta
    -- print("LOADING SAVE 1 loaded")
    -- else
    --     data_store.runData = createNewRun()
    --     data_store.metaData = loadDefaultMeta()
    -- print("LOADING NEW run/meta data created")
    -- end

    -- optional, preloader for particle images. I think the safeloading in particle.lua should be good for now
    -- Particle.preloadImages()

    self.world = world
    self.playing_state = playing_state
    self.safeRoom_state = safeRoom_state

    self.loaded = 0
    self.total = self.calculateTotalAssets()
    self.modulesLoaded  = false
    self.imagesLoaded   = false
    self.soundsLoaded   = false
    self.mapsLoaded     = false
    self.assetsAlreadyLoaded = false  -- Boot flag

    -- for _, category in pairs(assets) do
    --     self.total = self.total + #category
    -- end

    -- declare cache for enemy pool use
    self.enemyImageCache = self.enemyImageCache or {} -- Use the provided cache or an empty table 
    self.enemyPools = self.enemyPools or {
        blob = {},
        gorgoneye = {}
    }
    self.mapCache = self.mapCache or {}

    -- TODO: Preload all enemy images, from main love.load, old, may not be needed anymore 8/10/25
    -- for _, blob in ipairs(enemyTypes) do
    --     if not enemyImageCache[blob.spritePath] then
    --         enemyImageCache[blob.spritePath] = love.graphics.newImage(blob.spritePath)
    --     end
    -- end

    -- only preload enemies if enemy cache is empty
    if not next(self.enemyImageCache) then
        for enemyType, enemyTable in pairs(enemyTypes) do -- preload enemy images type-keyed enemy table
            -- preload enemy images
            for _, blob in ipairs(enemyTable) do
                --print("[LOADING] Loading enemy sprite:", blob.spritePath)
                local success, img = pcall(love.graphics.newImage, blob.spritePath)
                if success and img:getWidth() > 0 and img:getHeight() > 0 then
                    --print("[LOADING] successfully loaded:", blob.spritePath)
                    self.enemyImageCache[blob.spritePath] = img
                else
                    --print("[LOADING] Invalid image:", blob.spritePath)
                    -- Use fallback texture
                    local placeholder = love.newImageData(32, 32)
                    placeholder:mapPixel(function()
                        return 1, 0, 0, 1 -- red RGBA
                    end)
                    self.enemyImageCache[blob.spritePath] = love.graphics.newImage(placeholder)
                    --print("[LOADING] Using placeholder for:", blob.spritePath)
                end
                -- Add to the loaded counter
                self.loaded = self.loaded + 1
                -- Add to the total counter
                self.total = self.total + 1
            end
        end
    end

    -- image helper function for batching
    local projectileImageNames = { "fireball", "gorgoneye_shot" }
    self.projectileImages = {}
    self.projectileBatches = {}
    for _, name in ipairs(projectileImageNames) do
        local img = Assets.images[name]
        if img then
            self.projectileImages[name] = img
            self.projectileBatches[name] = love.graphics.newSpriteBatch(img, 512)
        else
            print("[LOADING] WARNING: image missing for projectile type:", name)
        end
    end

    -- preload all enemy types with flat array
    local allEnemyVariants = {}
    for _, subTable in pairs(enemyTypes) do
        for _, variant in ipairs(subTable) do
            table.insert(allEnemyVariants, variant)
        end
    end

    -- Preload 300 enemies into enemy pool
    for i = 1, 300 do
        local pick = 1
        local pickIndex = math.random(pick, #allEnemyVariants) -- Pick a random enemy variant/type
        local enemyDef = allEnemyVariants[pickIndex] -- Get a random blob configuration
        local img = self.enemyImageCache[enemyDef.spritePath]
        -- local e = Enemy:new(world, enemyDef.name, 0, 0, 32, 32, nil, nil, enemyDef.maxHealth, enemyDef.speed, enemyDef.baseDamage, 0, img)
        local logicClass = ENEMY_CLASSES[enemyDef.name] or ENEMY_CLASSES["default"] or Enemy
        local e = logicClass:new({
            world = world, 
            name = enemyDef.name, 
            x = 0, 
            y = 0, 
            width = 32, 
            height = 32, 
            maxHealth = enemyDef.maxHealth,
            health = enemyDef.health, 
            speed = enemyDef.speed, 
            baseDamage = enemyDef.baseDamage,
            xpAmount = enemyDef.xpAmount, 
            spriteSheet = img,
            spritePath = enemyDef.spritePath
        })
        e.isDead = true -- Mark as reusable

        -- Determine the right pool by name
        local poolName = enemyDef.poolName or enemyDef.name:lower()
        self.enemyPools[poolName] = self.enemyPools[poolName] or {}
        table.insert(self.enemyPools[poolName], e)
    end

    -- check for pool loading
    for k,v in pairs(self.enemyPools) do
        print("Pool", k, "has", #v, "enemies preloaded")
    end

    -- print("[LOADING] Enemy pool preloaded. Total enemies in pool: " .. tostring(#self.enemyPool))
    -- for i, e in ipairs(self.enemyPool) do
    --     print(string.format(" [Pool #%d] Name: %s, IsDead = reusable: %s", i, e.name, tostring(e.isDead)))
    --     if i >= 5 then
    --         print(" ... (only showing first 5 of " .. #self.enemyPool .. ")")
    --         break
    --     end
    -- end

    -- Preload 100 projectiles into the correct pool
    -- for i = 1, 100 do
    --     local proj = Projectile:new(world, 0, 0, 0, 0, 0, nil)
    --     proj.active = true -- make preloaded projectiles active
    --     proj.collider:setActive(false)
    -- table.insert(Projectile.pool, proj)
    -- end
end

function Loading:calculateTotalAssets()
    local count = 0
    for _, category in pairs(assets) do
        count = count + #category
    end
    return count
end

function Loading:update(dt)
  if self.loaded < self.total then
    -- load assets
        self:loadNextAsset()
    else
        -- load into playing state
        self.assetsAlreadyLoaded = true
        Gamestate.switch(self.playing_state, self.world, self.enemyPools, self.enemyImageCache, self.mapCache, self.safeRoom_state, self.projectileBatches)
    end
end

function Loading:loadNextAsset()
    -- load in dependency order

    -- load modules
    if not self.modulesLoaded then
        for _, module in ipairs(assets.modules) do
            require(module)
        end
        self.loaded = self.loaded + #assets.modules
        self.modulesLoaded = true

    -- load images
    elseif not self.imagesLoaded then
        for _, img in ipairs(assets.images) do
            love.graphics.newImage(img)
        end
        self.loaded = self.loaded + #assets.images
        self.imagesLoaded = true

    -- load sounds
    elseif not self.soundsLoaded then
        for _, sound in ipairs(assets.sounds) do
            local name = sound:match("([^/]+)%.%w+$")
            sounds[name] = love.audio.newSource(sound, "static")
        end
        self.loaded = self.loaded + #assets.sounds
        self.soundsLoaded = true

    -- load map and walls
    elseif not self.mapsLoaded then
        for _, mapFile in ipairs(assets.maps) do
            local map, wallData = MapLoader.parse(mapFile:gsub("maps/", ""):gsub("%.lua$", ""))
            self.mapCache[mapFile] = { map = map, wallData = wallData }
        end
        self.loaded = self.loaded + #assets.maps
        self.mapsLoaded = true
    end
    --print("[LOADING] loading asset: ", assets)
end

function Loading:draw()
    local progress = self.loaded / self.total
    local barWidth = 400
    local barHeight = 30
    local x = (love.graphics.getWidth() - barWidth) / 2
    local y = love.graphics.getHeight() * 0.7
    
    -- BG, dark gray
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    
    -- Progress bar, bright teal, 3.51 contrast on current BG
    love.graphics.setColor(0, 0.7, 0.7)
    love.graphics.rectangle("fill", x, y, barWidth * progress, barHeight)
    
    -- Border, white
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, barWidth, barHeight)
    
    -- Text, white
    love.graphics.printf("Loading: " .. math.floor(progress * 100) .. "%", 
        x, y - 30, barWidth, "center")
end

return Loading