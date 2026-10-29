-- palettes.lua — the sky as colour stops over altitude, one set per time of day.
-- Every palette shares the same altitude positions (`lib.positions`), so two
-- palettes blend stop by stop. Press 'r' in the app to reload this file.
--
-- Altitude is in world units above the ground (y = 0); `lib.space` is where the
-- sky has turned black. Colours come from lib/gradient.lua's presets where they
-- fit (the day is Puppetmaker 2's #61d0cf -> #efeebc).
local lib = {}

lib.space = 60000 -- world units: from here up it's black space
lib.moonAltitude = 120000

-- 0 = the horizon, 1 = space (fractions of lib.space)
lib.positions = { 0, 0.03, 0.1, 0.22, 0.42, 0.7, 1 }

lib.palettes = {
    night = { '233072', '192861', '12195a', '0a0f3a', '060a28', '02040f', '000000' },
    dawn  = { 'ffe467', 'fda65a', 'f06b7e', '7b5aa6', '2c2c74', '0a0f30', '000000' },
    day   = { 'efeebc', 'a3dec6', '61d0cf', '2f9fd0', '1c5fa8', '0b1f4a', '000000' },
    dusk  = { 'ffd364', 'f18448', 'ca5a92', '5b2c83', '28166b', '0b0b2a', '000000' },
}

-- The day as keyframes: { hour, palette }. Between two keyframes the palettes blend.
lib.timeline = {
    { 0, 'night' }, { 5, 'night' }, { 6.5, 'dawn' }, { 8.5, 'day' },
    { 17, 'day' }, { 19, 'dusk' }, { 20.5, 'night' }, { 24, 'night' },
}

-- How much of the night shows at an hour (stars, moon): 0 by day, 1 at night.
lib.nightness = {
    { 0, 1 }, { 5, 1 }, { 7, 0 }, { 18.5, 0 }, { 20.5, 1 }, { 24, 1 },
}

return lib
