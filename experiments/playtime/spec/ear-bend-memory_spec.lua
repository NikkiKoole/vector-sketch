-- spec/ear-bend-memory_spec.lua
-- ear-bend remembers, per body, what it found about an ear (src/ear-bend.lua bonesOf). The table
-- has weak keys, but an ear's entry holds its bones, and so the very body that is its key: Lua 5.1
-- never lets such a key go, so every rebuilt Mipo's old ear bodies were kept (and the LÖVE objects
-- behind them), 2 per rebuild. Destroyed bodies have to be forgotten.
-- Run with: love . --specs spec/ear-bend-memory_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local draw = require('src.physics.box2d-draw-textured')
local earBend = require('src.ear-bend')

describe('ear-bend remembering ears', function()
    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        math.randomseed(4); love.math.setRandomSeed(4)
    end)

    after_each(function()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    it('forgets the ears of a Mipo rebuilt again and again', function()
        local canvas = love.graphics.newCanvas(128, 128)
        local function frame()
            draw.makeCombinedImages()
            love.graphics.setCanvas({ canvas, stencil = true })
            draw.drawTexturedWorld(state.physicsWorld)
            love.graphics.setCanvas()
        end
        local mipo = CM.createCharacter('humanoid', 0, 0, 0.3)
        frame()
        local first = earBend._test.rememberedCount()
        for _ = 1, 30 do
            CM.rebuildFromCreation(mipo, {})
            frame()
        end
        collectgarbage('collect'); collectgarbage('collect')
        local after = earBend._test.rememberedCount()
        assert.is_true(after <= first + 4, first .. ' remembered at first, ' .. after .. ' after 30 rebuilds')
    end)

    it('draws ears in a new world after the old world was thrown away (its bodies released)', function()
        local canvas = love.graphics.newCanvas(128, 128)
        local function frame()
            draw.makeCombinedImages()
            love.graphics.setCanvas({ canvas, stencil = true })
            draw.drawTexturedWorld(state.physicsWorld)
            love.graphics.setCanvas()
        end
        CM.createCharacter('humanoid', 0, 0, 0.3)
        frame()
        state.physicsWorld:destroy()
        registry.reset()
        mipoRegistry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        CM.createCharacter('humanoid', 0, 0, 0.3)
        local ok, err = pcall(frame)
        assert.is_true(ok, tostring(err))
    end)
end)
