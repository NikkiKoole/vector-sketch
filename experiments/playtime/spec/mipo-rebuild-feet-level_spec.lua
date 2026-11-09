-- spec/mipo-rebuild-feet-level_spec.lua
-- A rebuild keeps torso1 where it was. A Mipo that came out taller (the dice, longer legs) started with
-- its feet inside the floor and Box2D pushed it out in one step: the Mipo maker's dice shot Mipos
-- thousands of px up (2026-11-09, feet measured 307 px into the floor). A rebuild puts the Mipo's
-- lowest point back where it was, through either path (rebuildFromCreation, updatePart).
-- Run with: love . --specs spec/mipo-rebuild-feet-level_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local build = require('src.mipo-build')

describe('rebuilding a Mipo that comes out taller', function()
    local world

    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        math.randomseed(7); love.math.setRandomSeed(7)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    it('keeps its lowest point where it was (rebuildFromCreation)', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        local before = build.lowestPoint(instance)
        for _, name in ipairs({ 'luleg', 'llleg', 'ruleg', 'rlleg' }) do
            local dims = instance.dna.parts[name].dims
            dims.h = dims.h * 2
        end
        CM.rebuildFromCreation(instance, {})
        assert.is_true(math.abs(build.lowestPoint(instance) - before) < 1,
            'lowest ' .. build.lowestPoint(instance) .. ' was ' .. before)
    end)

    it('keeps its lowest point where it was (updatePart, a longer shin)', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        local before = build.lowestPoint(instance)
        local h = instance.dna.parts.llleg.dims.h
        CM.updatePart('llleg', { h = h * 2 }, instance)
        CM.updatePart('rlleg', { h = h * 2 }, instance)
        assert.is_true(math.abs(build.lowestPoint(instance) - before) < 1,
            'lowest ' .. build.lowestPoint(instance) .. ' was ' .. before)
    end)
end)
