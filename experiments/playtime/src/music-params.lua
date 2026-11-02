-- music-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's music
-- section (src/ui/world-settings.lua). The target is the src/music.lua module
-- itself: its switches are plain fields, read at the next bar or song.
local lib = {}

local function music() return require('src.music') end
local function synth() return require('src.synth') end

local function field(key, label, kind, options, advanced, stepper)
    return { key = label, kind = kind, options = options, advanced = advanced, stepper = stepper,
        get = function(m) return m[key] end,
        set = function(m, v) m[key] = v end }
end

-- A part's instrument: 'style' (the style's own) or one of the tonal patches. The tune's voice works in
-- every style that has a tune; keys and bass in the score styles (src/music-parts.lua bookScoreBar).
local VOICES = { 'style', 'piano', 'pianoLead', 'feltKeys', 'rhodes', 'rhodesLead', 'lofiKeys', 'clav',
    'vibes', 'marimba', 'kalimba', 'steelpan', 'tongueDrum', 'guitar', 'jabGuitar', 'jingleGuitar', 'cityGuitar',
    'pickBass', 'bass', 'musicBass', 'roundBass', 'dubBass', 'jingleBass', 'strings', 'junoPad', 'stab', 'horn',
    'citySynth', 'flute', 'jingleLead', 'violin', 'viola', 'cello', 'clarinet' }
local function voiceRow(key, label)
    return { key = label, kind = 'choice', stepper = true, options = VOICES,
        get = function(m) return m[key] or 'style' end,
        set = function(m, v) m[key] = v ~= 'style' and v or nil end }
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
    { key = 'tune', kind = 'choice', options = { 'classic', 'guide' }, -- src/music-guide.lua
        get = function(m) return m.tune or 'guide' end,
        set = function(m, v) m.tune = v end },
    field('style', 'style', 'choice',
          { 'set', 'bossa', 'guaraldi', 'island', 'dusk', 'dumont', 'supermarket', 'herbs', 'lofi', 'puppetmaker',
            'strum', 'rollo', 'jingle', 'vibesnight', 'sesame', 'citypop', 'buymode', 'satie', 'ambient',
            'bethena', 'gnossienne', 'gymnopedie', 'bachprelude', 'traumerei', 'carrelage', 'tapisserie',
            'ballad' }, nil, true),
    field('rhythmSection', 'band', 'choice', { 'auto', 'on', 'off' }),
    voiceRow('melodyPatch', 'lead'),
    voiceRow('keysPatch', 'keys'),
    voiceRow('bassPatch', 'bass'),
    -- the play level (music.bump) as a bar up to twice where the band joins, '|' marks the join
    { key = 'play', kind = 'note',
        label = function()
            local level, withBand = music().playLevel()
            local joins, width = music().bandJoins, 20
            local filled = math.min(width, math.floor(level / (2 * joins) * width + 0.5))
            local bar = ('#'):rep(filled) .. ('.'):rep(width - filled)
            bar = bar:sub(1, width / 2) .. '|' .. bar:sub(width / 2 + 1)
            return ('play %s %.1f%s'):format(bar, level, withBand and '  band in' or '')
        end },
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
-- The read-outs that grow and shrink with the style (the playing parts, then their pedals) go under
-- all the controls, so the buttons stay put while you step through the styles. Moving rows around
-- needs a restart: a hot swap merges the new rows into the old tables and an old row's `visible`
-- stays on whatever row lands in its place (2026-11-02: the whole panel hid behind 'off').
for i = 1, #music().parts do
    lib.rows[#lib.rows + 1] = { key = 'playing' .. i, kind = 'note',
        label = function() return playingLine(i) or '' end,
        visible = function() return playingLine(i) ~= nil end }
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
for i = 1, MAX_PEDAL_LINES do
    lib.rows[#lib.rows + 1] = { key = 'pedals' .. i, kind = 'note',
        label = function() return pedalLines()[i] or '' end,
        visible = function() return pedalLines()[i] ~= nil end }
end
local effectsAt = 1
for i, row in ipairs(lib.rows) do if row.key == 'volume' then effectsAt = i + 1 end end
-- the effects slider: every pedal's amount, 0 dry, 1 as designed, 2 extreme
table.insert(lib.rows, effectsAt, { key = 'effects', kind = 'number', min = 0, max = 2,
    get = function() return synth().effectAmount() end,
    set = function(_, v) synth().setEffectAmount(v) end })

function lib.target() return music() end

return lib
