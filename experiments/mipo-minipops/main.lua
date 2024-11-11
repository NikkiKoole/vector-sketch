inspect = require 'inspect'
Timer = require "hump.timer"
local SceneryInit = require("scenery")

font = love.graphics.newFont('assets/fonts/COOPBL.TTF', 48)
love.graphics.setFont(font)

scenes = {
    { path = "games.overworld",             key = "overworld", },
    { default = true,                       path = "games.thief-vs-police.entry", key = "thief-vs-police",             img = 'assets/thief-vs-police.png' },
    { path = "games.thief-vs-police.intro", key = "thief-vs-police-intro" },
    { path = "games.test1.entry",           key = "test1",                        img = 'assets/trains-tycoon.png',    draft = true },
    { path = "games.test1.settings",        key = "test1-settings" },
    { path = "games.test2.entry",           key = "test2",                        img = 'assets/city-build.png',       draft = true },
    { path = "games.test1.entry",           key = "test3",                        img = 'assets/villagers-people.png', draft = true },
    { path = "games.test2.entry",           key = "test4",                        img = 'assets/coaster-ride.png',     draft = true },
    { path = "games.test1.entry",           key = "test5",                        img = 'assets/slide-game.png',       draft = true },
    { path = "games.test2.entry",           key = "test6",                        img = 'assets/escape-ground.png',    draft = true },

}

local scenery = SceneryInit(
    unpack(scenes)
)

scenery:hook(love)
