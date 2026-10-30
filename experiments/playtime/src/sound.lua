-- sound.lua
-- Ticks the synth and what plays on it every frame: the music (src/music.lua), snap clicks
-- (src/snap-sound.lua) and slide sounds (src/slide-sound.lua). Called from main.lua, paused or not,
-- so the music keeps going in the editor and with impact sounds off (BUG7: it used to hang off
-- mipoVoice.update). The Mipo voice keeps its own mouth flaps and impact cooldowns.

local lib = {}

local function now()
    return love.timer.getTime()
end

-- Required lazily: src/synth.lua needs LuaJIT's ffi, which the pure busted specs don't have.
local function getSynth()
    local synth = require('src.synth')
    return synth.start() and synth or nil
end

-- paused: the world isn't stepping, so nothing slides or snaps; the music plays on.
function lib.update(dt, paused)
    local synth = getSynth()
    if not synth then return end
    synth.update(dt, require('src.camera').getInstance())
    if not paused then
        require('src.slide-sound').update(synth, now())
        require('src.snap-sound').update(synth)
    end
    require('src.music').update(synth, now())
end

return lib
