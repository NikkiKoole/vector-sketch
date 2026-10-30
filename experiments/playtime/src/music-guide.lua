-- music-guide.lua
-- The tune the way the jazz improvisation books teach it: built from each chord, not from the key.
-- Strong and long notes are chord tones, a group of notes starts on a guide tone (the 3rd or the
-- 7th: they say which chord it is, and from one chord to the next they move by a step), the notes
-- in between walk the chord's scale (the key's, bent to the chord's own notes), and a new chord is
-- arrived at by step. The song's motif (music-plan's planTune) gives the rhythm and the contour:
-- stated in bars 1-2, moved over the next chords in bars 3-4. bookTune (src/music-parts.lua) plays
-- it unless music.tune is 'classic'; the notes are music-plan's buildPhrase's { s, midi, len, vol }.

local D = require('src.music-styles')
local theory = require('src.music-theory')
local stream = theory.stream
local chordAtStep = theory.chordAtStep
local chordPcs = theory.chordPcs
local qualityOf = theory.qualityOf

local lib = {}

-- the chord's tones, its guide tones, the tones to land on and its scale, as pitch-class sets
local function chordSets(song, chord)
    local root = (song.key + chord.degree) % 12
    local tones, guides, scale = {}, {}, {}
    for _, pc in ipairs(chordPcs(song, chord)) do tones[pc] = true end
    local third, seventh
    for _, interval in ipairs(qualityOf(song, chord.quality)) do
        local i = interval % 12
        if i == 3 or i == 4 then third = i elseif i == 10 or i == 11 then seventh = i end
    end
    third = third or 5                                   -- a sus chord: the fourth stands in
    seventh = seventh or (tones[(root + 9) % 12] and 9)  -- a sixth chord: the sixth stands in
    -- the notes to land on: the chord's tones, less one a semitone from another. The keys voice the
    -- 9ths, so on a m9 the 9th sits right under the minor 3rd and on a maj9 the root over the 7th:
    -- a long note there rubs the voicing. A guide tone that rubs gives way to the other one.
    local lands = {}
    for pc in pairs(tones) do
        if not tones[(pc + 1) % 12] and not tones[(pc + 11) % 12] then lands[pc] = true end
    end
    for _, i in ipairs({ third, seventh }) do
        if i and lands[(root + i) % 12] then guides[(root + i) % 12] = true end
    end
    if next(guides) == nil then guides = lands end
    -- the walk: the key's scale, where a key note a semitone from a chord tone gives way to it (over
    -- the II7 the raised fourth, over the iv the flat sixth; the avoid notes drop out), and only the
    -- chord tones that land: even passing, the others ring a flat ninth against the voicing
    for pc = 0, 11 do
        local inKey = song.scale[(pc - song.key) % 12]
        if lands[pc] or inKey and not tones[(pc + 1) % 12] and not tones[(pc + 11) % 12] then scale[pc] = true end
    end
    return { tones = tones, guides = guides, lands = lands, scale = scale }
end

-- the note of the set nearest to midi in lo..hi (below first, the calmer way), not `except`
local function nearest(set, midi, lo, hi, except)
    midi = math.max(lo, math.min(hi, midi))
    for d = 0, 12 do
        local down, up = midi - d, midi + d
        if down >= lo and down ~= except and set[down % 12] then return down end
        if up <= hi and up ~= except and set[up % 12] then return up end
    end
    return midi
end

-- the next note of the set from midi going dir (-1, 0, 1); turns back at the range's edge
local function step(set, midi, dir, lo, hi)
    if dir == 0 then return midi end
    for _ = 1, 2 do
        local m = midi + dir
        while m >= lo and m <= hi and not set[m % 12] do m = m + dir end
        if m >= lo and m <= hi then return m end
        dir = -dir
    end
    return midi
end

local function sameChord(a, b)
    return a.degree == b.degree and a.quality == b.quality
end

-- The 4-bar phrase starting at bar b
function lib.buildPhrase(song, b)
    local section, j = song.barSection[b], song.barIndex[b]
    local slot = math.floor(j / 4)
    local rnd = stream(song.seed, 7000 + (section.kind == 'B' and 100 or 0) + slot)
    local style = D.styles[song.style]
    if slot % 2 == 1 and rnd(100) < 30 then return {} end -- a phrase of space
    local range = style.range or { 67, 86 }
    local lo, hi = range[1], range[2]
    local at = section.guideLast -- where the last phrase left off; a section starts mid-range, B higher
    if slot == 0 or not at then at = math.floor((lo + hi) / 2) + (section.kind == 'B' and 4 or -2) end

    local motif, notes = song.motif, {}
    for half = 0, 1 do -- the call in bars 1-2, the answer (the same motif over the next chords) in 3-4
        local last = #motif.steps
        if half == 1 and rnd(100) < 40 then -- the answer leaves out its last group: room to breathe
            local group = motif.groups[last]
            while last > 1 and motif.groups[last] == group do last = last - 1 end
        end
        for i = 1, last do
            local s = motif.steps[i] + 32 * half
            local chord = chordAtStep(song, b, s)
            local sets = chordSets(song, chord)
            local first = i == 1 or motif.groups[i] ~= motif.groups[i - 1]
            if first then at = nearest(sets.guides, at, lo, hi, at) -- the nearest other guide tone
            else at = step(sets.scale, at, motif.dir[i], lo, hi) end
            if s % 8 == 0 then at = nearest(sets.lands, at, lo, hi) end -- beats 1 and 3: a chord tone
            notes[#notes + 1] = { s = s, midi = at, vol = first and 5 or 4, chord = chord, sets = sets }
        end
    end

    -- each note lasts to the next (the last rings); a long note is a chord tone
    for k, note in ipairs(notes) do
        local nextNote = notes[k + 1]
        note.len = math.min((nextNote and nextNote.s or 64) - note.s, nextNote and (style.staccato or 6) or 10)
        if note.len >= 4 then note.midi = nearest(note.sets.lands, note.midi, lo, hi) end
    end
    -- a new chord is arrived at by step: the note before the change, if it's short and not a group's
    -- start, becomes a scale step above the arrival or a half step below it
    for k = 1, #notes - 1 do
        local note, arrival = notes[k], notes[k + 1]
        if note.vol < 5 and arrival.s - note.s <= 4 and not sameChord(note.chord, arrival.chord) then
            local below, tones = arrival.midi - 1, note.sets.tones -- the half step below, if it doesn't
            local rubs = not tones[below % 12] and (tones[(below + 1) % 12] or tones[(below + 11) % 12])
            if rnd(100) < 50 or rubs then note.midi = step(note.sets.scale, arrival.midi, 1, lo, hi)
            else note.midi = below end -- rub the chord it sounds over
            note.vol = 3
        end
    end
    for _, note in ipairs(notes) do note.chord, note.sets = nil, nil end
    section.guideLast = #notes > 0 and notes[#notes].midi or section.guideLast
    return notes
end

lib.chordSets = chordSets
lib.nearest = nearest
lib.step = step

return lib
