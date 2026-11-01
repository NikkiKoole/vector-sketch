-- spec/feet-stand_spec.lua
-- Every foot picture (shape-catalogs handShapes: the hand is worn as a foot too) on a Mipo of
-- its own, dropped onto a floor three times: after each landing both feet come to rest flat.
-- A foot hangs from its picture's ankle point (src/shape8-dict.lua), near the heel end of a
-- straight sole: a wide stance (spec/standing_spec), and nothing to tip onto.
-- The same Mipos stand in scripts/feet-check, to look at (d drops them).
-- Run with: love . --specs spec/feet-stand_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local C = require('src.shape-catalogs')
local contactTracker = require('src.physics.contact-tracker')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

local DT = 1 / require('src.physics-units').stepsPerSecond()
local DROPS = 3
local SETTLE = 2.5 -- seconds after a drop; the feet are measured over the last half second
-- Flat: the foot touches the floor along its sole, contact points at least this share of its
-- length apart (on a heel, a toe or a thumb it touches in one place), and lies level. The
-- outlines' soles are straight from heel to toe (2026-11-01; before, most touched with their
-- toe half only, and a foot hanging from its heel tipped onto it): they rest on 0.43 (hand3r)
-- to 0.89 of their length, 0-1 degrees off level.
local FLAT = 0.35
local LEVEL = math.rad(5)

-- Not flat yet: each should be; when one is, take it out.
local TILTED = {}

-- How far a foot is from lying flat: built a quarter turn from its shin, flat is ±90 degrees.
local REST = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }
local function tilt(instance, foot)
    local d = instance.parts[foot].body:getAngle() - REST[foot]
    return math.abs(math.atan2(math.sin(d), math.cos(d)))
end

-- How much of its length a foot rests on: the spread of its contact points with the floor.
local function resting(instance, foot, floor)
    local body = instance.parts[foot].body
    local xs = {}
    for _, contact in ipairs(body:getContacts()) do
        local a, b = contact:getFixtures()
        if contact:isTouching() and (a:getBody() == floor or b:getBody() == floor) then
            local points = { contact:getPositions() }
            for i = 1, #points, 2 do xs[#xs + 1] = points[i] end
        end
    end
    if #xs < 2 then return 0 end
    local lo, hi, minX, maxX = math.huge, -math.huge, math.huge, -math.huge
    for _, x in ipairs(xs) do lo, hi = math.min(lo, x), math.max(hi, x) end
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
            for i = 1, #points, 2 do minX, maxX = math.min(minX, points[i]), math.max(maxX, points[i]) end
        end
    end
    return (hi - lo) / (maxX - minX)
end

-- Lift the whole Mipo by dy and let go.
local function lift(instance, dy)
    for _, part in pairs(instance.parts) do
        local body = part.body
        body:setPosition(body:getX(), body:getY() - dy)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

-- Per drop: the least either foot rested on (over the last half second), and its worst tilt.
local function drop(url)
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(4000, 100)):setFriction(0.9)
    local instance = CM.createCharacter('humanoid', 0, 500, 0.3)
    CM.updatePart('lfoot', { shape8URL = url }, instance)
    CM.updatePart('rfoot', { shape8URL = url }, instance)
    local least, worst = {}, {}
    for d = 1, DROPS do
        if d > 1 then lift(instance, 400) end
        least[d], worst[d] = 1, 0
        local steps = math.floor(SETTLE / DT)
        for step = 1, steps do
            world:update(DT)
            jointGuard.update()
            mipoActions.update()
            keepAngle.update(DT, {})
            if step > steps - math.floor(0.5 / DT) then
                worst[d] = math.max(worst[d], tilt(instance, 'lfoot'), tilt(instance, 'rfoot'))
                least[d] = math.min(least[d], resting(instance, 'lfoot', floor), resting(instance, 'rfoot', floor))
            end
        end
    end
    world:destroy()
    return least, worst
end

describe('feet', function()
    it('dropped three times, come to rest flat each time', function()
        local problems, report = {}, {}
        for _, name in ipairs(C.handShapes) do
            local url = name .. '.png'
            local least, worst = drop(url)
            local flat, rests, degrees = true, {}, {}
            for d = 1, DROPS do
                rests[d] = string.format('%.2f', least[d])
                degrees[d] = string.format('%.0f', math.deg(worst[d]))
                if least[d] < FLAT or worst[d] > LEVEL then flat = false end
            end
            report[#report + 1] = name .. ' ' .. table.concat(rests, '/') .. ' (' .. table.concat(degrees, '/') ..
                ' deg)' .. (flat and '' or ' NOT FLAT')
            if not flat and not TILTED[url] then
                problems[#problems + 1] = url .. ' does not come to rest flat (share of its length on the floor ' ..
                    'per drop: ' .. table.concat(rests, ', ') .. ')'
            elseif flat and TILTED[url] then
                problems[#problems + 1] = url .. ' lies flat now: take it out of TILTED'
            end
        end
        print('feet, share of the length on the floor after each drop (and degrees off level):\n  ' ..
            table.concat(report, '\n  '))
        assert.are.equal(0, #problems, table.concat(problems, '\n'))
    end)
end)
