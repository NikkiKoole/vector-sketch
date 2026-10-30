-- room-music.lua
-- Each room (scene) can name its music, the way LucasArts' iMUSE did: walk into the room and the
-- music turns into that room's style on a musical boundary, not with a hard cut. Saved with the
-- scene (data.music), like the camera settings; set in settings → room music
-- (src/room-music-params.lua). 'keep' (the default) leaves whatever is playing.
-- A room can also name its layers, an arrangement of the same song ('cellar': bass and keys,
-- 'full': everyone). That's iMUSE's Woodtick trick: one tune, re-arranged per place. With style
-- 'keep' and a layers preset, the song plays on and only the arrangement changes.
-- The turn itself is src/music.lua's: music.cue(style, { at, layers }) and music.layers(preset).
-- Whatever music doesn't have yet is skipped (no cue: setting music.style cuts over at the next bar).

local state = require('src.state')
local music = require('src.music')

local lib = {}

lib.defaults = {
    style = 'keep',  -- 'keep', 'set' or a music style name
    at = 'bar',      -- 'bar': the handoff starts at the next bar line; 'phrase': at the phrase end
    layers = 'keep', -- 'keep' or one of music.layerPresets
}

local function fresh(saved)
    local s = {}
    for k, v in pairs(lib.defaults) do s[k] = v end
    for k, v in pairs(saved or {}) do s[k] = v end
    return s
end

-- A scene's saved setting (nil: the defaults), then cue it. A new room starts outside any
-- music zone (src/music-zones.lua).
function lib.load(saved)
    state.roomMusic = fresh(saved)
    state.musicZones = nil
    lib.cue()
    return state.roomMusic
end

function lib.settings()
    state.roomMusic = state.roomMusic or fresh(nil)
    return state.roomMusic
end

-- What goes in the scene file: nil when the room keeps whatever plays.
function lib.save()
    local s = lib.settings()
    if s.style == 'keep' and s.layers == 'keep' then return nil end
    return { style = s.style, at = s.at, layers = s.layers }
end

-- Turn the music into this room's style and arrangement.
function lib.cue()
    lib.apply(lib.settings())
end

-- Turn the music into s = { style, layers, at } ('keep' leaves that part as it is); music zones
-- (src/music-zones.lua) send theirs through here too.
function lib.apply(s)
    local layers = s.layers ~= 'keep' and s.layers or nil
    if s.style ~= 'keep' then
        if music.cue then
            music.cue(s.style, { at = s.at, layers = layers })
            return
        elseif music.style ~= s.style then
            music.style = s.style
        end
    end
    if layers and music.layers then music.layers(layers, { at = s.at }) end
end

return lib
