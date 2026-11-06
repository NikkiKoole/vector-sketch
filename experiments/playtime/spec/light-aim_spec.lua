-- spec/light-aim_spec.lua
-- A directional LIGHT shines the way its body's +X points (its panel: "aim: rotate the body (body +X
-- = light dir)"). The shader took that as the way *to* the light, so a lamp aimed at a box lit the
-- box's far side, away from the lamp (found in the scene light-grass-check, 2026-11-06). A point
-- light was right: it lights the side facing it.
-- Run with: love . --specs spec/light-aim_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

-- mean brightness of the box's left and right halves (drawn around the world origin)
local function halves(world)
    local canvas = love.graphics.newCanvas(300, 300)
    box2dDrawTextured.makeCombinedImages()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.translate(150, 150)
    box2dDrawTextured.drawTexturedWorld(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    local img = canvas:newImageData()
    local sum, n = { 0, 0 }, { 0, 0 }
    for y = 50, 250 do
        for x = 50, 250 do
            local r, g, b, a = img:getPixel(x, y)
            if a > 0.9 then
                local side = x < 150 and 1 or 2
                sum[side], n[side] = sum[side] + (r + g + b) / 3, n[side] + 1
            end
        end
    end
    return sum[1] / n[1], sum[2] / n[2]
end

describe('a light aimed at a plasticine box', function()
    local lamp, light

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty, e.plasticine = true, true, true
        -- a strong swing and a round form, so which side is lit is plain
        e.plasticineLightGain, e.plasticineLightZ, e.plasticineFormRadius = 0.5, 0.35, 0.35
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'b8a48cff', pHex = 'b8a48cff' }
        -- the lamp on the left, its +X pointing right, at the box
        lamp = objectManager.addThing('rectangle', { x = -300, y = 0, width = 10, height = 10, bodyType = 'static' })
        light = fixtures.createSFixture(lamp.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        light:getUserData().extra.range = 5000
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('directional: lights the side facing the lamp', function()
        local left, right = halves(state.physicsWorld)
        assert.is_true(left > right, string.format('left %.3f, right %.3f', left, right))
    end)

    it('point: lights the side facing the lamp', function()
        light:getUserData().extra.lightType = 'point'
        local left, right = halves(state.physicsWorld)
        assert.is_true(left > right, string.format('left %.3f, right %.3f', left, right))
    end)
end)
