-- enemytypes type-keyed dictionary / table
return {
    blob = {
        { 
            name = "Black Blob", 
            spritePath = "sprites/slime_black.png", 
            width = 32, 
            height = 32,
            maxHealth = 60, 
            health = 60, 
            speed = 50, 
            baseDamage = 5, 
            xpAmount = 10, 
            enemyType = "blob",
            poolName = "blob"
        },
        { 
            name = "Blue Blob", 
            spritePath = "sprites/slime_blue.png",
            width = 32, 
            height = 32, 
            maxHealth = 120, 
            health = 120, 
            speed = 70, 
            baseDamage = 10, 
            xpAmount = 15, 
            enemyType = "blob",
            poolName = "blob" 
        },
        { 
            name = "Violet Blob", 
            spritePath = "sprites/slime_violet.png",
            width = 32, 
            height = 32, 
            maxHealth = 180, 
            health = 180, 
            speed = 90, 
            baseDamage = 15, 
            xpAmount = 25, 
            enemyType = "blob",
            poolName = "blob" 
        }
    },
    gorgoneye = {
        { 
            name = "Gorgoneye", 
            spritePath = "sprites/gorgoneye-tileset.png",
            width = 36, 
            height = 36, 
            maxHealth = 80, 
            health = 80, 
            speed = 30, 
            baseDamage = 20, 
            xpAmount = 30, 
            enemyType = "gorgoneye",
            poolName = "gorgoneye" 
        }
    }
}