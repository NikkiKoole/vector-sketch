-- spec/form-bake_spec.lua
-- src/render/form-bake.lua: a picture's roundness baked from its mask, for the plasticine light.
-- A white disc on black as the mask: the height peaks in the middle, the normals point out at the
-- edge, outside is flat; a dome (rise 1) rises all the way in, a pebble (rise 0.2) is flat on top.
-- Run with: love . --specs spec/form-bake_spec.lua

if not love then return end

local formBake = require('src.render.form-bake')

local SIZE = 192

local function disc()
    local data = love.image.newImageData(SIZE, SIZE)
    local c, r = SIZE / 2, SIZE * 0.4
    data:mapPixel(function(x, y)
        local inside = (x - c) ^ 2 + (y - c) ^ 2 < r * r
        local v = inside and 1 or 0
        return v, v, v, 1
    end)
    return data
end

-- the map's height, normal x and y (-1..1) and inside at a fraction (fx, fy) of the picture
local function at(map, fx, fy)
    local w, h = map:getDimensions()
    local r, g, b, a = map:getPixel(math.floor(fx * (w - 1) + 0.5), math.floor(fy * (h - 1) + 0.5))
    return r, (g - 0.5) * 2, (b - 0.5) * 2, a
end

describe('form bake', function()
    it('a disc: highest in the middle, flat outside', function()
        local map = formBake.bakeData(disc(), 1)
        local middle = at(map, 0.5, 0.5)
        local outside, nx, ny, inside = at(map, 0.02, 0.02)
        assert.is_true(middle > 0.9, 'middle ' .. middle)
        assert.are.equal(0, outside)
        assert.are.equal(0, inside)
        assert.is_true(math.abs(nx) < 0.01 and math.abs(ny) < 0.01)
    end)

    it('a disc: normals point out near its edge', function()
        local map = formBake.bakeData(disc(), 1)
        local _, rx = at(map, 0.85, 0.5)  -- right edge: out is +x
        local _, lx = at(map, 0.15, 0.5)  -- left edge: out is -x
        local _, _, by = at(map, 0.5, 0.85) -- bottom edge (y down): out is +y
        local _, _, ty = at(map, 0.5, 0.15)
        assert.is_true(rx > 0.2, 'right ' .. rx)
        assert.is_true(lx < -0.2, 'left ' .. lx)
        assert.is_true(by > 0.2, 'bottom ' .. by)
        assert.is_true(ty < -0.2, 'top ' .. ty)
    end)

    it('a dome rises all the way in; a pebble is flat on top', function()
        local dome = formBake.bakeData(disc(), 1)
        local pebble = formBake.bakeData(disc(), 0.2)
        -- halfway between the middle and the edge
        local domeH, domeX = at(dome, 0.7, 0.5)
        local pebbleH, pebbleX = at(pebble, 0.7, 0.5)
        assert.is_true(domeH < 0.95, 'dome height halfway ' .. domeH)
        assert.is_true(domeX > 0.05, 'dome still sloping halfway ' .. domeX)
        assert.is_true(pebbleH > 0.95, 'pebble height halfway ' .. pebbleH)
        assert.is_true(math.abs(pebbleX) < 0.05, 'pebble flat halfway ' .. pebbleX)
    end)
end)
