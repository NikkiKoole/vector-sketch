-- spec/mipo-band_spec.lua
-- The Mipos and Puppetmaker's band (src/mipo-band.lua): a pi/po note is sung by a
-- Mipo on stage when there's a crowd, not by one alone; in the puppetmaker style
-- a triangle makes a Mipo breathe. Notes play when the synth's audio clock reaches them (faked here).
-- Run with: love . --specs spec/mipo-band_spec.lua

if not love then return end
if not love.audio then -- spec runs open no audio device unless given --audio (conf.lua)
    describe('mipo band', function() pending('needs audio: love . --specs --audio') end)
    return
end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local camera = require('src.camera')
local mipoVoice = require('src.mipo-voice')

describe('mipo band', function()
    local world, mipos, realSynth, clock
    local band

    local function setUp(count)
        world = love.physics.newWorld(0, 980, true)
        state.physicsWorld = world
        state.world.paused = false
        registry.reset()
        mipoRegistry.reset()
        local CM = require('src.character-manager')
        mipos = {}
        for i = 1, count do mipos[i] = CM.createCharacter('humanoid', -300 + (i - 1) * 300, 140, 0.3) end
        camera.getInstance():setTranslation(0, 300)
        state.mipoBand.queue = {}
    end

    setup(function()
        realSynth = package.loaded['src.synth']
        clock = 0
        package.loaded['src.synth'] = { audioTime = function() return clock end }
        band = require('src.mipo-band')
    end)

    teardown(function()
        package.loaded['src.synth'] = realSynth
    end)

    after_each(function()
        if world then world:destroy() end
        world = nil
    end)

    local function hear(part, patch, midi, t)
        state.music.listeners['mipo-band'](part, patch, midi, 5, 300, t, 0)
    end

    local function talking()
        local n = 0
        for _, instance in ipairs(mipos) do
            if mipoVoice.isTalking(instance) then n = n + 1 end
        end
        return n
    end

    it('listens to the music', function()
        assert.is_function(state.music.listeners['mipo-band'])
    end)

    it('a crowd sings pi on time, in key with the note', function()
        setUp(3)
        clock = 10
        hear('sample', 'pi', 62, 10.2)
        band.update()
        assert.are.equal(0, talking(), 'sang before its time')
        clock = 10.25
        band.update()
        assert.are.equal(1, talking())
        assert.are.equal(0, #state.mipoBand.queue)
    end)

    it('one Mipo alone does not sing', function()
        setUp(1)
        clock = 20
        hear('sample', 'po3', 60, 20)
        band.update()
        assert.are.equal(0, talking())
    end)

    local function anyBreathing()
        for _, instance in ipairs(mipos) do
            local _, vy = instance.parts.torso1.body:getLinearVelocity()
            if vy < -50 then return true end
        end
        return false
    end

    local function withStyle(style, fn)
        local music = require('src.music')
        local real = music.nowPlaying
        music.nowPlaying = function() return { style = style } end
        local ok, err = pcall(fn)
        music.nowPlaying = real
        if not ok then error(err, 0) end
    end

    it('in the puppetmaker style a triangle makes a Mipo breathe', function()
        withStyle('puppetmaker', function()
            setUp(2)
            clock = 30
            hear('perc', 'triangle', 90, 30)
            band.update()
            assert.is_true(anyBreathing())
        end)
    end)

    it('other styles leave the Mipos be', function()
        withStyle('strum', function()
            setUp(2)
            clock = 35
            hear('perc', 'triangle', 90, 35)
            hear('chord', 'rhodes', 63, 35)
            band.update()
            assert.is_false(anyBreathing())
            assert.are.equal(0, #state.mipoBand.queue)
        end)
    end)

    it('a note that comes much too late is skipped', function()
        setUp(3)
        clock = 41
        hear('sample', 'pi', 60, 40)
        band.update()
        assert.are.equal(0, talking())
        assert.are.equal(0, #state.mipoBand.queue)
    end)
end)
