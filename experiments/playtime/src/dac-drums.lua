-- dac-drums.lua
-- Mega Drive DAC drums, built in Lua for the megadrive style (src/music-megadrive.lua): the console streamed
-- its drum samples through the YM2612's DAC as 8-bit values at ~8 kHz with no smoothing, which is where their
-- grit and punch come from. Ported from dreamengine's mdstudies cart (tools/carts/mdstudies.c, make_drum and
-- its k909 / clap / chat / ohat): each sound computed at 44.1 kHz, sample-and-held at 8191 Hz, quantised to
-- 8 bits, normalised to 0.95. The four go end to end into one buffer; synth.lua loads it into a sample slot
-- (lib.sampleBanks) and each drum patch plays its own region. Pure Lua, no FFI: build() returns
-- { data = { floats }, n = count, regions = { name = { start, end } } } (fractions of the buffer).

local lib = {}

lib.RATE = 44100
lib.DAC_RATE = 8191
lib.SEED = 0x5EED -- the cart's noise seed

-- the cart's noise: a 32-bit LCG, the top bits as -1..1 (exact in doubles: the product stays under 2^53)
local function noise(rng)
    rng.s = (rng.s * 1664525 + 1013904223) % 4294967296
    return math.floor(rng.s / 512) / 4194304 - 1
end

local exp, sin, tanh = math.exp, math.sin, math.tanh
local TWO_PI = 6.2832 -- as the cart writes it

-- each drum: its length (s) and a function of time that advances its oscillator every sample
local DRUMS = {
    -- a 909-ish kick: a sine falling from 182 to 52 Hz, decaying in 0.14 s, soft-clipped, a 2 ms click
    { name = 'kick', secs = 0.35, make = function(rng)
        local phase = 0
        return function(t)
            phase = phase + TWO_PI * (52 + 130 * exp(-t / 0.025)) / lib.RATE
            return tanh(1.6 * sin(phase) * exp(-t / 0.14)) + noise(rng) * exp(-t / 0.002) * 0.3
        end
    end },
    -- a clap: three noise bursts 11 ms apart, then a tail
    { name = 'clap', secs = 0.25, make = function(rng)
        return function(t)
            local e = 0
            for k = 0, 2 do
                local tk = t - k * 0.011
                if tk >= 0 then e = e + exp(-tk / 0.006) end
            end
            return noise(rng) * (e * 0.7 + exp(-t / 0.08) * 0.6)
        end
    end },
    { name = 'closedHat', secs = 0.06, make = function(rng)
        return function(t) return noise(rng) * exp(-t / 0.012) end
    end },
    { name = 'openHat', secs = 0.35, make = function(rng)
        return function(t) return noise(rng) * exp(-t / 0.13) * 0.8 end
    end },
}
lib.DRUMS = DRUMS

-- one drum, as the cart's make_drum: the value held between DAC ticks, 8-bit, the peak brought to 0.95
local function render(drum, rng)
    local n = math.floor(drum.secs * lib.RATE)
    local fn, out = drum.make(rng), {}
    local held, nextTick, peak = 0, 0, 0
    for i = 0, n - 1 do
        local t = i / lib.RATE
        local v = fn(t) -- every sample, so the oscillators move on between ticks
        if t >= nextTick then
            v = math.max(-1, math.min(1, v)) * 127
            held = (v >= 0 and math.floor(v + 0.5) or -math.floor(-v + 0.5)) / 127 -- roundf
            nextTick = nextTick + 1 / lib.DAC_RATE
        end
        out[i + 1] = held
        if math.abs(held) > peak then peak = math.abs(held) end
    end
    if peak > 0 then
        for i = 1, n do out[i] = out[i] * 0.95 / peak end
    end
    return out
end
lib.render = render

function lib.build()
    local rng = { s = lib.SEED }
    local data, regions, n = {}, {}, 0
    local starts = {}
    for _, drum in ipairs(DRUMS) do
        starts[drum.name] = n
        for _, v in ipairs(render(drum, rng)) do
            n = n + 1
            data[n] = v
        end
        regions[drum.name] = { starts[drum.name], n }
    end
    for _, region in pairs(regions) do region[1], region[2] = region[1] / n, region[2] / n end
    return { data = data, n = n, regions = regions }
end

return lib
