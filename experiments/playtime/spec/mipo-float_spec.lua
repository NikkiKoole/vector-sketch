-- A walking Mipo keeps its feet on the floor (docs/MIPO-LOCOMOTION.md LO13). spec/fixtures/floaty-mipo.json
-- is the one that floated (Nikki 2026-11-12: "the middle green one seems to almost float when walking":
-- long thin legs, a light torso, off the floor 5-11% of a walk, 26% with the old walk): its DNA, saved
-- from the motor spike. Not solved yet (LO13): it's off the floor ~7% of a walk; this keeps it from
-- getting worse (under 12%) until it is; the goal is under 3%.
-- Compare settings: MOTOR_SET='walkGlue=0' love . --specs spec/mipo-float_spec.lua
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

describe('a walking Mipo stays on the floor', function()
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

    local json = require('vendor.dkjson')
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

    it('the floaty one walks with its feet down', function()
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(unpack(callbacks))
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        pointerJoints.resetPointerJoints()
        mipoWalk.load(nil)
        for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('([%w_]+)=([%w%.]+)') do
            mipoWalk[k] = tonumber(v) or (v == 'true')
        end
        local floor = love.physics.newBody(world, 0, 1000, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(40000, 100)):setFriction(0.9)
        local f = assert(io.open('spec/fixtures/floaty-mipo.json'))
        local saved = json.decode(f:read('*a'))
        f:close()
        inst = CM.createCharacterFromJustDNA(saved.dna, 0, 600, saved.scale, saved.dnaVersion)
        seconds(2)
        mipoWalk.drive(inst, 1.5, 'walk')
        local t, air, n = 0, 0, 0
        seconds(6, function()
            t = t + DT
            if t > 1.5 then
                n = n + 1
                if not mipoActions.isGrounded(inst) then air = air + 1 end
            end
        end)
        print(string.format('  floaty Mipo walking: off the floor %.1f%% of the time', 100 * air / n))
        assert.is_true(air / n < 0.12) -- the goal: 0.03 (LO13)
    end)
end)
