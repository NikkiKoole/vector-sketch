-- spec/backdrop-shadows_spec.lua
-- Backdrop shadows (src/backdrop-shadows.lua, docs/LIGHT-AND-SHADOW.md LS7): what stands in front of a
-- back wall throws a soft shadow onto it, shifted the way the light shines; only on the wall (no shadow
-- over nothing: open sky behind, none). Off (state.backdropShadows nil) it draws nothing.
-- Run with: love . --specs spec/backdrop-shadows_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local backdropShadows = require('src.backdrop-shadows')

local W, H = 400, 300

-- the wall: x -150..150, y -120..120 (world), white on a white canvas: the shadow alone shows
local function wall() love.graphics.rectangle('fill', -150, -120, 300, 240) end

local function render(world)
    -- baked first, as the game does: baking sets the canvas back to the screen
    box2dDrawTextured.makeCombinedImages()
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    backdropShadows.draw(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas:newImageData()
end

local function at(img, wx, wy)
    local r, g, b = img:getPixel(wx + W / 2, wy + H / 2)
    return (r + g + b) / 3
end

describe('backdrop shadows', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        -- a pictured box in front of the wall
        local box = objectManager.addThing('rectangle', { x = -40, y = -20, width = 80, height = 80, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 80, height = 80 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty = true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
        -- the light shines right and down: the shadow falls 40 to the right, 30 down
        state.backdropShadows = { strength = 0.5, offset = { 40, 30 }, blur = 4, wall = wall }
    end)

    after_each(function()
        state.backdropShadows = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('darkens the wall where the shifted box falls', function()
        local img = render(state.physicsWorld)
        assert.is_true(at(img, 0, 10) < 0.85, 'shadow at the box + offset: ' .. at(img, 0, 10))
        assert.is_true(at(img, -120, -100) > 0.99, 'a wall corner the shadow doesn\'t reach')
    end)

    it('only on the wall: nothing past its edge', function()
        state.backdropShadows.offset = { 160, 0 } -- most of the shadow lands past the wall's right edge (150)
        local img = render(state.physicsWorld)
        for x = 152, 190 do
            assert.are.equal(1, at(img, x, -20), 'past the wall at x ' .. x)
        end
        assert.is_true(at(img, 130, -20) < 0.9, 'on the wall, just inside its edge')
    end)

    it('off, nothing', function()
        state.backdropShadows = nil
        assert.are.equal(1, at(render(state.physicsWorld), 0, 10))
    end)
end)
