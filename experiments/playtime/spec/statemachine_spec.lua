-- Pure unit specs for the state-machine helper. No LÖVE needed.

local sm = require('src.statemachine')

describe('statemachine', function()
    local m

    before_each(function() m = sm.new() end)

    describe('new()', function()
        it('starts with no current state and depth 0', function()
            assert.is_nil(m:current())
            assert.equal(0, m:depth())
            assert.same({}, m:getHistory())
        end)
    end)

    describe('state()', function()
        it('registers a state and returns self for chaining', function()
            assert.equal(m, m:state('a', { enter = function() end }))
            assert.is_not_nil(m.states['a'])
        end)

        it('errors on bad input', function()
            assert.has_error(function() m:state(nil, {}) end)
            assert.has_error(function() m:state('a', nil) end)
        end)
    end)

    describe('transition()', function()
        it('errors if target state not registered', function()
            assert.has_error(function() m:transition('nope') end)
        end)

        it('enters the first state with no leave fired', function()
            local enter_data
            m:state('a', { enter = function(d) enter_data = d end })
            m:transition('a', { x = 1 })
            assert.equal('a', m:current())
            assert.same({ x = 1 }, enter_data)
            assert.equal(1, m:depth())
        end)

        it('leaves the old state then enters the new, with data threaded', function()
            local order = {}
            m:state('a', {
                enter = function(d) order[#order+1] = 'a.enter:' .. tostring(d) end,
                leave = function(to, d) order[#order+1] = 'a.leave:' .. to .. ':' .. tostring(d) end,
            })
            m:state('b', {
                enter = function(d) order[#order+1] = 'b.enter:' .. tostring(d) end,
            })
            m:transition('a', 'first')
            m:transition('b', 'second')
            assert.same({
                'a.enter:first',
                'a.leave:b:second',
                'b.enter:second',
            }, order)
        end)

        it('records each from-state into history', function()
            m:state('a', {}); m:state('b', {}); m:state('c', {})
            m:transition('a')
            m:transition('b')
            m:transition('c')
            assert.same({ 'a', 'b' }, m:getHistory())
        end)
    end)

    describe('push/pop', function()
        it('push does NOT fire leave on the previous top', function()
            local leave_called = false
            m:state('a', { leave = function() leave_called = true end })
            m:state('b', {})
            m:transition('a')
            m:push('b')
            assert.is_false(leave_called)
            assert.equal('b', m:current())
            assert.equal(2, m:depth())
        end)

        it('pop fires leave on top (with state-below as nextState) then resume on it', function()
            local events = {}
            m:state('a', {
                resume = function(d) events[#events+1] = 'a.resume:' .. tostring(d) end,
            })
            m:state('b', {
                leave = function(to, d) events[#events+1] = 'b.leave:' .. tostring(to) .. ':' .. tostring(d) end,
            })
            m:transition('a')
            m:push('b')
            m:pop('result')
            assert.same({ 'b.leave:a:result', 'a.resume:result' }, events)
            assert.equal('a', m:current())
            assert.equal(1, m:depth())
        end)

        it('errors if you try to pop an empty stack', function()
            assert.has_error(function() m:pop() end)
        end)

        it('does NOT record push/pop in history', function()
            m:state('a', {}); m:state('b', {})
            m:transition('a')
            m:push('b')
            m:pop()
            assert.same({}, m:getHistory())
        end)
    end)

    describe('back()', function()
        it('returns false when history is empty', function()
            m:state('a', {})
            assert.is_false(m:back())
        end)

        it('transitions to previous state without re-recording onto history', function()
            m:state('a', {}); m:state('b', {})
            m:transition('a')
            m:transition('b')
            assert.same({ 'a' }, m:getHistory())
            assert.is_true(m:back())
            assert.equal('a', m:current())
            assert.same({}, m:getHistory())  -- history popped, NOT b appended
        end)

        it('threads data through to the previous state', function()
            local got
            m:state('a', { enter = function(d) got = d end })
            m:state('b', {})
            m:transition('a')
            m:transition('b')
            got = nil  -- clear the enter from transition('a')
            m:back({ reason = 'cancel' })
            assert.same({ reason = 'cancel' }, got)
        end)
    end)

    describe('update/draw', function()
        it('forwards update/draw only to the top state', function()
            local up_a, dr_b = 0, 0
            m:state('a', { update = function(dt) up_a = up_a + dt end })
            m:state('b', { draw = function() dr_b = dr_b + 1 end })
            m:transition('a')
            m:update(0.5)
            m:push('b')
            m:update(1.0)     -- goes to b, not a
            m:draw()          -- b.draw
            assert.equal(0.5, up_a)
            assert.equal(1, dr_b)
        end)

        it('is a no-op when the stack is empty', function()
            assert.has_no.errors(function() m:update(0.1) end)
            assert.has_no.errors(function() m:draw() end)
        end)

        it('tolerates states missing some hooks', function()
            m:state('a', {})  -- no hooks at all
            m:transition('a')
            assert.has_no.errors(function() m:update(0.1) end)
            assert.has_no.errors(function() m:draw() end)
        end)
    end)

    describe('clear()', function()
        it('pops all states, firing leave on each top in order', function()
            local leaves = {}
            m:state('a', { leave = function(to) leaves[#leaves+1] = 'a:' .. tostring(to) end })
            m:state('b', { leave = function(to) leaves[#leaves+1] = 'b:' .. tostring(to) end })
            m:transition('a')
            m:push('b')
            m:clear()
            assert.same({ 'b:a', 'a:nil' }, leaves)
            assert.equal(0, m:depth())
        end)
    end)
end)
