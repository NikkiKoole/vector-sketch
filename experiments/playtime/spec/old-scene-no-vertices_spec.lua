-- spec/old-scene-no-vertices_spec.lua
-- Older scene files saved a body without its outline (`"vertices": false`, or none for a circle):
-- catapult, planets, the snap tests and others. Every body made today has one, and resizing or
-- flipping such a body in the inspector died in recreateThingFromBody (shallowCopy of a boolean,
-- found by claudetools/editor-actions_spec.lua). A body gets its outline on load now, made from its
-- shape and sizes as a new body's is.
-- Run with: love . --specs spec/old-scene-no-vertices_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local utils = require('src.utils')
local objectManager = require('src.object-manager')

describe('a body saved without its outline', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    local function load(path)
        sceneIO.load((love.filesystem.read(path)), state.physicsWorld, camera.getInstance())
    end

    for _, case in ipairs({
        { 'scripts/rooms/catapult.playtime.json', '16DBob', { width = 40 } },
        { 'scripts/spikes/planets.playtime.json', '1UmHbU', { radius = 8 } },
    }) do
        it('has one after loading, and resizes (' .. case[2] .. ')', function()
            load(case[1])
            local body = registry.getBodyByID(case[2])
            assert.are.equal('table', type(utils.thingOf(body).vertices))
            local thing = objectManager.recreateThingFromBody(body, case[3])
            assert.are.equal('table', type(thing.vertices))
        end)
    end
end)
