-- spec/mipo-breeds_spec.lua
-- Breeds (src/mipo-breeds.lua): every breed rolls, its lists and build show in the DNA, its
-- palette's colours stay in their bands, and what it swaps in for the draw is put back after.
--
-- Run with: love . --specs spec/mipo-breeds_spec.lua

if not love then return end

local breeds = require('src.mipo-breeds')
local CharacterManager = require('src.character-manager')
local randomize = require('src.mipo-randomize')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local state = require('src.state')
local C = require('src.shape-catalogs')
local D = require('src.dna-defaults')

-- hue (degrees), saturation, lightness of 'RRGGBB..'
local function hexHsl(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local maxc, minc = math.max(r, g, b), math.min(r, g, b)
    local l = (maxc + minc) / 2
    if maxc == minc then return 0, 0, l end
    local d = maxc - minc
    local s = l > 0.5 and d / (2 - maxc - minc) or d / (maxc + minc)
    local h
    if maxc == r then h = (g - b) / d % 6 elseif maxc == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    return h * 60, s, l
end

describe("mipo-breeds colours", function()
    it("hslHex gives the plain colours", function()
        assert.are.equal('FF0000FF', breeds.hslHex(0, 1, 0.5))
        assert.are.equal('00FF00FF', breeds.hslHex(120, 1, 0.5))
        assert.are.equal('0000FFFF', breeds.hslHex(240, 1, 0.5))
        assert.are.equal('808080FF', breeds.hslHex(77, 0, 0.5))
        assert.are.equal('FF0000FF', breeds.hslHex(360, 1, 0.5))
    end)

    it("every breed's palette colours stay in its bands", function()
        math.randomseed(3)
        for _, name in ipairs(breeds.order) do
            local palette = breeds.breeds[name].palette
            if palette then
                for _ = 1, 200 do
                    local h, s, l = hexHsl(breeds.paletteColor(palette))
                    local inBand = false
                    for _, band in ipairs(palette.hues) do
                        -- a byte per channel: a degree or two off at the edges
                        if (h - band[1] + 2) % 360 <= (band[2] - band[1]) + 4 or band[2] - band[1] >= 360 then inBand = true end
                    end
                    assert.is_true(inBand, string.format('%s: hue %.1f outside its bands', name, h))
                    assert.is_true(l >= palette.light[1] - 0.01 and l <= palette.light[2] + 0.01,
                        string.format('%s: lightness %.3f', name, l))
                    if l > 0.02 and l < 0.98 then
                        assert.is_true(s >= palette.sat[1] - 0.02 and s <= palette.sat[2] + 0.02,
                            string.format('%s: saturation %.3f', name, s))
                    end
                end
            end
        end
    end)
end)

describe("a Mipo of each breed", function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
        registry.reset()
        mipoRegistry.reset()
        state.physicsWorld = world
    end)

    after_each(function()
        for _, b in ipairs(world:getBodies()) do
            if not b:isDestroyed() then b:destroy() end
        end
        world:destroy()
    end)

    it("every breed in the order exists, and every breed is in the order", function()
        local inOrder = {}
        for _, name in ipairs(breeds.order) do
            assert.is_table(breeds.breeds[name], name)
            inOrder[name] = true
        end
        for name in pairs(breeds.breeds) do assert.is_true(inOrder[name], name .. ' not in lib.order') end
    end)

    for i, name in ipairs(breeds.order) do
        it(name .. ": rolls, and puts back what it swapped in", function()
            local rangesBefore, listsBefore = {}, {}
            for k, v in pairs(D.randomRanges) do rangesBefore[k] = v end
            for k, v in pairs(C) do listsBefore[k] = v end

            math.randomseed(i); love.math.setRandomSeed(i)
            local mipo = CharacterManager.createCharacter('humanoid', 0, 0, 1)
            breeds.randomize(mipo, name)

            for k, v in pairs(rangesBefore) do assert.are.equal(v, D.randomRanges[k], name .. ' left range ' .. k) end
            for k, v in pairs(listsBefore) do assert.are.equal(v, C[k], name .. ' left list ' .. k) end
            assert.are.equal(randomize.anyColor, randomize.randomColor, name .. ' left its palette on')

            local breed = breeds.breeds[name]
            local torsoList = breed.lists and breed.lists.torsoHeadShapes
            if torsoList then
                local url = mipo.dna.parts.torso1.shape8URL
                local found = false
                for _, u in ipairs(torsoList) do found = found or (u .. '.png' == url) end
                assert.is_true(found, name .. ': torso ' .. tostring(url) .. ' not from its list')
            end
            for key, v in pairs(breed.creation or {}) do
                assert.are.equal(v, mipo.dna.creation[key], name .. ': creation.' .. key)
            end
        end)
    end

    -- lips 2 and 2, and the widest resting mouth inside the head (2026-11-09)
    it("every roll: lips 2 and 2, the mouth no wider than the head", function()
        local mouthShapes = require('src.mouth-shapes')
        local textures = require('src.mipo-textures')
        local widest = 0
        for _, n in ipairs(mouthShapes.restShapes) do
            local s = mouthShapes.normalized[mouthShapes.indexOf(n)]
            local a, b = math.huge, -math.huge
            for k = 1, #s.points, 2 do a, b = math.min(a, s.points[k]), math.max(b, s.points[k]) end
            widest = math.max(widest, b - a)
        end
        local names = { 'any' }
        for _, n in ipairs(breeds.order) do names[#names + 1] = n end
        for seed = 1, 4 do
            for _, name in ipairs(names) do
                math.randomseed(seed); love.math.setRandomSeed(seed)
                local mipo = CharacterManager.createCharacter('humanoid', 0, 0, 1)
                if name == 'any' then CharacterManager.randomizeMipo(mipo) else breeds.randomize(mipo, name) end
                local owner = mipo.dna.creation.isPotatoHead and 'torso1' or 'head'
                local mouth = mipo.dna.parts[owner].appearance.face.mouth
                assert.are.equal(2, mouth.upperLipShape, name)
                assert.are.equal(2, mouth.lowerLipShape, name)
                local share = widest * textures.MOUTH_UNIT * mouth.wMul * (mipo.dna.faceMagnitude or 1)
                assert.is_true(share <= randomize.mouthMaxHeadShare + 1e-9,
                    string.format('%s seed %d: mouth %.2f of the head wide', name, seed, share))
                assert.is_true(mouth.hMul <= 0.8 + 1e-9, name .. ': mouth hMul ' .. mouth.hMul)
            end
        end
    end)
end)
