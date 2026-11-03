-- spec/mipo-drag-press_spec.lua
-- A Mipo dragged hard into another that can't get away (backed against a wall) doesn't get its
-- limbs pushed through it: while it touches another Mipo the drag pulls softly
-- (box2d-pointerjoints touchingDragStrength). At full strength (40 of its weights) 21 limbs
-- crossed in 10 tries; in a pile such knots stayed (scripts/tests/hands-mess, 2026-11-01).
-- Parked (2026-11-01): pending while touchingDragStrength is off.
-- Run with: love . --specs spec/mipo-drag-press_spec.lua

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

local DT = 1 / units.stepsPerSecond()

local function step(world)
    world:update(DT)
    jointGuard.update()
    mipoActions.update()
    keepAngle.update(DT, {})
end

-- Crossed limbs between the two right after a 2 s push into the one at the wall.
local function pressIntoWall(seed)
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(unpack(callbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
    local wall = love.physics.newBody(world, 650, 500, 'static')
    love.physics.newFixture(wall, love.physics.newRectangleShape(100, 1200))
    local b = CM.createCharacter('humanoid', 350, 500, 0.3)
    CM.randomizeMipo(b)
    local a = CM.createCharacter('humanoid', -350, 500, 0.3)
    CM.randomizeMipo(a)
    for _ = 1, math.floor(2 / DT) do step(world) end
    local torso = a.parts.torso1.body
    local tx, ty = torso:getPosition()
    local weight = units.weight(mipoRegistry.totalMass(a))
    -- as input-manager's drag: dragStrength of its weights (makePointerJoint takes reference forces)
    local pj = pointerJoints.makePointerJoint('spec', torso, tx, ty,
        units.toReferenceForce(state.world.dragStrength * weight), 0.5)
    local bx = b.parts.torso1.body:getX()
    local steps = math.floor(2 / DT)
    for k = 1, steps do
        pj.joint:setTarget(tx + (bx + 600 - tx) * k / steps, ty)
        pointerJoints.softenWhenTouching(pj)
        step(world)
    end
    local crossed = 0
    for _, h in ipairs(jointGuard.hooks()) do
        if (h.a == a and h.b == b) or (h.a == b and h.b == a) then crossed = crossed + 1 end
    end
    pj.joint:destroy()
    world:destroy()
    return crossed
end

describe('a Mipo dragged into another against a wall', function()
    it('does not get its limbs pushed through', function()
        if not pointerJoints.touchingDragStrength then
            pending('parked: touchingDragStrength is off (pulling out of a group was weak too)')
            return
        end
        jointGuard.untangle = false
        local crossed = 0
        for seed = 1, 6 do crossed = crossed + pressIntoWall(seed) end
        jointGuard.untangle = true
        assert.is_true(crossed <= 2, crossed .. ' limbs pushed through in 6 tries')
    end)
end)
