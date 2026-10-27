-- spec/mipo-actions_spec.lua
-- Run with: love . --specs spec/mipo-actions_spec.lua

if not love then return end

local CharacterManager = require('src.character-manager')
local mipoActions = require('src.mipo-actions')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local state = require('src.state')

local function enabledOf(instance, partName)
    local b = mipoActions.getKeepAngle(instance.parts[partName])
    return b and b.enabled
end

describe('src.mipo-actions', function()
    local world, instance

    before_each(function()
        world = love.physics.newWorld(0, 980, true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        instance = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it('ragdoll on makes every kept part limp, off makes legs upright again', function()
        mipoActions.setRagdoll(instance, true)
        assert.is_true(mipoActions.isRagdoll(instance))
        for _, name in ipairs({ 'torso1', 'luleg', 'rlleg' }) do
            assert.are.equal(false, enabledOf(instance, name))
        end
        mipoActions.setRagdoll(instance, false)
        assert.is_false(mipoActions.isRagdoll(instance))
        assert.is_nil(enabledOf(instance, 'luleg'))
        assert.is_nil(enabledOf(instance, 'torso1'))
    end)

    it('flip turns the torso over and stands on the arms, and back', function()
        local torso = instance.parts.torso1.body
        local before = torso:getAngle()
        mipoActions.setFlipped(instance, true)
        assert.is_true(mipoActions.isFlipped(instance))
        assert.is_near(before + math.pi, torso:getAngle(), 1e-6)
        assert.are.equal(false, enabledOf(instance, 'luleg'))
        assert.is_nil(enabledOf(instance, 'luarm'))
        mipoActions.setFlipped(instance, false)
        assert.is_false(mipoActions.isFlipped(instance))
        assert.is_nil(enabledOf(instance, 'luleg'))
        assert.are.equal(false, enabledOf(instance, 'luarm'))
    end)

    it('a hard landing dazes (limp), a soft one does not', function()
        mipoActions.onHardImpact(instance, mipoActions.dazeSpeed - 1)
        assert.is_false(mipoActions.isDazed(instance))
        mipoActions.onHardImpact(instance, mipoActions.dazeSpeed + 1000)
        assert.is_true(mipoActions.isDazed(instance))
        assert.is_true(mipoActions.isRagdoll(instance))
    end)

    it('wakes up after the daze and straightens again', function()
        mipoActions.onHardImpact(instance, mipoActions.dazeSpeed + 1000)
        instance._dazedUntil = love.timer.getTime() - 0.01
        mipoActions.update()
        assert.is_false(mipoActions.isDazed(instance))
        assert.is_false(mipoActions.isRagdoll(instance))
        assert.is_nil(enabledOf(instance, 'luleg'))
    end)

    it('never undoes a ragdoll switched on by hand', function()
        mipoActions.setRagdoll(instance, true)
        mipoActions.onHardImpact(instance, mipoActions.dazeSpeed + 1000)
        assert.is_false(mipoActions.isDazed(instance))
        mipoActions.update()
        assert.is_true(mipoActions.isRagdoll(instance))
    end)

    it('dazes no longer than dazeMax however often it is hit', function()
        mipoActions.onHardImpact(instance, 1e9)
        local start = instance._dazeStart
        for _ = 1, 5 do mipoActions.onHardImpact(instance, 1e9) end
        assert.is_true(instance._dazedUntil <= start + mipoActions.dazeMax + 1e-9)
    end)

    it('setting the same state twice is a no-op', function()
        mipoActions.setFlipped(instance, true)
        local angle = instance.parts.torso1.body:getAngle()
        mipoActions.setFlipped(instance, true)
        assert.is_near(angle, instance.parts.torso1.body:getAngle(), 1e-6)
    end)
end)
