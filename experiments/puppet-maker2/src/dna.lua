local parse = require 'lib.parse-file'
local node  = require 'lib.node'
local mesh  = require 'lib.mesh'

local function TableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

local function createDefaultTextureValues()
    return {
        shape     = 1,
        bgPal     = math.ceil(love.math.random() * #palettes),
        fgPal     = 1,
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

function generateValues()
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
    return values
end

function generateParts()
    --print('generatre!')
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

    local bodyImgUrls, bodyParts = loadGroupFromFile('assets/bodies.polygons.txt', 'bodies')
    zeroTransform(bodyParts)

    local feetImgUrls, feetParts = loadGroupFromFile('assets/feet.polygons.txt', 'feet')
    local handParts = feetParts
    local headImgUrls = bodyImgUrls
    local headParts = bodyParts

    local eyeImgUrls, eyeParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyes')
    local pupilImgUrls, pupilParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'pupils')
    local noseImgUrls, noseParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'noses')
    local browImgUrls, browParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyebrows')
    local earImgUrls, earParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'ears')
    local teethImgUrls, teethParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'teeths')
    local upperlipImgUrls, upperlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'upperlips')
    local lowerlipImgUrls, lowerlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'lowerlips')

    -- ok haha this cause a bug, because the randomizer doenst know how to handle it properly
    --

    -- but why is this an issue for the nose and not for the patch for example
    table.insert(teethImgUrls, 'assets/parts/null.png')
    local parts = {
        { name = 'head',           imgs = headImgUrls,     p = headParts,                                                    kind = 'head' },
        { name = 'hair',           imgs = hairUrls,        kind = 'head' },
        { name = 'brows',          imgs = browImgUrls,     p = browParts,                                                    kind = 'head' },
        { name = 'eyes2',          kind = 'head',          children = { 'eyes', 'pupils' } },
        { name = 'pupils',         imgs = pupilImgUrls,    p = pupilParts,                                                   kind = 'head',                   child = true },
        { name = 'eyes',           imgs = eyeImgUrls,      p = eyeParts,                                                     kind = 'head',                   child = true },
        { name = 'ears',           imgs = earImgUrls,      p = earParts,                                                     kind = 'head' },
        { name = 'nose',           imgs = noseImgUrls,     p = noseParts,                                                    kind = 'head' },
        { name = 'patches',        kind = 'head',          children = { 'skinPatchSnout', 'skinPatchEye1', 'skinPatchEye2' } },
        { name = 'skinPatchSnout', imgs = patchUrls,       kind = 'head',                                                    child = true },
        { name = 'skinPatchEye1',  imgs = patchUrls,       kind = 'head',                                                    child = true },
        { name = 'skinPatchEye2',  imgs = patchUrls,       kind = 'head',                                                    child = true },
        { name = 'mouth',          kind = 'head',          children = { 'upperlip', 'lowerlip', 'teeth' } },
        { name = 'upperlip',       imgs = upperlipImgUrls, p = upperlipParts,                                                kind = 'head',                   child = true },
        { name = 'lowerlip',       imgs = lowerlipImgUrls, p = lowerlipParts,                                                kind = 'head',                   child = true },
        { name = 'teeth',          imgs = teethImgUrls,    p = teethParts,                                                   kind = 'head',                   child = true },
        { name = 'neck',           imgs = neckUrls,        kind = 'body' },
        { name = 'body',           imgs = bodyImgUrls,     p = bodyParts,                                                    kind = 'body' },
        { name = 'chestHair',      imgs = chestHairUrls,   kind = 'body' },
        { name = 'arms2',          imgs = legUrls,         kind = 'body',                                                    children = { 'arms', 'armhair' } },
        { name = 'armhair',        imgs = hairUrls,        kind = 'body',                                                    child = true },
        { name = 'arms',           imgs = legUrls,         kind = 'body',                                                    child = true },
        { name = 'hands',          imgs = feetImgUrls,     p = handParts,                                                    kind = 'body' },
        { name = 'legs2',          kind = 'body',          children = { 'legs', 'leghair' } },
        { name = 'legs',           imgs = legUrls,         kind = 'body',                                                    child = true },
        { name = 'leghair',        imgs = hairUrls,        kind = 'body',                                                    child = true },
        { name = 'feet',           imgs = feetImgUrls,     p = feetParts,                                                    kind = 'body' },
    }

    local urls = {}
    urls = TableConcat(urls, legUrls)
    urls = TableConcat(urls, neckUrls)
    urls = TableConcat(urls, patchUrls)
    urls = TableConcat(urls, hairUrls)
    urls = TableConcat(urls, bodyImgUrls)
    urls = TableConcat(urls, feetImgUrls)
    urls = TableConcat(urls, eyeImgUrls)
    urls = TableConcat(urls, pupilImgUrls)
    return parts, urls
end
