-- spec/voice-lab_spec.lua
-- The voice lab's 'synth' path (src/voice-lab.lua) at all zeros must sound like
-- 'now' (the take through LÖVE at volume 0.8): same pitch, same length, same
-- loudness. Rendered offline straight through libdesound (INSTR_SAMPLE at its root).
-- At the instrument's default level it was ~15 dB quieter, and quieter sounded lower.
-- Run with: love . --specs spec/voice-lab_spec.lua

if not love then return end
if not jit then return end

local ffi = require('ffi')
local state = require('src.state')

local function mono(path)
    local d = love.sound.newSoundData(path)
    local n, ch, rate = d:getSampleCount(), d:getChannelCount(), d:getSampleRate()
    local out = {}
    for i = 0, n - 1 do
        local s = 0
        for c = 1, ch do s = s + d:getSample(i, c) end
        out[i + 1] = s / ch
    end
    return out, rate
end

-- f0 (Hz) of the loudest 60 ms (autocorrelation), length above 3% of the peak, peak
local function analyse(x, rate)
    local win = math.floor(rate * 0.06)
    local best, at = 0, 1
    for i = 1, #x - win, math.floor(win / 4) do
        local e = 0
        for k = i, i + win - 1 do e = e + x[k] * x[k] end
        if e > best then best, at = e, i end
    end
    local bestLag, bestR = 1, -1
    for lag = math.floor(rate / 900), math.floor(rate / 60) do
        local r, n0, n1 = 0, 0, 0
        for k = at, at + win - 1 - lag do
            r = r + x[k] * x[k + lag]
            n0 = n0 + x[k] * x[k]
            n1 = n1 + x[k + lag] * x[k + lag]
        end
        r = r / math.sqrt(n0 * n1 + 1e-12)
        if r > bestR then bestR, bestLag = r, lag end
    end
    local peak = 0
    for k = 1, #x do peak = math.max(peak, math.abs(x[k])) end
    local first, last
    for k = 1, #x do
        if math.abs(x[k]) > peak * 0.03 then first = first or k; last = k end
    end
    return rate / bestLag, ((last or 0) - (first or 0)) / rate, peak
end

describe('voice lab', function()
    it("'synth' at all zeros plays a take like 'now': pitch, length, loudness", function()
        -- the running synth renders on its own thread; rendering here too would race it
        if state.synth and state.synth.started then return end
        local synth = require('src.synth') -- its cdef
        local lab = require('src.voice-lab')
        local ok, C = pcall(ffi.load, love.filesystem.getWorkingDirectory() .. '/native/desound/libdesound.dylib')
        if not ok then return end -- not built on this machine
        pcall(ffi.cdef, 'void de_lua_render(float *out, int frames);')
        C.de_lua_init()
        for _, path in ipairs({ 'assets/voices/theo/ba.ogg', 'assets/voices/puppetmaker/po3.ogg' }) do
            local x, rate = mono(path)
            local n = math.floor(#x * 44100 / rate)
            local buf = ffi.new('float[?]', n)
            for i = 0, n - 1 do
                local pos = i * rate / 44100
                local i0 = math.floor(pos)
                local i1 = math.min(i0 + 1, #x - 1)
                buf[i] = x[i0 + 1] + (x[i1 + 1] - x[i0 + 1]) * (pos - i0)
            end
            C.sample_load(7, buf, n)
            C.instrument(45, synth.INSTR.SAMPLE, 1, 0, 7, 40)
            C.instrument_sample(45, 7, 60)
            C.instrument_level(45, lab.level)
            C.de_lua_tick(0.016)
            C.hit(60, 45, 7, math.floor(n / 44100 * 1000) + 60)
            C.de_lua_tick(0.016)
            local out, y, done = ffi.new('float[?]', 1024), {}, 0
            while done < n + 44100 * 0.3 do
                C.de_lua_render(out, 512)
                for k = 0, 511 do y[#y + 1] = (out[k * 2] + out[k * 2 + 1]) / 2 end
                done = done + 512
                C.de_lua_tick(512 / 44100)
            end
            local f0a, lena, peakA = analyse(x, rate)
            local f0b, lenb, peakB = analyse(y, 44100)
            local semis = 12 * math.log(f0b / f0a) / math.log(2)
            local dB = 20 * math.log10(peakB / (peakA * 0.8)) -- 'now' plays at LÖVE volume 0.8
            -- alone: 0.00 semitones, length x1.000. In a full run, effects other specs leave on
            -- the engine (tape wobble, ...) bend it a little (0.15 st) and trim the tail (x0.90),
            -- so the bounds catch real mistakes: a 48k/44.1k mix-up is 1.5 st, a wrong root more
            assert.is_true(math.abs(semis) < 0.3, path .. ' pitch off by ' .. semis .. ' semitones')
            assert.is_true(math.abs(lenb / lena - 1) < 0.15, path .. ' length x' .. lenb / lena)
            assert.is_true(math.abs(dB) < 1, path .. ' loudness off by ' .. dB .. ' dB')
        end
    end)
end)
