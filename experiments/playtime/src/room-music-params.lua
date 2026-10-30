-- room-music-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's room music
-- section (src/ui/world-settings.lua). The target is the scene's room music
-- (src/room-music.lua, state.roomMusic), saved with the scene.
local lib = {}

local roomMusic = require('src.room-music')

-- the music section's style choices (src/music-params.lua), with 'keep' in front
local function styles()
    for _, row in ipairs(require('src.music-params').rows) do
        if row.key == 'style' then
            local out = { 'keep' }
            for _, name in ipairs(row.options) do out[#out + 1] = name end
            return out
        end
    end
    return { 'keep', 'set' }
end

-- music's arrangement presets ('cellar', 'full', ...), with 'keep' in front; only 'keep' until
-- src/music.lua has them
local function layerPresets()
    local out = { 'keep' }
    for _, name in ipairs(require('src.music').layerPresets or {}) do out[#out + 1] = name end
    return out
end

local function field(key, label, kind, options)
    return { key = label, kind = kind, options = options,
        get = function(s) return s[key] end,
        set = function(s, v)
            s[key] = v
            roomMusic.cue() -- hear it at once
        end }
end

lib.rows = {
    { key = 'about', kind = 'note', label = 'entering this room plays:' },
    field('style', 'style', 'choice', styles()),
    field('layers', 'layers', 'choice', layerPresets()),
    field('at', 'turn at', 'choice', { 'bar', 'phrase' }),
}

-- the choices follow music's styles and presets (they grow with a hot reload)
function lib.target()
    lib.rows[2].options, lib.rows[3].options = styles(), layerPresets()
    return roomMusic.settings()
end

return lib
