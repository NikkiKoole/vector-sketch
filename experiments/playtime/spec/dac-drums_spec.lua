-- The megadrive style's DAC drums (src/dac-drums.lua): 8-bit values held at the DAC's ~8.2 kHz, each drum
-- brought to 0.95, laid end to end with a region each. Pure Lua.
package.path = './?.lua;' .. package.path
local drums = require('src.dac-drums')

describe('dac drums', function()
    local bank = drums.build()

    it('lays the four drums end to end, each a region of the buffer', function()
        assert.are.equal(#bank.data, bank.n)
        local total = 0
        for _, drum in ipairs(drums.DRUMS) do total = total + math.floor(drum.secs * drums.RATE) end
        assert.are.equal(total, bank.n)
        local last = 0
        for _, drum in ipairs(drums.DRUMS) do
            local region = bank.regions[drum.name]
            assert.are.equal(last, region[1])
            assert.is_true(region[2] > region[1])
            last = region[2]
        end
        assert.are.equal(1, last)
    end)

    it('holds each value between DAC ticks and peaks at 0.95', function()
        local kick = drums.render(drums.DRUMS[1], { s = drums.SEED })
        local peak, changes = 0, 0
        for i, v in ipairs(kick) do
            peak = math.max(peak, math.abs(v))
            if i > 1 and v ~= kick[i - 1] then changes = changes + 1 end
        end
        assert.is_true(math.abs(peak - 0.95) < 1e-9)
        -- at most one new value per DAC tick (~5.4 samples apart at 44.1 kHz)
        assert.is_true(changes <= math.ceil(#kick * drums.DAC_RATE / drums.RATE))
        assert.is_true(changes > #kick * drums.DAC_RATE / drums.RATE * 0.5)
    end)

    it('is the same every build', function()
        local again = drums.build()
        for i = 1, bank.n, 997 do assert.are.equal(bank.data[i], again.data[i]) end
    end)
end)
