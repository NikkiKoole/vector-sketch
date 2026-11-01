-- mipo-breeds.lua
-- Breeds: a random Mipo of a kind (docs/MIPO-BREEDS.md). A breed narrows what the randomizer
-- draws from for one Mipo: lists from src/shape-catalogs.lua and ranges from
-- src/dna-defaults.lua are swapped in for the draw and put back after. Anything a breed doesn't
-- name stays as random as ever. scripts/breeds tries more breeds the same way.
--
-- Also undo for the Mipo editor's random buttons: the DNA from before each roll, a few steps
-- back, on state (a hot reload keeps it).
local lib = {}

local C = require('src.shape-catalogs')
local D = require('src.dna-defaults')
local utils = require('src.utils')
local state = require('src.state')
local CharacterManager = require('src.character-manager')

lib.breeds = {
    -- rope-like limbs instead of shaped ones (leg1, leg5); limb hair: none half the time ('' is
    -- no hair, three of them), else one of the last three (2026-11-01, Nikki in the vanilla scene)
    rubberleg = {
        lists = {
            limbSkinTextures = { 'leg1', 'leg5' },
            limbHairTextures = { '', '', '', 'hair9', 'hair10', 'hair11' },
        },
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
    local ok, err = pcall(CharacterManager.randomizeMipo, instance)
    for key, r in pairs(savedRanges) do D.randomRanges[key] = r end
    for key, list in pairs(savedLists) do C[key] = list end
    if not ok then error(err) end
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
