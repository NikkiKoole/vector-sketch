-- spec/mipo-chatter_spec.lua
-- Mipos standing around talk to each other (src/mipo-chatter.lua): one says MI,
-- a different one answers PO. One Mipo alone stays quiet, so does a held one.
-- Run with: love . --specs spec/mipo-chatter_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local camera = require('src.camera')
local mipoVoice = require('src.mipo-voice')
local chatter = require('src.mipo-chatter')

describe('mipo chatter', function()
    local world, mipos

    local function setUp(count)
        world = love.physics.newWorld(0, 9.81 * 100, true)
        state.physicsWorld = world
        state.world.paused = false
        registry.reset()
        objectManager.addThing('rectangle', { x = 0, y = 600, width = 3000, height = 40, bodyType = 'static',
            label = 'floor' })
        local CM = require('src.character-manager')
        mipos = {}
        for i = 1, count do
            mipos[i] = CM.createCharacter('humanoid', -300 + (i - 1) * 300, 140, 0.3)
        end
        camera.getInstance():setTranslation(0, 300)
        state.chatter.nextAt, state.chatter.answer = nil, nil
    end

    local function talking()
        local n = 0
        for _, instance in ipairs(mipos) do
            if mipoVoice.isTalking(instance) then n = n + 1 end
        end
        return n
    end

    -- run the chatter as if its timers had just run out
    local function due()
        state.chatter.nextAt = 0
        chatter.update()
    end

    after_each(function()
        state.chatter.nextAt, state.chatter.answer = nil, nil
        world:destroy()
    end)

    it('two Mipos: one says MI, a different one answers PO', function()
        setUp(2)
        due()
        assert.are.equal(1, talking())
        local answer = state.chatter.answer
        assert.is_not_nil(answer)
        local first
        for _, instance in ipairs(mipos) do
            if mipoVoice.isTalking(instance) then first = instance end
        end
        assert.are.equal(first.id, answer.from)

        answer.at = 0
        chatter.update()
        assert.are.equal(2, talking())
        assert.is_nil(state.chatter.answer)
        assert.is_true(state.chatter.nextAt > love.timer.getTime())
    end)

    it('one Mipo alone stays quiet', function()
        setUp(1)
        due()
        assert.are.equal(0, talking())
        assert.is_nil(state.chatter.answer)
    end)

    it('nothing while paused', function()
        setUp(2)
        state.world.paused = true
        due()
        assert.are.equal(0, talking())
        state.world.paused = false
    end)
end)
