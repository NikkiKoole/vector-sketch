-- spec/mipo-untangle_spec.lua
-- Two Mipos knotted together (src/mipo-joint-guard.lua, untangle): a hard drag
-- forced the limbs of one through the other and they stayed hooked. After a
-- while (neither held) their limbs pass through each other until they're free.
-- A Mipo sitting on another is not a knot and stays. The knot is a real one,
-- saved from the dollhouse (spec/fixtures/tangled-mipos.playtime.json: the two
-- Mipos and the room, 9 hooks between them).
-- Run with: love . --specs spec/mipo-untangle_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local sceneLoader = require('src.scene-loader')
local callbacks = require('src.physics.physics-callbacks')
local snap = require('src.physics.snap')

local DT = 1 / 60

local function newWorld()
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(unpack(callbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    for key in pairs(state.mipoTangles) do state.mipoTangles[key] = nil end
    for key in pairs(state.untangleTries) do state.untangleTries[key] = nil end
    return world
end

local function simulate(world, seconds, clock)
    for _ = 1, math.floor(seconds / DT) do
        clock.t = clock.t + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
    end
end

-- The clock goes on from test to test: the untangle remembers when it last looked (a clock
-- that went back to the start sat out a whole test waiting for that time to come again).
local clockT = 1000
local function withClock(fn)
    local clock = { t = clockT }
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return clock.t end
    local ok, err = pcall(fn, clock)
    love.timer.getTime = realGetTime
    clockT = clock.t + 10
    if not ok then error(err, 0) end
end

local function hookCount()
    return #jointGuard.hooks()
end

local function loadKnot()
    local world = newWorld()
    local f = assert(io.open(love.filesystem.getWorkingDirectory() .. '/spec/fixtures/tangled-mipos.playtime.json'))
    local json = f:read('*a')
    f:close()
    sceneLoader.loadSceneData(json, 'tangled-mipos')
    return world
end

describe('Mipo untangle', function()
    after_each(function() jointGuard.untangle = true end)

    it('the saved knot stays knotted without untangling', function()
        withClock(function(clock)
            jointGuard.untangle = false
            local world = loadKnot()
            simulate(world, 0.5, clock)
            assert.is_true(hookCount() > 0, 'the fixture is not knotted')
            simulate(world, 8, clock)
            assert.is_true(hookCount() > 0, 'came apart on its own')
            world:destroy()
        end)
    end)

    it('the knot comes apart after a while, and both Mipos stay in the room', function()
        withClock(function(clock)
            local before = jointGuard.stats.untangles or 0
            local world = loadKnot()
            simulate(world, 1, clock)
            assert.are.equal(before, jointGuard.stats.untangles or 0, 'untangled right away')
            simulate(world, 8, clock)
            assert.is_true((jointGuard.stats.untangles or 0) > before)
            assert.are.equal(0, hookCount())
            for _, instance in pairs(mipoRegistry.getAll()) do
                local vx, vy = instance.parts.torso1.body:getLinearVelocity()
                assert.is_true(math.sqrt(vx * vx + vy * vy) < 600, 'a Mipo is flying')
            end
            world:destroy()
        end)
    end)

    -- scripts/tests/feet-pile: a Mipo standing on two others' feet, its hands caught in both. It hopped
    -- away from one into the other and back, contacts off, every ~2.5 s for good (2026-11-01).
    it('a Mipo wedged between two others stops untangling after a few tries', function()
        withClock(function(clock)
            local world = newWorld()
            sceneLoader.loadScriptAndScene('feet-pile')
            local start = jointGuard.stats.untangles or 0
            simulate(world, 30, clock) -- tries start after ~10 s and end by ~25 s (at 60 steps a second)
            local early = jointGuard.stats.untangles or 0
            simulate(world, 15, clock)
            local late = jointGuard.stats.untangles or 0
            -- before: ~6 in these 15 s, and on for good. A pile plays out a little differently from run
            -- to run (one late try in ~7 full-suite runs), so one is allowed.
            assert.is_true(late - early <= 1, string.format('still untangling after 30 s: %d in the first 30 s, %d after',
                early - start, late - early))
            for _, t in pairs(state.mipoTangles) do
                assert.is_nil(t.untilT, 'a pair still passing through each other')
            end
            world:destroy()
        end)
    end)

    -- holding hands kept the arms crossed, and a hold only breaks while one of them is held
    it('two Mipos let go of each other\'s hands when they untangle', function()
        withClock(function(clock)
            local world = newWorld()
            sceneLoader.loadScriptAndScene('feet-pile')
            local function heldHands()
                local n = 0
                for _, joint in ipairs(snap.joints()) do
                    local a, b = joint:getBodies()
                    local ma, mb = mipoRegistry.getFromBody(a), mipoRegistry.getFromBody(b)
                    if ma and mb and ma ~= mb then n = n + 1 end
                end
                return n
            end
            assert.is_true(heldHands() > 0, 'nobody holds hands in feet-pile')
            local before = jointGuard.stats.untangles or 0
            simulate(world, 30, clock)
            assert.is_true((jointGuard.stats.untangles or 0) > before, 'nothing untangled')
            assert.are.equal(0, heldHands())
            world:destroy()
        end)
    end)

    it('a Mipo sitting on another is left alone', function()
        withClock(function(clock)
            local before = jointGuard.stats.untangles or 0
            for _, seed in ipairs({ 1, 2, 3 }) do
                local world = newWorld()
                local floor = love.physics.newBody(world, 0, 1000, 'static')
                love.physics.newFixture(floor, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
                love.math.setRandomSeed(seed)
                math.randomseed(seed)
                local below = CM.createCharacter('humanoid', 0, 500, 0.3)
                CM.randomizeMipoConstrained(below)
                simulate(world, 1.5, clock)
                local hx, hy = below.parts.head.body:getPosition()
                CM.randomizeMipoConstrained(CM.createCharacter('humanoid', hx, hy - 700, 0.3))
                simulate(world, 6, clock)
                world:destroy()
            end
            assert.are.equal(before, jointGuard.stats.untangles or 0)
        end)
    end)
    -- Nikki's pit (spec/fixtures/pit-knot.playtime.json, saved from the hair scene, 2026-11-10): 19
    -- Mipos in a bowl, three of them knotted into each other (25 hooks). Untangled pair by pair, each
    -- hop landed in the third Mipo; after 4 tries each it gave up and they lay knotted for good. As a
    -- group they pass through each other and drift apart. The file is cut down to the bowl, its floor
    -- and walls, the three and their two nearest neighbours (2.1 MB -> 0.28 MB); the old pair-by-pair
    -- untangle still leaves it knotted. Only Mipos in the bowl are checked for flying off.
    it('a knot of three in a crowded pit comes apart as a group, and stays apart', function()
        withClock(function(clock)
            local world = newWorld()
            local f = assert(io.open(love.filesystem.getWorkingDirectory() .. '/spec/fixtures/pit-knot.playtime.json'))
            local json = f:read('*a')
            f:close()
            sceneLoader.loadSceneData(json, 'pit-knot')
            local knot = { ['2Gk6Md'] = true, ['4awB8O'] = true, KAmBT = true }
            local function knotHooks()
                local n = 0
                for _, h in ipairs(jointGuard.hooks()) do
                    if knot[h.a.id] and knot[h.b.id] then n = n + 1 end
                end
                return n
            end
            simulate(world, 0.2, clock)
            assert.is_true(knotHooks() > 0, 'the fixture is not knotted')
            local inBowl = {}
            for id, instance in pairs(mipoRegistry.getAll()) do
                local x, y = instance.parts.torso1.body:getPosition()
                if x > -350 and x < 3050 and y < -1300 then inBowl[id] = instance end
            end
            local before = jointGuard.stats.untangles or 0
            local fastest = 0
            for _ = 1, 15 do
                simulate(world, 1, clock)
                for _, instance in pairs(inBowl) do
                    local vx, vy = instance.parts.torso1.body:getLinearVelocity()
                    fastest = math.max(fastest, math.sqrt(vx * vx + vy * vy))
                end
            end
            -- before: 5 untangles, 12-18 hooks left all the way; now one group untangle, 0 hooks
            assert.are.equal(0, knotHooks(), 'still knotted')
            assert.is_true((jointGuard.stats.untangles or 0) - before <= 2, 'untangled again and again')
            assert.is_true(fastest < 3000, 'a Mipo in the bowl flew at ' .. math.floor(fastest))
            world:destroy()
        end)
    end)
end)
