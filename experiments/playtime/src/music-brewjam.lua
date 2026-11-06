-- music-brewjam.lua
-- brewjam: improvisations on brew. Each song a new 3-bar riff with its organ and guitar, made by the rules
-- Electric Relaxation / Mystic Brew work by (docs/MUSIC-ANALYSIS.md Song 3, "What makes it work, as rules"),
-- and played by brew's own player (src/music-brew.lua): the measured feel, the drums, the bells, the form.
--   the riff     three bars; each opens with the push (a short, hand-stopped note on the beat, a long one on the
--                "and"), then one of a few figures; the last note leads back round
--   the harmony  one note held on top for two bars, another for the third; the long notes (and the bars' other
--                notes) are bass notes under which that top note is a colour: 6th, 9th, 3rd, maj7, #11, or a minor
--                chord's 3rd or 7th, never a b9. The pickups lead in: a step above, a 3rd below, a 4th or 5th
--   the chords   the organ: the top note with that colour's chord tones under it, no half steps between voices;
--                the guitar: the inner notes. Both strike with the bass's notes (not its pickups) and hold
--   the feel     by role: pickups early, long notes late, beat notes a hair early, the last note early and loud
-- Brew itself stays Mystic Brew's riff; this one is in the set's key, its bass kept between G1 and A#2.
local theory = require('src.music-theory')
local brew = require('src.music-brew')
local stream = theory.stream

local lib = {}

