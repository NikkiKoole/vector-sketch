-- spec/omp-no-pattern_spec.lua
-- A texture switched to OMP in its panel ('mode') before a pattern was picked has no pURL. The next
-- frame died composing it: attempt to concatenate field 'pURL' (found by
-- claudetools/editor-actions_spec.lua on a connected texture; the texfixture panel has the same row).
-- It's composed without a pattern now.
-- Run with: love . --specs spec/omp-no-pattern_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local draw = require('src.physics.box2d-draw-textured')

describe('a texture switched to OMP with no pattern yet', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('draws', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100 })
        local fixture = fixtures.createSFixture(thing.body, 0, 0, subtypes.TEXFIXTURE, { width = 100, height = 100 })
        local extra = fixture:getUserData().extra
        extra.main = extra.main or {}
        extra.main.bgURL = 'world/line-01.png'
        extra.main.pURL = nil
        extra.OMP = true -- as the panel's mode row sets it
        extra.dirty = true
        local canvas = love.graphics.newCanvas(128, 128)
        love.graphics.setCanvas({ canvas, stencil = true })
        local ok, err = pcall(function()
            draw.makeCombinedImages()
            draw.drawTexturedWorld(state.physicsWorld)
        end)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end)
end)
