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

-- Update face appearance (eye/pupil/brow/nose/mouth shape, colors, positions).
-- values can contain: eyeShape, eyeBgHex, eyeFgHex, eyeWMul, eyeHMul,
-- eyeR, eyeLookAtMouse,
-- pupilShape, pupilBgHex, pupilFgHex, pupilWMul, pupilHMul, eyeX, eyeY,
-- browShape, browBgHex, browWMul, browHMul, browBend, browY,
-- noseShape, noseBgHex, noseFgHex, noseWMul, noseHMul, noseY,
-- mouthShape, mouthUpperLipShape, mouthLowerLipShape, mouthLipHex,
-- mouthBackdropHex, mouthUpperLipScale, mouthLowerLipScale, mouthWMul, mouthHMul, mouthY,
-- teethShape, teethWMul, teethHMul, teethStickOut, teethBgHex, teethFgHex
function lib.updateFaceOfPart(instance, partName, values)
    local p = instance.dna.parts[partName]
    if not p or not p.appearance or not p.appearance['face'] then return end
    local face = p.appearance['face']
    D.ensureDefaults(face, D.face)

    if values.eyeShape then face.eye.shape = values.eyeShape end
    if values.eyeBgHex then face.eye.bgHex = values.eyeBgHex end
    if values.eyeFgHex then face.eye.fgHex = values.eyeFgHex end
    if values.eyeWMul then face.eye.wMul = values.eyeWMul end
    if values.eyeHMul then face.eye.hMul = values.eyeHMul end
    if values.pupilShape then face.pupil.shape = values.pupilShape end
    if values.pupilBgHex then face.pupil.bgHex = values.pupilBgHex end
    if values.pupilFgHex then face.pupil.fgHex = values.pupilFgHex end
    if values.pupilWMul then face.pupil.wMul = values.pupilWMul end
    if values.pupilHMul then face.pupil.hMul = values.pupilHMul end
    if values.eyeX then face.positioners.eye.x = values.eyeX end
    if values.eyeY then face.positioners.eye.y = values.eyeY end
    if values.eyeR then face.positioners.eye.r = values.eyeR end
    if values.eyeLookAtMouse ~= nil then face.eye.lookAtMouse = values.eyeLookAtMouse end

    if values.browShape then face.brow.shape = values.browShape end
    if values.browBgHex then face.brow.bgHex = values.browBgHex end
    if values.browWMul then face.brow.wMul = values.browWMul end
    if values.browHMul then face.brow.hMul = values.browHMul end
    if values.browBend then face.brow.bend = values.browBend end
    if values.browY then face.positioners.brow.y = values.browY end

    if values.noseShape then face.nose.shape = values.noseShape end
    if values.noseBgHex then face.nose.bgHex = values.noseBgHex end
    if values.noseFgHex then face.nose.fgHex = values.noseFgHex end
    if values.noseWMul then face.nose.wMul = values.noseWMul end
    if values.noseHMul then face.nose.hMul = values.noseHMul end
    if values.noseY then face.positioners.nose.y = values.noseY end

    if values.mouthShape then face.mouth.shape = values.mouthShape end
    if values.mouthUpperLipShape then face.mouth.upperLipShape = values.mouthUpperLipShape end
    if values.mouthLowerLipShape then face.mouth.lowerLipShape = values.mouthLowerLipShape end
    if values.mouthLipHex then face.mouth.lipHex = values.mouthLipHex end
    if values.mouthBackdropHex then face.mouth.backdropHex = values.mouthBackdropHex end
    if values.mouthUpperLipScale then face.mouth.upperLipScale = values.mouthUpperLipScale end
    if values.mouthLowerLipScale then face.mouth.lowerLipScale = values.mouthLowerLipScale end
    if values.mouthWMul then face.mouth.wMul = values.mouthWMul end
    if values.mouthHMul then face.mouth.hMul = values.mouthHMul end
    if values.mouthY then face.positioners.mouth.y = values.mouthY end

    if values.teethShape then face.teeth.shape = values.teethShape end
    if values.teethWMul then face.teeth.wMul = values.teethWMul end
    if values.teethHMul then face.teeth.hMul = values.teethHMul end
    if values.teethStickOut ~= nil then face.teeth.stickOut = values.teethStickOut end
    if values.teethBgHex then face.teeth.bgHex = values.teethBgHex end
    if values.teethFgHex then face.teeth.fgHex = values.teethFgHex end
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
