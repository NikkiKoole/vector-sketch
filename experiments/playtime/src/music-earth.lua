-- music-earth.lua
-- earth: MF Grimm's "Earth" (the instrumental) as measured (docs/MUSIC-ANALYSIS.md Song 5, 2026-11-12): one
-- 4-bar loop, the same every pass, ~91 BPM, straight 8ths with the 16th 'a' dragged late; C minor, the record
-- (a sample, sped up: everything ~30 cents sharp) played in tune here. Three parts, each folded over 16 passes:
--   bass   a pulse of short C3 16ths (1 1e 1& 1a 2), then Eb3 held from 3 (C sus2 -> Eb7), three bars; the 4th
--          bar A2 then D2 (A7#9 -> Dm7) and round
--   keys   a slow sigh on top: G4, G4+D5 on 1&, G4, then Db5 on 3& held and G4 on 4 (the top D -> Db over the
--          Eb: its 7th); the 4th bar C5 over A7#9 (C# G), Bb4 over A7b9 (F#), F4 (Dm7), C5 back up to the D
--   kit    boom-bap: kick 1 and 3, snare 2 and 4, 8th hats, a dragged ghost (kick, snare, hat) on the 'a' of 1
-- Made whimsical (Nikki 2026-11-12: "can we make it more whimsical"): the same notes, lighter sounds: the keys
-- a soft mallet with a slow tape wow (synth.lua earthKeys), the kit a toy one on the record's pattern (a soft
-- kick, rim and brush for the snare, shaker for the hats, a woodblock tick on the dragged ghost); and the
-- loop from the first bar, no intro without the drums ("the start shouldn't have cut this off").
-- Registered as loop = 'earth' (music-plan, music-parts), the same way as music-neige.lua. The music panel's
-- 'humanize' row plays it all on the grid.
local state = require('src.state')

local lib = {}

-- the 16th 'a' of a beat lands this far into it (bass, keys and drums: ~+45..65 ms at 91 BPM)
local DRAG = 0.83

-- the bass: { beat in the cycle, midi, length beats, short, odds }. Lengths and odds from the fold (in how
-- many of the 16 passes a note was there); the shorts are stopped, the held notes ring
local function pulse(bar)
    local o = bar * 4
    return { o, 48, 0.2, true }, { o + 0.25, 48, 0.18, true }, { o + 0.5, 48, 0.2, true },
        { o + DRAG, 48, 0.22, true }, { o + 1, 48, 0.25, true }, { o + 1.25, 48, 0.3, true, 0.6 }
