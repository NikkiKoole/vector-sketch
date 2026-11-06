-- spec/light-form-baked_spec.lua
-- The plasticine light on a baked form (extra.plasticineFormBaked, src/render/form-bake.lua): the
-- shader's own guess rounds only the outer edge, so the middle stays flat and a light from the side
-- barely changes it. Baked from the mask, the shape is round all the way in: the middle's near half
-- is clearly lighter than its far half. Off, it draws as before.
-- Run with: love . --specs spec/light-form-baked_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

-- mean brightness in a band (x0..x1) of the box drawn around the world origin, rows 110..190
local function band(world, x0, x1)
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
    local sum, n = 0, 0
    for y = 110, 190 do
        for x = x0, x1 do
            local r, g, b, a = img:getPixel(x, y)
            if a > 0.9 then sum, n = sum + (r + g + b) / 3, n + 1 end
        end
    end
    return sum / n
end

describe('the plasticine light on a baked form', function()
    local extra

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        extra = fixture:getUserData().extra
        extra.OMP, extra.dirty, extra.plasticine = true, true, true
        extra.plasticineLightGain, extra.plasticineLightZ = 0.5, 0.35
        extra.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'b8a48cff', pHex = 'b8a48cff' }
        -- a point light on the left
        local lamp = objectManager.addThing('rectangle', { x = -300, y = 0, width = 10, height = 10, bodyType = 'static' })
        local light = fixtures.createSFixture(lamp.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        light:getUserData().extra.range = 5000
        light:getUserData().extra.lightType = 'point'
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('lights the near half of the middle more than the shader alone does', function()
        local quick = band(state.physicsWorld, 100, 145) - band(state.physicsWorld, 155, 200)
        extra.plasticineFormBaked = true
        local baked = band(state.physicsWorld, 100, 145) - band(state.physicsWorld, 155, 200)
        assert.is_true(baked > 0.02 and baked > quick * 2,
            string.format('middle, near minus far: quick %.3f, baked %.3f', quick, baked))
    end)
end)
