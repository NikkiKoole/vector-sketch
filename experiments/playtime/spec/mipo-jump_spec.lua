-- src/mipo-walk.lua lib.jump (docs/MIPO-LOCOMOTION.md LO8): the jump as animation. A Mipo squats first
-- (its torso dips), then leaves the floor about lib.jumpHeight leg lengths up, lands and stands again,
-- upright. Facing a side and facing front; several Mipos (seeds). Prints the numbers per Mipo.
-- Compare settings: MOTOR_SET='jumpHeight=2' love . --specs spec/mipo-jump_spec.lua
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

describe('a Mipo jumping', function()
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

    for _, side in ipairs({ 'right', 'front' }) do
        for _, seed in ipairs(SEEDS) do
            it('squats, jumps, lands and stands (' .. side .. ', seed ' .. seed .. ')', function()
                setup(seed)
                if side ~= 'front' then
                    mipoWalk.turnTo(inst, side)
                    seconds(1.5)
                end
                local len = legLen()
                local y0 = inst.parts.torso1.body:getY()
                local footY0 = inst.parts.lfoot.body:getY()
                assert.is_true(mipoActions.jump(inst, 0))
                local dip, peak, feetUp, worst, leftAt = 0, 0, 0, 0, nil
                seconds(3, function()
                    local y = inst.parts.torso1.body:getY()
                    if not leftAt then dip = math.max(dip, y - y0) end
                    if not mipoActions.isGrounded(inst) and not leftAt then leftAt = simTime end
                    peak = math.max(peak, y0 - y)
                    feetUp = math.max(feetUp, footY0 - inst.parts.lfoot.body:getY())
                    worst = math.max(worst, tilt())
                end)
                local endTilt = tilt()
                print(string.format('  jump %s seed %d: leg %.0f, dip %.2f legs, torso up %.2f legs, feet up %.2f legs, worst tilt %.0f, end tilt %.0f, %s',
                    side, seed, len, dip / len, peak / len, feetUp / len, worst, endTilt,
                    mipoWalk.jumping(inst) and 'still jumping' or 'done'))
                assert.is_true(dip / len > 0.05)        -- the anticipation: it went down first
                assert.is_true(feetUp / len > 0.5)      -- it left the floor
                assert.is_false(mipoWalk.jumping(inst)) -- landed and finished
                assert.is_true(endTilt < 30)            -- standing again
            end)
        end
    end
end)
