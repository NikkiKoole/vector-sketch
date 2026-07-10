-- Specs for src/physics/snap.lua core logic — snap-joint creation,
-- force breaking, cooldowns, stale-body guards, and scene-load rebuild.
-- Previously only resetList/registration were covered.

if not love then return end

local snap = require('src.physics.snap')
local fixtures = require('src.fixtures')
local registry = require('src.registry')
local state = require('src.state')
local subtypes = require('src.subtypes')
local utils = require('src.utils')

describe('snap core', function()
    local world
    local prevSnapConfig

    local function makeBody(id, x, y)
        local body = love.physics.newBody(world, x, y, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
        body:setUserData({ thing = { id = id, body = body } })
        registry.registerBody(id, body)
        return body
    end

    -- state.snap.fixtures is rebuilt from a hash on every registration, so
    -- its order is not stable — always look a body's snap point up by owner.
    local function snapPointOf(body)
        for i = 1, #state.snap.fixtures do
            if state.snap.fixtures[i]:getUserData().extra.at == body then
                return state.snap.fixtures[i]
            end
        end
    end

    local function addSnapPoint(body)
        fixtures.createSFixture(body, 0, 0, subtypes.SNAP, { radius = 8 })
        return snapPointOf(body)
    end

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        snap.resetList()
        prevSnapConfig = {
            onlyConnect = state.snap.onlyConnectWhenInteracted,
            onlyBreak = state.snap.onlyBreakWhenInteracted,
            threshold = state.snap.jointBreakThreshold,
        }
        state.snap.onlyConnectWhenInteracted = false
        state.snap.onlyBreakWhenInteracted = false
    end)

    after_each(function()
        state.snap.onlyConnectWhenInteracted = prevSnapConfig.onlyConnect
        state.snap.onlyBreakWhenInteracted = prevSnapConfig.onlyBreak
        state.snap.jointBreakThreshold = prevSnapConfig.threshold
        snap.resetList()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
        registry.reset()
    end)

    describe('checkForSnaps (via update)', function()
        it('joins two nearby free snap points with a revolute joint', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            local fixA = addSnapPoint(bodyA)
            addSnapPoint(bodyB)

            snap.update(1 / 60)

            assert.equal(1, #state.snap.activeJoints)
            local joint = state.snap.activeJoints[1]
            assert.equal('revolute', joint:getType())
            -- both snap points marked connected, pointing at each other's body
            assert.equal(bodyB, fixA:getUserData().extra.to)
            -- and the joint is registered under its generated id
            local id = joint:getUserData().id
            assert.equal(joint, registry.getJointByID(id))
        end)

        it('does not join snap points beyond snapDistance', function()
            addSnapPoint(makeBody('snap-a', 0, 0))
            addSnapPoint(makeBody('snap-b', state.snap.snapDistance + 200, 0))

            snap.update(1 / 60)

            assert.equal(0, #state.snap.activeJoints)
        end)

        it('respects onlyConnectWhenInteracted', function()
            state.snap.onlyConnectWhenInteracted = true
            addSnapPoint(makeBody('snap-a', 0, 0))
            addSnapPoint(makeBody('snap-b', 50, 0))

            snap.update(1 / 60) -- nothing is grabbed by a pointer

            assert.equal(0, #state.snap.activeJoints)
        end)

        it('respects cooldowns and snaps again once they expire', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            local fixA = addSnapPoint(bodyA)
            local fixB = addSnapPoint(bodyB)

            local farFuture = love.timer.getTime() + 999
            state.snap.cooldownList[fixA] = farFuture
            state.snap.cooldownList[fixB] = farFuture
            snap.update(1 / 60)
            assert.equal(0, #state.snap.activeJoints)

            state.snap.cooldownList = {}
            snap.update(1 / 60)
            assert.equal(1, #state.snap.activeJoints)
        end)

        it('skips snap points whose bound body was destroyed (stale ref)', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            local fixA = addSnapPoint(bodyA)
            addSnapPoint(bodyB)

            -- Simulate the stale state the old crash TODO recorded: extra.at
            -- pointing at a destroyed body without a rebuild in between.
            local doomed = love.physics.newBody(world, 0, 0, 'dynamic')
            doomed:destroy()
            local ud = fixA:getUserData()
            ud.extra.at = doomed
            fixA:setUserData(ud)

            assert.has_no.errors(function() snap.update(1 / 60) end)
            assert.equal(0, #state.snap.activeJoints)
        end)
    end)

    describe('checkForJointBreaks (via update)', function()
        it('breaks an overstressed snap joint and puts its points in cooldown', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            local fixA = addSnapPoint(bodyA)
            local fixB = addSnapPoint(bodyB)

            snap.update(1 / 60)
            assert.equal(1, #state.snap.activeJoints)
            local joint = state.snap.activeJoints[1]
            local jointId = joint:getUserData().id

            -- Rip the bodies apart with opposing velocities: the joint
            -- resists with a large velocity impulse that getReactionForce
            -- reports. (Teleporting instead is corrected by the position
            -- solver and reports ~zero force.)
            state.snap.jointBreakThreshold = 100
            bodyA:setLinearVelocity(-1000, 0)
            bodyB:setLinearVelocity(1000, 0)
            world:update(1 / 60)
            snap.update(1 / 60)

            assert.equal(0, #state.snap.activeJoints)
            assert.is_true(joint:isDestroyed())
            assert.is_nil(registry.getJointByID(jointId))
            assert.is_nil(fixA:getUserData().extra.to)
            assert.is_nil(fixB:getUserData().extra.to)
            -- both points are cooling down
            assert.is_true(utils.tablelength(state.snap.cooldownList) >= 2)
        end)
    end)

    describe('onSceneLoaded', function()
        it('re-adopts loaded snap-type joints and relinks their snap points', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            local fixA = addSnapPoint(bodyA)
            local fixB = addSnapPoint(bodyB)

            -- A snap joint as io.load would recreate it: revolute with
            -- scriptmeta.type == 'snap', registered, but not yet adopted.
            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 0, 0, 50, 0)
            joint:setUserData({ id = 'loaded-snap-1', scriptmeta = { type = 'snap' } })
            registry.registerJoint('loaded-snap-1', joint)

            snap.onSceneLoaded()

            assert.equal(1, #state.snap.activeJoints)
            assert.equal(joint, state.snap.activeJoints[1])
            assert.equal(bodyB, fixA:getUserData().extra.to)
            assert.equal(bodyA, fixB:getUserData().extra.to)
        end)

        it('ignores non-snap joints', function()
            local bodyA = makeBody('snap-a', 0, 0)
            local bodyB = makeBody('snap-b', 50, 0)
            addSnapPoint(bodyA)
            addSnapPoint(bodyB)

            local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 0, 0, 50, 0)
            joint:setUserData({ id = 'plain-1' })
            registry.registerJoint('plain-1', joint)

            snap.onSceneLoaded()

            assert.equal(0, #state.snap.activeJoints)
        end)
    end)
end)
