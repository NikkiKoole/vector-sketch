-- spec/scene-light_spec.lua
-- The scene's light level (src/scene-light.lua, LIGHT-AND-SHADOW LS13): saved with the scene only when
-- it's on, its settings put on Mipo parts and taken off again (their own values back), contact shadows
-- and default lights set only while it's on, and a scene's own contact shadows left alone.
-- Run with: love . --specs spec/scene-light_spec.lua

if not love then return end

local state = require('src.state')
local sceneLight = require('src.scene-light')
local mipoRegistry = require('src.mipo-registry')

-- a stand-in Mipo: one part, one picture sfixture whose extra the level lights
local function fakeMipo(extra)
    local world = love.physics.newWorld(0, 0, true)
    local body = love.physics.newBody(world, 0, 0, 'dynamic')
    local fixture = love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
    fixture:setUserData({ type = 'sfixture', subtype = 'texfixture', id = 'x', extra = extra })
    mipoRegistry.register({ id = 'spec-mipo', parts = { torso1 = { body = body } } })
    return world
end

describe('the scene light level', function()
    local world

    before_each(function()
        mipoRegistry.reset()
        state.contactShadows = nil
        state.backdropShadows = nil
        state.shadowEveryOther = nil
        state.projectedShadows = nil
        sceneLight.load(nil)
    end)

    after_each(function()
        sceneLight.load(nil)
        mipoRegistry.reset()
        if world then world:destroy(); world = nil end
        state.contactShadows = nil
    end)

    it('is off by default and saves nothing then', function()
        assert.are.equal('off', sceneLight.level().name)
        assert.is_nil(sceneLight.save())
    end)

    it('steps off -> lit -> shadows -> full -> off and saves the level', function()
        assert.are.equal('lit', sceneLight.step())
        assert.are.same({ level = 'lit' }, sceneLight.save())
        assert.are.equal('shadows', sceneLight.step())
        assert.are.equal('full', sceneLight.step())
        assert.are.equal('off', sceneLight.step())
        sceneLight.load({ level = 'lit' })
        assert.are.equal('lit', sceneLight.level().name)
    end)

    it("lights a Mipo's parts and gives them their own values back", function()
        local extra = { main = { fgURL = 'x.png' }, plasticineLightZ = 0.2 }
        world = fakeMipo(extra)
        sceneLight.load({ level = 'lit' })
        sceneLight.apply()
        assert.is_true(extra.plasticine)
        assert.are.equal(0.75, extra.plasticineLightZ)
        assert.is_truthy(state.contactShadows)
        assert.is_truthy(state.sceneDefaultLights)

        sceneLight.unapply() -- as before a save
        assert.is_nil(extra.plasticine)
        assert.are.equal(0.2, extra.plasticineLightZ)
        assert.is_nil(state.contactShadows)
        assert.is_nil(state.sceneDefaultLights)

        sceneLight.apply() -- the next frame: on again
        assert.is_true(extra.plasticine)
        sceneLight.settings().level = 'off'
        sceneLight.apply()
        assert.is_nil(extra.plasticine)
        assert.are.equal(0.2, extra.plasticineLightZ)
    end)

    it('shadows adds wall shadows on everything behind, and takes them off again', function()
        sceneLight.load({ level = 'shadows' })
        sceneLight.apply()
        assert.is_truthy(state.backdropShadows)
        assert.are.equal('function', type(state.backdropShadows.wall))
        assert.is_true(state.backdropShadows.offset[1] > 0 and state.backdropShadows.offset[2] > 0,
            'away from a sun high on the left')
        assert.is_truthy(state.contactShadows)
        sceneLight.settings().level = 'off'
        sceneLight.apply()
        assert.is_nil(state.backdropShadows)
        assert.is_nil(state.shadowEveryOther)
        assert.is_nil(state.contactShadows)
    end)

    it('full: clay on the parts; 3D shadows only with a floor, saved with the scene', function()
        local extra = { main = { fgURL = 'x.png' } }
        world = fakeMipo(extra)
        sceneLight.load({ level = 'full' })
        sceneLight.apply()
        assert.is_true(extra.plasticine)
        assert.is_nil(extra.plasticineStrength, 'clay: its own strength, not 0')
        assert.is_nil(state.projectedShadows, 'no floor, no 3D shadows')
        assert.is_truthy(state.backdropShadows)

        sceneLight.settings().floor = { standY = 450, depth = 400 }
        sceneLight.apply()
        assert.is_truthy(state.projectedShadows)
        assert.are.equal(50, state.projectedShadows.floorY)
        assert.are.same({ level = 'full', floor = { standY = 450, depth = 400 } }, sceneLight.save())

        sceneLight.settings().floor = nil
        sceneLight.apply()
        assert.is_nil(state.projectedShadows, 'the floor gone: its shadows too')

        sceneLight.load({ level = 'off', floor = { standY = 10, depth = 100 } })
        assert.are.same({ level = 'off', floor = { standY = 10, depth = 100 } }, sceneLight.save(),
            'a floor is kept with the level off')
    end)

    it("leaves a scene's own contact shadows alone", function()
        local own = { strength = 0.3 }
        state.contactShadows = own
        sceneLight.load({ level = 'lit' })
        sceneLight.apply()
        assert.are.equal(own, state.contactShadows)
        sceneLight.step()
        sceneLight.apply()
        assert.are.equal(own, state.contactShadows)
    end)
end)
