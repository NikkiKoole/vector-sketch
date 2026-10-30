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
local units = require('src.physics-units')

-- Ears hang on a soft weld: the angle springs back to the stanceAngle, the root stays
-- put. On a hinge (+-11 deg) they lay on a limit all the time, drooping, one up and one
-- down when the head tilted. frequency is Hz at the reference meter (physics-units).
lib.earSpring = { frequency = 3, dampingRatio = 0.25 }
local function earJoint()
    return { type = JT.WELD, frequency = lib.earSpring.frequency, dampingRatio = lib.earSpring.dampingRatio }
end

-- Negative group index counter for character self-collision prevention.
-- Each character gets a unique negative index so its fixtures never collide
-- with each other, but fixtures from different characters (different indices)
-- still collide normally.
-- Both counters restart every session, while characters loaded from a scene keep
-- their saved values, so allocation skips anything already in use (a shared
-- group index means two Mipos pass through each other).
local nextGroupIndex = -1
local nextZGroupOffset = 1

local function allocateGroupIndex()
    local candidate = nextGroupIndex
    if state.physicsWorld then
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            for _, fixture in ipairs(body:getFixtures()) do
                local gi = fixture:getGroupIndex()
                if gi <= candidate then candidate = gi - 1 end
            end
        end
    end
    nextGroupIndex = candidate - 1
    return candidate
end

local function allocateZGroupOffset(instance)
    local candidate = nextZGroupOffset
    for _, other in pairs(mipoRegistry.getAll()) do
        if other ~= instance and other.zGroupOffset and other.zGroupOffset >= candidate then
            candidate = other.zGroupOffset + 1
        end
    end
    nextZGroupOffset = candidate + 1
    return candidate
end

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
-- mouthBackdropHex, mouthUpperLipScale, mouthLowerLipScale, mouthWMul, mouthHMul, mouthY,
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

