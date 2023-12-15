local lib = {}


-- the parts array is not unique, every mipo shares the same ones
-- creation, multipliers, values and positioners however are UNIQUE to a MIPO
-- from creation we have the 'limits array' which more or less are shared, but the details describe the picked texture shapes and dimensions etc.

local creation     = {
    isPotatoHead = false,
    hasPhysicsHair = false,
    hasNeck = true,
    torso = { flipx = 1, flipy = 1, w = 300, h = 300, d = 2.15, shape = 'trapezium' },
    neck = { w = 140, h = 150, d = 1, shape = 'capsule', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    neck1 = { w = 140, h = 110, d = 1, shape = 'capsule', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    head = { flipx = 1, flipy = 1, w = 100, h = 200, d = 1, shape = 'capsule3', limits = { low = -math.pi / 4, up = math.pi / 4, enabled = true } },
    lear = { w = 100, h = 100, d = .1, shape = 'capsule', stanceAngle = math.pi / 2, limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    rear = { w = 100, h = 100, d = .1, shape = 'capsule', stanceAngle = -math.pi / 2, limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    luarm = { w = 40, h = 280, d = 2.5, shape = 'capsule', limits = { low = 0, up = math.pi, enabled = false }, friction = 4000 },
    ruarm = { w = 40, h = 280, d = 2.5, shape = 'capsule', limits = { low = -math.pi, up = 0, enabled = false }, friction = 4000 },
    llarm = { w = 40, h = 160, d = 2.5, shape = 'capsule', limits = { low = 0, up = math.pi - 0.5, enabled = false }, friction = 2000 },
    rlarm = { w = 40, h = 160, d = 2.5, shape = 'capsule', limits = { low = (math.pi - 0.5) * -1, up = 0, enabled = false }, friction = 2000 },
    lhand = { w = 40, h = 40, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    rhand = { w = 40, h = 40, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    luleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = 0, up = math.pi / 2, enabled = true } },
    ruleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = -math.pi / 2, up = 0, enabled = true } },
    llleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = -math.pi / 8, up = 0, enabled = true } },
    rlleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = 0, up = math.pi / 8, enabled = true } },
    lfoot = { w = 80, h = 150, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    rfoot = { w = 80, h = 150, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    hair1 = { w = 180, h = 200, d = 0.1, shape = 'capsule', limits = { low = -math.pi / 2, up = math.pi / 2, enabled = true }, friction = 5000 },
    hair2 = { w = 150, h = 100, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair3 = { w = 150, h = 150, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair4 = { w = 150, h = 100, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair5 = { w = 180, h = 200, d = 0.1, shape = 'capsule', limits = { low = -math.pi / 2, up = math.pi / 2, enabled = true }, friction = 5000 },
    brow = { w = 10, h = 10 },
    eye = { w = 10, h = 10 },
    pupil = { w = 10, h = 10 },
    nose = { w = 10, h = 10 },
    upperlip = { w = 10, h = 10 },
    lowerlip = { w = 10, h = 10 },
    teeth = { w = 10, h = 10 },
}

local multipliers  = {
    torso = { hMultiplier = 1, wMultiplier = 1 },
    leg = { lMultiplier = 1, wMultiplier = 1 },
    leghair = { wMultiplier = 1 },
    feet = { wMultiplier = 1, hMultiplier = 1 },
    arm = { lMultiplier = 1, wMultiplier = 1 },
    armhair = { wMultiplier = 1 },
    hand = { wMultiplier = 1, hMultiplier = 1 },
    neck = { wMultiplier = 1, hMultiplier = 1 },
    head = { wMultiplier = 1, hMultiplier = 1 },
    face = { mMultiplier = 1 },
    ear = { wMultiplier = 1, hMultiplier = 1 },
    hair = { wMultiplier = 1, sMultiplier = 1, tension = 0.5 },
    nose = { wMultiplier = 1, hMultiplier = 1 },
    eye = { wMultiplier = 1, hMultiplier = 1 },
    pupil = { wMultiplier = .5, hMultiplier = .5 },
    brow = { wMultiplier = 1, hMultiplier = 1 },
    mouth = { wMultiplier = 1, hMultiplier = 1 },
    teeth = { hMultiplier = 1 },
    chesthair = { mMultiplier = 1 }
}

local positioners  = {
    leg = { x = 0.5 },
    eye = { x = 0.2, y = 0.5, r = 0 },
    nose = { y = 0.5 },
    brow = { y = 0.8, bend = 1 },
    mouth = { y = 0.25 },
    ear = { y = 0.5 }
}

lib.getCreation    = function()
    return creation
end

lib.getMultipliers = function()
    return multipliers
end

lib.getPositioners = function()
    return positioners
end

local function createDefaultTextureValues()
    return {
        shape     = 1,
        bgPal     = 13, --math.ceil(love.math.random() * #palettes),
        fgPal     = 1, --math.ceil(love.math.random() * #palettes),
        bgTex     = 1,
        fgTex     = 2,
        linePal   = 1,
        bgAlpha   = 5,
        fgAlpha   = 5,
        lineAlpha = 5,
        texRot    = 0,
        texScale  = 1,
    }
end

local function createDefaultPatchValues()
    return {
        sx = 1,
        sy = 1,
        r = 1,
        tx = 0,
        ty = 3
    }
end



local values = {
    chestHair        = createDefaultTextureValues(),
    skinPatchSnout   = createDefaultTextureValues(),
    skinPatchSnoutPV = createDefaultPatchValues(),
    skinPatchEye1    = createDefaultTextureValues(),
    skinPatchEye1PV  = createDefaultPatchValues(),
    skinPatchEye2    = createDefaultTextureValues(),
    skinPatchEye2PV  = createDefaultPatchValues(),
    upperlip         = createDefaultTextureValues(),
    lowerlip         = createDefaultTextureValues(),
    eyes             = createDefaultTextureValues(),
    pupils           = createDefaultTextureValues(),
    ears             = createDefaultTextureValues(),
    brows            = createDefaultTextureValues(),
    nose             = createDefaultTextureValues(),
    leghair          = createDefaultTextureValues(),
    legs             = createDefaultTextureValues(),
    armhair          = createDefaultTextureValues(),
    arms             = createDefaultTextureValues(),
    hands            = createDefaultTextureValues(),
    teeth            = createDefaultTextureValues(),
    body             = createDefaultTextureValues(),
    head             = createDefaultTextureValues(),
    hair             = createDefaultTextureValues(),
    neck             = createDefaultTextureValues(),
    feet             = createDefaultTextureValues(),
}
values.skinPatchSnoutPV.ty = 5
values.skinPatchSnoutPV.sx = 2
values.skinPatchEye1PV.ty = 0
values.skinPatchEye1PV.tx = -2
values.skinPatchEye2PV.ty = 0
values.skinPatchEye2PV.tx = 2
values.teeth.bgPal = 5

lib.generateValues = function()
    return values
end

lib.generateParts = function()
    local legUrls = {
        'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
        'assets/parts/leg5.png', 'assets/parts/leg7.png', 'assets/parts/legp2.png', 'assets/parts/leg1x.png',
        'assets/parts/leg2x.png', 'assets/parts/leg3x.png', 'assets/parts/leg4x.png', 'assets/parts/leg5x.png',
        'assets/parts/neck8.png',
    }

    local neckUrls = {
        'assets/parts/neck1.png', 'assets/parts/neck2.png', 'assets/parts/neck3.png', 'assets/parts/neck4.png',
        'assets/parts/neck5.png', 'assets/parts/neck6.png', 'assets/parts/neck7.png', 'assets/parts/neck8.png',
        'assets/parts/neck9.png', 'assets/parts/neck10.png', 'assets/parts/leg1.png', 'assets/parts/leg2.png',
        'assets/parts/leg3.png', 'assets/parts/leg4.png', 'assets/parts/leg5.png', 'assets/parts/leg1x.png',
        'assets/parts/leg2x.png', 'assets/parts/leg3x.png', 'assets/parts/leg4x.png', 'assets/parts/leg5x.png',
    }

    local patchUrls = {
        'assets/parts/patch1.png', 'assets/parts/patch2.png', 'assets/parts/patch3.png', 'assets/parts/patch4.png',
    }

    local hairUrls = {
        'assets/parts/hair1.png', 'assets/parts/hair2.png', 'assets/parts/hair3.png', 'assets/parts/hair4.png',
        'assets/parts/hair5.png', 'assets/parts/hair6.png', 'assets/parts/hair7.png', 'assets/parts/hair8.png',
        'assets/parts/hair9.png', 'assets/parts/hair10.png', 'assets/parts/hair11.png', 'assets/parts/hair1x.png',
        'assets/parts/hair2x.png', 'assets/parts/haarnew1.png', 'assets/parts/haarnew2.png', 'assets/parts/haarnew3.png',
        'assets/parts/haarnew4.png',
    }

    table.insert(patchUrls, 'assets/parts/null.png')
    table.insert(hairUrls, 'assets/parts/null.png') -- i dont have a part array for these things, the url should suffice

    local chestHairUrls = {
        'assets/parts/borsthaar1.png', 'assets/parts/borsthaar2.png', 'assets/parts/borsthaar3.png',
        'assets/parts/borsthaar4.png',
        'assets/parts/borsthaar5.png', 'assets/parts/borsthaar6.png', 'assets/parts/borsthaar7.png'

    }
    table.insert(chestHairUrls, 'assets/parts/null.png')

    local bodyImgUrls, bodyParts = loadVectorSketchAndGetImages('assets/bodies.polygons.txt', 'bodies')

    local feetImgUrls, feetParts = loadVectorSketchAndGetImages('assets/feet.polygons.txt', 'feet')
    local handParts = feetParts
    local headImgUrls = bodyImgUrls
    local headParts = bodyParts

    local eyeImgUrls, eyeParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'eyes')
    local pupilImgUrls, pupilParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'pupils')
    local noseImgUrls, noseParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'noses')
    local browImgUrls, browParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'eyebrows')
    local earImgUrls, earParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'ears')
    local teethImgUrls, teethParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'teeths')
    local upperlipImgUrls, upperlipParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'upperlips')
    local lowerlipImgUrls, lowerlipParts = loadVectorSketchAndGetImages('assets/faceparts.polygons.txt', 'lowerlips')

    table.insert(teethImgUrls, 'assets/parts/null.png')

    local patchChildren = { 'skinPatchSnout', 'skinPatchEye1', 'skinPatchEye2' }
    local mouthChildren = { 'upperlip', 'lowerlip', 'teeth' }

    local parts = {
        { name = 'head',           imgs = headImgUrls,     p = headParts,                   kind = 'head' },
        { name = 'hair',           imgs = hairUrls,        kind = 'head' },
        { name = 'brows',          imgs = browImgUrls,     p = browParts,                   kind = 'head' },
        { name = 'eyes2',          kind = 'head',          children = { 'eyes', 'pupils' } },
        { name = 'pupils',         imgs = pupilImgUrls,    p = pupilParts,                  kind = 'head',                   child = true },
        { name = 'eyes',           imgs = eyeImgUrls,      p = eyeParts,                    kind = 'head',                   child = true },
        { name = 'ears',           imgs = earImgUrls,      p = earParts,                    kind = 'head' },
        { name = 'nose',           imgs = noseImgUrls,     p = noseParts,                   kind = 'head' },
        { name = 'patches',        kind = 'head',          children = patchChildren },
        { name = 'skinPatchSnout', imgs = patchUrls,       kind = 'head',                   child = true },
        { name = 'skinPatchEye1',  imgs = patchUrls,       kind = 'head',                   child = true },
        { name = 'skinPatchEye2',  imgs = patchUrls,       kind = 'head',                   child = true },
        { name = 'mouth',          kind = 'head',          children = mouthChildren },
        { name = 'upperlip',       imgs = upperlipImgUrls, p = upperlipParts,               kind = 'head',                   child = true },
        { name = 'lowerlip',       imgs = lowerlipImgUrls, p = lowerlipParts,               kind = 'head',                   child = true },
        { name = 'teeth',          imgs = teethImgUrls,    p = teethParts,                  kind = 'head',                   child = true },
        { name = 'neck',           imgs = neckUrls,        kind = 'body' },
        { name = 'body',           imgs = bodyImgUrls,     p = bodyParts,                   kind = 'body' },
        { name = 'chestHair',      imgs = chestHairUrls,   kind = 'body' },
        { name = 'arms2',          imgs = legUrls,         kind = 'body',                   children = { 'arms', 'armhair' } },
        { name = 'armhair',        imgs = hairUrls,        kind = 'body',                   child = true },
        { name = 'arms',           imgs = legUrls,         kind = 'body',                   child = true },
        { name = 'hands',          imgs = feetImgUrls,     p = handParts,                   kind = 'body' },
        { name = 'legs2',          kind = 'body',          children = { 'legs', 'leghair' } },
        { name = 'legs',           imgs = legUrls,         kind = 'body',                   child = true },
        { name = 'leghair',        imgs = hairUrls,        kind = 'body',                   child = true },
        { name = 'feet',           imgs = feetImgUrls,     p = feetParts,                   kind = 'body' },
    }


    return parts
end

return lib
