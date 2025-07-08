local weaponDefinitions = {
    FireCrystal = {
        name = "Fire Crystal",
        imagePath = "sprites/crystal.png",
        group = "Crystal",
        element = "Fire",
        baseFireRate = 2.0,
        baseDamage = 10,
        projectileClass = Projectile,
        levelUpStats = {
            damagePerLevel = 2,
            fireRateIncreasePerLevel = 0.05
        },
        upgradePaths = {
            { key = "InfernoCrystal", requiredLevel = 5 },
            { key = "DiamondCrystal", requiredLevel = 5 },
        },
        description = "A basic fire crystal weapon."
    }
}

return weaponDefinitions