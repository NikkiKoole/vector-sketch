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

local function strip(useNative, owner, img, scaleW, points, dir, shift, pinch)
    ribbon.useNative = useNative
    local mesh = ribbon.ownStrip(owner, 'test', img, scaleW, points, dir, shift, nil, pinch)
    ribbon.useNative = true
    return vertices(mesh)
end

-- An upper lip's Bezier (mouth.lua lipCurve) whose last stretch curls ~80 degrees in ~13 px
local CURLED_LIP = { -48.6, 24.3, -38.3, 15.7, -38.3, 15.7, -0.66, 0.93, -0.66, 0.93, 49.4, 17.3, 49.4, 17.3,
    45.3, 28.2 }

-- How many times an edge of the strip steps backwards against the curve: a fold
local function folds(verts)
    local n = 0
    for i = 1, #verts - 2, 2 do
        local tx = (verts[i + 2][1] + verts[i + 3][1]) - (verts[i][1] + verts[i + 1][1])
        local ty = (verts[i + 2][2] + verts[i + 3][2]) - (verts[i][2] + verts[i + 1][2])
        for side = 0, 1 do
            local a, b = verts[i + side], verts[i + 2 + side]
            if (b[1] - a[1]) * tx + (b[2] - a[2]) * ty < 0 then n = n + 1 end
        end
    end
    return n
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
        -- a thick upper lip curling into the mouth corner (it folded into a zigzag, 2026-10-31):
        -- pinched, it tapers instead
        { name = 'pinched lip', points = CURLED_LIP, scaleW = 0.3, dir = -1, shift = 0.6, pinch = true },
        -- (not two points: Lua's Bezier can't make their derivative, and no caller passes two)
    }

    for _, case in ipairs(cases) do
        it('lays the same vertices as Lua: ' .. case.name, function()
            if not native.available() then
                pending('no native library (native/desound/build.sh)')
                return
            end
            local lua = strip(false, {}, img, case.scaleW, case.points, case.dir, case.shift, case.pinch)
            local c = strip(true, {}, img, case.scaleW, case.points, case.dir, case.shift, case.pinch)
            assert.are.equal(#lua, #c)
            for i = 1, #lua do
                for k = 1, 4 do
                    assert.is_true(math.abs(lua[i][k] - c[i][k]) < 1e-3,
                        case.name .. ': vertex ' .. i .. '[' .. k .. '] ' .. lua[i][k] .. ' vs ' .. c[i][k])
                end
            end
        end)
    end

    it('pinch: a thick lip curling into its corner tapers instead of folding', function()
        local lipImg = love.graphics.newImage(love.image.newImageData(100, 128))
        for _, useNative in ipairs({ false, true }) do
            if useNative and not native.available() then break end
            local plain = strip(useNative, {}, lipImg, 0.3, CURLED_LIP, -1, 0)
            local pinched = strip(useNative, {}, lipImg, 0.3, CURLED_LIP, -1, 0, true)
            assert.is_true(folds(plain) > 0, 'the plain clamp folds this lip (else the case is too easy)')
            assert.are.equal(0, folds(pinched))
            assert.are.equal(ribbon.pinchSegments * 2, #pinched)
        end
    end)

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
