-- spec/mipo-texture-group_spec.lua
-- A Mipo's fixtures all share its negative group index, so its parts never collide or sense each
-- other. Redrawing its textures (a colour picked in the Mipo editor, a breed, randomize) makes the
-- texture sensors anew: they have to land in that group too. They used to start in group 0 (25 of
-- them on a humanoid) and only a rebuild or a scene load put them back.
-- Run with: love . --specs spec/mipo-texture-group_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')

describe('a Mipo redrawing its textures', function()
    local world

    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        math.randomseed(3); love.math.setRandomSeed(3)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    -- the fixtures not in the Mipo's group, as 'part #n subtype' lines
    local function outOfGroup(instance)
        local out = {}
        for name, part in pairs(instance.parts) do
            for i, fixture in ipairs(part.body:getFixtures()) do
                if fixture:getGroupIndex() ~= instance.groupIndex then
                    local ud = fixture:getUserData()
                    out[#out + 1] = name .. ' #' .. i .. ' ' .. tostring(ud and ud.subtype)
                end
            end
        end
        table.sort(out)
        return out
    end

    it('starts with every fixture in its group', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        assert.is_true(instance.groupIndex < 0)
        assert.are.same({}, outOfGroup(instance))
    end)

    it('keeps every fixture in its group after its textures are redrawn', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        CM.rebuildTextures(instance)
        assert.are.same({}, outOfGroup(instance))
    end)

    it('keeps them in its group after a rebuild and a redraw, as the editor panels do', function()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        CM.rebuildFromCreation(instance, {})
        CM.rebuildTextures(instance)
        assert.are.same({}, outOfGroup(instance))
    end)
end)
