-- spec/replace-shape-fails_spec.lua
-- fixtures.replaceShape (moving, resizing an sfixture) destroyed the old fixture before making the
-- new shape: a shape Box2D refuses (no area; a point clicked millions of pixels off, found by
-- claudetools/tool-modes_spec.lua on knutjump's body that fell out of the world) lost the
-- sfixture and left the registry holding a destroyed one. The old one stays now.
-- Run with: love . --specs spec/replace-shape-fails_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')

describe('an sfixture given a shape Box2D refuses', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('keeps the one it had', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100 })
        local anchor = fixtures.createSFixture(thing.body, 0, 0, subtypes.ANCHOR, { radius = 10 })
        local id = anchor:getUserData().id
        local result
        assert.has_no.errors(function()
            result = fixtures.replaceShape(anchor, { 5, 5, 5.000001, 5, 5, 5.000001 }) -- no area
        end)
        assert.are.equal(anchor, result)
        assert.is_false(anchor:isDestroyed())
        assert.are.equal(anchor, registry.getSFixtureByID(id))
    end)
end)
