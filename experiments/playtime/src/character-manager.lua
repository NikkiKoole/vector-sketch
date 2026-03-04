local lib = {}

local objectManager = require 'src.object-manager'
local joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'
local box2dDrawTextured = require 'src.physics.box2d-draw-textured'
local subtypes = require 'src.subtypes'
local ST = require 'src.shape-types'
local JT = require('src.joint-types')
local BT = require('src.body-types')
local NT = require('src.node-types')
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')
local state = require('src.state')
local D = require('src.dna-defaults')
local C = require('src.shape-catalogs')
local topology = require('src.character-topology')

-- Negative group index counter for character self-collision prevention.
-- Each character gets a unique negative index so its fixtures never collide
-- with each other, but fixtures from different characters (different indices)
-- still collide normally.
local nextGroupIndex = -1
local nextZGroupOffset = 1

-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in lib.drawTexturedWorld(world)
-- the torso images, or maybe every tex-fixture also needs a growvalue that describes
-- how much the w, h values will be grown.
-- next the chesthair has a grow too, the torso too and I also have a foot offset value that should be parametrized.

-- do lerping positioners (arm beginning, leg beginnnig, ear)
-- OMP images as limb hair (and chesthair) -- maybe we should just know which images have a mask and if they are OMP
-- do FACE PARTS


local function cyclicShift(arr, shift)
    local n = #arr
    local result = {}
    shift = shift % n -- handles overflow and negative values

    for i = 1, n do
        local new_index = ((i - 1 - shift) % n) + 1
        result[i] = arr[new_index]
    end

    return result
end

