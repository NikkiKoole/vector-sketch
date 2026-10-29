-- spec/mipo-neck_spec.lua
-- A long neck holds the head up (character-manager balanceNeck, applyNeck, neckBend): each
-- neck segment weighs at least a quarter of the head and keeps itself upright, and the whole
-- neck bends at most 45 degrees spread over its joints. Before, 5 light segments of 22.5
-- degrees each folded under the head and it hung ~200 to the side (3BjZpF).
-- Run with: love . --specs spec/mipo-neck_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local contactTracker = require('src.physics.contact-tracker')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

local DT = 1 / require('src.physics-units').stepsPerSecond()

describe('a long neck', function()
    it('holds the head up over the torso, and the Mipo stands still', function()
        local simTime = 0
        local realGetTime = love.timer.getTime
        love.timer.getTime = function() return simTime end
        local ok, err = pcall(function()
            -- Mipos that stand still without a neck (seed 3 hops on its own legs)
            for _, seed in ipairs({ 1, 2, 4, 5, 6, 7, 8 }) do
                love.math.setRandomSeed(seed)
                math.randomseed(seed)
                local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
                world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
                state.physicsWorld = world
                registry.reset()
                mipoRegistry.reset()
                local floor = love.physics.newBody(world, 0, 1500, 'static')
                love.physics.newFixture(floor, love.physics.newRectangleShape(8000, 100)):setFriction(0.9)
                local instance = CM.createCharacter('humanoid', 0, 400, 0.3)
                CM.randomizeMipoConstrained(instance)
                CM.rebuildFromCreation(instance, { isPotatoHead = false, neckSegments = 5, noseSegments = 0 })
                local standUps
                local worst = 0
                for step = 1, math.floor(8 / DT) do
                    simTime = simTime + DT
                    world:update(DT)
                    jointGuard.update()
                    mipoActions.update()
                    keepAngle.update(DT, {})
                    if step * DT > 4 then
                        standUps = standUps or jointGuard.stats.standUps -- landing hops are fine
                        local head, torso = instance.parts.head.body, instance.parts.torso1.body
                        worst = math.max(worst, math.abs(head:getX() - torso:getX()))
                    end
                end
                local neckLength = 0
                for i = 1, 5 do neckLength = neckLength + instance.dna.parts['neck' .. i].dims.h * instance.scale end
                -- the head within 40% of the neck's length of the middle (it leans 20 degrees at
                -- most; 5 of 7 stay under 30%); before, all lay at ~100%: neck flat to the side
                assert.is_true(worst < neckLength * 0.4,
                    string.format('seed %d: head %d to the side (neck %d long)', seed, worst, neckLength))
                assert.are.equal(standUps, jointGuard.stats.standUps, 'seed ' .. seed .. ' kept hopping')
                world:destroy()
            end
        end)
        love.timer.getTime = realGetTime
        assert(ok, err)
    end)
end)
