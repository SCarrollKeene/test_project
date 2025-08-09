local M = {} -- M == Module, Lua convention for modules apparently

-- current run data and persistent game data
-- upgrades, modifiers, enemy stats, dropped items in rooms
M.runData = {
  currentRoom = 1,
  cleared = false,
  clearedRooms = {},
  playerHealth = 100,
  inventory = {},
  equippedSlot = 1,
  playerLevel = 1,
  playerExperience = 0,
  playerBaseDamage = 1,
  playerSpeed = 300,
}

-- high scores, best runs, achievements and milestones
M.metaData = {
  unlockedCharacters = {},
  permanentUpgrades = {},
  highScore = 0,
  shards = 0,
}

return M
