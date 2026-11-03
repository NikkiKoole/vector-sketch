-- Bass riffs for the drum jam (J8, docs/DRUM-JAM.md): a short PHRASE and how it changes each time it comes
-- round, the way real bass lines are built (one bar played three times, the fourth ending differently so
-- it leads into the next root). Pure: no LÖVE, no other modules (spec/music-riffs_spec.lua).
--
-- A riff:
--   phrase  16 steps (16ths) in the jam's degrees (src/music-jam.lua: R m 4 5 7 8 L ..., A the approach,
--           N the push, '-' hold, '.' rest). A shorter phrase repeats to fill the bar.
--   vars    variations by letter: an OVERLAY on the phrase, 16 steps where a space keeps the phrase's step
--           and anything else replaces it ('.' too: a variation can take a note out).
--   form    the bars as letters, 'A' = the phrase as written: 'AAAB'. It lines up with the END of the
--           root's step, so the last letter is the bar before the root moves (the ending leads into the
--           change); a step shorter than the form plays its tail (2 bars of 'AAAB' = 'AB'), a longer one
--           plays the first letter until the form fits.
--   scale   the notes the riff keeps to, over the moving root (an option; 'pentatonic' by default: the
--           jam has no chords, only a root that walks, and the minor pentatonic is the scale that sits on
--           any of its roots). Notes outside it are fine on the off-16ths and as A / N (passing notes);
--           lib.check finds the rest.
--   follow  (pentatonic riffs, true unless false) the riff FOLLOWS THE CHORD under it (J9): written in the
--           minor pentatonic, it plays each note in the same place on the chord's own pentatonic (over
--           a major chord R m 4 5 7 becomes R 2 3 5 6, over a dominant R 2 3 5 b7). Written once, it fits
--           1 5 6 4's minor 6 and its major 1 and 4 alike. Other scales keep their own sound.
local lib = {}

-- semitones over the root
lib.SCALES = {
    pentatonic = { 0, 3, 5, 7, 10 },
    blues = { 0, 3, 5, 6, 7, 10 }, -- the pentatonic + the b5 (the blue note, passed through)
    dorian = { 0, 2, 3, 5, 7, 9, 10 }, -- the bright minor of disco and funk (the major 6th)
    mixolydian = { 0, 2, 4, 5, 7, 9, 10 }, -- major with a b7 (rock, soul); wants chords to follow (later)
}
lib.DEFAULT_SCALE = 'pentatonic'

-- the jam's degree letters (src/music-jam.lua reads them from here)
lib.DEGREE = { R = 0, ['2'] = 2, m = 3, ['3'] = 4, ['4'] = 5, b = 6, ['5'] = 7, ['6'] = 9, ['7'] = 10,
               ['8'] = 12, L = -5 }

-- Pentatonic riffs to start with (Nikki 2026-11-03: "lets start pentatonic"). Busier than the jam's
-- figures on purpose: those keep to 1-3 notes so the root moving is heard; these are picked in the panel.
lib.RIFFS = {
    { name = 'pocket', phrase = 'R..R..7.R.....5.',
      vars = { B = '            8.7A' }, form = 'AAAB' },
    { name = 'climb', phrase = 'R.....m.4.5.7...',
      vars = { B = '          8.7.5.', C = '          8.5.mA' }, form = 'ABAC' },
    { name = 'call and answer', phrase = 'R..8..R.....5.7.',
      vars = { B = '        7.5.4.mA' }, form = 'AAAB' },
    { name = 'low and high', phrase = 'R...L...R..m4...',
      vars = { B = '        R..m5.N.' }, form = 'AAAB' },
}

-- a chord kind's pentatonic (the walks' `kinds` in src/music-jam.lua): m minor, M major, 7 dominant
lib.CHORD_SCALES = {
    m = { 0, 3, 5, 7, 10 },
    M = { 0, 2, 4, 7, 9 },
    ['7'] = { 0, 2, 4, 7, 10 },
}

-- letter -> semitones for this riff over a chord of `kind`: the jam's DEGREE, with the minor pentatonic's
-- notes moved to their place on the chord's pentatonic when the riff follows the chord.
function lib.degrees(riff, kind)
    local follows = (riff.scale or lib.DEFAULT_SCALE) == 'pentatonic' and riff.follow ~= false
    local shape = follows and lib.CHORD_SCALES[kind]
    if not shape then return lib.DEGREE end
    local out = {}
    for c, d in pairs(lib.DEGREE) do out[c] = d end
    local minor = lib.CHORD_SCALES.m
    for c, d in pairs(lib.DEGREE) do
        for k = 2, #minor do
            if d == minor[k] then out[c] = shape[k] end
        end
    end
    return out
end

function lib.scaleOf(riff) return lib.SCALES[riff.scale or lib.DEFAULT_SCALE] end

local function fill16(s)
    if #s >= 16 then return s:sub(1, 16) end
    local out = s
    while #out < 16 do out = out .. s end
    return out:sub(1, 16)
end

-- One bar of the riff with variation `letter` laid over it.
function lib.barWith(riff, letter)
    local bar = fill16(riff.phrase)
    local over = letter ~= 'A' and riff.vars and riff.vars[letter]
    if not over then return bar end
    local out = {}
    for s = 1, 16 do
        local c = over:sub(s, s)
        out[s] = (c ~= '' and c ~= ' ') and c or bar:sub(s, s)
    end
    return table.concat(out)
end

-- The letter for a bar, from how many bars are left on the root's step (1 = the bar before it moves).
function lib.letter(riff, barsLeft)
    local form = riff.form or 'A'
    local k = math.max(1, #form - (barsLeft - 1))
    return form:sub(k, k)
end

function lib.bar(riff, barsLeft) return lib.barWith(riff, lib.letter(riff, barsLeft)) end

-- Notes outside the riff's scale on a beat's strong 16ths (steps 1 and 3 of each beat): { {letter, step, c} }.
function lib.check(riff)
    local inScale = {}
    for _, d in ipairs(lib.scaleOf(riff)) do inScale[d] = true end
    local bad = {}
    local letters = { 'A' }
    for letter in pairs(riff.vars or {}) do letters[#letters + 1] = letter end
    for _, letter in ipairs(letters) do
        local bar = lib.barWith(riff, letter)
        for s = 1, 16 do
            local d = lib.DEGREE[bar:sub(s, s)]
            if d and s % 2 == 1 and not inScale[d % 12] then bad[#bad + 1] = { letter, s, bar:sub(s, s) } end
        end
    end
    return bad
end

return lib
