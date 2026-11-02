-- tapisserie: Erik Satie, Tapisserie en fer forgé, Musique d'ameublement (1917), transcribed by hand
-- (2026-11-02) from the typeset score by Joâo Schnier (IMSLP #570626, 2019, dedicated to the public
-- domain), in concert pitch (the clarinet in B♭ sounds a tone below what's written).
-- Four bars of 6/8 (12 16ths), made to repeat without end. Per bar: { step in 16ths, midi, len in
-- 16ths, part, velocity }; parts fl tp cl vn va vc (both violin parts play the same notes: one part).
-- f throughout; the winds' accented quarters are velocity 102, the rest 90.
local function line(notes, part)
    local out = {}
    for _, n in ipairs(notes) do out[#out + 1] = { n[1], n[2], n[3], part, n[4] or 90 } end
    return out
end
local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do for _, n in ipairs(list) do out[#out + 1] = n end end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end
-- the winds' call: a staccato eighth up to an accented quarter, twice
local function call(low, high) return { { 0, low, 1 }, { 2, high, 4, 102 }, { 6, low, 1 }, { 8, high, 4, 102 } } end
local function up(notes, shift)
    local out = {}
    for _, n in ipairs(notes) do out[#out + 1] = { n[1], n[2] + shift, n[3], n[4] } end
    return out
end

local violins = {
    { { 0, 55, 2 }, { 2, 62, 4 }, { 6, 59, 2 }, { 8, 57, 4 } },  -- G D, B A
    { { 0, 55, 2 }, { 2, 57, 4 }, { 6, 55, 2 }, { 8, 57, 4 } },  -- G A, G A
    { { 0, 55, 2 }, { 2, 62, 4 }, { 6, 64, 2 }, { 8, 62, 4 } },  -- G D, E D
    { { 0, 60, 2 }, { 2, 62, 4 }, { 6, 60, 2 }, { 8, 62, 4 } },  -- C D, C D
}
local low1 = { { 0, 52, 4 }, { 4, 48, 2 }, { 6, 50, 4 }, { 10, 50, 2 } }  -- E C D D (viola and cello)
local low4 = { { 0, 55, 2 }, { 2, 53, 2 }, { 4, 52, 2 }, { 6, 55, 2 }, { 8, 53, 2 }, { 10, 52, 2 } } -- G F♮ E twice
local function rock(a, b, c) -- three eighths, twice
    return { { 0, a, 2 }, { 2, b, 2 }, { 4, c, 2 }, { 6, a, 2 }, { 8, b, 2 }, { 10, c, 2 } }
end

return { key = 7, meter = 3, velocity = 90, bars = {
    [1] = join(line(violins[1], 'vn'), line(low1, 'va'), line(low1, 'vc')),
    [2] = join(line(up(call(67, 69), 12), 'fl'), line(call(67, 69), 'tp'), line(call(50, 52), 'cl'),
               line(violins[2], 'vn'), line(rock(59, 57, 60), 'va'), line(rock(47, 45, 48), 'vc')),
    [3] = join(line(violins[3], 'vn'), line({ { 0, 52, 4 }, { 4, 52, 2 }, { 6, 54, 4 }, { 10, 54, 2 } }, 'va'),
               line({ { 0, 52, 4 }, { 4, 40, 2 }, { 6, 42, 4 }, { 10, 54, 2 } }, 'vc')),
    [4] = join(line(up(call(72, 74), 12), 'fl'), line(call(72, 74), 'tp'), line(call(57, 58), 'cl'),
               line(violins[4], 'vn'), line(low4, 'va'), line(low4, 'vc')),
} }
