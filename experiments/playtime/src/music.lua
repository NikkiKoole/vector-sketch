-- music.lua
-- Background music: a sleepy Rhodes, played rather than stamped (each chord drifts in note by
-- note, fingers lift at their own time, a little melody inside the chord). Harmony and voicing
-- follow dreamengine's lofi.c: its loops, its four-voice rootless voicings that move least and
-- never stack a minor ninth.
--
-- The arrangement follows the play: calm, the Rhodes plays alone and its left hand takes the
-- bass; busy (impacts call music.bump), an upright joins and the left hand lifts. It only
-- changes at a chord change. lib.chordNotes lets sound effects play in the current chord.
-- Notes are booked ahead on the synth's audio clock, so frame hitches
-- don't shake the groove. Driven by mipo-voice.update while synth impacts are on.

local state = require('src.state')

local lib = {}

lib.enabled = true
lib.bpm = 76
lib.lookahead = 0.3          -- seconds of music booked ahead
lib.chordsPerSong = 16       -- then a new loop in a new key
lib.activityHalfLife = 8     -- seconds for the play level to halve
lib.bassJoins = 4            -- play level at which the upright comes in...
lib.bassLeaves = 1.5         -- ...and below which it leaves again

lib.keys = { 5, 10, 3, 8 }   -- F, Bb, Eb, Ab: warm Rhodes keys
-- lofi.c's qualities (rootless: the bass owns the root) and loops (degree from the key, quality)
lib.qualities = { maj9 = { 4, 7, 11, 14 }, m9 = { 3, 7, 10, 14 }, dom9 = { 4, 10, 14, 21 },
                  maj7 = { 4, 7, 11, 12 }, m7 = { 3, 7, 10, 12 } }
