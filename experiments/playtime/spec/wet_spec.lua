-- spec/wet_spec.lua
-- Wet (src/wet.lua, docs/MATERIALS.md MT6a): a spot sticks to the body it lands on and dries; the
-- waterline soaks the bodies under it; each part is sent only the spots that reach it (a dry part's
-- shader loops over nothing), a part without a body (a limb ribbon) all of them.
-- Run with: love . --specs spec/wet_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local wet = require('src.wet')

describe('wet', function()
    local near, far

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        wet.clear()
        near = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100, bodyType = 'dynamic' })
        far = objectManager.addThing('rectangle', { x = 5000, y = 0, width = 100, height = 100, bodyType = 'dynamic' })
    end)

    after_each(function()
        wet.clear()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('a spot sticks to the body it lands on, and moves with it', function()
        wet.splash(10, 10, 40, 1)
        assert.are.equal(near.body, state.wet.spots[1].body)
        wet.update(0)
        local x1 = state.wet.spots[1].screen[1]
        near.body:setPosition(200, 0)
        wet.update(0)
        assert.is_true(state.wet.spots[1].screen[1] > x1)
    end)

    it('dries up', function()
        wet.splash(10, 10, 40, 1)
        wet.update(wet.DRY_SECONDS / 2)
        assert.is_true(math.abs(state.wet.spots[1].amount - 0.5) < 1e-6)
        wet.update(wet.DRY_SECONDS)
        assert.are.equal(0, #state.wet.spots)
    end)

    it('a part only gets the spots that reach it', function()
        wet.splash(10, 10, 40, 1)
        wet.update(0)
        assert.are.equal(1, (wet.shaderSpots(near.body)))
        assert.are.equal(0, (wet.shaderSpots(far.body)))
        assert.are.equal(1, (wet.shaderSpots(nil))) -- a limb ribbon: all of them
    end)

    it('the waterline soaks what is under it', function()
        wet.setWaterline(-1000)
        wet.update(0)
        assert.are.equal(2, #state.wet.spots)
        assert.is_true(state.wet.spots[1].soak)
    end)
end)
