-- music.lua
-- Background music on a Rhodes, played rather than stamped. Two styles:
--   bossa  - straight eighths at 116, the piano comping short chords on the bossa clave, a bass
--            on root and fifth (1 and the and-of-2), kick under it, cross-stick rim on the clave,
--            a quiet shaker
--   ballad - slow (76): each chord drifts in note by note, fingers lift at their own time, a
--            little melody moves inside the chord
-- Harmony and voicing follow dreamengine's lofi.c: four-voice rootless voicings that move least
-- and never stack a minor ninth.
--
-- The arrangement follows the play: calm, the Rhodes plays alone and its left hand takes the
-- bass; busy (impacts call music.bump), the rhythm section joins (the drums in bossa; the upright
-- too when lib.upright is on, and then the left hand lifts). rhythmSection forces it on or off.
-- It only changes at a chord change. lib.chordNotes lets sound effects play in the current
-- chord. Notes are booked ahead on the synth's audio clock, so frame hitches don't shake the
-- groove. Driven by mipo-voice.update while synth impacts are on.

local state = require('src.state')

local lib = {}

lib.enabled = true
lib.style = 'bossa'          -- 'bossa' or 'ballad' (lib.styles)
lib.rhythmSection = 'auto'   -- 'auto' (joins when play gets busy), 'on' or 'off'
lib.upright = false          -- the upright in the rhythm section; off: the Rhodes' left hand keeps the bass
lib.melody = true            -- a little tune on top: a motif, then its answer
lib.melodyPatch = 'rhodesLead' -- the tune's voice: rhodesLead, kalimba, kalimbaPlonk, celesta (src/synth.lua)
lib.melodyRest = 0.25        -- chance a phrase rests (the first of each four always plays)
lib.lydianChance = 0.6       -- a song's major chords get the raised fourth (maj7#11): floaty, a bit magical
lib.sidestepChance = 0.25    -- a chord's last stab slides into the next chord from a half-step above
lib.lookahead = 0.3          -- seconds of music booked ahead
lib.chordsPerSong = 16       -- then a new loop in a new key
lib.activityHalfLife = 8     -- seconds for the play level to halve
lib.bandJoins = 4            -- play level at which the rhythm section comes in...
lib.bandLeaves = 1.5         -- ...and below which it leaves again

lib.keys = { 5, 10, 3, 8 }   -- F, Bb, Eb, Ab: warm Rhodes keys
-- lofi.c's qualities (rootless: the bass owns the root)
lib.qualities = { maj9 = { 4, 7, 11, 14 }, m9 = { 3, 7, 10, 14 }, dom9 = { 4, 10, 14, 21 },
                  maj7 = { 4, 7, 11, 12 }, m7 = { 3, 7, 10, 12 },
                  lydian = { 4, 11, 14, 18 } } -- maj9#11: third, seventh, ninth, raised fourth
-- the melody's rhythm cells, in eighth steps within one bar; a song picks one as its motif
lib.melodyCells = { { 0, 2, 3, 6 }, { 1, 3, 4, 7 }, { 0, 3, 5 }, { 2, 3, 4, 6 }, { 0, 1, 3, 5, 6 } }
-- loops: { degree from the key, quality } per chord
lib.styles = {
    bossa = {
        bpm = 116, barsPerChord = { 2 },
        loops = {
            { { 0, 'maj9' }, { 2, 'dom9' }, { 2, 'm9' }, { 7, 'dom9' } },   -- Imaj7 II7 iim7 V7 (Ipanema)
            { { 0, 'maj9' }, { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' } },     -- I vi ii V
            { { 0, 'maj9' }, { 5, 'm9' }, { 0, 'maj9' }, { 10, 'dom9' } },  -- I ivm I bVII7, the dreamy one
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 9, 'dom9' } },   -- ii V I VI7
            { { 0, 'maj9' }, { 1, 'maj9' } },                               -- I bIImaj7, the half-step float
        },
        -- the piano's comp over two bars, in eighth steps (0..15); the clave is the first
        comps = { { 0, 3, 6, 10, 13 }, { 0, 3, 7, 10, 12 }, { 2, 5, 8, 10, 13 } },
        clave = { 0, 3, 6, 10, 13 },
    },
    ballad = {
        bpm = 76, barsPerChord = { 1, 2 },
        loops = {
            { { 0, 'maj9' }, { 9, 'm9' } },                                 -- Imaj9 vi9
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 0, 'maj9' } },   -- ii V I
            { { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' } },     -- vi ii V I
            { { 0, 'maj9' }, { 5, 'm7' }, { 8, 'dom9' }, { 0, 'maj9' } },   -- the jazzy loop
            { { 5, 'maj9' }, { 5, 'm9' }, { 0, 'maj9' }, { 9, 'm9' } },     -- IV iv I vi, the sigh
        },
    },
}

