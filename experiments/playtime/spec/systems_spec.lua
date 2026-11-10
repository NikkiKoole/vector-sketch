-- src/systems.lua: each hook calls the systems that have it, in list order, with their module as
-- package.loaded holds it now (a hot-swapped module is the one used). Pure: fake modules.
local systems = require('src.systems')

describe('systems', function()
    local saved, calls

    before_each(function()
        saved = systems.list
        calls = {}
        package.loaded['spec.fake-a'] = { tag = 'a' }
        package.loaded['spec.fake-b'] = { tag = 'b' }
        systems.list = {
            { name = 'a', module = 'spec.fake-a',
                update = function(m, dt) calls[#calls + 1] = m.tag .. ':update:' .. dt end,
                draw = function(m) calls[#calls + 1] = m.tag .. ':draw' end },
            { name = 'b', module = 'spec.fake-b',
                update = function(m, dt) calls[#calls + 1] = m.tag .. ':update:' .. dt end,
                drawBelow = function(m) calls[#calls + 1] = m.tag .. ':drawBelow' end,
                unload = function(m) calls[#calls + 1] = m.tag .. ':unload' end },
        }
    end)

    after_each(function()
        systems.list = saved
        package.loaded['spec.fake-a'], package.loaded['spec.fake-b'] = nil, nil
    end)

    it('calls each hook on the systems that have it, in order', function()
        systems.update(0.5)
        systems.drawBelow()
        systems.draw()
        systems.unload()
        assert.same({ 'a:update:0.5', 'b:update:0.5', 'b:drawBelow', 'a:draw', 'b:unload' }, calls)
    end)

    it('uses the module as loaded now (after a hot swap)', function()
        package.loaded['spec.fake-a'] = { tag = 'a2' }
        systems.draw()
        assert.same({ 'a2:draw' }, calls)
    end)

    it('passes splits their add', function()
        local got
        systems.list = { { name = 'c', module = 'spec.fake-a', splits = function(m, add) got = { m.tag, add } end } }
        local add = function() end
        systems.splits(add)
        assert.same({ 'a', add }, got)
    end)

    it('lists hair: stepped, in its Mipo\'s layers, let go on unload', function()
        local hair
        for _, s in ipairs(saved) do if s.name == 'hair' then hair = s end end
        assert.is_not_nil(hair)
        assert.equal('src.hair-locks', hair.module)
        for _, hook in ipairs({ 'update', 'splits', 'unload' }) do
            assert.is_function(hair[hook])
        end
    end)
end)
