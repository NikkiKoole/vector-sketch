-- src/mipo-walk.lua the recovery step (docs/MIPO-LOCOMOTION.md LO4b) and the squat. A standing Mipo
-- bumped (a push on its torso, soft and firm, either way) steps to catch itself and is standing after;
-- facing a side and facing front, several Mipos. Prints per Mipo: did it step, did it fall. A squat
-- goes down while held and comes back up. Compare: MOTOR_SET='recoverStep=false' love . --specs spec/mipo-recover_spec.lua
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

describe('a Mipo bumped, and squatting', function()
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
        for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('(%w+)=([%w%.]+)') do
            mipoWalk[k] = tonumber(v) or (v == 'true')
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

    local results = { stepped = 0, fell = 0, n = 0 }
    for _, side in ipairs({ 'right', 'front' }) do
        for _, push in ipairs({ 1.5, 3, 4.5 }) do -- leg lengths a second
            for _, seed in ipairs(SEEDS) do
                it('bumped ' .. push .. ' legs/s, stands (' .. side .. ', seed ' .. seed .. ')', function()
                    setup(seed)
                    if side ~= 'front' then
                        mipoWalk.turnTo(inst, side)
                        seconds(1.5)
                    end
                    local len = legLen()
                    local dir = (seed % 2 == 0) and 1 or -1 -- some pushed forward, some back
                    local mass = mipoRegistry.totalMass(inst)
                    inst.parts.torso1.body:applyLinearImpulse(dir * mass * push * len, 0)
                    local before = inst._recoverCount or 0
                    local y0 = inst.parts.torso1.body:getY()
                    local x0 = inst.parts.torso1.body:getX()
                    local feet0 = inst.parts.lfoot.body:getX() + inst.parts.rfoot.body:getX()
                    local worst = 0
                    seconds(3, function() worst = math.max(worst, tilt()) end)
                    local stepped = (inst._recoverCount or 0) - before
                    local drop = (inst.parts.torso1.body:getY() - y0) / len
                    local fell = tilt() > 45 or drop > 0.4
                    results.n = results.n + 1
                    if stepped > 0 then results.stepped = results.stepped + 1 end
                    if fell then results.fell = results.fell + 1 end
                    local moved = math.abs(inst.parts.torso1.body:getX() - x0) / len
                    local feetMoved = math.abs(inst.parts.lfoot.body:getX() + inst.parts.rfoot.body:getX() - feet0) / 2 / len
                    print(string.format('  bump %s %.1f %s seed %d: steps %d, worst tilt %.0f, end tilt %.0f, torso down %.2f legs, went %.2f legs, feet %.2f%s',
                        side, push, dir > 0 and 'fwd' or 'back', seed, stepped, worst, tilt(), drop, moved, feetMoved,
                        fell and ', FELL' or ''))
                    if push < 2 then assert.is_false(fell) end -- a soft bump: it stays up
                end)
            end
        end
    end

    it('sums up the bumps', function()
        print(string.format('BUMPS: %d of %d stepped, %d fell', results.stepped, results.n, results.fell))
    end)

    for _, side in ipairs({ 'right', 'front' }) do
        it('squats while held and stands up after (' .. side .. ')', function()
            setup(4)
            if side ~= 'front' then
                mipoWalk.turnTo(inst, side)
                seconds(1.5)
            end
            local len = legLen()
            local y0 = inst.parts.torso1.body:getY()
            mipoWalk.squat(inst, true)
            seconds(1)
            local down = (inst.parts.torso1.body:getY() - y0) / len
            mipoWalk.squat(inst, false)
            seconds(1.5)
            local after = (inst.parts.torso1.body:getY() - y0) / len
            print(string.format('  squat %s: down %.2f legs, after %.2f legs, tilt %.0f, %s', side, down, after, tilt(),
                mipoWalk.squatting(inst) and 'still squatting' or 'done'))
            assert.is_true(down > 0.1)
            assert.is_true(math.abs(after) < 0.1)
            assert.is_false(mipoWalk.squatting(inst))
            assert.is_true(tilt() < 30)
        end)
    end
end)
