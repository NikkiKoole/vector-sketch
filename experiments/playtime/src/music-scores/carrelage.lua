-- carrelage: Erik Satie, Carrelage phonique, Musique d'ameublement (1917), transcribed by hand
-- (2026-11-02) from the typeset score by Joâo Schnier (IMSLP #570627, 2019, dedicated to the public
-- domain), in concert pitch (the clarinet in B♭ sounds a tone below what's written).
-- Four bars of 2/4, made to repeat without end. Per bar: { step in 16ths, midi, len in 16ths, part,
-- velocity }; parts fl vn1 vn2 va vc cl (the style gives each its patch and role). f throughout;
-- an accent is velocity 102, the rest 90.
local function line(notes, shift, part)
    local out = {}
    for _, n in ipairs(notes) do out[#out + 1] = { n[1], n[2] + shift, n[3], part, n[4] or 90 } end
    return out
end
local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do for _, n in ipairs(list) do out[#out + 1] = n end end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

-- the tune (flute; the first violin an octave down, viola and cello two): B held, A B up to it,
-- then the octave leaps, staccato
local tuneA = { { 0, 83, 6, 102 }, { 6, 81, 1 }, { 7, 83, 1 } }
local tune2 = { { 0, 86, 1 }, { 2, 74, 1 }, { 4, 86, 1 }, { 6, 74, 1 } }
local tune4 = { { 0, 83, 1 }, { 2, 71, 1 }, { 4, 83, 1 }, { 6, 71, 1 } }
-- the running eighths (second violin; the clarinet an octave down), slurred
local run1 = { { 0, 66, 2 }, { 2, 64, 2 }, { 4, 66, 2 }, { 6, 62, 2 } }
local run2 = { { 0, 67, 2 }, { 2, 69, 2 }, { 4, 71, 2 }, { 6, 67, 2 } }
local run4 = { { 0, 67, 2 }, { 2, 66, 2 }, { 4, 64, 2 }, { 6, 67, 2 } }
local violaBar4 = { { 0, 59, 1 }, { 2, 59, 1 }, { 4, 59, 1 }, { 6, 59, 1 } } -- B, four times

local function bar(tune, run, viola)
    return join(line(tune, 0, 'fl'), line(tune, -12, 'vn1'), line(viola or tune, viola and 0 or -24, 'va'),
        line(tune, -24, 'vc'), line(run, 0, 'vn2'), line(run, -12, 'cl'))
end

return { key = 7, meter = 2, velocity = 90, bars = {
    [1] = bar(tuneA, run1),
    [2] = bar(tune2, run2),
    [3] = bar(tuneA, run1),
    [4] = bar(tune4, run4, violaBar4),
} }