-- the bar figures: { beat in the bar, role, length in beats, short (hand-stopped) }. A, B, C are Mystic Brew's
-- three bars; D sparser (the long note rings to 4), E busier (a walk of 8ths after the push)
lib.CELLS = {
    A = { { 0, 'pick', 0.54, true }, { 0.5, 'long', 1.39 }, { 2, 'beat', 0.81 }, { 3, 'beat', 0.94 } },
    B = { { 0, 'pick', 0.54, true }, { 0.5, 'long', 1.26 }, { 2, 'beat', 0.52, true }, { 2.5, 'off', 0.53, true },
          { 3, 'beat', 0.73 } },
    C = { { 0, 'pick', 0.5, true }, { 0.5, 'long', 1.3 }, { 2.5, 'off', 0.49, true }, { 3, 'beat', 0.82 } },
    D = { { 0, 'pick', 0.54, true }, { 0.5, 'long', 2.3 }, { 3, 'beat', 0.9 } },
    E = { { 0, 'pick', 0.54, true }, { 0.5, 'long', 1.3 }, { 2, 'beat', 0.5, true }, { 2.5, 'off', 0.5, true },
          { 3, 'beat', 0.5, true }, { 3.5, 'off', 0.45, true } },
}
-- which figures each bar of the riff may take (Mystic Brew's first, and more often)
lib.BAR_CELLS = { { 'A', 'A', 'D', 'C' }, { 'B', 'B', 'E', 'A', 'C' }, { 'C', 'C', 'A', 'D' } }
-- the feel by role, measured on Ronnie (beats: + late) and the accents (dB)
lib.FEEL = { pick = -0.045, long = 0.045, beat = -0.015, off = 0.006, lead = -0.024 }
lib.ACCENT = { pick = -0.9, long = 1.6, beat = -0.3, off = 0.2, lead = 2.6 }

-- the top note as a colour of the bass note under it: (top - bass) % 12 -> weight, and the chord tones (semitones
-- over the bass) that fill in under the top
lib.COLOURS = {
    [9] = { 3, { 4, 2 } },        -- the 6th: 6/9
    [2] = { 3, { 9, 5 } },        -- the 9th: 13sus
    [4] = { 3, { 11, 7, 2 } },    -- the 3rd: maj9
    [11] = { 2, { 4, 7 } },       -- the maj7
    [6] = { 2, { 11, 7, 2 } },    -- the #11: maj9#11, Lydian
    [7] = { 1, { 4, 2 } },        -- the 5th: add9
    [3] = { 1, { 10, 7 } },       -- a minor chord's 3rd: m7
    [10] = { 1, { 3, 7 } },       -- a minor chord's 7th
}
-- the top notes over the key (bars 1-2), and how the third bar's moves from it
local TOPS = { 4, 9, 2, 11, 7 }
local TOP_MOVES = { 3, 5, 7, 10, 6 }
-- the pickups: semitones from the long note they lead into
local PICKUPS = { 2, -3, -4, 5, -5, 7, -1 }
-- how the long notes move from bar to bar (pitch classes, weighted by how often)
local MOVES = { [-2] = 3, [-5] = 3, [5] = 2, [-3] = 2, [-1] = 1, [2] = 1, [3] = 1, [6] = 1 }
local LO, HI = 31, 46 -- G1 .. A#2

local function pick(rnd, list) return list[rnd(#list) + 1] end

-- the octave of pitch class pc nearest to near, inside the bass's range
local function place(pc, near)
    local best
    for m = LO, HI do
        if m % 12 == pc and (not best or math.abs(m - near) < math.abs(best - near)) then best = m end
    end
    return best
end

-- a bass pitch class under `top`, moving from `from` (a pitch class, or nil), weighted by colour and motion
local function bassUnder(rnd, top, from, avoid)
    local cands, total = {}, 0
    for pc = 0, 11 do
        local colour = lib.COLOURS[(top - pc) % 12]
        if colour and pc ~= avoid and pc ~= from then
            local w = colour[1]
            if from then
                local d = ((pc - from + 6) % 12) - 6
                w = w * (MOVES[d] or 0.3)
            end
            cands[#cands + 1] = { pc, w }; total = total + w
        end
    end
    local r = rnd() * total
    for _, c in ipairs(cands) do
        r = r - c[2]
        if r <= 0 then return c[1] end
    end
    return cands[#cands][1]
end

-- the organ's chord over bass pc with `topMidi` on top: the colour's tones under it, no half steps between them
local function voicing(bass, topMidi)
    local colour = lib.COLOURS[(topMidi - bass) % 12]
    local notes = { topMidi }
    for _, iv in ipairs(colour[2]) do
        local pc = (bass + iv) % 12
        local m = topMidi - ((topMidi - pc) % 12)
        if m == topMidi then m = m - 12 end
        local ok = true
        for _, n in ipairs(notes) do
            local d = math.abs(n - m)
            if d <= 1 then ok = false end -- no half steps, no doubling
        end
        if ok then notes[#notes + 1] = m end
    end
    table.sort(notes)
    return notes
end

-- One improvised riff with its chords, in brew's tables: riff notes { beat, semitones over F2 (41), length, short,
-- feel, accent }, organ and guitar { beat, midi... }, ghosts { beat, semitones over 41 }, chords a bar
function lib.improvise(key, rnd)
    local top1 = (key + pick(rnd, TOPS)) % 12
    local top2 = (top1 + pick(rnd, TOP_MOVES)) % 12
    local topMidi1 = 64 + (top1 - 64) % 12 -- between E4 and Eb5 (Mystic Brew's A4)
    -- the third bar's top: the octave nearest the first (a tie goes up, as Mystic Brew's A goes up to its Eb),
    -- kept between Eb4 and Eb5
    local down = topMidi1 - ((topMidi1 - top2) % 12)
    local topMidi2 = (topMidi1 - down < down + 12 - topMidi1) and down or down + 12
    if topMidi2 < 63 then topMidi2 = topMidi2 + 12 elseif topMidi2 > 75 then topMidi2 = topMidi2 - 12 end
    -- the long notes, bar by bar, each under its bar's top; the last leads back to the first
    local tops = { top1, top1, top2 }
    local longs = {}
    longs[1] = bassUnder(rnd, top1, nil)
    longs[2] = bassUnder(rnd, top1, longs[1])
    longs[3] = bassUnder(rnd, top2, longs[2], longs[1])
    local riff, organ, guitar, ghosts, chords = {}, {}, {}, {}, {}
    local prev = place(longs[3], 38)
    for bar = 1, 3 do
        local cell = lib.CELLS[pick(rnd, lib.BAR_CELLS[bar])]
        local top, topMidi = tops[bar], bar == 3 and topMidi2 or topMidi1
        local long = longs[bar]
        local nextLong = longs[bar % 3 + 1]
        local pc = long
        chords[bar] = { (long - key) % 12, 'maj9' }
        for i, n in ipairs(cell) do
            local pos, role, len, short = (bar - 1) * 4 + n[1], n[2], n[3], n[4]
            if role == 'pick' then
                local p = (long + pick(rnd, PICKUPS)) % 12
                if math.abs(((p - top + 6) % 12) - 6) == 1 then p = (long + 2) % 12 end -- no half step on the top
                pc = p
            elseif role == 'long' then
                pc = long
            else -- a beat or off note: under the same top, heading for the next bar's long note
                local before = pc
                pc = bassUnder(rnd, top, before)
                if i == #cell and bar == 3 then -- the lead back: near the first long note, not the note before
                    local lead = bassUnder(rnd, top, nextLong, before)
                    if math.abs(((lead - nextLong + 6) % 12) - 6) <= 2 then pc = lead end
                end
            end
            local midi = place(pc, prev)
            prev = midi
            local lead = bar == 3 and i == #cell
            local r = lead and 'lead' or role
            riff[#riff + 1] = { pos, midi - 41, len, short or false, lib.FEEL[r], lib.ACCENT[r],
                                drop = role == 'long' and bar == 2 and 0.3 or nil }
            if role ~= 'pick' then
                local v = voicing(pc, topMidi)
                organ[#organ + 1] = { pos, unpack(v) }
                if role ~= 'off' then
                    local inner = {}
                    for k = 1, #v - 1 do inner[#inner + 1] = v[k] end
                    if #inner < 2 then table.insert(inner, 1, v[1] - 5) end
                    guitar[#guitar + 1] = { pos, unpack(inner) }
                end
            end
            if role == 'long' then ghosts[#ghosts + 1] = { pos + 0.75, midi - 41 } end
        end
    end
    return { riff = riff, organ = organ, guitar = guitar, ghosts = ghosts, chords = chords,
             tops = { top1, top2 } }
end

function lib.plan(song, _style, addSections)
    local g = lib.improvise(song.key, stream(song.seed, 300))
    brew.addForm(song, addSections, g.chords)
    song.brew = { shift = 0, passGain = 0, riff = g.riff, organ = g.organ, guitar = g.guitar, ghosts = g.ghosts,
                  tops = g.tops }
end

function lib.bookBar(play, remember, synth, t0, song, b)
    return brew.bookBar(play, remember, synth, t0, song, b)
end

return lib
