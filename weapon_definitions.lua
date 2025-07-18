local weaponDefinitions = {
    FireCrystal = {
        name = "Fire Crystal",
        imagePath = "sprites/crystal.png",
        group = "Crystal",
        element = "Fire",
        baseSpeed = 200,
        baseFireRate = 2.0,
        baseDamage = 10,
        knockback = 0,
        projectileClass = Projectile,
        levelUpStats = {
            speedPerLevel = 0.03,
            damagePerLevel = 2,
            fireRateIncreasePerLevel = 0.05
        },
        upgradePaths = {
            { key = "InfernoCrystal", requiredLevel = 5 },
            { key = "DiamondCrystal", requiredLevel = 5 },
        },
        description = "A basic fire crystal weapon."
    },
    infernoCrystal = {
        name = "Inferno Crystal",
        group = "Crystal",
        knockback = 120
    }
}

return weaponDefinitions