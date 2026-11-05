-- spec/tile-repeat-new_spec.lua
-- A tile repeat dropped on a body from the tool rail has no texture yet (no extra.main until the
-- panel picks one). Its first draw died: attempt to index field 'main' (found by
-- claudetools/editor-actions_spec.lua). It draws nothing until it has a texture now.
-- Run with: love . --specs spec/tile-repeat-new_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local draw = require('src.physics.box2d-draw-textured')

describe('a new tile repeat, no texture picked yet', function()
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
        -- as the tool rail drops it (src/ui/tool-rail.lua dropAttach)
        fixtures.createSFixture(thing.body, 5, 5, subtypes.TILE_REPEAT, { radius = 30 })
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