local function getBoundingBox(poly)
    assert(#poly % 2 == 0, "Polygon must have even number of coordinates")

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, #poly, 2 do
        local x, y = poly[i], poly[i + 1]
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    return {
        x = minX,
        y = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX,
        height = maxY - minY
    }
end
local randomHexColor = utils.randomHexColor


local function createDefaultTextureDNABlock(shape, skipFG)
    --local r, g, b, a = box2dDrawTextured.hexToColor('ff0000ff')
    --print(r, g, b, a)

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
    -- local r, g, b, a = box2dDrawTextured.hexToColor('ff0000ff')
    -- print(r, g, b, a)
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
                -- Without this, deepCopy in addTexturesFromInstance2 copies stale cached
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
-- pupilShape, pupilBgHex, pupilFgHex, pupilWMul, pupilHMul, eyeX, eyeY,
-- browShape, browBgHex, browWMul, browHMul, browBend, browY,
-- noseShape, noseBgHex, noseFgHex, noseWMul, noseHMul, noseY,
-- mouthShape, mouthUpperLipShape, mouthLowerLipShape, mouthLipHex,
-- mouthBackdropHex, mouthLipScale, mouthWMul, mouthHMul, mouthY,
-- teethShape, teethHMul, teethStickOut, teethBgHex, teethFgHex
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
    if values.mouthLipScale then face.mouth.lipScale = values.mouthLipScale end
    if values.mouthWMul then face.mouth.wMul = values.mouthWMul end
    if values.mouthHMul then face.mouth.hMul = values.mouthHMul end
    if values.mouthY then face.positioners.mouth.y = values.mouthY end

    if values.teethShape then face.teeth.shape = values.teethShape end
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

local function randomPatternURL()
    local pats = C.patternTextures
    -- strip 'pat/' prefix, add '.png' suffix to match pURL format
    local pat = pats[math.ceil(math.random() * #pats)]
    return pat:gsub('^pat/', '') .. '.png'
end

-- Randomize torso/head shapes, scales, colors, and clear skin patches.
local function randomizeShapes(instance)
    local randomHexColor = utils.randomHexColor
    local urls = C.torsoHeadShapes
    local urlIndex = math.ceil(math.random() * #urls)
    local url = urls[urlIndex]
    local creation = instance.dna.creation
    local count = creation.torsoSegments
    local s = D.randomInRangeWeighted('bodyScale')

    for i = 1, count do
        lib.updatePart('torso' .. i,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
    end

    local headScale = D.randomInRangeWeighted('bodyScale')
    local headUrlIndex = math.ceil(math.random() * #urls)
    local headUrl = urls[headUrlIndex]
    lib.updatePart('head',
        { shape8URL = headUrl .. '.png', sy = headScale * (math.random() < 0.5 and -1 or 1), sx = headScale },
        instance)

    -- Random colors + pattern — shared across all torso segments + head
    local bgHex = '000000ff'
    local fgHex = randomHexColor()
    local pHex = randomHexColor()
    local skinPURL = randomPatternURL()
    for i = 1, count do
        lib.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex, pURL = skinPURL })
        lib.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex, pURL = skinPURL }, 'patch1')
        lib.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex, pURL = skinPURL }, 'patch2')
    end
    lib.updateSkinOfPart(instance, 'head',
        { bgHex = bgHex, fgHex = fgHex, pHex = pHex, pURL = skinPURL })

    -- Clear skin patches (they're optional overlays, not always wanted)
    for _, patchName in ipairs({'patch1', 'patch2', 'patch3'}) do
        local headSkin = instance.dna.parts.head.appearance.skin
        if headSkin[patchName] then
            headSkin[patchName].bgURL = ''
            headSkin[patchName].fgURL = ''
        end
        for i = 1, count do
            local torsoSkin = instance.dna.parts['torso' .. i].appearance.skin
            if torsoSkin[patchName] then
                torsoSkin[patchName].bgURL = ''
                torsoSkin[patchName].fgURL = ''
            end
        end
    end
end

-- Randomize ear shapes, scales, and colors.
local function randomizeEars(instance)
    local randomHexColor = utils.randomHexColor
    local earUrls = C.earShapes
    local earUrlIndex = math.ceil(math.random() * #earUrls)
    local earUrl = earUrls[earUrlIndex]
    local earSy = D.randomInRangeWeighted('earScale')
    local earSx = D.randomInRangeWeighted('earScale')
    -- Sync w/h between ears so they're always symmetric
    local earW = instance.dna.parts.lear.dims.w
    local earH = instance.dna.parts.lear.dims.h
    lib.updatePart('lear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = -earSx, w = earW, h = earH },
        instance)
    lib.updatePart('rear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = earSx, w = earW, h = earH },
        instance)

    local earBgHex = '000000ff'
    local earFgHex = randomHexColor()
    local earPHex = randomHexColor()
    local earPURL = randomPatternURL()
    lib.updateSkinOfPart(instance, 'lear',
        { bgHex = earBgHex, fgHex = earFgHex, pHex = earPHex, pURL = earPURL })
    lib.updateSkinOfPart(instance, 'rear',
        { bgHex = earBgHex, fgHex = earFgHex, pHex = earPHex, pURL = earPURL })
end

-- Randomize feet/hand shapes, scales, and colors.
local function randomizeFeetAndHands(instance)
    local randomHexColor = utils.randomHexColor
    local fhUrls = C.handShapes
    local fUrlIndex = math.ceil(math.random() * #fhUrls)
    local fUrl = fhUrls[fUrlIndex]
    local fS = D.randomInRangeWeighted('feetScale')

    lib.updatePart('lfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = fS },
        instance)
    lib.updatePart('rfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = -fS },
        instance)

    local handScale = D.randomInRangeWeighted('handScale')
    local handUrlIndex = math.ceil(math.random() * #fhUrls)
    local handUrl = fhUrls[handUrlIndex]
    lib.updatePart('lhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = handScale },
        instance)
    lib.updatePart('rhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = -handScale },
        instance)

    -- Random feet skin colors
    local feetFgHex = randomHexColor()
    local feetPHex = randomHexColor()
    local feetPURL = randomPatternURL()
    for _, part in ipairs({'lfoot', 'rfoot'}) do
        lib.updateSkinOfPart(instance, part,
            { bgHex = '000000ff', fgHex = feetFgHex, pHex = feetPHex, pURL = feetPURL })
    end

    -- Random hand skin colors
    local handFgHex = randomHexColor()
    local handPHex = randomHexColor()
    local handPURL = randomPatternURL()
    for _, part in ipairs({'lhand', 'rhand'}) do
        lib.updateSkinOfPart(instance, part,
            { bgHex = '000000ff', fgHex = handFgHex, pHex = handPHex, pURL = handPURL })
    end
end

-- Randomize haircut, bodyhair, connected-skin, and connected-hair textures.
-- hairColor: shared hex color for all hair-related parts.
local function randomizeTextures(instance, hairColor)
    local randomHexColor = utils.randomHexColor
    local count = instance.dna.creation.torsoSegments

    -- Random haircut (update both head and torso1 since isPotatoHead flip changes owner)
    local hcUrl = C.haircutTextures[math.ceil(math.random() * #C.haircutTextures)]
    local hcBgURL = hcUrl .. '.png'
    local hcFgURL = C.hairsWithMask[hcBgURL] and hcBgURL:gsub('%.png', '-mask.png') or ''
    local hcValues = {
        bgURL = hcBgURL, fgURL = hcFgURL,
        bgHex = hairColor, width = D.randomInRangeWeighted('haircutWidth'),
    }
    lib.updateHaircutOfPart(instance, 'head', hcValues)
    lib.updateHaircutOfPart(instance, 'torso1', hcValues)

    -- Random bodyhair (shared hairColor for bgHex, independent fgHex/pHex for variety)
    local bhUrls = C.bodyhairTextures
    local bhUrlIndex = math.ceil(math.random() * #bhUrls)
    local bhUrl = bhUrls[bhUrlIndex]
    local bhFgHex = randomHexColor()
    local bhPHex = randomHexColor()
    local bhPURL = randomPatternURL()
    for i = 1, count do
        lib.updateBodyhairOfPart(instance, 'torso' .. i,
            { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png',
              bgHex = hairColor, fgHex = bhFgHex, pHex = bhPHex, pURL = bhPURL })
    end

    -- Random arm connected-skin
    local armSkinUrl = C.limbSkinTextures[math.ceil(math.random() * #C.limbSkinTextures)]
    local armSkinFgHex = randomHexColor()
    local armSkinPHex = randomHexColor()
    local armSkinPURL = randomPatternURL()
    for _, part in ipairs({'luarm', 'ruarm'}) do
        lib.updateConnectedAppearance(instance, part, 'connected-skin',
            { bgURL = armSkinUrl .. '.png', fgURL = armSkinUrl .. '-mask.png',
              fgHex = armSkinFgHex, pHex = armSkinPHex, pURL = armSkinPURL })
    end

    -- Random leg connected-skin
    local legSkinUrl = C.limbSkinTextures[math.ceil(math.random() * #C.limbSkinTextures)]
    local legSkinFgHex = randomHexColor()
    local legSkinPHex = randomHexColor()
    local legSkinPURL = randomPatternURL()
    for _, part in ipairs({'luleg', 'ruleg'}) do
        lib.updateConnectedAppearance(instance, part, 'connected-skin',
            { bgURL = legSkinUrl .. '.png', fgURL = legSkinUrl .. '-mask.png',
              fgHex = legSkinFgHex, pHex = legSkinPHex, pURL = legSkinPURL })
    end

    -- Torso connected-skin (uses leg skin for continuity)
    for i = 1, count do
        lib.updateConnectedAppearance(instance, 'torso' .. i, 'connected-skin',
            { bgURL = legSkinUrl .. '.png', fgURL = legSkinUrl .. '-mask.png',
              fgHex = legSkinFgHex, pHex = legSkinPHex, pURL = legSkinPURL })
    end

    -- Random arm connected-hair (shared hairColor)
    local armHairUrl = C.limbHairTextures[math.ceil(math.random() * #C.limbHairTextures)]
    for _, part in ipairs({'luarm', 'ruarm'}) do
        lib.updateConnectedAppearance(instance, part, 'connected-hair',
            { bgURL = armHairUrl .. '.png', bgHex = hairColor })
    end

    -- Random leg connected-hair (shared hairColor)
    local legHairUrl = C.limbHairTextures[math.ceil(math.random() * #C.limbHairTextures)]
    for _, part in ipairs({'luleg', 'ruleg'}) do
        lib.updateConnectedAppearance(instance, part, 'connected-hair',
            { bgURL = legHairUrl .. '.png', bgHex = hairColor })
    end

    -- Torso connected-hair (uses leg hair URL for continuity, shared hairColor)
    for i = 1, count do
        lib.updateConnectedAppearance(instance, 'torso' .. i, 'connected-hair',
            { bgURL = legHairUrl .. '.png', bgHex = hairColor })
    end
end

-- Randomize face features: eyes, pupils, brows, nose, mouth, and teeth.
-- hairColor: shared hex color used for brow color.
local function randomizeFace(instance, hairColor)
    local randomHexColor = utils.randomHexColor
    local randomEyeY = D.randomInRangeWeighted('eyeY')
    local randomMouthY = randomEyeY + D.randomInRangeWeighted('mouthYOffset')
    local faceValues = {
        eyeShape = math.ceil(math.random() * #C.eyeShapes),
        pupilShape = math.ceil(math.random() * #C.pupilShapes),
        eyeX = D.randomInRangeWeighted('eyeX'),
        eyeY = randomEyeY,
        eyeWMul = D.randomInRangeWeighted('eyeWMul'),
        eyeHMul = D.randomInRangeWeighted('eyeHMul'),
        pupilWMul = D.randomInRangeWeighted('pupilWMul'),
        pupilHMul = D.randomInRangeWeighted('pupilHMul'),
        eyeBgHex = '000000ff',
        eyeFgHex = 'ffffffff',
        pupilBgHex = '000000ff',
        mouthShape = math.ceil(math.random() * #mouthShapes.normalized),
        mouthUpperLipShape = math.ceil(math.random() * #C.upperLipShapes),
        mouthLowerLipShape = math.ceil(math.random() * #C.lowerLipShapes),
        mouthLipHex = 'cc5555ff',
        mouthBackdropHex = '00000033',
        mouthLipScale = D.randomInRangeWeighted('mouthLipScale'),
        mouthWMul = D.randomInRangeWeighted('mouthWMul'),
        mouthHMul = D.randomInRangeWeighted('mouthHMul'),
        mouthY = randomMouthY,
        browShape = math.ceil(math.random() * #C.browShapes),
        browBgHex = hairColor,
        browWMul = D.randomInRangeWeighted('browWMul'),
        browHMul = D.randomInRangeWeighted('browHMul'),
        browBend = D.randomIntInRangeWeighted('browBend'),
        browY = D.randomInRangeWeighted('browY'),
        noseShape = math.ceil(math.random() * #C.noseShapes),
        noseBgHex = '000000ff',
        noseFgHex = randomHexColor(),
        noseWMul = D.randomInRangeWeighted('noseWMul'),
        noseHMul = D.randomInRangeWeighted('noseHMul'),
        noseY = D.randomInRangeWeighted('noseY'),
        teethShape = math.random() < D.randomRanges.teethChance and math.ceil(math.random() * #C.teethShapes) or 0,
        teethHMul = D.randomInRangeWeighted('teethHMul'),
        teethStickOut = math.random() < D.randomRanges.teethStickOut,
        teethBgHex = 'ffffffff',
        teethFgHex = 'eeeeeeff',
    }
    lib.updateFaceOfPart(instance, 'head', faceValues)
    lib.updateFaceOfPart(instance, 'torso1', faceValues)
end

-- Randomize all visual aspects of a character instance.
function lib.randomizeMipo(instance)
    if not instance then return end

    -- Generate one shared hair color for haircut, bodyhair, connected-hair, and brows
    local hairColor = utils.randomHexColor()

    randomizeShapes(instance)
    randomizeEars(instance)
    randomizeFeetAndHands(instance)
    randomizeTextures(instance, hairColor)
    randomizeFace(instance, hairColor)

    -- Disable physics nose when overlay nose is randomized
    lib.rebuildFromCreation(instance, { isPotatoHead = not instance.dna.creation.isPotatoHead, noseSegments = 0 })
    lib.addTexturesFromInstance2(instance)
end

-- 8-vertex polygon shapes for character body parts, keyed by texture filename
local shape8Dict = {
    ['shapeA1.png'] = { dimensions = { 339, 560 },
        vertices = { 1, -272, 112, -133, 154, 76, 123, 229, 1, 273, -134, 225, -145, 73, -91, -132 } },
    ['shapeA2.png'] = { dimensions = { 289, 468 },
        vertices = { 11, -224, 60, -144, 59, -20, 133, 135, 4, 224, -133, 131, -51, -20, -39, -147, } },
    ['shapeA3.png'] = { dimensions = { 370, 422 },
        vertices = { -6, -189, 135, -69, 160, 45, 123, 154, -6, 189, -92, 153, -164, 53, -155, -67 } },
    ['shapeA4.png'] = { dimensions = { 308, 414 },
        vertices = { 7, -194, 133, -56, 126, 45, 101, 190, -6, 195, -129, 185, -134, 40, -110, -66 } },
    ['shapes1.png'] = { dimensions = { 296, 495 },
        vertices = { 10, -244, 133, -56, 135, 48, 124, 221, -0, 231, -128, 215, -138, 41, -134, -62 } },
    ['shapes2.png'] = { dimensions = { 252, 461 },
        vertices = { -3, -223, 74, -78, 89, 51, 104, 196, -0, 231, -92, 202, -94, 54, -61, -80 } },
    ['shapes3.png'] = { dimensions = { 324, 442 },
        vertices = { -3, -206, 132, -137, 148, 12, 110, 186, -6, 216, -97, 192, -149, 7, -141, -141 } },
    ['shapes4.png'] = { dimensions = { 364, 266 },
        vertices = { 0, -123, 164, -98, 148, 12, 157, 112, -1, 117, -149, 105, -149, 7, -168, -87 } },
    ['shapes5.png'] = { dimensions = { 194, 338 },
        vertices = { 0, -162, 74, -132, 78, -4, 73, 148, -2, 156, -81, 142, -84, 1, -87, -126, } },
    ['shapes6.png'] = { dimensions = { 250, 384 },
        vertices = { 3, -178, 77, -118, 92, -0, 93, 143, -2, 160, -85, 141, -92, 0, -67, -119 } },
    ['shapes7.png'] = { dimensions = { 722, 929 },
        vertices = { -3, -452, 127, -245, 305, 19, 247, 384, -2, 451, -276, 378, -283, 15, -207, -238 } },
    ['shapes8.png'] = { dimensions = { 788, 708 },
        vertices = { 3, -154, 271, -307, 341, 26, 89, 298, -9, 332, -166, 299, -302, 34, -238, -319 } },
    ['shapes9.png'] = { dimensions = { 520, 468 },
        vertices = { -0, -236, 233, -191, 198, 24, 174, 206, -18, 216, -226, 205, -233, 19, -234, -198 } },
    ['shapes10.png'] = { dimensions = { 520, 856 },
        vertices = { 4, -407, 166, -232, 231, 24, 141, 344, -16, 418, -186, 332, -233, 19, -182, -233 } },
    ['shapes11.png'] = { dimensions = { 652, 932 },
        vertices = { 4, -451, 110, -405, 195, 6, 306, 408, 13, 436, -277, 417, -205, -3, -114, -417 } },
    ['shapes12.png'] = { dimensions = { 558, 323 },
        vertices = { 17, -129, 208, -76, 249, 11, 191, 109, 9, 142, -228, 103, -247, -1, -175, -91 } },
    ['shapes13.png'] = { dimensions = { 486, 556 },
        vertices = { 22, -239, 175, -101, 197, 11, 177, 219, 14, 260, -168, 210, -156, 12, -125, -105 } },
    ['feet2r.png'] = { dimensions = { 261, 475 },
        vertices = { 46, -189, 96, -184, 131, 48, 109, 180, 45, 234, -15, 176, -70, 53, -87, -193 } },
    ['feet6r.png'] = { dimensions = { 293, 612 },
        vertices = { -28, -264, 46, -180, 110, 42, 117, 167, -7, 274, -109, 268, -110, 47, -102, -182 } },
    ['feet5xr.png'] = { dimensions = { 174, 621 },
        vertices = { -4, -243, 25, -216, 46, 31, 66, 244, 3, 275, -69, 245, -71, 29, -41, -233 } },
    ['feet3xr.png'] = { dimensions = { 231, 505 },
        vertices = { 8, -199, 56, -154, 46, 31, 61, 196, 5, 245, -54, 191, -71, 29, -38, -150 } },
    ['feet7r.png'] = { dimensions = { 300, 546 },
        vertices = { -4, -243, 57, -227, 111, 6, 87, 218, 3, 256, -69, 213, -96, 10, -50, -223 } },
    ['feet8r.png'] = { dimensions = { 303, 465 },
        vertices = { -11, -200, 37, -151, 87, 6, 110, 180, -7, 203, -100, 176, -96, 10, -74, -149 } },
    ['hand3r.png'] = { dimensions = { 294, 489 },
        vertices = { -31, -215, 99, -111, 26, 52, 39, 192, -32, 242, -121, 188, -140, 50, -132, -110 } },
    ['feet7xr.png'] = { dimensions = { 216, 410 },
        vertices = { 4, -170, 71, -143, 77, -47, 45, 165, -11, 182, -71, 163, -67, -51, -42, -144 } },
    ['earx1r.png'] = { dimensions = { 312, 416 },
        vertices = { -32, -132, 71, -50, 92, 36, 36, 177, -23, 92, -74, 93, -117, 36, -140, -53 } },
    ['earx2r.png'] = { dimensions = { 354, 420 },
        vertices = { 23, -163, 125, -63, 135, 33, 116, 95, 16, 144, -74, 99, -112, 35, -89, -63 } },
    ['earx3r.png'] = { dimensions = { 369, 339 },
        vertices = { -111, -116, -23, -48, 36, 13, 96, 70, -11, 74, -94, 70, -107, 15, -114, -49 } },
    ['earx4r.png'] = { dimensions = { 306, 483 },
        vertices = { -15, -195, 85, -67, 69, 35, 54, 96, -13, 98, -74, 93, -92, 34, -108, -68 } },
    ['earx5r.png'] = { dimensions = { 240, 549 },
        vertices = { 9, -191, 49, -72, 69, 48, 82, 187, 10, 209, -61, 198, -69, 51, -54, -72 } },
    ['earx6r.png'] = { dimensions = { 240, 519 },
        vertices = { -15, -214, 79, -67, 92, 59, 73, 187, -4, 193, -66, 185, -88, 57, -94, -68 } },
    ['earx7r.png'] = { dimensions = { 204, 474 },
        vertices = { -49, -189, 48, -67, 69, 35, 54, 96, -13, 98, -74, 93, -92, 34, -81, -68 } },
    ['earx8r.png'] = { dimensions = { 402, 270 },
        vertices = { -22, -88, 85, -67, 128, 29, 120, 84, -13, 90, -153, 88, -160, 25, -108, -68 } },
    ['earx9r.png'] = { dimensions = { 231, 243 },
        vertices = { -4, -81, 38, -60, 66, 0, 62, 38, -7, 59, -73, 49, -82, 7, -57, -59 } },
    ['earx10r.png'] = { dimensions = { 168, 174 },
        vertices = { -3, -35, 29, -16, 32, 13, 35, 46, -7, 50, -50, 45, -45, 13, -37, -15 } },
    ['earx11r.png'] = { dimensions = { 177, 150 },
        vertices = { -1, -33, 29, -16, 32, 16, 14, 47, -16, 41, -50, 45, -45, 13, -37, -15 } },
    ['earx12r.png'] = { dimensions = { 240, 330 },
        vertices = { -19, -66, 39, -28, 76, 13, 49, 73, -9, 86, -45, 72, -57, 15, -62, -21 } },
    ['earx13r.png'] = { dimensions = { 225, 336 },
        vertices = { -33, -100, 12, -33, 29, 16, 43, 73, -9, 86, -54, 72, -57, 15, -62, -33 } },
    ['earx14r.png'] = { dimensions = { 270, 465 },
        vertices = { -54, -172, 47, -41, 76, 18, 102, 82, -39, 86, -105, 83, -117, 23, -104, -42 } },
    ['earx15r.png'] = { dimensions = { 132, 228 },
        vertices = { -20, -78, 15, -36, 26, 11, 21, 66, -16, 63, -37, 40, -43, 12, -48, -36 } },
    ['earx16r.png'] = { dimensions = { 312, 258 },
        vertices = { -57, -98, 25, -35, 54, 8, 69, 51, -50, 59, -89, 58, -99, 9, -95, -36 } },
}

topology.setShape8Dict(shape8Dict)

local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = true,
            neckSegments = 0,
            torsoSegments = 1,
            noseSegments = 1, -- 0 = no nose; >0 = segmented nose/trunk
        },
        positioners = {
            leg = { x = 0.5 },
            ear = { y = 0.5 },
            nose = { t = 0.35 },
        },
        faceMagnitude = 1,


        -- in the apppearance below we have a few options for types:
        -- skin = a skin that assumes a shape8 url to be present.
        -- bodyhair, = an overlay that assumes the shape8 url to be present, it will follow that
        -- connected-skin = a texture that will be drawn over a few connectd bodyparts
        -- connected-hair = an overlay that assumes a few parts to be there too.
        -- todo trace-hair, a texture that follows a few vertex indicises within 1 shape.
        parts = {
            ['nose-segment-template'] = {
                appearance = {

                    -- plain skin per segment; good first step
                    ['skin'] = {
                        zOffset = 230,
                        main = initBlock('shapeA2'), -- swap to a specific shape/texture if you prefer
                    },
                    -- ['connected-skin'] = {
                    --     main = add(initBlock('leg5'), {}),
                    --     zOffset = 3,
                    --     --endNode = 'tip'
                    -- },
                },
                -- small capsule by default; tweak as needed
                dims = { w = 40, h = 40, w2 = 4, sx = 1, sy = 1 },

                -- if we want the connected skin you probably want to use the capsule shape.
                -- if you want a normal txture you might want the shape8

                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',

                --shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 32, up = math.pi / 32 } }
            },
            ['torso-segment-template'] = {
                appearance = {
                    -- this will do the neck texturing (connecting torso and head)
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), {}),
                        endNode = 'head',
                        zOffset = 100,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'head',
                        zOffset = 101,
                    },
                    ['skin'] = {
                        zOffset = 200,
                        main = initBlock(),
                        patch1 = add(initBlock('patch2'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = add(initBlock('borsthaar4'), {}) },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 3,
                        main = initBlock('hair7'),
                    },
                    ['face'] = utils.deepCopy(D.face),
                },
                dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 },
                shape8URL = 'shapeA1.png',
                shape = ST.SHAPE8,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 },
            --    shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = {

                dims = { w = 80, w2 = 4, h = 150 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = ST.CAPSULE,
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 200,
                        main = initBlock(),
                        patch1 = add(initBlock('patch1'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = initBlock('borsthaar4') },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 3,
                        main = add(initBlock('hair6'), { fgURL = '' }),
                    },
                    ['face'] = utils.deepCopy(D.face),
                },
                dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',
                behaviors = { { name = 'KEEP_ANGLE', angle = 0 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } }
            },
            ['luleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lfoot',
                        zOffset = 300,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot',
                        zOffset = 301,
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } }
            },
            ['ruleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rfoot',
                        zOffset = 300,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rfoot',
                        zOffset = 301,
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 402,
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lhand',
                        zOffset = 403,
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi } }
            },
            ['ruarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 402,
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rhand',
                        zOffset = 403,
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi, up = 0 } }
            },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['lfoot'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 399,
                        main = add(initBlock(), { dir = -1 }),
                    },

                },
                dims = { w = 80, h = 150, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rfoot'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 399,
                        main = add(initBlock(), { dir = 1 }),
                    },
                },
                dims = { w = 80, h = 150, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            --['lfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            --['rfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 500,
                        main = add(initBlock(), { dir = -1 }),
                    },
                },
                dims = { w = 40, h = 40, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rhand'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 500,
                        main = add(initBlock(), {}),
                    },
                },
                dims = { w = 40, h = 40, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 190,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 100, h = 300, sx = .5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } },
                stanceAngle = -math.pi / 2 + math.pi / 5
            },
            ['rear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 190,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 100, h = 300, sx = -.5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } },
                stanceAngle = math.pi / 2 - math.pi / 5
            }
        },

    }
}



function lib.updateShape8(instance, partName, newShape8Name)
    -- Update the physics part
    lib.updatePart(partName, { shape8URL = newShape8Name .. '.png' }, instance)

    -- Trigger a rebuild
    lib.rebuildFromCreation(instance, {})

    -- Update all visuals linked to that shape
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'bgURL', newShape8Name .. '.png')
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'fgURL', newShape8Name .. '-mask.png')
    --lib.updateTextureGroupValueInRoot(instance, partName .. 'Hair', 'followShape8', newShape8Name .. '.png')

    -- Recreate the actual texture fixtures
    --   lib.addTextureFixturesFromInstance(instance)
end

-- copy pasted from playtime-ui.lua
local getCenterAndDimensions = mathutils.getCenterAndDimensions

local function recenterPoints(vertices)
    local bbox = getBoundingBox(vertices)
    local result = {}
    for i = 1, #vertices, 2 do
        local x = vertices[i]
        local y = vertices[i + 1]
        local newX = x - (bbox.x + bbox.width / 2)
        local newY = y - (bbox.y + bbox.height / 2)
        table.insert(result, newX)
        table.insert(result, newY)
    end
    return result
end

local makeTransformedVertices = mathutils.scalePolygonPoints

local lerp = mathutils.clampedLerp

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end


local function makePart(partName, instance, settings)
    local entry = instance.entryMap[partName]
    if not entry then return end
    local parent = entry.parent
    local prevA = 0

    if parent then
        if instance.parts[parent] then
            prevA = instance.parts[parent].body:getAngle()
            local parentOffsetX, parentOffsetY = topology.getOffsetFromParent(partName, instance, entry)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)
            settings.x = px
            settings.y = py
        end
    end

    local ownOffsetX, ownOffsetY = topology.getOwnOffset(partName, instance, entry)
    local xangle = topology.getAngleOffset(partName, instance, entry)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    local thing = objectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)
        thing.mipoId = instance.id
        thing.mipoPartName = partName

        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end

        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]
        local partB_thing = instance.parts[partName]

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
            }
            -- logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = topology.getOffsetFromParent(partName, instance, entry)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body

        local groupIndex = body:getFixtures()[1]:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end
    return poseCache
