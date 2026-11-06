-- spec/light-add_spec.lua
-- Light that adds up (docs/LIGHT-AND-SHADOW.md LS3), a shape's extra.plasticineLightAdd: the sky lights
-- are the base, every other light adds its colour and strength to it, a soft shoulder past full. Before,
-- how lit a shape is stopped at 1 (a second lamp near a lit shape added nothing) and a shape no light
-- reached kept a middling brightness. Off, it draws as before.
-- Run with: love . --specs spec/light-add_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
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

describe('light that adds up', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty, e.plasticine, e.plasticineLightAdd = true, true, true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('a second lamp in the same spot adds to the first (before: +12%)', function()
        lamp(-200, 0, { lightType = 'point', range = 2000, intensity = 0.6 })
        local one = brightness(state.physicsWorld)
        lamp(-200, 0, { lightType = 'point', range = 2000, intensity = 0.6 })
        local two = brightness(state.physicsWorld)
        assert.is_true(two > one * 1.5, string.format('one lamp %.3f, two %.3f', one, two))
    end)

    it('a shape no light reaches is dark', function()
        lamp(5000, 0, { lightType = 'point', range = 500, intensity = 1 })
        local dark = brightness(state.physicsWorld)
        assert.is_true(dark < 0.08, string.format('unlit %.3f', dark))
    end)

    it('a sky light alone lights it, less than the sky and a lamp', function()
        lamp(400, 400, { lightType = 'sky', colorHex = 'ffffffff', groundHex = '808080ff', intensity = 0.5 })
        local sky = brightness(state.physicsWorld)
        lamp(-200, 0, { lightType = 'point', range = 2000, intensity = 0.8 })
        local both = brightness(state.physicsWorld)
        assert.is_true(sky > 0.1, string.format('sky alone %.3f', sky))
        assert.is_true(both > sky * 1.15, string.format('sky %.3f, sky and a lamp %.3f', sky, both))
    end)
end)
