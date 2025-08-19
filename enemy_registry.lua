local Blob = require("blob")
local Gorgoneye = require("gorgoneye")

return {
    ["Black Blob"] = Blob,         -- All use base Enemy logic (can override per-name)
    ["Blue Blob"] = Blob,
    ["Violet Blob"] = Blob,
    ["Gorgoneye"] = Gorgoneye,
    ["default"] = Blob
}