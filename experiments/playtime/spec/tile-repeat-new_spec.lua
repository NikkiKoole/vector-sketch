-- spec/tile-repeat-new_spec.lua
-- A tile repeat dropped on a body from the tool rail has no texture yet (no extra.main until the
-- panel picks one). Its first draw died: attempt to index field 'main' (found by
-- claudetools/editor-actions_spec.lua). It draws nothing until it has a texture now.
-- Then the panel picks a texture: the draw died again, every frame (box2d-draw-textured.lua:664,
-- arithmetic on a nil tile width): a new one has no tile size or rotation, the panel only shows
-- their defaults (found by claudetools/feature-rounds_spec.lua). It draws at those defaults now.
-- Run with: love . --specs spec/tile-repeat-new_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local draw = require('src.physics.box2d-draw-textured')
local sfixtureParams = require('src.sfixture-params')

local function drawWorld()
    local canvas = love.graphics.newCanvas(128, 128)
    love.graphics.setCanvas({ canvas, stencil = true })
    local ok, err = pcall(function()
        draw.makeCombinedImages()
        draw.drawTexturedWorld(state.physicsWorld)
    end)
    love.graphics.setCanvas()
    return ok, err
end

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
        local ok, err = drawWorld()
        assert.is_true(ok, tostring(err))
    end)

    it('draws once its panel picks a texture', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100 })
        local fixture = fixtures.createSFixture(thing.body, 5, 5, subtypes.TILE_REPEAT, { radius = 30 })
        for _, row in ipairs(sfixtureParams.bySubtype[subtypes.TILE_REPEAT]) do
            if row.key == 'texture' then row.set(fixture, 'world/grasspattern2.png') end
        end
        local ok, err = drawWorld()
        assert.is_true(ok, tostring(err))
        assert.is_not_nil(fixture:getUserData().extra._mesh) -- drawn, not skipped
    end)
end)
