-- Specs for src/joints.lua recreateJoint — the destroy-and-rebuild path
-- flagged fragile in DEEPER-ISSUES (dangling refs, metadata continuity).
-- Until now only createJoint was exercised by specs.

if not love then return end

local joints = require('src.joints')
local registry = require('src.registry')
local state = require('src.state')
local JT = require('src.joint-types')

describe('joints.recreateJoint', function()
    local world, bodyA, bodyB

    local function makeBody(id, x, y)
        local body = love.physics.newBody(world, x, y, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
        body:setUserData({ thing = { id = id, body = body } })
        registry.registerBody(id, body)
        return body
    end

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        bodyA = makeBody('jr-body-a', 0, 0)
        bodyB = makeBody('jr-body-b', 100, 0)
    end)

    after_each(function()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
        registry.reset()
    end)

    it('rebuilds a revolute joint preserving id, limits, and registration', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.REVOLUTE, collideConnected = false,
        })
        assert.is_not_nil(joint)
        local id = joints.getJointId(joint)
        joint:setLimits(-0.5, 0.7)
        joint:setLimitsEnabled(true)

        local newJoint = joints.recreateJoint(joint)

        assert.is_not_nil(newJoint)
        assert.is_true(joint:isDestroyed())
        assert.is_false(newJoint:isDestroyed())
        assert.equal(id, joints.getJointId(newJoint))
        assert.equal(newJoint, registry.getJointByID(id))

        assert.is_true(newJoint:areLimitsEnabled())
        local lower, upper = newJoint:getLimits()
        assert.is_true(math.abs(lower - -0.5) < 1e-6)
        assert.is_true(math.abs(upper - 0.7) < 1e-6)
    end)

    it('keeps connecting the same two bodies', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.REVOLUTE, collideConnected = false,
        })
        local newJoint = joints.recreateJoint(joint)
        local a, b = newJoint:getBodies()
        assert.equal(bodyA, a)
        assert.equal(bodyB, b)
    end)

    it('preserves offset metadata across the rebuild', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.REVOLUTE, collideConnected = false,
            offsetA = { x = 5, y = -3 },
        })
        local newJoint = joints.recreateJoint(joint)
        local offsetA = joints.getJointMetaSetting(newJoint, 'offsetA')
        assert.equal(5, offsetA.x)
        assert.equal(-3, offsetA.y)
    end)

    it('applies newSettings overrides on top of the extracted data', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.REVOLUTE, collideConnected = false,
        })
        assert.is_false(joint:getCollideConnected())
        local newJoint = joints.recreateJoint(joint, { collideConnected = true })
        assert.is_true(newJoint:getCollideConnected())
    end)

    it('rebuilds a rope joint preserving maxLength', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.ROPE, collideConnected = false,
            maxLength = 55,
        })
        assert.is_not_nil(joint)
        local newJoint = joints.recreateJoint(joint)
        assert.is_true(math.abs(newJoint:getMaxLength() - 55) < 1e-6)
    end)

    it('returns nil for an already-destroyed joint', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyB,
            jointType = JT.REVOLUTE, collideConnected = false,
        })
        joint:destroy()
        assert.is_nil(joints.recreateJoint(joint))
    end)

    it('refuses to create a joint from a body to itself', function()
        local joint = joints.createJoint({
            body1 = bodyA, body2 = bodyA,
            jointType = JT.REVOLUTE, collideConnected = false,
        })
        assert.is_nil(joint)
    end)
end)
