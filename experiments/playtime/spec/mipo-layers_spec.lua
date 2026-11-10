-- The hair spike's hair drawn in its Mipo's own layers (src/mipo-layers.lua, docs/LANDING-2026-11.md
-- L2): each Mipo's head hair behind that Mipo and its bangs over its face, between the Mipos, so one
-- Mipo's bangs never go over another Mipo in front of it. And the textured world draws them.
if not love then return end

local sceneLoader = require('src.scene-loader')
local state = require('src.state')
local script = require('src.script')
local hairLocks = require('src.hair-locks')
local mipoLayers = require('src.mipo-layers')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

describe('mipo layers', function()
    local canvas

    setup(function()
        canvas = love.graphics.newCanvas(400, 300)
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        sceneLoader.loadScriptAndScene('hair')
    end)

    teardown(function()
        if state.scene.sceneScript then script.call('onUnload') end
        state.scene.sceneScript, state.scene.scriptPath = nil, nil
        canvas:release()
    end)

    it('puts each Mipo\'s head hair in its own z range', function()
        local byHolder = {}
        hairLocks.splits(function(z, fn, arg, mipoId)
            byHolder[arg] = byHolder[arg] or {}
            table.insert(byHolder[arg], { z = z, fn = fn, mipoId = mipoId })
        end)
        local heads = 0
        for _, instance in pairs(state.mipoInstances) do
            local s = byHolder[instance]
            if instance.hairLocks then
                heads = heads + 1
                assert.equal(2, #s)
                assert.equal(mipoLayers.z(instance, 'hairBack'), s[1].z)
                assert.equal(mipoLayers.z(instance, 'hairFront'), s[2].z)
                assert.equal(instance.id, s[1].mipoId)
                -- inside this Mipo's range: over the Mipo behind it, under the one in front
                local base = (instance.zGroupOffset or 0) * 1000
                assert.is_true(s[1].z > base and s[2].z < base + 1000)
            end
        end
        assert.is_true(heads > 0, 'the hair scene has Mipos with hair')
    end)

    it('draws a torso\'s coat over the torso, under the head, its back behind the Mipo', function()
        local instance
        for _, i in pairs(state.mipoInstances) do if i.parts.torso1 and i.parts.head then instance = i end end
        assert.is_not_nil(instance)
        local holder = hairLocks.attachBody(instance.parts.torso1.body, hairLocks.defaults, 'spec-torso')
        local back, front
        hairLocks.splits(function(z, _, arg) if arg == holder then back, front = back or z, z end end)
        hairLocks.detachBody('spec-torso')
        local _, torsoTop = mipoLayers.bodyRange(instance.parts.torso1.body)
        local headLow = mipoLayers.bodyRange(instance.parts.head.body)
        assert.equal(mipoLayers.z(instance, 'hairBack'), back)
        assert.equal(torsoTop + 0.5, front)
        assert.is_true(front < headLow)
    end)

    it('is drawn by the textured world', function()
        local drawn = 0
        local saved = hairLocks.splits
        hairLocks.splits = function(add) saved(function(z, _, arg, id) add(z, function() drawn = drawn + 1 end, arg, id) end) end
        love.graphics.setCanvas({ canvas, stencil = true })
        local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, state.physicsWorld)
        love.graphics.setCanvas()
        hairLocks.splits = saved
        assert.is_true(ok, tostring(err))
        assert.is_true(drawn > 0)
    end)
end)
