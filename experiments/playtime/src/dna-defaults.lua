-- dna-defaults.lua
-- Single source of truth for DNA default values (face sub-structures, positioners,
-- creation params, and random ranges for character randomization).
--
-- Naming note: `wmul` (lowercase) = connected-texture rendered width multiplier.
-- `wMul` (camelCase) = face-part size multiplier (eyes, brows, nose, mouth, etc.).
-- This distinction is intentional — do not rename, as it would break saved scenes.

local lib = {}

-- Deep-copy a table (simple, no cyclic ref handling needed for defaults)
local function deepCopySimple(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopySimple(v)
    end
    return copy
end

--- Fill missing keys in target from defaults, recursing into sub-tables.
--- Checks `== nil` (not truthiness) so `false` values are preserved.
--- Deep-copies default tables when inserting to prevent mutation leakage.
function lib.ensureDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = deepCopySimple(v)
        elseif type(v) == 'table' and type(target[k]) == 'table' then
            lib.ensureDefaults(target[k], v)
        end
    end
    return target
end

-- Individual face sub-structure defaults
lib.eye = {
    shape = 1, bgHex = '000000ff', fgHex = 'ffffffff',
    wMul = 1, hMul = 1, lookAtMouse = false,
}

lib.pupil = {
    shape = 1, bgHex = '000000ff', fgHex = '',
    wMul = 0.5, hMul = 0.5,
}

lib.brow = {
    shape = 1, bgHex = '000000ff',
    wMul = 1, hMul = 1, bend = 1,
}

lib.nose = {
    shape = 0, bgHex = '000000ff', fgHex = 'ffffffff',
    wMul = 1, hMul = 1,
}

lib.teeth = {
    shape = 0, bgHex = 'ffffffff', fgHex = 'eeeeeeff',
    hMul = 1, stickOut = false,
}

lib.mouth = {
    shape = 2, upperLipShape = 1, lowerLipShape = 1,
    lipHex = 'cc5555ff', backdropHex = '00000033',
    lipScale = 0.25, wMul = 1, hMul = 1,
}

lib.facePositioners = {
    eye = { x = 0.2, y = 0.5, r = 0 },
    brow = { y = 0.3 },
    nose = { y = 0.35 },
    mouth = { y = 0.7 },
}

-- Combined face default (all sub-structures)
lib.face = {
    eye = deepCopySimple(lib.eye),
    pupil = deepCopySimple(lib.pupil),
    brow = deepCopySimple(lib.brow),
    nose = deepCopySimple(lib.nose),
    teeth = deepCopySimple(lib.teeth),
    mouth = deepCopySimple(lib.mouth),
    positioners = deepCopySimple(lib.facePositioners),
}

-- Top-level positioners (leg, ear, nose placement on body)
lib.positioners = {
    leg = { x = 0.5 },
    ear = { y = 0.5 },
    nose = { t = 0.35 },
}

-- Creation params (body topology)
lib.creation = {
    isPotatoHead = false,
    torsoSegments = 1,
    neckSegments = 0,
    noseSegments = 0,
}

-- Face magnitude (overall face-part scale factor)
lib.faceMagnitude = 1

-- ─── Random ranges for character randomization ───

lib.randomRanges = {
    bodyScale     = { min = 1, max = 2 },
    earScale      = { min = 0.5, max = 2 },
    feetScale     = { min = 1, max = 2 },
    handScale     = { min = 1, max = 2 },
    haircutWidth  = { min = 100, max = 400 },
    eyeY          = { min = 0.3, max = 0.6 },
    eyeX          = { min = 0.1, max = 0.4 },
    eyeWMul       = { min = 0.5, max = 1.5 },
    eyeHMul       = { min = 0.5, max = 1.5 },
    pupilWMul     = { min = 0.2, max = 0.8 },
    pupilHMul     = { min = 0.2, max = 0.8 },
    mouthYOffset  = { min = 0.15, max = 0.35 },
    mouthLipScale = { min = 0.1, max = 0.4 },
    mouthWMul     = { min = 0.5, max = 1.5 },
    mouthHMul     = { min = 0.5, max = 1.5 },
    browWMul      = { min = 0.8, max = 1.3 },
    browHMul      = { min = 0.6, max = 1.4 },
    browBend      = { min = 1, max = 10 },
    browY         = { min = 0.25, max = 0.35 },
    noseWMul      = { min = 0.5, max = 2.5 },
    noseHMul      = { min = 0.5, max = 2.5 },
    noseY         = { min = 0.3, max = 0.5 },
    teethHMul     = { min = 0.5, max = 2.5 },
    teethChance   = 0.3,
    teethStickOut = 0.2,
}

function lib.randomInRange(key)
    local r = lib.randomRanges[key]
    return r.min + math.random() * (r.max - r.min)
end

function lib.randomIntInRange(key)
    local r = lib.randomRanges[key]
    return math.ceil(r.min + math.random() * (r.max - r.min))
end

-- ─── Schemas for validation ───

lib.faceSchema = {
    eye = { shape = 'number', bgHex = 'string', fgHex = 'string',
            wMul = 'number', hMul = 'number', lookAtMouse = 'boolean' },
    pupil = { shape = 'number', bgHex = 'string', fgHex = 'string',
              wMul = 'number', hMul = 'number' },
    brow = { shape = 'number', bgHex = 'string',
             wMul = 'number', hMul = 'number', bend = 'number' },
    nose = { shape = 'number', bgHex = 'string', fgHex = 'string',
             wMul = 'number', hMul = 'number' },
    teeth = { shape = 'number', bgHex = 'string', fgHex = 'string',
              hMul = 'number', stickOut = 'boolean' },
    mouth = { shape = 'number', upperLipShape = 'number', lowerLipShape = 'number',
              lipHex = 'string', backdropHex = 'string',
              lipScale = 'number', wMul = 'number', hMul = 'number' },
    positioners = {
        eye = { x = 'number', y = 'number', r = 'number' },
        brow = { y = 'number' },
        nose = { y = 'number' },
        mouth = { y = 'number' },
    },
}

lib.positionersSchema = {
    leg = { x = 'number' },
    ear = { y = 'number' },
    nose = { t = 'number' },
}

lib.creationSchema = {
    isPotatoHead = 'boolean',
    torsoSegments = 'number',
    neckSegments = 'number',
    noseSegments = 'number',
}

--- Recursively validate target against schema.
--- Returns a list of issues (empty = valid).
function lib.validate(target, schema, prefix)
    local issues = {}
    for k, expected in pairs(schema) do
        local path = prefix and (prefix .. '.' .. k) or k
        local val = target[k]
        if type(expected) == 'table' then
            -- Sub-table expected
            if val == nil then
                issues[#issues + 1] = { path = path, issue = 'missing' }
            elseif type(val) ~= 'table' then
                issues[#issues + 1] = { path = path, issue = 'expected table, got ' .. type(val) }
            else
                local sub = lib.validate(val, expected, path)
                for i = 1, #sub do issues[#issues + 1] = sub[i] end
            end
        else
            -- Leaf: expected is a type name string
            if val == nil then
                issues[#issues + 1] = { path = path, issue = 'missing' }
            elseif type(val) ~= expected then
                issues[#issues + 1] = { path = path, issue = 'expected ' .. expected .. ', got ' .. type(val) }
            end
        end
    end
    return issues
end

function lib.validateFace(face)
    return lib.validate(face, lib.faceSchema, 'face')
end

function lib.validatePositioners(pos)
    return lib.validate(pos, lib.positionersSchema, 'positioners')
end

function lib.validateCreation(creation)
    return lib.validate(creation, lib.creationSchema, 'creation')
end

return lib
