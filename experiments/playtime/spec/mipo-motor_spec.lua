-- src/mipo-walk.lua lib.drive (docs/MIPO-MOTOR.md): a Mipo walks by itself, its feet pushing it only
-- while one touches the floor; it turns to face the way it goes, stays upright, and stops when told.
-- Hopping: it leaves the floor again and again and gets somewhere. A jump with a forward speed goes
-- that way. Several Mipos (seeds), so a stubby or a tall one doesn't fall over.
-- Run with: love . --specs spec/mipo-motor_spec.lua

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

local DT = 1 / units.stepsPerSecond()
local SEEDS = { 4, 7, 11, 23, 42, 5, 9, 13 }

describe('a Mipo moving by itself', function()
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

    local function legLen()
        local t = inst.parts.torso1.body
        local f = inst.parts.lfoot.body
        local _, ty = t:getPosition()
        local _, fy = f:getPosition()
        return math.abs(fy - ty)
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
        -- MOTOR_SET='driveAccel=2,upright=0': the module's switches, to compare
        for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('(%w+)=([%w%.]+)') do
            mipoWalk[k] = tonumber(v) or (v == 'true')
        end
        local floor = love.physics.newBody(world, 0, 1000, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(40000, 100)):setFriction(0.9)
        inst = CM.createCharacter('humanoid', 0, 600, 0.3)
        CM.randomizeMipoConstrained(inst)
        seconds(2) -- landed, standing
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

    for _, seed in ipairs(SEEDS) do
        it('walks right then left, upright, and stops (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            local x0 = inst.parts.torso1.body:getX()
            local worst = 0
            mipoWalk.drive(inst, 1.5)
            -- once under way (after 1.5 s): how far the torso bobs, how far the left arm swings
            local t, yLo, yHi, aLo, aHi = 0, math.huge, -math.huge, math.huge, -math.huge
            seconds(4, function()
                worst = math.max(worst, tilt())
                t = t + DT
                if t > 1.5 then
                    local y = inst.parts.torso1.body:getY()
                    yLo, yHi = math.min(yLo, y), math.max(yHi, y)
                    local a = math.deg(inst.parts.luarm.body:getAngle())
                    aLo, aHi = math.min(aLo, a), math.max(aHi, a)
                end
            end)
            print(string.format('  bob seed %d: torso %.0f px (%.2f legs), arm swings %.0f deg', seed, yHi - yLo,
                (yHi - yLo) / len, aHi - aLo))
            local x1 = inst.parts.torso1.body:getX()
            assert.are.equal('right', facing.get(inst))
            mipoWalk.drive(inst, -1.5)
            seconds(4, function() worst = math.max(worst, tilt()) end)
            local x2 = inst.parts.torso1.body:getX()
            assert.are.equal('left', facing.get(inst))
            mipoWalk.drive(inst, nil)
            seconds(1.0)
            local xs = inst.parts.torso1.body:getX()
            seconds(0.5)
            local vx = (inst.parts.torso1.body:getX() - xs) / 0.5 -- drift after stopping
            print(string.format('  walk seed %d: leg %.0f, right %.1f legs, left %.1f legs, worst tilt %.0f deg, end vx %.0f',
                seed, len, (x1 - x0) / len, (x1 - x2) / len, worst, vx))
            assert.is_true((x1 - x0) / len > 2)
            assert.is_true((x1 - x2) / len > 1.5)
            assert.is_true(worst < 75) -- a tall one (seed 42) rocks ~60 deg: MIPO-MOTOR MM leftovers
            assert.is_true(math.abs(vx) < 0.75 * len) -- it sways as it stops, but goes nowhere
        end)

        it('hops forward (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            local x0 = inst.parts.torso1.body:getX()
            local hops, wasUp, worst = 0, false, 0
            mipoWalk.drive(inst, 1.5, 'hop')
            seconds(5, function()
                local up = not mipoActions.isGrounded(inst)
                if up and not wasUp then hops = hops + 1 end
                wasUp = up
                worst = math.max(worst, tilt())
            end)
            local x1 = inst.parts.torso1.body:getX()
            print(string.format('  hop seed %d: %d hops, %.1f legs, worst tilt %.0f deg', seed, hops, (x1 - x0) / len, worst))
            assert.is_true(hops >= 4)
            assert.is_true((x1 - x0) / len > 2)
            assert.is_true(worst < 60)
        end)
    end

    it('takes one step, or two, and stops', function()
        setup(4)
        mipoWalk.steps(inst, 1.5, 2)
        local took
        for k = 1, math.floor(4 / DT) do
            step()
            if not mipoWalk.driving(inst) then took = k * DT break end
        end
        print(string.format('  2 steps: done in %s s', tostring(took)))
        assert.is_truthy(took)
        assert.are.equal('right', facing.get(inst))
    end)

    it('hops once and stops', function()
        setup(4)
        local len = legLen()
        local x0 = inst.parts.torso1.body:getX()
        local hops, wasUp = 0, false
        mipoWalk.hopOnce(inst, 1.5)
        seconds(3, function()
            local up = not mipoActions.isGrounded(inst)
            if up and not wasUp then hops = hops + 1 end
            wasUp = up
        end)
        local x1 = inst.parts.torso1.body:getX()
        print(string.format('  one hop: %d off the ground, %.1f legs', hops, (x1 - x0) / len))
        assert.is_falsy(mipoWalk.driving(inst))
        assert.are.equal(1, hops)
        assert.is_true(x1 - x0 > 0)
    end)

    it('jumps the way it is told', function()
        setup(4)
        local x0, y0 = inst.parts.torso1.body:getPosition()
        local top = y0
        assert.is_true(mipoActions.jump(inst, 400))
        seconds(0.6, function() top = math.min(top, inst.parts.torso1.body:getY()) end)
        local x1 = inst.parts.torso1.body:getX()
        print(string.format('  jump: up %.0f, forward %.0f', y0 - top, x1 - x0))
        assert.is_true(y0 - top > 50)
        assert.is_true(x1 - x0 > 50)
    end)
end)