end
-- Parts with a stance angle (ears, feet) should keep the angle from makePart
-- rather than restoring the cached angle, since their stanceAngle may have changed.
local stanceAngleParts = { lear = true, rear = true, lfoot = true, rfoot = true }
local function applyPoseCache(instance, poseCache)
    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            if not stanceAngleParts[partName] then
                body:setAngle(pose.angle)
            end
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local gi = instance.groupIndex or pose.groupIndex
            local bodyFixtures = body:getFixtures()
            for j = 1, #bodyFixtures do
                bodyFixtures[j]:setGroupIndex(gi)
            end
        end
    end
end

local function fixDrift(positionTorso, instance)
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end

local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end


    for k, v in pairs(data) do
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end

    local oldPosX, oldPosY = 0, 0
    local oldAngle = 0

    -- Remove old body
    local wasSelected = false
    if instance.parts[partName] then
        local oldBody = instance.parts[partName].body
        oldPosX, oldPosY = oldBody:getPosition()
        oldAngle = oldBody:getAngle()
        wasSelected = (state.selection.selectedObj and state.selection.selectedObj.body == oldBody)
        objectManager.destroyBody(oldBody)
        instance.parts[partName] = nil
    end

    local scale = instance.scale or 1
    -- Recreate the part
    local settings = {
        x = oldPosX,
        y = oldPosY,
        bodyType = BT.DYNAMIC,
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        behaviors = partData.behaviors,
        radius = (partData.dims.r or 0) * scale,
        width = (partData.dims.w or 0) * scale,
        width2 = (partData.dims.w2 or 0) * scale,
        width3 = (partData.dims.w3 or 0) * scale,
        height = (partData.dims.h or 0) * scale,
        height2 = (partData.dims.h2 or 0) * scale,
        height3 = (partData.dims.h3 or 0) * scale,
        height4 = (partData.dims.h4 or 0) * scale,
    }

    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = shape8Dict[partData.shape8URL].vertices
        settings.vertices = makeTransformedVertices(
            raw, (partData.dims.sx or 1) * scale, (partData.dims.sy or 1) * scale)
    end

    local children = instance.childrenMap[partName] or {}
    makePart(partName, instance, settings)

    if not instance.parts[partName] then return end

    -- after making a part set it to its angle so the children will be using that angle in their calculations.
    instance.parts[partName].body:setAngle(oldAngle)

    -- Re-select the new body if the old one was selected
    if wasSelected and instance.parts[partName] then
        local ud = instance.parts[partName].body:getUserData()
        if ud and ud.thing then
            state.selection.selectedObj = ud.thing
        end
    end

    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

