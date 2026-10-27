-- spec/heal-walls_spec.lua
-- Heal teleports a torn limb back onto its joint; it must not do that through a
-- wall (Mipo limbs got stuck inside the dollhouse walls).
-- Run with: love . --specs spec/heal-walls_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CharacterManager = require('src.character-manager')
local jointGuard = require('src.mipo-joint-guard')
local pointerJoints = require('src.physics.box2d-pointerjoints')

describe('heal and walls', function()
    local world, instance

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        pointerJoints.resetPointerJoints()
        instance = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
        local tx, ty = instance.parts.torso1.body:getPosition()
        pointerJoints.handlePointerPressed(tx, ty, 'mouse') -- held: heal is active
    end)

    after_each(function()
        pointerJoints.resetPointerJoints()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function yankHand(dx)
        local hand = instance.parts.lhand.body
        local x, y = hand:getPosition()
        hand:setPosition(x + dx, y)
        return x + dx
    end

    it('heals a torn limb when nothing is in the way', function()
        local yanked = yankHand(600)
        jointGuard.update()
        local x = instance.parts.lhand.body:getPosition()
        assert.is_true(math.abs(x - yanked) > 300)
    end)

    it('does not teleport a limb through a wall', function()
        local hx = instance.parts.lhand.body:getPosition()
        local wall = love.physics.newBody(world, hx + 300, 0, 'static')
        love.physics.newFixture(wall, love.physics.newRectangleShape(20, 3000))
        local yanked = yankHand(600)
        jointGuard.update()
        local x = instance.parts.lhand.body:getPosition()
        assert.is_near(yanked, x, 1)
    end)
end)
