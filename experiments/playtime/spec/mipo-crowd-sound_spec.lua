-- spec/mipo-crowd-sound_spec.lua
-- A pile of Mipos dropped into a box: the drop should be heard, but once the
-- pile lies still its limbs keep re-touching, and every touch used to be a
-- plonk (a calm dollhouse pile: ~6.5 a second). Counts impact sounds
-- (mipoVoice.stats.impacts) while dropping and while lying still.
-- Run with: love . --specs spec/mipo-crowd-sound_spec.lua

if not love then return end
if not love.audio then -- spec runs open no audio device unless given --audio (conf.lua)
    describe('Mipo impact sounds in a crowd', function() pending('needs audio: love . --specs --audio') end)
    return
end

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

-- Drop `count` Mipos into a box and simulate; returns impact sounds per second
-- in the first two seconds (the drop) and from 6 s on (lying still).
local function pile(seed, count, seconds)
    local simTime = 0
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return simTime end
    local world = love.physics.newWorld(0, 980, true)
    world:setCallbacks(unpack(callbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    mipoVoice.reset()
    local box = love.physics.newBody(world, 0, 0, 'static')
    for _, r in ipairs({ { 0, 1000, 1400, 100 }, { -700, 500, 100, 1100 }, { 700, 500, 100, 1100 } }) do
        love.physics.newFixture(box, love.physics.newRectangleShape(r[1], r[2], r[3], r[4])):setFriction(0.9)
    end
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    for i = 1, count do
        local instance = CharacterManager.createCharacter('humanoid', ((i % 3) - 1) * 150, 600 - i * 250, 0.3)
        CharacterManager.randomizeMipoConstrained(instance)
    end
    local drop, still, stillFrom = 0, 0, 6
    for f = 1, math.floor(seconds / DT) do
        simTime = simTime + DT
        local before = mipoVoice.stats.impacts
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        keepAngle.update(DT, {})
        mipoVoice.update(DT)
        local made = mipoVoice.stats.impacts - before
        local t = f * DT
        if t <= 2 then drop = drop + made end
        if t > stillFrom then still = still + made end
    end
    world:destroy()
    love.timer.getTime = realGetTime
    return drop / 2, still / (seconds - stillFrom)
end

describe('Mipo impact sounds in a crowd', function()
    -- physics in a pile is chaotic (runs differ), so judge the average of three piles.
    -- Before re-touches went quiet: lying still 1-3.3 a second, about as often as the drop.
    it('a pile is heard when it lands and goes quiet once it lies still', function()
        local drop, still = 0, 0
        for _, seed in ipairs({ 3, 17, 29 }) do
            local d, s = pile(seed, 6, 16)
            drop, still = drop + d / 3, still + s / 3
        end
        assert.is_true(drop >= 1.5, 'the drop should be heard: ' .. drop .. '/s')
        assert.is_true(still <= 1.2, 'a still pile keeps plonking: ' .. still .. '/s')
        assert.is_true(still < drop, 'lying still is as noisy as falling')
    end)
end)
