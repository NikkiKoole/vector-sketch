-- spec/color_spec.lua
-- src/color.lua: hex colours as the editor and the renderer read them. Pure spec.

local color = require('src.color')

local function near(a, b) assert.is_true(math.abs(a - b) < 1e-9, a .. ' vs ' .. b) end

describe('color.hexToColor', function()
    it('reads rrggbbaa, rrggbb (opaque), the short forms and a leading #', function()
        local r, g, b, a = color.hexToColor('ff800040')
        near(1, r); near(128 / 255, g); near(0, b); near(64 / 255, a)
        r, g, b, a = color.hexToColor('#00ff00')
        near(0, r); near(1, g); near(0, b); near(1, a)
        r, g, b, a = color.hexToColor('f00')
        near(1, r); near(0, g); near(0, b); near(1, a)
        r, g, b, a = color.hexToColor('f008')
        near(1, r); near(0, g); near(136 / 255, a)
    end)

    it('is white for what it cannot read', function()
        for _, bad in ipairs({ 'zzzzzz', 'abcde', nil, 12 }) do
            local r, g, b, a = color.hexToColor(bad)
            assert.are.same({ 1, 1, 1, 1 }, { r, g, b, a })
        end
    end)

    it('gives the same answer the second time (remembered)', function()
        assert.are.same({ color.hexToColor('123456') }, { color.hexToColor('123456') })
    end)

    it('remembers a bounded number (random Mipo colours are new every randomize)', function()
        for i = 1, 20000 do color.hexToColor(string.format('%06x', i)) end
        assert.is_true(color._test.parsedCount() <= 4096, tostring(color._test.parsedCount()))
        local r, g, b = color.hexToColor('ff8000')
        near(1, r); near(128 / 255, g); near(0, b)
    end)

    it('has a palette of hex colours', function()
        assert.is_true(#color.palette > 50)
        for _, hex in ipairs(color.palette) do assert.are.equal(6, #hex) end
    end)
end)

describe('color.darkerHex', function()
    it('makes r, g and b darker by the factor, keeps alpha', function()
        assert.are.equal('BF6000FF', color.darkerHex('FF8000FF'))
        assert.are.equal('80402080', color.darkerHex('FF804080', 0.5))
        assert.are.equal('000000FF', color.darkerHex('000000ff'))
    end)

    it('reads the short forms too', function()
        assert.are.equal('BF0000FF', color.darkerHex('#f00'))
    end)
end)
