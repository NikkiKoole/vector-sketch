-- utils.sortedPairs: pairs in a fixed order (numbers first, then strings, each sorted), for the loops
-- that make or destroy Box2D things, so a Mipo built twice settles the same (mipo-neck seed 6 passed or
-- failed by what ran before it, 2026-11-10).
local utils = require('src.utils')

describe('utils.sortedPairs', function()
    it('walks numbers, then strings, each in order, with their values', function()
        local t = { lear = 1, head = 2, [3] = 'c', [1] = 'a', torso1 = 3, ['neck5'] = 4 }
        local keys, values = {}, {}
        for k, v in utils.sortedPairs(t) do keys[#keys + 1], values[#values + 1] = k, v end
        assert.same({ 1, 3, 'head', 'lear', 'neck5', 'torso1' }, keys)
        assert.same({ 'a', 'c', 2, 1, 4, 3 }, values)
    end)

    it('gives the same order however the table was filled', function()
        local a, b = {}, {}
        for _, k in ipairs({ 'rfoot', 'lhand', 'neck1', 'torso2', 'head' }) do a[k] = true end
        for _, k in ipairs({ 'head', 'torso2', 'neck1', 'lhand', 'rfoot' }) do b[k] = true end
        local ka, kb = {}, {}
        for k in utils.sortedPairs(a) do ka[#ka + 1] = k end
        for k in utils.sortedPairs(b) do kb[#kb + 1] = k end
        assert.same(ka, kb)
    end)

    it('walks an empty table without a step', function()
        for _ in utils.sortedPairs({}) do error('a step') end
    end)
end)
