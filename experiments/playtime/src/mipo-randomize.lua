-- src/mipo-randomize.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local appearance = require('src.mipo-appearance')
local build = require('src.mipo-build')
local textures = require('src.mipo-textures')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')
local D = require('src.dna-defaults')
local C = require('src.shape-catalogs')

local randomHexColor = utils.randomHexColor

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
        build.updatePart('torso' .. i,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
    end

    local headScale = D.randomInRangeWeighted('bodyScale')
    local headUrl = pick(urls)
    build.updatePart('head',
        { shape8URL = headUrl .. '.png', sy = headScale * (math.random() < 0.5 and -1 or 1), sx = headScale },
        instance)

    -- Random colors + pattern — shared across all torso segments + head
    local fgHex, pHex, pURL = randomLook()
    local look = { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL }
    for i = 1, count do
        for _, patch in ipairs({ 'main', 'patch1', 'patch2' }) do
            appearance.updateSkinOfPart(instance, 'torso' .. i, look, patch)
        end
    end
    appearance.updateSkinOfPart(instance, 'head', look)

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
        build.updatePart(pname, { h = legH }, instance)
    end
    for _, pname in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm' }) do
        build.updatePart(pname, { h = armH }, instance)
    end
    for _, p in ipairs({ 'luarm', 'ruarm' }) do
        if instance.dna.parts[p] and instance.dna.parts[p].appearance
            and instance.dna.parts[p].appearance['connected-skin'] then
            appearance.updateConnectedAppearance(instance, p, 'connected-skin', { wmul = armWMul })
        end
    end
    for _, p in ipairs({ 'luleg', 'ruleg' }) do
        if instance.dna.parts[p] and instance.dna.parts[p].appearance
            and instance.dna.parts[p].appearance['connected-skin'] then
            appearance.updateConnectedAppearance(instance, p, 'connected-skin', { wmul = legWMul })
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
    build.updatePart('lear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = -earSx, w = earW, h = earH },
        instance)
    build.updatePart('rear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = earSx, w = earW, h = earH },
        instance)

    local fgHex, pHex, pURL = randomLook()
    for _, ear in ipairs({ 'lear', 'rear' }) do
        appearance.updateSkinOfPart(instance, ear, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
    end
end

-- Randomize feet/hand shapes, scales, and colors.
local function randomizeFeetAndHands(instance)
    local fhUrls = C.handShapes
    local fUrl = pick(fhUrls)
    local fS = D.randomInRangeWeighted('feetScale')

    build.updatePart('lfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = fS },
        instance)
    build.updatePart('rfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = -fS },
        instance)

    local handScale = D.randomInRangeWeighted('handScale')
    local handUrl = pick(fhUrls)
    build.updatePart('lhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = handScale },
        instance)
    build.updatePart('rhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = -handScale },
        instance)

    for _, pair in ipairs({ { 'lfoot', 'rfoot' }, { 'lhand', 'rhand' } }) do
        local fgHex, pHex, pURL = randomLook()
        for _, part in ipairs(pair) do
            appearance.updateSkinOfPart(instance, part, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
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
    appearance.updateHaircutOfPart(instance, 'head', hcValues)
    appearance.updateHaircutOfPart(instance, 'torso1', hcValues)

    -- Random bodyhair (shared hairColor for bgHex, independent fgHex/pHex for variety).
    -- Head gets the same bodyhair as torsos so outline/colors are consistent across the body.
    local bhUrl = pick(C.bodyhairTextures)
    local bhFgHex, bhPHex, bhPURL = randomLook()
    local bhValues = { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png',
                       bgHex = hairColor, fgHex = bhFgHex, pHex = bhPHex, pURL = bhPURL }
    appearance.updateBodyhairOfPart(instance, 'head', bhValues)
    for i = 1, count do
        appearance.updateBodyhairOfPart(instance, 'torso' .. i, bhValues)
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
        for _, part in ipairs(parts) do appearance.updateConnectedAppearance(instance, part, 'connected-skin', skin) end
    end
    for _, part in ipairs(torsos) do appearance.updateConnectedAppearance(instance, part, 'connected-skin', skin) end

    -- limb hair in the hair colour, the same way
    local hair
    for _, parts in ipairs(limbs) do
        hair = { bgURL = pick(C.limbHairTextures) .. '.png', bgHex = hairColor }
        for _, part in ipairs(parts) do appearance.updateConnectedAppearance(instance, part, 'connected-hair', hair) end
    end
    for _, part in ipairs(torsos) do appearance.updateConnectedAppearance(instance, part, 'connected-hair', hair) end
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
    appearance.updateFaceOfPart(instance, 'head', faceValues)
    appearance.updateFaceOfPart(instance, 'torso1', faceValues)
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

local dist = mathutils.dist

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
                    build.updatePart(pname, { sx = (dims.sx or 1) * handFactor, sy = (dims.sy or 1) * handFactor },
                        instance)
                end
            end
        end
        for _, pname in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm' }) do
            local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
            if dims and dims.h then build.updatePart(pname, { h = dims.h * factor }, instance) end
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
    build.rebuildFromCreation(instance, { isPotatoHead = not instance.dna.creation.isPotatoHead, noseSegments = 0 })
    lib.limitArmReach(instance)
    textures.rebuildTextures(instance)
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
        build.updatePart('head',
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
        local fgHex, pHex, pURL = randomLook()
        appearance.updateSkinOfPart(instance, 'head', { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        local hcUrl = pick(C.haircutTextures)
        local hcBgURL = hcUrl .. '.png'
        local hcFgURL = C.hairsWithMask[hcBgURL] and hcBgURL:gsub('%.png', '-mask.png') or ''
        appearance.updateHaircutOfPart(instance, 'head',
            { bgURL = hcBgURL, fgURL = hcFgURL,
              bgHex = hairColor, width = D.randomInRangeWeighted('haircutWidth') })
        randomizeFace(instance, hairColor)

    elseif partName:match('^torso') then
        local url = pick(C.torsoHeadShapes)
        local s = D.randomInRangeWeighted('bodyScale')
        build.updatePart(partName,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
        local fgHex, pHex, pURL = randomLook()
        appearance.updateSkinOfPart(instance, partName, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        local bhUrl = pick(C.bodyhairTextures)
        local bhFgHex, bhPHex, bhPURL = randomLook()
        appearance.updateBodyhairOfPart(instance, partName, { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png',
            bgHex = hairColor, fgHex = bhFgHex, pHex = bhPHex, pURL = bhPURL })

    elseif partName == 'lear' or partName == 'rear' then
        randomizeEars(instance)

    elseif partName:match('foot$') or partName:match('hand$') then
        -- both feet (or both hands): a shape and a size, mirrored, and one look
        local kind = partName:match('foot$') and 'foot' or 'hand'
        local url = pick(C.handShapes)
        local size = D.randomInRangeWeighted(kind == 'foot' and 'feetScale' or 'handScale')
        build.updatePart('l' .. kind, { shape8URL = url .. '.png', sy = size, sx = size }, instance)
        build.updatePart('r' .. kind, { shape8URL = url .. '.png', sy = size, sx = -size }, instance)
        local fgHex, pHex, pURL = randomLook()
        for _, p in ipairs({ 'l' .. kind, 'r' .. kind }) do
            appearance.updateSkinOfPart(instance, p, { bgHex = '000000ff', fgHex = fgHex, pHex = pHex, pURL = pURL })
        end

    elseif partName:match('arm') or partName:match('leg') then
        -- both arms (or both legs): skin and hair along them
        local kind = partName:match('arm') and 'arm' or 'leg'
        local parts = { 'lu' .. kind, 'ru' .. kind }
        local skinUrl = pick(C.limbSkinTextures)
        local fgHex, pHex, pURL = randomLook()
        for _, p in ipairs(parts) do
            appearance.updateConnectedAppearance(instance, p, 'connected-skin',
                { bgURL = skinUrl .. '.png', fgURL = skinUrl .. '-mask.png',
                  fgHex = fgHex, pHex = pHex, pURL = pURL })
        end
        local hairUrl = pick(C.limbHairTextures)
        for _, p in ipairs(parts) do
            appearance.updateConnectedAppearance(instance, p, 'connected-hair',
                { bgURL = hairUrl .. '.png', bgHex = hairColor })
        end
    end

    textures.rebuildTextures(instance)
end

-- Jitter all size/proportion values of a mipo while keeping shapes and colors identical.
-- Useful for generating genetic variants of a character.
local MUTATE_JITTER = 0.35  -- fraction of global range applied as ± offset

local function jitterInRange(value, key)
    local r = D.randomRanges[key]
    if not r then return value end
    local delta = (math.random() * 2 - 1) * (r.max - r.min) * MUTATE_JITTER
    return mathutils.clamp(value + delta, r.min, r.max)
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
            build.updatePart('torso' .. i, { sx = s, sy = s * (dims.sy < 0 and -1 or 1) }, instance)
        end
    end
    local hd = instance.dna.parts.head and instance.dna.parts.head.dims
    if hd then
        local s = jitterInRange(math.abs(hd.sx or 1), 'bodyScale')
        build.updatePart('head', { sx = s, sy = s * ((hd.sy or 1) < 0 and -1 or 1) }, instance)
    end

    -- Ears (always symmetric pair)
    local ed = instance.dna.parts.lear and instance.dna.parts.lear.dims
    if ed then
        local esx = jitterInRange(math.abs(ed.sx or 1), 'earScale')
        local esy = jitterInRange(math.abs(ed.sy or 1), 'earScale')
        build.updatePart('lear', { sx = -esx, sy = esy }, instance)
        build.updatePart('rear', { sx =  esx, sy = esy }, instance)
    end

    -- Feet
    local ffd = instance.dna.parts.lfoot and instance.dna.parts.lfoot.dims
    if ffd then
        local fS = jitterInRange(math.abs(ffd.sx or 1), 'feetScale')
        build.updatePart('lfoot', { sx =  fS, sy = fS }, instance)
        build.updatePart('rfoot', { sx = -fS, sy = fS }, instance)
    end

    -- Hands
    local fhd = instance.dna.parts.lhand and instance.dna.parts.lhand.dims
    if fhd then
        local hS = jitterInRange(math.abs(fhd.sx or 1), 'handScale')
        build.updatePart('lhand', { sx =  hS, sy = hS }, instance)
        build.updatePart('rhand', { sx = -hS, sy = hS }, instance)
    end

    -- Face sizes
    local faceOwner = creation.isPotatoHead and 'torso1' or 'head'
    local fp = instance.dna.parts[faceOwner]
    if fp and fp.appearance and fp.appearance.face then
        local face = fp.appearance.face
        appearance.updateFaceOfPart(instance, faceOwner, {
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
            if not legH then legH = mathutils.clamp(jitterRelative(dims.h, MUTATE_JITTER), 60, 800) end
            build.updatePart(pname, { h = legH }, instance)
        end
    end
    for _, pname in ipairs({'luarm', 'ruarm', 'llarm', 'rlarm'}) do
        local dims = instance.dna.parts[pname] and instance.dna.parts[pname].dims
        if dims and dims.h then
            if not armH then armH = mathutils.clamp(jitterRelative(dims.h, MUTATE_JITTER), 60, 800) end
            build.updatePart(pname, { h = armH }, instance)
        end
    end

    textures.rebuildTextures(instance)
end


return lib
