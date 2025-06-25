local Gamestate = require("libraries/hump/gamestate")

local Loading = {}

local assets = {
    images = {
        "sprites/mage-NESW.png",
        "sprites/dash.png",
        "sprites/slime_black.png",
        "sprites/slime_blue.png",
        "sprites/slime_violet.png",
    },
    maps = {
        "maps/room1.lua",
        "maps/room2.lua",
        "maps/room3.lua",
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

function Loading:enter(previous_state, world, playing_state, randomBlobs)
    self.world = world
    self.playing_state = playing_state
    self.randomBlobs = randomBlobs
    self.loaded = 0
    self.total = self.calculateTotalAssets() or #assets
    for _, category in pairs(assets) do
        self.total = self.total + #category
    end

    -- initialize cache
    self.enemyImageCache = self.enemyImageCache or {}
    self.mapCache = self.mapCache or {}

    -- only preload enemies if enemy cache is empty
    if not next(self.enemyImageCache) then
        -- preload enemy images
        for _, blob in ipairs(self.randomBlobs) do
            print("[LOADING] Loading enemy sprite:", blob.spritePath)
            local success, img = pcall(love.graphics.newImage, blob.spritePath)
            if success and img:getWidth() > 0 and img:getHeight() > 0 then
                print("[LOADING] successfully loaded:", blob.spritePath)
                self.enemyImageCache[blob.spritePath] = img
            else
                print("[LOADING] Invalid image:", blob.spritePath)
                -- Use fallback texture
                local placeholder = love.newImageData(32, 32)
                placeholder:mapPixel(function()
                    return 1, 0, 0, 1 -- red RGBA
                end)
                self.enemyImageCache[blob.spritePath] = love.graphics.newImage(placeholder)
                print("[LOADING] Using placeholder for:", blob.spritePath)
            end
        end
    end
end

function Loading:calculateTotalAssets()
    local count = 0
    -- for _, category in pairs(assets) do
    --     count = count + #category
    -- end
    -- return count
end

function Loading:update(dt)
  if self.loaded < self.total then
        self:loadNextAsset()
    else
        Gamestate.switch(self.playing_state, self.world, self.enemyImageCache, self.mapCache)
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
            love.audio.newSource(sound, "static")
        end
        self.loaded = self.loaded + #assets.sounds
        self.soundsLoaded = true

    -- load maps
    else
        for _, map in ipairs(assets.maps) do
            self.mapCache[map] = require(map:gsub("%.lua$", ""))
        end
        self.loaded = self.loaded + #assets.maps
    end
    print("[LOADING] loading asset: ", assets)
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