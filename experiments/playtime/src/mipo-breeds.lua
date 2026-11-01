-- mipo-breeds.lua
-- Breeds: a random Mipo of a kind (docs/MIPO-BREEDS.md). A breed narrows what the randomizer
-- draws from for one Mipo: lists from src/shape-catalogs.lua and ranges from
-- src/dna-defaults.lua are swapped in for the draw and put back after; positioners are set
-- after it. Anything a breed doesn't name stays as random as ever. scripts/breeds tries more
-- breeds the same way.
--
-- Also undo for the Mipo editor's random buttons: the DNA from before each roll, a few steps
-- back, on state (a hot reload keeps it).
local lib = {}

local C = require('src.shape-catalogs')
local D = require('src.dna-defaults')
local utils = require('src.utils')
local state = require('src.state')
local CharacterManager = require('src.character-manager')
local mouthShapes = require('src.mouth-shapes')

lib.breeds = {
    -- rope-like limbs instead of shaped ones (leg1, leg5); limb hair: none half the time ('' is
    -- no hair, three of them), else one of the last three; the widest leg stance; a pear body
    -- that is the head too (2026-11-01, Nikki in the vanilla scene)
    ['rubberleg-pearbod'] = {
        lists = {
            limbSkinTextures = { 'leg1', 'leg5' },
            limbHairTextures = { '', '', '', 'hair9', 'hair10', 'hair11' },
            torsoHeadShapes = { 'shapes7' },
            randomHandShapes = { 'hand3r' }, -- real hands
            randomFootShapes = { 'feet7r' }, -- the round foot with toes (the editor's feet grid: 5)
        },
        -- the pear the right way up (wide at the bottom), sizes around Nikki's 1.48; hands about
        -- half the size (any Mipo: 1-2)
        ranges = { bodyFlipChance = 0, bodyScale = { min = 1.35, max = 1.6 }, handScale = { min = 0.5, max = 1 },
                   eyeWMul = { min = 1.1, max = 1.5 }, -- big eyes (any Mipo: 0.5-1.5)
                   eyeX = { min = 0.24, max = 0.36 } }, -- set wide apart (any Mipo: 0.1-0.4)
        positioners = { legX = 0 },
        -- eye white 1, pupil 2 or 3; noses 7 (the snout), 8, 9, 12; round eyes (and pupils): the same
        -- width and height scale
        face = { allowedEyeShapes = { 1 }, allowedPupilShapes = { 2, 3 }, allowedNoseShapes = { 7, 8, 9, 12 },
                 uniformEyeScale = true },
        creation = { isPotatoHead = true }, -- the body is the head
        teethToMouth = { 1, 1.25 }, -- the set of teeth as wide as the mouth, or a little wider
    },
}

-- Randomize the whole Mipo as one of breed `name`.
function lib.randomize(instance, name)
    local breed = lib.breeds[name]
    if not (instance and breed) then return end
    local savedRanges, savedLists = {}, {}
    for key, r in pairs(breed.ranges or {}) do
        savedRanges[key] = D.randomRanges[key]
        D.randomRanges[key] = r
    end
    for key, list in pairs(breed.lists or {}) do
        savedLists[key] = C[key]
        C[key] = list
    end
    -- face: randomizeFace's options (allowedEyeShapes, allowedPupilShapes, allowedNoseShapes, …)
    local ok, err = pcall(CharacterManager.randomizeMipo, instance, nil, breed.face)
    for key, r in pairs(savedRanges) do D.randomRanges[key] = r end
    for key, list in pairs(savedLists) do C[key] = list end
    if not ok then error(err) end
    -- positioners (where the legs, ears and nose sit; mipo-appearance updatePositioners) are
    -- not drawn at random, and the randomizer flips potato head every roll: a breed sets both
    -- after it, in one rebuild
    if breed.teethToMouth then
        local potato = instance.dna.creation.isPotatoHead
        if breed.creation and breed.creation.isPotatoHead ~= nil then potato = breed.creation.isPotatoHead end
        lib.fitTeeth(instance, breed.teethToMouth, potato and 'torso1' or 'head')
    end
    if breed.positioners or breed.creation or breed.teethToMouth then
        if breed.positioners then CharacterManager.updatePositioners(instance, breed.positioners) end
        CharacterManager.rebuildFromCreation(instance, breed.creation or {})
        CharacterManager.limitArmReach(instance)
        CharacterManager.rebuildTextures(instance)
    end
end

-- Teeth as wide as the rolled mouth times a share from `range` ({ min, max }): drawn, a set of
-- teeth is 100 x its width setting and the mouth its shape's width (mouth-shapes normalized,
-- 66-247), both times the same scale (mipo-textures placeMouth). Set once, at the roll.
-- owner: the part with the face (torso1 on a potato head, else head).
function lib.fitTeeth(instance, range, owner)
    local face = instance.dna.parts[owner] and instance.dna.parts[owner].appearance.face
    local shape = face and mouthShapes.normalized[face.mouth.shape]
    if not shape then return end
    local minX, maxX = math.huge, -math.huge
    for i = 1, #shape.points, 2 do
        minX, maxX = math.min(minX, shape.points[i]), math.max(maxX, shape.points[i])
    end
    local share = range[1] + math.random() * (range[2] - range[1])
    face.teeth.wMul = (maxX - minX) / 100 * share
end

-- ─── Undo ───

lib.undoSteps = 20
state.mipoUndo = state.mipoUndo or {}

-- Before a roll: keep the DNA as it is now.
function lib.remember(instance)
    if not instance then return end
    local history = state.mipoUndo[instance.id] or {}
    history[#history + 1] = utils.deepCopy(instance.dna)
    if #history > lib.undoSteps then table.remove(history, 1) end
    state.mipoUndo[instance.id] = history
end

function lib.canUndo(instance)
    local history = instance and state.mipoUndo[instance.id]
    return history ~= nil and #history > 0
end

-- The Mipo as it was before the last roll, rebuilt in place (same Mipo, same selection).
function lib.undo(instance)
    if not lib.canUndo(instance) then return end
    instance.dna = table.remove(state.mipoUndo[instance.id])
    CharacterManager.rebuildFromCreation(instance, {})
    CharacterManager.rebuildTextures(instance)
end

return lib
