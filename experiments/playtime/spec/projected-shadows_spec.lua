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

    it('two lights, two shadows: a lamp on the left and one on the right', function()
        state.projectedShadows.light = nil
        state.projectedShadows.lights = {
            { light = { kind = 'point', x = -100, h = 40, z = 80 } },
            { light = { kind = 'point', x = 100, h = 40, z = 80 }, strength = 0.3 },
        }
        local img = render(state.physicsWorld)
        -- from the left lamp the shadow lands right of the box, from the right lamp left of it
        assert.is_true(at(img, 110, 10) < 0.6, 'the left lamp\'s shadow: ' .. at(img, 110, 10))
        assert.is_true(at(img, -110, 10) < 0.8, 'the right lamp\'s, lighter: ' .. at(img, -110, 10))
        assert.is_true(at(img, -110, 10) > at(img, 110, 10), 'each its own strength')
    end)

    it('a board close behind the box catches a smaller shadow than the wall', function()
        -- the lamp at z 80, the box at 40: on the wall (z 0) twice the box, on a board at z 30 5/4 of it
        state.projectedShadows.boards = { { 25, 140, 30, 150 } } -- x 25..140, its foot at y 80, 150 tall
        local img = render(state.physicsWorld)
        -- on the wall the shadow reaches x 80, on the board only 40 * 5/4 = 50 (x 30 is the box's x 24)
        assert.is_true(at(img, 30, 30) < 0.6, 'the board at x 30: ' .. at(img, 30, 30))
        assert.is_true(at(img, 70, 30) > 0.99, 'the board at x 70 is past it (on the wall it was dark)')
        assert.is_true(at(img, 15, -40) < 0.6, 'the wall left of the board still dark')
    end)

    it('things at two depths: the front box throws its shadow onto the back one', function()
        -- a second box further back (z 20: standing on y 70), to the right; the lamp on the left
        local back = objectManager.addThing('rectangle', { x = 110, y = 30, width = 80, height = 80, bodyType = 'static' })
        local fixture = fixtures.createSFixture(back.body, 0, 0, subtypes.TEXFIXTURE, { width = 80, height = 80 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty = true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
        local backBody = back.body
        state.projectedShadows.light = { kind = 'point', x = -60, h = 40, z = 80 }
        state.projectedShadows.layers = {
            { z = 20, only = function(body) return body == backBody end },
            { z = DEPTH, only = function(body) return body ~= backBody end },
        }
        local function shot(withThings)
            box2dDrawTextured.makeCombinedImages()
            local canvas = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas({ canvas, stencil = true })
            love.graphics.clear(1, 1, 1, 1)
            love.graphics.push()
            love.graphics.translate(W / 2, H / 2)
            if withThings then projectedShadows.drawOnThings(state.physicsWorld) end
            love.graphics.pop()
            love.graphics.setCanvas()
            return canvas:newImageData()
        end
        local img = shot(true)
        -- the back box at x 70..150: from the lamp at x -60 the front box (x -40..40) falls on it up to x ~90
        local darkest = 1
        for x = 80, 120, 4 do darkest = math.min(darkest, at(img, x, 30)) end
        assert.is_true(darkest < 0.7, 'a shadow on the back box: ' .. darkest)
        assert.is_true(at(img, -100, 0) > 0.99, 'none where nothing is')
    end)

    it('a lamp behind the box throws its shadow forward onto the ground in front', function()
        -- the lamp between the wall and the box (z 20, the box at 40); the ground in front from y 90 (z 40)
        state.projectedShadows.light = { kind = 'point', x = 0, h = 40, z = 20 }
        local function front() love.graphics.rectangle('fill', -150, 90, 300, 60) end
        box2dDrawTextured.makeCombinedImages()
        local canvas = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear(1, 1, 1, 1)
        love.graphics.push()
        love.graphics.translate(W / 2, H / 2)
        projectedShadows.drawFront(state.physicsWorld, front)
        love.graphics.pop()
        love.graphics.setCanvas()
        local img = canvas:newImageData()
        -- the ground at z 60 (y 110): x 50 is the box's x 25, 20 up
        assert.is_true(at(img, 50, 110) < 0.6, 'in front of the box: ' .. at(img, 50, 110))
        assert.is_true(at(img, 110, 110) > 0.99, 'past its shadow')
        assert.are.equal(1, at(img, 0, 60), 'not outside the area')
    end)

    it('only on the area, and off draws nothing', function()
        state.projectedShadows.light = { kind = 'point', x = 0, h = 40, z = 50 } -- a huge shadow
        local img = render(state.physicsWorld)
        assert.are.equal(1, at(img, 0, -140), 'above the area')
        state.projectedShadows = nil
        assert.are.equal(1, at(render(state.physicsWorld), 50, 10))
    end)
end)
