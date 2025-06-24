local Loading = {}

local sounds = {
  "sounds/ghost.wav",
  "sounds/portal.wav"
}

local assets = {
  "sprites/mage-NESW.png",
  "sprites/dash.png",
  "sprites/slime_black.png",
  "sprites/slime_blue.png",
  "sprites/slime_violet.png",
  "maps/room1.lua",
  "maps/room2.lua",
  "maps/room3.lua",
  "maps/saferoom.lua"
}

local loaded = 0
local total = #assets

function Loading:enter()
  loaded = 0
end

function Loading:update(dt)
  if loaded < total then
    local asset = assets[loaded + 1]
    if asset:match("%.png$") then
      love.graphics.newImage(asset)
    elseif asset:match("%.lua$") then
      require(asset:gsub("%.lua$", ""))
    end
    loaded = loaded + 1
  else
    Gamestate.switch("playing") -- or "menu"
  end
end

function Loading:draw()
  love.graphics.print("Loading...", 300, 200)
  local progress = loaded / total
  love.graphics.rectangle("line", 200, 250, 400, 30)
  love.graphics.rectangle("fill", 200, 250, 400 * progress, 30)
end

return Loading