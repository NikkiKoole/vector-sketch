-- The arms (docs/MIPO-LOCOMOTION.md LO11): walking, jogging, running, the elbow's bend on average and how
-- far an upper arm swings; jumping, the arm through the crouch (back), the push and the air (up). A
-- run's elbows bend clearly more than a walk's; a jump's wind-up takes the arms back behind the body.
-- Compare settings: ARM_SET='run_armStiff=2,run_arms=40' love . --specs spec/mipo-arms_spec.lua
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

describe('a Mipo\'s arms', function()
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

    local function rel(a, b)
        local d = inst.parts[b].body:getAngle() - inst.parts[a].body:getAngle()
        return math.deg(math.atan2(math.sin(d), math.cos(d)))
    end
    local function ang(n)
        local a = inst.parts[n].body:getAngle()
        return math.deg(math.atan2(math.sin(a), math.cos(a)))
    end
    for _, seed in ipairs({ 4, 42 }) do
        it('arms (seed ' .. seed .. ')', function()
            setup(seed)
            for k, v in (os.getenv('ARM_SET') or ''):gmatch('([%w_]+)=([%w%.]+)') do
                local gait, key = k:match('^(%w+)_(%w+)$')
                mipoWalk.gaits[gait][key] = tonumber(v)
            end
            local elbows = {}
            for _, mode in ipairs({ 'walk', 'jog', 'run' }) do
                mipoWalk.drive(inst, 1.5 * mipoWalk.gaits[mode].speed, mode)
                local t, eSum, n, lo, hi = 0, 0, 0, 1e9, -1e9
                seconds(4, function()
                    t = t + DT
                    if t > 2 then
                        eSum, n = eSum + math.abs(rel('luarm', 'llarm')), n + 1
                        lo, hi = math.min(lo, ang('luarm')), math.max(hi, ang('luarm'))
                    end
                end)
                elbows[mode] = eSum / n
                print(string.format('ARMS seed %d %s: elbow %.0f deg on average, upper arm swings %.0f deg', seed, mode, eSum / n, hi - lo))
            end
            mipoWalk.drive(inst, nil)
            seconds(2.5)
            for _ = 1, 30 do -- standing on the floor (a run's stop can leave it bobbing a moment)
                if mipoActions.isGrounded(inst) then break end
                seconds(0.1)
            end
            local face = require('src.mipo-facing').dir(inst)
            assert.is_true(mipoActions.jump(inst, 0))
            local marks = {}
            seconds(1.2, function()
                local j = inst._jump
                local ph = j and j.phase or 'done'
                if marks[ph] == nil then marks[ph] = 0 end
                -- forward of hanging (degrees), the way it faces
                marks[ph] = math.max(marks[ph], -face * ang('luarm'))
                marks[ph .. '_min'] = math.min(marks[ph .. '_min'] or 1e9, -face * ang('luarm'))
            end)
            print(string.format('ARMS seed %d jump (facing %d): crouch back to %.0f, push up to %.0f, air %.0f..%.0f, land %.0f..%.0f',
                seed, face, marks.crouch_min or 0, marks.push or 0, marks.air_min or 0, marks.air or 0, marks.land_min or 0, marks.land or 0))
            assert.is_true(elbows.run > elbows.walk + 20) -- a run's arms bent
            assert.is_true((marks.crouch_min or 0) < -15)  -- the wind-up: arms back
            assert.is_true((marks.air or 0) > 40)          -- and up after the push
        end)
    end
end)
