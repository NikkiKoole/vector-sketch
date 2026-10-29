-- music-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's music
-- section (src/ui/world-settings.lua). The target is the src/music.lua module
-- itself: its switches are plain fields, read at the next bar or song.
local lib = {}

local function music() return require('src.music') end
local function synth() return require('src.synth') end

local function field(key, label, kind, options, advanced)
    return { key = label, kind = kind, options = options, advanced = advanced,
        get = function(m) return m[key] end,
        set = function(m, v) m[key] = v end }
end

lib.rows = {
    { key = 'now', kind = 'note',
        label = function()
            local now = music().nowPlaying()
            if not music().enabled then return 'off' end
            if not now then return 'starts soon' end
            return now.style .. ' · ' .. tostring(now.section or '') .. ' · bar ' .. now.bar .. '/' .. now.bars
        end },
    -- all sound, not just the music: it scales every synth patch. Read from state
    -- (where setVolume keeps it): after a hot reload synth's module table is a copy.
    { key = 'volume', kind = 'number', min = 0, max = 1,
        get = function()
            local fallback = synth().volume -- loading synth also sets up state.synth
            return require('src.state').synth.volume or fallback
        end,
        set = function(_, v) synth().setVolume(v) end },
    field('enabled', 'music', 'bool'),
    field('melody', 'melody', 'bool'),
    field('style', 'style', 'choice',
          { 'set', 'bossa', 'guaraldi', 'island', 'dumont', 'supermarket', 'herbs', 'lofi', 'ballad' }),
    field('rhythmSection', 'band', 'choice', { 'auto', 'on', 'off' }),
    field('upright', 'upright', 'bool', nil, true),
}

function lib.target() return music() end

return lib
