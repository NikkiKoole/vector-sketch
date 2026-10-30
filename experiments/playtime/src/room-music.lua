-- room-music.lua
-- Each room (scene) can name its music, the way LucasArts' iMUSE did: walk into the room and the
-- music turns into that room's style on a musical boundary, not with a hard cut. Saved with the
-- scene (data.music), like the camera settings; set in settings → room music
-- (src/room-music-params.lua). 'keep' (the default) leaves whatever is playing.
-- The turn itself is src/music.lua's: music.cue(style, { at = 'phrase' | 'bar' }) waits for the
-- phrase end and plays a bridge bar. Until cue exists, setting music.style cuts over at the next bar.

local state = require('src.state')

local lib = {}

lib.defaults = {
    style = 'keep', -- 'keep', 'set' or a music style name
    at = 'phrase',  -- 'phrase': turn at the end of the phrase; 'bar': at the next bar line
}

-- A scene's saved setting (nil: the defaults), then cue it.
function lib.load(saved)
    local s = {}
    for k, v in pairs(lib.defaults) do s[k] = v end
    for k, v in pairs(saved or {}) do s[k] = v end
    state.roomMusic = s
    lib.cue()
    return s
end

function lib.settings()
    if not state.roomMusic then
        state.roomMusic = {}
        for k, v in pairs(lib.defaults) do state.roomMusic[k] = v end
    end
    return state.roomMusic
end

-- What goes in the scene file: nil when the room keeps whatever plays.
function lib.save()
    local s = lib.settings()
    if s.style == 'keep' then return nil end
    return { style = s.style, at = s.at }
end

-- Turn the music into this room's style.
function lib.cue()
    local s = lib.settings()
    if s.style == 'keep' then return end
    local music = require('src.music')
    if music.cue then
        music.cue(s.style, { at = s.at })
    elseif music.style ~= s.style then
        music.style = s.style
    end
end

return lib