-- One of the list, at random.
local function pick(list)
    return list[math.ceil(math.random() * #list)]
end

-- a pattern texture as a pURL ('pat/x' -> 'x.png')
local function randomPatternURL()
    return (pick(C.patternTextures):gsub('^pat/', '')) .. '.png'
end

-- A random fill colour, pattern colour and pattern (in that order of draws).
local function randomLook()
    local fgHex = randomHexColor()
    local pHex = randomHexColor()
    return fgHex, pHex, randomPatternURL()
end

-- Randomize torso/head shapes, scales, colors, and clear skin patches.
local function randomizeShapes(instance)
    local urls = C.torsoHeadShapes
    local url = pick(urls)
    local creation = instance.dna.creation
    local count = creation.torsoSegments
    local s = D.randomInRangeWeighted('bodyScale')

    for i = 1, count do
        lib.updatePart('torso' .. i,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
    end

    local headScale = D.randomInRangeWeighted('bodyScale')
    local headUrl = pick(urls)
    lib.updatePart('head',
        { shape8URL = headUrl .. '.png', sy = headScale * (math.random() < 0.5 and -1 or 1), sx = headScale },
        instance)

    -- Random colors + pattern — shared across all torso segments + head
    local fgHex, pHex, pURL = randomLook()
    local look = { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL }
    for i = 1, count do
        for _, patch in ipairs({ 'main', 'patch1', 'patch2' }) do
            lib.updateSkinOfPart(instance, 'torso' .. i, look, patch)
        end
    end
    lib.updateSkinOfPart(instance, 'head', look)

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

-- Lengths + visual fatness (wmul) for arms and legs. Symmetric L/R, upper/lower share.
-- wmul lives on the upper limb's connected-skin (covers the whole chain via getLimbRoot).
local function randomizeLimbLengths(instance)
    local legH = D.randomInRangeWeighted('legH')
    local armH = D.randomInRangeWeighted('armH')
    local armWMul = D.randomInRangeWeighted('limbWMul')
    local legWMul = D.randomInRangeWeighted('limbWMul')
    for _, pname in ipairs({ 'luleg', 'ruleg', 'llleg', 'rlleg' }) do
        lib.updatePart(pname, { h = legH }, instance)
    end
    for _, pname in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm' }) do
        lib.updatePart(pname, { h = armH }, instance)
    end
    for _, p in ipairs({ 'luarm', 'ruarm' }) do
        if instance.dna.parts[p] and instance.dna.parts[p].appearance
            and instance.dna.parts[p].appearance['connected-skin'] then
            lib.updateConnectedAppearance(instance, p, 'connected-skin', { wmul = armWMul })
        end
    end
    for _, p in ipairs({ 'luleg', 'ruleg' }) do
        if instance.dna.parts[p] and instance.dna.parts[p].appearance
            and instance.dna.parts[p].appearance['connected-skin'] then
            lib.updateConnectedAppearance(instance, p, 'connected-skin', { wmul = legWMul })
        end
    end
end

-- Randomize ear shapes, scales, and colors.
local function randomizeEars(instance)
    local earUrl = pick(C.earShapes)
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

    local fgHex, pHex, pURL = randomLook()
    for _, ear in ipairs({ 'lear', 'rear' }) do
        lib.updateSkinOfPart(instance, ear, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
    end
end

-- Randomize feet/hand shapes, scales, and colors.
local function randomizeFeetAndHands(instance)
    local fhUrls = C.handShapes
    local fUrl = pick(fhUrls)
    local fS = D.randomInRangeWeighted('feetScale')

    lib.updatePart('lfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = fS },
        instance)
    lib.updatePart('rfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = -fS },
        instance)

    local handScale = D.randomInRangeWeighted('handScale')
    local handUrl = pick(fhUrls)
    lib.updatePart('lhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = handScale },
        instance)
    lib.updatePart('rhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = -handScale },
        instance)

    for _, pair in ipairs({ { 'lfoot', 'rfoot' }, { 'lhand', 'rhand' } }) do
        local fgHex, pHex, pURL = randomLook()
        for _, part in ipairs(pair) do
            lib.updateSkinOfPart(instance, part, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        end
    end
end

-- Randomize haircut, bodyhair, connected-skin, and connected-hair textures.
-- hairColor: shared hex color for all hair-related parts.
-- opts: optional overrides table. opts.limbSkin = url string to lock limb skin texture.
local function randomizeTextures(instance, hairColor, opts)
    local count = instance.dna.creation.torsoSegments

    -- Random haircut (update both head and torso1 since isPotatoHead flip changes owner)
    local hcUrl = pick(C.haircutTextures)
    local hcBgURL = hcUrl .. '.png'
    local hcFgURL = C.hairsWithMask[hcBgURL] and hcBgURL:gsub('%.png', '-mask.png') or ''
    local hcValues = {
        bgURL = hcBgURL, fgURL = hcFgURL,
        bgHex = hairColor, width = D.randomInRangeWeighted('haircutWidth'),
    }
    lib.updateHaircutOfPart(instance, 'head', hcValues)
    lib.updateHaircutOfPart(instance, 'torso1', hcValues)

    -- Random bodyhair (shared hairColor for bgHex, independent fgHex/pHex for variety).
    -- Head gets the same bodyhair as torsos so outline/colors are consistent across the body.
    local bhUrl = pick(C.bodyhairTextures)
    local bhFgHex, bhPHex, bhPURL = randomLook()
    local bhValues = { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png',
                       bgHex = hairColor, fgHex = bhFgHex, pHex = bhPHex, pURL = bhPURL }
    lib.updateBodyhairOfPart(instance, 'head', bhValues)
    for i = 1, count do
        lib.updateBodyhairOfPart(instance, 'torso' .. i, bhValues)
    end

    -- arm skin, then leg skin; torsos take the leg's for continuity
    local torsos = {}
    for i = 1, count do torsos[i] = 'torso' .. i end
    local limbs = { { 'luarm', 'ruarm' }, { 'luleg', 'ruleg' } }
    local skin
    for _, parts in ipairs(limbs) do
        local url = (opts and opts.limbSkin) or pick(C.limbSkinTextures)
        local fgHex, pHex, pURL = randomLook()
        skin = { bgURL = url .. '.png', fgURL = url .. '-mask.png', fgHex = fgHex, pHex = pHex, pURL = pURL }
        for _, part in ipairs(parts) do lib.updateConnectedAppearance(instance, part, 'connected-skin', skin) end
    end
    for _, part in ipairs(torsos) do lib.updateConnectedAppearance(instance, part, 'connected-skin', skin) end

    -- limb hair in the hair colour, the same way
    local hair
    for _, parts in ipairs(limbs) do
        hair = { bgURL = pick(C.limbHairTextures) .. '.png', bgHex = hairColor }
        for _, part in ipairs(parts) do lib.updateConnectedAppearance(instance, part, 'connected-hair', hair) end
    end
    for _, part in ipairs(torsos) do lib.updateConnectedAppearance(instance, part, 'connected-hair', hair) end
end

-- Randomize face features: eyes, pupils, brows, nose, mouth, and teeth.
-- hairColor: shared hex color used for brow color.
local function randomizeFace(instance, hairColor, opts)
    local randomEyeY = D.randomInRangeWeighted('eyeY')
    local randomMouthY = randomEyeY + D.randomInRangeWeighted('mouthYOffset')
    local eyeScale = D.randomInRangeWeighted('eyeWMul')
    local pupilScale = D.randomInRangeWeighted('pupilWMul')
    local uniform = opts and opts.uniformEyeScale
    local allowedPupils = opts and opts.allowedPupilShapes
    local pupilShapeIdx = allowedPupils
        and pick(allowedPupils)
        or math.ceil(math.random() * #C.pupilShapes)
    local faceValues = {
        eyeShape = math.ceil(math.random() * #C.eyeShapes),
        pupilShape = pupilShapeIdx,
        eyeX = D.randomInRangeWeighted('eyeX'),
        eyeY = randomEyeY,
        eyeWMul = eyeScale,
        eyeHMul = uniform and eyeScale or D.randomInRangeWeighted('eyeHMul'),
        pupilWMul = pupilScale,
        pupilHMul = uniform and pupilScale or D.randomInRangeWeighted('pupilHMul'),
        eyeBgHex = '000000ff',
        eyeFgHex = 'ffffffff',
        pupilBgHex = '000000ff',
        mouthShape = mouthShapes.indexOf(pick(mouthShapes.restShapes)),
        mouthUpperLipShape = math.ceil(math.random() * #C.upperLipShapes),
        mouthLowerLipShape = math.ceil(math.random() * #C.lowerLipShapes),
        mouthLipHex = 'cc5555ff',
        mouthBackdropHex = '00000099',
        mouthUpperLipScale = D.randomInRangeWeighted('mouthUpperLipScale'),
        mouthLowerLipScale = D.randomInRangeWeighted('mouthLowerLipScale'),
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
        teethWMul = D.randomInRangeWeighted('teethWMul'),
        teethHMul = D.randomInRangeWeighted('teethHMul'),
        teethStickOut = math.random() < D.randomRanges.teethStickOut,
        teethBgHex = '000000ff',
        teethFgHex = 'eeeeeeff',
    }
    lib.updateFaceOfPart(instance, 'head', faceValues)
    lib.updateFaceOfPart(instance, 'torso1', faceValues)
end

-- Randomize all visual aspects of a character instance.
-- Design rule: a hanging hand never reaches the floor.
--   arm (shoulder->elbow + elbow->wrist + hand past the wrist)
--   <= torso (shoulder->hip) + leg (hip->knee + knee->ankle)
-- Measured on the built bodies (joint anchors), so body scale, hand image and
-- pose don't matter. Returns arm length, limit (nil when parts are missing).
local function jointAnchor(instance, parentName, childName)
    local parent, child = instance.parts[parentName], instance.parts[childName]
    if not (parent and child and parent.body and child.body) then return nil end
    local joint = mipoRegistry.jointBetween(parent.body, child.body)
    if joint then return joint:getAnchors() end
    return nil
end

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function lib.armReach(instance)
    local sx, sy = jointAnchor(instance, 'torso1', 'luarm')
    local ex, ey = jointAnchor(instance, 'luarm', 'llarm')
    local wx, wy = jointAnchor(instance, 'llarm', 'lhand')
    local hx, hy = jointAnchor(instance, 'torso1', 'luleg')
    local kx, ky = jointAnchor(instance, 'luleg', 'llleg')
    local ax, ay = jointAnchor(instance, 'llleg', 'lfoot')
    if not (sx and ex and wx and hx and kx and ax) then return nil end
    local hand = 0
    local handBody = instance.parts.lhand.body
    for _, fixture in ipairs(handBody:getFixtures()) do
        local shape = fixture:getShape()
        if not fixture:isSensor() and shape.getPoints then
            local pts = { handBody:getWorldPoints(shape:getPoints()) }
            for i = 1, #pts, 2 do hand = math.max(hand, dist(wx, wy, pts[i], pts[i + 1])) end
        end
    end
    local segments = dist(sx, sy, ex, ey) + dist(ex, ey, wx, wy)
    local limit = dist(sx, sy, hx, hy) + dist(hx, hy, kx, ky) + dist(kx, ky, ax, ay)
    return segments + hand, limit, segments, hand
end

-- Shorten upper arm + forearm (DNA h) so the arm fits the rule; when the hand
-- alone is too big for that (arms would drop below 40%), shrink the hand too.
-- Measured again after each pass since the hand's reach isn't linear in scale.
lib.minArmFactor = 0.4

function lib.limitArmReach(instance)
    local changed = false
    for _ = 1, 3 do
        local arm, limit, segments, hand = lib.armReach(instance)
        if not arm or arm <= limit + 1 or segments <= 0 then return changed end
        local factor = (limit - hand) / segments
        if factor < lib.minArmFactor then
            factor = lib.minArmFactor
            local handFactor = math.max(0.3, (limit - segments * factor) / hand)
            for _, pname in ipairs({ 'lhand', 'rhand' }) do
                local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
                if dims then
                    lib.updatePart(pname, { sx = (dims.sx or 1) * handFactor, sy = (dims.sy or 1) * handFactor },
                        instance)
                end
            end
        end
        for _, pname in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm' }) do
            local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
            if dims and dims.h then lib.updatePart(pname, { h = dims.h * factor }, instance) end
        end
        changed = true
    end
    return changed
end

-- Everything at random; textureOpts / faceOpts narrow it down (see randomizeMipoConstrained).
local function randomizeAll(instance, textureOpts, faceOpts)
    if not instance then return end
    local hairColor = utils.randomHexColor() -- haircut, bodyhair, limb hair and brows share it
    randomizeShapes(instance)
    randomizeLimbLengths(instance)
    randomizeEars(instance)
    randomizeFeetAndHands(instance)
    randomizeTextures(instance, hairColor, textureOpts)
    randomizeFace(instance, hairColor, faceOpts)
    -- no physics nose: the randomized nose is drawn on the face
    lib.rebuildFromCreation(instance, { isPotatoHead = not instance.dna.creation.isPotatoHead, noseSegments = 0 })
    lib.limitArmReach(instance)
    lib.addTexturesFromInstance2(instance)
end

function lib.randomizeMipo(instance)
    randomizeAll(instance)
end

-- Coherent but varied (Bathhouse Mipos): limb skin locked to leg1, round-ish eyes, calm pupils.
-- More constraints go here as the Mipo DNA language grows.
function lib.randomizeMipoConstrained(instance)
    randomizeAll(instance, { limbSkin = C.limbSkinTextures[1] },
        { uniformEyeScale = true, allowedPupilShapes = { 1, 2, 3, 6, 7, 8 } })
end

-- Randomize a single part (or its symmetric group) by name.
-- ears/feet/hands always randomize both sides together.
-- arms/legs randomize all connected-skin/hair for that limb group.
function lib.randomizePart(instance, partName)
    if not instance or not partName then return end
    local hairColor = utils.randomHexColor()

    if partName == 'head' then
        local url = pick(C.torsoHeadShapes)
        local s = D.randomInRangeWeighted('bodyScale')
        lib.updatePart('head',
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
        local fgHex, pHex, pURL = randomLook()
        lib.updateSkinOfPart(instance, 'head', { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        local hcUrl = pick(C.haircutTextures)
        local hcBgURL = hcUrl .. '.png'
        local hcFgURL = C.hairsWithMask[hcBgURL] and hcBgURL:gsub('%.png', '-mask.png') or ''
        lib.updateHaircutOfPart(instance, 'head',
            { bgURL = hcBgURL, fgURL = hcFgURL,
              bgHex = hairColor, width = D.randomInRangeWeighted('haircutWidth') })
        randomizeFace(instance, hairColor)

    elseif partName:match('^torso') then
        local url = pick(C.torsoHeadShapes)
        local s = D.randomInRangeWeighted('bodyScale')
        lib.updatePart(partName,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
        local fgHex, pHex, pURL = randomLook()
        lib.updateSkinOfPart(instance, partName, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        local bhUrl = pick(C.bodyhairTextures)
        local bhFgHex, bhPHex, bhPURL = randomLook()
        lib.updateBodyhairOfPart(instance, partName, { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png',
            bgHex = hairColor, fgHex = bhFgHex, pHex = bhPHex, pURL = bhPURL })

    elseif partName == 'lear' or partName == 'rear' then
        randomizeEars(instance)

    elseif partName:match('foot$') or partName:match('hand$') then
        -- both feet (or both hands): a shape and a size, mirrored, and one look
        local kind = partName:match('foot$') and 'foot' or 'hand'
        local url = pick(C.handShapes)
        local size = D.randomInRangeWeighted(kind == 'foot' and 'feetScale' or 'handScale')
        lib.updatePart('l' .. kind, { shape8URL = url .. '.png', sy = size, sx = size }, instance)
        lib.updatePart('r' .. kind, { shape8URL = url .. '.png', sy = size, sx = -size }, instance)
        local fgHex, pHex, pURL = randomLook()
        for _, p in ipairs({ 'l' .. kind, 'r' .. kind }) do
            lib.updateSkinOfPart(instance, p, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        end

    elseif partName:match('arm') or partName:match('leg') then
        -- both arms (or both legs): skin and hair along them
        local kind = partName:match('arm') and 'arm' or 'leg'
        local parts = { 'lu' .. kind, 'ru' .. kind }
        local skinUrl = pick(C.limbSkinTextures)
        local fgHex, pHex, pURL = randomLook()
        for _, p in ipairs(parts) do
            lib.updateConnectedAppearance(instance, p, 'connected-skin',
                { bgURL = skinUrl .. '.png', fgURL = skinUrl .. '-mask.png',
                  fgHex = fgHex, pHex = pHex, pURL = pURL })
        end
        local hairUrl = pick(C.limbHairTextures)
        for _, p in ipairs(parts) do
            lib.updateConnectedAppearance(instance, p, 'connected-hair',
                { bgURL = hairUrl .. '.png', bgHex = hairColor })
        end
    end

    lib.addTexturesFromInstance2(instance)
end

-- Jitter all size/proportion values of a mipo while keeping shapes and colors identical.
-- Useful for generating genetic variants of a character.
local MUTATE_JITTER = 0.35  -- fraction of global range applied as ± offset

local function jitterInRange(value, key)
    local r = D.randomRanges[key]
    if not r then return value end
    local delta = (math.random() * 2 - 1) * (r.max - r.min) * MUTATE_JITTER
    return math.max(r.min, math.min(r.max, value + delta))
end

-- Jitter relative to the current value (for dims without global ranges, e.g. limb h).
local function jitterRelative(value, factor)
    local delta = (math.random() * 2 - 1) * value * factor
    return math.max(value * 0.3, value + delta)
end

function lib.mutateSizes(instance)
    if not instance then return end
    local creation = instance.dna.creation

    -- Body/head shape scales (preserve flip sign on sy)
    for i = 1, creation.torsoSegments do
        local dims = instance.dna.parts['torso' .. i] and instance.dna.parts['torso' .. i].dims
        if dims then
            local s = jitterInRange(math.abs(dims.sx or 1), 'bodyScale')
            lib.updatePart('torso' .. i, { sx = s, sy = s * (dims.sy < 0 and -1 or 1) }, instance)
        end
    end
    local hd = instance.dna.parts.head and instance.dna.parts.head.dims
    if hd then
        local s = jitterInRange(math.abs(hd.sx or 1), 'bodyScale')
        lib.updatePart('head', { sx = s, sy = s * ((hd.sy or 1) < 0 and -1 or 1) }, instance)
    end

    -- Ears (always symmetric pair)
    local ed = instance.dna.parts.lear and instance.dna.parts.lear.dims
    if ed then
        local esx = jitterInRange(math.abs(ed.sx or 1), 'earScale')
        local esy = jitterInRange(math.abs(ed.sy or 1), 'earScale')
        lib.updatePart('lear', { sx = -esx, sy = esy }, instance)
        lib.updatePart('rear', { sx =  esx, sy = esy }, instance)
    end

    -- Feet
    local ffd = instance.dna.parts.lfoot and instance.dna.parts.lfoot.dims
    if ffd then
        local fS = jitterInRange(math.abs(ffd.sx or 1), 'feetScale')
        lib.updatePart('lfoot', { sx =  fS, sy = fS }, instance)
        lib.updatePart('rfoot', { sx = -fS, sy = fS }, instance)
    end

    -- Hands
    local fhd = instance.dna.parts.lhand and instance.dna.parts.lhand.dims
    if fhd then
        local hS = jitterInRange(math.abs(fhd.sx or 1), 'handScale')
        lib.updatePart('lhand', { sx =  hS, sy = hS }, instance)
        lib.updatePart('rhand', { sx = -hS, sy = hS }, instance)
    end

    -- Face sizes
    local faceOwner = creation.isPotatoHead and 'torso1' or 'head'
    local fp = instance.dna.parts[faceOwner]
    if fp and fp.appearance and fp.appearance.face then
        local face = fp.appearance.face
        lib.updateFaceOfPart(instance, faceOwner, {
            eyeWMul          = jitterInRange(face.eye.wMul,                          'eyeWMul'),
            eyeHMul          = jitterInRange(face.eye.hMul,                          'eyeHMul'),
            pupilWMul        = jitterInRange(face.pupil.wMul,                        'pupilWMul'),
            pupilHMul        = jitterInRange(face.pupil.hMul,                        'pupilHMul'),
            browWMul         = jitterInRange(face.brow.wMul,                         'browWMul'),
            browHMul         = jitterInRange(face.brow.hMul,                         'browHMul'),
            noseWMul         = jitterInRange(face.nose.wMul,                         'noseWMul'),
            noseHMul         = jitterInRange(face.nose.hMul,                         'noseHMul'),
            mouthWMul        = jitterInRange(face.mouth.wMul,                        'mouthWMul'),
            mouthHMul        = jitterInRange(face.mouth.hMul,                        'mouthHMul'),
            mouthUpperLipScale = jitterInRange(face.mouth.upperLipScale or 0.15,     'mouthUpperLipScale'),
            mouthLowerLipScale = jitterInRange(face.mouth.lowerLipScale or 0.2,      'mouthLowerLipScale'),
        })
    end

    -- Limb lengths (arms and legs vary independently, left/right always symmetric)
    -- Floor at 60 to prevent capsule polygons from going degenerate under Box2D
    local legH = nil
    local armH = nil
    for _, pname in ipairs({'luleg', 'ruleg', 'llleg', 'rlleg'}) do
        local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
        if dims and dims.h then
            if not legH then legH = math.max(60, math.min(800, jitterRelative(dims.h, MUTATE_JITTER))) end
            lib.updatePart(pname, { h = legH }, instance)
        end
    end
    for _, pname in ipairs({'luarm', 'ruarm', 'llarm', 'rlarm'}) do
        local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
        if dims and dims.h then
            if not armH then armH = math.max(60, math.min(800, jitterRelative(dims.h, MUTATE_JITTER))) end
            lib.updatePart(pname, { h = armH }, instance)
        end
    end

    lib.addTexturesFromInstance2(instance)
end

-- Torso layers: above the ears (190), below the head (200) with its bodyhair too. Both
-- used to be 200 (bodyhair 210), and same-z layers draw in fixture-id order: P4re5's
-- torso bodyhair covered its head. Saved Mipos are moved over by migrateDNA.
local TORSO_SKIN_Z = 192
local TORSO_HAIR_ABOVE_SKIN = 5

local shape8Dict = require('src.shape8-dict')


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
                dims = { w = 40, h = 40, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 32, up = math.pi / 32 } }
            },
            ['nose-single-template'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 350, -- physics nose: in front of body/legs, behind arms (402) and hands (500)
                        main = initBlock('shapeA2'),
                    },
                },
                dims = { w = 40, h = 40, w2 = 4, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',
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
                        zOffset = 192, -- TORSO_SKIN_Z
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
                dims = { w = 80, h = 400, w2 = 4 },
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
                dims = { w = 80, h = 400, w2 = 4 },
                shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 400, w2 = 4 }, shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 400, w2 = 4 }, shape = ST.CAPSULE,
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
                j = earJoint(),
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
                j = earJoint(),
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


-- Shoulders and elbows: range relative to the parent part (0 = hanging straight
-- in line, + = toward the Mipo's left), converted with the joint's own reference
-- angle. The DNA shoulder limits were relative to a T-pose (reference +-90),
-- which only allowed the upper half: arms rested horizontal and tipped over to
-- the other side. Elbows had no limits, so forearms crossed under the body.
lib.armRange = {
    luarm = { 0, 180 }, ruarm = { -180, 0 },   -- shoulder: from hanging down, out, up
    llarm = { -10, 150 }, rlarm = { -150, 10 }, -- elbow: bends outward/up only
} -- degrees

-- Legs, feet, hands, ears: the DNA limits are meant relative to the rest pose
-- (0 = in line with the parent; ears at their stanceAngle), but a joint's limits
-- count from its reference angle, which is whatever angle the part had when the
-- joint was made. Rebuilt while bent, 'upright' fell outside the hip limits and
-- feet got locked upside down (ankle references of 179 / -111 deg); keep-angle
-- then fought the limits at full spin (shaking, noise). Convert the DNA limits
-- with the actual reference angle.
-- A foot's rest pose is flat: it is built turned a quarter turn from its shin
-- (character-topology.lua angleOffset). Counting the ankle range from 'in line
-- with the shin' (0) centred it on a foot pointing straight down: Mipos stood
-- on the tips of their feet.
local footRest = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }

-- Not only legs and feet: every part with DNA limits (torso segments, spine bands, neck,
-- head). A scene saved before joints kept their reference angle came back with each joint
-- counting from the pose it was saved in: a spine saved mid-sway was held crooked by its
-- motor and the Mipo hopped forever; necks and heads were limited off-centre.
local function applyLegLimits(instance, joint, partName)
    if not joint or joint:isDestroyed() or joint:getType() ~= 'revolute' then return end
    local partDNA = instance.dna.parts[partName]
    local limits = partDNA and partDNA.j and partDNA.j.limits
    if not (limits and limits.low and limits.up) then return end
    local rest = footRest[partName] or partDNA.stanceAngle or 0
    local ref = joint:getReferenceAngle()
    joint:setLimits(rest + limits.low - ref, rest + limits.up - ref)
    joint:setLimitsEnabled(true)
end

local function applyShoulderLimits(joint, partName)
    local range = lib.armRange[partName]
    if not range or not joint or joint:isDestroyed() or joint:getType() ~= 'revolute' then return end
    local ref = joint:getReferenceAngle()
    joint:setLimits(math.rad(range[1]) - ref, math.rad(range[2]) - ref)
    joint:setLimitsEnabled(true)
end

-- Feet grip and don't bounce. With LÖVE's default friction (0.2) on both feet
-- and floor, Mipos stood on ice and slid into a split.
lib.footFriction = 1.0 -- spec/standing_spec.lua, 3 x 12 random Mipos: 1.0 -> 6/36 unsettled,
                       -- 0.45 -> 12/36 (a single 12-run said otherwise: physics here is chaotic)
lib.footRestitution = 0

local function applyFootMaterial(thing, partName)
    if partName ~= 'lfoot' and partName ~= 'rfoot' then return end
    if not thing or not thing.body or thing.body:isDestroyed() then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:isSensor() then
            fixture:setFriction(lib.footFriction)
            fixture:setRestitution(lib.footRestitution)
        end
    end
end

-- How makePart builds a part from its DNA at this scale.
local function partSettings(partName, partData, scale, x, y)
    local settings = {
        x = x,
        y = y,
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
        local raw = topology.shape8Vertices(partData) -- a spine band, or the whole shape
        settings.vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * scale,
            (partData.dims.sy or 1) * scale)
    end
    return settings
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
        applyFootMaterial(thing, partName)

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
                frequency = jointData.frequency and units.rate(jointData.frequency),
                dampingRatio = jointData.dampingRatio,
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
            applyShoulderLimits(joint, partName)
            applyLegLimits(instance, joint, partName)
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
    -- a spine's bands all take torso1's shape (rebuilt below as its children)
    if partName:find('^torso%d') then lib.applySpine(instance) end

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

    local children = instance.childrenMap[partName] or {}
    makePart(partName, instance, partSettings(partName, partData, instance.scale or 1, oldPosX, oldPosY))

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
    lib.balanceMasses(instance)
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

-- Where the whole torso picture sits on a spine band's body (its y offset): the band's
-- outline is centred on the band, the picture on the whole shape. 0 for anything else.
local function spinePictureOffset(partData, scale)
    local band = partData.spineBand
    if not band then return 0 end
    local _, middle = topology.spineBand(shape8Dict[partData.shape8URL].vertices, band[1], band[2],
        (partData.dims.sy or 1) < 0)
    return -middle * (partData.dims.sy or 1) * scale
end

local function addSkinTexture(body, partData, skinData, scale)
    local _, _, w, h = getCenterAndDimensions(body)
    local offsetY = spinePictureOffset(partData, scale)

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
        fixture = fixtures.createSFixture(body, 0, offsetY,
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
    -- Layer bodyhair above skin (skin zOffset is 200 for the head, 192 for torsos: see TORSO_SKIN_Z)
    local skinZ = (partData.appearance and partData.appearance['skin'] and partData.appearance['skin'].zOffset) or 200
    ud.extra.zOffset = skinZ + (partName:find('^torso%d') and TORSO_HAIR_ABOVE_SKIN or 10)
    ud.extra.dirty = true
    ud.extra.main = utils.deepCopy(bodyhairData.main)

    local raw = shape8Dict[partData.shape8URL].vertices
    local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor * scale,
        (partData.dims.sy or 1) * growfactor * scale)
    local offsetY = spinePictureOffset(partData, scale) -- the whole torso's hair, on a spine's lowest band
    for i = 2, #vertices, 2 do vertices[i] = vertices[i] + offsetY end
    local newVertices = cyclicShift(vertices, 2)
    if partData.dims.sy < 0 then
        newVertices = cyclicShift(newVertices, 8)
    end

    ud.extra.vertices = newVertices
    ud.extra.vertexCount = #vertices / 2
end

local function addConnectedTexture(body, partName, _partData, connData, instance, scale)
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

    -- Add terminal anchor at the tip of the last nose segment
    if partName == 'nose1' and noseSegments > 0 then
        local lastNose = 'nose' .. noseSegments
        local lastBody = instance.parts[lastNose] and instance.parts[lastNose].body
        if lastBody then
            local lastDims = instance.dna.parts[lastNose].dims
            local tipY = (lastDims.h / 2) * scale
            local tipAnchor = fixtures.createSFixture(lastBody, 0, tipY, subtypes.ANCHOR,
                { radius = 5 * scale })
            if tipAnchor then
                local anchorId = tipAnchor:getUserData().id
                ud.extra.nodes[#ud.extra.nodes + 1] = { id = anchorId, type = NT.ANCHOR }
            end
        end
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

-- Every fixture of the Mipo in its collision group (setGroup; a negative group never
-- collides with itself) and its sfixtures in its z-range (zGroupOffset * 1000 + zOffset).
local function applyGroupAndZ(instance, setGroup)
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                if setGroup and instance.groupIndex then fixture:setGroupIndex(instance.groupIndex) end
                local ud = fixture:getUserData()
                if instance.zGroupOffset and ud and ud.extra then ud.extra.zGroupOffset = instance.zGroupOffset end
            end
        end
    end
end

-- Where the face's decals sit, front to back (zOffset, within the Mipo's z group).
local FACE_Z = { eye = 250, pupil = 251, teeth = 251, lowerLip = 252, brow = 252, teethOut = 252.5,
    upperLip = 253, nose = 254 } -- nose above the mouth, below the arms (402); was 490

-- An outline + mask (+ no pattern) colour block for a decal (extra.main).
local function omp(bgURL, fgURL, bgHex, fgHex)
    return { bgURL = bgURL, fgURL = fgURL, pURL = '', bgHex = bgHex, fgHex = fgHex, pHex = 'ffffff00' }
end

-- '<name>-mask.png' when that texture exists, else ''.
local function maskOf(name)
    local mask = name .. '-mask.png'
    return love.filesystem.getInfo('textures/' .. mask) and mask or ''
end

-- A decal on the body: label, its extra fields; a colour block (main) is composed when drawn.
local function addDecal(body, label, extra)
    local ud = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 }):getUserData()
    ud.label = label
    for k, v in pairs(extra) do ud.extra[k] = v end
    if extra.main then
        ud.extra.dirty = true
        box2dDrawTextured.makeCached(ud.extra.main)
    end
    return ud
end

-- Masked: a colour block; no mask: the outline picture in one colour.
local function maskedOrPlain(extra, name, bgHex, fgHex)
    local mask = maskOf(name)
    if mask ~= '' then
        extra.OMP = true
        extra.main = omp(name .. '.png', mask, bgHex, fgHex)
    else
        extra.OMP = false
        extra.bgURL = name .. '.png'
        extra.bgHex = bgHex
    end
    return extra
end

local imageSizes = {} -- [path] = { w, h }: a picture's size, without loading it on every rebuild
local function imageSize(path)
    if imageSizes[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        imageSizes[path] = ok and { img:getDimensions() } or false
        if ok then img:release() end
    end
    return imageSizes[path] or nil
end

local function placeEyes(body, face, box)
    local eye, pupil, eyeR = face.eye, face.pupil, face.positioners.eye.r
    local eyeW, eyeH = box.headW * 0.25 * box.fm * eye.wMul, box.headH * 0.25 * box.fm * eye.hMul
    local eyeName = 'eye' .. eye.shape
    for _, side in ipairs({ { x = box.leftEyeX, label = 'l', mirror = true, rot = -eyeR },
                            { x = box.rightEyeX, label = 'r', mirror = false, rot = eyeR } }) do
        addDecal(body, side.label .. 'eye', {
            ox = side.x, oy = box.eyeY, w = eyeW, h = eyeH, mirror = side.mirror, rot = side.rot,
            zOffset = FACE_Z.eye, isEye = true, OMP = true,
            main = omp(eyeName .. '.png', eyeName .. '-mask.png', eye.bgHex, eye.fgHex),
        })
        -- a pupil with a mask is two colours, without one a tinted outline
        addDecal(body, side.label .. 'pupil', maskedOrPlain({
            ox = side.x, oy = box.eyeY, w = eyeW * pupil.wMul, h = eyeH * pupil.hMul, mirror = side.mirror,
            zOffset = FACE_Z.pupil, isEye = true, eyeW = eyeW, eyeH = eyeH, eyeMaskURL = eyeName .. '-mask.png',
            eyeMirror = side.mirror, eyeRot = side.rot, lookAtMouse = eye.lookAtMouse,
        }, 'pupil' .. pupil.shape, pupil.bgHex, pupil.fgHex))
    end
end

local function placeBrows(body, face, box)
    local brow = face.brow
    for _, side in ipairs({ { x = box.leftEyeX, label = 'lbrow', mirror = false },
                            { x = box.rightEyeX, label = 'rbrow', mirror = true } }) do
        addDecal(body, side.label, {
            ox = side.x, oy = lerp(box.topY, box.botY, face.positioners.brow.y),
            w = box.headW * 0.2 * brow.wMul * box.fm, h = box.headH * 0.1 * brow.hMul * box.fm,
            zOffset = FACE_Z.brow, browCurve = true, browBend = brow.bend, browMirror = side.mirror,
            bgURL = 'brow' .. brow.shape .. '.png', bgHex = brow.bgHex,
        })
    end
end

local function placeNose(body, face, box)
    local nose = face.nose
    if nose.shape <= 0 then return end
    addDecal(body, 'nose', maskedOrPlain({
        ox = (box.leftX + box.rightX) / 2, oy = lerp(box.topY, box.botY, face.positioners.nose.y),
        w = box.headW * 0.15 * nose.wMul * box.fm, h = box.headH * 0.15 * nose.hMul * box.fm,
        zOffset = FACE_Z.nose,
    }, 'nose' .. nose.shape, nose.bgHex, nose.fgHex))
end

-- Lower lip (draws first, stencils the inside), upper lip, and teeth clipped to the mouth.
local function placeMouth(body, face, box)
    local mouth = face.mouth
    local mouthShape = mouthShapes.normalized[mouth.shape]
    if not mouthShape then return end
    local mouthX, mouthY = (box.leftX + box.rightX) / 2, lerp(box.topY, box.botY, face.positioners.mouth.y)
    -- about 40% of the head wide (wMul/hMul adjust)
    local scaleX = (box.headW * 0.004) * mouth.wMul * box.fm
    local scaleY = (box.headH * 0.004) * mouth.hMul * box.fm
    local curvePoints = {} -- the 8 shape points scaled and moved onto the face
    for ci = 1, 16, 2 do
        curvePoints[ci] = mouthShape.points[ci] * scaleX + mouthX
        curvePoints[ci + 1] = mouthShape.points[ci + 1] * scaleY + mouthY
    end
    local function mouthPart(curve, z)
        return { ox = mouthX, oy = mouthY, zOffset = z, mouthCurve = curve, curvePoints = curvePoints,
            mouthScaleX = scaleX, mouthScaleY = scaleY, mouthX = mouthX, mouthY = mouthY, OMP = true }
    end
    local lower = mouthPart('lower', FACE_Z.lowerLip)
    lower.lipScale = mouth.lowerLipScale or mouth.lipScale or 0.2
    lower.backdropHex = mouth.backdropHex
    lower.main = omp('lowerlip' .. mouth.lowerLipShape .. '.png', 'lowerlip' .. mouth.lowerLipShape .. '-mask.png',
        '000000ff', mouth.lipHex)
    addDecal(body, 'lowerlip', lower)
    local upper = mouthPart('upper', FACE_Z.upperLip)
    upper.lipScale = mouth.upperLipScale or mouth.lipScale or 0.15
    upper.main = omp('upperlip' .. mouth.upperLipShape .. '.png', 'upperlip' .. mouth.upperLipShape .. '-mask.png',
        '000000ff', mouth.lipHex)
    addDecal(body, 'upperlip', upper)

    local teeth = face.teeth
    if teeth.shape <= 0 then return end
    local teethName = 'teeth' .. teeth.shape
    local teethW = scaleX * 100 * (teeth.wMul or 1)
    local size = imageSize('textures/' .. teethName .. '.png')
    local aspect = size and (size[2] / size[1]) or 0.5 -- 2:1 when the picture is missing
    local part = mouthPart('teeth', teeth.stickOut and FACE_Z.teethOut or FACE_Z.teeth)
    part.w, part.h = teethW, teethW * aspect * teeth.hMul
    part.teethStickOut = teeth.stickOut
    part.main = omp(teethName .. '.png', teethName .. '-mask.png', teeth.bgHex, teeth.fgHex)
    addDecal(body, 'teeth', part)
end

-- Eyes, pupils, brows, nose and mouth, on the head (or torso1 on a potato head), placed by
-- the face's positioners within the head shape's box.
local function addFaceDecals(body, partName, partData, faceData, instance, scale)
    local faceOwner = instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    if partName ~= faceOwner or not (partData.shape8URL and shape8Dict[partData.shape8URL]) then return end
    D.ensureDefaults(faceData, D.face)

    local verts = makeTransformedVertices(shape8Dict[partData.shape8URL].vertices,
        (partData.dims.sx or 1) * scale, (partData.dims.sy or 1) * scale)
    -- a spine's torso1 (potato head): the face is on the whole torso, like its picture
    local offsetY = spinePictureOffset(partData, scale)
    for i = 2, #verts, 2 do verts[i] = verts[i] + offsetY end

    -- 8 vertices: 1 top, 3 right, 5 bottom, 7 left; min/max so a flipped shape works too
    local box = {
        topY = math.min(verts[2], verts[10]), botY = math.max(verts[2], verts[10]),
        leftX = math.min(verts[5], verts[13]), rightX = math.max(verts[5], verts[13]),
        fm = instance.dna.faceMagnitude,
    }
    box.headW, box.headH = math.abs(box.rightX - box.leftX), math.abs(box.botY - box.topY)
    local eyePos = faceData.positioners.eye
    box.leftEyeX = lerp(box.leftX, box.rightX, 0.5 - eyePos.x)
    box.rightEyeX = lerp(box.leftX, box.rightX, 0.5 + eyePos.x)
    box.eyeY = lerp(box.topY, box.botY, eyePos.y)

    placeEyes(body, faceData, box)
    placeBrows(body, faceData, box)
    placeNose(body, faceData, box)
    placeMouth(body, faceData, box)
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

                -- a spine's upper bands draw no picture of their own: torso1 draws the whole torso
                local upperBand = v.spineBand and v.spineBand[1] > 1
                for k2, v2 in pairs(v.appearance) do
                    if (k2 == 'skin' or k2 == 'bodyhair') and upperBand then -- luacheck: ignore 542
                    elseif k2 == 'skin' then
                        addSkinTexture(relevant.body, v, v2, scale)
                    elseif k2 == 'bodyhair' then
                        addBodyhairTexture(relevant.body, k, v, v2, scale)
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        if v2.main and v2.main.bgURL and v2.main.bgURL ~= '' then
                            addConnectedTexture(relevant.body, k, v, v2, instance, scale)
                        end
                    elseif k2 == 'haircut' then
                        addHaircutTexture(relevant.body, k, v, v2, instance, scale)
                    elseif k2 == 'face' then
                        addFaceDecals(relevant.body, k, v, v2, instance, scale)
                    end
                end
            end
        end
    end
    applyGroupAndZ(instance, false) -- the new texture fixtures in the Mipo's z-range
end

-- Arms are thin capsules under big hands and next to a big torso: by area alone a segment
-- weighed 1/40 of its hand and 1/80 of the torso (2eJYpY). Box2D chains past ~10:1 stretch
-- and lag; a hand snapped to a hold let the body slide 1000 units away on a stretched arm.
-- So each arm segment weighs at least this share of its hand and of the torso (the larger),
-- by density only: looks and collisions stay the same.
lib.armMinShare = { hand = 1 / 6, torso = 1 / 12 }

local arms = {
    { 'luarm', 'llarm', hand = 'lhand' },
    { 'ruarm', 'rlarm', hand = 'rhand' },
}

-- `share` (optional) instead of lib.armMinShare: to try values on live Mipos from the bridge.
function lib.balanceArms(instance, share)
    share = share or lib.armMinShare
    local torso = instance.parts.torso1
    if not (torso and torso.body and not torso.body:isDestroyed()) then return end
    for _, arm in ipairs(arms) do
        local hand = instance.parts[arm.hand]
        local handMass = (hand and hand.body and not hand.body:isDestroyed()) and hand.body:getMass() or 0
        local minMass = math.max(handMass * share.hand, torso.body:getMass() * share.torso)
        for _, name in ipairs(arm) do
            local part = instance.parts[name]
            if part and part.body and not part.body:isDestroyed() then
                local mass = part.body:getMass()
                if mass > 0 and mass < minMass then
                    for _, f in ipairs(part.body:getFixtures()) do
                        if not f:getUserData() then f:setDensity(f:getDensity() * minMass / mass) end
                    end
                    part.body:resetMassData()
                end
            end
        end
    end
end

-- A head weighs at most this many times the torso (all its segments). By area a big head
-- weighed up to 5x its torso (1C4UIs; CnANW 2.3x fell head first and was dazed over and
-- over): the Mipo tipped onto it and its light legs couldn't lift it. Density only, so a
-- big head still looks big.
lib.headMaxShare = 1.5

-- `share` (optional) instead of lib.headMaxShare: to try values on live Mipos from the bridge.
function lib.balanceHead(instance, share)
    share = share or lib.headMaxShare
    local head = instance.parts.head
    if not (head and head.body and not head.body:isDestroyed()) then return end
    local torsoMass = 0
    for i = 1, (instance.dna.creation.torsoSegments or 1) do
        local torso = instance.parts['torso' .. i]
        if torso and torso.body and not torso.body:isDestroyed() then torsoMass = torsoMass + torso.body:getMass() end
    end
    local mass, maxMass = head.body:getMass(), torsoMass * share
    if torsoMass > 0 and mass > maxMass then
        for _, f in ipairs(head.body:getFixtures()) do
            if not f:getUserData() then f:setDensity(f:getDensity() * maxMass / mass) end
        end
        head.body:resetMassData()
    end
end

-- A long neck under a big head (3BjZpF: 5 segments, each 1/7 of the head) hung to the side:
-- the light chain stretched past its limits. What held it (tested together; neither alone
-- did): each neck segment weighs at least neckMinShare of the head (density only), and keeps
-- itself upright (KEEP_ANGLE, as torso segments do; applyNeck). Head 200 -> 30 to the side.
lib.neckMinShare = 1 / 4

function lib.balanceNeck(instance, share)
    share = share or lib.neckMinShare
    local head = instance.parts.head
    if not (head and head.body and not head.body:isDestroyed()) then return end
    local minMass = head.body:getMass() * share
    for i = 1, (instance.dna.creation.neckSegments or 0) do
        local part = instance.parts['neck' .. i]
        if part and part.body and not part.body:isDestroyed() then
            local mass = part.body:getMass()
            if mass > 0 and mass < minMass then
                for _, f in ipairs(part.body:getFixtures()) do
                    if not f:getUserData() then f:setDensity(f:getDensity() * minMass / mass) end
                end
                part.body:resetMassData()
            end
        end
    end
end

-- How far a whole neck may bend, spread over its joints (none looser than the template's
-- 22.5 degrees, so 1-2 segments are as before): 5 joints of 22.5 let a neck fold 110 degrees
-- under its head and lie sideways (head 150-220 to the side, 3 random Mipos); 45 over 5
-- joints held it at 40-60.
lib.neckBend = 45

-- A segmented physics nose is a trunk: each joint bends this far (degrees). The template's
-- 5.6 made a 5-segment nose a stiff stick; Nikki wants it to hang and swing (2026-10-29).
lib.trunkBend = 30

-- Trunk limits on a segmented nose's DNA (built and loaded Mipos alike).
function lib.applyTrunk(instance)
    local creation = instance.dna.creation
    if (creation.noseSegments or 0) < 2 and creation.noseMode ~= 'physics' then return end
    local bend = math.rad(lib.trunkBend)
    for i = 1, creation.noseSegments or 0 do
        local part = instance.dna.parts['nose' .. i]
        if part and part.j and part.shape ~= ST.SHAPE8 then part.j.limits = { low = -bend, up = bend } end
    end
end

-- Neck segments keep themselves upright (see balanceNeck). Behaviors are the part's
-- thing.behaviors (from the DNA when built, saved with the body); `things` = true also sets
-- them on the built parts (a scene saved before this).
function lib.applyNeck(instance, things)
    local count = instance.dna.creation.neckSegments or 0
    local template = instance.dna.parts['neck-segment-template']
    local templateBend = template and template.j and template.j.limits and template.j.limits.up or math.pi / 8
    for i = 1, count do
        local name = 'neck' .. i
        local dnaPart = instance.dna.parts[name]
        if dnaPart and not (dnaPart.behaviors and dnaPart.behaviors[1]) then
            dnaPart.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        end
        if dnaPart and dnaPart.j then -- the bend budget (neckBend), from the template's own range
            local bend = math.min(templateBend, math.rad(lib.neckBend) / count)
            dnaPart.j.limits = { low = -bend, up = bend }
        end
        local part = things and instance.parts[name]
        if part and not (part.behaviors and part.behaviors[1]) then
            part.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        end
    end
end

-- A Mipo loaded in a pose its joints don't allow got yanked together by Box2D in one step and
-- fell over (3BjZpF stood rebuilt, fell loaded): saved while flailing, its joints pulled
-- apart (the nose tip 238 off, the neck 64), and saved bent past a limit that has changed
-- since (a neck at 25 degrees a joint, its limit now 9). Parents first, each part and
-- everything that hangs from it is moved onto its parent's anchor, then turned back inside
-- its limits about the joint, as a rebuild would assemble it.
local subtreeOf = mipoRegistry.subtreeBodies

function lib.settlePose(instance)
    for _, entry in ipairs(instance.topology or {}) do
        local part, parent = instance.parts[entry.name], entry.parent and instance.parts[entry.parent]
        if part and parent and part.body and parent.body and not part.body:isDestroyed() then
            for _, joint in ipairs(part.body:getJoints()) do
                local a, b = joint:getBodies()
                if a == parent.body and b == part.body then
                    local x1, y1, x2, y2 = joint:getAnchors()
                    if math.abs(x1 - x2) + math.abs(y1 - y2) > 0.5 then
                        for _, body in ipairs(subtreeOf(instance, entry.name, {})) do
                            local x, y = body:getPosition()
                            body:setPosition(x + x1 - x2, y + y1 - y2)
                        end
                    end
                end
                if a == parent.body and b == part.body and joint:getType() == 'revolute'
                    and joint:areLimitsEnabled() then
                    local angle = joint:getJointAngle()
                    local target = math.max(joint:getLowerLimit(), math.min(joint:getUpperLimit(), angle))
                    local turn = target - angle
                    if math.abs(turn) > 1e-3 then
                        local ax, ay = joint:getAnchors()
                        local c, s = math.cos(turn), math.sin(turn)
                        for _, body in ipairs(subtreeOf(instance, entry.name, {})) do
                            local x, y = body:getPosition()
                            local dx, dy = x - ax, y - ay
                            body:setPosition(ax + dx * c - dy * s, ay + dx * s + dy * c)
                            body:setAngle(body:getAngle() + turn)
                            body:setAngularVelocity(0)
                        end
                    end
                end
            end
        end
    end
end

-- Part masses that by area alone make a Mipo hard to move: a heavy head, thin arms and neck.
function lib.balanceMasses(instance)
    lib.balanceHead(instance)
    lib.balanceArms(instance)
    lib.balanceNeck(instance)
end

-- A spine (creation.torsoSpine, docs/MIPO-SPINE.md): the torso segments are bands of
-- torso1's shape (part.spineBand, read by topology.shape8Vertices), the upper ones bend
-- on a spring (mipo-actions, spineSpring) instead of each keeping its own angle.
-- Without it, the segments are whole torsos again, each with KEEP_ANGLE.
function lib.applySpine(instance)
    local creation = instance.dna.creation
    local count = creation.torsoSegments or 1
    local spine = creation.torsoSpine and count > 1
    local base = instance.dna.parts.torso1
    for i = 1, count do
        local part = instance.dna.parts['torso' .. i]
        if part then
            part.spineBand = spine and { i, count } or nil
            if i > 1 then
                if spine then
                    part.shape8URL = base.shape8URL
                    part.dims = utils.deepCopy(base.dims)
                    part.behaviors = {}
                    local bend = math.rad(creation.spineBend or D.creation.spineBend)
                    part.j = { type = JT.REVOLUTE, limits = { low = -bend, up = bend } }
                elseif not (part.behaviors and part.behaviors[1]) then
                    part.behaviors = { { name = 'KEEP_ANGLE', angle = 0 } }
                end
            end
        end
    end
end

-- Old saved DNA moved over to what builds now.
local function migrateDNA(instance)
    for partName, partDNA in pairs(instance.dna.parts or {}) do
        -- noses saved when they drew at z 490, above the arms
        if partName:find('^nose') and partDNA.appearance then
            for _, block in pairs(partDNA.appearance) do
                if type(block) == 'table' and block.zOffset == 490 then block.zOffset = 350 end
            end
        end
        -- ears on a hinge (saved before the soft weld): the next rebuild makes them springy
        if (partName == 'lear' or partName == 'rear') and partDNA.j and partDNA.j.type == JT.REVOLUTE then
            partDNA.j = earJoint()
        end
        local skin = partName:find('^torso%d') and partDNA.appearance and partDNA.appearance.skin
        if skin and skin.zOffset == 200 then skin.zOffset = TORSO_SKIN_Z end
        -- the duck beak upper lip is out (shape-catalogs.lua)
        local face = partDNA.appearance and partDNA.appearance.face
        if face and face.mouth and face.mouth.upperLipShape == 4 then face.mouth.upperLipShape = 1 end
    end
end

-- Defaults for what older DNA lacks, old saves moved over, and the body plan (topology).
local function prepareDNA(instance)
    D.ensureDefaults(instance.dna.creation, D.creation)
    migrateDNA(instance)
    instance.dna.faceMagnitude = instance.dna.faceMagnitude or D.faceMagnitude
    instance.dna.positioners = instance.dna.positioners or {}
    D.ensureDefaults(instance.dna.positioners, D.positioners)
    local topo = topology.resolve(instance.dna.creation)
    instance.topology = topo
    instance.entryMap = topology.buildEntryMap(topo)
    instance.childrenMap = topology.buildChildrenMap(topo)
    return topo
end

-- A new Mipo instance around a copy of this DNA (no bodies yet).
local function newInstance(mipoDNA, scale, id)
    return {
        id = id or uuid.generateID(),
        dna = utils.deepCopy(mipoDNA),
        scale = scale or 1,
        parts = {},  -- [partName] = thing
        joints = {}, -- ['parent->child'] = joint id (connected textures follow them)
    }
end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.

    local ordered = topology.buildOrderedNames(prepareDNA(instance))

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
    lib.applySpine(instance)

    if not instance.dna.creation.isPotatoHead and instance.dna.creation.neckSegments > 0 then
        for i = 1, instance.dna.creation.neckSegments do
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
        lib.applyNeck(instance)
    end

    local noseSegments = instance.dna.creation.noseSegments
    local noseMode = instance.dna.creation.noseMode or 'overlay'

    -- Skip physics nose entirely for overlay mode with 1 segment
    local physicsNoseCount = noseSegments
    if noseSegments == 1 and noseMode == 'overlay' then
        physicsNoseCount = 0
    end

    if physicsNoseCount > 0 then
        if physicsNoseCount == 1 and noseMode == 'physics' then
            -- Single SHAPE8 nose
            if not instance.dna.parts['nose1'] then
                instance.dna.parts['nose1'] = utils.deepCopy(instance.dna.parts['nose-single-template'])
            end
        else
            -- Segmented capsule trunk
            for i = 1, physicsNoseCount do
                local partName = 'nose' .. i
                if not instance.dna.parts[partName] then
                    instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['nose-segment-template'])
                end
            end
            lib.applyTrunk(instance)
            local nose1 = instance.dna.parts['nose1']
            if not nose1.appearance then nose1.appearance = {} end
            if not nose1.appearance['connected-skin'] then
                nose1.appearance['connected-skin'] = {
                    main = initBlock('leg5'),
                    zOffset = 350, -- trunk: in front of body/legs, behind arms and hands
                }
            end
            -- connected-hair is optional; added via UI when the user picks a hair texture
        end
    end

    for i = 1, #ordered do
        local partName = ordered[i]
        makePart(partName, instance, partSettings(partName, instance.dna.parts[partName], instance.scale, x, y))
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
        instance.groupIndex = allocateGroupIndex()
    end
    -- Assign a unique zGroupOffset so each character's textures occupy a
    -- separate z-range (composedZ = zGroupOffset * 1000 + zOffset).
    if not instance.zGroupOffset then
        instance.zGroupOffset = allocateZGroupOffset(instance)
    end
    applyGroupAndZ(instance, true)

    lib.balanceMasses(instance)
    mipoRegistry.register(instance)
    return instance
end

function lib.createCharacterFromJustDNA(mydna, x, y, scale)
    return lib.createCharacterFromExistingDNA(newInstance(mydna, scale), x, y, false)
end

-- One-shot post-spawn pose: rigidly rotate each arm chain about its shoulder so
-- the character appears in T-pose the moment it's added. No KEEP_ANGLE — physics
-- takes over on the next step and the arms behave naturally.
-- Assumes arms were created at angle 0 (hanging). Safe to call on a fresh instance.
function lib.poseTpose(instance)
    local chains = {
        { parts = { 'luarm', 'llarm', 'lhand' }, delta = math.pi / 2 },
        { parts = { 'ruarm', 'rlarm', 'rhand' }, delta = -math.pi / 2 },
    }
    for _, chain in ipairs(chains) do
        local upper = instance.parts[chain.parts[1]]
        if upper and upper.body and upper.height then
            -- Shoulder = top of the upper arm in its hanging pose (local y = -h/2).
            local sx, sy = upper.body:getWorldPoint(0, -upper.height / 2)
            for _, partName in ipairs(chain.parts) do
                local part = instance.parts[partName]
                if part and part.body then
                    local cx, cy = part.body:getPosition()
                    local nx, ny = mathutils.rotatePoint(cx, cy, sx, sy, chain.delta)
                    part.body:setPosition(nx, ny)
                    part.body:setAngle(part.body:getAngle() + chain.delta)
                    part.body:setAngularVelocity(0)
                    part.body:setLinearVelocity(0, 0)
                end
            end
        end
    end
end

function lib.createCharacter(template, x, y, scale)
    if dna[template] then
        local instance = newInstance(dna[template], scale)
        instance.templateName = template
        return lib.createCharacterFromExistingDNA(instance, x, y, false)
    end
end

-- Serialize all registered character instances to a plain-table array suitable
-- for JSON encoding. Each entry is versioned so future loaders can migrate.
-- dna.metadata is preserved verbatim — use it for archetype kind, mipo codes, etc.
function lib.serializeCharacters()
    local result = {}
    for _, instance in pairs(mipoRegistry.getAll()) do
        result[#result + 1] = {
            version = 1,
            id = instance.id,
            scale = instance.scale or 1,
            zGroupOffset = instance.zGroupOffset,
            dna = utils.deepCopy(instance.dna),
        }
    end
    return result
end

-- Reconstruct a character instance from saved data and a map of already-loaded bodies.
-- partBodies: { [partName] = body } — the bodies that were just recreated by io.buildWorld.
-- Ensures DNA defaults so new fields added to dna-defaults are auto-populated on old saves.
function lib.reconstructInstance(charData, partBodies)
    if not partBodies then return nil end
    local instance = newInstance(charData.dna, charData.scale, charData.id)
    instance.zGroupOffset = charData.zGroupOffset
    prepareDNA(instance)
    lib.applyNeck(instance) -- neck limits (bend budget) before the rest-pose limits below
    lib.applyTrunk(instance)
    for partName, body in pairs(partBodies) do
        local ud = body:getUserData()
        if ud and ud.thing then
            instance.parts[partName] = ud.thing
            applyFootMaterial(ud.thing, partName) -- scenes saved before feet had grip
            -- scenes saved when every nose was drawn at z 490, above the arms; and when
            -- torsos drew at the head's 200/210 (TORSO_SKIN_Z)
            for _, fixture in ipairs(body:getFixtures()) do
                local fud = fixture:getUserData()
                if fud and fud.extra and partName:find('^torso%d') and fud.subtype == subtypes.TEXFIXTURE then
                    if fud.extra.zOffset == 200 then
                        fud.extra.zOffset = TORSO_SKIN_Z
                    elseif fud.extra.zOffset == 210 then
                        fud.extra.zOffset = TORSO_SKIN_Z + TORSO_HAIR_ABOVE_SKIN
                    end
                end
                if fud and fud.label == 'upperlip' and fud.extra and fud.extra.main
                    and fud.extra.main.bgURL == 'upperlip4.png' then -- the duck beak is out
                    fud.extra.main.bgURL, fud.extra.main.fgURL = 'upperlip1.png', 'upperlip1-mask.png'
                    fud.extra.dirty = true
                end
                if fud and fud.extra and fud.extra.zOffset == 490 then
                    if fud.label == 'nose' then
                        fud.extra.zOffset = 254
                    elseif partName:find('^nose') then
                        fud.extra.zOffset = 350
                    end
                end
            end
            do -- limits relative to the rest pose
                for _, joint in ipairs(body:getJoints()) do
                    local _, bodyB = joint:getBodies()
                    if bodyB == body then
                        applyShoulderLimits(joint, partName)
                        applyLegLimits(instance, joint, partName)
                    end
                end
            end
        end
        -- keep the saved group index so a rebuild doesn't hand out a new one
        local first = body:getFixtures()[1]
        if not instance.groupIndex and first and first:getGroupIndex() < 0 then
            instance.groupIndex = first:getGroupIndex()
        end
    end
    -- instance.joints ('parent->child' = joint id) is what texture rebuilds use
    -- for connected-texture nodes. It isn't saved, so rebuild it from the bodies;
    -- left empty, redrawing textures on a loaded Mipo pointed leg textures at
    -- missing joints (untextured legs).
    for parentName, children in pairs(instance.childrenMap or {}) do
        local parent = instance.parts[parentName]
        for _, childName in ipairs(children) do
            local child = instance.parts[childName]
            if parent and child and parent.body and child.body then
                for _, joint in ipairs(child.body:getJoints()) do
                    local a, b = joint:getBodies()
                    local jud = joint:getUserData()
                    if a == parent.body and b == child.body and jud and jud.id then
                        instance.joints[parentName .. '->' .. childName] = jud.id
                    end
                end
            end
        end
    end
    -- connected textures saved with missing joints (from the bug above): redraw
    local registry = require('src.registry')
    local brokenTextures = false
    for _, part in pairs(instance.parts) do
        for _, fixture in ipairs(part.body:getFixtures()) do
            local fud = fixture:getUserData()
            for _, node in ipairs(fud and fud.extra and fud.extra.nodes or {}) do
                if node.type == NT.JOINT and not registry.getJointByID(node.id) then brokenTextures = true end
            end
        end
    end

    -- repair scenes saved before allocation skipped values in use: two Mipos
    -- sharing a group index never collide, sharing a zGroupOffset interleaves textures
    local groupTaken, zTaken = false, false
    for id, other in pairs(mipoRegistry.getAll()) do
        if id ~= instance.id then
            if instance.groupIndex and other.groupIndex == instance.groupIndex then groupTaken = true end
            if instance.zGroupOffset and other.zGroupOffset == instance.zGroupOffset then zTaken = true end
        end
    end
    if groupTaken then instance.groupIndex = allocateGroupIndex() end
    if zTaken then instance.zGroupOffset = allocateZGroupOffset(instance) end
    if groupTaken or zTaken then applyGroupAndZ(instance, true) end
    mipoRegistry.register(instance)
    if brokenTextures then
        lib.addTexturesFromInstance2(instance)
        applyGroupAndZ(instance, true) -- the redrawn texture fixtures start in group 0
    end
    lib.applyNeck(instance, true)
    lib.balanceMasses(instance)
    lib.settlePose(instance)
    return instance
end

return lib
