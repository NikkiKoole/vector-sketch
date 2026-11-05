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
-- The kit plays the same in both: the sampled bar is a drummer's, with its own fixed pushes.
-- The form: the bass alone for two passes, then the kit, then the bass alone again, ending on its last note.
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

lib.FORM = {
    { 'intro', 6, {} },
    { 'A', 24, { drums = true } },
    { 'outro', 6, {} },
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
    bookBass(play, synth, t0, song, b, roles, h)
    if roles.drums then bookDrums(play, synth, t0, song) end
end

return lib
