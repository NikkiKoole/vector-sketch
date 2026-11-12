-- src/mipo-walk.lua stopping and turning round (docs/MIPO-LOCOMOTION.md LO4). Told to stop, a walking
-- Mipo stops within about a leg's length and a second, upright. Told to go back the other way, it
-- doesn't moonwalk: it isn't pushed the new way while it still faces the old one (and walks), and
-- is going the new way within a few seconds. Prints the numbers per Mipo.
-- 'feet skid' is how fast the feet's middles move while they touch: a foot rocking on its heel or toe
-- counts too (a standing Mipo shows some), so compare it between settings, don't read it alone.
-- Compare settings: MOTOR_SET='stopStep=false,turnFirst=false' love . --specs spec/mipo-stop_spec.lua
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

describe('a Mipo stopping and turning round', function()
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

    for _, seed in ipairs(SEEDS) do
        it('stops, upright (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            mipoWalk.drive(inst, 1.5)
            seconds(3)
            local x0 = inst.parts.torso1.body:getX()
            local v0 = inst.parts.torso1.body:getLinearVelocity()
            mipoWalk.drive(inst, nil)
            local stoppedAt, worst, skid = nil, 0, 0
            seconds(2.5, function()
                local vx = inst.parts.torso1.body:getLinearVelocity()
                for _, n in ipairs({ 'lfoot', 'rfoot' }) do
                    local foot = inst.parts[n].body
                    if contactTracker.any(foot, function() return true end) then
                        skid = skid + math.abs((foot:getLinearVelocity())) * DT
                    end
                end
                worst = math.max(worst, tilt())
                if not stoppedAt and math.abs(vx) < 0.15 * len then stoppedAt = simTime end
                if stoppedAt and math.abs(vx) > 0.3 * len then stoppedAt = nil end
            end)
            local x1 = inst.parts.torso1.body:getX()
            local start = simTime - 2.5
            print(string.format('  stop seed %d: from %.1f legs/s, went %.2f legs, feet skid %.2f legs, still after %s s, worst tilt %.0f, end tilt %.0f',
                seed, v0 / len, (x1 - x0) / len, skid / len,
                stoppedAt and string.format('%.2f', stoppedAt - start) or 'never', worst, tilt()))
            assert.is_true(math.abs(x1 - x0) / len < 2) -- the fastest (seed 4, 2.1 legs/s) needs 1.56
            assert.is_truthy(stoppedAt)
            assert.is_true(tilt() < 30)
        end)

        it('turns round without moonwalking (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            mipoWalk.drive(inst, 1.5)
            seconds(3)
            mipoWalk.drive(inst, -1.5)
            local moon, goingAt, worst = 0, nil, 0
            seconds(4, function()
                local vx = inst.parts.torso1.body:getLinearVelocity()
                worst = math.max(worst, tilt())
                -- moonwalking: on the floor, still facing right, going left
                if mipoActions.isGrounded(inst) and facing.dir(inst) == 1 and vx < -0.3 * len then moon = moon + 1 end
                if not goingAt and vx < -0.5 * len and facing.dir(inst) == -1 then goingAt = simTime end
            end)
            local start = simTime - 4
            print(string.format('  turn seed %d: moonwalk %.2f s, going left after %s s, worst tilt %.0f, facing %s',
                seed, moon * DT, goingAt and string.format('%.2f', goingAt - start) or 'never', worst, facing.get(inst)))
            assert.is_true(moon * DT < 0.2)
            assert.is_truthy(goingAt)
            assert.is_true(worst < 60)
        end)
    end
end)
