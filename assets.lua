local Assets = {}

Assets.images = {
    shard = nil,
    red_orb = nil,
    fireball = nil,
    crystal = nil,
    fire_crystal = nil,
    soulsplode = nil,
    gorgoneye = nil,
    -- Add more as needed
}

function Assets.load()
    Assets.images.shard = love.graphics.newImage("sprites/magicite-shard.png")
    Assets.images.red_orb = love.graphics.newImage("sprites/orb_red.png")
    Assets.images.fireball = love.graphics.newImage("sprites/fireball.png")
    Assets.images.firecrystal = love.graphics.newImage("sprites/crystal.png")
    Assets.images.soulsplode = love.graphics.newImage("sprites/soulsplode.png")
    Assets.images.gorgoneye = love.graphics.newImage("sprites/gorgoneye-tileset.png")
    -- load image/sound/fonts here
end

return Assets