end
lib.BASS = {}
for bar = 0, 2 do
    for _, n in ipairs({ pulse(bar) }) do lib.BASS[#lib.BASS + 1] = n end
end
local function add(list, entries) for _, e in ipairs(entries) do list[#list + 1] = e end end
add(lib.BASS, {
    { 2, 51, 0.5, false },               -- Eb3, bar 1: half a beat
    { 3, 51, 0.35, false, 0.4 },
    { 6, 51, 0.95, false },              -- bar 2: held
    { 7, 51, 0.4, false, 0.55 },
    { 10, 51, 0.9, false },              -- bar 3
    { 11, 51, 0.2, false, 0.45 },
    { 12, 45, 0.12, true },              -- A2, a short one, then held
    { 12.25, 45, 0.6, false },
    { 14.25, 38, 0.85, false },          -- D2 on the 'e' of 3 (a 16th late)
    { 15, 38, 0.35, false, 0.8 },
    { 15.5, 38, 0.3, false, 0.5 },
})
-- the keys: { beat, length beats, odds, midi... }; top line as heard over the passes (13-16 of 16)
lib.KEYS = {}
for bar = 0, 2 do
    local o = bar * 4
    add(lib.KEYS, {
        { o, 0.5, 1, 67 },               -- G4
        { o + 0.5, 1.05, 1, 67, 74 },    -- G4 + D5: the 9th on top
        { o + 1, 1.4, 0.45, 67 },
        { o + 2.5, 1.4, 1, 73 },         -- Db5 over the Eb: its 7th, the top sighing down a half step
        { o + 3, 0.95, 0.85, 67 },
    })
end
add(lib.KEYS, {
    { 12, 0.7, 1, 61, 67, 72 },          -- A7#9: C#4 G4, C5 on top
    { 13, 0.85, 0.85, 66, 70 },          -- A7b9 13: F#4 Bb4
    { 14, 1.15, 0.6, 65, 69 },           -- Dm7: F4 A4
    { 15, 0.7, 1, 72 },                  -- C5, back up to the D
})
-- the kit, one bar (the record's drums repeat within ~5 ms: a looped bar), on toy sounds. { beat, patch, midi,
-- vol, ms }; the record had bapKick for the kicks and the snare where the rim and brush are
lib.KIT = {
    { 0, 'bapKick', 36, 3, 160 }, { 1.5, 'bapKick', 36, 2, 120 }, { 2, 'bapKick', 36, 3, 160 },
    { 1, 'rim', 72, 5, 60 }, { 1, 'brush', 60, 3, 200 }, { 3, 'rim', 72, 5, 60 }, { 3, 'brush', 60, 3, 200 },
    { DRAG, 'wood', 84, 3, 120 }, { 2.5, 'rim', 72, 2, 40 }, { 3.5, 'rim', 72, 2, 40 },
}
-- the harmony a bar (for what plays along): C sus2 (Eb7 its second half), the same twice more, A7#9 (Dm7)
lib.HARMONY = { { 0, 'sus2' }, { 0, 'sus2' }, { 0, 'sus2' }, { 9, 's9' } }

lib.FORM = {
    { 'A', 40, { keys = true, bass = true, kit = true } },
    { 'end', 1, { ending = true } },
}

local function human() return state.musicSettings.humanize ~= false end
local function gauss(sd)
    return sd * math.sqrt(-2 * math.log(1 - love.math.random())) * math.cos(2 * math.pi * love.math.random())
end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        list[#list + 1] = { entry[1], entry[2], function(j) return lib.HARMONY[j % 4 + 1] end, entry[3] }
    end
    addSections(song, list)
    song.key = 0 -- the record's: C minor
end

-- the events of `list` whose beat falls in this bar of the cycle
local function inBar(list, b)
    local lo = ((b - 1) % 4) * 4
    local out = {}
    for _, e in ipairs(list) do
        if e[1] >= lo and e[1] < lo + 4 then out[#out + 1] = e end
    end
    return out, lo
end

local function bookBass(play, synth, t0, song, b, roles, h)
    local notes, lo = inBar(lib.BASS, b)
    for _, n in ipairs(notes) do
        local beat, midi, len, short, odds = n[1], n[2], n[3], n[4], n[5]
        local final = roles.ending
        if not final or beat == lo then
            local at = t0 + (beat - lo) * song.beat
            local s = math.floor((beat - lo) * 4 + 0.5)
            if final then len, short = 4, false end
            if not h then
                if not odds or odds >= 0.5 then
                    play(synth, 'bass', 'earthBass', at, midi, 6, len * song.beat * 1000, s)
                end
            elseif not odds or love.math.random() < odds then
                local opts = { gain = math.min(1, 0.8 * 10 ^ (gauss(1.2) / 20)), cents = gauss(4) }
                if short then opts.damp = 0.8 else opts.release = 120 end
                play(synth, 'bass', 'earthBass', at + gauss(0.006), midi, 6, len * song.beat * 1000, s, nil, nil, opts)
            end
        end
    end
end

local function bookKeys(play, synth, t0, song, b, h)
    local events, lo = inBar(lib.KEYS, b)
    for _, e in ipairs(events) do
        local at = t0 + (e[1] - lo) * song.beat
        local s = math.floor((e[1] - lo) * 4 + 0.5)
        local len, odds = e[2] * song.beat * 1000, e[3]
        if (h and love.math.random() < odds) or (not h and odds >= 0.5) then
            for k = 4, #e do
                if h then
                    play(synth, 'keys', 'earthKeys', at + 0.012 + gauss(0.006) + (k - 4) * 0.004, e[k], 4, len, s, nil,
                         nil, { gain = math.min(1, 0.85 * 10 ^ (gauss(1.0) / 20)), cents = gauss(3) })
                else
                    play(synth, 'keys', 'earthKeys', at, e[k], 4, len, s)
                end
            end
        end
    end
end

local function bookKit(play, synth, t0, song)
    for _, k in ipairs(lib.KIT) do
        play(synth, 'drums', k[2], t0 + k[1] * song.beat, k[3], k[4], k[5], math.floor(k[1] * 4 + 0.5))
    end
    for s = 0, 14, 2 do
        play(synth, 'drums', 'shaker', t0 + s / 4 * song.beat, 60, s % 4 == 0 and 4 or 3, 40, s)
    end
end

function lib.bookBar(play, remember, synth, t0, song, b)
    local chord = song.chords[b]
    local root = (song.key + chord[1]) % 12
    local pcs = { root }
    for _, interval in ipairs(require('src.music-styles').qualities[chord[2]]) do
        pcs[#pcs + 1] = (root + interval) % 12
    end
    remember(t0, pcs)
    local h = human()
    local roles = song.barSection[b].roles
    if roles.bass or roles.ending then bookBass(play, synth, t0, song, b, roles, h) end
    if roles.keys then bookKeys(play, synth, t0, song, b, h) end
    if roles.kit then bookKit(play, synth, t0, song) end
end

return lib
