-- spec/draw-skips_spec.lua
-- The draw loops skip some things and go on with the next (once `goto`, now a `repeat ...
-- until true` block left with `break`, because the web build's Lua 5.1 has no goto).
-- These check that a skip moves on to the next thing instead of ending the whole loop.
-- Run with: love . --specs spec/draw-skips_spec.lua

if not love then return end
-- luacheck: ignore 122 (the spies swap love.graphics.polygon/draw and put them back)

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

-- Runs fn on a canvas and records every love.graphics.polygon('line', ...) call.
local function recordOutlines(fn)
    local outlines = {}
    local polygon = love.graphics.polygon
    love.graphics.polygon = function(mode, ...)
        local first = ...
        if mode == 'line' then outlines[#outlines + 1] = type(first) == 'table' and first or { ... } end
        return polygon(mode, ...)
    end
    local canvas = love.graphics.newCanvas(200, 200)
    love.graphics.setCanvas(canvas)
    local ok, err = pcall(fn)
    love.graphics.setCanvas()
    love.graphics.polygon = polygon
    canvas:release()
    assert.is_true(ok, tostring(err))
    return outlines
end

-- How many recorded outlines lie around world x (all their points within 100 of it).
local function outlinesAround(outlines, x)
    local n = 0
    for _, points in ipairs(outlines) do
        local inside = true
        for i = 1, #points, 2 do
            if math.abs(points[i] - x) > 100 then inside = false end
        end
        if inside then n = n + 1 end
    end
    return n
end

describe('draw loops skip and go on', function()
    local world
    local saved

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        saved = {
            debugDrawBodies = state.world.debugDrawBodies,
            textureOrBody = state.world.textureOrBody,
            showTextures = state.world.showTextures,
            drawOutline = state.world.drawOutline,
        }
    end)

    after_each(function()
        for k, v in pairs(saved) do state.world[k] = v end
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it('drawWorld skips a textured body and still draws the bodies after it', function()
        objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local textured = objectManager.addThing('rectangle', { x = 300, y = 0, width = 40, height = 40 })
        fixtures.createSFixture(textured.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        objectManager.addThing('rectangle', { x = 900, y = 0, width = 40, height = 40 })
        state.world.debugDrawBodies = true
        state.world.showTextures = true
        state.world.textureOrBody = true
        state.world.drawOutline = true

        local outlines = recordOutlines(function() box2dDraw.drawWorld(world, true) end)
        assert.are.equal(1, outlinesAround(outlines, 0))
        assert.are.equal(0, outlinesAround(outlines, 300))
        assert.are.equal(1, outlinesAround(outlines, 900))
    end)

    it('a custom body draws one outline, not one per fixture, and the next body still draws', function()
        -- a U shape: concave, so Box2D gets several fixtures for it
        local x, y, w, h, wall = 600, 0, 100, 80, 10
        local hw, hh = w / 2, h / 2
        local vertices = {
            x - hw, y - hh, x - hw + wall, y - hh, x - hw + wall, y + hh - wall, x + hw - wall, y + hh - wall,
            x + hw - wall, y - hh, x + hw, y - hh, x + hw, y + hh, x - hw, y + hh,
        }
        local custom = objectManager.addThing('custom', { x = x, y = y, vertices = vertices })
        assert.is_truthy(custom)
        assert.is_true(#custom.body:getFixtures() > 1)
        objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        state.world.debugDrawBodies = true
        state.world.textureOrBody = false
        state.world.drawOutline = true

        local outlines = recordOutlines(function() box2dDraw.drawWorld(world, true) end)
        assert.are.equal(1, outlinesAround(outlines, 600))
        assert.are.equal(1, outlinesAround(outlines, 0))
    end)

    it('makeCombinedImages drops a cleared picture and still composes the next one', function()
        local function ompFixture(x, bgURL, body)
            body = body or objectManager.addThing('rectangle', { x = x, y = 0, width = 40, height = 40 }).body
            local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', { width = 40, height = 40 })
            local extra = fixture:getUserData().extra
            extra.OMP = true
            extra.main = extra.main or {}
            extra.main.bgURL = bgURL
            extra.main.pURL = 'pattern.png'
            extra.dirty = true
            return extra
        end
        local cleared = ompFixture(0, '')
        local pictured = ompFixture(300, 'shapeA1.png')
        local cleared2 = ompFixture(600, '')
        -- two on one body, in both orders: a cleared one mustn't end that body's fixture loop
        local both1 = objectManager.addThing('rectangle', { x = 900, y = 0, width = 40, height = 40 }).body
        local first1, second1 = ompFixture(nil, '', both1), ompFixture(nil, 'shapeA1.png', both1)
        local both2 = objectManager.addThing('rectangle', { x = 1200, y = 0, width = 40, height = 40 }).body
        local first2, second2 = ompFixture(nil, 'shapeA1.png', both2), ompFixture(nil, '', both2)

        local canvas = love.graphics.newCanvas(10, 10)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(box2dDrawTextured.makeCombinedImages)
        love.graphics.setCanvas()
        canvas:release()
        assert.is_true(ok, tostring(err))

        assert.is_nil(cleared.ompImage)
        assert.is_false(cleared.dirty)
        assert.is_nil(cleared2.ompImage)
        assert.is_false(cleared2.dirty)
        assert.is_truthy(pictured.ompImage)
        assert.is_false(pictured.dirty)
        for _, extra in ipairs({ first1, second2 }) do assert.is_nil(extra.ompImage) end
        for _, extra in ipairs({ second1, first2 }) do assert.is_truthy(extra.ompImage) end
    end)

    it('a traced haircut without a picture is skipped and the textured world still draws', function()
        local traced = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local fixture = fixtures.createSFixture(traced.body, 0, 0, subtypes.TRACE_VERTICES, { radius = 10 })
        assert.is_truthy(fixture)
        local extra = fixture:getUserData().extra
        extra.main = extra.main or {}
        extra.main.bgURL = ''
        extra.startIndex, extra.endIndex = 0, 2
        local textured = objectManager.addThing('rectangle', { x = 300, y = 0, width = 40, height = 40 })
        local texfixture = fixtures.createSFixture(textured.body, 0, 0, 'texfixture', { width = 40, height = 40 })
        local texExtra = texfixture:getUserData().extra
        texExtra.main = texExtra.main or {}
        texExtra.main.bgURL = 'shapeA1.png'

        local draws = 0
        local draw = love.graphics.draw
        love.graphics.draw = function(...)
            draws = draws + 1
            return draw(...)
        end
        local canvas = love.graphics.newCanvas(10, 10)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, world)
        love.graphics.setCanvas()
        love.graphics.draw = draw
        canvas:release()
        assert.is_true(ok, tostring(err))
        assert.is_true(draws > 0)
    end)
end)
