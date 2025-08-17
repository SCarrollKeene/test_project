local wf = require("libraries/windfield")
local Assets = require("assets")
local Collision = require("collision")
local enemyTypes = require("enemytypes")
local Gamestate = require("libraries/hump/gamestate")
local Loading = require("loading")
local MapLoader = require("maploader")
local playing = require("states/playing")
local safeRoom = require("states/safeRoom")
local pause_menu = require("states/pause_menu")
local data_store = require("data_store")
local SaveSystem = require("save_game_data")
local Debug = require("game_debug")
local Projectile = require("projectile")
local Weapon = require("weapon")
local player = require("player")
local Enemy = require("enemy")
-- local Gorgoneye = require("gorgoneye")
local Walls = require("walls")
local LevelManager = require("levelmanager")
local UI = require("ui")
local sti = require("libraries/sti")
local Camera = require("libraries/hump/camera")

-- virtual resolution
local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 768

local gameCanvas -- off-screen drawing surface
local scaleX, scaleY, offsetX, offsetY -- variables for scaling and positioning 

globalParticleSystems = {}

local scoreFont = 0
_G.incrementPlayerScore = incrementPlayerScore -- Make it accessible globally for Utils.lua

-- game state definitions
local gameOver = {}

-- Debug to test table loading and enemy functions for taking damage, dying and score increment
function love.keypressed(key)
    if key == "p" then
        if Gamestate.current() == playing or Gamestate.current() == safeRoom then
            Gamestate.push(pause_menu)
            return
        elseif Gamestate.current() == pause_menu then
            Gamestate.pop()
            return
        end
    end
    
    if key == "r" and player.isDead then
        PlayerRespawn.respawnPlayer(player, world, data_store.metaData, playerScore) -- encapsulate data_store.metaData and player score to main.lua only
        return -- prevent other keys from utilizing r
    end

    if key == "space" and not player.isDead then
        player:dash()
    end

    if key == "escape" then
        love.event.quit()
    end

    -- enable debug mode
    Debug.keypressed(key)

    if key == "f5" then
        Debug.showWalls = not Debug.showWalls
    end

    if Gamestate.current() == safeRoom then
        return -- Prevent any attack actions in safe room
    end
end

function love.load()
    -- Initialize the game canvas with virtual resolution
    gameCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- Set default filter for crisp pixel art scaling (optional, but good for pixel games)
    -- love.graphics.setDefaultFilter("nearest", "nearest")

    -- Call initial game setup
    love.window.setMode(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, { resizable = true, fullscreen = false, vsync = true }) -- Ensure window is resizable
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    world = wf.newWorld(0, 0)
    -- initialize first
    wallColliders = {}

    -- collision classes must load into the world first, per order of operations/how content is loaded, I believe
    world:addCollisionClass('player', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'player')
    -- stops enemies from colliding/getting stuck on one another
    world:addCollisionClass('enemy', {ignores = {'enemy'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'enemy')
    -- ignore enemy/enemy collider when dashing
    world:addCollisionClass('player_dashing', {ignores = {'enemy'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'player_dashing')
    world:addCollisionClass('projectile', {ignores = {'projectile'}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'projectile')
    world:addCollisionClass('wall', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'wall')
    world:addCollisionClass('portal', {ignores = {}})
    Debug.debugPrint("DEBUG: main.lua: Added collision class - " .. 'portal')
    -- You can also define interactions here

    -- optional, preloader for particle images. I think the safeloading in particle.lua should be good for now
    -- Particle.preloadImages()
    Projectile.loadAssets()
    Weapon.loadAssets()
    Assets.load()

    local mage_spritesheet_path = "sprites/mage-NESW.png"
    local dash_spritesheet_path = "sprites/dash.png"
    local death_spritesheet_path = "sprites/soulsplode.png"

    player:load(world, mage_spritesheet_path, dash_spritesheet_path, death_spritesheet_path)

    -- In love.load(), after first load:
    player.mage_spritesheet_path = mage_spritesheet_path
    player.dash_spritesheet_path = dash_spritesheet_path
    player.death_spritesheet_path = death_spritesheet_path

    scoreFont = love.graphics.newFont(20)
    -- Call love.resize to set up initial scaling
    love.resize(love.graphics.getWidth(), love.graphics.getHeight())

    Gamestate.registerEvents()
    -- initial loading screen before loading playing state
    Gamestate.switch(Loading, world, playing, safeRoom)
end

function love.resize(w, h)
    -- called when the window is resized
    local aspectRatio = VIRTUAL_WIDTH / VIRTUAL_HEIGHT
    local windowAspectRatio = w / h

    if windowAspectRatio > aspectRatio then
        -- Window is wider than our virtual resolution aspect ratio (pillarboxing)
        scaleY = h / VIRTUAL_HEIGHT
        scaleX = scaleY
        offsetX = (w - VIRTUAL_WIDTH * scaleX) / 2
        offsetY = 0
    else
        -- Window is taller than our virtual resolution aspect ratio (letterboxing)
        scaleX = w / VIRTUAL_WIDTH
        scaleY = scaleX
        offsetX = 0
        offsetY = (h - VIRTUAL_HEIGHT * scaleY) / 2
    end
end

function love.update(dt)
    -- moved all logic into func playing:update(dt) because I'm utilizing hump.gamestate
end

function love.draw()
    -- moved all logic into func playing:draw() because I'm utilizing hump.gamestate

    -- Set the render target to your gameCanvas
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.1, 0.1, 0.1, 1) -- Clear the canvas (e.g., to a dark grey)

    -- Reset the render target to the screen
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1) -- Clear the actual screen to black (for letter/pillarboxing)

    -- Draw the gameCanvas to the actual screen, scaled and offset
    love.graphics.draw(gameCanvas, offsetX, offsetY, 0, scaleX, scaleY)
end

-- TODO: make ESC key global for quiting no matter what game state they are in
function love.quit()
    -- save game on quit
    SaveSystem.saveGame()
end