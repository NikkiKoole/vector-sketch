-- mipo-breeds.lua
-- Breeds: a random Mipo of a kind (docs/MIPO-BREEDS.md). A breed narrows what the randomizer
-- draws from for one Mipo: lists from src/shape-catalogs.lua and ranges from
-- src/dna-defaults.lua are swapped in for the draw and put back after, and its palette gives
-- every random colour of the draw; positioners and the body's build (creation) are set after
-- it. Anything a breed doesn't name stays as random as ever. scripts/spikes/breeds puts a
-- litter of each on a floor.
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

-- Shapes grouped by eye (scratch sheets of the masks, 2026-11-01), until the catalogs have tags (B1).
local ROUND_BODY = {
    'mipo/body/body-03', 'mipo/body/body-07', 'mipo/body/body-10', 'mipo/body/body-12', 'mipo/body/body-14',
    'mipo/body/body-16', 'mipo/body/body-17',
}
local SQUARE_BODY = {
    'mipo/body/body-04', 'mipo/body/body-05', 'mipo/body/body-08', 'mipo/body/body-09', 'mipo/body/body-13',
    'mipo/body/body-15',
}
local TALL_BODY = {
    'mipo/body/body-01', 'mipo/body/body-02', 'mipo/body/body-06', 'mipo/body/body-09', 'mipo/body/body-10',
    'mipo/body/body-14',
}
local POINTY_BODY = {
    'mipo/body/body-01', 'mipo/body/body-11', 'mipo/body/body-15', 'mipo/body/body-17',
}
local ROUND_EARS = {
    'mipo/ear/ear-01', 'mipo/ear/ear-02', 'mipo/ear/ear-08', 'mipo/ear/ear-09', 'mipo/ear/ear-10',
    'mipo/ear/ear-11', 'mipo/ear/ear-12', 'mipo/ear/ear-16',
}
local POINTY_EARS = {
    'mipo/ear/ear-03', 'mipo/ear/ear-04', 'mipo/ear/ear-05', 'mipo/ear/ear-06', 'mipo/ear/ear-07',
    'mipo/ear/ear-13', 'mipo/ear/ear-14', 'mipo/ear/ear-15',
}

-- The order for pickers (the breeds spike's keys, later the editor's, B5).
lib.order = { 'teddy', 'fat', 'tall', 'hairy', 'bad', 'geometric', 'bathhouse', 'rubberleg-pearbod' }

