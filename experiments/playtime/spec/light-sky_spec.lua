-- spec/light-sky_spec.lua
-- A sky light (a LIGHT sfixture, lightType 'sky'; docs/LIGHT-AND-SHADOW.md): light from all of above
-- in its colour and from all of below in its ground colour, wherever the light is. A shape's top
-- takes the sky's colour, its bottom the ground's, its front half of each. Under a blue sky over red
-- ground a plasticine box is bluer on top and redder underneath; turned upside down it still is
-- (above is the world's above, not the shape's).
-- Run with: love . --specs spec/light-sky_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

-- mean (blue - red) in the box's top and bottom thirds (drawn around the world origin)
local function blueness(world)
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
    local function band(y0, y1)
        local sum, n = 0, 0
        for y = y0, y1 do
            for x = 60, 240 do
                local r, _, b, a = img:getPixel(x, y)
                if a > 0.9 then sum, n = sum + (b - r), n + 1 end
            end
        end
        return sum / n
    end
    return band(50, 115), band(185, 250)
end

describe('a sky light', function()
    local box

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = fixture:getUserData().extra
        e.OMP, e.dirty, e.plasticine = true, true, true
        e.plasticineLightGain, e.plasticineLightZ, e.plasticineFormBaked = 0.5, 0.35, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = 'ccccccff', pHex = 'ccccccff' }
        -- the sky light off to the side: where it is doesn't matter
        local holder = objectManager.addThing('rectangle', { x = 400, y = 300, width = 10, height = 10, bodyType = 'static' })
        local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        local le = light:getUserData().extra
        le.lightType, le.colorHex, le.groundHex = 'sky', '3060ffff', 'ff3020ff'
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('the top takes the sky, the bottom the ground', function()
        local top, bottom = blueness(state.physicsWorld)
        assert.is_true(top > bottom + 0.03, string.format('blue - red: top %.3f, bottom %.3f', top, bottom))
    end)

    it('above is the world\'s above: the same with the box upside down', function()
        box.body:setAngle(math.pi)
        local top, bottom = blueness(state.physicsWorld)
        assert.is_true(top > bottom + 0.03, string.format('blue - red: top %.3f, bottom %.3f', top, bottom))
    end)
end)
