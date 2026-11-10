-- spec/feet-hop_spec.lua
-- Random Mipos facing front, left and right hop the way they do by themselves (the band's breath
-- and doink, a jump, the untangle hop sideways), and after each landing their feet should come to
-- rest flat, not on a heel or a toe tip
-- (Nikki, 2026-11-10: Mipos end up on the heel or the tip of the foot, a lot after they jump by
-- themselves, and more when facing a side).
-- Also a measuring tool: FEET_HOP_REPORT=1 prints every landing.
-- Run with: love . --specs spec/feet-hop_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local contactTracker = require('src.physics.contact-tracker')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local units = require('src.physics-units')
local facing = require('src.mipo-facing')
local stance = require('src.mipo-stance')

local DT = 1 / units.stepsPerSecond()
local SEEDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local SETTLE = 2.0
local LEVEL = math.rad(8)
local MAX_NOT_FLAT = 10 -- of 720

local REST = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }
local function tilt(instance, foot)
    -- facing a side, a foot rests at its side's foot angle (src/mipo-facing.lua source)
    local d = instance.parts[foot].body:getAngle() - REST[facing.source(instance, foot)]
    return math.atan2(math.sin(d), math.cos(d))
end

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
    if #xs == 0 then return nil end -- in the air
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

local function sideways(instance, dir)
    local x, y = units.speed(jointGuard.untangleHop[1]), units.speed(jointGuard.untangleHop[2])
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then part.body:setLinearVelocity(dir * x, -y) end
    end
end

local HOPS = {
    breathe = function(instance) mipoActions.breathe(instance) end,
    doink = function(instance)
        instance.parts.torso1.body:applyLinearImpulse(0, units.impulse(1500))
    end,
    jump = function(instance) mipoActions.jump(instance) end,
    -- the untangle hop (src/mipo-joint-guard.lua hopOut): every part sideways and up
    left = function(instance) sideways(instance, -1) end,
    right = function(instance) sideways(instance, 1) end,
}
local ORDER = { 'breathe', 'breathe', 'doink', 'jump', 'left', 'breathe', 'right', 'jump', 'left', 'right' }

-- One random Mipo hops through ORDER; returns its landings that aren't flat.
local function run(seed, face, report)
    local simTime = 0
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return simTime end
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local instance = CM.createCharacter('humanoid', 0, 500, 0.3)
    CM.randomizeMipoConstrained(instance)
    local function step(seconds)
        for _ = 1, math.floor(seconds / DT) do
            simTime = simTime + DT
            world:update(DT)
            jointGuard.update()
            mipoActions.update()
            keepAngle.update(DT, {})
            stance.update()
        end
    end
    step(1)
    if face ~= 'front' then CM.switchFacing(instance, face) end
    local range = tonumber(os.getenv('FEET_HOP_RANGE') or '')
    if range then
        for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
            for _, j in ipairs(instance.parts[foot].body:getJoints()) do
                local _, bb = j:getBodies()
                if bb == instance.parts[foot].body and j:getType() == 'revolute' then
                    local lo, hi = j:getLimits()
                    local mid = (lo + hi) / 2
                    j:setLimits(mid - math.rad(range), mid + math.rad(range))
                end
            end
        end
    end
    step(2)
    local bad = {}
    for i, kind in ipairs(ORDER) do
        HOPS[kind](instance)
        step((kind == 'breathe' or kind == 'doink') and SETTLE or SETTLE + 3)
        for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
            local t, r = tilt(instance, foot), resting(instance, foot, floor)
            -- a foot off the floor (the other one carries) only counts if it hangs tipped
            -- level within LEVEL; a level sole may touch in one Box2D point (rests 0), that's fine
            local flat = math.abs(t) <= LEVEL
            if report then
                local ankle
                for _, j in ipairs(instance.parts[foot].body:getJoints()) do
                    local _, bb = j:getBodies()
                    if bb == instance.parts[foot].body and j:getType() == 'revolute' then ankle = j end
                end
                local lo, hi = ankle:getLimits()
                local ja = ankle:getJointAngle()
                local atLimit = (ja <= lo + 0.03 and 'LOW') or (ja >= hi - 0.03 and 'HIGH') or ''
                print(string.format(
                    '  %-5s seed %2d %-7s %s tilt %4.0f rests %.2f%s  shin %4.0f joint %4.0f [%4.0f %4.0f] %s',
                    face, seed, kind, foot, math.deg(t), r or -1, flat and '' or '  <-',
                    math.deg(instance.parts[instance.entryMap[foot].parent].body:getAngle()),
                    math.deg(ja), math.deg(lo), math.deg(hi), atLimit))
            end
            if not flat then bad[#bad + 1] = string.format('%s seed %d hop %d (%s) %s: %.0f deg, rests %.2f',
                face, seed, i, kind, foot, math.deg(t), r or -1) end
        end
    end
    world:destroy()
    love.timer.getTime = realGetTime
    return bad
end

describe('feet after a hop', function()
    it('land flat, not on a heel or a toe', function()
        local report = os.getenv('FEET_HOP_REPORT') ~= nil
        -- measuring: FEET_HOP_STANCE=0 (no ankle or knee motors), FEET_HOP_KNEES=0, FEET_HOP_FRONT=1
        stance.ankles = os.getenv('FEET_HOP_STANCE') ~= '0'
        stance.knees = os.getenv('FEET_HOP_STANCE') ~= '0' and os.getenv('FEET_HOP_KNEES') ~= '0'
        stance.kneesFront = os.getenv('FEET_HOP_FRONT') == '1'
        stance.ankleStrength = tonumber(os.getenv('FEET_HOP_AS') or '') or stance.ankleStrength
        stance.kneeStrength = tonumber(os.getenv('FEET_HOP_KNEE') or '') or stance.kneeStrength
        local all, landings = {}, 0
        local per = {}
        for _, face in ipairs({ 'front', 'left', 'right' }) do
            local before = #all
            for _, seed in ipairs(SEEDS) do
                for _, b in ipairs(run(seed, face, report)) do all[#all + 1] = b end
                landings = landings + #ORDER * 2
            end
            per[#per + 1] = face .. ' ' .. (#all - before)
        end
        print('feet-hop, not flat by facing: ' .. table.concat(per, ', '))
        print(string.format('feet-hop: %d of %d landings not flat', #all, landings))
        -- 2026-11-10: 96 of 720 before (a limp ankle, thin legs: 38 fell over, 58 feet tipped), 8 with
        -- src/mipo-stance.lua and legs as wide as drawn (mipo-build fitLegWidth); 7 of those are seed 7
        -- falling over after the sideways untangle hops (lying down, not on a toe)
        assert.is_true(#all <= MAX_NOT_FLAT,
            #all .. ' of ' .. landings .. ' landings not flat:\n' .. table.concat(all, '\n'))
    end)
end)
