local parse = require 'lib.parse-file'
local node  = require 'lib.node'

texscales   = { 0.06, 0.12, 0.24, 0.48, 0.64, 0.96, 1.28, 1.64, 2.56 }
leglengths  = { 100, 200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000 }

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





function generate()
    --print('generatre!')
    local legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
        'assets/parts/leg5.png', 'assets/parts/leg6.png', 'assets/parts/leg7.png', 'assets/parts/leg8.png' }


    local patchUrls = { 'assets/parts/patch1.png', 'assets/parts/patch2.png', 'assets/parts/patch3.png',
        'assets/parts/patch4.png' }


    local hairUrls = { 'assets/parts/hair1.png', 'assets/parts/hair2.png',
        'assets/parts/hair3.png',
        'assets/parts/hair4.png',
        'assets/parts/hair5.png', 'assets/parts/hair6.png', 'assets/parts/hair7.png', 'assets/parts/hair8.png',
        'assets/parts/hair9.png', 'assets/parts/hair10.png', 'assets/parts/hair11.png' }

    table.insert(patchUrls, 'assets/null.png')
    table.insert(hairUrls, 'assets/null.png') -- i dont have a part array for these things, the url should suffice

    local bodyImgUrls, bodyParts = loadGroupFromFile('assets/bodies.polygons.txt', 'bodies')
    local feetImgUrls, feetParts = loadGroupFromFile('assets/bodies.polygons.txt', 'feet')
    local handParts = feetParts
    local headImgUrls = bodyImgUrls
    local headParts = bodyParts

    local eyeImgUrls, eyeParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyes')
    local pupilImgUrls, pupilParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'pupils')
    local noseImgUrls, noseParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'noses')
    local browImgUrls, browParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyebrows')
    local earImgUrls, earParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'ears')
    local upperlipImgUrls, upperlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'upperlips')
    local lowerlipImgUrls, lowerlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'lowerlips')

    table.insert(noseImgUrls, 'assets/null.png')

    local parts = {
        { name = 'head',           imgs = headImgUrls,     p = headParts },
        { name = 'hair',           imgs = hairUrls },
        { name = 'brows',          imgs = browImgUrls,     p = browParts },
        { name = 'pupils',         imgs = pupilImgUrls,    p = pupilParts },
        { name = 'eyes',           imgs = eyeImgUrls,      p = eyeParts },
        -- { name = 'eye1skin', imgs = eyeImgUrls },
        -- { name = 'eye2skin', imgs = eyeImgUrls },
        { name = 'ears',           imgs = earImgUrls,      p = earParts },
        { name = 'neck',           imgs = legUrls },
        { name = 'nose',           imgs = noseImgUrls,     p = noseParts },
        { name = 'skinPatchSnout', imgs = patchUrls },
        { name = 'upperlip',       imgs = upperlipImgUrls, p = upperlipParts },
        { name = 'lowerlip',       imgs = lowerlipImgUrls, p = lowerlipParts },
        { name = 'body',           imgs = bodyImgUrls,     p = bodyParts },
        { name = 'armhair',        imgs = hairUrls },
        { name = 'arms',           imgs = legUrls },
        { name = 'hands',          imgs = feetImgUrls,     p = handParts },
        { name = 'legs',           imgs = legUrls },
        { name = 'leghair',        imgs = hairUrls },
        { name = 'feet',           imgs = feetImgUrls,     p = feetParts },
    }



    local values = {
        faceScaleX = 1,
        faceScaleY = 1,
        potatoHead = false,
        --[[
        skinPatchEye1           = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        skinPatchEye1Scale      = 1,
        skinPatchEye1Angle      = 1,
        skinPatchEye1X          = 0,
        skinPatchEye1Y          = 0,
        skinPatchEye2           = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        skinPatchEye2Scale      = 1,
        skinPatchEye2Angle      = 1,
        skinPatchEye2X          = 0,
        skinPatchEye2Y          = 0,
        --]]
        skinPatchSnout          = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        skinPatchSnoutScaleX    = 1,
        skinPatchSnoutScaleY    = 1,
        skinPatchSnoutAngle     = 1,
        skinPatchSnoutX         = 0,
        skinPatchSnoutY         = 0,
        upperlip                = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 11,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        upperlipWidthMultiplier = 1,
        lowerlip                = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 11,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        lowerlipWidthMultiplier = 1,
        mouthXAxis              = 0,
        mouthYAxis              = 2,
        eyes                    = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        eyeWidthMultiplier      = 1,
        eyeHeightMultiplier     = 1,
        eyeRotation             = 0,
        eyeYAxis                = 0,
        pupils                  = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        pupilSizeMultiplier     = 1,
        ears                    = {
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
        },
        earUnderHead            = true,
        earWidthMultiplier      = 1,
        earHeightMultiplier     = 1,
        earRotation             = 0,
        earYAxis                = 0, -- -2,-1,0,1,2
        brows                   = {
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
        },
        browsWidthMultiplier    = .5,
        browsWideMultiplier     = 1,
        browsDefaultBend        = 1,
        nose                    = {
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

        },
        noseXAxis               = 0, --  -2,-1,0,1,2
        noseYAxis               = 0, --  -3, -2,-1,0,1,2, 3
        noseWidthMultiplier     = 1,
        noseHeightMultiplier    = 1,
        leghair                 = {
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
        },
        legs                    = {
            shape     = 7,
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
        },
        legLength               = 5,
        legWidthMultiplier      = 1,
        leg1flop                = -1,
        leg2flop                = 1,
        legXAxis                = 0,
        armhair                 = {
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
        },
        arms                    = {
            shape     = 7,
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
        },
        armLength               = 700,
        armWidthMultiplier      = 1,
        arm1flop                = 1,
        arm2flop                = -1,
        hands                   = {
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
        },
        body                    = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 1,
            bgTex     = 1,
            fgTex     = 2,
            linePal   = 1,
            flipy     = 1,
            bgAlpha   = 5,
            fgAlpha   = 1,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        bodyWidthMultiplier     = 1,
        bodyHeightMultiplier    = 1,
        head                    = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 1,
            bgTex     = 1,
            fgTex     = 2,
            linePal   = 1,

            bgAlpha   = 5,
            fgAlpha   = 1,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,
        },
        headWidthMultiplier     = 1,
        headHeightMultiplier    = 1,
        hair                    = {
            shape     = 1,
            bgPal     = 4,
            fgPal     = 5,
            bgTex     = 1,
            fgTex     = 1,
            linePal   = 1,
            bgAlpha   = 5,
            fgAlpha   = 5,
            lineAlpha = 5,
            texRot    = 0,
            texScale  = 1,


        },
        hairWidthMultiplier     = 1,
        hairTension             = 0.001,
        neck                    = {
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
        },
        neckLength              = 700,
        neckWidthMultiplier     = 1,
        feet                    = {
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
        },
    }

    return parts, values
end