-- Update a character body part's shape/dimensions and recreate it.
-- data: {shape8URL, sx, sy, w, h}
function lib.updatePart(partName, data, instance)
    local positionTorso = nil
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)
    updateSinglePart(partName, data, instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

-- given an instance with dna and a new creation, this function is made to change
-- a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings
    for k, v in pairs(newCreation) do
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }

    -- Track which part was selected so we can re-select after rebuild
    local selectedPartName = nil
    local selectedObj = state.selection.selectedObj
    if selectedObj and selectedObj.body and not selectedObj.body:isDestroyed() then
        for pName, part in pairs(instance.parts) do
            if part == selectedObj then
                selectedPartName = pName
                break
            end
        end
    end

    -- Step 2: Remove all existing parts
    for _, part in pairs(instance.parts) do
        objectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    instance.textures = {}
    --print(instance.scale)
    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end

    -- Re-select the same part (or torso1 if the old part no longer exists)
    if selectedPartName then
        local newPart = instance.parts[selectedPartName] or instance.parts['torso1']
        if newPart then
            state.selection.selectedObj = newPart
        end
    end
end

local function addSkinTexture(body, partData, skinData, scale)
    local _, _, w, h = getCenterAndDimensions(body)

    local documentSize = nil
    if partData.shape8URL then
        if shape8Dict[partData.shape8URL] then
            if shape8Dict[partData.shape8URL].dimensions then
                getBoundingBox(shape8Dict[partData.shape8URL].vertices)
                documentSize = {}
                documentSize.w = shape8Dict[partData.shape8URL].dimensions[1] * math.abs(partData.dims.sx)
                documentSize.h = shape8Dict[partData.shape8URL].dimensions[2] * math.abs(partData.dims.sy)
            end
        end
    end

    local growfactor = 1.1

    local fixture
    if (documentSize) then
        fixture = fixtures.createSFixture(body, 0, 0,
            subtypes.TEXFIXTURE,
            {
                width = documentSize.w * growfactor * scale,
                height = documentSize.h * growfactor *
                    scale
            })
    else
        fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE,
            { width = w * growfactor, height = h * growfactor })
    end
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.main = utils.deepCopy(skinData.main)
    ud.extra.main.bgURL = partData.shape8URL
    ud.extra.main.fgURL = partData.shape8URL:gsub('.png', '-mask.png')
    ud.extra.zOffset = skinData.zOffset or 0
    if partData.dims.sy ~= nil and partData.dims.sy < 0 then
        ud.extra.main.fy = -1
    end
    if partData.dims.sx ~= nil and partData.dims.sx < 0 then
        ud.extra.main.fx = -1
    end

    if skinData.patch1 then
        ud.extra.patch1 = utils.deepCopy(skinData.patch1)
    end
    if skinData.patch2 then
        ud.extra.patch2 = utils.deepCopy(skinData.patch2)
    end
    if skinData.patch3 then
        ud.extra.patch3 = utils.deepCopy(skinData.patch3)
    end
