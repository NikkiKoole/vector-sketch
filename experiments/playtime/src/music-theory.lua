-- music-theory.lua
-- The music's pure functions: seeded streams, voicings, chords in a bar and their tones, rubs, the
-- swung step grid and progressions. They read the song they're given and the style data, nothing
-- else (src/music.lua).

local D = require('src.music-styles')

local lib = {}

-- A seeded stream: rnd(n) is 0..n-1, rnd() is 0..1. Every planning concern draws from its own
-- stream (song seed + a number), so a decision added to one never reshuffles another, and a phrase
-- seeded by its place in the form comes out the same each time that place comes round.
local function stream(seed, k)
    local s = (seed * 69069 + k * 2654435 + 1) % 2147483647
    if s == 0 then s = 1 end
    local function rnd(n)
        s = (s * 16807) % 2147483647
        if n then return s % n end
        return s / 2147483647
    end
    rnd(); rnd()
    return rnd
end

-- lofi.c's lead_to4: every rotation and drop-2 of the chord in every octave, bottom note in
-- lo..lo+12, top at most hi, no semitone or minor ninth between any two notes, no low clusters; the
-- one that moves least from the previous voicing (top-voice leaps over 4 cost extra), pulled toward 62.
local function voiceChord(rootPc, intervals, lo, hi, previous)
    if intervals.stack then -- a fixed shape: the octave nearest the previous voicing's middle
        local best, bestCost = nil, math.huge
        for octave = 2, 7 do
            local v = {}
            for j, interval in ipairs(intervals) do v[j] = rootPc + interval + 12 * octave end
            if v[1] >= lo and v[1] <= lo + 12 and v[#v] <= hi then
                local mean = 0
                for j = 1, #v do mean = mean + v[j] / #v end
                local target = previous and (previous[1] + previous[#previous]) / 2 or 62
                local cost = math.abs(mean - target)
                if cost < bestCost then bestCost, best = cost, v end
            end
        end
        return best or previous
    end
    local pcs = {}
    for _, interval in ipairs(intervals) do
        local pc = (rootPc + interval) % 12
        local dup = false
        for _, existing in ipairs(pcs) do if existing == pc then dup = true end end
        if not dup then pcs[#pcs + 1] = pc end
    end
    table.sort(pcs)
    local n, best, bestCost = #pcs, nil, math.huge
    for rotation = 0, n - 1 do
        for drop2 = 0, (n >= 3 and 1 or 0) do
            local shape = {}
            for j = 0, n - 1 do
                local note = pcs[(rotation + j) % n + 1]
                while j > 0 and note <= shape[j] do note = note + 12 end
                shape[j + 1] = note
            end
            if drop2 == 1 then
                shape[n - 1] = shape[n - 1] - 12
                table.sort(shape)
            end
            for octave = 2, 7 do
                local v = {}
                for j = 1, n do v[j] = shape[j] + 12 * octave end
                if v[1] >= lo and v[1] <= lo + 12 and v[n] <= hi then
                    local bad = false
                    for a = 1, n do
                        for b = a + 1, n do
                            local d = v[b] - v[a]
                            if d == 1 or d == 13 or d == 25 then bad = true end
                        end
                        if a > 1 and v[a] - v[a - 1] < 3 and v[a - 1] < 52 then bad = true end
                    end
                    if not bad then
                        local mean = 0
                        for j = 1, n do mean = mean + v[j] end
                        local cost = 0.5 * math.abs(mean / n - 62)
                        if previous then
                            for j = 1, n do cost = cost + math.abs(v[j] - previous[math.min(j, #previous)]) end
                            local topLeap = math.abs(v[n] - previous[#previous])
                            if topLeap > 4 then cost = cost + 2 * (topLeap - 4) end
                        end
                        if cost < bestCost then bestCost, best = cost, v end
                    end
                end
            end
        end
    end
    return best or previous
end

-- MIDI note of pitch class pc in lo..lo+11
local function inRange(pc, lo)
    return lo + (pc - lo) % 12
end

-- performance, not composition: a few ms of human timing (a sum of uniforms, roughly Gaussian)
local function humanize(sigma)
    local r = love.math.random
    return (r() + r() + r() - 1.5) * 2 * sigma
end

local function progAdd(prog, degree, quality, beats)
    prog[#prog + 1] = { degree = degree % 12, quality = quality, steps = beats * 4 }
    prog.steps = (prog.steps or 0) + beats * 4
end

-- the last bar of B becomes a ii-V back to the top
local function progTurnaround(prog, minor, fromKey)
    local cut = 16
    while cut > 0 and #prog > 0 do
        local last = prog[#prog]
        if last.steps > cut then
            last.steps, cut = last.steps - cut, 0
        else
            cut = cut - last.steps
            prog[#prog] = nil
        end
    end
    prog.steps = prog.steps - 16
    local home = fromKey and 0 or prog[1].degree -- lofi turns around to the key, the others to A's first chord
    progAdd(prog, home + 2, minor and 'm7b5' or 'm9', 2)
    progAdd(prog, home + 7, minor and 'b9' or 'dom9', 2)
end

local function qualityOf(song, name)
    if song.lydian and name == 'maj9' then name = 'lydian' end
    if song.flavor and song.flavor[name] then name = song.flavor[name] end
    return D.qualities[name]
end

-- A shell: the 3rd, the 7th and one colour on top (the 9th, a lydian's #11, a dom9's 13th; not a
-- colour a semitone from the 3rd or 7th: then the 5th), what a bossa guitarist or a comping piano
-- plays under a tune. A quality without a 3rd or a 7th, or a stacked one, keeps its full voicing.
local shells = setmetatable({}, { __mode = 'k' })
local function shellOf(intervals)
    if intervals.stack then return intervals end
    if shells[intervals] then return shells[intervals] end
    local third, seventh
    for _, i in ipairs(intervals) do
        if i % 12 == 3 or i % 12 == 4 then third = i elseif i % 12 == 10 or i % 12 == 11 then seventh = i end
    end
    local shell = intervals
    if third and seventh then
        local function clear(i)
            for _, g in ipairs({ third, seventh }) do
                local d = (i - g) % 12
                if d == 0 or d == 1 or d == 11 then return false end
            end
            return true
        end
        local colour = 7
        for k = #intervals, 1, -1 do
            if intervals[k] % 12 ~= 0 and clear(intervals[k]) then colour = intervals[k] break end
        end
        shell = { third, seventh, colour }
    end
    shells[intervals] = shell
    return shell
end

-- the intervals the keys voice for a chord: the quality, or its shell in a song that comps in shells
local function voicedQuality(song, chord)
    local intervals = qualityOf(song, chord.quality)
    if song.comping == 'shell' then return shellOf(intervals) end
    return intervals
end

local function chordPcs(song, chord)
    local root = (song.key + chord.degree) % 12
    local pcs = { root }
    for _, interval in ipairs(qualityOf(song, chord.quality)) do pcs[#pcs + 1] = (root + interval) % 12 end
    return pcs
end

-- the chords inside bar b: { degree, quality, s = start step, len = steps }
local function barChords(song, b)
    if b < 1 or b > song.bars then b = math.max(1, math.min(song.bars, b)) end
    local section, j = song.barSection[b], song.barIndex[b]
    -- degrees from the key sounding now: a bar in a lifted section (or out of one) shifts by the difference
    local shift = (section.lift or 0) - (song.lift or 0)
    if section.kind == 'outro' and j >= 2 and not section.prog then -- the outro rings on home
        return { { degree = shift % 12, quality = song.home or D.styles[song.style].home, s = 0, len = 16 } }
    end
    local prog = section.prog or section.kind == 'B' and song.B or song.A
    local b0, at, out = (j * 16) % prog.steps, 0, {}
    for _, chord in ipairs(prog) do
        local cs, ce = at, at + chord.steps
        at = ce
        local s, e = math.max(cs, b0), math.min(ce, b0 + 16)
        if e > s then
            out[#out + 1] = { degree = (chord.degree + shift) % 12, quality = chord.quality, s = s - b0, len = e - s }
        end
    end
    return out
end

local function chordAtStep(song, b, s)
    local chords = barChords(song, b + math.floor(s / 16))
    s = s % 16
    for i = #chords, 1, -1 do
        if s >= chords[i].s then return chords[i] end
    end
    return chords[1]
end

---------------------------------------------------------------------------------------------------
-- The tune

local function isChordTone(song, midi, chord)
    local pc = midi % 12
    for _, chordPc in ipairs(chordPcs(song, chord)) do
        if chordPc == pc or (chordPc + 7) % 12 == pc and chordPc == (song.key + chord.degree) % 12 then return true end
    end
    return false
end

-- an avoid note: a semitone above a chord tone
local function isAvoid(song, midi, chord)
    return not isChordTone(song, midi, chord) and isChordTone(song, midi - 1, chord)
end

-- a semitone from a note the chord holds: fine for a passing 16th, not for a long note
local function rubs(song, midi, chord)
    local root = (song.key + chord.degree) % 12
    for _, interval in ipairs(qualityOf(song, chord.quality)) do
        local d = (midi - root - interval) % 12
        if d == 1 or d == 11 then return true end
    end
    return false
end

local function snapChord(song, li, chord)
    local ladder = song.ladder
    for d = 0, 3 do
        if ladder[li - d] and isChordTone(song, ladder[li - d], chord) then return li - d end
        if ladder[li + d] and isChordTone(song, ladder[li + d], chord) then return li + d end
    end
    return li
end

local function inKey(song, midi)
    return song.scale[(midi - song.key) % 12] == true
end

-- the audio time of 16th step s in a bar starting at t0, swung on the off-beat 8ths
local function stepTime(song, t0, s)
    local beat, sw = song.beat, song.swing
    if song.swing16 then -- lofi's swing: straight 8ths, the off-beat 16ths late
        local sd = beat / 4
        return t0 + s * sd + (s % 2 == 1 and (sw - 0.5) * 2 * sd or 0)
    end
    local r = s % 4
    local off = r == 0 and 0 or r == 1 and sw * beat / 2 or r == 2 and sw * beat or sw * beat + (1 - sw) * beat / 2
    return t0 + math.floor(s / 4) * beat + off
end

-- how long steps s..s+len last, in ms: on the swung grid, not in straight 16ths (a swung off-beat
-- 8th is short, so a straight length rings into the next downbeat)
local function lengthMs(song, s, len)
    return (stepTime(song, 0, s + len) - stepTime(song, 0, s)) * 1000
end

lib.stream = stream
lib.voiceChord = voiceChord
lib.inRange = inRange
lib.humanize = humanize
lib.progAdd = progAdd
lib.progTurnaround = progTurnaround
lib.qualityOf = qualityOf
lib.shellOf = shellOf
lib.voicedQuality = voicedQuality
lib.chordPcs = chordPcs
lib.barChords = barChords
lib.chordAtStep = chordAtStep
lib.isChordTone = isChordTone
lib.isAvoid = isAvoid
lib.rubs = rubs
lib.snapChord = snapChord
lib.inKey = inKey
lib.stepTime = stepTime
lib.lengthMs = lengthMs

return lib
