-- spec/mipo-daze_spec.lua
-- What counts as a hard landing (the daze, src/mipo-actions.lua) is measured in
-- src/mipo-voice.lua. It used impulse / mass of the part that was hit: a heavy-headed
-- Mipo (CnANW in the crowd scene: head 54, torso 23, legs ~0.4) put its weight on light legs,
-- stepping onto a slope at a few hundred read as 2000-17000, and it was dazed again
-- every few steps, never getting up. Now it is how fast the two met. (Seen live on the
-- dollhouse ribbons; a spec toss or shuffle didn't reproduce it, so this guards the other
-- side: the new measure must still daze a real fall.)
-- Run with: love . --specs spec/mipo-daze_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CharacterManager = require('src.character-manager')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local mipoVoice = require('src.mipo-voice')
local callbacks = require('src.physics.physics-callbacks')

local DT = 1 / 60

-- One heavy-headed Mipo over a floor with a slope; `throw(instance)` sets it going.
-- Returns the hard hits (speeds) the daze was told about.
local function run(throw, seconds)
    local simTime = 0
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return simTime end
    local world = love.physics.newWorld(0, 980, true)
    world:setCallbacks(unpack(callbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    mipoVoice.reset()
    local ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(ground, love.physics.newRectangleShape(0, 1000, 4000, 100)):setFriction(0.9)
    -- a 35 degree slope on the right made of short segments, like the dollhouse's ribbons
    -- (34 polygons): a leg sliding along it meets a new one every few steps
    local x1, y1, x2, y2, n = 200, 950, 1400, 110, 30
    for i = 0, n - 1 do
        local ax, ay = x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n
        local bx, by = x1 + (x2 - x1) * (i + 1) / n, y1 + (y2 - y1) * (i + 1) / n
        love.physics.newFixture(ground, love.physics.newPolygonShape(ax, ay, bx, by, bx, by + 20, ax, ay + 20))
            :setFriction(0.9)
    end

    love.math.setRandomSeed(7)
    math.randomseed(7)
    local instance = CharacterManager.createCharacter('humanoid', 0, 600, 0.3)
    CharacterManager.randomizeMipoConstrained(instance)
    -- CnANW's masses: head 54, torso 23 (its light legs carry all of it)
    for name, mass in pairs({ head = 54, torso1 = 23 }) do
        local body = instance.parts[name].body
        local ratio = mass / body:getMass()
        for _, f in ipairs(body:getFixtures()) do
            if not f:getUserData() then f:setDensity(f:getDensity() * ratio) end
        end
        body:resetMassData()
    end
    for _ = 1, 60 do world:update(DT) end -- settle

    local hits = {}
    local realHook = mipoVoice.onHardImpact
    mipoVoice.onHardImpact = function(inst, speed)
        if inst == instance then hits[#hits + 1] = speed end
        return mipoActions.onHardImpact(inst, speed)
    end
    throw(instance)
    for _ = 1, math.floor(seconds / DT) do
        simTime = simTime + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
        mipoVoice.update(DT)
    end
    mipoVoice.onHardImpact = realHook
    world:destroy()
    love.timer.getTime = realGetTime
    return hits
end

local function dazing(hits)
    local n = 0
    for _, s in ipairs(hits) do
        if s >= mipoActions.dazeSpeed then n = n + 1 end
    end
    return n
end

describe('what dazes a Mipo', function()
    it('a fall from high up still dazes it', function()
        local hits = run(function(instance)
            for _, p in pairs(instance.parts) do
                local x, y = p.body:getPosition()
                p.body:setPosition(x - 1200, y - 3000)
                p.body:setLinearVelocity(0, 0)
            end
        end, 4)
        assert.is_true(dazing(hits) > 0, 'no hard hit dazed it (' .. #hits .. ' hits)')
    end)
end)