lib.loops = {
    { { 0, 'maj9' }, { 9, 'm9' } },                                 -- Imaj9 vi9
    { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 0, 'maj9' } },   -- ii V I
    { { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' } },     -- vi ii V I
    { { 0, 'maj9' }, { 5, 'm7' }, { 8, 'dom9' }, { 0, 'maj9' } },   -- the jazzy loop
    { { 5, 'maj9' }, { 5, 'm9' }, { 0, 'maj9' }, { 9, 'm9' } },     -- IV iv I vi, the sigh
}

-- On `state` so a hot reload keeps the song going where it was.
state.music = state.music or { activity = 0, withBass = false, chordsLeft = 0 }
local M = state.music
M.booked = M.booked or {} -- the last few booked chords: { at = audio time, pcs = { pitch classes } }

-- Gameplay calls this (impacts); enough of it brings the upright in.
function lib.bump(amount)
    M.activity = M.activity + (amount or 1)
end

-- lofi.c's lead_to4: every rotation and drop-2 of the chord in every octave, bottom note in
-- lo..lo+12, top at most hi, no minor ninth between any two notes, no low clusters; the one that
-- moves least from the previous voicing (top-voice leaps over 4 cost extra), pulled toward 62.
local function voiceChord(rootPc, intervals, lo, hi, previous)
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
                            if d == 13 or d == 25 then bad = true end
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

local function newSong()
    M.key = lib.keys[love.math.random(#lib.keys)]
    M.loop = lib.loops[love.math.random(#lib.loops)]
    M.barsPerChord = love.math.random() < 0.5 and 1 or 2
    M.chordIndex = 0
    M.chordsLeft = lib.chordsPerSong
end

-- MIDI note of pitch class pc in lo..lo+11
local function inRange(pc, lo)
    return lo + (pc - lo) % 12
end

-- Books one chord starting at audio time t0; returns its length in seconds.
local function bookChord(synth, t0)
    if not M.loop or M.chordsLeft <= 0 then newSong() end
    M.chordIndex = M.chordIndex % #M.loop + 1
    M.chordsLeft = M.chordsLeft - 1
    if M.withBass and M.activity < lib.bassLeaves then M.withBass = false end
    if not M.withBass and M.activity > lib.bassJoins then M.withBass = true end

    local beat = 60 / lib.bpm
    local barLength = 4 * beat
    local chordLength = M.barsPerChord * barLength
    local chord = M.loop[M.chordIndex]
    local nextChord = M.loop[M.chordIndex % #M.loop + 1]
    local rootPc = (M.key + chord[1]) % 12
    local v = voiceChord(rootPc, lib.qualities[chord[2]], 48, 76, M.voicing)
    M.voicing = v
    local pcs = { rootPc }
    for _, interval in ipairs(lib.qualities[chord[2]]) do pcs[#pcs + 1] = (rootPc + interval) % 12 end
    table.insert(M.booked, { at = t0, pcs = pcs })
    if #M.booked > 3 then table.remove(M.booked, 1) end

    if M.withBass then
        -- the upright: root on 1, fifth on 3 of every bar, walking into the next root from a half-step
        local root = inRange(rootPc, 34)
        for bar = 0, M.barsPerChord - 1 do
            local tb = t0 + bar * barLength
            synth.scheduleAt('musicBass', tb, root, 6, 500)
            synth.scheduleAt('musicBass', tb + 2 * beat, root + 7, 5, 500)
        end
        local nextRoot = inRange((M.key + nextChord[1]) % 12, 34)
        if nextRoot ~= root and love.math.random() < 0.6 then
            local approach = nextRoot + (love.math.random() < 0.5 and 1 or -1)
            synth.scheduleAt('musicBass', t0 + chordLength - beat * 0.38, approach, 4, 200)
        end
    else
        -- alone, the Rhodes' left hand plays the root low and holds it
        synth.scheduleAt('rhodes', t0, inRange(rootPc, 40), 5, chordLength * 1000)
    end

    -- the right hand comes just after: the notes drift in one by one, not always bottom-up
    local rh = t0 + 0.12 * beat
    local order = { 1 }
    local rest = {}
    for k = 2, #v do rest[#rest + 1] = k end
    if love.math.random() < 0.5 then
        for i = #rest, 2, -1 do
            local j = love.math.random(i)
            rest[i], rest[j] = rest[j], rest[i]
        end
    end
    for _, k in ipairs(rest) do order[#order + 1] = k end
    local spread = (0.25 + love.math.random() * 0.5) * beat
    for i, k in ipairs(order) do
        local t = rh + (i - 1) / (#order - 1) * spread + (love.math.random() - 0.5) * 0.02
        local hold = chordLength * (0.55 + love.math.random() * 0.45) - (t - t0) -- some fingers lift early
        local vol = (k == #v) and 5 or (love.math.random() < 0.3 and 3 or 4)
        synth.scheduleAt('rhodes', t, v[k], vol, hold * 1000)
    end
    -- a little melody inside the chord: the top note again, or a step down to the next chord tone
    if love.math.random() < 0.6 then
        local t = t0 + (1.5 + love.math.random(0, 2)) * beat
        local top = v[#v]
        local note = top
        if love.math.random() < 0.5 then note = v[#v - 1] + 12 <= top + 5 and v[#v - 1] + 12 or top - 2 end
        synth.scheduleAt('rhodes', t, note, 4, (chordLength - (t - t0)) * 800)
    end
    return chordLength
end

-- The notes from lo to hi (MIDI) that belong to the chord sounding right now, low to high, so
-- sound effects can play along. nil when the music is off or hasn't started.
function lib.chordNotes(lo, hi)
    if not (lib.enabled and M.audioTime) then return nil end
    local sounding
    for _, chord in ipairs(M.booked) do
        if chord.at <= M.audioTime then sounding = chord end
    end
    sounding = sounding or M.booked[1]
    if not sounding then return nil end
    local inChord = {}
    for _, pc in ipairs(sounding.pcs) do inChord[pc] = true end
    local notes = {}
    for midi = lo, hi do
        if inChord[midi % 12] then notes[#notes + 1] = midi end
    end
    return #notes > 0 and notes or nil
end

function lib.update(synth, now)
    if M.lastNow then M.activity = M.activity * 0.5 ^ ((now - M.lastNow) / lib.activityHalfLife) end
    M.lastNow = now
    if not lib.enabled then return end
    local t = synth.audioTime()
    if not t then return end
    M.audioTime = t
    -- first call, or back from a pause: start fresh a moment from now
    if not M.chordAt or M.chordAt < t then M.chordAt = t + 0.2 end
    while M.chordAt < t + lib.lookahead do
        M.chordAt = M.chordAt + bookChord(synth, M.chordAt)
    end
end

return lib
