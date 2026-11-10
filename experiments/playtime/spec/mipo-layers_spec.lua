-- Hair drawn in its Mipo's own layers (src/mipo-layers.lua, docs/LANDING-2026-11.md L2): each Mipo's
-- head hair behind that Mipo and its bangs over its face, between the Mipos, so one Mipo's bangs never
-- go over another Mipo in front of it; a torso's coat over the torso, under the head. And the textured
-- world draws them. Two Mipos in a world of its own, no scene loaded (a scene's settings would stay
-- behind for the specs after this one: mipo-neck failed after it, 2026-11-10).
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local characterManager = require('src.character-manager')
local hairLocks = require('src.hair-locks')
local mipoLayers = require('src.mipo-layers')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

describe('mipo layers', function()
    local canvas, previousWorld, world, mipos

    setup(function()
        canvas = love.graphics.newCanvas(400, 300)
        previousWorld = state.physicsWorld
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        love.math.setRandomSeed(11)
        math.randomseed(11)
        mipos = {}
        for i = 1, 2 do
            local instance = characterManager.createCharacter('humanoid', i * 150, 0, 1)
            characterManager.randomizeMipoConstrained(instance)
            hairLocks.attach(instance, hairLocks.defaults)
            mipos[i] = instance
        end
    end)

    teardown(function()
        for _, instance in ipairs(mipos) do instance.hairLocks = nil end
        hairLocks.detachBodies()
        registry.reset()
        mipoRegistry.reset()
        world:setCallbacks()
        world:destroy()
        state.physicsWorld = previousWorld
        canvas:release()
    end)

    it('puts each Mipo\'s head hair in its own z range', function()
        local byHolder = {}
        hairLocks.splits(function(z, fn, arg, mipoId)
            byHolder[arg] = byHolder[arg] or {}
            table.insert(byHolder[arg], { z = z, fn = fn, mipoId = mipoId })
        end)
        assert.are_not.equal(mipos[1].zGroupOffset, mipos[2].zGroupOffset)
        for _, instance in ipairs(mipos) do
            assert.is_not_nil(instance.hairLocks, 'a Mipo without hair')
            local s = byHolder[instance]
            assert.equal(2, #s)
            assert.equal(mipoLayers.z(instance, 'hairBack'), s[1].z)
            assert.equal(mipoLayers.z(instance, 'hairFront'), s[2].z)
            assert.equal(instance.id, s[1].mipoId)
            -- inside this Mipo's range: over the Mipo behind it, under the one in front
            local base = (instance.zGroupOffset or 0) * 1000
            assert.is_true(s[1].z > base and s[2].z < base + 1000)
        end
    end)

    it('draws a torso\'s coat over the torso, under the head, its back behind the Mipo', function()
        local instance = mipos[1]
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
        hairLocks.splits = function(add)
            saved(function(z, _, arg, id) add(z, function() drawn = drawn + 1 end, arg, id) end)
        end
        love.graphics.setCanvas({ canvas, stencil = true })
        local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, world)
        love.graphics.setCanvas()
        hairLocks.splits = saved
        assert.is_true(ok, tostring(err))
        assert.equal(4, drawn) -- two layers for each of the two Mipos
    end)
end)
