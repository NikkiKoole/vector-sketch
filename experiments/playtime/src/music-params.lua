-- music-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's music
-- section (src/ui/world-settings.lua). The target is the src/music.lua module
-- itself: its switches are plain fields, read at the next bar or song.
local lib = {}

local function music() return require('src.music') end
local function state() return require('src.state') end
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
    'citySynth', 'flute', 'jingleLead', 'tb303', 'violin', 'viola', 'cello', 'clarinet' }
-- One row per part the playing style uses (src/music-parts.lua's play remembers them, also while a
-- part is off): [x] on/off, the part's name with a dot while it sounds, and for the tonal parts
-- '< instrument >' ('(rhodes)' = the style's own); drums, perc and vinyl get a row per sound under them.
local function styleParts() -- the playing style's parts; with the music off, the picked style's
    local now = music().nowPlaying()
    local seen = state().music.styleParts or {}
    return seen[now and now.style or music().style]
end
-- the playing style's ideas (style.ideas), and every idea any style has, in the panel's order
local IDEAS = { 'dynamics', 'range', 'approach', 'borrow', 'rhythms', 'revoice', 'figures', 'colour', 'walks', 'flat9',
                'answer', 'runup', 'flutefeel', 'picks' }
local function styleIdeas()
    local now = music().nowPlaying()
    local style = music().styles[now and now.style or music().style]
    return style and require('src.music-styles').ideasOf(style) or {}
end
local function ideaRow(name)
    return { key = name, kind = 'choice', options = { 'never', 'less', 'some songs', 'always', 'lots' }, stepper = true,
        visible = function() return styleIdeas()[name] ~= nil end,
        -- nil is never (the music as before the ideas); 'some songs' is stored as 'some'
        get = function(m)
            local v = m.ideas and m.ideas[name]
            return v == 'some' and 'some songs' or v or 'never'
        end,
        set = function(m, v)
            local ideas = m.ideas or {}
            ideas[name] = v == 'some songs' and 'some' or v ~= 'never' and v or nil
            m.ideas = ideas
        end }
end
local function heard(part)
    for _, entry in ipairs(music().playing()) do
        if entry.part == part then return entry end
    end
end
local function partRow(part)
    local tonal = require('src.music-parts').TONAL[part]
    return { key = part, kind = 'part', stepper = true, options = tonal and VOICES or nil,
        label = function()
            local entry = heard(part)
            local sounding = false
            for _, patch in ipairs(entry and entry.patches or {}) do sounding = sounding or patch.now end
            return part .. (sounding and ' •' or '')
        end,
        visible = function() local own = styleParts(); return own ~= nil and own[part] ~= nil end,
        on = function(m) return not (m.partsOff and m.partsOff[part]) end,
        setOn = function(m, on)
            local off = m.partsOff or {}
            off[part] = not on or nil
            m.partsOff = off
        end,
        get = function(m) return m.voices and m.voices[part] or part == 'lead' and m.melodyPatch or 'style' end,
        set = function(m, v)
            local voices = m.voices or {}
            voices[part] = v ~= 'style' and v or nil
            m.voices = voices
            if part == 'lead' then m.melodyPatch = nil end
        end,
        display = function(_, v)
            if v ~= 'style' then return v end
            local own = styleParts()
            return '(' .. tostring(own and own[part] or 'style') .. ')'
        end,
    }
end

-- Under drums, perc and vinyl, one row per sound the style plays (src/music-parts.lua's play lists
-- them): [x] on/off, '< sound >' to swap it for another ('(kick)' = the style's own).
local SOUNDS = { 'style', 'kick', 'bapKick', 'lofiKick', 'tom', 'conga', 'djembe', 'snare', 'clap', 'rim', 'wood',
    'hat', 'ride', 'brush', 'shaker', 'tamb', 'guiro', 'quijada', 'triangle', 'triangleRing', 'crackle', 'hiss' }
local MAX_SOUNDS = 8
local function soundsOf(part)
    local now = music().nowPlaying()
    local seen = state().music.styleSounds or {}
    local own = seen[now and now.style or music().style]
    local list = {}
    for name in pairs(own and own[part] or {}) do list[#list + 1] = name end
    table.sort(list)
    return list
end
local function soundRow(part, i)
    local function name() return soundsOf(part)[i] end
    return { key = part .. ' sound ' .. i, kind = 'part', stepper = true, options = SOUNDS,
        label = function(m)
            local own = name() or ''
            local playsAs = m.soundVoices and m.soundVoices[own] or own
            local sounding = false
            for _, patch in ipairs(heard(part) and heard(part).patches or {}) do
                sounding = sounding or (patch.name == playsAs and patch.now)
            end
            return '· ' .. own .. (sounding and ' •' or '')
        end,
        visible = function() return name() ~= nil end,
        on = function(m) return not (m.soundsOff and m.soundsOff[name()]) end,
        setOn = function(m, on)
            local off = m.soundsOff or {}
            off[name()] = not on or nil
            m.soundsOff = off
        end,
        get = function(m) return m.soundVoices and m.soundVoices[name()] or 'style' end,
        set = function(m, v)
            local voices = m.soundVoices or {}
            voices[name()] = v ~= 'style' and v or nil
            m.soundVoices = voices
        end,
        display = function(_, v) return v == 'style' and '(' .. tostring(name()) .. ')' or v end }
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

-- Top to bottom: what plays, the switches, the style, then its parts and the effects, which grow and
-- shrink with the style and so sit under every button that stays put. Behind '+ more': how the tune
-- is built, the play level. Moving rows around needs a restart: a hot swap merges the
-- new rows into the old tables, and an old row's `visible` stays on whatever row lands in its place
-- (2026-11-02: the whole panel hid behind 'off').
-- The drum jam's picks (src/music-jam.lua, docs/DRUM-JAM.md): the bass's walk, its figure, how the
-- chords are played, how often the root moves. 'auto' = what the song rolled. Live (the walk from its
-- next change), shown only while the jam plays, kept in state.musicSettings.jam (a setup saves it:
-- src/music-setups.lua's CHOICES).
local function jamRow(key, label, options)
    return { key = label, kind = 'choice', options = options, stepper = true,
        visible = function()
            local now = music().nowPlaying()
            return (now and now.style or music().style) == 'jam'
        end,
        get = function() return (state().musicSettings.jam or {})[key] or 'auto' end,
        set = function(_, v)
            local s = state().musicSettings
            s.jam = s.jam or {}
            s.jam[key] = v
        end }
end
local jam = require('src.music-jam')
-- a world setting picked from one of music-stingers' option lists
local function worldRow(key, label, options, default)
    return { key = label, kind = 'choice', options = require('src.music-stingers')[options], stepper = true,
        get = function() return (state().musicSettings.world or {})[key] or default end,
        set = function(_, v)
            local s = state().musicSettings
            s.world = s.world or {}
            s.world[key] = v
        end }
end
local function bandRow(kind, label)
    return { key = label, kind = 'choice', options = { 'band', 'own' }, stepper = true,
        get = function()
            local w = state().musicSettings.world
            return w and w.band and w.band[kind] or require('src.music-events').BAND_DEFAULTS[kind]
        end,
        set = function(_, v)
            local s = state().musicSettings
            s.world = s.world or {}
            s.world.band = s.world.band or {}
            s.world.band[kind] = v
        end }
end

lib.rows = {
    { key = 'now', kind = 'note',
        label = function()
            local now = music().nowPlaying()
            if not music().enabled then return 'off' end
            if not now then return 'starts soon' end
            return now.style .. ' · ' .. tostring(now.section or '') .. ' · bar ' .. now.bar .. '/' .. now.bars
        end },
    field('enabled', 'music', 'bool'),
    -- all sound, not just the music: it scales every synth patch. Read from state
    -- (where setVolume keeps it): after a hot reload synth's module table is a copy.
    { key = 'volume', kind = 'number', min = 0, max = 1,
        get = function()
            local fallback = synth().volume -- loading synth also sets up state.synth
            return require('src.state').synth.volume or fallback
        end,
        set = function(_, v) synth().setVolume(v) end },
    field('style', 'style', 'choice',
          { 'set', 'bossa', 'guaraldi', 'island', 'dusk', 'dumont', 'supermarket', 'herbs', 'lofi', 'puppetmaker',
            'strum', 'rollo', 'jingle', 'vibesnight', 'wave', 'sesame', 'citypop', 'buymode', 'satie', 'ambient',
            'bethena', 'gnossienne', 'gymnopedie', 'bachprelude', 'traumerei', 'carrelage', 'tapisserie', 'gershwin2',
            'ballad', 'acid', 'jam' }, nil, true),
    field('rhythmSection', 'band', 'choice', { 'auto', 'on', 'off' }),
    jamRow('walk', 'jam walk', jam.walkNames()),
    jamRow('figure', 'jam bass', jam.figureNames()),
    jamRow('chords', 'jam chords', jam.chordNames()),
    jamRow('pace', 'jam pace', jam.PACES),
    jamRow('layers', 'jam layers', jam.LAYER_PICKS),
    jamRow('lean', 'jam lean-in', jam.MOVE_PICKS),
    jamRow('gap', 'jam gap', jam.MOVE_PICKS),
    jamRow('spot', 'jam spotlight', jam.SPOT_PICKS),
    jamRow('variations', 'jam variations', jam.MOVE_PICKS),
    -- MW7 (src/music-events.lua): an impact sound borrows the band's instrument ('band') or keeps its own
    -- ('own'): the ball the song's bass, boxes its hand drums and toms, Mipo bumps its keys
    bandRow('ball', 'ball sounds'), bandRow('box', 'box sounds'), bandRow('plonk', 'Mipo bump sounds'),
    -- stingers (src/music-stingers.lua, docs/STINGERS.md): a short phrase on the next beat for a moment
    worldRow('stingerSize', 'stingers', 'SIZES', 'off'), worldRow('stingerVoice', 'stinger voice', 'VOICES', 'band'),
    worldRow('stingerRest', 'part rests', 'RESTS', 'yes'),
    worldRow('stingerMoments', 'stinger moments', 'MOMENT_PICKS', 'button'),
    { key = 'try stinger', kind = 'action',
        run = function() music().event('stinger') end },
    -- the world's moments so far (music.event; docs/STINGERS.md): how often each happens while playing
    { key = 'events', kind = 'note',
        label = function()
            local log, names = (state().music or {}).eventLog or {}, {}
            for name in pairs(log) do names[#names + 1] = name end
            table.sort(names, function(a, b) return log[a].count > log[b].count end)
            for i, name in ipairs(names) do names[i] = name .. ' ' .. log[name].count end
            return 'events: ' .. (#names > 0 and table.concat(names, ' ') or 'none yet')
        end },
    { key = 'jam impacts', kind = 'choice', options = require('src.music-events').IMPACT_PICKS, stepper = true,
        visible = function()
            local now = music().nowPlaying()
            return (now and now.style or music().style) == 'jam'
        end,
        get = function() return (state().musicSettings.world or {}).impact or 'crash and fill' end,
        set = function(_, v)
            local s = state().musicSettings
            s.world = s.world or {}
            s.world.impact = v
        end },
    -- the style's ideas (docs/MUSIC-CONCEPTS.md: the walks, the answer): spice scales them all, 0 plain
    -- to 2, 1 as designed; a row per idea the playing style has, from none to lots: never, less (half as
    -- often), some songs (the style's share, as designed), always (every song), lots (every song, twice
    -- as often); and which ones this song uses
    { key = 'spice', kind = 'number', min = 0, max = 2,
        visible = function() return next(styleIdeas()) ~= nil end,
        get = function(m) return m.spice or 1 end,
        set = function(m, v) m.spice = v end },
    { key = 'song ideas', kind = 'note',
        visible = function() return next(styleIdeas()) ~= nil end,
        label = function()
            local song, used = state().music.song, {}
            for _, name in ipairs(IDEAS) do -- the ideas sounding now (their odds this bar), not just rolled
                if song and song.ideaOdds and (song.ideaOdds[name] or 0) > 0 then used[#used + 1] = name end
            end
            return 'this song: ' .. (#used > 0 and table.concat(used, ', ') or 'as before the ideas')
        end },
    -- the arrangements rooms use (music.layerPresets): a click sets the part checkboxes to one
    { key = 'layers', kind = 'buttons', wide = true, options = { 'full', 'quiet', 'cellar', 'rhythm' },
        run = function(_, m, preset) m.partsOff = music().layerParts(preset) end },
    -- setups (src/music-setups.lua): save what plays now; forget: the next setup clicked goes; reset:
    -- back to the style's own instruments and parts; undo: the last reset or setup put back
    { key = 'setups', kind = 'buttons', wide = true, options = { 'save', 'forget', 'reset', 'undo' },
        run = function(_, _, option)
            local setups = require('src.music-setups')
            if option == 'save' then setups.save()
            elseif option == 'forget' then state().musicForgetting = not state().musicForgetting
            elseif option == 'reset' then setups.reset()
            else setups.undo() end
        end },
}
-- the idea rows, right under spice and the song's ideas
do
    local at
    for i, row in ipairs(lib.rows) do if row.key == 'song ideas' then at = i end end
    for k, name in ipairs(IDEAS) do table.insert(lib.rows, at + k, ideaRow(name)) end
end
-- the saved setups, two buttons a row (consecutive actions sit side by side): click = put it back
local MAX_SETUPS = 16
for i = 1, MAX_SETUPS do
    lib.rows[#lib.rows + 1] = { key = 'setup' .. i, kind = 'action',
        label = function()
            local setup = require('src.music-setups').list()[i]
            return (state().musicForgetting and 'x ' or '') .. (setup and setup.name or '')
        end,
        visible = function() return require('src.music-setups').list()[i] ~= nil end,
        run = function()
            local setups = require('src.music-setups')
            local setup = setups.list()[i]
            if not setup then return end
            if state().musicForgetting then
                setups.remove(setup.name)
                state().musicForgetting = false
            else
                setups.apply(setup)
            end
        end }
end
for _, part in ipairs(music().parts) do
    lib.rows[#lib.rows + 1] = partRow(part)
    if not require('src.music-parts').TONAL[part] and part ~= 'sample' then
        for i = 1, MAX_SOUNDS do lib.rows[#lib.rows + 1] = soundRow(part, i) end
    end
end
-- the effects slider: every pedal's amount, 0 dry, 1 as designed, 2 extreme; the pedals under it
lib.rows[#lib.rows + 1] = { key = 'effects', kind = 'number', min = 0, max = 2,
    get = function() return synth().effectAmount() end,
    set = function(_, v) synth().setEffectAmount(v) end }
for i = 1, MAX_PEDAL_LINES do
    lib.rows[#lib.rows + 1] = { key = 'pedals' .. i, kind = 'note',
        label = function() return pedalLines()[i] or '' end,
        visible = function() return pedalLines()[i] ~= nil end }
end
for _, row in ipairs({
    { key = 'tune', kind = 'choice', options = { 'classic', 'guide' }, advanced = true, -- src/music-guide.lua
        get = function(m) return m.tune or 'guide' end,
        set = function(m, v) m.tune = v end },
    -- the play level (music.bump) as a bar up to twice where the band joins, '|' marks the join
    { key = 'play', kind = 'note', advanced = true,
        label = function()
            local level, withBand = music().playLevel()
            local joins, width = music().bandJoins, 20
            local filled = math.min(width, math.floor(level / (2 * joins) * width + 0.5))
            local bar = ('#'):rep(filled) .. ('.'):rep(width - filled)
            bar = bar:sub(1, width / 2) .. '|' .. bar:sub(width / 2 + 1)
            return ('play %s %.1f%s'):format(bar, level, withBand and '  band in' or '')
        end },
}) do lib.rows[#lib.rows + 1] = row end

function lib.target() return music() end

return lib