end

local function addBodyhairTexture(body, partName, partData, bodyhairData, scale)
    local _, _, w, h = getCenterAndDimensions(body)
    local growfactor = bodyhairData.growfactor or 1.2
    local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE,
        { width = w * growfactor, height = h * growfactor })
    local ud = fixture:getUserData()
    ud.extra.OMP = false
    -- Layer bodyhair above skin (skin zOffset is 200 for torso/head parts)
    local skinZ = (partData.appearance and partData.appearance['skin'] and partData.appearance['skin'].zOffset) or 200
    ud.extra.zOffset = skinZ + 10
    ud.extra.dirty = true
    ud.extra.main = utils.deepCopy(bodyhairData.main)

    local raw = shape8Dict[partData.shape8URL].vertices
    local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor * scale,
        (partData.dims.sy or 1) * growfactor * scale)
    local newVertices = cyclicShift(vertices, 2)
    if partData.dims.sy < 0 then
        newVertices = cyclicShift(newVertices, 8)
    end

    ud.extra.vertices = newVertices
    ud.extra.vertexCount = #vertices / 2
end

local function addConnectedTexture(body, partName, partData, connData, instance, scale)
    local torsoSegments = instance.dna.creation.torsoSegments
    local noseSegments  = instance.dna.creation.noseSegments
    local jointLabels   = {}

    local fixture       = fixtures.createSFixture(body, 0, 0, subtypes.CONNECTED_TEXTURE,
        { radius = 30 * scale })

    local ud            = fixture:getUserData()

    ud.extra            = {
        attachTo = partName,
        OMP = true,
        dirty = true,
        main = utils.deepCopy(connData.main),
        zOffset = connData.zOffset or 0,
        nodes = {},
        growExtra = 20 * scale,
    }

    -- wmul controls the rendered width of the connected texture.
    -- Use DNA value if set, otherwise default to instance scale.
    ud.extra.main.wmul  = connData.main.wmul or scale
    if partName:find('uleg') then
        if partName == 'luleg' then
            jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" }
        elseif partName == 'ruleg' then
            jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" }
        end
    end
    if partName:find('uarm') then
        local top = 'torso' .. torsoSegments

        if partName == 'luarm' then
            jointLabels = { top .. "->luarm", "luarm->llarm", "llarm->lhand" }
        elseif partName == 'ruarm' then
            jointLabels = { top .. "->ruarm", "ruarm->rlarm", "rlarm->rhand" }
        end
    end
    -- we only do neck stuff from the top torso to the head. (other torso segments are ignored)
    if partName == ('torso' .. torsoSegments) and connData.endNode == 'head' then
        local neckSegments2 = instance.dna.creation.neckSegments
        local previous = 'torso' .. torsoSegments

        for i = 1, neckSegments2 do
            local current = 'neck' .. i
            table.insert(jointLabels, previous .. '->' .. current)
            previous = current
        end
        -- Final connection to head
        table.insert(jointLabels, previous .. '->head')
    end

    if partName == 'nose1' and noseSegments > 0 then
        local startParent = instance.dna.creation.isPotatoHead and ('torso' .. torsoSegments) or
            'head'
        table.insert(jointLabels, startParent .. '->nose1')
        for i = 1, noseSegments - 1 do
            table.insert(jointLabels, 'nose' .. i .. '->nose' .. (i + 1))
        end
    end

    for j = 1, #jointLabels do
        local jointID = jointLabels[j]
        ud.extra.nodes[j] = { id = instance.joints[jointID], type = NT.JOINT }
    end
