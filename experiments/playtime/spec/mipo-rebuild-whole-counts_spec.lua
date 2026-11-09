-- spec/mipo-rebuild-whole-counts_spec.lua
-- The segment counts name parts (torso1..torsoN, neck1..neckN). The Mipo maker's drawn slider handed a
-- rebuild torsoSegments = 3.25 (dragged in quarter steps): the top torso was looked up as 'torso3.25',
-- so the arms, the neck and the head were jointed to nothing and fell off (2026-11-09). A rebuild
-- takes the counts as whole numbers.
-- Run with: love . --specs spec/mipo-rebuild-whole-counts_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')

-- every part reachable from torso1 over joints
local function looseParts(instance)
    local nameOf = {}
    for name, part in pairs(instance.parts) do nameOf[part.body] = name end
    local seen, queue = { [instance.parts.torso1.body] = true }, { instance.parts.torso1.body }
    while #queue > 0 do
        local body = table.remove(queue)
        for _, joint in ipairs(body:getJoints()) do
            local a, b = joint:getBodies()
            local other = (a == body) and b or a
            if nameOf[other] and not seen[other] then
                seen[other] = true
                queue[#queue + 1] = other
            end
        end
    end
    local loose = {}
    for body, name in pairs(nameOf) do
        if not seen[body] then loose[#loose + 1] = name end
    end
    table.sort(loose)
    return loose
end

describe('rebuilding a Mipo with a fractional segment count', function()
    local world

    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        math.randomseed(5); love.math.setRandomSeed(5)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    it('rounds the torso and neck counts and keeps the arms, neck and head on', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        CM.rebuildFromCreation(instance, { isPotatoHead = false, torsoSegments = 3.25, neckSegments = 1.75 })
        assert.are.equal(3, instance.dna.creation.torsoSegments)
        assert.are.equal(2, instance.dna.creation.neckSegments)
        assert.is_truthy(instance.parts.torso3)
        assert.is_truthy(instance.parts.neck2)
        assert.are.same({}, looseParts(instance))
    end)
end)
