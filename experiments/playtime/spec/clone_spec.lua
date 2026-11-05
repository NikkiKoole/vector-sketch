-- spec/clone_spec.lua
-- Clone (the editor's copy of a selection, src/library.lua clone): copies 50 down and to
-- the right, joints between them with their settings, links pointing at the copies,
-- a Mipo whole and in its pose with an id of its own. Links to a joint or anchor that didn't come
-- along are dropped: the copy is on its own, not bent or drawn by the original's rig.
-- Run with: love . --specs spec/clone_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local fixtures = require('src.fixtures')
local sceneIO = require('src.io')
local library = require('src.library')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')

local function clone(things)
    if library.clone then return library.clone(things) end
    return sceneIO.cloneSelection(things, state.physicsWorld) -- before CL17
end

describe('clone', function()
    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        mipoRegistry.reset()
    end)

    after_each(function()
        mipoRegistry.reset()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('copies two bodies and the motor joint between them, 50 down and right', function()
        local a = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40, label = 'a' })
        local b = objectManager.addThing('rectangle', { x = 100, y = 0, width = 40, height = 40, label = 'b' })
        local j = joints.createJoint({ body1 = a.body, body2 = b.body, jointType = 'revolute' })
        j:setMotorEnabled(true); j:setMotorSpeed(2); j:setMaxMotorTorque(300)
        local copies = clone({ a, b })
        assert.are.equal(2, #copies)
        local copyA
        for _, t in ipairs(copies) do
            assert.are_not.equal(a.id, t.id); assert.are_not.equal(b.id, t.id)
            assert.are.equal(t.body, registry.getBodyByID(t.id))
            if t.label == 'a' then copyA = t end
        end
        assert.is_near(50, copyA.body:getX(), 1e-3)
        assert.is_near(50, copyA.body:getY(), 1e-3)
        local cj = copyA.body:getJoints()[1]
        assert.are_not.equal(j, cj)
        assert.is_true(cj:isMotorEnabled())
        assert.is_near(2, cj:getMotorSpeed(), 1e-6)
        assert.are.equal(2, #state.physicsWorld:getJoints())
    end)

    it('points a copied ribbon at the copied joint', function()
        local a = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local b = objectManager.addThing('rectangle', { x = 100, y = 0, width = 40, height = 40 })
        local j = joints.createJoint({ body1 = a.body, body2 = b.body, jointType = 'revolute' })
        local ribbon = fixtures.createSFixture(a.body, 0, 0, 'connected-texture', { radius = 10 })
        ribbon:getUserData().extra.nodes = { { id = joints.getJointId(j), type = 'joint' } }
        local copies = clone({ a, b })
        local copiedJointId
        for _, joint in ipairs(state.physicsWorld:getJoints()) do
            if joint ~= j then copiedJointId = joints.getJointId(joint) end
        end
        local found
        for _, t in ipairs(copies) do
            for _, f in ipairs(t.body:getFixtures()) do
                local ud = f:getUserData()
                if ud and ud.subtype == 'connected-texture' then found = ud end
            end
        end
        assert.is_not_nil(found)
        assert.are_not.equal(ribbon:getUserData().id, found.id)
        assert.are.equal(copiedJointId, found.extra.nodes[1].id)
    end)

    it('copies a Mipo whole, in its pose, with its own id', function()
        local mipo = CM.createCharacter('humanoid', 0, 0, 0.3)
        mipo.parts.luarm.body:setAngle(1.1) -- an arm up
        local things = {}
        for _, part in pairs(mipo.parts) do things[#things + 1] = part end
        local partCount = #things
        local copies = clone(things)
        assert.are.equal(partCount, #copies)
        local copy
        for id, instance in pairs(mipoRegistry.getAll()) do
            if id ~= mipo.id then copy = instance end
        end
        assert.is_not_nil(copy)
        assert.is_near(1.1, copy.parts.luarm.body:getAngle(), 1e-3)
        assert.is_near(mipo.parts.torso1.body:getX() + 50, copy.parts.torso1.body:getX(), 1e-3)
        assert.are.same(mipo.dna.creation, copy.dna.creation)
    end)
    it("drops a copied ribbon's link to a joint that didn't come along", function()
        local a = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local b = objectManager.addThing('rectangle', { x = 100, y = 0, width = 40, height = 40 })
        local j = joints.createJoint({ body1 = a.body, body2 = b.body, jointType = 'revolute' })
        local ribbon = fixtures.createSFixture(a.body, 0, 0, 'connected-texture', { radius = 10 })
        local anchor = fixtures.createSFixture(a.body, 5, 0, 'anchor', { radius = 5 })
        ribbon:getUserData().extra.nodes = {
            { id = joints.getJointId(j), type = 'joint' },
            { id = anchor:getUserData().id, type = 'anchor' },
        }
        local copies = clone({ a })
        local found
        for _, f in ipairs(copies[1].body:getFixtures()) do
            local ud = f:getUserData()
            if ud and ud.subtype == 'connected-texture' then found = ud end
        end
        assert.are.equal(2, #found.extra.nodes)
        assert.is_nil(found.extra.nodes[1].id, 'the joint between a and b was not copied')
        assert.is_truthy(registry.getSFixtureByID(found.extra.nodes[2].id), 'its own anchor, copied')
        assert.are_not.equal(anchor:getUserData().id, found.extra.nodes[2].id)
    end)

    it("leaves a mesh copied without its rig unbent by the original's bones", function()
        local camera = require('src.camera')
        sceneIO.load(love.filesystem.read('scripts/tech/hoop.playtime.json'), state.physicsWorld, camera.getInstance())
        local mesh
        for _, f in pairs(registry.sfixtures) do
            if f:getUserData().subtype == 'meshusert' then mesh = f end
        end
        local copies = clone({ mesh:getBody():getUserData().thing })
        assert.are.equal(1, #copies)
        local copied
        for _, f in ipairs(copies[1].body:getFixtures()) do
            local ud = f:getUserData()
            if ud and ud.subtype == 'meshusert' then copied = ud end
        end
        local count = 0
        for _, list in ipairs(copied.extra.influences) do
            for _, infl in ipairs(list) do
                count = count + 1
                assert.is_nil(infl.body, 'an influence still on a body of the original')
            end
        end
        assert.is_true(count > 0, 'the weights are kept')
        for _, node in ipairs(copied.extra.nodes) do assert.is_nil(node.id) end
        -- the RESOURCE link stays: the picture is shared, not the rig
        assert.are.equal(mesh:getUserData().extra.resourceId, copied.extra.resourceId)
    end)
end)
