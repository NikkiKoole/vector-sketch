-- spec/signals_spec.lua
-- Run with: love . --specs spec/signals_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local props = require('src.props')
local signals = require('src.signals')

describe('src.signals + props gate/button', function()
    local world, base

    before_each(function()
        world = love.physics.newWorld(0, 980, true)
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
end)
