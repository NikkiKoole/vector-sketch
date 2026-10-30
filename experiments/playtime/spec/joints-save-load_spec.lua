-- spec/joints-save-load_spec.lua
-- Every joint type keeps its settings through a save and a load (gatherSaveData ->
-- JSON -> buildWorld). Save and load go through src/joint-handlers.lua (CL13).
-- Run with: love . --specs spec/joints-save-load_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local sceneIO = require('src.io')
local json = require('vendor.dkjson')
local JT = require('src.joint-types')

local function cam()
    local c = { x = 0, y = 0, scale = 1 }
    return { getTranslation = function() return c.x, c.y end, getScale = function() return c.scale end,
        getRotation = function() return 0 end, setTranslation = function(_, x, y) c.x, c.y = x, y end,
        setScale = function(_, s) c.scale = s end }
end

local function near(expected, actual, what)
    assert.is_true(math.abs(expected - actual) < 1e-3, what .. ': expected ' .. expected .. ', got ' .. actual)
end

describe('joints through save and load', function()
    local a, b

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        a = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        b = objectManager.addThing('rectangle', { x = 100, y = 20, width = 40, height = 40 })
        b.body:setAngle(0.3)
    end)

    after_each(function()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then state.physicsWorld:destroy() end
        state.physicsWorld = nil
        registry.reset()
    end)

    -- save, load into a fresh world, return the one joint there
    local function roundTrip(joint)
        joint:getUserData().label = 'the joint'
        local saved = json.decode(json.encode(sceneIO.gatherSaveData(state.physicsWorld, cam())))
        registry.reset()
        local world = love.physics.newWorld(0, 0, true)
        state.physicsWorld:destroy()
        state.physicsWorld = world
        sceneIO.buildWorld(saved, world, cam())
        assert.are.equal(1, #world:getJoints())
        local loaded = world:getJoints()[1]
        assert.are.equal('the joint', loaded:getUserData().label)
        return loaded
    end

    local function sameAnchors(before, after) -- before: { joint:getAnchors() } from before saving
        local b1, b2, b3, b4 = unpack(before)
        local a1, a2, a3, a4 = after:getAnchors()
        near(b1, a1, 'anchor x1'); near(b2, a2, 'anchor y1')
        if b3 then near(b3, a3, 'anchor x2'); near(b4, a4, 'anchor y2') end
    end

    local function connect(jointType, extra)
        local data = { body1 = a.body, body2 = b.body, jointType = jointType, collideConnected = true,
            offsetA = { x = 10, y = 5 }, offsetB = { x = -8, y = 3 } }
        for k, v in pairs(extra or {}) do data[k] = v end
        return joints.createJoint(data)
    end

    it('revolute: limits, motor, reference angle, both anchors', function()
        local j = connect(JT.REVOLUTE, { lowerLimit = -0.4, upperLimit = 0.6, limitsEnabled = true })
        j:setMotorEnabled(true); j:setMotorSpeed(2); j:setMaxMotorTorque(300)
        local ref, x1, y1, x2, y2 = j:getReferenceAngle(), j:getAnchors()
        b.body:setAngle(0.9) -- saved mid-swing
        local l = roundTrip(j)
        near(ref, l:getReferenceAngle(), 'reference angle')
        near(-0.4, l:getLowerLimit(), 'lower'); near(0.6, l:getUpperLimit(), 'upper')
        assert.is_true(l:areLimitsEnabled()); assert.is_true(l:isMotorEnabled())
        near(2, l:getMotorSpeed(), 'motor speed'); near(300, l:getMaxMotorTorque(), 'torque')
        assert.is_true(l:getCollideConnected())
        local lx1, ly1 = l:getAnchors()
        near(x1, lx1, 'anchor x'); near(y1, ly1, 'anchor y')
        assert.is_not_nil(x2 and y2)
    end)

    it('distance: length and spring', function()
        local j = connect(JT.DISTANCE, { length = 77 })
        j:setFrequency(3); j:setDampingRatio(0.4)
        local anchors = { j:getAnchors() }
        local l = roundTrip(j)
        near(77, l:getLength(), 'length'); near(3, l:getFrequency(), 'f'); near(0.4, l:getDampingRatio(), 'd')
        sameAnchors(anchors, l)
    end)

    it('weld: spring and reference angle', function()
        local j = connect(JT.WELD)
        j:setFrequency(5); j:setDampingRatio(0.2)
        local ref = j:getReferenceAngle()
        b.body:setAngle(1.2)
        local l = roundTrip(j)
        near(5, l:getFrequency(), 'f'); near(0.2, l:getDampingRatio(), 'd'); near(ref, l:getReferenceAngle(), 'ref')
    end)

    it('rope: max length', function()
        local j = connect(JT.ROPE, { maxLength = 140 })
        local anchors = { j:getAnchors() }
        local l = roundTrip(j)
        near(140, l:getMaxLength(), 'max length')
        sameAnchors(anchors, l)
    end)

    it('prismatic: axis, limits, motor', function()
        local j = connect(JT.PRISMATIC, { axisX = 1, axisY = 0 })
        j:setLimits(-20, 30); j:setLimitsEnabled(true)
        j:setMotorEnabled(true); j:setMotorSpeed(5); j:setMaxMotorForce(400)
        local l = roundTrip(j)
        local ax, ay = l:getAxis()
        near(1, ax, 'axis x'); near(0, ay, 'axis y')
        near(-20, l:getLowerLimit(), 'lower'); near(30, l:getUpperLimit(), 'upper')
        assert.is_true(l:areLimitsEnabled()); assert.is_true(l:isMotorEnabled())
        near(5, l:getMotorSpeed(), 'speed'); near(400, l:getMaxMotorForce(), 'force')
    end)

    it('wheel: axis, spring, motor', function()
        local j = connect(JT.WHEEL, { axisX = 0, axisY = 1 })
        j:setSpringFrequency(4); j:setSpringDampingRatio(0.5)
        j:setMotorEnabled(true); j:setMotorSpeed(-3); j:setMaxMotorTorque(250)
        local l = roundTrip(j)
        local ax, ay = l:getAxis()
        near(0, ax, 'axis x'); near(1, ay, 'axis y')
        near(4, l:getSpringFrequency(), 'f'); near(0.5, l:getSpringDampingRatio(), 'd')
        assert.is_true(l:isMotorEnabled()); near(-3, l:getMotorSpeed(), 'speed'); near(250, l:getMaxMotorTorque(), 't')
    end)

    it('motor: offsets and strength', function()
        local j = connect(JT.MOTOR, { correctionFactor = 0.5 })
        j:setLinearOffset(12, -7); j:setAngularOffset(0.4); j:setMaxForce(321); j:setMaxTorque(99)
        local l = roundTrip(j)
        local lx, ly = l:getLinearOffset()
        near(12, lx, 'lin x'); near(-7, ly, 'lin y'); near(0.4, l:getAngularOffset(), 'ang')
        near(321, l:getMaxForce(), 'force'); near(99, l:getMaxTorque(), 'torque')
        near(0.5, l:getCorrectionFactor(), 'correction')
    end)

    it('pulley: ground anchors and ratio', function()
        local j = connect(JT.PULLEY, { groundAnchor1 = { x = -50, y = -200 }, groundAnchor2 = { x = 150, y = -180 },
            ratio = 1.5 })
        local l = roundTrip(j)
        local g1x, g1y, g2x, g2y = l:getGroundAnchors()
        near(-50, g1x, 'g1x'); near(-200, g1y, 'g1y'); near(150, g2x, 'g2x'); near(-180, g2y, 'g2y')
        near(1.5, l:getRatio(), 'ratio')
    end)

    it('friction: strength', function()
        local j = connect(JT.FRICTION)
        j:setMaxForce(55); j:setMaxTorque(66)
        local anchors = { j:getAnchors() }
        local l = roundTrip(j)
        near(55, l:getMaxForce(), 'force'); near(66, l:getMaxTorque(), 'torque')
        sameAnchors(anchors, l)
    end)
end)
