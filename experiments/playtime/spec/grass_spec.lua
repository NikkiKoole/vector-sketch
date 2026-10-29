-- spec/grass_spec.lua — where the GRASS sfixture puts its blades (src/grass.lua).
-- Pure: placeBlades only does maths (noise falls back to a constant without LÖVE).

describe("src.grass placeBlades", function()
    package.loaded['src.grass'] = nil
    local grass = require('src.grass')

    -- a 200 x 100 rectangle around the body's origin, clockwise on screen (y points down)
    local rect = { -100, -50, 100, -50, 100, 50, -100, 50 }
    local function reversed(vertices)
        local out = {}
        for i = #vertices - 1, 1, -2 do
            out[#out + 1] = vertices[i]
            out[#out + 1] = vertices[i + 1]
        end
        return out
    end

    it("puts blades only on the top edge", function()
        local blades = grass.placeBlades(rect, 0, { density = 10 })
        assert.are.equal(20, #blades) -- 200 units at 10 per 100
        for _, blade in ipairs(blades) do
            assert.are.equal(-50, blade.y)
            assert.is_true(blade.x > -100 and blade.x < 100)
        end
    end)

    it("doesn't care about the winding", function()
        local blades = grass.placeBlades(reversed(rect), 0, { density = 10 })
        assert.are.equal(20, #blades)
        for _, blade in ipairs(blades) do assert.are.equal(-50, blade.y) end
    end)

    it("follows the body's angle: upside down, the grass is on the other edge", function()
        local blades = grass.placeBlades(rect, math.pi, { density = 10 })
        assert.are.equal(20, #blades)
        for _, blade in ipairs(blades) do assert.are.equal(50, blade.y) end
    end)

    it("skips edges steeper than maxSlope", function()
        -- a triangle: flat bottom, two 45 degree sides on top
        local tri = { -100, 0, 0, -100, 100, 0 }
        assert.are.equal(0, #grass.placeBlades(tri, 0, { density = 10, maxSlope = 30 }))
        assert.is_true(#grass.placeBlades(tri, 0, { density = 10, maxSlope = 50 }) > 0)
    end)

    it("gives every blade a sprite, a scale and a layer", function()
        for _, blade in ipairs(grass.placeBlades(rect, 0, {})) do
            assert.is_true(blade.quad >= 1 and blade.quad <= #grass.QUADS)
            assert.is_true(blade.scale >= 0 and blade.scale <= 1)
            assert.is_boolean(blade.front)
        end
    end)
end)
