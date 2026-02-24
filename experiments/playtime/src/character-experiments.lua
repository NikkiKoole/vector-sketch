-- Character experiment keybindings
-- Extracted from main.lua — randomization experiments for character parts
-- Keys: c, q, w, e, r, t, y, u, i (require humanoidInstance to be present)

local lib = {}

local utils = require 'src.utils'
local randomHexColor = utils.randomHexColor
local CharacterManager = require('src.character-manager')

function lib.handleKeyPress(key, humanoidInstance)
    if not humanoidInstance then return end

    if key == 'c' then
        local mydna = (humanoidInstance.dna)
        CharacterManager.createCharacterFromJustDNA(mydna, 200, 200, humanoidInstance.scale)
    end

    if key == 'q' then
        -- recolor everything
        local parts = humanoidInstance.dna.creation.torsoSegments
        for i = 1, parts do
            local bgHex = '000000ff'
            local fgHex = randomHexColor()
            local pHex = randomHexColor()
            CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
            CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch1')
            CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch2')
        end
        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 'w' then
        CharacterManager.rebuildFromCreation(humanoidInstance, {})
        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 'e' then
        local bgHex = '000000ff'
        local fgHex = randomHexColor()
        local pHex = randomHexColor()
        CharacterManager.updateSkinOfPart(humanoidInstance, 'lear',
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
        CharacterManager.updateSkinOfPart(humanoidInstance, 'rear',
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex })

        local urls = { 'earx1r', 'earx2r', 'earx3r', 'earx4r', 'earx5r', 'earx6r', 'earx7r', 'earx8r', 'earx9r',
            'earx10r', 'earx11r', 'earx12r', 'earx13r', 'earx14r', 'earx15r', 'earx16r' }
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]
        print(url)
        local s = 1 + math.random() * 1
        local sy = love.math.random()
        CharacterManager.updatePart('lear',
            { shape8URL = url .. '.png', sy = s, sx = -s * sy },
            humanoidInstance)
        CharacterManager.updatePart('rear',
            { shape8URL = url .. '.png', sy = s, sx = s * sy },
            humanoidInstance)
        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 'r' then
        local urls = { 'hand3r', 'feet8r', 'feet2r', 'feet6r', 'feet5xr', 'feet3xr', 'feet7r',
            'feet7xr' }
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]
        local s = 1 + math.random() * 1

        CharacterManager.updatePart('lfoot',
            { shape8URL = url .. '.png', sy = s, sx = s },
            humanoidInstance)
        CharacterManager.updatePart('rfoot',
            { shape8URL = url .. '.png', sy = s, sx = -s },
            humanoidInstance)

        local s = 1 + math.random() * 1
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]
        CharacterManager.updatePart('lhand',
            { shape8URL = url .. '.png', sy = s, sx = s },
            humanoidInstance)
        CharacterManager.updatePart('rhand',
            { shape8URL = url .. '.png', sy = s, sx = -s },
            humanoidInstance)

        CharacterManager.rebuildFromCreation(humanoidInstance, {})
        print(url)
        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 't' then
        local bgHex = randomHexColor()
        local fgHex = randomHexColor()
        local pHex = randomHexColor()

        local urls = { 'borsthaar1', 'borsthaar2', 'borsthaar3', 'borsthaar4', 'borsthaar5', 'borsthaar6',
            'borsthaar7' }
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]

        local creation = humanoidInstance.dna.creation
        local count = creation.torsoSegments
        print(url)
        for i = 1, count do
            CharacterManager.updateBodyhairOfPart(humanoidInstance, 'torso' .. i,
                { bgURL = url .. '.png', fgURL = url .. '-mask.png', bgHex = bgHex, fgHex = fgHex, pHex = pHex })
        end
        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 'y' then
        local urls = { 'shapeA3', 'shapeA2', 'shapeA1', 'shapeA4', 'shapes1', 'shapes2', 'shapes3', 'shapes4',
            'shapes5', 'shapes6', 'shapes7', 'shapes8', 'shapes9', 'shapes10', 'shapes11', 'shapes12', 'shapes13' }
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]
        local creation = humanoidInstance.dna.creation
        local count = creation.torsoSegments
        local s = 1 + math.random() * 1

        for i = 1, count do
            CharacterManager.updatePart('torso' .. i,
                { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
                humanoidInstance)
        end

        local s = 1 + math.random() * 1
        local urlIndex = math.ceil(math.random() * #urls)
        local url = urls[urlIndex]
        CharacterManager.updatePart('head',
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            humanoidInstance)

        CharacterManager.rebuildFromCreation(humanoidInstance,
            { torsoSegments = count, isPotatoHead = not creation.isPotatoHead })

        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end

    if key == 'u' then
        local lowerleglength = 20 + love.math.random() * 1400
        CharacterManager.updatePart('luleg', { h = lowerleglength }, humanoidInstance)
        CharacterManager.updatePart('ruleg', { h = lowerleglength }, humanoidInstance)
        CharacterManager.updatePart('llleg', { h = lowerleglength }, humanoidInstance)
        CharacterManager.updatePart('rlleg', { h = lowerleglength }, humanoidInstance)

        local lowerarmlength = 120 + love.math.random() * 1400
        CharacterManager.updatePart('luarm', { h = lowerarmlength }, humanoidInstance)
        CharacterManager.updatePart('ruarm', { h = lowerarmlength }, humanoidInstance)
        CharacterManager.updatePart('llarm', { h = lowerarmlength }, humanoidInstance)
        CharacterManager.updatePart('rlarm', { h = lowerarmlength }, humanoidInstance)

        CharacterManager.addTexturesFromInstance2(humanoidInstance)

        local count = math.floor(math.random() * 5)
        CharacterManager.rebuildFromCreation(humanoidInstance,
            { noseSegments = count })
    end

    if key == 'i' then
        local segments = 1

        local url = humanoidInstance.dna.parts['torso1'].shape8URL

        CharacterManager.rebuildFromCreation(humanoidInstance,
            { torsoSegments = segments })

        for i = 1, segments do
            CharacterManager.updatePart('torso' .. i,
                { shape8URL = url },
                humanoidInstance)
        end

        CharacterManager.addTexturesFromInstance2(humanoidInstance)
    end
end

return lib
