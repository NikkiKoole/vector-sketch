-- spec/mipo-hands_spec.lua
-- A Mipo hand on a hold (src/physics/snap.lua, handLetGo): hanging and swinging it holds
-- on, a hard drag pulls it free. Measured in the Mipo's own weight, so light and heavy
-- Mipos behave alike (a fixed force stopped working when Mipos got 4-10x lighter).
-- Run with: love . --specs spec/mipo-hands_spec.lua

if not love then return end

local contactTracker = require('src.physics.contact-tracker')

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local snap = require('src.physics.snap')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local units = require('src.physics-units')

local DT = 1 / 60

-- A Mipo (seed) holding a fixed hold with its left hand; `pull(i, instance)` each step.
-- Returns whether it still holds after `seconds`.
local function hang(seed, seconds, pull)
    local simTime = 0
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return simTime end
    local saved = { state.snap.onlyConnectWhenInteracted, state.snap.onlyBreakWhenInteracted }
    state.snap.onlyConnectWhenInteracted, state.snap.onlyBreakWhenInteracted = false, false
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    snap.reset()
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
    CM.randomizeMipoConstrained(instance)
    local hx, hy = instance.parts.lhand.body:getWorldCenter()
    local hold = love.physics.newBody(world, hx + 20, hy, 'static')
    love.physics.newFixture(hold, love.physics.newCircleShape(10)):setSensor(true)
    hold:setUserData({ thing = { id = 'HOLD', body = hold } })
    registry.registerBody('HOLD', hold)
    fixtures.createSFixture(hold, 0, 0, subtypes.SNAP, { radius = 8 })
    for i = 1, math.floor(seconds / DT) do
        simTime = simTime + DT
        if pull then pull(i, instance) end
        world:update(DT)
        snap.update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
    end
    local holds = #snap.joints() > 0
    world:destroy()
    state.snap.onlyConnectWhenInteracted, state.snap.onlyBreakWhenInteracted = saved[1], saved[2]
    love.timer.getTime = realGetTime
    return holds
end

describe('a Mipo hand on a hold', function()
    it('holds on while the Mipo hangs and swings', function()
        for seed = 1, 4 do
            assert.is_true(hang(seed, 4), 'seed ' .. seed .. ' fell off')
        end
    end)

    it('lets go when dragged down hard (the drag at full strength)', function()
        for seed = 1, 4 do
            local mj
            local holds = hang(seed, 3, function(i, instance)
                if i < 60 then return end
                local torso = instance.parts.torso1.body
                local tx, ty = torso:getPosition()
                if not mj then
                    local mass = 0
                    for _, part in pairs(instance.parts) do mass = mass + part.body:getMass() end
                    mj = love.physics.newMouseJoint(torso, tx, ty)
                    mj:setMaxForce(state.world.dragStrength * mass * 9.8 * units.meter())
                    mj:setFrequency(units.rate(5))
                end
                mj:setTarget(tx, ty + 1000) -- a yank: the finger far below
            end)
            assert.is_false(holds, 'seed ' .. seed .. ' still holds')
        end
    end)
end)
