-- spec/integration_spec.lua
-- Real-world integration tests: create bodies, joints, fixtures, save/load, flip, destroy
-- Tests exercise the public API as a user would, without knowing internals.
-- Run with: love . --specs spec/integration_spec.lua

if not love then return end

-- Fresh-require modules to avoid stale state
package.loaded['src.registry'] = nil
package.loaded['src.object-manager'] = nil
package.loaded['src.joints'] = nil
package.loaded['src.fixtures'] = nil
package.loaded['src.io'] = nil
package.loaded['src.state'] = nil
package.loaded['src.physics.snap'] = nil

local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local fixtures = require('src.fixtures')
local sceneIO = require('src.io')
local state = require('src.state')
local utils = require('src.utils')
local snap = require('src.physics.snap')

-- ─── Helpers ───

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * 100, true)
end

local function makeCam()
    local camState = { x = 0, y = 0, scale = 1 }
    return {
        getTranslation = function() return camState.x, camState.y end,
        getScale = function() return camState.scale end,
        getRotation = function() return 0 end,
        setTranslation = function(_, x, y) camState.x = x; camState.y = y end,
        setScale = function(_, s) camState.scale = s end,
    }
end

local function addBody(shapeType, x, y, opts)
    opts = opts or {}
    return objectManager.addThing(shapeType, {
        x = x or 100, y = y or 100,
        bodyType = opts.bodyType or 'dynamic',
        radius = opts.radius or 20,
        width = opts.width or 40,
        width2 = opts.width2 or 40,
        width3 = opts.width3 or 40,
        height = opts.height or 40,
        height2 = opts.height2 or 40,
        height3 = opts.height3 or 40,
        height4 = opts.height4 or 40,
        label = opts.label or '',
    })
end

local function bodyCount()
    return utils.tablelength(registry.bodies)
end

local function jointCount()
    return utils.tablelength(registry.joints)
end

local function sfCount()
    return utils.tablelength(registry.sfixtures)
end

-- ─── Setup ───

