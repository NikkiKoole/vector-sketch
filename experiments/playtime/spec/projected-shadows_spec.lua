-- spec/projected-shadows_spec.lua
-- 3D shadows (src/projected-shadows.lua, docs/LIGHT-AND-SHADOW.md LS22): a thing standing in front of the
-- wall throws a hard shadow from the light, along the floor behind it and up the wall. A lamp close to it
-- throws a bigger one than a lamp far off; a low sun stretches it far along the floor. Only on the area.
-- Run with: love . --specs spec/projected-shadows_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local projectedShadows = require('src.projected-shadows')

local W, H = 400, 300
-- the wall's foot at y 50, the things 40 in front of it: they stand on y 90; the floor behind is 50..90
local FLOOR_Y, DEPTH = 50, 40

local function area() love.graphics.rectangle('fill', -150, -120, 300, 210) end

local function render(world)
    box2dDrawTextured.makeCombinedImages()
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    projectedShadows.draw(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas:newImageData()
end

local function at(img, wx, wy)
    local r, g, b = img:getPixel(wx + W / 2, wy + H / 2)
    return (r + g + b) / 3
end

describe('projected shadows', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        -- a pictured box standing on the floor line: x -40..40, y 10..90 (0..80 high)
        local box = objectManager.addThing('rectangle', { x = 0, y = 50, width = 80, height = 80, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 80, height = 80 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty = true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
        state.projectedShadows = { area = area, floorY = FLOOR_Y, depth = DEPTH, strength = 0.6,
            light = { kind = 'point', x = 0, h = 40, z = 80 } }
    end)

    after_each(function()
        state.projectedShadows = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('a lamp close by throws a shadow on the wall twice the size, hard', function()
        -- halfway between the lamp (z 80) and the wall (0): x 50 on the wall is the box's x 25
        local img = render(state.physicsWorld)
        assert.is_true(at(img, 50, 10) < 0.6, 'on the wall beside the box: ' .. at(img, 50, 10))
        assert.is_true(at(img, 120, 10) > 0.99, 'past the doubled box')
        assert.is_true(at(img, 0, -110) > 0.99, 'above it')
    end)

    it('the lamp further off: the shadow shrinks to near the box\'s size', function()
        state.projectedShadows.light = { kind = 'point', x = 0, h = 40, z = 400 }
        local img = render(state.physicsWorld)
        assert.is_true(at(img, 50, 10) > 0.99, 'x 50 now lit: ' .. at(img, 50, 10))
        assert.is_true(at(img, 0, 10) < 0.6, 'straight behind the box still dark')
    end)

    it('a low sun on the left stretches it far right along the floor', function()
        state.projectedShadows.light = { kind = 'sun', x = -1, h = 0.25, z = 0.3 }
        local img = render(state.physicsWorld)
        -- the floor at depth 10 (y 60): x 100 is the box's x 0, 25 up
        assert.is_true(at(img, 100, 60) < 0.6, 'on the floor right of the box: ' .. at(img, 100, 60))
        assert.is_true(at(img, -100, 60) > 0.99, 'none on its left')
    end)

    it('only on the area, and off draws nothing', function()
        state.projectedShadows.light = { kind = 'point', x = 0, h = 40, z = 50 } -- a huge shadow
        local img = render(state.physicsWorld)
        assert.are.equal(1, at(img, 0, -140), 'above the area')
        state.projectedShadows = nil
        assert.are.equal(1, at(render(state.physicsWorld), 50, 10))
    end)
end)
