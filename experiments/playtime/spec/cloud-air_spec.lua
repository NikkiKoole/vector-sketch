-- src/cloud-air.lua: the air clouds grow in, and their thermals (CLOUDS.md CG1, CG2). Pure.
package.path = './?.lua;' .. package.path
local air = require('src.cloud-air')

local function newAir(over)
    local a = {}
    for k, v in pairs(air.DEFAULTS) do a[k] = v end
    for k, v in pairs(over or {}) do a[k] = v end
    return a
end

describe('cloud-air', function()
    it('holds about 17 g/kg of vapour at 22 °C at the ground', function()
        assert.is_true(math.abs(air.qs(22, 1000) - 16.9) < 0.5)
    end)

    it('puts the cloud base about 125 m per degree of dew point spread', function()
        local lcl = air.levels(newAir())
        -- 22 °C at 70%: dew point ~16.3 °C, spread 5.7: ~710 m
        assert.is_true(lcl > 600 and lcl < 820, 'lcl ' .. tostring(lcl))
    end)

    it('bases go up when the ground is drier', function()
        local wet = air.levels(newAir({ groundRH = 85 }))
        local dry = air.levels(newAir({ groundRH = 50 }))
        assert.is_true(dry > wet + 500)
    end)

    it('the ground air goes on alone above the base and stops under the lid', function()
        local lcl, lfc, top = air.levels(newAir())
        assert.is_truthy(lfc)
        assert.is_true(lfc >= lcl)
        assert.is_true(top > 3500 and top < 4500, 'top ' .. tostring(top))
    end)

    it('in stable air nothing goes on alone', function()
        local _, lfc = air.levels(newAir({ lapse = 4 }))
        assert.is_nil(lfc)
    end)

    it('a lifted thermal cools, turns to cloud and is warmed by it', function()
        local a = newAir()
        local p = air.newThermal(a, 0, 600, 0.95, 0, 350)
        assert.are.equal(0, p.qc)
        air.moveTo(p, 1700)
        assert.is_true(p.qc > 1)
        -- warmer than the dry way down from where it was
        assert.is_true(p.t > air.envT(a, 600) - 0.0098 * 1100 + 2)
    end)

    it('one pulled past the free convection level rises by itself, one dropped back sinks and clears', function()
        local a = newAir()
        local up = air.newThermal(a, 0, 600, 0.95, 0, 350)
        air.moveTo(up, 1700)
        for _ = 1, 150 do air.step(a, up, 1) end
        assert.is_true(up.z > 2300, 'up ' .. up.z)
        local down = air.newThermal(a, 0, 600, 0.95, 0, 350)
        air.moveTo(down, 900)
        air.moveTo(down, 300)
        assert.are.equal(0, down.qc)
    end)

    it('a big cloud rains, the rain cools it and it dies; under a higher lid it rains more', function()
        local function shower(lidZ)
            local a = newAir({ groundRH = 85, lidZ = lidZ })
            local p = air.newThermal(a, 0, 600, 0.97, 0.3, 400)
            air.moveTo(p, 1500)
            p.w = 3
            local rained = 0
            for i = 1, 4000 do
                air.step(a, p, 1)
                rained = rained + p.rainRate
                if air.spent(p) then return rained, i end
            end
            return rained, nil
        end
        local low, lowEnd = shower(3500)
        local high, highEnd = shower(6000)
        assert.is_truthy(lowEnd)
        assert.is_truthy(highEnd)
        assert.is_true(low > 0.5)
        assert.is_true(high > low)
        assert.is_true(highEnd > lowEnd)
    end)
end)
