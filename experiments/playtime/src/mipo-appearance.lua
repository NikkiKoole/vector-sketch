-- src/mipo-appearance.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local utils = require('src.utils')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local D = require('src.dna-defaults')

local randomHexColor = utils.randomHexColor

local function createDefaultTextureDNABlock(shape, skipFG)

    local result = {
        bgURL = shape .. '.png',
        fgURL = skipFG and '' or shape .. '-mask.png',
        pURL = 'type2t.png',
        bgHex = '020202ff',
        fgHex = skipFG and '' or 'ff0000ff',
        pHex = 'ffff00ff',

    }

    box2dDrawTextured.makeCached(result)

    return result
end

local function initBlock(url)
    local result = {
        bgURL = (url or '') .. '.png',
        fgURL = (url or '') .. '-mask.png',
        pURL = 'type2t.png',
        bgHex = '020202ff',
        fgHex = randomHexColor(),
        pHex = randomHexColor(),

    }
    box2dDrawTextured.makeCached(result)

    return result
end

local function add(block, values)
    for k, v in pairs(values) do
        block[k] = v
    end
    return block
end

-- Update skin appearance on a body part's OMP texture layer.
-- values: {bgHex, fgHex, pHex, bgURL, fgURL, [pattern params like pOpacity]}
-- optionalPatchName: 'main', 'patch1', 'patch2', etc. (defaults to 'main')
function lib.updateSkinOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['skin'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['skin'][patch] then
                for k, v in pairs(values) do
                    p.appearance['skin'][patch][k] = v
                end
                -- Clear cached RGB so makeCached() recalculates from the new hex values.
                -- Without this, deepCopy in rebuildTextures copies stale cached
                -- values and makeCached skips recalculation (it only runs when cached is nil).
                p.appearance['skin'][patch].cached = nil
            end
        end
    end
end

-- Update bodyhair appearance on a body part's texture layer.
-- values: {bgHex, fgHex, pHex, bgURL, fgURL}
-- optionalPatchName: defaults to 'main'
-- Hairy feet: body hair on both feet, as on the torso (drawn along the foot's outline,
-- mipo-textures addBodyhairTexture), or none. Turned on, the feet start with the body's own
-- body hair (the torso's, else the head's) so it matches; a random roll keeps them in step.
-- Rebuild the textures after.
function lib.setFeetBodyhair(instance, on)
    local source
    for _, name in ipairs({ 'torso1', 'head' }) do
        local part = instance.dna.parts[name]
        source = source or (part and part.appearance and part.appearance.bodyhair)
    end
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local part = instance.dna.parts[foot]
        if part then
            part.appearance = part.appearance or {}
            local chest = source or { main = lib.initBlock('mipo/chesthair/chesthair-04') }
            part.appearance.bodyhair = on and utils.deepCopy(chest) or nil
        end
    end
end

function lib.hasFeetBodyhair(instance)
    local foot = instance.dna.parts.lfoot
    return foot ~= nil and foot.appearance ~= nil and foot.appearance.bodyhair ~= nil
end

function lib.updateBodyhairOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['bodyhair'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['bodyhair'][patch] then
                for k, v in pairs(values) do
                    p.appearance['bodyhair'][patch][k] = v
                end
                -- Clear cached RGB (same reason as updateSkinOfPart above)
                p.appearance['bodyhair'][patch].cached = nil
            end
        end
    end
end

-- Update haircut appearance. Color keys (bgURL, fgURL, bgHex, fgHex, pHex, pURL)
-- go into haircut.main; other keys (startIndex, endIndex) go on the haircut table itself.
function lib.updateHaircutOfPart(instance, partName, values)
    local p = instance.dna.parts[partName]
    if p and p.appearance and p.appearance['haircut'] then
        local hc = p.appearance['haircut']
        for k, v in pairs(values) do
            if k == 'bgURL' or k == 'fgURL' or k == 'bgHex' or k == 'fgHex' or k == 'pHex' or k == 'pURL' then
                if hc.main then
                    hc.main[k] = v
                    hc.main.cached = nil
                end
            else
                hc[k] = v
            end
        end
    end
end

-- [value name] = { where in the face (a table, or positioners.<feature>), field, set when false too }
local FACE_FIELDS = {}
for _, row in ipairs({
    { 'eyeShape', 'eye', 'shape' }, { 'eyeBgHex', 'eye', 'bgHex' }, { 'eyeFgHex', 'eye', 'fgHex' },
    { 'eyeWMul', 'eye', 'wMul' }, { 'eyeHMul', 'eye', 'hMul' },
    { 'pupilShape', 'pupil', 'shape' }, { 'pupilBgHex', 'pupil', 'bgHex' }, { 'pupilFgHex', 'pupil', 'fgHex' },
    { 'pupilWMul', 'pupil', 'wMul' }, { 'pupilHMul', 'pupil', 'hMul' },
    { 'eyeX', 'positioners.eye', 'x' }, { 'eyeY', 'positioners.eye', 'y' }, { 'eyeR', 'positioners.eye', 'r' },
    { 'eyeLookAtMouse', 'eye', 'lookAtMouse', true },
    { 'browShape', 'brow', 'shape' }, { 'browBgHex', 'brow', 'bgHex' }, { 'browWMul', 'brow', 'wMul' },
    { 'browHMul', 'brow', 'hMul' }, { 'browBend', 'brow', 'bend' }, { 'browY', 'positioners.brow', 'y' },
    { 'noseShape', 'nose', 'shape' }, { 'noseBgHex', 'nose', 'bgHex' }, { 'noseFgHex', 'nose', 'fgHex' },
    { 'noseWMul', 'nose', 'wMul' }, { 'noseHMul', 'nose', 'hMul' }, { 'noseY', 'positioners.nose', 'y' },
    { 'mouthShape', 'mouth', 'shape' }, { 'mouthUpperLipShape', 'mouth', 'upperLipShape' },
    { 'mouthLowerLipShape', 'mouth', 'lowerLipShape' }, { 'mouthLipHex', 'mouth', 'lipHex' },
    { 'mouthBackdropHex', 'mouth', 'backdropHex' }, { 'mouthUpperLipScale', 'mouth', 'upperLipScale' },
    { 'mouthLowerLipScale', 'mouth', 'lowerLipScale' }, { 'mouthWMul', 'mouth', 'wMul' },
    { 'mouthHMul', 'mouth', 'hMul' }, { 'mouthY', 'positioners.mouth', 'y' },
    { 'teethShape', 'teeth', 'shape' }, { 'teethWMul', 'teeth', 'wMul' }, { 'teethHMul', 'teeth', 'hMul' },
    { 'teethStickOut', 'teeth', 'stickOut', true }, { 'teethBgHex', 'teeth', 'bgHex' },
    { 'teethFgHex', 'teeth', 'fgHex' }, { 'teethGum', 'teeth', 'gum', true },
    { 'teethGumHex', 'teeth', 'gumHex' }, { 'teethGumDepth', 'teeth', 'gumDepth' },
}) do
    local feature = row[2]:match('^positioners%.(.+)$')
    FACE_FIELDS[row[1]] = { feature = feature or row[2], positioner = feature ~= nil, field = row[3],
        evenFalse = row[4] or false }
end

-- Update face appearance (eye/pupil/brow/nose/mouth/teeth shape, colors, positions): the
-- values named in FACE_FIELDS; a value that's nil (or false, but for the on/off ones) is left as is.
function lib.updateFaceOfPart(instance, partName, values)
    local p = instance.dna.parts[partName]
    if not p or not p.appearance or not p.appearance['face'] then return end
    local face = p.appearance['face']
    D.ensureDefaults(face, D.face)
    for name, value in pairs(values) do
        local to = FACE_FIELDS[name]
        if to and (value or (to.evenFalse and value == false)) then
            local where = to.positioner and face.positioners[to.feature] or face[to.feature]
            where[to.field] = value
        end
    end
end

-- Update top-level positioners (leg.x, ear.y, nose.t) and faceMagnitude.
-- values can contain: legX, earY, noseT, faceMagnitude
function lib.updatePositioners(instance, values)
    if not instance.dna.positioners then instance.dna.positioners = {} end
    D.ensureDefaults(instance.dna.positioners, D.positioners)
    local pos = instance.dna.positioners

    if values.legX then pos.leg.x = values.legX end
    if values.earY then pos.ear.y = values.earY end
    if values.noseT then pos.nose.t = values.noseT end
    if values.faceMagnitude then instance.dna.faceMagnitude = values.faceMagnitude end
end

-- Update connected-skin or connected-hair appearance colors.
-- Connected textures stretch between joint-linked body parts (used for arms/legs).
-- appearanceKey: 'connected-skin' (OMP composite) or 'connected-hair' (2-layer)
-- values: {bgURL, fgURL, bgHex, fgHex, pHex}
function lib.updateConnectedAppearance(instance, partName, appearanceKey, values)
    local p = instance.dna.parts[partName]
    if p and p.appearance and p.appearance[appearanceKey] then
        local main = p.appearance[appearanceKey].main
        if main then
            for k, v in pairs(values) do
                main[k] = v
            end
            -- Clear cached RGB so makeCached() recalculates from the new hex values
            main.cached = nil
        end
    end
end


lib.add = add
lib.initBlock = initBlock
lib.createDefaultTextureDNABlock = createDefaultTextureDNABlock

return lib
