-- spec/mipo-rebuild-fixtureless_spec.lua
-- A rebuild that fails half way (a part shape Box2D refused, MEASURING M6) can leave a part's body
-- with no fixtures. The next rebuild read every part's first fixture to remember its pose and died
-- there (mipo-build getPoseCache: attempt to index a nil value). It has to rebuild the Mipo whole.
-- Run with: love . --specs spec/mipo-rebuild-fixtureless_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')

describe('rebuilding a Mipo with a part left without fixtures', function()
    local world

    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        math.randomseed(5); love.math.setRandomSeed(5)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    it('rebuilds it whole, every part with fixtures again', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        local hand = instance.parts.lhand.body
        local x, y = hand:getPosition()
        for _, fixture in ipairs(hand:getFixtures()) do fixture:destroy() end
        assert.are.equal(0, #hand:getFixtures())

        local ok, err = pcall(CM.rebuildFromCreation, instance, {})
        assert.is_true(ok, tostring(err))
        for name, part in pairs(instance.parts) do
            assert.is_true(#part.body:getFixtures() > 0, name .. ' has no fixtures')
            assert.are.equal(instance.groupIndex, part.body:getFixtures()[1]:getGroupIndex())
        end
        -- the hand is still about where it was (its pose came from the body, not its fixtures)
        local nx, ny = instance.parts.lhand.body:getPosition()
        assert.is_true(math.abs(nx - x) < 200 and math.abs(ny - y) < 200)
    end)
end)
