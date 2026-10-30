-- sound.lua
-- Ticks the synth and what plays on it every frame: the music (src/music.lua), snap clicks
-- (src/snap-sound.lua), what the pointer does as play (src/play-level.lua) and the music zones
-- (src/music-zones.lua, around the camera centre). Called
-- from main.lua, paused or not, so the music keeps going in the editor and with impact sounds off
-- (BUG7: it used to hang off mipoVoice.update). The Mipo voice keeps its own mouth flaps and impact cooldowns.

local camera = require('src.camera')
local music = require('src.music')
local musicZones = require('src.music-zones')
local playLevel = require('src.play-level')
local snapSound = require('src.snap-sound')
local state = require('src.state')

local lib = {}

local function now()
    return love.timer.getTime()
end

-- Required lazily: src/synth.lua needs LuaJIT's ffi, which the pure busted specs don't have.
local function getSynth()
    local synth = require('src.synth')
    return synth.start() and synth or nil
end

-- paused: the world isn't stepping, so nothing snaps; the music plays on.
function lib.update(dt, paused)
    local synth = getSynth()
    if not synth then return end
    local cam = camera.getInstance()
    synth.update(dt, cam)
    if not paused then
        snapSound.update(synth)
        playLevel.update(dt)
    end
    local cx, cy = cam:getTranslation()
    musicZones.update(dt, state.physicsWorld, cx, cy)
    music.update(synth, now())
end

return lib
