local parse = require 'lib.parse-file'
local node  = require 'lib.node'

texscales   = { 0.06, 0.12, 0.24, 0.48, 0.64, 0.96, 1.28, 1.64, 2.56 }
leglengths  = { 400, 500, 600, 700, 800, 900, 1000, 1200, 1400 }
necklengths = { 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 }

local function TableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

local function loadGroupFromFile(url, groupName)
    local imgs = {}
    local parts = {}

    local whole = parse.parseFile(url)
    local group = node.findNodeByName(whole, groupName) or {}
    for i = 1, #group.children do
        local p = group.children[i]
        stripPath(p, '/experiments/puppet%-maker/')
        for j = 1, #p.children do
            if p.children[j].texture then
                imgs[i] = p.children[j].texture.url
                parts[i] = group.children[i]
            end
        end
    end
    return imgs, parts
end


local function zeroTransform(arr)
    for i = 1, #arr do
        if arr[i].transforms then
            arr[i].transforms.l[1] = 0
            arr[i].transforms.l[2] = 0
        end
    end
end

function createDefaultTextureValues()
    return {
        shape     = 1,
        bgPal     = 4,
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

function createDefaultPatchValues()
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
        handsPinned             = false,
        feetPinned              = true,
        faceScale               = 1,
        faceScaleX              = 1,
        faceScaleY              = 1,
        mouthScaleX             = 1,
        mouthScaleY             = 1,
        potatoHead              = false,
        skinPatchSnout          = createDefaultTextureValues(),
        skinPatchSnoutPV        = createDefaultPatchValues(),
        skinPatchEye1           = createDefaultTextureValues(),
        skinPatchEye1PV         = createDefaultPatchValues(),
        skinPatchEye2           = createDefaultTextureValues(),
        skinPatchEye2PV         = createDefaultPatchValues(),
        upperlip                = createDefaultTextureValues(),
        upperlipWidthMultiplier = 1,
        lowerlip                = createDefaultTextureValues(),
        lowerlipWidthMultiplier = 1,
        mouthXAxis              = 0,
        mouthYAxis              = 2,
        eyes                    = createDefaultTextureValues(),
        eyeWidthMultiplier      = 1,
        eyeHeightMultiplier     = 1,
        eyeRotation             = 0,
        eyeYAxis                = 0,
        eyeXAxisBetween         = 0,
        pupils                  = createDefaultTextureValues(),
        pupilSizeMultiplier     = 1,
        ears                    = createDefaultTextureValues(),
        earUnderHead            = true,
        earWidthMultiplier      = 1,
        earHeightMultiplier     = 1,
        earRotation             = 0,
        earYAxis                = 0, -- -2,-1,0,1,2
        brows                   = createDefaultTextureValues(),
        browsWidthMultiplier    = .5,
        browsWideMultiplier     = 1,
        browsDefaultBend        = 1,
        browYAxis               = 1,
        nose                    = createDefaultTextureValues(),
        noseXAxis               = 0, --  -2,-1,0,1,2
        noseYAxis               = 0, --  -3, -2,-1,0,1,2, 3
        noseWidthMultiplier     = 1,
        noseHeightMultiplier    = 1,
        leghair                 = createDefaultTextureValues(),
        legs                    = createDefaultTextureValues(),
        legDefaultStance        = .5,
        legLength               = 5,
        legWidthMultiplier      = 1,
        leg1flop                = -1,
        leg2flop                = 1,
        legXAxis                = 0,
        armhair                 = createDefaultTextureValues(),
        arms                    = createDefaultTextureValues(),
        armLength               = 2,
        armWidthMultiplier      = 1,
        arm1flop                = -1,
        arm2flop                = 1,
        hands                   = createDefaultTextureValues(),
        handLengthMultiplier    = 1,
        handWidthMultiplier     = 1,
        overBite                = true,
        teethHeightMultiplier   = 1,
        teeth                   = createDefaultTextureValues(),
        body                    = createDefaultTextureValues(),
        bodyWidthMultiplier     = 1,
        bodyHeightMultiplier    = 1,
        head                    = createDefaultTextureValues(),
        headWidthMultiplier     = 1,
        headHeightMultiplier    = 1,
        hair                    = createDefaultTextureValues(),
        hairWidthMultiplier     = 1,
        hairTension             = 0.001,
        neck                    = createDefaultTextureValues(),
        neckLength              = 1,
        neckWidthMultiplier     = 1,
        feet                    = createDefaultTextureValues(),
        feetLengthMultiplier    = 1,
        feetWidthMultiplier     = 1,
    }
    return values
end

function generateParts()
    --print('generatre!')
    local legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
        'assets/parts/leg5.png', 'assets/parts/leg7.png',
        'assets/parts/leg1x.png', 'assets/parts/leg2x.png', 'assets/parts/leg3x.png', 'assets/parts/leg4x.png',
        'assets/parts/leg5x.png', 'assets/parts/neck8.png', }

    local neckUrls = {

        'assets/parts/neck1.png', 'assets/parts/neck2.png', 'assets/parts/neck3.png', 'assets/parts/neck4.png',
        'assets/parts/neck5.png', 'assets/parts/neck6.png', 'assets/parts/neck7.png', 'assets/parts/neck8.png',
        'assets/parts/neck9.png', 'assets/parts/neck10.png',
        'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
        'assets/parts/leg5.png',
        'assets/parts/leg1x.png', 'assets/parts/leg2x.png', 'assets/parts/leg3x.png', 'assets/parts/leg4x.png',
        'assets/parts/leg5x.png' }

    local patchUrls = { 'assets/parts/patch1.png', 'assets/parts/patch2.png', 'assets/parts/patch3.png',
        'assets/parts/patch4.png' }


    local hairUrls = { 'assets/parts/hair1.png', 'assets/parts/hair2.png',
        'assets/parts/hair3.png',
        'assets/parts/hair4.png',
        'assets/parts/hair5.png', 'assets/parts/hair6.png', 'assets/parts/hair7.png', 'assets/parts/hair8.png',
        'assets/parts/hair9.png', 'assets/parts/hair10.png', 'assets/parts/hair11.png', 'assets/parts/hair1x.png',
        'assets/parts/hair2x.png', 'assets/parts/haarnew1.png', 'assets/parts/haarnew2.png', 'assets/parts/haarnew3.png',
        'assets/parts/haarnew4.png' }

    table.insert(patchUrls, 'assets/parts/null.png')
    table.insert(hairUrls, 'assets/parts/null.png') -- i dont have a part array for these things, the url should suffice


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
