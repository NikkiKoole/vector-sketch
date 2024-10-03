inspect = require 'inspect'
local SceneryInit = require("scenery")

scenes = {
    { path = "games.overworld",      key = "overworld",     default = "true" },
    { path = "games.test1.entry",    key = "test1",         img = 'assets/cover1.png' },
    { path = "games.test1.settings", key = "test1-settings" },
    { path = "games.test2.entry",    key = "test2",         img = 'assets/cover2.png' },
    { path = "games.test1.entry",    key = "test3",         img = 'assets/cover3.png' },
    { path = "games.test2.entry",    key = "test4",         img = 'assets/cover4.png' },
    { path = "games.test1.entry",    key = "test5",         img = 'assets/cover5.png' },
    { path = "games.test2.entry",    key = "test6",         img = 'assets/cover6.png' },
    { path = "games.test1.entry",    key = "test7",         img = 'assets/cover7.png' },
    { path = "games.test2.entry",    key = "test8",         img = 'assets/cover8.png' },

}

local scenery = SceneryInit(
    unpack(scenes)
)

scenery:hook(love)
