-- spec/polyline_spec.lua
-- src/polyline.lua: the mitered strip under the hair ribbons. Pure spec.

local polyline = require('src.polyline')

describe('polyline.miter', function()
    it('puts a straight line half_width to each side', function()
        local v = polyline.miter({ 0, 0, 10, 0 }, 2)
        assert.are.equal(4, #v)
        for _, p in ipairs(v) do
            assert.is_near(2, math.abs(p[2]), 1e-9)
        end
        assert.is_near(0, v[1][1], 1e-9)
        assert.is_near(10, v[4][1], 1e-9)
    end)

    it('meets a square corner on the diagonal', function()
        local v = polyline.miter({ 0, 0, 10, 0, 10, 10 }, 1)
        assert.are.equal(6, #v)
        -- the corner pair: (10 +- 1, 0 -+ 1), sqrt(2) from the corner
        local a, b = v[3], v[4]
        assert.is_near(math.sqrt(2), math.sqrt((a[1] - 10) ^ 2 + a[2] ^ 2), 1e-9)
        assert.is_near(math.sqrt(2), math.sqrt((b[1] - 10) ^ 2 + b[2] ^ 2), 1e-9)
        assert.is_near(20, a[1] + b[1], 1e-9)
    end)
end)
