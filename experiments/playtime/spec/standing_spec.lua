-- spec/standing_spec.lua
-- Mipos standing on a grippy floor, simulated with the game's per-frame logic
-- (keep-angle, joint guard, actions) on a simulated clock. Guards against legs
-- that sag, tremble or keep hopping. Also a measuring tool: change the
-- assertion into prints to compare settings (repeat runs: results vary).
-- Run with: love . --specs spec/standing_spec.lua

if not love then return end

local contactTracker = require('src.physics.contact-tracker')

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CharacterManager = require('src.character-manager')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

local DT = 1 / 60

local function legDeviation(instance)
    local worst = 0
    for _, n in ipairs({ 'luleg', 'ruleg', 'llleg', 'rlleg' }) do
        local a = instance.parts[n].body:getAngle()
        worst = math.max(worst, math.abs(math.deg((a + math.pi) % (2 * math.pi) - math.pi)))
    end
    return worst
end

-- Simulate one random Mipo for `seconds`; returns the worst leg deviation over
-- the last 3s, actual leg motion per frame after 4s (degrees, 4 legs summed;
-- ~0 = still, trembling shows as a steady non-zero), and stand-up hops.
local function simulate(seed, seconds)
    local simTime = 0
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return simTime end
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local instance = CharacterManager.createCharacter('humanoid', 0, 500, 0.3)
    CharacterManager.randomizeMipoConstrained(instance)
    local hops0 = jointGuard.stats.standUpsByMipo[instance.id] or 0
    local frames = math.floor(seconds / DT)
    local lateWorst, motion, counted = 0, 0, 0
    local last = {}
    for f = 1, frames do
        simTime = simTime + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
        local t = f * DT
        -- actual leg motion between frames (degrees), after the physics step
        for _, n in ipairs({ 'luleg', 'ruleg', 'llleg', 'rlleg' }) do
            local a = math.deg(instance.parts[n].body:getAngle())
            if t > 4 and last[n] then
                motion = motion + math.abs(a - last[n])
            end
            last[n] = a
        end
        if t > 4 then counted = counted + 1 end
        if t > seconds - 3 then lateWorst = math.max(lateWorst, legDeviation(instance)) end
    end
    local hops = (jointGuard.stats.standUpsByMipo[instance.id] or 0) - hops0
    world:destroy()
    love.timer.getTime = realGetTime
    return lateWorst, motion / math.max(1, counted), hops -- motion: degrees per frame, 4 legs summed
end

describe('Mipo feet', function()
    -- A foot is built turned a quarter turn from its shin (flat). Its ankle range
    -- used to be counted from 'in line with the shin', so it was centred on a foot
    -- pointing straight down: Mipos stood on the tips of their feet.
    it('the ankle range is centred on flat, not on pointing down', function()
        local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        for _, seed in ipairs({ 11, 37 }) do
            love.math.setRandomSeed(seed)
            math.randomseed(seed)
            local instance = CharacterManager.createCharacter('humanoid', 0, 500, 0.3)
            CharacterManager.randomizeMipoConstrained(instance)
            for foot, flat in pairs({ lfoot = 90, rfoot = -90 }) do
                local body = instance.parts[foot].body
                for _, joint in ipairs(body:getJoints()) do
                    local _, b = joint:getBodies()
                    if b == body and joint:getType() == 'revolute' then
                        local low, up = joint:getLimits()
                        local centre = math.deg((low + up) / 2 + joint:getReferenceAngle())
                        assert.is_true(math.abs(centre - flat) < 1, foot .. ' range centred on ' .. centre)
                    end
                end
            end
        end
        world:destroy()
    end)
end)

describe('Mipos standing on a grippy floor', function()
        -- Outcomes are chaotic (Mipo ids are random, so part creation order and the
    -- landing differ per run): measured ~2 of 12 unsettled on average. Guard with
    -- a margin so a real regression fails but a single unlucky landing doesn't.
    it('at most 3 of 12 random Mipos fail to settle upright and still', function()
        local many = { 11, 23, 37, 41, 53, 67, 71, 83, 97, 101, 113, 127 }
        local bad = {}
        for _, seed in ipairs(many) do
            local worst, motion = simulate(seed, 10)
            if worst > 30 or motion > 1.5 then
                bad[#bad + 1] = string.format('%d (%d deg, %.1f/frame)', seed, worst, motion)
            end
        end
        assert.is_true(#bad <= 3, 'unsettled: ' .. table.concat(bad, ', '))
    end)
end)
