-- spec/rebuild-while-dragged_spec.lua
-- A body rebuilt (resized from its panel) while a pointer drags it with the world running: the
-- rebuild carried its joints over and took the drag's mouse joint for one of them, logging four
-- errors (no id, no offsets, 'unsupported joint type: mouse'; found by
-- claudetools/tool-modes_spec.lua). The drag isn't the body's joint: it's left out quietly.
-- Run with: love . --specs spec/rebuild-while-dragged_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local logger = require('src.logger')

describe('a body rebuilt while it is dragged', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('rebuilds without taking the drag for one of its joints', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100 })
        love.physics.newMouseJoint(thing.body, 0, 0)
        local errors = {}
        local realError = logger.error
        logger.error = function(_, ...) errors[#errors + 1] = table.concat({ tostring((...)) }, ' ') end
        local ok, rebuilt = pcall(objectManager.recreateThingFromBody, thing.body, { width = 120 })
        logger.error = realError
        assert.is_true(ok, tostring(rebuilt))
        assert.are.same({}, errors)
        assert.are.equal(0, #rebuilt.body:getJoints())
    end)
end)
