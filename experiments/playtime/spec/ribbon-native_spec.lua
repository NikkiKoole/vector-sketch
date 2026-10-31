-- The limb ribbons laid in C (native/desound/ribbon.c via src/ribbon-native.lua) and in Lua
-- (texturedCurve) come out the same: ownStrip draws whichever is there.
if not love then return end

local ribbon = require('src.render.ribbon')
local native = require('src.ribbon-native')

local function vertices(mesh)
    local out = {}
    for i = 1, mesh:getVertexCount() do
        local x, y, u, v = mesh:getVertex(i)
        out[#out + 1] = { x, y, u, v }
    end
    return out
end

local function strip(useNative, owner, img, scaleW, points, dir, shift)
    ribbon.useNative = useNative
    local mesh = ribbon.ownStrip(owner, 'test', img, scaleW, points, dir, shift)
    ribbon.useNative = true
    return vertices(mesh)
end

describe('ribbon-native', function()
    local img = love.graphics.newImage(love.image.newImageData(40, 200))
    local cases = {
        -- an arm as drawConnectedTexture shapes it: grown ends, the elbow doubled twice
        { name = 'limb', points = { 80, 90, 100, 100, 140, 180, 140, 180, 140, 180, 120, 260, 115, 280 },
            scaleW = 0.5, dir = 1 },
        -- a lip: mirrored (dir -1) and shifted
        { name = 'lip', points = { 0, 0, 10, -4, 10, -4, 20, -6, 20, -6, 30, -4, 30, -4, 40, 0 },
            scaleW = 0.25, dir = -1, shift = 3 },
        -- a sharp bend: the half-width clamp at work
        { name = 'sharp', points = { 0, 0, 100, 0, 100, 0, 100, 0, 0, 10 }, scaleW = 1, dir = 1 },
        -- (not two points: Lua's Bezier can't make their derivative, and no caller passes two)
    }

    for _, case in ipairs(cases) do
        it('lays the same vertices as Lua: ' .. case.name, function()
            if not native.available() then
                pending('no native library (native/desound/build.sh)')
                return
            end
            local lua = strip(false, {}, img, case.scaleW, case.points, case.dir, case.shift)
            local c = strip(true, {}, img, case.scaleW, case.points, case.dir, case.shift)
            assert.are.equal(#lua, #c)
            for i = 1, #lua do
                for k = 1, 4 do
                    assert.is_true(math.abs(lua[i][k] - c[i][k]) < 1e-3,
                        case.name .. ': vertex ' .. i .. '[' .. k .. '] ' .. lua[i][k] .. ' vs ' .. c[i][k])
                end
            end
        end)
    end

    it('lays a strip again when its points change', function()
        if not native.available() then
            pending('no native library')
            return
        end
        local owner = {}
        local first = strip(true, owner, img, 1, { 0, 0, 50, 50, 100, 0 }, 1)
        local moved = strip(true, owner, img, 1, { 0, 0, 50, 80, 100, 0 }, 1)
        assert.are_not.equal(first[9][2], moved[9][2])
    end)
end)
