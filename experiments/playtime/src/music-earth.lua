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

-- the bass: { beat in the cycle, midi, length beats, short, odds }. Lengths from the fold; no odds: the record
-- is one fixed loop, so a note heard in only some passes was the transcriber missing it (Nikki 2026-11-12: "the
-- second time the whole phrase is played it misses the ending note"); the shorts are stopped, the held ones ring
local function pulse(bar)
    local o = bar * 4
    return { o, 48, 0.2, true }, { o + 0.25, 48, 0.18, true }, { o + 0.5, 48, 0.2, true },
        { o + DRAG, 48, 0.22, true }, { o + 1, 48, 0.25, true }, { o + 1.25, 48, 0.3, true }
end
lib.BASS = {}
for bar = 0, 2 do
    for _, n in ipairs({ pulse(bar) }) do lib.BASS[#lib.BASS + 1] = n end
end
local function add(list, entries) for _, e in ipairs(entries) do list[#list + 1] = e end end
-- Eb3 on 3, half a beat, and again on 4: bar 1's in all three bars. The record's bars 2 and 3 held the first
-- nearly a beat, and then the one on 4 ran into it without an attack (onset 0.4-0.5 against bar 1's 0.9:
-- Nikki 2026-11-12, "the vibes still seem to lose an end note at the second bar or 3rd")
add(lib.BASS, {
    { 2, 51, 0.5, false }, { 3, 51, 0.35, false },
    { 6, 51, 0.5, false }, { 7, 51, 0.35, false },
    { 10, 51, 0.5, false }, { 11, 51, 0.35, false },
    { 12, 45, 0.12, true },              -- A2, a short one, then held
    { 12.25, 45, 0.6, false },
    { 14.25, 38, 0.85, false },          -- D2 on the 'e' of 3 (a 16th late)
    { 15, 38, 0.35, false },
    { 15.5, 38, 0.3, false },
})
-- the keys: { beat, length beats, odds, midi... }; top line as heard over the passes (13-16 of 16). Odds all 1:
-- the record is one fixed loop, so a note heard in only some passes was the transcriber missing it, not the
-- player (Nikki 2026-11-12: "the vibes still seem to lose an end note at the second bar or 3rd")
lib.KEYS = {}
for bar = 0, 2 do
    local o = bar * 4
    add(lib.KEYS, {
        { o, 0.5, 1, 67 },               -- G4
        { o + 0.5, 1.05, 1, 67, 74 },    -- G4 + D5: the 9th on top
        { o + 1, 1.4, 1, 67 },
        { o + 2.5, 1.4, 1, 73 },         -- Db5 over the Eb: its 7th, the top sighing down a half step
        { o + 3, 0.95, 1, 67 },
    })
end
add(lib.KEYS, {
    { 12, 0.7, 1, 61, 67, 72 },          -- A7#9: C#4 G4, C5 on top
    { 13, 0.85, 1, 66, 70 },          -- A7b9 13: F#4 Bb4
    { 14, 1.15, 1, 65, 69 },           -- Dm7: F4 A4
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

-- one loop on and on, as the record: no ending bar (it stopped, then the next song started: Nikki 2026-11-12
-- "it stopped and then started"); after 40 bars the next song carries straight on with the same take
lib.FORM = {
    { 'A', 40, { keys = true, bass = true, kit = true, solo = true } },
}

local function human() return state.musicSettings.humanize ~= false end
local function gauss(sd)
    return sd * math.sqrt(-2 * math.log(1 - love.math.random())) * math.cos(2 * math.pi * love.math.random())
end

-- One take, played every pass: the record is one sampled loop, the same every time, so the humanizing nudges
-- (timing, loudness, pitch) are drawn once a song, on the loop's first pass, and every later pass reuses them
-- (Nikki 2026-11-12: "might as well just play the exact thing you play first phrase and repeat"). take(song,
-- key, sd) is the note's nudge for that key: drawn the first time, the same after, and kept on state.music so
-- the next song (after 40 bars) plays the same take, the loop running on without a seam.
local function take(_song, key, sd)
    local m = state.music
    m.earthTake = m.earthTake or {}
    local v = m.earthTake[key]
    if v == nil then
        v = gauss(sd)
        m.earthTake[key] = v
    end
    return v
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

-- beats from `beat` to the next note of the same pitch in the cycle (wrapping round; 16 if none). A note must
-- be done, its ring too, before its pitch comes again: two copies of one pitch overlapping cancel or add up by
-- how their waves happen to line up, so the second note vanished in some passes and boomed in others (the D2
-- on the last bar's 4 nearly gone in pass 2; Nikki 2026-11-12: "the second and maybe 5th skips a note at the end")
local function gapToSame(list, beat, midi)
    local best = 16
    for _, e in ipairs(list) do
        local has = e[2] == midi and list == lib.BASS
        if list == lib.KEYS then
            for k = 4, #e do has = has or e[k] == midi end
        end
        if has then
            local d = (e[1] - beat) % 16
            if d > 0.001 and d < best then best = d end
        end
    end
    return best
end
-- the note's length and release (ms) so it's quiet before its pitch comes again
local function fit(list, beat, midi, lenMs, rel, song)
    local gap = gapToSame(list, beat, midi) * song.beat * 1000 - 15
    if lenMs + rel > gap then
        rel = math.max(40, math.min(rel, gap - lenMs))
        lenMs = math.max(30, math.min(lenMs, gap - rel))
    end
    return lenMs, rel
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
            local lenMs, rel = len * song.beat * 1000, short and 60 or 120
            if not final then lenMs, rel = fit(lib.BASS, beat, midi, lenMs, rel, song) end
            if not h then
                if not odds or odds >= 0.5 then
                    play(synth, 'bass', 'earthBass', at, midi, 6, lenMs, s, nil, nil, { release = rel })
                end
            else
                local key = 'b' .. beat .. ':' .. midi
                local opts = { gain = math.min(1, 0.8 * 10 ^ (take(song, key .. 'g', 1.2) / 20)),
                               cents = take(song, key .. 'c', 4), release = rel }
                if short then opts.damp = 0.8 end
                play(synth, 'bass', 'earthBass', at + take(song, key .. 't', 0.006), midi, 6, lenMs, s, nil, nil,
                     opts)
            end
        end
    end
end

-- the keys' mallet rings 1.1 s after a note (synth.lua earthKeys): shortened before its pitch comes again
local KEYS_RING = 1100
local function bookKeys(play, synth, t0, song, b, h)
    local events, lo = inBar(lib.KEYS, b)
    for _, e in ipairs(events) do
        local at = t0 + (e[1] - lo) * song.beat
        local s = math.floor((e[1] - lo) * 4 + 0.5)
        local odds = e[3]
        if odds >= 0.5 then
            for k = 4, #e do
                local len, rel = fit(lib.KEYS, e[1], e[k], e[2] * song.beat * 1000, KEYS_RING, song)
                if h then
                    local key = 'k' .. e[1] .. ':' .. e[k]
                    play(synth, 'keys', 'earthKeys', at + 0.012 + take(song, key .. 't', 0.006) + (k - 4) * 0.004, e[k],
                         4, len, s, nil, nil, { gain = math.min(1, 0.85 * 10 ^ (take(song, key .. 'g', 1.0) / 20)),
                         cents = take(song, key .. 'c', 3), release = rel })
                else
                    play(synth, 'keys', 'earthKeys', at, e[k], 4, len, s, nil, nil, { release = rel })
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

---------------------------------------------------------------- the solo

-- A solo on top (Nikki 2026-11-12: "can you think up some solo thingie on top of this?"): a kalimba (synth.lua
-- earthSolo) above the
-- loop, sparse: two passes rest, then a call (A) and an answer (B), a pass's rest, A B again. Made once a
-- song and the same every time it comes round (steady, not wandering). Over each half bar the beats land on
-- the chord's own notes and the notes between step to the next; a phrase's second bar takes its first bar's
-- rhythm (the motif), the tune drifts down like the vibes' sigh, and the fourth bar lands long on the
-- turnaround (A on the A7, then F or D on the Dm7). Pitch classes per half bar of the cycle:
local HALF = {
    sus = { tones = { 0, 2, 7 }, between = { 3, 5, 10 } },          -- C sus2: C D G (Eb F Bb between)
    eb7 = { tones = { 3, 7, 10, 1 }, between = { 5, 0 } },          -- Eb7: Eb G Bb Db (F C between)
    a7 = { tones = { 9, 1, 4, 7 }, between = { 0, 10 } },           -- A7#9: A C# E G (the #9 C, b9 Bb between)
    dm7 = { tones = { 2, 5, 9, 0 }, between = { 4, 7 } },           -- Dm7: D F A C
}
local HALF_OF = { 'sus', 'eb7', 'sus', 'eb7', 'sus', 'eb7', 'a7', 'dm7' }
lib.SOLO_ROUNDS = { false, false, 'A', 'B', false, 'A', 'B', false, 'A', 'B' } -- per pass of a 40-bar song
lib.SOLO_LO, lib.SOLO_HI = 74, 86 -- D5..D6, over the vibes' top (D5)
-- rhythm cells (16ths in a bar): the call's and the answer's first bars, the third bar's run, the landing
local CALLS = { { 2, 3, 6 }, { 2, 6, 7 }, { 0, 3, 6 }, { 6, 7, 10 } }
local RUNS = { { 2, 4, 6, 8, 10 }, { 4, 5, 6, 10, 12 }, { 2, 3, 6, 10, 11 } }
local LANDS = { { 0, 2, 4 }, { 2, 4 }, { 0, 3 } } -- then a long note on beat 3 (the Dm7)

local function pcsAt(slot) -- slot: a 16th in the cycle (0..63)
    return HALF[HALF_OF[math.floor(slot / 8) + 1]]
end
-- the nearest pitch in range whose class is in `set`, going `dir` (-1/1) from p (not p itself), or any way
local function nearest(p, set, dir)
    local best, bestD
    for q = lib.SOLO_LO, lib.SOLO_HI do
        local pc = q % 12
        for _, c in ipairs(set) do
            if pc == c and q ~= p then
                local d = (q - p) * dir
                local cost = d > 0 and d or 12 - d -- the way it's going first
                if not bestD or cost < bestD then best, bestD = q, cost end
            end
        end
    end
    return best or p
end

-- one phrase (4 bars): { { slot, midi, length in 16ths, accent }, ... }
local function makePhrase(rng, answer)
    local notes, p, dir = {}, answer and 79 or 81, -1
    local function place(slot, last)
        local h = pcsAt(slot)
        local onBeat = slot % 4 == 0
        local set = onBeat and h.tones or {}
        if not onBeat then
            for _, c in ipairs(h.tones) do set[#set + 1] = c end
            for _, c in ipairs(h.between) do set[#set + 1] = c end
        end
        if last then set = h.tones end
        if rng:random() < 0.25 then dir = -dir end
        if p <= lib.SOLO_LO + 2 then dir = 1 elseif p >= lib.SOLO_HI - 2 then dir = -1 end
        p = nearest(p, set, dir)
        notes[#notes + 1] = { slot, p, 1, #notes == 0 }
    end
    local call = CALLS[rng:random(#CALLS)]
    local bars = answer and { {}, call, RUNS[rng:random(#RUNS)], LANDS[rng:random(#LANDS)] }
        or { call, call, RUNS[rng:random(#RUNS)], LANDS[rng:random(#LANDS)] }
    if answer then bars[1] = { 10, 12, 14 } end -- the answer comes in late, a pickup into its motif
    for b = 1, 4 do
        for _, s in ipairs(bars[b]) do place((b - 1) * 16 + s) end
    end
    dir = -1
    place(56, true) -- the landing: beat 3 of the fourth bar, on the Dm7
    -- lengths: up to the next note, played short (a kalimba's pluck); the landing rings
    for i, n in ipairs(notes) do
        local nxt = notes[i + 1]
        n[3] = nxt and math.max(1, math.min(3, nxt[1] - n[1] - 0.5)) or 7
    end
    return notes
end

-- the song's solo: made on first use (a song's own, kept while the song plays)
local function solo(song)
    if not song.earthSolo then
        local rng = { random = function(_, n) return n and love.math.random(n) or love.math.random() end }
        song.earthSolo = { A = makePhrase(rng, false), B = makePhrase(rng, true) }
    end
    return song.earthSolo
end

local function bookSolo(play, synth, t0, song, b, h)
    local round = lib.SOLO_ROUNDS[(math.floor((b - 1) / 4) % #lib.SOLO_ROUNDS) + 1]
    if not round then return end
    local lo = ((b - 1) % 4) * 16
    for _, n in ipairs(solo(song)[round]) do
        if n[1] >= lo and n[1] < lo + 16 then
            local s = n[1] - lo
            local at = t0 + s / 4 * song.beat
            local len = n[3] / 4 * song.beat * 1000
            if h then
                local key = 's' .. round .. n[1]
                play(synth, 'lead', 'earthSolo', at + 0.015 + take(song, key .. 't', 0.008), n[2], n[4] and 6 or 5, len,
                     s, nil, nil, { gain = math.min(1, 0.8 * 10 ^ (take(song, key .. 'g', 1.2) / 20)) })
            else
                play(synth, 'lead', 'earthSolo', at, n[2], n[4] and 6 or 5, len, s)
            end
        end
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
    if roles.solo then bookSolo(play, synth, t0, song, b, h) end
end

return lib
