-- spec/contact-shadows_spec.lua
-- Contact shadows (src/contact-shadows.lua, docs/LIGHT-AND-SHADOW.md LS6): a soft dark patch on what a
-- thing stands on, darker and tighter the closer it is, cut to the surface it falls on (no shadow over
-- nothing: past a shelf's edge, nothing; on a pictured surface, only where its picture is, not over the
-- see-through corners of its square: Nikki saw one float in the sky over a stone). Off
-- (state.contactShadows nil) it draws nothing.
-- Run with: love . --specs spec/contact-shadows_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local contactShadows = require('src.contact-shadows')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

local W, H = 400, 300

-- the shadows alone on a white canvas, the world's (0, 0) at the canvas centre
local function render(world)
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    contactShadows.drawAll(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas:newImageData()
end

-- darkest (lowest brightness) in a world-space box
local function darkest(img, x0, y0, x1, y1)
    local low = 1
    for y = y0 + H / 2, y1 + H / 2 do
        for x = x0 + W / 2, x1 + W / 2 do
            local r, g, b = img:getPixel(x, y)
            low = math.min(low, (r + g + b) / 3)
        end
    end
    return low
end

describe('contact shadows', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        state.contactShadows = { strength = 0.5 }
    end)

    after_each(function()
        state.contactShadows = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    -- a shelf whose top is at y = 50 and whose right edge is at x = 60
    local function shelf()
        objectManager.addThing('rectangle', { x = -40, y = 100, width = 200, height = 100, bodyType = 'static' })
    end

    it('on a sloped floor the shadow lies along the slope, both sides of the box', function()
        -- a floor turned 20 degrees (rising to the right), its top through about (0, 50)
        local floor = objectManager.addThing('rectangle', { x = 0, y = 100, width = 400, height = 100,
            bodyType = 'static' })
        floor.body:setAngle(-math.rad(20))
        -- a small box just above the slope at x = 0
        objectManager.addThing('rectangle', { x = 0, y = 25, width = 40, height = 20, bodyType = 'static' })
        local list = contactShadows.compute(state.physicsWorld)
        assert.are.equal(1, #list)
        assert.is_near(-math.rad(20), list[1].angle, 0.01, 'turned along the floor')
        -- darkened on the slope both left (lower) and right (higher) of the box's middle
        local img = render(state.physicsWorld)
        -- the floor's top: its centre (0, 100) plus (0, -50) turned -20 degrees, then along the slope
        local a = -math.rad(20)
        local tx, ty = 50 * math.sin(a), 100 - 50 * math.cos(a)
        local function onSlope(x) return math.floor(ty + (x - tx) * math.tan(a) + 4) end
        assert.is_true(darkest(img, -16, onSlope(-14) - 2, -12, onSlope(-14) + 2) < 0.9, 'left, down the slope')
        assert.is_true(darkest(img, 12, onSlope(14) - 2, 16, onSlope(14) + 2) < 0.9, 'right, up the slope')
    end)

    it('a box standing on a shelf darkens the shelf just under it', function()
        shelf()
        objectManager.addThing('rectangle', { x = -40, y = 25, width = 50, height = 50, bodyType = 'static' })
        local img = render(state.physicsWorld)
        assert.is_true(darkest(img, -50, 52, -30, 58) < 0.8, 'shelf top under the box')
    end)

    it('no shadow over nothing: past the shelf\'s edge, above its top', function()
        shelf()
        -- a box overhanging the shelf's right edge (x = 60)
        objectManager.addThing('rectangle', { x = 60, y = 25, width = 60, height = 50, bodyType = 'static' })
        local img = render(state.physicsWorld)
        assert.is_true(darkest(img, 30, 52, 55, 58) < 0.85, 'on the shelf, under the box')
        assert.are.equal(1, darkest(img, 62, 40, 110, 80), 'past the edge')
        assert.are.equal(1, darkest(img, -20, 40, 50, 49), 'above the shelf top')
    end)

    it('higher up, a lighter shadow', function()
        shelf()
        local box = objectManager.addThing('rectangle', { x = -40, y = 25, width = 50, height = 50, bodyType = 'static' })
        local near = darkest(render(state.physicsWorld), -50, 52, -30, 58)
        box.body:setPosition(-40, -25) -- 50 above the shelf
        local far = darkest(render(state.physicsWorld), -50, 52, -30, 58)
        assert.is_true(far > near + 0.05, string.format('near %.3f, far %.3f', near, far))
    end)

    it('on a pictured surface, only where its picture is: not over its see-through corners', function()
        -- a square shelf wearing a rounded picture (a stone in its square), a box on its top
        local shelfThing = objectManager.addThing('rectangle', { x = 0, y = 100, width = 200, height = 200,
            bodyType = 'static' })
        local fixture = fixtures.createSFixture(shelfThing.body, 0, 0, subtypes.TEXFIXTURE, { width = 200, height = 200 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty = true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
        box2dDrawTextured.makeCombinedImages()
        objectManager.addThing('rectangle', { x = 0, y = -25, width = 180, height = 50, bodyType = 'static' })
        local shadow = render(state.physicsWorld)
        -- the picture alone, to know where it's see-through
        local canvas = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.push()
        love.graphics.translate(W / 2, H / 2)
        box2dDrawTextured.drawPictureOf(fixture)
        love.graphics.pop()
        love.graphics.setCanvas()
        local picture = canvas:newImageData()
        local over, on = 0, 0
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local r = shadow:getPixel(x, y)
                if r < 0.97 then
                    local _, _, _, a = picture:getPixel(x, y)
                    if a < 0.5 then over = over + 1 else on = on + 1 end
                end
            end
        end
        assert.is_true(on > 50, 'shadow on the picture: ' .. on)
        assert.are.equal(0, over, 'shadow pixels where the picture is see-through')
    end)

    it('off, nothing', function()
        shelf()
        objectManager.addThing('rectangle', { x = -40, y = 25, width = 50, height = 50, bodyType = 'static' })
        state.contactShadows = nil
        assert.are.equal(1, darkest(render(state.physicsWorld), -100, 40, 100, 90))
    end)
end)
