-- music-neige.lua
-- neige: Domenique Dumont's "La bataille de neige" (Comme Ça, 2015) as measured (docs/MUSIC-ANALYSIS.md Song 4,
-- 2026-11-06): a dubby groove at 133 BPM, straight, in the record's key, over a 4-bar cycle Am | Dm | G | C (the
-- bass's G# sliding back up to A). Three parts, each from its stem folded over 20 cycles:
--   bass     a low, muted upright-ish line (A E D G, then C G G#), the long notes ringing and the short ones
--            stopped dead (they die at -90..-360 dB/s); one bent note (E sagging flat) and a scoop into the G#
--   synth    one soft analog synth (a saw through a lowpass, a quick drop to ~40% and held): skank chords on 2 and
--            4 (at half time, the off-beats) and a sparse high melody drifting down, C B ... G F E
--   box      an old rhythm box's 4-bar pattern: kicks over the beats and ands, rim on 2 and 2&, a maracas ghost on
--            the swung 'a' of 2 and of 4, claps on two loud ands, soft hats
-- The box is the clock; the bass and the synth lay back against it by their measured amounts (~+15..45 ms).
-- The music panel's 'humanize' row plays it all on the grid. Registered as loop = 'neige' (music-plan,
-- music-parts), the same way as music-brew.lua.
local state = require('src.state')

local lib = {}

