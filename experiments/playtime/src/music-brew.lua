-- music-brew.lua
-- brew: the 3-bar bass riff Electric Relaxation loops from Ronnie Foster's Mystic Brew, played the way
-- Ronnie plays it (measured, docs/MUSIC-ANALYSIS.md "Song 3", 2026-11-05), over Electric Relaxation's drum
-- bar (Brethren's Outside Love, one live bar looped: the same small pushes every bar). As there, the riff's
-- first note lands on the drums' 2. The bass:
--   feel     a fixed offset per note, the same every pass: the notes on the beat land early, the long
--            notes on the "and" late, so each short -> long pair swings lightly (~57:43) and the rest
--            stays near straight. In fractions of a beat, so it scales with the tempo.
--   jitter   on top of it, timing sd ~14 ms, loudness sd ~1.4 dB, pitch sd a few cents.
--   accents  the long notes on the "and" lean (+2 dB), the last note leading back round leans most,
--            the A# sits back (-3 dB); each pass a little louder or softer as a whole.
--   hands    the short notes are stopped by the hand (damped, a full 8th, legato into the next); the
--            long ones ring and let go just before the next note.
--   tone     every pluck opens bright and closes about an octave in 200 ms, more on higher, harder notes.
--   extras   about one quiet dead note a pass off the riff; the A# drops an octave now and then.
-- No scoops, slides or vibrato: Ronnie plays none. The music panel's 'humanize' row plays the same riff
-- plainly (on the grid, one force, the written lengths, no shapes or extras).
-- The keys and guitar (Mystic Brew's, measured per riff slot): Ronnie's organ holds lush chords whose top stays
-- on an A for two bars and an Eb for the third, the guitar small open shapes hanging on an F under it, both
-- struck with the bass's long notes and its beat-3/4 notes and held to the next; the organ a hair behind the
-- grid, the guitar further (a down-strum, ~15 ms).
-- The kit plays the same in both: the sampled bar is a drummer's, with its own fixed pushes.
-- The form follows Electric Relaxation's (MUSIC-ANALYSIS Song 3, "The song's map"), shorter: an intro of drums
-- and bells, the full loop (the organ swelling over its last two bars, the guitar out for the last), a verse of
-- bass, drums and the verse bells, no chords; again; a break of drums and bells; the full loop; the riff's last
-- note ringing. (ER's verses are a second Mystic Brew chop, played a little differently: here the same riff.)
-- Registered as loop = 'brew' in music-plan's LOOP_PLANS and music-parts' LOOP_BARS (as music-upright.lua).
local state = require('src.state')
local theory = require('src.music-theory')
local stepTime = theory.stepTime

local lib = {}

-- the riff, written in Mystic Brew's key (F; Electric Relaxation is it 2 semitones down, Eb), one 12-beat
-- cycle: { beat, semitones over F2 (41), length in beats, short (stopped by the hand), feel (beats: + late),
--          accent dB }. From 3 live passes of Mystic Brew at ~112 BPM (feel ms / 536).
lib.RIFF = {
    { 0.0,  3, 0.54, true,  -0.047, -0.9 }, -- G#2
    { 0.5, -5, 1.39, false,  0.041,  2.0 }, -- C2, long on the and
    { 2.0,  2, 0.81, false, -0.022, -0.2 }, -- G2
    { 3.0,  0, 0.94, false, -0.007, -0.8 }, -- F2
    { 4.0, -5, 0.56, true,  -0.019, -0.4 }, -- C2
    { 4.5,  5, 1.26, false,  0.056, -3.1, drop = 0.3 }, -- A#2, long on the and (an octave down a third of the time)
    { 6.0, -2, 0.52, true,  -0.026, -1.6 }, -- D#2
    { 6.5,  2, 0.53, true,   0.002,  0.5 }, -- G2
    { 7.0,  3, 0.73, false,  0.028,  1.3 }, -- G#2
    { 8.0, -2, 0.50, true,  -0.043, -0.9 }, -- D#2
    { 8.5,  1, 1.30, false,  0.024,  1.9 }, -- F#2, long on the and
    { 10.5, -5, 0.49, true,  0.013, -0.1 }, -- C2
    { 11.0, -4, 0.82, false, -0.024,  2.6 }, -- C#2, leading back round
}
-- the riff starts a beat into the bar: its first note on the drums' 2 (its last, the C#, on the next 1)
local OFFSET = 1
-- the dead notes off the riff (Mystic Brew's extras, Electric Relaxation's re-hits): { beat, semitones }
lib.GHOSTS = { { 1.25, -5 }, { 2.5, -5 }, { 9.25, 1 }, { 10.0, -5 }, { 11.5, -4 } }
-- the harmony under each bar, roughly (for what plays along: impacts, stingers): degree over the key, quality
lib.CHORDS = { { 0, 'm9' }, { 3, 'maj9' }, { 8, 'maj9' } }

-- the organ's and the guitar's chords, in Mystic Brew's key like the riff: { beat in the riff's cycle, midi... },
-- each held to the next. The organ's top: A4 over bars 1-2, Bb4/Eb5 over bar 3
lib.ORGAN = {
    { 0.5, 60, 62, 64, 69 },   -- C6/9 over C
    { 2.0, 57, 64, 69 },       -- G13sus, open 4ths
    { 3.0, 60, 64, 67, 69 },   -- Fmaj9
    { 4.5, 57, 62, 69 },       -- Bbmaj7
    { 6.0, 58, 62, 65, 69 },   -- Ebmaj9#11 (the A: Lydian)
    { 6.5, 58, 65, 69 },       -- Gm9
    { 7.0, 60, 65, 70 },       -- Ab6/9
    { 8.5, 58, 63, 70 },       -- Gb6 over F#
    { 10.0, 63, 65, 68, 70 },  -- Ab6/9 over C
    { 11.0, 60, 63, 65, 70 },  -- Dbmaj9/13
}
lib.GUITAR = {
    { 0.5, 55, 60, 65 },       -- G C F over C
    { 2.0, 60, 65 },           -- C F over G
    { 3.0, 57, 60, 62, 65 },   -- A C D F over F
    { 4.5, 57, 62, 65 },       -- A D F over Bb
    { 6.0, 57, 62, 65 },       -- A D F over Eb
    { 7.0, 58, 63, 68, 70 },   -- Bb Eb Ab Bb over Ab
    { 8.5, 61, 65, 68, 70 },   -- C# F G# A# over F#
    { 10.0, 56, 61, 63, 65 },  -- G# C# D# F
    { 11.0, 61, 65, 68, 73 },  -- C# F G# C# over C#
}

-- the bells: a pair, like an agogo's (measured per hit 2026-11-06: every intro hit the same two partials, 1635
-- and 2604 Hz, ratio 1.59, an inharmonic bell, not an arpeggio, its louder partial changing from hit to hit;
-- the verse's a lower one, 1241 + 1863 Hz; both a quarter tone flat of the loop, which sounded off). One pitch
-- each, in tune (Nikki: 'let them have 1 pitch, be rhythmic'): the high bell Ab6, the low one the key's Eb6.
-- { beat in the bar, bell, volume }. The intro and break: the high bell on the beats ~35 ms late, a soft grace
-- just before 4 and a soft and-of-4. The verse: the low bell in 8ths a little late, once a pass, second bar.
local HIGH, LOW = 92, 87
lib.BELLS = {
    verse = { { 0.2, LOW, 3 }, { 0.7, LOW, 3 }, { 1.2, LOW, 3 }, { 1.7, LOW, 3 }, { 2.2, LOW, 3 }, { 2.7, LOW, 3 } },
    intro = { { 0.06, HIGH, 3 }, { 1.06, HIGH, 3 }, { 2.06, HIGH, 3 }, { 2.9, HIGH, 2 }, { 3.05, HIGH, 3 },
              { 3.45, HIGH, 2 } },
}

lib.FORM = {
    { 'intro', 3, { drums = true, bells = 'intro', bass = false } },
    { 'A', 12, { band = true, drums = true, swell = true } },
    { 'verse', 9, { drums = true, bells = 'verse' } },
    { 'A', 12, { band = true, drums = true, swell = true } },
    { 'verse', 6, { drums = true, bells = 'verse' } },
    { 'break', 3, { drums = true, bells = 'intro', bass = false } },
    { 'A', 9, { band = true, drums = true } },
    { 'end', 1, { ending = true } },
}

local function human() return state.musicSettings.humanize ~= false end
-- a normal spread (Box-Muller on love.math.random: the offline renderer's love has no randomNormal)
local function gauss(sd)
    return sd * math.sqrt(-2 * math.log(1 - love.math.random())) * math.cos(2 * math.pi * love.math.random())
end
local function dbGain(db) return 10 ^ (db / 20) end
-- a slow wander, the same for the same time
local function drift(t, k) return math.sin(t * k * 6.1 + 1.3) * 0.6 + math.sin(t * k * 2.3 + 4.1) * 0.4 end

-- the pluck's tone closing (a cutoff curve, in octaves); ids out of parlour's (21-28) and the Rhodes' (31) way
local SH = { close = 35 }
local function defineShapes(synth)
    if state.music.brewShapes == synth.audioTime then return end -- defined in this run already
    if synth.defineShape(SH.close, { 0, 200 }, { 1, 0 }, 'fast') then state.music.brewShapes = synth.audioTime end
end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        list[#list + 1] = { entry[1], entry[2], function(j) return lib.CHORDS[j % 3 + 1] end, entry[3] }
    end
    addSections(song, list)
    -- always in Eb, Electric Relaxation's pitch: the riff 2 down from Mystic Brew's F (Nikki 2026-11-05: the
    -- set's keys moved it up, in Ab it sat too high; pinned to the record's)
    song.key = 3
    song.brew = { shift = -2, passGain = 0 }
end

---------------------------------------------------------------- the bass

local BASE = 0.8 -- the pluck's force at 0 dB

local function pluck(play, synth, song, t, midi, beats, step, opts)
    play(synth, 'bass', 'hUpright', t, midi, 7, beats * song.beat * 1000, step, nil, nil, opts)
end

-- the riff's notes starting inside this bar; the song's last bar only rings the riff's last note
local function bookBass(play, synth, t0, song, b, roles, h)
    local j = b - 1 -- the riff runs on across the sections (each a whole number of passes)
    local pass = j % 3
    local lo, hi = pass * 4, pass * 4 + 4
    local shift = song.brew.shift
    if pass == 0 and h then song.brew.passGain = gauss(0.5) end -- each pass a little louder or softer
    for k, n in ipairs(lib.RIFF) do
        local semi, len, short, feel, acc = n[2], n[3], n[4], n[5], n[6]
        local pos = (n[1] + OFFSET) % 12
        local final = roles.ending and k == #lib.RIFF
        if pos >= lo and pos < hi and (final or not roles.ending) then
            local midi = 41 + semi + shift
            local s = math.floor((pos - lo) * 4 + 0.5) -- 16th step in the bar
            local at = t0 + (pos - lo) * song.beat
            if final then len = 4 end -- the ending: the last note rings
            if not h then
                pluck(play, synth, song, at, midi, final and len or len * 0.92, s, { gain = BASE })
            else
                if n.drop and love.math.random() < n.drop and midi - 12 >= 28 then midi = midi - 12 end
                local tt = at + feel * song.beat + gauss(0.014)
                local db = acc + song.brew.passGain + drift(at, 0.15) * 0.5 + gauss(1.4)
                local force = BASE * dbGain(db)
                -- the tone: opens about an octave over the patch and closes, more on higher, harder notes
                local close = math.max(0.8, math.min(2.6, 1.6 + (midi - 38) * 0.08 + db * 0.12))
                local opts = { gain = math.min(1, force), cents = gauss(5), timbre = db * 0.03,
                               shapes = { { id = SH.close, target = 'cutoff', scale = close } } }
                local gate
                if short then -- stopped by the hand: the full 8th, legato into the next, damped
                    gate = len
                    opts.damp = 0.7 + 0.1 * love.math.random()
                else           -- rings, let go just before the next note
                    gate = final and len or len - 0.05
                    opts.release = 120
                end
                pluck(play, synth, song, tt, midi, gate, s, opts)
                -- the finger and the body knocked, with the hand
                play(synth, 'bass', 'hThump', tt, 38 + math.floor((midi - 36) / 6), 7, 70 + love.math.random(50), s,
                     nil, nil, { gain = math.min(1, force * force * 0.9) })
            end
        end
    end
    -- about one dead note a pass, off the riff (not in the ending)
    if h and not roles.ending then
        for _, g in ipairs(lib.GHOSTS) do
            local pos = (g[1] + OFFSET) % 12
            if pos >= lo and pos < hi and love.math.random() < 0.2 then
                local at = t0 + (pos - lo) * song.beat + gauss(0.014)
                pluck(play, synth, song, at, 41 + g[2] + shift, 0.25, math.floor((pos - lo) * 4 + 0.5),
                      { gain = BASE * dbGain(-6 + gauss(1.5)), damp = 1 })
            end
        end
    end
end

---------------------------------------------------------------- the organ and the guitar

-- the chords of `list` struck inside this bar, each held to the next one (wrapping round the cycle)
local function bookChords(play, synth, t0, song, b, list, part, patch, h, feel, strum, vol, gain)
    local pass = (b - 1) % 3
    local lo, hi = pass * 4, pass * 4 + 4
    for i, c in ipairs(list) do
        local pos = (c[1] + OFFSET) % 12
        if pos >= lo and pos < hi then
            local nextPos = list[i % #list + 1][1]
            local held = (nextPos - c[1]) % 12
            if held == 0 then held = 12 end
            local s = math.floor((pos - lo) * 4 + 0.5)
            local at = t0 + (pos - lo) * song.beat
            local ms = held * song.beat * 1000 - 30
            if not h then
                for k = 2, #c do play(synth, part, patch, at, c[k] + song.brew.shift, vol, ms, s) end
            else
                local tt = at + feel + gauss(0.010)
                local g = gain * dbGain(gauss(1.0))
                for k = 2, #c do
                    local top = k == #c
                    play(synth, part, patch, tt + (k - 2) * strum + math.abs(gauss(0.002)), c[k] + song.brew.shift,
                         vol, ms - (k - 2) * strum * 1000, s, nil, nil,
                         { gain = math.min(1, g * (top and 1 or 0.85)), cents = gauss(3) })
                end
            end
        end
    end
end

---------------------------------------------------------------- the bells

local function bookBells(play, synth, t0, song, b, kind)
    local list
    if kind == 'verse' then
        if (b - 1) % 3 ~= 1 then return end -- once a pass, in its second bar
        list = lib.BELLS.verse
    else
        list = lib.BELLS.intro
    end
    for _, hit in ipairs(list) do
        play(synth, 'perc', 'brewBell', t0 + hit[1] * song.beat, hit[2], hit[3], 150, math.floor(hit[1] * 4 + 0.5))
    end
end

---------------------------------------------------------------- the kit

-- Electric Relaxation's drum bar (Outside Love's drummer, measured on the sampler-straight grid, ms at
-- 98 BPM as beats): the kick on 1, a swung 16th before 2 (5/6 of the beat, 50 ms past the straight 16th),
-- the and-of-2 and the and-of-3 a hair early; the snare on 2 and 4, on time; straight 8th hats, the beats
-- louder. The same every bar: one live bar, looped. { beat, patch, midi, vol, ms }
lib.KIT = {
    { 0, 'bapKick', 36, 6, 220 }, { 0.833, 'bapKick', 36, 4, 160 },
    { 1.487, 'bapKick', 36, 5, 200 }, { 2.484, 'bapKick', 36, 5, 200 },
    { 1.007, 'snare', 60, 5, 140 }, { 1.007, 'bapKick', 50, 3, 90 },
    { 2.998, 'snare', 60, 5, 140 }, { 2.998, 'bapKick', 50, 3, 90 },
}
local function bookDrums(play, synth, t0, song)
    for _, k in ipairs(lib.KIT) do
        play(synth, 'drums', k[2], t0 + k[1] * song.beat, k[3], k[4], k[5], math.floor(k[1] * 4 + 0.5))
    end
    for s = 0, 14, 2 do play(synth, 'drums', 'hat', stepTime(song, t0, s), 60, s % 4 == 0 and 3 or 2, 30, s) end
end

function lib.bookBar(play, remember, synth, t0, song, b)
    local chord = song.chords[b]
    local root = (song.key + chord[1]) % 12
    local pcs = {}
    for _, interval in ipairs(require('src.music-styles').qualities[chord[2]]) do
        pcs[#pcs + 1] = (root + interval) % 12
    end
    pcs[#pcs + 1] = root
    remember(t0, pcs)
    local h = human()
    if h then defineShapes(synth) end
    local roles = song.barSection[b].roles
    if roles.bass ~= false then bookBass(play, synth, t0, song, b, roles, h) end
    -- into a verse (ER's bars 17-18) the organ swells and the guitar drops out for the last bar
    local left = song.barSection[b].bars - song.barIndex[b]
    local swell = roles.swell and left <= 2
    if roles.band or roles.organ then -- the organ a hair behind the grid, its keys together
        bookChords(play, synth, t0, song, b, lib.ORGAN, 'keys', 'brewOrgan', h, 0.008, 0.002, 4, swell and 1 or 0.7)
    end
    if roles.band and not (swell and left == 1) then -- the guitar further behind, a quick down-strum
        bookChords(play, synth, t0, song, b, lib.GUITAR, 'guitar', 'brewGuitar', h, 0.018, 0.012, 4, 0.75)
    end
    if roles.bells then bookBells(play, synth, t0, song, b, roles.bells) end
    if roles.drums then bookDrums(play, synth, t0, song) end
end

return lib
