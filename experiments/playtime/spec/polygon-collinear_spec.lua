-- polygon.dropCollinear: points on the line between their neighbours go before a polygon reaches
-- Box2D (MEASURING M6: this torso crashed LÖVE 11.5's Box2D at 100+ px per metre)
local polygon = require('src.polygon')

describe('polygon.dropCollinear', function()
    it('drops the in-line points of the spine torso that crashed Box2D', function()
        local torso = { 1.4727854199436694, 27.655637330053345, 37.801492445220845, -1.8000710688200428,
            39.444854707587375, -14.727854199436694, 41.088216969953898, -27.655637330053345,
            1.3305156862346967, -27.655637330053345, -38.427185597484502, -27.655637330053345,
            -35.659696654779886, -14.482389962779417, -32.892207712075283, -1.3091425955054863 }
        assert.are.same({ 1.4727854199436694, 27.655637330053345, 37.801492445220845, -1.8000710688200428,
            41.088216969953898, -27.655637330053345, -38.427185597484502, -27.655637330053345,
            -32.892207712075283, -1.3091425955054863 }, polygon.dropCollinear(torso))
    end)

    it('keeps a polygon with no points in line', function()
        local square = { 0, 0, 10, 0, 10, 10, 0, 10 }
        assert.are.same(square, polygon.dropCollinear(square))
    end)

    -- a capsule whose corner is half its width has its two top points (and two bottom ones) on top
    -- of each other: one of each pair stays, as Box2D keeps one when it welds them
    it('keeps one of two points on top of each other', function()
        local capsule = { -10, -10, 0, -20, 0, -20, 10, -10, 10, 10, 0, 20, 0, 20, -10, 10 }
        assert.are.same({ -10, -10, 0, -20, 10, -10, 10, 10, 0, 20, -10, 10 }, polygon.dropCollinear(capsule))
    end)

    it('gives back the input when fewer than 3 points would be left', function()
        local line = { 0, 0, 5, 0, 10, 0 }
        assert.are.equal(line, polygon.dropCollinear(line))
    end)
end)
