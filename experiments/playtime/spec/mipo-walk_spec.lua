-- src/mipo-walk.lua (docs/MIPO-FACING.md MF6): a Mipo dragged sideways along the floor by a finger (a
-- pointer joint, as input-manager makes one) turns to face the way it's dragged and its legs step;
-- let go, it turns back to front. With walking off in the scene it does neither. The setting is saved
-- with the scene only when it's off.
-- Run with: love . --specs spec/mipo-walk_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local keepAngle = require('src.keep-angle')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local callbacks = require('src.physics.physics-callbacks')
local units = require('src.physics-units')
local facing = require('src.mipo-facing')
local mipoWalk = require('src.mipo-walk')

local DT = 1 / units.stepsPerSecond()

describe('a Mipo dragged along the floor', function()
    local simTime, realGetTime, world, inst

    local function step()
        simTime = simTime + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        mipoWalk.update(DT)
        keepAngle.update(DT, {})
    end

    local function seconds(s, each)
        for _ = 1, math.floor(s / DT) do
            step()
            if each then each() end
        end
    end

    -- the thighs' muscle targets while it's dragged: how far they swung each way
    local function thighSwing()
        local lo, hi = 0, 0
        return function()
            local b = mipoActions.getKeepAngle(inst.parts.luleg)
            if b and b.angle then lo, hi = math.min(lo, b.angle), math.max(hi, b.angle) end
        end, function() return lo, hi end
    end

    -- dragged by the torso, `distance` to the right over `time` seconds, `each` every step
    local function drag(distance, time, each)
        local torso = inst.parts.torso1.body
        local tx, ty = torso:getPosition()
        pointerJoints.grab('spec', torso, tx, ty)
        local pj = pointerJoints.getPointerJointAttachedTo(torso)
        local steps = math.floor(time / DT)
        for k = 1, steps do
            pj.joint:setTarget(tx + distance * k / steps, ty)
            step()
            if each then each() end
        end
        pointerJoints.killMouseJointIfPossible('spec')
    end

    before_each(function()
        simTime, realGetTime = 0, love.timer.getTime
        love.timer.getTime = function() return simTime end
        love.math.setRandomSeed(4)
        math.randomseed(4)
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(unpack(callbacks))
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        pointerJoints.resetPointerJoints()
        mipoWalk.load(nil) -- walking on, as in a scene that says nothing
        local floor = love.physics.newBody(world, 0, 1000, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(20000, 100)):setFriction(0.9)
        inst = CM.createCharacter('humanoid', 0, 600, 0.3)
        CM.randomizeMipoConstrained(inst)
        seconds(2) -- landed, standing
    end)

    after_each(function()
        pointerJoints.resetPointerJoints()
        world:setCallbacks()
        world:destroy()
        love.timer.getTime = realGetTime
        mipoWalk.load(nil)
    end)

    it('turns the way it is dragged and steps, then turns back to front', function()
        assert.equal('front', facing.get(inst))
        local track, swing = thighSwing()
        local walked, faced = false, nil
        drag(1500, 3, function()
            track()
            walked = walked or inst._walking == true
            faced = facing.get(inst)
        end)
        local lo, hi = swing()
        assert.is_true(walked, 'never walked')
        assert.equal('right', faced)
        assert.is_true(lo < -10 and hi > 10, ('thighs swung %.0f .. %.0f degrees'):format(lo, hi))
        seconds(5) -- let go: it stands, and turns back to front
        assert.equal('front', facing.get(inst))
        assert.is_false(mipoWalk.isTurning(inst))
    end)

    it('does neither with walking off in the scene', function()
        mipoWalk.settings().walk = false
        local track, swing = thighSwing()
        local walked = false
        drag(1500, 3, function()
            track()
            walked = walked or inst._walking == true
        end)
        local lo, hi = swing()
        assert.is_false(walked)
        assert.equal('front', facing.get(inst))
        assert.is_true(lo == 0 and hi == 0, ('thighs swung %.0f .. %.0f degrees'):format(lo, hi))
    end)

    it('keeps off a Mipo the scene holds (sitting, riding)', function()
        mipoWalk.hold(inst, true)
        local walked = false
        drag(1500, 3, function() walked = walked or inst._walking == true end)
        assert.is_false(walked)
        assert.equal('front', facing.get(inst))
    end)
end)

describe('the walking setting', function()
    it('puts the facing scene\'s switches back on a scene load', function()
        mipoWalk.auto, mipoWalk.rebuild, mipoWalk.hop, mipoWalk.lean, mipoWalk.armAt = true, true, true, false, 1
        mipoWalk.load(nil)
        assert.is_false(mipoWalk.auto)
        assert.is_false(mipoWalk.rebuild)
        assert.is_false(mipoWalk.hop)
        assert.is_true(mipoWalk.lean)
        assert.equal(0.6, mipoWalk.armAt)
    end)

    it('is saved with the scene only when off', function()
        mipoWalk.load(nil)
        assert.is_true(mipoWalk.isOn())
        assert.is_nil(mipoWalk.save())
        mipoWalk.load({ walk = false })
        assert.is_false(mipoWalk.isOn())
        assert.same({ walk = false }, mipoWalk.save())
        mipoWalk.load(nil)
    end)
end)
