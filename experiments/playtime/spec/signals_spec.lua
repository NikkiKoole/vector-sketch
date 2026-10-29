-- spec/signals_spec.lua
-- Run with: love . --specs spec/signals_spec.lua

if not love then return end

local contactTracker = require('src.physics.contact-tracker')

local state = require('src.state')
local registry = require('src.registry')
local props = require('src.props')
local signals = require('src.signals')
local joints = require('src.joints')
local objectManager = require('src.object-manager')
local snap = require('src.physics.snap')

describe('src.signals + props gate/button', function()
    local world, base

    before_each(function()
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
        state.physicsWorld = world
        registry.reset()
        base = love.physics.newBody(world, 0, 0, 'static')
        love.physics.newFixture(base, love.physics.newRectangleShape(2000, 40))
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function gateJoint(gate)
        for _, j in ipairs(gate.body:getJoints()) do
            if j:getType() == 'prismatic' then return j end
        end
    end

    it('a gate starts closed: motor driving up', function()
        local gate = props.makeGate(base, 300, -20, 'g1')
        assert.is_true(gateJoint(gate):getMotorSpeed() > 0)
        assert.is_false(gate.behaviors[1].open)
    end)

    it('its signal opens it, again closes it; other signals do nothing', function()
        local gate = props.makeGate(base, 300, -20, 'g1')
        assert.are.equal(0, signals.emit('other'))
        assert.are.equal(1, signals.emit('g1'))
        assert.is_true(gate.behaviors[1].open)
        assert.is_true(gateJoint(gate):getMotorSpeed() < 0)
        signals.emit('g1')
        assert.is_false(gate.behaviors[1].open)
    end)

    it('pressing a button sends its signal', function()
        local gate = props.makeGate(base, 300, -20, 'g1')
        local button = props.makeButton(-300, 500, 300, 'g1')
        assert.is_true(signals.onPressed({ button.body }))
        assert.is_true(gate.behaviors[1].open)
    end)

    it('an editor-made gate (add-joint prismatic, limits 0..0, axis down) drops and rises', function()
        local gate = objectManager.addThing('rectangle', { x = 0, y = -120, width = 30, height = 200, label = 'g' })
        gate.behaviors = { { name = 'SIGNAL_GATE', signal = 'e1' } }
        joints.createJoint({ body1 = base, body2 = gate.body, jointType = 'prismatic',
            offsetA = { x = 0, y = -120 }, offsetB = { x = 0, y = 0 }, collideConnected = false })
        local _, y0 = gate.body:getPosition()
        signals.emit('e1')
        for _ = 1, 120 do world:update(1 / 60) end
        local _, yOpen = gate.body:getPosition()
        assert.is_true(yOpen > y0 + 150, string.format('open: %d -> %d', y0, yOpen))
        signals.emit('e1')
        for _ = 1, 120 do world:update(1 / 60) end
        local _, yClosed = gate.body:getPosition()
        assert.is_near(y0, yClosed, 5)
    end)

    local function step(n)
        for _ = 1, n do
            world:update(1 / 60)
            signals.update()
        end
    end

    it('a pressure plate (hold) opens its gate while something rests on it', function()
        local gate = props.makeGate(base, 300, -20, 'p1')
        local plate = props.makePlate(-300, -20, 'p1', 'hold')
        step(2) -- first look: nothing on it
        local ball = props.makeBall(-300, -200, 50)
        step(90)
        assert.is_true(gate.behaviors[1].open)
        ball.body:destroy()
        step(5)
        assert.is_true(gate.behaviors[1].open) -- release is debounced (plateReleaseFrames)
        step(20)
        assert.is_false(gate.behaviors[1].open)
        assert.are.equal('hold', plate.behaviors[1].mode)
    end)

    it('a toggle plate keeps the gate open after the ball rolls off', function()
        local gate = props.makeGate(base, 300, -20, 'p2')
        props.makePlate(-300, -20, 'p2', 'toggle')
        step(2)
        local ball = props.makeBall(-300, -200, 50)
        step(90)
        assert.is_true(gate.behaviors[1].open)
        ball.body:destroy()
        step(25)
        assert.is_true(gate.behaviors[1].open)
    end)

    it("something already on the plate when the scene loads doesn't fire", function()
        local gate = props.makeGate(base, 300, -20, 'p3')
        props.makePlate(-300, -20, 'p3', 'hold')
        props.makeBall(-300, -82, 50) -- resting on the plate from the start
        step(30)
        assert.is_false(gate.behaviors[1].open)
    end)

    describe('sockets (snap as a trigger)', function()
        local savedConnect
        before_each(function()
            savedConnect = state.snap.onlyConnectWhenInteracted
            state.snap.onlyConnectWhenInteracted = false
            snap.reset()
        end)
        after_each(function() state.snap.onlyConnectWhenInteracted = savedConnect end)

        local function tick(n)
            for _ = 1, n or 1 do
                world:update(1 / 60)
                snap.update(1 / 60)
                signals.update()
            end
        end

        it('a key clicked into the socket opens the gate; pulled out (hold) closes it', function()
            local gate = props.makeGate(base, 300, -20, 's1')
            local socket = props.makeSocket(-300, -20, 's1', 'key', 'hold')
            tick()
            local sx, sy = socket.body:getPosition()
            local key = props.makeKey(sx, sy - 80 - 60 - 20)
            key.body:setGravityScale(0)
            tick(2)
            assert.are.equal(1, #snap.joints())
            assert.is_true(gate.behaviors[1].open)
            snap.destroySnapJointAboutBody(key.body)
            tick(2)
            assert.is_false(gate.behaviors[1].open)
        end)

        it('a block that is not a key does nothing in a key-only socket', function()
            local gate = props.makeGate(base, 300, -20, 's2')
            local socket = props.makeSocket(-300, -20, 's2', 'key', 'hold')
            tick()
            local sx, sy = socket.body:getPosition()
            local block = props.makeSnapBlock(sx, sy - 80 - 55 - 15)
            block.body:setGravityScale(0)
            tick(2)
            assert.is_true(#snap.joints() >= 1)
            assert.is_false(gate.behaviors[1].open)
        end)
    end)
end)
