-- spec/physics-units_spec.lua
-- Tuned numbers (written at 100 px per metre) turned into the world's meter.
-- Pure: LÖVE's meter is stubbed.
-- Run with: busted spec/physics-units_spec.lua

local units = require('src.physics-units')

local function atMeter(meter, fn)
    local realLove = _G.love
    _G.love = { physics = { getMeter = function() return meter end } }
    local ok, err = pcall(fn)
    _G.love = realLove
    assert(ok, err)
end

describe('physics units', function()
    it('changes nothing at the reference meter', function()
        atMeter(units.REFERENCE_METER, function()
            for _, f in ipairs({ 'speed', 'rate', 'accel', 'mass', 'force', 'impulse', 'toReferenceSpeed',
                'toReferenceForce' }) do
                assert.are.equal(1234, units[f](1234), f)
            end
        end)
    end)

    it('at 4x the meter: speeds and rates 2x, accelerations 4x, forces 1/4, impulses 1/8', function()
        atMeter(400, function()
            assert.are.equal(2400, units.speed(1200))
            assert.are.equal(40, units.rate(20))
            assert.are.equal(4000, units.accel(1000))
            assert.are.equal(125000, units.force(500000))
            assert.are.equal(125, units.impulse(1000))
            assert.are.equal(2.5, units.mass(40))
            assert.are.equal(1200, units.toReferenceSpeed(units.speed(1200)))
            assert.are.equal(500000, units.toReferenceForce(units.force(500000)))
        end)
    end)

    -- A jump is mass * speed: mass shrinks k^2 (same pixels, density per m^2), so the
    -- impulse it takes to reach the same pixel height shrinks k^1.5.
    it('a mass-scaled impulse and impulse() agree', function()
        atMeter(400, function()
            local k = 4
            local massAt100 = 10
            local massHere = massAt100 / (k * k)
            assert.are.equal(massHere, units.mass(massAt100))
            assert.is_true(math.abs(massHere * units.speed(100) - units.impulse(massAt100 * 100)) < 1e-9)
        end)
    end)

    it('reads --meter from the command line', function()
        assert.are.equal(400, units.meterFromArgs({ '--bridge', '--meter', '400' }))
        assert.is_nil(units.meterFromArgs({ '--bridge' }))
        assert.is_nil(units.meterFromArgs(nil))
    end)
end)

describe('units.weight', function()
    it('is mass times 9.8 m/s^2 in the world meter', function()
        atMeter(200, function() assert.is_near(2 * 9.8 * 200, units.weight(2), 1e-9) end)
        atMeter(100, function() assert.is_near(9.8 * 100, units.weight(1), 1e-9) end)
    end)
end)
