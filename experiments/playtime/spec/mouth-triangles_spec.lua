-- spec/mouth-triangles_spec.lua
-- A mouth's triangles (src/render/mouth.lua): LÖVE's quick triangulation where it works, the careful one
-- (shapes.makeTrianglesFromPolygon) where it refuses (lips crossing). Where the quick one works it must cover the
-- same area as the careful one, over the mouth shapes, sizes and openings a talking Mipo goes through.
-- Run with: love . --specs spec/mouth-triangles_spec.lua

if not love then return end

local mouth = require('src.render.mouth')
local shapes = require('src.shapes')
local mouthShapes = require('src.mouth-shapes')

local function area(tris)
    local a = 0
    for _, t in ipairs(tris) do
        a = a + math.abs((t[3] - t[1]) * (t[6] - t[2]) - (t[5] - t[1]) * (t[4] - t[2])) / 2
    end
    return a
end

-- a mouth shape scaled, its lower lip moved by `open` of the mouth's height (up past the upper one: crossing)
local function curve(shape, sx, sy, open)
    local minY, maxY = math.huge, -math.huge
    for i = 2, 16, 2 do minY, maxY = math.min(minY, shape.points[i]), math.max(maxY, shape.points[i]) end
    local cp = {}
    for i = 1, 16, 2 do
        local x, y = shape.points[i] * sx, shape.points[i + 1] * sy
        if i >= 11 and i <= 15 then y = y + open * (maxY - minY) * sy end
        cp[i], cp[i + 1] = x, y
    end
    return cp
end

describe('a mouth\'s triangles', function()
    it('cover the same area quickly as carefully, wherever the quick way works', function()
        love.math.setRandomSeed(7)
        local quick = 0
        for _, shape in ipairs(mouthShapes.normalized) do
            for _ = 1, 8 do
                local poly = mouth.polygonOf(curve(shape, 1 + love.math.random() * 4, 1 + love.math.random() * 4,
                    love.math.random() * 2.4 - 0.9))
                if poly and #poly >= 6 then
                    local ok, fast = pcall(love.math.triangulate, poly)
                    if ok then
                        quick = quick + 1
                        local careful = shapes.makeTrianglesFromPolygon(poly)
                        local a, b = area(careful), area(fast)
                        assert.is_true(math.abs(a - b) <= 0.01 * a, string.format('%s: %.1f vs %.1f', shape.name, a, b))
                    end
                end
            end
        end
        assert.is_true(quick > 50, 'the quick way works for most mouths (' .. quick .. ')')
    end)
end)
