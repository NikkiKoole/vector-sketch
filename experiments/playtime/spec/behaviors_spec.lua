-- spec/behaviors_spec.lua
-- The inspector (src/ui/inspector.lua) draws whatever `params` a behavior
-- declares; a malformed row would only show up as a broken panel. Pure spec.

local behaviors = require('src.behaviors')

local kinds = { text = true, numberText = true, number = true, bool = true, choice = true, action = true,
    buttons = true, note = true, color = true, file = true }

describe('behavior params (inspector schema)', function()
    for _, behavior in ipairs(behaviors.allBehaviors) do
        it(behavior.name .. ' declares valid rows', function()
            for i, row in ipairs(behavior.params or {}) do
                local where = behavior.name .. ' row ' .. i
                assert.is_true(kinds[row.kind] == true, where .. ': unknown kind ' .. tostring(row.kind))
                if row.kind == 'action' then
                    assert.are.equal('function', type(row.run), where)
                    assert.is_not_nil(row.label, where)
                else
                    assert.are.equal('string', type(row.key), where)
                end
                if row.kind == 'number' then
                    assert.is_true(row.min < row.max, where)
                    assert.is_true(row.default >= row.min and row.default <= row.max, where)
                end
                if row.kind == 'choice' then
                    assert.is_true(#row.options >= 2, where)
                end
            end
        end)
    end
end)

-- BUG9: the add-behavior panel put a copy of the userData on the body, so the
-- selection (and a Mipo's parts) kept the old thing without the behavior.
describe('behaviors.add', function()
    local function fakeBody(thing, fixtures)
        local ud = { thing = thing }
        return {
            getUserData = function() return ud end,
            getFixtures = function() return fixtures or {} end,
            isDestroyed = function() return false end,
        }
    end

    local function fakeFixture(userData)
        local f = { sensor = false }
        function f.getUserData() return userData end
        function f.setSensor(_, v) f.sensor = v end
        return f
    end

    it('adds to the thing the body already has', function()
        local thing = { id = 'b1' }
        local body = fakeBody(thing)
        behaviors.add(body, 'KEEP_ANGLE')
        assert.are.equal(thing, body:getUserData().thing)
        assert.are.equal('KEEP_ANGLE', thing.behaviors[1].name)
    end)

    it('gives a signal behavior its signal, a door its name, and makes a door walk-through', function()
        local thing = {}
        local shape, sfixture = fakeFixture(nil), fakeFixture({ subtype = 'snap' })
        local body = fakeBody(thing, { shape, sfixture })
        assert.are.equal('signal1', behaviors.add(body, 'SIGNAL_BUTTON').signal)
        assert.are.equal('door1', behaviors.add(body, 'DOOR').door)
        assert.is_true(shape.sensor)
        assert.is_false(sfixture.sensor)
        assert.are.equal(2, #thing.behaviors)
    end)
end)

-- CL9: one way to look a behavior up (signals, doors, Mipo voice and actions had their own)
describe('behaviors.find / all / isSignal', function()
    local function body(list, destroyed)
        local ud = { thing = { behaviors = list } }
        return { getUserData = function() return ud end, isDestroyed = function() return destroyed end }
    end

    it('finds a behavior by name, nil when it has none', function()
        local door = { name = 'DOOR', door = 'door1' }
        assert.are.equal(door, behaviors.find(body({ { name = 'SQUISHY' }, door }), 'DOOR'))
        assert.is_nil(behaviors.find(body({ { name = 'SQUISHY' } }), 'DOOR'))
        assert.is_nil(behaviors.find(body(nil), 'DOOR'))
        assert.is_nil(behaviors.find(body({ door }, true), 'DOOR'))
    end)

    it('lists none for a body without behaviors', function()
        assert.are.same({}, behaviors.all(body(nil)))
    end)

    it('knows a signal behavior by its name and signal', function()
        assert.is_true(behaviors.isSignal({ name = 'SIGNAL_GATE', signal = 'gate1' }))
        assert.is_false(behaviors.isSignal({ name = 'SIGNAL_GATE' }))
        assert.is_false(behaviors.isSignal({ name = 'DOOR', signal = 'x' }))
    end)
end)