describe("integration: object lifecycle", function()

    before_each(function()
        state.physicsWorld = makeWorld()
        registry.reset()
    end)

    after_each(function()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
    end)

    -- ═══════════════════════════════════════════════════════
    -- BODY CREATION
    -- ═══════════════════════════════════════════════════════

    describe("body creation", function()
        it("creates a rectangle body and registers it", function()
            local thing = addBody('rectangle', 100, 200)
            assert.is_not_nil(thing)
            assert.is_not_nil(thing.id)
            assert.is_not_nil(thing.body)
            assert.are.equal('rectangle', thing.shapeType)
            assert.are.equal(1, bodyCount())
            assert.is_not_nil(registry.getBodyByID(thing.id))
        end)

        it("creates all standard shape types without error", function()
            local shapeTypes = { 'circle', 'rectangle', 'triangle', 'pentagon',
                'hexagon', 'capsule', 'trapezium', 'itriangle' }
            for _, st in ipairs(shapeTypes) do
                local thing = addBody(st, 100, 100)
                assert.is_not_nil(thing, "failed to create " .. st)
                assert.are.equal(st, thing.shapeType)
            end
            assert.are.equal(#shapeTypes, bodyCount())
        end)

        it("creates bodies at the correct position", function()
            local thing = addBody('circle', 300, 500)
            local bx, by = thing.body:getPosition()
            assert.is_near(300, bx, 0.1)
            assert.is_near(500, by, 0.1)
        end)

        it("each body gets a unique ID", function()
            local ids = {}
            for _ = 1, 20 do
                local thing = addBody('circle', 0, 0)
                assert.is_nil(ids[thing.id], "duplicate ID: " .. thing.id)
                ids[thing.id] = true
            end
        end)

        it("creates static and kinematic bodies", function()
            local s = addBody('rectangle', 0, 0, { bodyType = 'static' })
            local k = addBody('rectangle', 0, 0, { bodyType = 'kinematic' })
            assert.are.equal('static', s.body:getType())
            assert.are.equal('kinematic', k.body:getType())
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- BODY DESTRUCTION & REGISTRY CLEANUP
    -- ═══════════════════════════════════════════════════════

    describe("body destruction", function()
        it("removes body from registry when destroyed", function()
            local thing = addBody('rectangle', 0, 0)
            local id = thing.id
            assert.are.equal(1, bodyCount())

            objectManager.destroyBody(thing.body)

            assert.are.equal(0, bodyCount())
            assert.is_nil(registry.getBodyByID(id))
        end)

        it("cleans up joints when body is destroyed", function()
            local t1 = addBody('rectangle', 0, 0)
            local t2 = addBody('rectangle', 100, 0)
            joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })
            assert.are.equal(1, jointCount())

            objectManager.destroyBody(t1.body)

            assert.are.equal(0, jointCount())
            -- t2 should still exist
            assert.are.equal(1, bodyCount())
            assert.is_not_nil(registry.getBodyByID(t2.id))
        end)

        it("cleans up sfixtures when body is destroyed", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            assert.are.equal(1, sfCount())

            objectManager.destroyBody(thing.body)

            assert.are.equal(0, sfCount())
            assert.are.equal(0, bodyCount())
        end)

        it("handles rapid create-destroy cycles without leaks", function()
            for _ = 1, 50 do
                local thing = addBody('circle', 0, 0)
                objectManager.destroyBody(thing.body)
            end
            assert.are.equal(0, bodyCount())
            assert.are.equal(0, jointCount())
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- BODY RECREATION (shape change preserves state)
    -- ═══════════════════════════════════════════════════════

    describe("body recreation", function()
        it("preserves position when changing shape", function()
            local thing = addBody('circle', 250, 350, { radius = 20 })
            thing.body:setAngle(math.rad(45))

            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'circle', radius = 40
            })

            local nx, ny = newThing.body:getPosition()
            assert.is_near(250, nx, 0.1)
            assert.is_near(350, ny, 0.1)
            assert.is_near(math.rad(45), newThing.body:getAngle(), 0.001)
        end)

        it("preserves velocity when changing shape", function()
            local thing = addBody('rectangle', 0, 0)
            thing.body:setLinearVelocity(100, -50)
            thing.body:setAngularVelocity(2.5)

            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'rectangle', width = 80, height = 80
            })

            local vx, vy = newThing.body:getLinearVelocity()
            assert.is_near(100, vx, 0.1)
            assert.is_near(-50, vy, 0.1)
            assert.is_near(2.5, newThing.body:getAngularVelocity(), 0.01)
        end)

        it("preserves fixed rotation flag", function()
            local thing = addBody('rectangle', 0, 0)
            thing.body:setFixedRotation(true)

            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'rectangle', width = 60, height = 60
            })

            assert.is_true(newThing.body:isFixedRotation())
        end)

        it("old body is destroyed after recreation", function()
            local thing = addBody('circle', 0, 0)
            local oldBody = thing.body

            objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'circle', radius = 50
            })

            assert.is_true(oldBody:isDestroyed())
            assert.are.equal(1, bodyCount())
        end)

        it("keeps the same ID after recreation", function()
            local thing = addBody('rectangle', 0, 0)
            local originalId = thing.id

            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'circle', radius = 30
            })

            assert.are.equal(originalId, newThing.id)
            assert.is_not_nil(registry.getBodyByID(originalId))
        end)

        it("updates dimensions after recreation", function()
            local thing = addBody('rectangle', 0, 0, { width = 40, height = 40 })

            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'rectangle', width = 100, height = 200
            })

            assert.are.equal(100, newThing.width)
            assert.are.equal(200, newThing.height)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- JOINTS
    -- ═══════════════════════════════════════════════════════

    describe("joint creation", function()
        it("creates a revolute joint between two bodies", function()
            local t1 = addBody('rectangle', 0, 0)
            local t2 = addBody('rectangle', 100, 0)

            local joint = joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })

            assert.is_not_nil(joint)
            assert.are.equal('revolute', joint:getType())
            assert.are.equal(1, jointCount())
            assert.is_not_nil(joint:getUserData())
            assert.is_not_nil(joint:getUserData().id)
        end)

        it("creates distance and weld joints", function()
            for _, jt in ipairs({ 'distance', 'weld' }) do
                local t1 = addBody('circle', 0, 0)
                local t2 = addBody('circle', 100, 0)
                local joint = joints.createJoint({
                    body1 = t1.body, body2 = t2.body,
                    jointType = jt,
                    p1 = { 0, 0 }, p2 = { 0, 0 },
                })
                assert.is_not_nil(joint, "failed to create " .. jt)
            end
        end)

        it("joint is registered with unique ID", function()
            local t1 = addBody('rectangle', 0, 0)
            local t2 = addBody('rectangle', 100, 0)
            local t3 = addBody('rectangle', 200, 0)

            local j1 = joints.createJoint({ body1 = t1.body, body2 = t2.body, jointType = 'revolute' })
            local j2 = joints.createJoint({ body1 = t2.body, body2 = t3.body, jointType = 'revolute' })

            assert.are_not.equal(j1:getUserData().id, j2:getUserData().id)
            assert.are.equal(2, jointCount())
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- SFIXTURES
    -- ═══════════════════════════════════════════════════════

    describe("sfixture lifecycle", function()
        it("creates an anchor sfixture on a body", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })

            assert.is_not_nil(sf)
            assert.is_true(sf:isSensor())
            assert.are.equal('anchor', sf:getUserData().subtype)
            assert.are.equal(1, sfCount())
        end)

        it("creates snap and resource sfixtures", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })

            fixtures.createSFixture(thing.body, 0, 0, 'snap', { radius = 10 })
            fixtures.createSFixture(thing.body, 10, 10, 'anchor', { radius = 10 })

            assert.are.equal(2, sfCount())
        end)

        it("sfixture is destroyed and unregistered via destroyFixture", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            local sfId = sf:getUserData().id

            assert.are.equal(1, sfCount())
            fixtures.destroyFixture(sf)
            assert.are.equal(0, sfCount())
            assert.is_nil(registry.getSFixtureByID(sfId))
        end)

        it("body with sfixtures has correct fixture ordering", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            -- Body should have 1 collision fixture
            local initialFixtures = #thing.body:getFixtures()

            fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            fixtures.createSFixture(thing.body, 10, 0, 'snap', { radius = 10 })

            -- Now should have collision + 2 sfixtures
            assert.are.equal(initialFixtures + 2, #thing.body:getFixtures())
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- FLIP OPERATIONS
    -- ═══════════════════════════════════════════════════════

    describe("flip operations", function()
        it("flips a single body on X axis", function()
            local thing = addBody('rectangle', 100, 200, { width = 40, height = 60 })
            thing.mirrorX = 1
            thing.mirrorY = 1

            local flipped = objectManager.flipThing(thing, 'x', false)

            assert.is_not_nil(flipped)
            -- mirrorX should toggle
            assert.are.equal(-1, flipped.mirrorX)
            -- position stays same for single non-recursive flip
            local fx, fy = flipped.body:getPosition()
            assert.is_near(100, fx, 0.1)
            assert.is_near(200, fy, 0.1)
        end)

        it("flips a single body on Y axis", function()
            local thing = addBody('rectangle', 100, 200)
            thing.mirrorX = 1
            thing.mirrorY = 1

            objectManager.flipThing(thing, 'y', false)

            assert.are.equal(-1, thing.mirrorY)
            assert.are.equal(1, thing.mirrorX) -- X unchanged
        end)

        it("double flip restores mirror flags", function()
            local thing = addBody('rectangle', 100, 200)
            thing.mirrorX = 1
            thing.mirrorY = 1

            objectManager.flipThing(thing, 'x', false)
            objectManager.flipThing(thing, 'x', false)

            assert.are.equal(1, thing.mirrorX)
        end)

        it("flips a body with vertices (polygon)", function()
            local thing = addBody('hexagon', 100, 100, { radius = 30 })
            assert.is_not_nil(thing.vertices)
            local origVerts = utils.shallowCopy(thing.vertices)

            objectManager.flipThing(thing, 'x', false)

            -- X coords should be negated
            for i = 1, #origVerts, 2 do
                assert.is_near(-origVerts[i], thing.vertices[i], 0.01)
            end
        end)

        it("recursive flip flips connected bodies", function()
            local t1 = addBody('rectangle', 0, 0)
            local t2 = addBody('rectangle', 100, 0)
            t1.mirrorX = 1
            t2.mirrorX = 1

            joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })

            objectManager.flipThing(t1, 'x', true)

            -- Both bodies should be flipped
            assert.are.equal(-1, t1.mirrorX)
            assert.are.equal(-1, t2.mirrorX)

            -- t2 should have moved to the other side of t1
            local t2x = t2.body:getX()
            assert.is_true(t2x < 0, "t2 should be on opposite side after flip")
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- RECREATION WITH JOINTS
    -- ═══════════════════════════════════════════════════════

    describe("body recreation with joints", function()
        it("joints survive body recreation", function()
            local t1 = addBody('rectangle', 0, 0, { width = 40, height = 40 })
            local t2 = addBody('rectangle', 100, 0, { width = 40, height = 40 })

            joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })
            assert.are.equal(1, jointCount())

            -- Recreate t1 with different size
            objectManager.recreateThingFromBody(t1.body, {
                shapeType = 'rectangle', width = 80, height = 80
            })

            -- Joint should still exist (reattached)
            assert.are.equal(1, jointCount())
            assert.are.equal(2, bodyCount())
        end)

        it("sfixtures survive body recreation", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            local sfId = sf:getUserData().id

            assert.are.equal(1, sfCount())

            -- Recreate with different size
            local newThing = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'rectangle', width = 120, height = 120
            })

            -- SFixture should still be registered
            assert.are.equal(1, sfCount())
            assert.is_not_nil(registry.getSFixtureByID(sfId))
            -- And be on the new body
            local newFixtures = newThing.body:getFixtures()
            local foundSf = false
            for _, f in ipairs(newFixtures) do
                local ud = f:getUserData()
                if ud and ud.id == sfId then foundSf = true end
            end
            assert.is_true(foundSf, "sfixture not found on recreated body")
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- SAVE/LOAD ROUND-TRIP WITH LIVE OBJECTS
    -- ═══════════════════════════════════════════════════════

    describe("save/load round-trip", function()
        local cam

        before_each(function()
            cam = makeCam()
        end)

        it("round-trips a single body", function()
            local thing = addBody('rectangle', 150, 250, {
                width = 60, height = 40, label = 'test-body'
            })
            thing.body:getFixtures()[1]:setDensity(3.0)
            thing.body:getFixtures()[1]:setFriction(0.5)

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)

            -- Load into fresh world
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            local restoredData = sceneIO.gatherSaveData(world2, cam)

            assert.are.equal(1, #restoredData.bodies)
            assert.are.equal('test-body', restoredData.bodies[1].label)
            assert.are.equal('rectangle', restoredData.bodies[1].shapeType)
            assert.is_near(150, restoredData.bodies[1].position[1], 0.1)
            assert.is_near(250, restoredData.bodies[1].position[2], 0.1)

            world2:destroy()
        end)

        it("round-trips fixture physics properties", function()
            local thing = addBody('circle', 0, 0, { radius = 25 })
            local fix = thing.body:getFixtures()[1]
            fix:setDensity(5.0)
            fix:setFriction(0.8)
            fix:setRestitution(0.6)

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            local restoredData = sceneIO.gatherSaveData(world2, cam)
            local sfd = restoredData.bodies[1].sharedFixtureData

            assert.is_near(5.0, sfd.density, 0.01)
            assert.is_near(0.8, sfd.friction, 0.01)
            assert.is_near(0.6, sfd.restitution, 0.01)

            world2:destroy()
        end)

        it("round-trips body type (static, dynamic, kinematic)", function()
            addBody('rectangle', 0, 0, { bodyType = 'static', label = 's' })
            addBody('rectangle', 100, 0, { bodyType = 'dynamic', label = 'd' })
            addBody('rectangle', 200, 0, { bodyType = 'kinematic', label = 'k' })

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            local restoredData = sceneIO.gatherSaveData(world2, cam)
            local types = {}
            for _, b in ipairs(restoredData.bodies) do types[b.label] = b.bodyType end

            assert.are.equal('static', types['s'])
            assert.are.equal('dynamic', types['d'])
            assert.are.equal('kinematic', types['k'])

            world2:destroy()
        end)

        it("round-trips multiple bodies with joints", function()
            local t1 = addBody('rectangle', 0, 0, { label = 'a' })
            local t2 = addBody('rectangle', 100, 0, { label = 'b' })
            joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)

            assert.are.equal(2, #saveData.bodies)
            assert.are.equal(1, #saveData.joints)

            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            assert.are.equal(2, bodyCount())
            assert.are.equal(1, jointCount())

            world2:destroy()
        end)

        it("round-trips body angle", function()
            local thing = addBody('rectangle', 0, 0)
            thing.body:setAngle(math.rad(73))

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)
            local restoredData = sceneIO.gatherSaveData(world2, cam)

            assert.is_near(math.rad(73), restoredData.bodies[1].angle, 0.001)

            world2:destroy()
        end)

        it("round-trips sfixture data", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 5, 10, 'anchor', { radius = 10 })
            local sfId = sf:getUserData().id

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)

            -- Should have one body with fixtures
            assert.are.equal(1, #saveData.bodies)
            assert.is_true(#saveData.bodies[1].fixtures > 0)

            -- Verify the sfixture data is in the save (id lives inside userData)
            local foundSf = false
            for _, fdata in ipairs(saveData.bodies[1].fixtures) do
                if fdata.userData and fdata.userData.id == sfId then
                    foundSf = true
                    assert.are.equal('anchor', fdata.userData.subtype)
                end
            end
            assert.is_true(foundSf, "sfixture not found in save data")

            -- Load and verify
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            assert.are.equal(1, sfCount())

            world2:destroy()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- EDGE CASES & BUG HUNTING
    -- ═══════════════════════════════════════════════════════

    describe("edge cases", function()
        it("body with empty label defaults gracefully", function()
            local thing = addBody('circle', 0, 0, { label = '' })
            assert.are.equal('', thing.label)
        end)

        it("destroying body with multiple joints cleans all", function()
            local t1 = addBody('rectangle', 0, 0)
            local t2 = addBody('rectangle', 100, 0)
            local t3 = addBody('rectangle', 200, 0)

            joints.createJoint({ body1 = t1.body, body2 = t2.body, jointType = 'revolute' })
            joints.createJoint({ body1 = t1.body, body2 = t3.body, jointType = 'weld' })

            assert.are.equal(2, jointCount())

            -- Destroy t1 which connects to both
            objectManager.destroyBody(t1.body)

            assert.are.equal(0, jointCount())
            assert.are.equal(2, bodyCount()) -- t2 and t3 survive
        end)

        it("destroying body with multiple sfixtures cleans all", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, -10, 0, 'anchor', { radius = 10 })
            fixtures.createSFixture(thing.body, 10, 0, 'anchor', { radius = 10 })
            fixtures.createSFixture(thing.body, 0, -10, 'snap', { radius = 10 })

            assert.are.equal(3, sfCount())

            objectManager.destroyBody(thing.body)

            assert.are.equal(0, sfCount())
        end)

        it("recreating a destroyed body returns nil gracefully", function()
            local thing = addBody('rectangle', 0, 0)
            thing.body:destroy()

            local result = objectManager.recreateThingFromBody(thing.body, {
                shapeType = 'circle', radius = 20
            })

            assert.is_nil(result)
        end)

        it("create-destroy-create cycle keeps registry clean", function()
            local thing1 = addBody('circle', 0, 0)
            objectManager.destroyBody(thing1.body)
            assert.are.equal(0, bodyCount())

            local thing2 = addBody('rectangle', 0, 0)
            assert.are.equal(1, bodyCount())
            assert.is_not_nil(registry.getBodyByID(thing2.id))
        end)

        it("groupIndex is preserved through save/load", function()
            local cam = makeCam()
            local thing = addBody('rectangle', 0, 0)
            local fix = thing.body:getFixtures()[1]
            fix:setGroupIndex(-5)

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            -- Check the restored body's fixture groupIndex
            local bodies = world2:getBodies()
            local found = false
            for _, body in ipairs(bodies) do
                local bfixes = body:getFixtures()
                for _, f in ipairs(bfixes) do
                    if not f:getUserData() then -- collision fixture
                        assert.are.equal(-5, f:getGroupIndex())
                        found = true
                    end
                end
            end
            assert.is_true(found, "no collision fixture found to check groupIndex")

            world2:destroy()
        end)

        it("sensor flag is preserved through save/load", function()
            local cam = makeCam()
            local thing = addBody('rectangle', 0, 0)
            local fix = thing.body:getFixtures()[1]
            fix:setSensor(true)

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            local bodies = world2:getBodies()
            local found = false
            for _, body in ipairs(bodies) do
                local bfixes = body:getFixtures()
                for _, f in ipairs(bfixes) do
                    if not f:getUserData() then
                        assert.is_true(f:isSensor())
                        found = true
                    end
                end
            end
            assert.is_true(found, "no collision fixture found to check sensor")

            world2:destroy()
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- SIMULATION STABILITY
    -- ═══════════════════════════════════════════════════════

    describe("simulation stability", function()
        it("jointed bodies don't explode after recreation", function()
            local t1 = addBody('rectangle', 0, 0, { bodyType = 'static', width = 40, height = 40 })
            local t2 = addBody('rectangle', 50, 0, { width = 40, height = 40 })

            joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })

            -- Recreate t2
            local newT2 = objectManager.recreateThingFromBody(t2.body, {
                shapeType = 'rectangle', width = 60, height = 60
            })

            -- Step simulation
            for _ = 1, 120 do
                state.physicsWorld:update(1 / 60)
            end

            -- t2 should still be near t1 (constrained by joint)
            local dx = newT2.body:getX() - t1.body:getX()
            local dy = newT2.body:getY() - t1.body:getY()
            local dist = math.sqrt(dx * dx + dy * dy)
            assert.is_true(dist < 200, "body flew away after recreation: dist=" .. dist)
        end)

        it("bodies with fixtures settle on ground", function()
            -- Ground
            addBody('rectangle', 0, 500, { bodyType = 'static', width = 2000, height = 20 })

            -- Falling body
            local thing = addBody('circle', 0, 0, { radius = 15 })

            for _ = 1, 300 do
                state.physicsWorld:update(1 / 60)
            end

            -- Should have settled near ground
            assert.is_true(thing.body:getY() > 400, "body didn't fall")
            assert.is_true(thing.body:getY() < 510, "body fell through ground")
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- SNAP STATE THROUGH SAVE/LOAD
    -- ═══════════════════════════════════════════════════════

    describe("snap state", function()
        local cam

        before_each(function()
            cam = makeCam()
        end)

        it("snap fixtures are populated after creating snap sfixtures", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, 0, 0, 'snap', { radius = 10 })

            assert.are.equal(1, #state.snap.fixtures)
            assert.are.equal('snap', state.snap.fixtures[1]:getUserData().subtype)
        end)

        it("snap fixtures are cleared after registry.reset()", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, 0, 0, 'snap', { radius = 10 })
            assert.are.equal(1, #state.snap.fixtures)

            registry.reset()

            assert.are.equal(0, #state.snap.fixtures)
        end)

        it("activeJoints are cleared on resetList()", function()
            -- Manually insert a dummy to prove it clears
            table.insert(state.snap.activeJoints, "dummy")
            assert.are.equal(1, #state.snap.activeJoints)

            snap.resetList()

            assert.are.equal(0, #state.snap.activeJoints)
        end)

        it("cooldownList is cleared on resetList()", function()
            state.snap.cooldownList["fake-fixture"] = 999
            assert.is_not_nil(state.snap.cooldownList["fake-fixture"])

            snap.resetList()

            assert.is_nil(next(state.snap.cooldownList))
        end)

        it("snap fixtures survive save/load round-trip", function()
            local t1 = addBody('rectangle', -100, 0, { width = 80, height = 80 })
            local t2 = addBody('rectangle', 100, 0, { width = 80, height = 80 })
            fixtures.createSFixture(t1.body, 0, 0, 'snap', { radius = 10 })
            fixtures.createSFixture(t2.body, 0, 0, 'snap', { radius = 10 })

            assert.are.equal(2, #state.snap.fixtures)

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)

            -- Load into fresh world
            local world2 = makeWorld()
            registry.reset()
            sceneIO.buildWorld(saveData, world2, cam)

            -- snap.fixtures should be repopulated via registry.registerSFixture
            assert.are.equal(2, #state.snap.fixtures)
            for i = 1, #state.snap.fixtures do
                assert.are.equal('snap', state.snap.fixtures[i]:getUserData().subtype)
            end

            world2:destroy()
        end)

        it("activeJoints and cooldownList are clean after load", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, 0, 0, 'snap', { radius = 10 })

            -- Pollute snap state
            table.insert(state.snap.activeJoints, "stale-joint")
            state.snap.cooldownList["stale-fixture"] = 999

            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)

            local world2 = makeWorld()
            -- buildWorld calls snap.resetList() which should clear both
            sceneIO.buildWorld(saveData, world2, cam)

            assert.are.equal(0, #state.snap.activeJoints)
            assert.is_nil(next(state.snap.cooldownList))

            world2:destroy()
        end)

        it("snap config values have correct defaults", function()
            assert.are.equal(140, state.snap.snapDistance)
            assert.are.equal(100000, state.snap.jointBreakThreshold)
            assert.are.equal(0.5, state.snap.cooldownTime)
            assert.is_true(state.snap.onlyConnectWhenInteracted)
            assert.is_true(state.snap.onlyBreakWhenInteracted)
        end)

        it("multiple snap sfixtures on same body are all tracked", function()
            local thing = addBody('rectangle', 0, 0, { width = 120, height = 120 })
            fixtures.createSFixture(thing.body, -20, 0, 'snap', { radius = 10 })
            fixtures.createSFixture(thing.body, 20, 0, 'snap', { radius = 10 })
            fixtures.createSFixture(thing.body, 0, -20, 'snap', { radius = 10 })

            assert.are.equal(3, #state.snap.fixtures)
        end)

        it("non-snap sfixtures don't appear in snap.fixtures", function()
            local thing = addBody('rectangle', 0, 0, { width = 80, height = 80 })
            fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            fixtures.createSFixture(thing.body, 10, 0, 'snap', { radius = 10 })

            assert.are.equal(1, #state.snap.fixtures)
            assert.are.equal('snap', state.snap.fixtures[1]:getUserData().subtype)
        end)
    end)
end)