-- On `state` so a hot reload keeps the song going where it was.
state.music = state.music or { activity = 0, withBand = false, chordsLeft = 0 }
local M = state.music
M.booked = M.booked or {} -- the last few booked chords: { at = audio time, pcs = { pitch classes } }

-- Gameplay calls this (impacts); enough of it brings the rhythm section in.
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

local function currentStyle()
    return lib.styles[lib.style] or lib.styles.bossa
end

local function newSong()
    local style = currentStyle()
    M.style = lib.style
    M.key = lib.keys[love.math.random(#lib.keys)]
    M.loop = style.loops[love.math.random(#style.loops)]
    M.barsPerChord = style.barsPerChord[love.math.random(#style.barsPerChord)]
    M.chordIndex = 0
    M.chordsLeft = lib.chordsPerSong
    M.lydian = love.math.random() < lib.lydianChance
    M.cell = lib.melodyCells[love.math.random(#lib.melodyCells)]
    M.phrase = 0
end

-- MIDI note of pitch class pc in lo..lo+11
local function inRange(pc, lo)
    return lo + (pc - lo) % 12
end

-- a few milliseconds of human timing
local function humanize()
    return (love.math.random() - 0.5) * 0.012
end

local function bandPlays()
    if lib.rhythmSection == 'on' then return true end
    if lib.rhythmSection == 'off' then return false end
    if M.withBand and M.activity < lib.bandLeaves then M.withBand = false end
    if not M.withBand and M.activity > lib.bandJoins then M.withBand = true end
    return M.withBand
end

-- Ballad: the chord drifts in, the left hand (or the upright) holds the root.
local function bookBallad(synth, t0, chord)
    local beat, chordLength, v = chord.beat, chord.length, chord.voicing
    local barLength = 4 * beat
    if chord.band and lib.upright then
        -- the upright: root on 1, fifth on 3 of every bar, walking into the next root from a half-step
        local root = inRange(chord.rootPc, 34)
        for bar = 0, M.barsPerChord - 1 do
            local tb = t0 + bar * barLength
            synth.scheduleAt('musicBass', tb, root, 6, 500)
            synth.scheduleAt('musicBass', tb + 2 * beat, root + 7, 5, 500)
        end
        local nextRoot = inRange(chord.nextRootPc, 34)
        if nextRoot ~= root and love.math.random() < 0.6 then
            local approach = nextRoot + (love.math.random() < 0.5 and 1 or -1)
            synth.scheduleAt('musicBass', t0 + chordLength - beat * 0.38, approach, 4, 200)
        end
    else
        -- alone, the Rhodes' left hand plays the root low and holds it
        synth.scheduleAt('rhodes', t0, inRange(chord.rootPc, 40), 5, chordLength * 1000)
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
end

-- Bossa: short comped chords on a two-bar pattern; the bass (or the left hand) on root and fifth.
local function bookBossa(synth, t0, chord)
    local style = currentStyle()
    local beat, chordLength, v = chord.beat, chord.length, chord.voicing
    local eighth = beat / 2
    local steps = math.floor(chordLength / eighth + 0.5)

    -- the bass rhythm, every bar: root on 1 (a dotted quarter), fifth on the and-of-2, held over 3
    for bar = 0, steps / 8 - 1 do
        local tb = t0 + bar * 8 * eighth
        if chord.band and lib.upright then
            local root = inRange(chord.rootPc, 34)
            synth.scheduleAt('musicBass', tb + humanize(), root, 6, eighth * 2.8 * 1000)
            synth.scheduleAt('musicBass', tb + 3 * eighth + humanize(), root + 7, 5, eighth * 4.8 * 1000)
        else
            local root = inRange(chord.rootPc, 40)
            synth.scheduleAt('rhodes', tb + humanize(), root, 4, eighth * 2.8 * 1000)
            synth.scheduleAt('rhodes', tb + 3 * eighth + humanize(), root + 7, 3, eighth * 4.8 * 1000)
        end
        if chord.band then
            synth.scheduleAt('kick', tb, 36, 4, 150)
            synth.scheduleAt('kick', tb + 3 * eighth, 36, 3, 150)
            for step = 0, 7 do -- the shaker: every eighth, the off-beats leaning
                synth.scheduleAt('shaker', tb + step * eighth + humanize(), 84, step % 2 == 1 and 3 or 2, 40)
            end
        end
    end
    if chord.band then -- the cross-stick on the clave
        for _, step in ipairs(style.clave) do
            if step < steps then synth.scheduleAt('rim', t0 + step * eighth + humanize(), 79, 4, 40) end
        end
    end

    -- the right hand comps: short chords, a quick roll, now and then lighter (the bottom note left out)
    local comp = style.comps[love.math.random(#style.comps)]
    -- the side-step: the last stab is the NEXT chord a half-step high, sliding down into it
    local sidestep
    if chord.nextRootPc ~= chord.rootPc and love.math.random() < lib.sidestepChance then
        sidestep = voiceChord(chord.nextRootPc, chord.nextQuality, 48, 76, v)
    end
    for i, step in ipairs(comp) do
        if step < steps then
            local t = t0 + step * eighth + humanize()
            local light = i > 1 and love.math.random() < 0.35
            local hitVoicing = (sidestep and i == #comp) and sidestep or v
            for k = light and 2 or 1, #hitVoicing do
                local note = hitVoicing[k] + (hitVoicing == sidestep and 1 or 0)
                -- the last hit sometimes lets the top note step down to the next chord tone
                if hitVoicing == v and k == #v and i == #comp and love.math.random() < 0.4 then
                    note = v[#v - 1] + 12 <= v[#v] + 5 and v[#v - 1] + 12 or v[#v] - 2
                end
                synth.scheduleAt('rhodes', t + (k - 1) * 0.008, note, k == #hitVoicing and 5 or 4, eighth * 1.3 * 1000)
            end
        end
    end
end

-- The celesta: the song's rhythm cell as a motif (odd phrases, first bar), answered a bar later
-- with the contour turned around (even phrases). Chord notes only, mostly steps between
-- neighbours, now and then a grace note from a half-step below.
local function bookMelody(synth, t0, chord)
    M.phrase = (M.phrase or 0) + 1
    local answer = M.phrase % 2 == 0
    if M.phrase % 4 ~= 1 and love.math.random() < lib.melodyRest then return end
    local notes = {}
    local inChord = {}
    for _, pc in ipairs(chord.pcs) do inChord[pc] = true end
    for midi = 72, 91 do
        if inChord[midi % 12] then notes[#notes + 1] = midi end
    end
    -- start on the chord note nearest to where the tune last was
    local index, nearest = 1, math.huge
    for i, note in ipairs(notes) do
        local d = math.abs(note - (M.melodyNote or 79))
        if d < nearest then index, nearest = i, d end
    end
    local eighth = chord.beat / 2
    local steps = math.floor(chord.length / eighth + 0.5)
    local offset = (answer and steps >= 16) and 8 or 0 -- the answer comes in the second bar (if there is one)
    local direction = answer and -(M.melodyDirection or 1) or (love.math.random() < 0.5 and 1 or -1)
    M.melodyDirection = direction
    local cell = M.cell or lib.melodyCells[1]
    for i, step in ipairs(cell) do
        if i > 1 then
            index = index + direction * (love.math.random() < 0.75 and 1 or 2)
            if index < 1 or index > #notes then
                direction = -direction
                index = math.max(1, math.min(#notes, index + 2 * direction))
            end
            if love.math.random() < 0.2 then direction = -direction end
        end
        local note = notes[index]
        local t = t0 + (offset + step) * eighth + humanize()
        if love.math.random() < 0.2 then synth.scheduleAt(lib.melodyPatch, t - 0.05, note - 1, 3, 45) end -- grace note
        local length = (i == #cell) and eighth * 3 or eighth * 1.2
        synth.scheduleAt(lib.melodyPatch, t, note, i == 1 and 5 or 4, length * 1000)
        M.melodyNote = note
    end
end

-- Books one chord starting at audio time t0; returns its length in seconds.
local function bookChord(synth, t0)
    if not M.loop or M.chordsLeft <= 0 or M.style ~= lib.style then newSong() end
    M.chordIndex = M.chordIndex % #M.loop + 1
    M.chordsLeft = M.chordsLeft - 1

    local style = currentStyle()
    local beat = 60 / style.bpm
    local loopChord = M.loop[M.chordIndex]
    local rootPc = (M.key + loopChord[1]) % 12
    local quality = lib.qualities[(M.lydian and loopChord[2] == 'maj9') and 'lydian' or loopChord[2]]
    local nextLoopChord = M.loop[M.chordIndex % #M.loop + 1]
    local nextQuality = lib.qualities[(M.lydian and nextLoopChord[2] == 'maj9') and 'lydian' or nextLoopChord[2]]
    local chord = {
        beat = beat,
        length = M.barsPerChord * 4 * beat,
        rootPc = rootPc,
        nextRootPc = (M.key + nextLoopChord[1]) % 12,
        nextQuality = nextQuality,
        band = bandPlays(),
    }
    chord.voicing = voiceChord(rootPc, quality, 48, 76, M.voicing)
    M.voicing = chord.voicing

    local pcs = { rootPc }
    for _, interval in ipairs(quality) do pcs[#pcs + 1] = (rootPc + interval) % 12 end
    chord.pcs = pcs
    table.insert(M.booked, { at = t0, pcs = pcs })
    if #M.booked > 3 then table.remove(M.booked, 1) end

    if lib.style == 'ballad' then bookBallad(synth, t0, chord) else bookBossa(synth, t0, chord) end
    if lib.melody then bookMelody(synth, t0, chord) end
    return chord.length
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