-- A breed's fields, all optional:
--   ranges     entries of D.randomRanges for the draw: { min, max }, or a number for a chance
--   lists      shape-catalogs lists for the draw ('' in a list: none, for limb hair)
--   palette    every random colour of the draw: hues = bands of degrees to pick one from,
--              sat and light = { lo, hi } in 0..1
--   face       randomizeFace's options (allowedEyeShapes, allowedPupilShapes, …)
--   creation   the body's build, set after the draw (neckSegments, isPotatoHead)
--   positioners, teethToMouth  set after the draw
--   constrained  roll as randomizeMipoConstrained (the Bathhouse Mipos)
-- teddy … bathhouse came from the breeds spike (2026-11-01), as it tried them.
lib.breeds = {
    teddy = {
        note = 'round, short thick limbs, small round ears, browns, no teeth',
        ranges = { legH = { min = 60, max = 200 }, armH = { min = 60, max = 220 }, earScale = { min = 0.5, max = 0.8 },
                   limbWMul = { min = 0.4, max = 0.5 }, teethChance = 0 },
        lists = { torsoHeadShapes = ROUND_BODY, earShapes = ROUND_EARS },
        palette = { hues = { { 18, 40 } }, sat = { 0.3, 0.6 }, light = { 0.3, 0.55 } },
        creation = { neckSegments = 0 },
    },
    fat = {
        note = 'big round bodies, thick short limbs, soft pastels',
        ranges = { bodyScale = { min = 1.7, max = 2.3 }, legH = { min = 60, max = 260 }, armH = { min = 60, max = 300 },
                   limbWMul = { min = 0.45, max = 0.6 } },
        lists = { torsoHeadShapes = ROUND_BODY },
        palette = { hues = { { 0, 360 } }, sat = { 0.3, 0.5 }, light = { 0.6, 0.78 } },
        creation = { neckSegments = 0 },
    },
    tall = {
        note = 'long neck, long thin legs, narrow bodies, cool colours',
        ranges = { bodyScale = { min = 1, max = 1.3 }, legH = { min = 500, max = 800 }, armH = { min = 400, max = 700 },
                   limbWMul = { min = 0.2, max = 0.28 } },
        lists = { torsoHeadShapes = TALL_BODY },
        palette = { hues = { { 170, 260 } }, sat = { 0.3, 0.6 }, light = { 0.4, 0.65 } },
        creation = { neckSegments = 3 },
    },
    hairy = {
        note = 'everything one warm colour family: skin and hair belong together',
        ranges = { haircutWidth = { min = 300, max = 400 } },
        palette = { hues = { { 25, 55 } }, sat = { 0.4, 0.7 }, light = { 0.25, 0.6 } },
    },
    bad = {
        note = 'pointy, angry brows, teeth, sour greens and purples',
        ranges = { browBend = { min = 8, max = 10 }, teethChance = 1, teethStickOut = 0.8 },
        lists = { torsoHeadShapes = POINTY_BODY, earShapes = POINTY_EARS },
        palette = { hues = { { 70, 130 }, { 265, 300 } }, sat = { 0.25, 0.5 }, light = { 0.2, 0.42 } },
    },
    geometric = {
        note = 'square bodies, no pattern, bright flat colours',
        lists = { torsoHeadShapes = SQUARE_BODY, patternTextures = { 'pat/type0' } },
        palette = { hues = { { 0, 10 }, { 45, 55 }, { 200, 220 } }, sat = { 0.75, 0.9 }, light = { 0.45, 0.55 } },
    },
    bathhouse = {
        note = "randomizeMipoConstrained, today's Bathhouse Mipos",
        constrained = true,
    },
    -- rope-like limbs instead of shaped ones (leg-01, leg-05); limb hair: none half the time ('' is
    -- no hair, three of them), else one of the last three; the widest leg stance; a pear body
    -- that is the head too (2026-11-01, Nikki in the vanilla scene)
    ['rubberleg-pearbod'] = {
        note = 'a pear body that is the head too, rope legs, big eyes set wide',
        lists = {
            limbSkinTextures = { 'mipo/leg/leg-01', 'mipo/leg/leg-05' },
            limbHairTextures = { '', '', '', 'mipo/hair/hair-09', 'mipo/hair/hair-10', 'mipo/hair/hair-11' },
            torsoHeadShapes = { 'mipo/body/body-11' },
            randomHandShapes = { 'mipo/hand/hand-01' }, -- real hands
            randomFootShapes = { 'mipo/foot/foot-05' }, -- the round foot with toes (the editor's feet grid: 5)
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

-- 'RRGGBBAA' from hue in degrees, saturation and lightness in 0..1.
function lib.hslHex(h, s, l)
    h = (h % 360) / 360
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    local function channel(t)
        t = t % 1
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format('%02X%02X%02X%02X', byte(channel(h + 1 / 3)), byte(channel(h)), byte(channel(h - 1 / 3)), 255)
end

local function between(range) return range[1] + math.random() * (range[2] - range[1]) end

-- A colour from a palette: one of its hue bands, then hue, saturation and lightness inside it.
function lib.paletteColor(palette)
    local band = palette.hues[math.random(#palette.hues)]
    return lib.hslHex(between(band), between(palette.sat), between(palette.light))
end

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
    if breed.palette then
        CharacterManager.setRandomColor(function() return lib.paletteColor(breed.palette) end)
    end
    -- face: randomizeFace's options (allowedEyeShapes, allowedPupilShapes, allowedNoseShapes, …)
    local roll = breed.constrained and CharacterManager.randomizeMipoConstrained or CharacterManager.randomizeMipo
    local ok, err = pcall(roll, instance, nil, breed.face)
    CharacterManager.setRandomColor(nil)
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