-- the cycle is 16 beats; the bass and synth's timing is measured against the box (ms: + late)
-- the bass: { beat, midi, length beats, short, ms, dB, odds, cents shape }
lib.BASS = {
    { 0, 33, 0.97, false, 14, 0.6 },           -- A1, the loudest note: the one
    { 1.5, 33, 0.43, true, 45, -1.0 },
    { 2, 40, 0.36, true, 37, -0.4 },           -- E2
    { 3, 40, 0.89, false, -4, -2.3 },
    { 4, 38, 0.95, false, 11, -0.3 },          -- D2
    { 5.5, 38, 0.82, false, 16, -1.4 },
    { 6.5, 38, 0.36, true, 56, -4.0 },
    { 7, 45, 0.86, false, 12, -4.8, 0.55 },    -- A2, half the time
    { 8, 43, 0.84, false, 53, -1.6 },          -- G2
    { 9, 43, 0.12, true, -12, -7.0, 0.45 },    -- a dead ghost
    { 9.5, 43, 0.41, true, 27, -3.2 },
    { 10, 45, 0.35, true, 29, -3.1 },
    { 10.5, 43, 0.42, true, 37, -4.6 },
    { 11, 40, 0.5, true, 33, -3.8, nil, 'sag' }, -- E2 sagging toward Eb
    { 12, 48, 0.96, false, 23, -5.5 },         -- C3
    { 13.5, 48, 0.5, true, 1, -9.6, 0.6 },
    { 14, 43, 0.35, true, 33, -3.5 },
    { 14.5, 48, 0.36, true, 42, -7.0 },
    { 15, 44, 0.72, false, 32, -3.3, nil, 'scoop' }, -- G#2, scooped up into, sliding on to the A
}
-- the synth's skank chords: { beat, velocity (0..1 as basic-pitch heard it), length ms, ms late, midi... }
lib.CHORDS = {
    { 1, 0.38, 110, 15, 60, 72 },             -- C4 C5 (Am)
    { 1.5, 0.38, 90, 40, 64 },                -- E4
    { 3, 0.37, 140, 40, 57, 60, 72 },         -- A3 C4 C5
    { 5, 0.56, 190, 46, 65 },                 -- F4 (Dm), loud and long
    { 7, 0.53, 230, 12, 65 },
    { 7.5, 0.33, 80, 18, 62 },                -- D4
    { 9, 0.39, 130, 40, 55, 59, 71, 74 },     -- G3 B3 B4 D5 (G)
    { 12, 0.38, 115, 50, 55 },                -- G3
    { 13, 0.44, 125, 59, 55, 60, 72 },        -- G3 C4 C5 (C)
    { 13.5, 0.38, 105, 30, 60, 72 },
    { 15, 0.42, 160, 55, 60, 72 },
}
-- the melody: { beat, midi, velocity, length ms, ms late }. Not in it: what basic-pitch heard as F6 (5.5), A5
-- (7.5) and G5 (13), the 4th harmonic of the F4 and the 12ths of the D4 and the C4 struck with them (the synth's
-- brightness, not notes; played, they stuck out: Nikki 'the notes are off')
lib.MELODY = {
    { 0, 72, 0.57, 110, 72 },    -- C5
    { 0.5, 71, 0.44, 190, 74 },  -- B4
    { 3.5, 72, 0.36, 95, -7 },   -- C5
    { 8.5, 79, 0.46, 170, 65 },  -- G5
    { 9.5, 77, 0.50, 130, 34 },  -- F5
    { 10, 77, 0.39, 120, 25 },
    { 10.5, 76, 0.45, 105, 33 }, -- E5
}
-- the rhythm box, 4 bars: { beat, patch, midi, vol }. Kicks where the kick band hit in >55% of the cycles (vol
-- from its level), the rim on 2 and 2&, maracas on the swung 'a's (a 16th + ~50 ms: 0.87 of the beat), claps
-- on bar 2's and bar 4's loud 4&, soft hats on 2, 2&, 4, 4&
local K, R, M, CL, H = 'tr808Kick', 'tr808Rim', 'tr808Maracas', 'tr808Clap', 'tr808HatClosed'
lib.BOX = {
    { 0, K, 36, 3 }, { 1.5, K, 36, 5 }, { 1, R, 60, 3 }, { 1.5, R, 60, 4 }, { 1.87, M, 60, 3 }, { 3.87, M, 60, 3 },
    { 4.5, K, 36, 4 }, { 5, K, 36, 6 }, { 5.5, K, 36, 5 }, { 5, R, 60, 4 }, { 5.5, R, 60, 3 }, { 5.87, M, 60, 3 },
    { 7.5, CL, 60, 5 },
    { 8, K, 36, 5 }, { 9, K, 36, 5 }, { 9.5, K, 36, 6 }, { 11, K, 36, 4 }, { 8, R, 60, 4 }, { 9, R, 60, 3 },
    { 9.5, R, 60, 3 }, { 9.87, M, 60, 3 }, { 11.87, M, 60, 3 },
    { 12, K, 36, 3 }, { 12.5, K, 36, 3 }, { 13, K, 36, 5 }, { 13.5, K, 36, 4 }, { 15, K, 36, 6 }, { 13, R, 60, 4 },
    { 13.5, R, 60, 3 }, { 13.87, M, 60, 3 }, { 15.5, CL, 60, 4 },
}
for b = 0, 3 do
    for _, s in ipairs({ 1, 1.5, 3, 3.5 }) do lib.BOX[#lib.BOX + 1] = { b * 4 + s, H, 60, 2 } end
end
-- the harmony a bar (for what plays along): Am Dm G C
lib.HARMONY = { { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' } }

lib.FORM = {
    { 'intro', 4, { box = true, bass = true } },
    { 'A', 24, { box = true, bass = true, chords = true, melody = true } },
    { 'drop', 8, { box = true, bass = true, chords = true } },
    { 'A', 24, { box = true, bass = true, chords = true, melody = true } },
    { 'outro', 4, { box = true, bass = true } },
    { 'end', 1, { ending = true } },
}

local function human() return state.musicSettings.humanize ~= false end
local function gauss(sd)
    return sd * math.sqrt(-2 * math.log(1 - love.math.random())) * math.cos(2 * math.pi * love.math.random())
end
local function dbGain(db) return 10 ^ (db / 20) end

-- the bent notes (cents curves), ids out of the others' way (parlour 21-28, Rhodes 31, brew 35)
local SH = { sag = 36, scoop = 37, close = 38 }
local function defineShapes(synth)
    if state.music.neigeShapes == synth.audioTime then return end
    if synth.defineShape(SH.sag, { 0, 60, 260 }, { 0, -10, -55 }, 'ease')
        and synth.defineShape(SH.scoop, { 0, 90 }, { -60, 0 }, 'fast')
        and synth.defineShape(SH.close, { 0, 200 }, { 1, 0 }, 'fast') then
        state.music.neigeShapes = synth.audioTime
    end
end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        list[#list + 1] = { entry[1], entry[2], function(j) return lib.HARMONY[j % 4 + 1] end, entry[3] }
    end
    addSections(song, list)
    song.key = 0 -- the record's: C, the cycle on A minor
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

-- one bass note: humanized (its measured lateness and level, the shorts stopped dead, the bends), or plain
local function bookBassNote(play, synth, t0, song, n, lo, final, h)
    local beat, midi, len, short, ms, db, odds, bend = n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8]
    local at = t0 + (beat - lo) * song.beat
    local s = math.floor((beat - lo) * 4 + 0.5)
    if final then len, short = 4, false end
    if not h then
        play(synth, 'bass', 'hUpright', at, midi, 7, len * song.beat * 920, s, nil, nil, { gain = 0.8 })
        return
    end
    if odds and love.math.random() >= odds then return end
    local d = db + gauss(1.0)
    local force = 0.85 * dbGain(d)
    local opts = { gain = math.min(1, force), cents = gauss(4), timbre = d * 0.03 - 0.05,
                   shapes = { { id = SH.close, target = 'cutoff', scale = math.max(0.6, 1.2 + d * 0.1) } } }
    if bend then opts.shapes[2] = { id = SH[bend], target = 'pitch' } end
    if short then opts.damp = 0.85 + 0.1 * love.math.random() else opts.release = 140 end
    local tt = at + ms / 1000 + gauss(0.012)
    play(synth, 'bass', 'hUpright', tt, midi, 7, len * song.beat * 1000, s, nil, nil, opts)
    play(synth, 'bass', 'hThump', tt, 36, 7, 80, s, nil, nil, { gain = math.min(1, force * force * 0.8) })
end

local function bookBass(play, synth, t0, song, b, roles, h)
    local notes, lo = inBar(lib.BASS, b)
    for _, n in ipairs(notes) do
        if not roles.ending or n[1] == 0 then -- the ending rings only the one
            bookBassNote(play, synth, t0, song, n, lo, roles.ending, h)
        end
    end
end

-- the synth's chords and melody, their measured velocities (as gain), lengths and lateness
local function bookSynth(play, synth, t0, song, b, list, isMelody, h)
    local events, lo = inBar(list, b)
    for _, e in ipairs(events) do
        local at = t0 + (e[1] - lo) * song.beat
        local s = math.floor((e[1] - lo) * 4 + 0.5)
        local vel, len, ms
        local notes = {}
        if isMelody then
            vel, len, ms = e[3], e[4], e[5]; notes[1] = e[2]
        else
            vel, len, ms = e[2], e[3], e[4]
            for k = 5, #e do notes[#notes + 1] = e[k] end
        end
        for k, midi in ipairs(notes) do
            if not h then
                play(synth, isMelody and 'lead' or 'keys', 'neigeSynth', at, midi, 4, len, s)
            else
                local tt = at + ms / 1000 + gauss(0.008) + (k - 1) * 0.003
                local g = math.min(1, (vel / 0.57) * dbGain(gauss(1.0)))
                play(synth, isMelody and 'lead' or 'keys', 'neigeSynth', tt, midi, 4,
                     len * (0.9 + 0.2 * love.math.random()), s, nil, nil, { gain = g, cents = gauss(4) })
            end
        end
    end
end

-- the box sits ~9.5 dB under the bass in the record (stems over 20-160 s): every hit at a third of its gain
local BOX_GAIN = 0.33
local function bookBox(play, synth, t0, song, b)
    local hits, lo = inBar(lib.BOX, b)
    for _, k in ipairs(hits) do
        play(synth, 'drums', k[2], t0 + (k[1] - lo) * song.beat, k[3], k[4], 120, math.floor((k[1] - lo) * 4 + 0.5),
             nil, nil, { gain = BOX_GAIN })
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
    if h then defineShapes(synth) end
    local roles = song.barSection[b].roles
    if roles.bass or roles.ending then bookBass(play, synth, t0, song, b, roles, h) end
    if roles.chords then bookSynth(play, synth, t0, song, b, lib.CHORDS, false, h) end
    if roles.melody then bookSynth(play, synth, t0, song, b, lib.MELODY, true, h) end
    if roles.box then bookBox(play, synth, t0, song, b) end
end

return lib
