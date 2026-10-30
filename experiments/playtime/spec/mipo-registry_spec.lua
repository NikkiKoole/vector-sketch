-- spec/mipo-registry_spec.lua
-- The Mipo helpers in src/mipo-registry.lua (CL11: written in four modules before).
-- Run with: love . --specs spec/mipo-registry_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')

describe('mipo registry helpers', function()
    local mipo

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        mipoRegistry.reset()
        mipo = CM.createCharacter('humanoid', 0, 0, 0.3)
    end)

    after_each(function()
        mipoRegistry.reset()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('weighs every part', function()
        local sum = 0
        for _, part in pairs(mipo.parts) do sum = sum + part.body:getMass() end
        assert.is_near(sum, mipoRegistry.totalMass(mipo), 1e-9)
        assert.is_true(sum > 0)
    end)

    it("finds a part's subtree, the part first", function()
        local bodies = mipoRegistry.subtreeBodies(mipo, 'luarm', {})
        assert.are.equal(mipo.parts.luarm.body, bodies[1])
        local has = {}
        for _, b in ipairs(bodies) do has[b] = true end
        assert.is_true(has[mipo.parts.llarm.body] and has[mipo.parts.lhand.body])
        assert.is_nil(has[mipo.parts.torso1.body])
    end)

    it('finds the joint from parent to child, of a type when asked', function()
        local arm = mipoRegistry.jointBetween(mipo.parts.torso1.body, mipo.parts.luarm.body)
        assert.are.equal('revolute', arm:getType())
        assert.is_nil(mipoRegistry.jointBetween(mipo.parts.luarm.body, mipo.parts.torso1.body)) -- child -> parent
        local earParent = mipo.parts.head and mipo.parts.head.body or mipo.parts.torso1.body
        local ear = mipoRegistry.jointBetween(earParent, mipo.parts.lear.body)
        if ear and ear:getType() ~= 'revolute' then -- ears hang on a weld
            assert.is_nil(mipoRegistry.jointBetween(earParent, mipo.parts.lear.body, 'revolute'))
        end
    end)
end)
