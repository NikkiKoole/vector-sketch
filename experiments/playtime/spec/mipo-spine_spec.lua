-- spec/mipo-spine_spec.lua
-- The spine test room (scripts/spine.playtime.json): P4re5, a Mipo with a tall torso, on a
-- floor between two walls (docs/MIPO-SPINE.md).
-- Run with: love . --specs spec/mipo-spine_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneLoader = require('src.scene-loader')
local contactTracker = require('src.physics.contact-tracker')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

local DT = 1 / 60

describe('the spine room', function()
    local world, simTime, realGetTime

    before_each(function()
        simTime = 0
        realGetTime = love.timer.getTime
        love.timer.getTime = function() return simTime end
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        sceneLoader.loadScriptAndScene('spine')
        world = state.physicsWorld
        world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    end)

    after_each(function()
        love.timer.getTime = realGetTime
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function simulate(seconds)
        for _ = 1, math.floor(seconds / DT) do
            simTime = simTime + DT
            world:update(DT)
            jointGuard.update()
            mipoActions.update()
            keepAngle.update(DT, {})
        end
    end

    it('has P4re5 standing on the floor', function()
        local instance = mipoRegistry.getAll().P4re5
        assert.is_truthy(instance, 'P4re5 is not in the room')
        local torso = instance.parts.torso1.body
        local _, y0 = torso:getPosition()
        simulate(4)
        local _, y1 = torso:getPosition()
        assert.is_true(math.abs(y1 - y0) < 100, string.format('torso moved from %d to %d', y0, y1))
        assert.is_true(math.abs(torso:getAngle()) < math.rad(20),
            string.format('torso leans %.0f degrees', math.deg(torso:getAngle())))
    end)
end)