end

local function addHaircutTexture(body, partName, partData, haircutData, instance, scale)
    local rightPlaceForHaircut = false
    if instance.dna.creation.isPotatoHead and partName == 'torso1' then
        rightPlaceForHaircut = true
    end
    if not instance.dna.creation.isPotatoHead and partName == 'head' then
        rightPlaceForHaircut = true
    end

    if rightPlaceForHaircut then
        local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TRACE_VERTICES,
            { radius = 30, width = 100, height = 100 })
        local ud = fixture:getUserData()
        local hasMask = haircutData.main.fgURL and haircutData.main.fgURL ~= ''
        ud.extra.OMP = hasMask
        ud.extra.zOffset = 220
        ud.extra.dirty = true
        ud.extra.main = utils.deepCopy(haircutData.main)
        ud.extra.width = (haircutData.width or 250) * scale
        ud.extra.startIndex = haircutData.startIndex
        ud.extra.endIndex = haircutData.endIndex

        if partData.dims.sy < 0 then
            ud.extra.startIndex = haircutData.startIndex + 4
            ud.extra.endIndex = haircutData.endIndex + 4
        end
    end
end

local function addFaceDecals(body, partName, partData, faceData, instance, scale)
    -- Face decals (eyes + pupils) go on head (non-potato) or torso1 (potato)
    local rightPlaceForFace = false
    if instance.dna.creation.isPotatoHead and partName == 'torso1' then
        rightPlaceForFace = true
    end
    if not instance.dna.creation.isPotatoHead and partName == 'head' then
        rightPlaceForFace = true
    end

    if rightPlaceForFace and partData.shape8URL and shape8Dict[partData.shape8URL] then
        local face = faceData
        D.ensureDefaults(face, D.face)
        local eyePos = face.positioners.eye

        -- Get head shape vertices to compute eye positions
        local raw = shape8Dict[partData.shape8URL].vertices
        local verts = makeTransformedVertices(raw,
            (partData.dims.sx or 1) * scale, (partData.dims.sy or 1) * scale)

        -- 8-vertex polygon: 1=top, 3=right-mid, 5=bottom, 7=left-mid
        -- Indices are 1-based, pairs of x,y
        -- Normalize so topY < botY and leftX < rightX even when shape is flipped
        local topY = math.min(verts[2], verts[10])
        local botY = math.max(verts[2], verts[10])
        local leftX = math.min(verts[5], verts[13])
        local rightX = math.max(verts[5], verts[13])

        local leftEyeX = lerp(leftX, rightX, 0.5 - eyePos.x)
        local rightEyeX = lerp(leftX, rightX, 0.5 + eyePos.x)
        local eyeY = lerp(topY, botY, eyePos.y)

        -- Compute base eye size from head dimensions
        local headW = math.abs(rightX - leftX)
        local headH = math.abs(botY - topY)
        local fm = instance.dna.faceMagnitude
        local baseEyeW = headW * 0.25 * fm
        local baseEyeH = headH * 0.25 * fm

        local eye = face.eye
        local pupil = face.pupil

        local eyeW = baseEyeW * eye.wMul
        local eyeH = baseEyeH * eye.hMul
        local pupilW = baseEyeW * pupil.wMul
        local pupilH = baseEyeH * pupil.hMul

        local eyeBgURL = 'eye' .. eye.shape .. '.png'
        local eyeFgURL = 'eye' .. eye.shape .. '-mask.png'
        local pupilBgURL = 'pupil' .. pupil.shape .. '.png'
        -- Only some pupils have masks
        local pupilFgURL = ''
        local pupilMaskPath = 'textures/pupil' .. pupil.shape .. '-mask.png'
        if love.filesystem.getInfo(pupilMaskPath) then
            pupilFgURL = 'pupil' .. pupil.shape .. '-mask.png'
        end

        -- Create eye decals (left and right)
        -- Uses OMP compositing: outline + mask → pre-composited image
        local eyeZOffset = 250
        local eyeR = eyePos.r
        local eyeSides = {
            { ox = leftEyeX, label = 'leye', mirror = true, rot = -eyeR },
            { ox = rightEyeX, label = 'reye', rot = eyeR },
        }
        for _, side in ipairs(eyeSides) do
            local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local ud = f:getUserData()
            ud.label = side.label
            ud.extra.ox = side.ox
            ud.extra.oy = eyeY
            ud.extra.w = eyeW
            ud.extra.h = eyeH
            ud.extra.mirror = side.mirror or false
            ud.extra.rot = side.rot or 0
            ud.extra.zOffset = eyeZOffset
            ud.extra.OMP = true
            ud.extra.dirty = true
            ud.extra.main = {
                bgURL = eyeBgURL,
                fgURL = eyeFgURL,
                pURL = '',
                bgHex = eye.bgHex,
                fgHex = eye.fgHex,
                pHex = 'ffffff00',
            }
            box2dDrawTextured.makeCached(ud.extra.main)
        end

        -- Create pupil decals (left and right)
        -- Pupils with a mask use OMP compositing (2-color).
        -- Pupils without a mask are single-color (just tinted outline).
        local hasPupilMask = pupilFgURL ~= ''
        local pupilZOffset = 251
        local pupilSides = {
            { ox = leftEyeX, label = 'lpupil', mirror = true, eyeRot = -eyeR },
            { ox = rightEyeX, label = 'rpupil', eyeRot = eyeR },
        }
        for _, side in ipairs(pupilSides) do
            local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local ud = f:getUserData()
            ud.label = side.label
            ud.extra.ox = side.ox
            ud.extra.oy = eyeY
            ud.extra.w = pupilW
            ud.extra.h = pupilH
            ud.extra.mirror = side.mirror or false
            ud.extra.zOffset = pupilZOffset
            ud.extra.eyeW = eyeW
            ud.extra.eyeH = eyeH
            ud.extra.eyeMaskURL = eyeFgURL
            ud.extra.eyeMirror = side.mirror or false
            ud.extra.eyeRot = side.eyeRot or 0
            ud.extra.lookAtMouse = eye.lookAtMouse
            if hasPupilMask then
                ud.extra.OMP = true
                ud.extra.dirty = true
                ud.extra.main = {
                    bgURL = pupilBgURL,
                    fgURL = pupilFgURL,
                    pURL = '',
                    bgHex = pupil.bgHex,
                    fgHex = pupil.fgHex,
                    pHex = 'ffffff00',
                }
                box2dDrawTextured.makeCached(ud.extra.main)
            else
                ud.extra.OMP = false
                ud.extra.bgURL = pupilBgURL
                ud.extra.bgHex = pupil.bgHex
            end
        end

        -- Create brow decals (left and right)
        local brow = face.brow
        local browPos = face.positioners.brow
        local browY = lerp(topY, botY, browPos.y)
        local browW = headW * 0.2 * brow.wMul * fm
        local browH = headH * 0.1 * brow.hMul * fm
        local browURL = 'brow' .. brow.shape .. '.png'
        local browZOffset = 249
        local browSides = {
            { ox = leftEyeX, label = 'lbrow', mirror = false },
            { ox = rightEyeX, label = 'rbrow', mirror = true },
        }
        for _, side in ipairs(browSides) do
            local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local ud = f:getUserData()
            ud.label = side.label
            ud.extra.ox = side.ox
            ud.extra.oy = browY
            ud.extra.w = browW
            ud.extra.h = browH
            ud.extra.zOffset = browZOffset
            ud.extra.browCurve = true
            ud.extra.browBend = brow.bend
            ud.extra.browMirror = side.mirror
            ud.extra.bgURL = browURL
            ud.extra.bgHex = brow.bgHex
        end

        -- Create nose decal (single, centered)
        local nose = face.nose
        local noseShape = nose.shape
        if noseShape > 0 then
            local nosePos = face.positioners.nose
            local noseY = lerp(topY, botY, nosePos.y)
            local noseX = (leftX + rightX) / 2
            local noseW = headW * 0.15 * nose.wMul * fm
            local noseH = headH * 0.15 * nose.hMul * fm
            local noseBgURL = 'nose' .. noseShape .. '.png'
            local noseMaskPath = 'textures/nose' .. noseShape .. '-mask.png'
            local noseFgURL = ''
            if love.filesystem.getInfo(noseMaskPath) then
                noseFgURL = 'nose' .. noseShape .. '-mask.png'
            end
            local hasNoseMask = noseFgURL ~= ''
            local noseZOffset = 248

            local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local ud = f:getUserData()
            ud.label = 'nose'
            ud.extra.ox = noseX
            ud.extra.oy = noseY
            ud.extra.w = noseW
            ud.extra.h = noseH
            ud.extra.zOffset = noseZOffset
            if hasNoseMask then
                ud.extra.OMP = true
                ud.extra.dirty = true
                ud.extra.main = {
                    bgURL = noseBgURL,
                    fgURL = noseFgURL,
                    pURL = '',
                    bgHex = nose.bgHex,
                    fgHex = nose.fgHex,
                    pHex = 'ffffff00',
                }
                box2dDrawTextured.makeCached(ud.extra.main)
            else
                ud.extra.OMP = false
                ud.extra.bgURL = noseBgURL
                ud.extra.bgHex = nose.bgHex
            end
        end

        -- Create mouth decals (upper lip + lower lip)
        local mouth = face.mouth
        local mouthPos = face.positioners.mouth
        local mouthY = lerp(topY, botY, mouthPos.y)
        local mouthX = (leftX + rightX) / 2

        -- Get the normalized shape points and scale to head
        local shapeIdx = mouth.shape
        local mouthShape = mouthShapes.normalized[shapeIdx]
        if mouthShape then
            local mwMul = mouth.wMul
            local mhMul = mouth.hMul
            -- Scale mouth to ~40% of head width (adjustable via wMul/hMul)
            local mouthScaleX = (headW * 0.004) * mwMul * fm
            local mouthScaleY = (headH * 0.004) * mhMul * fm

            -- Build scaled + offset curve points (16 floats)
            local curvePoints = {}
            for ci = 1, 16, 2 do
                curvePoints[ci] = mouthShape.points[ci] * mouthScaleX + mouthX
                curvePoints[ci + 1] = mouthShape.points[ci + 1] * mouthScaleY + mouthY
            end

            local upperLipURL = 'upperlip' .. mouth.upperLipShape .. '.png'
            local upperLipMaskURL = 'upperlip' .. mouth.upperLipShape .. '-mask.png'
            local lowerLipURL = 'lowerlip' .. mouth.lowerLipShape .. '.png'
            local lowerLipMaskURL = 'lowerlip' .. mouth.lowerLipShape .. '-mask.png'

            -- Lower lip decal (draws first, handles stencil interior)
            local fLower = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local udLower = fLower:getUserData()
            udLower.label = 'lowerlip'
            udLower.extra.ox = mouthX
            udLower.extra.oy = mouthY
            udLower.extra.zOffset = 252
            udLower.extra.mouthCurve = 'lower'
            udLower.extra.curvePoints = curvePoints
            udLower.extra.lipScale = mouth.lipScale
            udLower.extra.backdropHex = mouth.backdropHex
            udLower.extra.OMP = true
            udLower.extra.dirty = true
            udLower.extra.main = {
                bgURL = lowerLipURL,
                fgURL = lowerLipMaskURL,
                pURL = '',
                bgHex = '000000ff',
                fgHex = mouth.lipHex,
                pHex = 'ffffff00',
            }
            box2dDrawTextured.makeCached(udLower.extra.main)

            -- Upper lip decal (draws on top)
            local fUpper = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
            local udUpper = fUpper:getUserData()
            udUpper.label = 'upperlip'
            udUpper.extra.ox = mouthX
            udUpper.extra.oy = mouthY
            udUpper.extra.zOffset = 253
            udUpper.extra.mouthCurve = 'upper'
            udUpper.extra.curvePoints = curvePoints
            udUpper.extra.lipScale = mouth.lipScale
            udUpper.extra.OMP = true
            udUpper.extra.dirty = true
            udUpper.extra.main = {
                bgURL = upperLipURL,
                fgURL = upperLipMaskURL,
                pURL = '',
                bgHex = '000000ff',
                fgHex = mouth.lipHex,
                pHex = 'ffffff00',
            }
            box2dDrawTextured.makeCached(udUpper.extra.main)

            -- Create teeth decal (positioned image, clipped to mouth polygon)
            local teeth = face.teeth
            local teethShape = teeth.shape
            if teethShape > 0 then
                local teethURL = 'teeth' .. teethShape .. '.png'
                local teethMaskURL = 'teeth' .. teethShape .. '-mask.png'
                -- Calculate teeth dimensions: scale to mouth width, preserve aspect ratio
                local teethImgPath = 'textures/' .. teethURL
                local teethImg = love.filesystem.getInfo(teethImgPath) and love.graphics.newImage(teethImgPath)
                local teethW = mouthScaleX * 100
                local teethH = teethW * 0.5 * teeth.hMul -- default aspect ratio 2:1
                if teethImg then
                    local imgW, imgH = teethImg:getDimensions()
                    teethH = teethW * (imgH / imgW) * teeth.hMul
                end

                local teethZOffset = teeth.stickOut and 252.5 or 251
                local fTeeth = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                local udTeeth = fTeeth:getUserData()
                udTeeth.label = 'teeth'
                udTeeth.extra.ox = mouthX
                udTeeth.extra.oy = mouthY
                udTeeth.extra.w = teethW
                udTeeth.extra.h = teethH
                udTeeth.extra.zOffset = teethZOffset
                udTeeth.extra.mouthCurve = 'teeth'
                udTeeth.extra.curvePoints = curvePoints
                udTeeth.extra.teethStickOut = teeth.stickOut
                udTeeth.extra.OMP = true
                udTeeth.extra.dirty = true
                udTeeth.extra.main = {
                    bgURL = teethURL,
                    fgURL = teethMaskURL,
                    pURL = '',
                    bgHex = teeth.bgHex,
                    fgHex = teeth.fgHex,
                    pHex = 'ffffff00',
                }
                box2dDrawTextured.makeCached(udTeeth.extra.main)
            end
        end
    end
