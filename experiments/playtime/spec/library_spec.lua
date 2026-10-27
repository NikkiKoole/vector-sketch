-- spec/library_spec.lua
-- Prefabs (src/library.lua): saving a selection keeps its bodies, behaviors,
-- sfixtures and inner joints (not joints to the outside, not Mipo parts), and
-- placing one twice builds two independent copies with fresh ids where asked.
-- A scene file dropped on the library tab is imported the same way. Copies
-- that hold both ends of a wire get their own signal name (src/signals.lua).
-- Run with: love . --specs spec/library_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local fixtures = require('src.fixtures')
local signals = require('src.signals')
local library = require('src.library')

local NAME = 'spec-prefab'

describe('library prefabs', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        library.delete(NAME)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function add(label, x, behaviors)
        local thing = objectManager.addThing('rectangle', { x = x, y = 100, width = 40, height = 40 })
        thing.label = label
        thing.behaviors = behaviors
        return thing
    end

    local function contraption()
        local button = add('button', 100, { { name = 'SIGNAL_BUTTON', signal = 'door' } })
        local gate = add('gate', 300, { { name = 'SIGNAL_GATE', signal = 'door' } })
        local outside = add('outside', 500)
        joints.createJoint({ jointType = 'revolute', body1 = button.body, body2 = gate.body,
            offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
        joints.createJoint({ jointType = 'revolute', body1 = gate.body, body2 = outside.body,
            offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
        fixtures.createSFixture(gate.body, 0, 0, 'snap', { radius = 10 })
        return button, gate, outside
    end

    local function count(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    it('gathers the selection centred, with only the inner joints', function()
        local button, gate = contraption()
        local prefab = library.gather({ button, gate })
        assert.are.equal(2, #prefab.bodies)
        assert.are.equal(1, #prefab.joints)
        assert.are.equal(0, prefab.bodies[1].position[1] + prefab.bodies[2].position[1])
    end)

    it('names are cleaned and empty selections are refused', function()
        assert.are.equal('my-cart-2', library.cleanName('  My Cart #2 '))
        assert.is_false((library.save('', {})))
        assert.is_false((library.save(NAME, {})))
    end)

    it('a dropped scene file becomes a prefab, without Mipo parts or their joints', function()
        local json = require('vendor.dkjson')
        local scene = {
            version = '1.0', camera = { x = 0, y = 0, scale = 1 }, backdrops = {}, characters = {},
            bodies = {
                { id = 'a', position = { 0, 0 }, fixtures = {} },
                { id = 'b', position = { 200, 0 }, fixtures = {} },
                { id = 'm', position = { 900, 0 }, fixtures = {}, mipoId = 'mipo1' },
            },
            joints = { { id = 'j1', bodyA = 'a', bodyB = 'b' }, { id = 'j2', bodyA = 'b', bodyB = 'm' } },
        }
        local ok, name = library.import('/some/dir/' .. NAME .. '.playtime.json', json.encode(scene))
        assert.is_true(ok)
        assert.are.equal(NAME, name)
        local prefab = library.load(NAME)
        assert.are.equal(2, #prefab.bodies)
        assert.are.equal(1, #prefab.joints)
        assert.are.equal(-100, prefab.bodies[1].position[1])
        assert.is_nil(prefab.camera)
        assert.is_false((library.import('x.playtime.json', 'not json')))
    end)

    it('placing twice builds two copies with their own ids, joints and wires', function()
        local button, gate = contraption()
        assert.is_true((library.save(NAME, { button, gate })))
        assert.is_true(#library.list() >= 1)

        local bodiesBefore, jointsBefore = count(registry.bodies), count(registry.joints)
        local sfixturesBefore = count(registry.sfixtures)
        local wiresBefore = #signals.wires()

        local first = library.place(NAME, 1000, 1000)
        local second = library.place(NAME, 2000, 1000)
        assert.are.equal(2, #first)
        assert.are.equal(2, #second)
        assert.are.equal(bodiesBefore + 4, count(registry.bodies))
        assert.are.equal(jointsBefore + 2, count(registry.joints))
        assert.are.equal(sfixturesBefore + 2, count(registry.sfixtures))

        local ids = { [button.id] = true, [gate.id] = true }
        for _, thing in ipairs({ first[1], first[2], second[1], second[2] }) do
            assert.is_nil(ids[thing.id], 'id reused: ' .. thing.id)
            ids[thing.id] = true
            assert.are.equal(thing.body, registry.getBodyByID(thing.id))
        end

        -- centred on the drop point
        local cx = (first[1].body:getX() + first[2].body:getX()) / 2
        assert.is_true(math.abs(cx - 1000) < 0.01)

        -- each copy's joint holds its own two bodies
        for _, copy in ipairs({ first, second }) do
            local joint = copy[1].body:getJoints()[1]
            local a, b = joint:getBodies()
            assert.is_true((a == copy[1].body and b == copy[2].body) or (a == copy[2].body and b == copy[1].body))
        end

        -- behaviors came along, and each copy got its own signal (door2, door3):
        -- its button opens its own gate only
        assert.are.equal(wiresBefore + 2, #signals.wires())
        local names = {}
        for _, wire in ipairs(signals.wires()) do names[wire.signal] = true end
        assert.is_true(names.door and names.door2 and names.door3)
    end)

    it('a copy with one end of a wire keeps the name and joins that circuit', function()
        local button, gate = contraption()
        assert.is_true((library.save(NAME, { button })))
        local copy = library.place(NAME, 1000, 1000)
        assert.are.equal('door', copy[1].behaviors[1].signal)
        assert.are.equal(2, #signals.wires())
        assert.is_not_nil(gate)
    end)

    it('editor clone: own behaviors table, own signal for a whole contraption', function()
        local sceneIO = require('src.io')
        local button, gate = contraption()
        local cloned = sceneIO.cloneSelection({ button, gate }, world)
        local names = {}
        for _, thing in ipairs(cloned) do
            assert.are_not.equal(button.behaviors, thing.behaviors)
            names[thing.behaviors[1].signal] = true
        end
        assert.is_true(names.door2)
        assert.are.equal('door', button.behaviors[1].signal)
    end)
end)
