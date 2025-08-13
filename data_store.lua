local Data_Store = {} -- M == Module, Lua convention for modules apparently

-- current run data and persistent game data
-- upgrades, modifiers, enemy stats, dropped items in rooms
Data_Store.runData = {
  score = 0,
  currentRoom = 1,
  cleared = false,
  clearedRooms = {},
  playerHealth = 100,
  playerMaxHealth = 100,
  inventory = {},
  equippedSlot = 1,
  playerLevel = 1,
  playerExperience = 0,
  playerBaseDamage = 1,
  playerSpeed = 300,
}

-- high scores, best runs, achievements and milestones
Data_Store.metaData = {
  unlockedCharacters = {},
  permanentUpgrades = {},
  highScore = 0,
  shards = 0,
}

return Data_Store
