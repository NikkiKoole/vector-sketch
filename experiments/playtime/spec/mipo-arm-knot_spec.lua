-- spec/mipo-arm-knot_spec.lua
-- Arm knots (src/mipo-actions.lua, knotRescue): an arm flung straight up ends
-- just past vertical over the head with its elbow folded, and the hand's weight
-- holds it there for good. The Mipo notices after a while and pulls the arm down.
-- A pile must stay a pile: a whole-arm pull that never let up made Mipos fly out.
-- Run with: love . --specs spec/mipo-arm-knot_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

local DT = 1 / 60

local function into(body)
    for _, joint in ipairs(body:getJoints()) do
        local _, b = joint:getBodies()
        if b == body and joint:getType() == 'revolute' then return joint end
    end
end

-- the joint angle in lib.armRange terms (0 = hanging, degrees)
local function rangeAngle(joint) return math.deg(joint:getJointAngle() + joint:getReferenceAngle()) end

local function rotate(bodies, px, py, delta)
    local c, s = math.cos(delta), math.sin(delta)
    for _, body in ipairs(bodies) do
        local x, y = body:getPosition()
        local dx, dy = x - px, y - py
        body:setPosition(px + dx * c - dy * s, py + dx * s + dy * c)
        body:setAngle(body:getAngle() + delta)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

-- put one arm in the knot: shoulder at the top of its range, elbow folded all the way
local function knot(instance, side)
    local range = CM.armRange
    local upper, lower = instance.parts[side .. 'uarm'].body, instance.parts[side .. 'larm'].body
    local hand = instance.parts[side .. 'hand'].body
    local shoulder, elbow = into(upper), into(lower)
    local sx, sy = shoulder:getAnchors()
    local up = side == 'l' and range.luarm[2] or range.ruarm[1]
    rotate({ upper, lower, hand }, sx, sy, math.rad(up - rangeAngle(shoulder)))
    local ex, ey = elbow:getAnchors()
    local fold = side == 'l' and range.llarm[2] or range.rlarm[1]
    rotate({ lower, hand }, ex, ey, math.rad(fold - rangeAngle(elbow)))
end

local function newWorld()
    local world = love.physics.newWorld(0, 980, true)
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    return world
end

local function simulate(world, seconds, clock, each)
    for _ = 1, math.floor(seconds / DT) do
        clock.t = clock.t + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
        if each then each() end
    end
end

-- run `fn(world, clock)` on a simulated clock
local function withClock(fn)
    local clock = { t = 0 }
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return clock.t end
    local ok, err = pcall(fn, clock)
    love.timer.getTime = realGetTime
    if not ok then error(err, 0) end
end

local function standingMipo(seed)
    local world = newWorld()
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local instance = CM.createCharacter('humanoid', 0, 500, 0.3)
    CM.randomizeMipoConstrained(instance)
    return world, instance
end

describe('Mipo arm knots', function()
    it('arms hanging normally are left alone', function()
        withClock(function(clock)
            local before = mipoActions.stats.knots
            for _, seed in ipairs({ 1, 2, 3 }) do
                local world = standingMipo(seed)
                simulate(world, 5, clock)
                world:destroy()
            end
            assert.are.equal(before, mipoActions.stats.knots)
        end)
    end)

    it('a knotted arm gets pulled down after a while, not right away', function()
        withClock(function(clock)
            local stuck, total = 0, 0
            for seed = 1, 6 do
                local world, instance = standingMipo(seed)
                simulate(world, 2, clock)
                knot(instance, 'l')
                knot(instance, 'r')
                local before = mipoActions.stats.knots
                simulate(world, 1, clock)
                assert.are.equal(before, mipoActions.stats.knots, 'pulled right away')
                simulate(world, 5, clock)
                local l = rangeAngle(into(instance.parts.luarm.body))
                local r = rangeAngle(into(instance.parts.ruarm.body))
                if l > CM.armRange.luarm[2] - 20 then stuck = stuck + 1 end
                if r < CM.armRange.ruarm[1] + 20 then stuck = stuck + 1 end
                total = total + 2
                world:destroy()
            end
            -- without the rescue: 12 of 12 stay up
            assert.is_true(stuck <= 2, stuck .. ' of ' .. total .. ' arms still knotted')
        end)
    end)

    it('a pile of Mipos stays in its box', function()
        withClock(function(clock)
            for _, seed in ipairs({ 3, 41 }) do
                local world = newWorld()
                local box = love.physics.newBody(world, 0, 0, 'static')
                for _, r in ipairs({ { 0, 1000, 1400, 100 }, { -700, 500, 100, 1100 }, { 700, 500, 100, 1100 } }) do
                    love.physics.newFixture(box, love.physics.newRectangleShape(r[1], r[2], r[3], r[4])):setFriction(0.9)
                end
                love.math.setRandomSeed(seed)
                math.randomseed(seed)
                for i = 1, 6 do
                    CM.randomizeMipoConstrained(CM.createCharacter('humanoid', ((i % 3) - 1) * 150, 600 - i * 250, 0.3))
                end
                simulate(world, 14, clock)
                for _, instance in pairs(mipoRegistry.getAll()) do
                    local x, y = instance.parts.torso1.body:getPosition()
                    assert.is_true(math.abs(x) < 700 and y < 1000 and y > -1500, 'a Mipo left the box')
                end
                world:destroy()
            end
        end)
    end)
end)
