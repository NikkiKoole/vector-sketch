-- spec/mipo-mouth_spec.lua
-- Mipos rest with a closed mouth: randomize picks from mouthShapes.restShapes
-- (it picked from all 15, mostly open speaking shapes, and 7 of 9 dollhouse
-- Mipos were born open-mouthed).
-- Run with: love . --specs spec/mipo-mouth_spec.lua

local mouthShapes = require('src.mouth-shapes')

describe('Mipo rest mouths', function()
    it('every rest shape exists', function()
        for _, name in ipairs(mouthShapes.restShapes) do
            assert.is_not_nil(mouthShapes.indexOf(name), name)
        end
    end)

    if not love then return end

    it('randomized Mipos are born with a closed mouth', function()
        local state = require('src.state')
        local registry = require('src.registry')
        local CM = require('src.character-manager')
        local world = love.physics.newWorld(0, 980, true)
        state.physicsWorld = world
        registry.reset()
        local rest = {}
        for _, name in ipairs(mouthShapes.restShapes) do rest[mouthShapes.indexOf(name)] = name end
        for seed = 1, 12 do
            math.randomseed(seed)
            love.math.setRandomSeed(seed)
            local instance = CM.createCharacter('humanoid', seed * 400, 0, 0.3)
            CM.randomizeMipo(instance)
            local owner = instance.dna.creation.isPotatoHead and 'torso1' or 'head'
            local shape = instance.dna.parts[owner].appearance.face.mouth.shape
            assert.is_not_nil(rest[shape], 'born with ' .. tostring(mouthShapes.normalized[shape].name))
        end
        world:destroy()
    end)
end)
