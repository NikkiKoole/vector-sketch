-- spec/light-back_spec.lua
-- A back light (a LIGHT sfixture, lightType 'back'; docs/LIGHT-AND-SHADOW.md LS9): light from behind a
-- shape, towards you. Its edges glow in the light's colour, most on the side the light comes from (the
-- body's +X is the way it shines, like a directional light: from the left it shines right); its middle
-- stays as it was.
-- Run with: love . --specs spec/light-back_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

local function draw(world)
    box2dDrawTextured.makeCombinedImages()
    local canvas = love.graphics.newCanvas(300, 300)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.translate(150, 150)
    box2dDrawTextured.drawTexturedWorld(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas:newImageData()
end

-- mean brightness of the opaque pixels in columns x0..x1, rows 100..200
local function band(img, x0, x1)
    local sum, n = 0, 0
    for y = 100, 200 do
        for x = x0, x1 do
            local r, g, b, a = img:getPixel(x, y)
            if a > 0.9 then sum, n = sum + (r + g + b) / 3, n + 1 end
        end
    end
    return n > 0 and sum / n or 0
end

-- the shape's own left and right edge columns (first and last opaque pixel on the middle row)
local function edges(img)
    local first, last
    for x = 0, 299 do
        local _, _, _, a = img:getPixel(x, 150)
        if a > 0.9 then first = first or x; last = x end
    end
    return first, last
end

describe('a back light', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty, e.plasticine, e.plasticineFormBaked = true, true, true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = '606060ff', pHex = '606060ff' }
        -- a sky light already: without any light the shader uses a default of its own, so before and
        -- after would differ by more than the back light
        local sky = objectManager.addThing('rectangle', { x = -400, y = 400, width = 10, height = 10, bodyType = 'static' })
        local skyLight = fixtures.createSFixture(sky.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        skyLight:getUserData().extra.lightType = 'sky'
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('lights the edge on the side it comes from, not the middle', function()
        local before = draw(state.physicsWorld)
        local holder = objectManager.addThing('rectangle', { x = 400, y = 400, width = 10, height = 10, bodyType = 'static' })
        local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        local le = light:getUserData().extra
        le.lightType, le.colorHex, le.intensity = 'back', 'ffffffff', 1.5
        holder.body:setAngle(0) -- shines right: comes from the left
        local after = draw(state.physicsWorld)
        local left, right = edges(after)
        local leftGain = band(after, left + 4, left + 22) - band(before, left + 4, left + 22)
        local rightGain = band(after, right - 22, right - 4) - band(before, right - 22, right - 4)
        local middleGain = band(after, 140, 160) - band(before, 140, 160)
        assert.is_true(leftGain > 0.04, string.format('left edge brighter by %.3f', leftGain))
        assert.is_true(leftGain > rightGain * 2 + 0.02, string.format('left %.3f, right %.3f', leftGain, rightGain))
        assert.is_true(math.abs(middleGain) < 0.02, string.format('middle changed by %.3f', middleGain))
    end)
end)
