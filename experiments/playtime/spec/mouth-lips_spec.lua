-- spec/mouth-lips_spec.lua
-- A lip ribbon is placed so its picture's mouth-opening edge lies on the mouth hole's edge
-- (box2d-draw-textured lipEdgeU): measured per lip picture, nearest the opening side.
-- (Was: the ribbon's middle on the edge plus a fixed 8 px, so every lip sat differently.)
-- Run with: love . --specs spec/mouth-lips_spec.lua

if not love then return end

local draw = require('src.physics.box2d-draw-textured')

describe('lip edges', function()
    it('every lip picture has its opening edge measured inside the picture', function()
        for i = 1, 4 do
            for _, side in ipairs({ 'upper', 'lower' }) do
                local u = draw.lipEdgeU(side .. 'lip' .. i .. '.png', side)
                assert.is_true(u > 0.2 and u < 0.8, side .. 'lip' .. i .. ': ' .. u)
            end
        end
    end)

    it("measures the stroke nearest the opening side: right for an upper lip, left for a lower", function()
        -- a test picture: a stroke at x 2..3 and one at x 12..13 of 16
        local data = love.image.newImageData(16, 10)
        for y = 0, 9 do
            for _, x in ipairs({ 2, 3, 12, 13 }) do data:setPixel(x, y, 1, 1, 1, 1) end
        end
        love.filesystem.write('lip-edge-test.png', data:encode('png'))
        local realNew = love.image.newImageData
        love.image.newImageData = function(path)
            if path == 'textures/lip-edge-test.png' then return realNew('lip-edge-test.png') end
            return realNew(path)
        end
        local upper, lower = draw.lipEdgeU('lip-edge-test.png', 'upper'), draw.lipEdgeU('lip-edge-test.png', 'lower')
        love.image.newImageData = realNew
        love.filesystem.remove('lip-edge-test.png')
        assert.is_near((12.5 + 0.5) / 16, upper, 1e-6)
        assert.is_near((2.5 + 0.5) / 16, lower, 1e-6)
    end)

    describe('the duck beak upper lip (upperlip4) is out', function()
        local state = require('src.state')
        local registry = require('src.registry')
        local mipoRegistry = require('src.mipo-registry')
        local CM = require('src.character-manager')
        local world

        before_each(function()
            world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
            state.physicsWorld = world
            registry.reset()
            mipoRegistry.reset()
        end)
        after_each(function()
            if not world:isDestroyed() then world:destroy() end
        end)

        it('random Mipos never get it', function()
            for seed = 1, 30 do
                love.math.setRandomSeed(seed)
                math.randomseed(seed)
                local instance = CM.createCharacter('humanoid', seed * 2000, 0, 0.3)
                CM.randomizeMipoConstrained(instance)
                for _, part in pairs(instance.dna.parts) do
                    local face = part.appearance and part.appearance.face
                    if face and face.mouth then assert.is_true(face.mouth.upperLipShape <= 3) end
                end
            end
        end)

        it('saved Mipos that had it get upperlip1 when they load', function()
            require('src.scene-loader').loadScriptAndScene('crowd')
            world = state.physicsWorld
            local lips = 0
            for _, instance in pairs(mipoRegistry.getAll()) do
                for _, part in pairs(instance.parts) do
                    for _, f in ipairs(part.body:getFixtures()) do
                        local ud = f:getUserData()
                        if ud and ud.label == 'upperlip' then
                            lips = lips + 1
                            assert.are_not.equal('upperlip4.png', ud.extra.main.bgURL)
                        end
                    end
                end
                for _, part in pairs(instance.dna.parts) do
                    local face = part.appearance and part.appearance.face
                    if face and face.mouth then assert.are_not.equal(4, face.mouth.upperLipShape) end
                end
            end
            assert.is_true(lips > 0, 'no upper lips in the crowd')
        end)
    end)
end)
