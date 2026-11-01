-- scripts/meta.playtime.json is the sheet the shape8 outlines were traced on.
-- src/shape8-dict.lua is the copy the game uses. Same picture names, and the
-- outlines agree exactly. docs/SCENES.md.
-- Pure: busted spec/shape8-dict_spec.lua

local sheet = require('claudetools.shape8-from-meta')
local dict = require('src.shape8-dict')
local catalogs = require('src.shape-catalogs')

describe('shape8 dict and the meta sheet', function()
    it('names, outlines, sizes, catalogs and ear roots agree', function()
        local scene, err = sheet.loadScene(sheet.scenePath)
        assert.is_not_nil(scene, err)
        local problems = sheet.problems(sheet.outlines(scene), dict, catalogs)
        assert.are.equal(0, #problems, table.concat(problems, '\n'))
    end)

    it('flags a picture missing from the dict, a moved outline, and a changed size', function()
        local vertices = {}
        for i = 1, 16 do vertices[i] = 0 end
        local rows = { { url = 'newpart.png', dimensions = { 10, 20 }, vertices = vertices } }
        local missing = sheet.problems(rows, {}, nil)
        assert.are.equal('newpart.png is on the sheet but not in src/shape8-dict.lua', missing[1])

        local moved = {}
        for i = 1, 16 do moved[i] = 0 end
        moved[1] = 5
        local dictOne = { ['newpart.png'] = { dimensions = { 10, 20 }, vertices = moved } }
        local outline = table.concat(sheet.problems(rows, dictOne, nil), '\n')
        assert.is_truthy(outline:find('differs from the sheet by 5px', 1, true), outline)

        dictOne['newpart.png'].vertices = vertices
        dictOne['newpart.png'].dimensions = { 11, 20 }
        local size = table.concat(sheet.problems(rows, dictOne, nil), '\n')
        assert.is_truthy(size:find('size differs', 1, true), size)
    end)

    it('rounds a meta8 outline the way the editor log does', function()
        assert.are.equal(2, sheet.roundCoord(1.5))
        assert.are.equal(-1, sheet.roundCoord(-1.5)) -- math.floor(-1.5 + 0.5) = -1
        assert.are.equal(1, sheet.roundCoord(1.2))
    end)
end)
