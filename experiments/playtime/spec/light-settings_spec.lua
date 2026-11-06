-- spec/light-settings_spec.lua
-- The light work's settings on the panels (docs/LIGHT-AND-SHADOW.md LS4): a texfixture's plasticine (and
-- hairs) section sets adding up, swing, from the front, baked form and its rise; a light's panel turns a
-- directional light's fading off (a sun: range 0) and sets a back light's width, which widens its rim.
-- Run with: love . --specs spec/light-settings_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local texfixtureParams = require('src.texfixture-params')
local sfixtureParams = require('src.sfixture-params')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

local function rowOf(rows, name)
    for _, row in ipairs(rows) do
        if row.key == name or row.label == name then return row end
    end
end

local function shown(row, target) return not row.visible or row.visible(target) end

describe('the light settings on the panels', function()
    local box, picture

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 220, height = 220, bodyType = 'static' })
        picture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = 220, height = 220 })
        local e = picture:getUserData().extra
        e.OMP, e.dirty, e.plasticine, e.plasticineFormBaked = true, true, true, true
        e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
            bgHex = '000000ff', fgHex = '606060ff', pHex = '606060ff' }
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('a shape\'s plasticine section sets the light settings', function()
        local rows = texfixtureParams.plasticine
        local e = picture:getUserData().extra
        rowOf(rows, 'adds up').set(picture, true)
        rowOf(rows, 'plasticineLightGain').set(picture, 0.4)
        rowOf(rows, 'plasticineLightZ').set(picture, 0.5)
        rowOf(rows, 'baked form').set(picture, true)
        rowOf(rows, 'plasticineFormRise').set(picture, 0.3)
        assert.are.same({ true, 0.4, 0.5, true, 0.3 }, { e.plasticineLightAdd, e.plasticineLightGain,
            e.plasticineLightZ, e.plasticineFormBaked, e.plasticineFormRise })
        rowOf(rows, 'baked form').set(picture, false)
        assert.is_false(shown(rowOf(rows, 'plasticineFormRise'), picture), 'rise only with a baked form')
        -- hairs read the same light
        assert.is_not_nil(rowOf(texfixtureParams.hairs, 'adds up'))
    end)

    it('a light\'s panel: a directional light without fading is a sun; a back light has a width', function()
        local holder = objectManager.addThing('rectangle', { x = 400, y = 0, width = 10, height = 10, bodyType = 'static' })
        local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        local le = light:getUserData().extra
        local rows = sfixtureParams.bySubtype[subtypes.LIGHT]
        rowOf(rows, 'fades').set(light, false)
        assert.are.equal(0, le.range)
        assert.is_false(shown(rowOf(rows, 'range'), light), 'no range for a sun')
        rowOf(rows, 'fades').set(light, true)
        assert.is_true(le.range > 0)
        le.lightType = 'back'
        assert.is_false(shown(rowOf(rows, 'fades'), light))
        assert.is_true(shown(rowOf(rows, 'width'), light))
        rowOf(rows, 'width').set(light, 0.1)
        assert.are.equal(0.1, le.rimWidth)
    end)

    it('a wider back light lights a wider rim', function()
        local sky = objectManager.addThing('rectangle', { x = -400, y = 400, width = 10, height = 10, bodyType = 'static' })
        fixtures.createSFixture(sky.body, 0, 0, subtypes.LIGHT, { radius = 10 }):getUserData().extra.lightType = 'sky'
        local holder = objectManager.addThing('rectangle', { x = 400, y = 0, width = 10, height = 10, bodyType = 'static' })
        local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        local le = light:getUserData().extra
        le.lightType, le.intensity = 'back', 2
        local function litPixels(width)
            le.rimWidth = width
            box2dDrawTextured.makeCombinedImages()
            local canvas = love.graphics.newCanvas(300, 300)
            love.graphics.setCanvas({ canvas, stencil = true })
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.push()
            love.graphics.translate(150, 150)
            box2dDrawTextured.drawTexturedWorld(state.physicsWorld)
            love.graphics.pop()
            love.graphics.setCanvas()
            return canvas:newImageData()
        end
        local base = litPixels(0.0001)
        local function count(img)
            local n = 0
            for y = 0, 299, 2 do
                for x = 0, 299, 2 do
                    local r = img:getPixel(x, y)
                    local r0 = base:getPixel(x, y)
                    if r > r0 + 0.05 then n = n + 1 end
                end
            end
            return n
        end
        local narrow, wide = count(litPixels(0.03)), count(litPixels(0.1))
        assert.is_true(wide > narrow * 1.3, string.format('narrow %d, wide %d', narrow, wide))
    end)
end)
