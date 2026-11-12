-- src/mipo-walk.lua skipping and the triple jump (docs/MIPO-LOCOMOTION.md LO12). Skipping (the 'skip'
-- gait): it leaves the floor again and again, landing one foot at a time, gets somewhere, stays up.
-- Hop, step and jump (lib.tripleJump): after the run-up the phases come in order (hop, step, jump,
-- land), it goes a good way, and it ends standing. Prints the numbers per Mipo.
-- Compare settings: MOTOR_SET='tripleHop=0.5' love . --specs spec/mipo-skip_spec.lua
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

describe('a Mipo skipping, and hop step jump', function()
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

    local function down(name) return contactTracker.any(inst.parts[name].body, function() return true end) end

    for _, seed in ipairs(SEEDS) do
        it('skips: off the floor again and again, one foot at a time (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            mipoWalk.drive(inst, 1.5 * mipoWalk.gaits.skip.speed, 'skip')
            local x0, t, airs, wasUp, oneFoot, landings, worst = nil, 0, 0, false, 0, 0, 0
            seconds(5, function()
                t = t + DT
                if t < 1.5 then return end
                x0 = x0 or inst.parts.torso1.body:getX()
                worst = math.max(worst, tilt())
                local l, r = down('lfoot'), down('rfoot')
                local up = not mipoActions.isGrounded(inst)
                if up and not wasUp then airs = airs + 1 end
                if wasUp and not up then
                    landings = landings + 1
                    if l ~= r then oneFoot = oneFoot + 1 end
                end
                wasUp = up
            end)
            local went = (inst.parts.torso1.body:getX() - x0) / len
            print(string.format('  skip seed %d: %d times off the floor in 3.5 s, %d of %d landings on one foot, %.1f legs, worst tilt %.0f',
                seed, airs, oneFoot, landings, went, worst))
            assert.is_true(airs >= 4)
            assert.is_true(went > 1)
            assert.is_true(worst < 60)
        end)

        it('hop, step and jump (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            assert.is_true(mipoWalk.tripleJump(inst))
            local order, last, x0, worst = {}, nil, nil, 0
            seconds(6, function()
                local tj = inst._triple
                local ph = tj and tj.phase or 'done'
                if ph ~= last then
                    order[#order + 1] = ph
                    last = ph
                    if ph == 'hop' then x0 = inst.parts.torso1.body:getX() end
                end
                if tj and tj.phase ~= 'runup' then worst = math.max(worst, tilt()) end
            end)
            local went = x0 and math.abs(inst.parts.torso1.body:getX() - x0) / len or 0
            print(string.format('  triple seed %d: %s, %.1f legs from the hop on, worst tilt %.0f, end tilt %.0f',
                seed, table.concat(order, ' > '), went, worst, tilt()))
            assert.are.equal('runup > hop > step > jump > land > done', table.concat(order, ' > '))
            assert.is_true(went > 1.5) -- the slowest runner (seed 7, a 2.2 legs/s run) goes 1.7
            assert.is_true(tilt() < 30)
        end)
    end
end)