end

function lib.addTexturesFromInstance2(instance)
    local scale = instance.scale
    for k, v in pairs(instance.dna.parts) do
        if v.appearance then
            --logger:info(k .. ' has appearance')
            local relevant = instance.parts[k]
            if (relevant) then
                --logger:info('relevant real thing found ' .. k)
                --logger:inspect(v.appearance)
                --
                --
                -- maybe i can jst remove all texture fixtures from the body right now?
                -- and then reattahc new ones below.

                local allFixtures = relevant.body:getFixtures()
                for fi = #allFixtures, 1, -1 do -- backwards to safely remove
                    local f = allFixtures[fi]
                    local ud = f:getUserData()
                    if ud then
                        if (subtypes.is(ud, subtypes.CONNECTED_TEXTURE)
                                or subtypes.is(ud, subtypes.TEXFIXTURE)
                                or subtypes.is(ud, subtypes.TRACE_VERTICES)
                                or subtypes.is(ud, subtypes.DECAL)) then
                            fixtures.destroyFixture(f)
                        end
                    end
                end

                for k2, v2 in pairs(v.appearance) do
                    if k2 == 'skin' then
                        addSkinTexture(relevant.body, v, v2, scale)
                    elseif k2 == 'bodyhair' then
                        addBodyhairTexture(relevant.body, k, v, v2, scale)
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        addConnectedTexture(relevant.body, k, v, v2, instance, scale)
                    elseif k2 == 'haircut' then
                        addHaircutTexture(relevant.body, k, v, v2, instance, scale)
                    elseif k2 == 'face' then
                        addFaceDecals(relevant.body, k, v, v2, instance, scale)
                    end
                end
            end
        end
    end
    -- Re-apply zGroupOffset to newly created fixtures (destroyed+recreated above)
    if instance.zGroupOffset then
        for _, part in pairs(instance.parts) do
            if part.body and not part.body:isDestroyed() then
                local bodyFixtures = part.body:getFixtures()
                for fi = 1, #bodyFixtures do
                    local ud = bodyFixtures[fi]:getUserData()
                    if ud and ud.extra then
                        ud.extra.zGroupOffset = instance.zGroupOffset
                    end
                end
            end
        end
    end
