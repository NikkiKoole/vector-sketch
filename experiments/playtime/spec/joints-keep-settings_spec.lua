-- A joint the editor rebuilds keeps what it had (docs/CODE-BUGS-2026-10.md):
-- BUG1: recreate (collide toggle, anchor drag, resize) dropped motors, springs,
--       prismatic limits and the reference angle.
-- BUG2: clone and flip asked every joint for limits; only revolute and prismatic have them.

if not love then return end

local joints = require('src.joints')
local registry = require('src.registry')
local state = require('src.state')
local objectManager = require('src.object-manager')
local library = require('src.library')
local JT = require('src.joint-types')

local function near(expected, actual, msg)
    assert.is_true(math.abs(expected - actual) < 1e-4,
        (msg or '') .. ' expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

describe('joints keep their settings', function()
    local a, b

    local function addBody(x, y)
        return objectManager.addThing('rectangle', {
            x = x, y = y, bodyType = 'dynamic', width = 40, height = 40,
            width2 = 40, width3 = 40, height2 = 40, height3 = 40, height4 = 40, radius = 20, label = '',
        })
    end

    local function connect(jointType, extra)
        local data = { body1 = a.body, body2 = b.body, jointType = jointType, collideConnected = false }
        for k, v in pairs(extra or {}) do data[k] = v end
        return joints.createJoint(data)
    end

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        a = addBody(0, 0)
        b = addBody(100, 0)
    end)

    after_each(function()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
        registry.reset()
    end)

    describe('recreateJoint (BUG1)', function()
        it('revolute keeps its motor', function()
            local joint = connect(JT.REVOLUTE)
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(2.5)
            joint:setMaxMotorTorque(1234)
            local rebuilt = joints.recreateJoint(joint, { collideConnected = true })
            assert.is_true(rebuilt:isMotorEnabled())
            near(2.5, rebuilt:getMotorSpeed())
            near(1234, rebuilt:getMaxMotorTorque())
            assert.is_true(rebuilt:getCollideConnected())
        end)

        it('revolute keeps its reference angle when the bodies have turned', function()
            local joint = connect(JT.REVOLUTE, { lowerLimit = -0.2, upperLimit = 0.3, areLimitsEnabled = true })
            near(0, joint:getReferenceAngle())
            b.body:setAngle(0.8) -- a Mipo arm mid-swing
            local rebuilt = joints.recreateJoint(joint)
            near(0, rebuilt:getReferenceAngle(), 'reference angle')
            near(-0.2, rebuilt:getLowerLimit())
            near(0.3, rebuilt:getUpperLimit())
        end)

        it('distance keeps its spring', function()
            local joint = connect(JT.DISTANCE)
            joint:setFrequency(3)
            joint:setDampingRatio(0.4)
            local rebuilt = joints.recreateJoint(joint)
            near(3, rebuilt:getFrequency())
            near(0.4, rebuilt:getDampingRatio())
        end)

        it('weld keeps its spring and reference angle', function()
            b.body:setAngle(0.5)
            local joint = connect(JT.WELD)
            joint:setFrequency(5)
            joint:setDampingRatio(0.7)
            b.body:setAngle(0)
            local rebuilt = joints.recreateJoint(joint)
            near(5, rebuilt:getFrequency())
            near(0.7, rebuilt:getDampingRatio())
            near(0.5, rebuilt:getReferenceAngle())
        end)

        it('prismatic keeps limits, motor and axis', function()
            local joint = connect(JT.PRISMATIC, { axisX = 1, axisY = 0 })
            joint:setLimits(-20, 40)
            joint:setLimitsEnabled(true)
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(10)
            joint:setMaxMotorForce(500)
            local rebuilt = joints.recreateJoint(joint)
            near(-20, rebuilt:getLowerLimit())
            near(40, rebuilt:getUpperLimit())
            assert.is_true(rebuilt:areLimitsEnabled())
            assert.is_true(rebuilt:isMotorEnabled())
            near(10, rebuilt:getMotorSpeed())
            near(500, rebuilt:getMaxMotorForce())
            local ax, ay = rebuilt:getAxis()
            near(1, ax)
            near(0, ay)
        end)

        it('wheel keeps axis, spring and motor', function()
            local joint = connect(JT.WHEEL, { axisX = 0, axisY = 1 })
            joint:setSpringFrequency(4)
            joint:setSpringDampingRatio(0.3)
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(-6)
            joint:setMaxMotorTorque(800)
            local rebuilt = joints.recreateJoint(joint)
            near(4, rebuilt:getSpringFrequency())
            near(0.3, rebuilt:getSpringDampingRatio())
            assert.is_true(rebuilt:isMotorEnabled())
            near(-6, rebuilt:getMotorSpeed())
            near(800, rebuilt:getMaxMotorTorque())
            local ax, ay = rebuilt:getAxis()
            near(0, ax)
            near(1, ay)
        end)

        it('motor joint keeps its offsets and strength', function()
            local joint = connect(JT.MOTOR)
            joint:setLinearOffset(12, -7)
            joint:setAngularOffset(0.4)
            joint:setMaxForce(321)
            joint:setMaxTorque(99)
            local rebuilt = joints.recreateJoint(joint)
            local lx, ly = rebuilt:getLinearOffset()
            near(12, lx)
            near(-7, ly)
            near(0.4, rebuilt:getAngularOffset())
            near(321, rebuilt:getMaxForce())
            near(99, rebuilt:getMaxTorque())
        end)

        it('the caller wins over what the joint had (the axis sliders)', function()
            local joint = connect(JT.WHEEL, { axisX = 0, axisY = 1 })
            local rebuilt = joints.recreateJoint(joint, { axisX = 1, axisY = 0 })
            local ax, ay = rebuilt:getAxis()
            near(1, ax)
            near(0, ay)
        end)

        it('resizing a body keeps the motor on its joint', function()
            local joint = connect(JT.REVOLUTE)
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(3)
            joint:setMaxMotorTorque(100)
            local id = joints.getJointId(joint)
            objectManager.recreateThingFromBody(a.body, { width = 80 })
            local rebuilt = registry.getJointByID(id)
            assert.is_not_nil(rebuilt)
            assert.is_false(rebuilt:isDestroyed())
            assert.is_true(rebuilt:isMotorEnabled())
            near(3, rebuilt:getMotorSpeed())
        end)
    end)

    describe('clone and flip with joints that have no limits (BUG2)', function()
        for _, jointType in ipairs({ JT.WELD, JT.DISTANCE, JT.ROPE, JT.WHEEL, JT.MOTOR, JT.FRICTION }) do
            it('clones two bodies joined by a ' .. jointType .. ' joint', function()
                connect(jointType)
                local cloned = library.clone({ a, b })
                assert.are.equal(2, #cloned)
                assert.are.equal(1, #cloned[1].body:getJoints())
                assert.are.equal(jointType, cloned[1].body:getJoints()[1]:getType())
            end)

            it('flips two bodies joined by a ' .. jointType .. ' joint', function()
                connect(jointType)
                objectManager.flipThing(a, 'x', true)
                local list = a.body:getJoints()
                assert.are.equal(1, #list)
                assert.are.equal(jointType, list[1]:getType())
            end)
        end

        it('clone keeps a weld spring', function()
            local joint = connect(JT.WELD)
            joint:setFrequency(6)
            local cloned = library.clone({ a, b })
            near(6, cloned[1].body:getJoints()[1]:getFrequency())
        end)

        it('flip mirrors revolute limits and motor direction', function()
            local joint = connect(JT.REVOLUTE, { lowerLimit = -0.2, upperLimit = 0.5, areLimitsEnabled = true })
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(2)
            objectManager.flipThing(a, 'x', true)
            local flipped = a.body:getJoints()[1]
            assert.is_true(flipped:areLimitsEnabled())
            near(-0.5, flipped:getLowerLimit())
            near(0.2, flipped:getUpperLimit())
            near(-2, flipped:getMotorSpeed())
        end)
    end)
end)
