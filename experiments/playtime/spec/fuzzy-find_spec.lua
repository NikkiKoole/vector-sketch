-- src/fuzzy-find.lua: the scenes tab's search (pure)
local fuzzy = require('src.fuzzy-find')

local scenes = {
    { name = 'dollhouse', note = 'rooms with toys, a slide and a skateboard' },
    { name = 'rides', note = 'little vehicles Mipos get into and you drive' },
    { name = 'bike', note = 'a Mipo riding down a hill' },
    { name = 'bark', note = 'tree trunks in real bark, lit' },
    { name = 'boat2', note = 'the boat of planks' },
}
local function fields(s) return { s.name, s.note }, { 2, 1 } end
local function names(list)
    local out = {}
    for i, s in ipairs(list) do out[i] = s.name end
    return out
end

describe('fuzzy-find', function()
    it('finds a name by its start first', function()
        assert.are.same('rides', fuzzy.rank('rid', scenes, fields)[1].name)
    end)

    it('finds letters in order, not in one piece', function()
        assert.is_not_nil(fuzzy.scoreWord('bnn', 'banana'))
        assert.is_nil(fuzzy.scoreWord('nnb', 'banana'))
    end)

    it('letters too far apart are not a match', function()
        assert.is_nil(fuzzy.scoreWord('water', 'wild: a Mipo looking at a tree'))
        assert.is_not_nil(fuzzy.scoreWord('wtr', 'water'))
        -- the tightest place counts, not the first
        assert.is_not_nil(fuzzy.scoreWord('bk', 'b..........bike'))
    end)

    it('ignores case', function()
        assert.is_not_nil(fuzzy.scoreWord('MIPO', 'a Mipo riding'))
    end)

    it('searches the description too', function()
        assert.are.same({ 'rides' }, names(fuzzy.rank('vehicles', scenes, fields)))
    end)

    it('needs every word of the query', function()
        assert.are.same({ 'bike' }, names(fuzzy.rank('mipo hill', scenes, fields)))
        assert.are.same({}, fuzzy.rank('mipo zzz', scenes, fields))
    end)

    it('ranks one piece over scattered letters, a word start over the middle', function()
        assert.is_true(fuzzy.scoreWord('bar', 'bark') > fuzzy.scoreWord('bar', 'b-a-r'))
        assert.is_true(fuzzy.scoreWord('lit', 'bark, lit') > fuzzy.scoreWord('lit', 'split'))
    end)

    it('a name match beats a description match', function()
        -- 'boat' is boat2's name; nothing else says boat
        assert.are.same('boat2', fuzzy.rank('boat', scenes, fields)[1].name)
        -- 'skate': only dollhouse's description
        assert.are.same({ 'dollhouse' }, names(fuzzy.rank('skate', scenes, fields)))
    end)

    it('an empty query finds nothing (the tab shows its groups then)', function()
        assert.are.same({}, fuzzy.rank('  ', scenes, fields))
    end)
end)