end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.

    -- Ensure all DNA sub-tables have their defaults filled in
    D.ensureDefaults(instance.dna.creation, D.creation)
    if not instance.dna.faceMagnitude then instance.dna.faceMagnitude = D.faceMagnitude end
    if not instance.dna.positioners then instance.dna.positioners = {} end
    D.ensureDefaults(instance.dna.positioners, D.positioners)

    -- Resolve topology: flat ordered list of body-part entries with parent links
    local topo = topology.resolve(instance.dna.creation)
    instance.topology = topo
    instance.entryMap = topology.buildEntryMap(topo)
    instance.childrenMap = topology.buildChildrenMap(topo)
    local ordered = topology.buildOrderedNames(topo)

    -- Ensure template-based parts have their DNA filled in
    local torsoSegments = instance.dna.creation.torsoSegments
    for i = 1, torsoSegments do
        local partName = 'torso' .. i
        if not instance.dna.parts[partName] then
            if not instance.dna.parts['torso-segment-template'] then
                error("Missing 'torso-segment-template' in DNA parts")
            end
            instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])
        end
    end

    if not instance.dna.creation.isPotatoHead and instance.dna.creation.neckSegments > 0 then
        for i = 1, instance.dna.creation.neckSegments do
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
    end

    local noseSegments = instance.dna.creation.noseSegments
    if noseSegments > 0 then
        for i = 1, noseSegments do
            local partName = 'nose' .. i
            if not instance.dna.parts[partName] then
                instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['nose-segment-template'])
            end
        end
    end

    for i = 1, #ordered do
        local partName = ordered[i]
        local partData = instance.dna.parts[partName]
        local settings = {
            x = x,
            y = y,
            bodyType = BT.DYNAMIC,
            shapeType = partData.shape,
            shape8URL = partData.shape8URL,
            label = partName,
            density = partData.density or 1,
            radius = (partData.dims.r or 0) * instance.scale,
            width = (partData.dims.w or 0) * instance.scale,
            width2 = (partData.dims.w2 or 0) * instance.scale,
            width3 = (partData.dims.w3 or 0) * instance.scale,
            height = (partData.dims.h or 0) * instance.scale,
            height2 = (partData.dims.h2 or 0) * instance.scale,
            height3 = (partData.dims.h3 or 0) * instance.scale,
            height4 = (partData.dims.h4 or 0) * instance.scale,
            behaviors = partData.behaviors,
        }

        if partData.shape8URL and shape8Dict[partData.shape8URL] then
            local raw = shape8Dict[partData.shape8URL].vertices
            settings.vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * instance.scale,
                (partData.dims.sy or 1) * instance.scale)
        end

        makePart(partName, instance, settings)
        if optionalTorsoAngle and partName == 'torso1' then
            instance.parts['torso1'].body:setAngle(optionalTorsoAngle)
        end
    end


    -- here we will build up the sfixtures we need.
    --logger:info('calling defaultSetupTextures')


    lib.addTexturesFromInstance2(instance)
    --logger:info('calling addTextureFixturesFromInstance')

    -- Assign a unique negative group index to prevent self-collision.
    -- Reuse existing index if this is a rebuild, otherwise allocate a new one.
    if not instance.groupIndex then
        instance.groupIndex = nextGroupIndex
        nextGroupIndex = nextGroupIndex - 1
    end
    -- Assign a unique zGroupOffset so each character's textures occupy a
    -- separate z-range (composedZ = zGroupOffset * 1000 + zOffset).
    if not instance.zGroupOffset then
        instance.zGroupOffset = nextZGroupOffset
        nextZGroupOffset = nextZGroupOffset + 1
    end
    for _, part in pairs(instance.parts) do
        local bodyFixtures = part.body:getFixtures()
        for i = 1, #bodyFixtures do
            bodyFixtures[i]:setGroupIndex(instance.groupIndex)
            local ud = bodyFixtures[i]:getUserData()
            if ud and ud.extra then
                ud.extra.zGroupOffset = instance.zGroupOffset
            end
        end
    end

    mipoRegistry.register(instance)
    return instance
end

function lib.createCharacterFromJustDNA(mydna, x, y, scale)
    local instance = {
        id = uuid.generateID(),
        --templateName = template,
        dna = utils.deepCopy(mydna), -- Copy template data for potential instance modification
        parts = {},                  -- { [partName] = thingObject, ... }
        joints = {},                 -- unused...{ [connectionName] = jointObject, ... }
        --appearanceValues = {},     -- Will hold visual overrides (implement later)
        -- Add other instance-specific state if needed
        textures = {},   -- texture data: simple textures and connected textures
        positioners = {} -- lerp values describing how things are positioned..

    }
    instance.scale = scale or 1
    return lib.createCharacterFromExistingDNA(instance, x, y, false)
end

function lib.createCharacter(template, x, y, scale)
    if dna[template] then
        local instance = {
            id = uuid.generateID(),
            templateName = template,
            dna = utils.deepCopy(dna[template]), -- Copy template data for potential instance modification
            parts = {},              -- { [partName] = thingObject, ... }
            joints = {},             -- unused...{ [connectionName] = jointObject, ... }
            --appearanceValues = {}, -- Will hold visual overrides (implement later)
            -- Add other instance-specific state if needed
            textures = {},   -- texture data: simple textures and connected textures
            positioners = {} -- lerp values describing how things are positioned..

        }
        instance.scale = scale or 1
        return lib.createCharacterFromExistingDNA(instance, x, y, false)
    end
end

return lib
