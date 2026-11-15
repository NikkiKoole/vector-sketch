-- spec/scene-light-lamps_spec.lua
-- Lamps throwing 3D shadows (src/scene-light.lua fillLamps, Nikki 2026-11-15): a point light with shadows3D
-- becomes one of the 3D lights beside the sun's, placed from its body (z = depth + inFront, h = floorY + z - y),
-- and goes again when it's turned off.
-- Run with: love . --specs spec/scene-light-lamps_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneLight = require('src.scene-light')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')

describe('a lamp throwing 3D shadows', function()
    local shared, lampExtra

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        local thing = objectManager.addThing('circle', { x = 300, y = 400, radius = 20, bodyType = 'static' })
        local fixture = fixtures.createSFixture(thing.body, 0, 0, subtypes.LIGHT, { radius = 10 })
        lampExtra = fixture:getUserData().extra
        lampExtra.lightType, lampExtra.colorHex, lampExtra.intensity = 'point', 'ffb060ff', 1
        -- a full level with a floor: the sun's 3D light first (src/scene-light.lua fullShared)
        shared = { projectedShadows = { floorY = 500, depth = 400, lights = {
            { light = { kind = 'sun', x = 0.5, h = 0.8, z = 0.5 }, strength = 0.5 } } } }
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('is not one until its 3D shadows are on', function()
        sceneLight.fillLamps(shared)
        assert.are.equal(1, #shared.projectedShadows.lights)
    end)

    it('stands where its body is, in front of the things, after the sun', function()
        lampExtra.shadows3D = true
        registry.sfixtureVersion = (registry.sfixtureVersion or 0) + 1 -- found again
        sceneLight.fillLamps(shared)
        local lights = shared.projectedShadows.lights
        assert.are.equal(2, #lights)
        assert.are.equal('sun', lights[1].light.kind)
        local lamp = lights[2].light
        assert.are.equal('point', lamp.kind)
        assert.are.equal(300, lamp.x)
        assert.are.equal(400 + sceneLight.LAMP_IN_FRONT, lamp.z)
        assert.are.equal(500 + lamp.z - 400, lamp.h) -- on screen at y = floorY + z - h
        assert.is_true(lights[2].strength > 0)
        lampExtra.shadows3D = nil
        registry.sfixtureVersion = registry.sfixtureVersion + 1
        sceneLight.fillLamps(shared)
        assert.are.equal(1, #shared.projectedShadows.lights)
    end)
end)
