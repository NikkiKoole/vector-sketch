-- spec/light-off_spec.lua
-- Lights that are off (intensity 0) are left out of what the shaders loop over per pixel (src/render/
-- shaders.lua gatherLightsForBody; docs/MATERIALS.md, what the shaders cost): they added nothing. The
-- picture must not change: a shape with a lamp that's off next to one that's on draws as with only
-- the one that's on, and a shape whose lights are all off stays dark (not the shader's own default
-- light, which is what no light at all means).
-- Run with: love . --specs spec/light-off_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local shaders = require('src.render.shaders')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

local function brightness(world)
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
    for y = 60, 240, 2 do
        for x = 60, 240, 2 do
            local r, g, b, a = img:getPixel(x, y)
            if a > 0.9 then sum, n = sum + (r + g + b) / 3, n + 1 end
        end
    end
    return sum / n
end

local function lamp(x, y, extra)
    local holder = objectManager.addThing('rectangle', { x = x, y = y, width = 10, height = 10, bodyType = 'static' })
    local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
    for k, v in pairs(extra) do light:getUserData().extra[k] = v end
    return light
end

describe('lights that are off', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty, e.plasticine = true, true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('are left out of the lights a shape gets', function()
        lamp(-300, 0, { lightType = 'point', intensity = 1, range = 2000 })
        lamp(300, 0, { lightType = 'point', intensity = 0, range = 2000 })
        assert.are.equal(1, (shaders.gatherLightsForBody(nil)))
    end)

    it('change nothing next to one that is on', function()
        lamp(-300, 0, { lightType = 'point', intensity = 1, range = 2000 })
        local alone = brightness(state.physicsWorld)
        lamp(300, 0, { lightType = 'point', intensity = 0, range = 2000 })
        assert.is_true(math.abs(brightness(state.physicsWorld) - alone) < 0.002)
    end)

    it('all off: the shape stays dark, not lit by the default light', function()
        local unlit = brightness(state.physicsWorld) -- no light at all: the shader's own default light
        lamp(-300, 0, { lightType = 'point', intensity = 0, range = 2000 })
        assert.are.equal(1, (shaders.gatherLightsForBody(nil)))
        assert.is_true(brightness(state.physicsWorld) < unlit - 0.02)
    end)
end)
