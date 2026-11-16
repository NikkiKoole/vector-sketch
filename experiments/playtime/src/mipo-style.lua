-- mipo-style: what a rolled Mipo is made of: the hand-drawn parts, the clean ones drawn by code
-- (claudetools/clean-parts.py), or a mix of both (Nikki 2026-11-16: "when rolling a mipo you can say if you
-- want just the clean geometric shapes, or just the handdrawn or mix"). One setting on state, used by every
-- roll (src/mipo-randomize.lua randomizeAll and randomizePart). It swaps the catalog lists in for the roll
-- and puts them back after, like a breed does. A breed rolls drawn whatever the setting (the clean breed
-- names its own clean lists), src/mipo-breeds.lua.
local lib = {}

local state = require('src.state')
local C = require('src.shape-catalogs')

lib.STYLES = { 'drawn', 'clean', 'mix' }

function lib.get() return state.mipoStyle or 'drawn' end

function lib.set(style) state.mipoStyle = style end

function lib.step(delta)
    local at = 1
    for i, s in ipairs(lib.STYLES) do if s == lib.get() then at = i end end
    lib.set(lib.STYLES[(at - 1 + (delta or 1)) % #lib.STYLES + 1])
end

local function join(a, b)
    local out = {}
    for _, v in ipairs(a or {}) do out[#out + 1] = v end
    for _, v in ipairs(b or {}) do out[#out + 1] = v end
    return out
end

local function upTo(n) -- 1..n: the hand-drawn face parts' numbers
    local out = {}
    for i = 1, n or 0 do out[i] = i end
    return out
end

local function nones(n) -- n times '' (no hair)
    local out = {}
    for i = 1, n do out[i] = '' end
    return out
end

-- The catalog lists and face options a style rolls from; nil for 'drawn' (the catalogs as they are).
-- Read from C at the roll, not at load (a hot swap of shape-catalogs gives new tables).
local function overrides(style)
    if style == 'clean' then
        return {
            torsoHeadShapes = C.cleanBodyShapes, earShapes = C.cleanEarShapes,
            randomHandShapes = C.cleanFootShapes, randomFootShapes = C.cleanFootShapes,
            limbSkinTextures = C.cleanLimbSkinTextures, patternTextures = C.cleanPatternTextures,
            limbHairTextures = { '' }, haircutTextures = { '' }, bodyhairTextures = { '' },
        }, {
            allowedEyeShapes = C.cleanEyeNumbers, allowedPupilShapes = C.cleanPupilNumbers,
            allowedNoseShapes = C.cleanNoseNumbers, allowedBrowShapes = C.cleanBrowNumbers,
            allowedUpperLipShapes = C.cleanUpperLipNumbers, allowedLowerLipShapes = C.cleanLowerLipNumbers,
            allowedTeethShapes = C.cleanTeethNumbers,
        }
    elseif style == 'mix' then
        -- either kind for every part; hair half the time (the clean look has none)
        return {
            torsoHeadShapes = join(C.torsoHeadShapes, C.cleanBodyShapes),
            earShapes = join(C.earShapes, C.cleanEarShapes),
            randomHandShapes = join(C.randomHandShapes, C.cleanFootShapes),
            randomFootShapes = join(C.randomFootShapes, C.cleanFootShapes),
            limbSkinTextures = join(C.limbSkinTextures, C.cleanLimbSkinTextures),
            patternTextures = join(C.patternTextures, C.cleanPatternTextures),
            limbHairTextures = join(C.limbHairTextures, nones(#C.limbHairTextures)),
            haircutTextures = join(C.haircutTextures, nones(#C.haircutTextures)),
            bodyhairTextures = join(C.bodyhairTextures, nones(#C.bodyhairTextures)),
        }, {
            allowedEyeShapes = join(upTo(C.randomEyeCount), C.cleanEyeNumbers),
            allowedPupilShapes = join(upTo(C.randomPupilCount), C.cleanPupilNumbers),
            allowedNoseShapes = join(upTo(C.randomNoseCount), C.cleanNoseNumbers),
            allowedBrowShapes = join(upTo(C.randomBrowCount), C.cleanBrowNumbers),
            -- the drawn lips: the default 2 and 2 (dna-defaults), the clean ones beside them
            allowedUpperLipShapes = join({ 2 }, C.cleanUpperLipNumbers),
            allowedLowerLipShapes = join({ 2 }, C.cleanLowerLipNumbers),
            allowedTeethShapes = join(upTo(C.randomTeethCount), C.cleanTeethNumbers),
        }
    end
    return nil, nil
end

-- Busy while a roll runs with the style in: a breed puts the style in itself (under its own lists), and
-- the randomizer it calls then leaves it be.
local busy = false

-- Run fn(faceOpts) with the style's lists swapped into the catalogs, except the keys in `keep` (a breed's
-- own lists). faceOpts: the given ones over the style's. `style`: this one instead of the setting (a breed
-- rolls 'drawn': Nikki 2026-11-16, the clean parts only for the clean ones). Returns what fn returns; the
-- lists go back even when it fails.
function lib.with(faceOpts, fn, keep, style)
    if busy then return fn(faceOpts) end
    local lists, face = overrides(style or lib.get())
    lists = lists or {}
    local saved = {}
    for key, list in pairs(lists) do
        if not (keep and keep[key]) then
            saved[key] = C[key]
            C[key] = list
        end
    end
    local merged = {}
    for k, v in pairs(face or {}) do merged[k] = v end
    for k, v in pairs(faceOpts or {}) do merged[k] = v end
    busy = true
    local ok, a, b = pcall(fn, merged)
    busy = false
    for key, list in pairs(saved) do C[key] = list end
    if not ok then error(a, 0) end
    return a, b
end

return lib
