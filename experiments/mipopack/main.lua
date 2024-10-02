inspect = require 'inspect'
local SceneryInit = require("scenery")

scenes = {
    { path = "games.overworld",      key = "overworld",     default = "true" },
    { path = "games.test1.entry",    key = "test1",         img = 'assets/cover1.png' },
    { path = "games.test1.settings", key = "test1-settings" },
    { path = "games.test2.entry",    key = "test2",         img = 'assets/cover2.png' }
}

local scenery = SceneryInit(
    unpack(scenes)
)

scenery:hook(love)
