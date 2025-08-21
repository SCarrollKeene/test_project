local Assets = {}

Assets.images = {
    shard = nil,
    red_orb = nil,
    fireball = nil,
    gorgoneye_shot = nil,
    crystal = nil,
    fire_crystal = nil,
    soulsplode = nil,
    slime_black = nil,
    gorgoneye = nil,
    -- Add more as needed
}

function Assets.load()
    Assets.images.shard = love.graphics.newImage("sprites/magicite-shard.png")
    Assets.images.red_orb = love.graphics.newImage("sprites/orb_red.png")
    Assets.images.fireball = love.graphics.newImage("sprites/fireball.png")
    -- print("Loaded player fireball:", Assets.images.fireball)
    Assets.images.gorgoneye_shot = love.graphics.newImage("sprites/gorgoneye-projectile.png")
    -- print("Loaded gorgoneye shot:", Assets.images.gorgoneye_shot)

    Assets.images.firecrystal = love.graphics.newImage("sprites/crystal.png")
    Assets.images.soulsplode = love.graphics.newImage("sprites/soulsplode.png")
    Assets.images.slime_black = love.graphics.newImage("sprites/slime_black.png")
    Assets.images.gorgoneye = love.graphics.newImage("sprites/gorgoneye-tileset.png")
    -- load image/sound/fonts here
end

function Assets.getImageName(image)
    for name, img in pairs(Assets.images) do
        if img == image then
            return name
        end
    end
    return "fireball" -- if not matching, return fireball by default
end

return Assets
