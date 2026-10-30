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
          { 'set', 'bossa', 'guaraldi', 'island', 'dumont', 'supermarket', 'herbs', 'lofi', 'puppetmaker',
            'strum', 'rollo', 'sesame', 'citypop', 'buymode', 'satie', 'ambient',
            'ballad' }),
    field('rhythmSection', 'band', 'choice', { 'auto', 'on', 'off' }),
    field('upright', 'upright', 'bool'),
}

-- one row per part that's playing: 'keys  [rhodes]', brackets on what sounds right now
local function playingLine(i)
    local entry = music().playing()[i]
    if not entry then return nil end
    local names = {}
    for _, patch in ipairs(entry.patches) do
        names[#names + 1] = patch.now and '[' .. patch.name .. ']' or patch.name
    end
    return entry.part .. '  ' .. table.concat(names, ' ')
end
for i = 1, #music().parts do
    table.insert(lib.rows, 1 + i, { key = 'playing' .. i, kind = 'note', -- under 'now'
        label = function() return playingLine(i) or '' end,
        visible = function() return playingLine(i) ~= nil end })
end

-- the pedals of every instrument with pedals that's playing, a row each ('guitar   drive .22', then
-- '         tape .25' ...), each the amount the effects slider turns, as it sounds now
local PEDAL_ORDER = { 'drive', 'tape', 'chorus', 'flanger', 'phaser', 'autopan' }
local function pedalLines()
    local lines, seen = {}, {}
    for _, entry in ipairs(music().playing()) do
        for _, patch in ipairs(entry.patches) do
            local pedals = not seen[patch.name] and synth().pedalsOf(patch.name)
            seen[patch.name] = true
            if pedals then
                local first = true
                for _, kind in ipairs(PEDAL_ORDER) do
                    if pedals[kind] then
                        local amount = ('%.2f'):format(pedals[kind]):gsub('^0%.', '.')
                        lines[#lines + 1] = ('%-11s %s %s'):format(first and patch.name or '', kind, amount)
                        first = false
                    end
                end
            end
        end
    end
    return lines
end
local MAX_PEDAL_LINES = 12
local effectsAt = 1
for i, row in ipairs(lib.rows) do if row.key == 'volume' then effectsAt = i + 1 end end
for i = MAX_PEDAL_LINES, 1, -1 do
    table.insert(lib.rows, effectsAt, { key = 'pedals' .. i, kind = 'note',
        label = function() return pedalLines()[i] or '' end,
        visible = function() return pedalLines()[i] ~= nil end })
end
-- the effects slider: every pedal's amount, 0 dry, 1 as designed, 2 extreme
table.insert(lib.rows, effectsAt, { key = 'effects', kind = 'number', min = 0, max = 2,
    get = function() return synth().effectAmount() end,
    set = function(_, v) synth().setEffectAmount(v) end })

function lib.target() return music() end

return lib
