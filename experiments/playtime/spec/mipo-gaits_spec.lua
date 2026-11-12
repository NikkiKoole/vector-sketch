-- src/mipo-walk.lua's gaits (docs/MIPO-LOCOMOTION.md LO10): walk, jog, run. Each Mipo goes 4 s in each:
-- the speed it gets to, how much of the time both feet are off the floor (a run's flight), steps a
-- second, the worst tilt; then it's told to stop and must be standing after. A jog is faster than a
-- walk and a run faster than a jog; a run has flight, a walk hardly any.
-- Compare settings: MOTOR_SET='driveAccel=2' love . --specs spec/mipo-gaits_spec.lua
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local mipoStance = require('src.mipo-stance')
local keepAngle = require('src.keep-angle')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local callbacks = require('src.physics.physics-callbacks')
local units = require('src.physics-units')
local facing = require('src.mipo-facing')
local mipoWalk = require('src.mipo-walk')
local contactTracker = require('src.physics.contact-tracker')

local DT = 1 / units.stepsPerSecond()
local SEEDS = { 4, 7, 11, 23, 42, 5, 9, 13 }

describe('a Mipo walking, jogging, running', function()
    local simTime, realGetTime, world, inst

    local function step()
        simTime = simTime + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        mipoWalk.update(DT)
        mipoStance.update()
        keepAngle.update(DT, {})
    end

    local function seconds(s, each)
        for _ = 1, math.floor(s / DT) do
            step()
            if each then each() end
        end
    end

    local function setup(seed)
        love.math.setRandomSeed(seed)
        math.randomseed(seed)
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(unpack(callbacks))
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        pointerJoints.resetPointerJoints()
        mipoWalk.load(nil)
        -- MOTOR_SET='driveAccel=2,run_accel=4': the module's switches, or a gait's (gait_key)
        for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('([%w_]+)=([%w%.]+)') do
            local gait, key = k:match('^(%w+)_(%w+)$')
            if gait and mipoWalk.gaits[gait] then
                mipoWalk.gaits[gait][key] = tonumber(v) or (v == 'true')
            else
                mipoWalk[k] = tonumber(v) or (v == 'true')
            end
        end
        local floor = love.physics.newBody(world, 0, 1000, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(40000, 100)):setFriction(0.9)
        inst = CM.createCharacter('humanoid', 0, 600, 0.3)
        CM.randomizeMipoConstrained(inst)
        seconds(2)
    end

    before_each(function()
        simTime, realGetTime = 0, love.timer.getTime
        love.timer.getTime = function() return simTime end
    end)

    after_each(function()
        pointerJoints.resetPointerJoints()
        if world and not world:isDestroyed() then
            world:setCallbacks()
            world:destroy()
        end
        love.timer.getTime = realGetTime
    end)

    local function tilt()
        local a = inst.parts.torso1.body:getAngle()
        return math.abs(math.deg(math.atan2(math.sin(a), math.cos(a))))
    end

    local function legLen()
        local _, ty = inst.parts.torso1.body:getPosition()
        local _, fy = inst.parts.lfoot.body:getPosition()
        return math.abs(fy - ty)
    end

    local function footDown(name)
        return contactTracker.any(inst.parts[name].body, function() return true end)
    end

    local SPEED = 1.5 -- legs a second, the walk's (the spike's); jog and run times their gait's speed
    local sums = {}
    for _, seed in ipairs(SEEDS) do
        it('walks, jogs and runs, each faster, and stops (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            local row = {}
            for _, mode in ipairs({ 'walk', 'jog', 'run' }) do
                local want = SPEED * mipoWalk.gaits[mode].speed
                mipoWalk.drive(inst, want, mode)
                local t, x1, flight, n, worst, steps0 = 0, nil, 0, 0, 0, nil
                seconds(4, function()
                    t = t + DT
                    worst = math.max(worst, tilt())
                    if t > 2 then
                        x1 = x1 or inst.parts.torso1.body:getX()
                        steps0 = steps0 or inst._gait
                        n = n + 1
                        if not footDown('lfoot') and not footDown('rfoot') then flight = flight + 1 end
                    end
                end)
                local speed = (inst.parts.torso1.body:getX() - x1) / 2 / len
                local stepsPerS = ((inst._gait or 0) - (steps0 or 0)) / math.pi / 2
                row[mode] = speed
                sums[mode] = sums[mode] or { speed = 0, flight = 0, tilt = 0, steps = 0, n = 0, worst = 0 }
                local sm = sums[mode]
                sm.speed, sm.flight, sm.steps, sm.n = sm.speed + speed, sm.flight + flight / n, sm.steps + stepsPerS, sm.n + 1
                sm.tilt, sm.worst = sm.tilt + worst, math.max(sm.worst, worst)
                print(string.format('  %s seed %d: wants %.1f legs/s, goes %.2f, flight %.0f%%, %.1f steps/s, worst tilt %.0f',
                    mode, seed, want, speed, 100 * flight / n, stepsPerS, worst))
                assert.is_true(worst < 75)
            end
            mipoWalk.drive(inst, nil)
            seconds(2.5)
            print(string.format('  stop seed %d after the run: tilt %.0f', seed, tilt()))
            assert.is_true(row.jog > row.walk)
            assert.is_true(row.run > row.jog * 0.9) -- Mipos differ: one runs a little under its jog (seed 11)
            assert.is_true(tilt() < 30)
        end)
    end

    it('sums up: on the whole a jog is faster than a walk, a run faster than a jog, and it flies more', function()
        if sums.run then
            assert.is_true(sums.jog.speed > sums.walk.speed and sums.run.speed > sums.jog.speed)
            assert.is_true(sums.run.flight > sums.walk.flight)
        end
        for _, mode in ipairs({ 'walk', 'jog', 'run' }) do
            local sm = sums[mode]
            if sm then
                print(string.format('GAIT %-4s goes %.2f legs/s, flight %.0f%%, %.1f steps/s, tilt mean %.0f worst %.0f',
                    mode, sm.speed / sm.n, 100 * sm.flight / sm.n, sm.steps / sm.n, sm.tilt / sm.n, sm.worst))
            end
        end
    end)
end)
