local audioHelper = require 'lib.audio-helper'
local gradient    = require 'lib.gradient'
local Timer       = require 'vendor.timer'
local scene       = {}

local parse       = require 'lib.parse-file'
local node        = require 'lib.node'
local skygradient = gradient.makeSkyGradient(16)

local hit         = require 'lib.hit'

local pink        = { 201 / 255, 135 / 255, 155 / 255 }
local yellow      = { 239 / 255, 219 / 255, 145 / 255 }
local green       = { 192 / 255, 212 / 255, 171 / 255 }
local colors      = { pink, yellow, green }
local tabs        = { "part", "colors", "pattern" }
local ui          = require 'lib.ui'
local Signal      = require 'vendor.signal'

local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end


function attachCallbacks()
    Signal.register('click-settings-scroll-area-item', function(x, y)
        partSettingsScrollable(false, x, y)
    end)

    Signal.register('click-scroll-list-item', function(x, y)
        scrollList(false, x, y)
    end)

    Signal.register('throw-settings-scroll-area', function(dxn, dyn, speed)
        if (math.abs(dyn) > math.abs(dxn)) then
            grid.isThrown = { velocity = speed / 10, direction = sign(dyn) }
        end
    end)

    Signal.register('throw-scroll-list', function(dxn, dyn, speed)
        if (math.abs(dyn) > math.abs(dxn)) then
            scroller.isThrown = { velocity = speed / 10, direction = sign(dyn) }
        end
    end)
end

function setCategories()
    categories = {}
    --if rootButton ~= nil then
    for i = 1, #parts do
        --if editingGuy.values.potatoHead and (parts[i].name == 'head' or parts[i].name == 'neck') then
        -- we dont want these categories when we are a potatohead!
        --else
        if parts[i].child ~= true then
            -- if rootButton == parts[i].kind and parts[i].child ~= true then
            table.insert(categories, parts[i].name)
        end
        --end
    end
    --end
end

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
        'assets/parts/hair2x.png' }

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

function loadUIImages()
    ui2 = {}

    ui2.tiles = love.graphics.newImage('assets/img/tiles/tiles.png')
    ui2.tiles2 = love.graphics.newImage('assets/img/tiles/tiles2.png')


    ui2.whiterects = {
        love.graphics.newImage('assets/ui/panels/whiterect1.png'),
        love.graphics.newImage('assets/ui/panels/whiterect2.png'),
        love.graphics.newImage('assets/ui/panels/whiterect3.png'),
        love.graphics.newImage('assets/ui/panels/whiterect4.png'),
        love.graphics.newImage('assets/ui/panels/whiterect5.png'),
        love.graphics.newImage('assets/ui/panels/whiterect6.png'),
        love.graphics.newImage('assets/ui/panels/whiterect7.png'),
    }


    ui2.bigbuttons        = {
        fiveguys = love.graphics.newImage('assets/ui/big-button-fiveguys.png'),
        fiveguysmask = love.graphics.newImage('assets/ui/big-button-fiveguys-mask.png'),
        editguys = love.graphics.newImage('assets/ui/big-button-editguys.png'),
        editguysmask = love.graphics.newImage('assets/ui/big-button-editguys-mask.png'),
        dice = love.graphics.newImage('assets/ui/big-button-dice.png'),
        dicemask = love.graphics.newImage('assets/ui/big-button-dice-mask.png'),
    }
    ui2.dots              = {
        love.graphics.newImage('assets/ui/colorpick/c1.png'),
        love.graphics.newImage('assets/ui/colorpick/c2.png'),
        love.graphics.newImage('assets/ui/colorpick/c3.png'),
        love.graphics.newImage('assets/ui/colorpick/c4.png'),
        love.graphics.newImage('assets/ui/colorpick/c5.png'),
        love.graphics.newImage('assets/ui/colorpick/c6.png'),
        love.graphics.newImage('assets/ui/colorpick/c7.png'),
    }

    ui2.uiheaders         = {
        love.graphics.newImage('assets/ui/panels/ui-header2.png', { linear = true }),
        love.graphics.newImage('assets/ui/panels/ui-header3.png', { linear = true }),
        love.graphics.newImage('assets/ui/panels/ui-header4.png', { linear = true })
    }
    ui2.tabui             = {
        love.graphics.newImage('assets/ui/panels/tab1.png'),
        love.graphics.newImage('assets/ui/panels/tab2.png'),
        love.graphics.newImage('assets/ui/panels/tab3.png'),
    }
    ui2.tabuimask         = {
        love.graphics.newImage('assets/ui/panels/tab1-mask.png'),
        love.graphics.newImage('assets/ui/panels/tab2-mask.png'),
        love.graphics.newImage('assets/ui/panels/tab3-mask.png'),
    }
    ui2.tabuilogo         = {
        love.graphics.newImage('assets/ui/panels/tab1-logo.png'),
        love.graphics.newImage('assets/ui/panels/tab2-logoC2.png'),
        love.graphics.newImage('assets/ui/panels/tab3-logo.png'),
    }
    ui2.colorpickerui     = {
        love.graphics.newImage('assets/ui/colorpick/uifill.png', { linear = true }),
        love.graphics.newImage('assets/ui/colorpick/uipattern.png', { linear = true }),
        love.graphics.newImage('assets/ui/colorpick/uiline.png', { linear = true }),
    }
    ui2.colorpickeruimask = {
        love.graphics.newImage('assets/ui/colorpick/uifill-mask.png', { linear = true }),
        love.graphics.newImage('assets/ui/colorpick/uipattern-mask.png', { linear = true }),
        love.graphics.newImage('assets/ui/colorpick/uiline-mask.png', { linear = true }),
    }
    ui2.circles           = {
        love.graphics.newImage('assets/ui/circle1.png'),
        love.graphics.newImage('assets/ui/circle2.png'),
        love.graphics.newImage('assets/ui/circle3.png'),
        love.graphics.newImage('assets/ui/circle4.png'),
    }
    ui2.rects             = {
        love.graphics.newImage('assets/ui/rect1.png'),
        love.graphics.newImage('assets/ui/rect2.png'),
    }

    ui2.sliderimg         = {
        track1 = love.graphics.newImage('assets/ui/interfaceparts/slider-track1.png'),
        thumb1 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb1.png'),
        thumb1Mask = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb1-mask.png'),
        track2 = love.graphics.newImage('assets/ui/interfaceparts/slider-track2.png'),
        thumb2 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb2.png'),
        thumb2Mask = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb2-mask.png'),
        thumb3 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb3.png'),
        thumb4 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb4.png'),
        thumb5 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb5.png'),
    }
    ui2.toggle            = {
        body1 = love.graphics.newImage('assets/ui/interfaceparts/togglebody1.png'),
        body2 = love.graphics.newImage('assets/ui/interfaceparts/togglebody2.png'),
        body3 = love.graphics.newImage('assets/ui/interfaceparts/togglebody3.png'),
        thumb1 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb1.png'),
        thumb2 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb2.png'),
        thumb3 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb3.png'),
    }

    ui2.icons             = {
        handspinned = love.graphics.newImage('assets/ui/icons/hands-pinned.png'),
        handsfree = love.graphics.newImage('assets/ui/icons/hands-free.png'),
        feetpinned = love.graphics.newImage('assets/ui/icons/feet-pinned.png'),
        feetfree = love.graphics.newImage('assets/ui/icons/feet-free.png'),
        mouthsmall = love.graphics.newImage('assets/ui/icons/mouth-small.png'),
        mouthtall = love.graphics.newImage('assets/ui/icons/mouth-tall.png'),
        mouthnarrow = love.graphics.newImage('assets/ui/icons/mouth-narrow.png'),
        mouthwide = love.graphics.newImage('assets/ui/icons/mouth-wide.png'),
        browsup = love.graphics.newImage('assets/ui/icons/brows-up.png'),
        browsdown = love.graphics.newImage('assets/ui/icons/brows-down.png'),
        facesmall = love.graphics.newImage('assets/ui/icons/face-small.png'),
        facebig = love.graphics.newImage('assets/ui/icons/face-big.png'),
        bodyfliph1 = love.graphics.newImage('assets/ui/icons/body-fliph1.png'),
        bodyfliph2 = love.graphics.newImage('assets/ui/icons/body-fliph2.png'),
        bodyflipv1 = love.graphics.newImage('assets/ui/icons/body-flipv1.png'),
        bodyflipv2 = love.graphics.newImage('assets/ui/icons/body-flipv2.png'),
        headfliph1 = love.graphics.newImage('assets/ui/icons/head-fliph1.png'),
        headfliph2 = love.graphics.newImage('assets/ui/icons/head-fliph2.png'),
        headflipv1 = love.graphics.newImage('assets/ui/icons/head-flipv1.png'),
        headflipv2 = love.graphics.newImage('assets/ui/icons/head-flipv2.png'),
        headsmall = love.graphics.newImage('assets/ui/icons/head-small.png'),
        headtall = love.graphics.newImage('assets/ui/icons/head-tall.png'),
        headnarrow = love.graphics.newImage('assets/ui/icons/head-narrow.png'),
        headwide = love.graphics.newImage('assets/ui/icons/head-wide.png'),
        bodysmall = love.graphics.newImage('assets/ui/icons/body-small.png'),
        bodytall = love.graphics.newImage('assets/ui/icons/body-tall.png'),
        bodynarrow = love.graphics.newImage('assets/ui/icons/body-narrow.png'),
        bodywide = love.graphics.newImage('assets/ui/icons/body-wide.png'),
        bodypotato = love.graphics.newImage('assets/ui/icons/body-potato.png'),
        bodynonpotato = love.graphics.newImage('assets/ui/icons/body-nonpotato.png'),
        brow1 = love.graphics.newImage('assets/ui/icons/brow-1.png'),
        brow10 = love.graphics.newImage('assets/ui/icons/brow-10.png'),
        brownarrow = love.graphics.newImage('assets/ui/icons/brow-narrow.png'),
        browwide = love.graphics.newImage('assets/ui/icons/brow-wide.png'),
        browthick = love.graphics.newImage('assets/ui/icons/brow-thick.png'),
        browthin = love.graphics.newImage('assets/ui/icons/brow-thin.png'),
        hairthin = love.graphics.newImage('assets/ui/icons/hair-thin.png'),
        hairthick = love.graphics.newImage('assets/ui/icons/hair-thick.png'),
        hairtloose = love.graphics.newImage('assets/ui/icons/hair-loose.png'),
        hairthight = love.graphics.newImage('assets/ui/icons/hair-thight.png'),
        nosedown = love.graphics.newImage('assets/ui/icons/nose-down.png'),
        noseup = love.graphics.newImage('assets/ui/icons/nose-up.png'),
        nosenarrow = love.graphics.newImage('assets/ui/icons/nose-narrow.png'),
        nosewide = love.graphics.newImage('assets/ui/icons/nose-wide.png'),
        nosesmall = love.graphics.newImage('assets/ui/icons/nose-small.png'),
        nosetall = love.graphics.newImage('assets/ui/icons/nose-tall.png'),
        mouthup = love.graphics.newImage('assets/ui/icons/mouth-up.png'),
        mouthdown = love.graphics.newImage('assets/ui/icons/mouth-down.png'),
        pupilsmall = love.graphics.newImage('assets/ui/icons/pupil-small.png'),
        pupilbig = love.graphics.newImage('assets/ui/icons/pupil-big.png'),
        eyesmall1 = love.graphics.newImage('assets/ui/icons/eye-small.png'),
        eyesmall2 = love.graphics.newImage('assets/ui/icons/eye-small2.png'),
        eyewide = love.graphics.newImage('assets/ui/icons/eye-wide.png'),
        eyetall = love.graphics.newImage('assets/ui/icons/eye-tall.png'),
        eyeccw = love.graphics.newImage('assets/ui/icons/eye-ccw.png'),
        eyecw = love.graphics.newImage('assets/ui/icons/eye-cw.png'),
        eyedown = love.graphics.newImage('assets/ui/icons/eye-down.png'),
        eyeup = love.graphics.newImage('assets/ui/icons/eye-up.png'),
        eyefar = love.graphics.newImage('assets/ui/icons/eye-far.png'),
        eyeclose = love.graphics.newImage('assets/ui/icons/eye-close.png'),
        earccw = love.graphics.newImage('assets/ui/icons/ear-ccw.png'),
        earcw = love.graphics.newImage('assets/ui/icons/ear-cw.png'),
        earback = love.graphics.newImage('assets/ui/icons/ear-back.png'),
        earfront = love.graphics.newImage('assets/ui/icons/ear-front.png'),
        earup = love.graphics.newImage('assets/ui/icons/ear-up.png'),
        eardown = love.graphics.newImage('assets/ui/icons/ear-down.png'),
        earsmall = love.graphics.newImage('assets/ui/icons/ear-small.png'),
        earbig = love.graphics.newImage('assets/ui/icons/ear-big.png'),
        patternccw = love.graphics.newImage('assets/ui/icons/pattern-ccw.png'),
        patterncw = love.graphics.newImage('assets/ui/icons/pattern-cw.png'),
        patternfine = love.graphics.newImage('assets/ui/icons/pattern-fine.png'),
        patterncoarse = love.graphics.newImage('assets/ui/icons/pattern-coarse.png'),
        patterntransparent = love.graphics.newImage('assets/ui/icons/pattern-transparent.png'),
        patternopaque = love.graphics.newImage('assets/ui/icons/pattern-opaque.png'),
        legthin = love.graphics.newImage('assets/ui/icons/legs-thin.png'),
        legthick = love.graphics.newImage('assets/ui/icons/legs-thick.png'),
        legflip1 = love.graphics.newImage('assets/ui/icons/legs-flipy1.png'),
        legflip2 = love.graphics.newImage('assets/ui/icons/legs-flipy2.png'),
        legshort = love.graphics.newImage('assets/ui/icons/legs-short.png'),
        leglong = love.graphics.newImage('assets/ui/icons/legs-long.png'),
        legnarrow = love.graphics.newImage('assets/ui/icons/legs-narrow.png'),
        legwide = love.graphics.newImage('assets/ui/icons/legs-wide.png'),
        legstance1 = love.graphics.newImage('assets/ui/icons/legs-stance1.png'),
        legstance2 = love.graphics.newImage('assets/ui/icons/legs-stance2.png'),
        armsshort = love.graphics.newImage('assets/ui/icons/arms-short.png'),
        armslong = love.graphics.newImage('assets/ui/icons/arms-long.png'),
        armsthin = love.graphics.newImage('assets/ui/icons/arms-thin.png'),
        armsthick = love.graphics.newImage('assets/ui/icons/arms-thick.png'),
        armsflip1 = love.graphics.newImage('assets/ui/icons/arms-flip1.png'),
        armsflip2 = love.graphics.newImage('assets/ui/icons/arms-flip2.png'),
        neckshort = love.graphics.newImage('assets/ui/icons/neck-short.png'),
        necklong = love.graphics.newImage('assets/ui/icons/neck-long.png'),
        neckthin = love.graphics.newImage('assets/ui/icons/neck-thin.png'),
        neckthick = love.graphics.newImage('assets/ui/icons/neck-thick.png'),
        footwide = love.graphics.newImage('assets/ui/icons/foot-wide.png'),
        footnarrow = love.graphics.newImage('assets/ui/icons/foot-narrow.png'),
        footshort = love.graphics.newImage('assets/ui/icons/foot-short.png'),
        foottall = love.graphics.newImage('assets/ui/icons/foot-tall.png'),
        handwide = love.graphics.newImage('assets/ui/icons/hand-wide.png'),
        handnarrow = love.graphics.newImage('assets/ui/icons/hand-narrow.png'),
        handshort = love.graphics.newImage('assets/ui/icons/hand-short.png'),
        handtall = love.graphics.newImage('assets/ui/icons/hand-tall.png'),
        ['patchPV.txless'] = love.graphics.newImage('assets/ui/icons/patch-Xless.png'),
        ['patchPV.txmore'] = love.graphics.newImage('assets/ui/icons/patch-Xmore.png'),
        ['patchPV.tyless'] = love.graphics.newImage('assets/ui/icons/patch-Yless.png'),
        ['patchPV.tymore'] = love.graphics.newImage('assets/ui/icons/patch-Ymore.png'),
        ['patchPV.rless'] = love.graphics.newImage('assets/ui/icons/patch-Angleless.png'),
        ['patchPV.rmore'] = love.graphics.newImage('assets/ui/icons/patch-Anglemore.png'),
        ['patchPV.sxless'] = love.graphics.newImage('assets/ui/icons/patch-ScaleXless.png'),
        ['patchPV.sxmore'] = love.graphics.newImage('assets/ui/icons/patch-ScaleXmore.png'),
        ['patchPV.syless'] = love.graphics.newImage('assets/ui/icons/patch-ScaleYless.png'),
        ['patchPV.symore'] = love.graphics.newImage('assets/ui/icons/patch-ScaleYmore.png'),
    }

    ui2.scrollIcons       = {
        body = love.graphics.newImage('assets/ui/icons/body.png'),
        bodyMask = love.graphics.newImage('assets/ui/icons/body-mask.png'),
        neck = love.graphics.newImage('assets/ui/icons/neck.png'),
        neckMask = love.graphics.newImage('assets/ui/icons/neck-mask.png'),
        arms2 = love.graphics.newImage('assets/ui/icons/arm.png'),
        arms2Mask = love.graphics.newImage('assets/ui/icons/arm-mask.png'),
        arms = love.graphics.newImage('assets/ui/icons/arm.png'),
        armsMask = love.graphics.newImage('assets/ui/icons/arm-mask.png'),
        armhair = love.graphics.newImage('assets/ui/icons/armhair.png'),
        armhairMask = love.graphics.newImage('assets/ui/icons/armhair-mask.png'),
        legs = love.graphics.newImage('assets/ui/icons/leg.png'),
        legsMask = love.graphics.newImage('assets/ui/icons/leg-mask.png'),
        legs2 = love.graphics.newImage('assets/ui/icons/leg.png'),
        legs2Mask = love.graphics.newImage('assets/ui/icons/leg-mask.png'),
        leghair = love.graphics.newImage('assets/ui/icons/leghair.png'),
        leghairMask = love.graphics.newImage('assets/ui/icons/leghair-mask.png'),
        hands = love.graphics.newImage('assets/ui/icons/hands.png'),
        handsMask = love.graphics.newImage('assets/ui/icons/hands-mask.png'),
        feet = love.graphics.newImage('assets/ui/icons/feet.png'),
        feetMask = love.graphics.newImage('assets/ui/icons/feet-mask.png'),
        eyes = love.graphics.newImage('assets/ui/icons/eyes.png'),
        eyesMask = love.graphics.newImage('assets/ui/icons/eyes-mask.png'),
        nose = love.graphics.newImage('assets/ui/icons/nose.png'),
        noseMask = love.graphics.newImage('assets/ui/icons/nose-mask.png'),
        ears = love.graphics.newImage('assets/ui/icons/ears.png'),
        earsMask = love.graphics.newImage('assets/ui/icons/ears-mask.png'),
        brows = love.graphics.newImage('assets/ui/icons/brows.png'),
        browsMask = love.graphics.newImage('assets/ui/icons/brows-mask.png'),
        hair = love.graphics.newImage('assets/ui/icons/hair.png'),
        hairMask = love.graphics.newImage('assets/ui/icons/hair-mask.png'),
        skinPatchEye1 = love.graphics.newImage('assets/ui/icons/skinpatchEye1.png'),
        skinPatchEye1Mask = love.graphics.newImage('assets/ui/icons/skinpatchEye1-mask.png'),
        skinPatchEye2 = love.graphics.newImage('assets/ui/icons/skinpatchEye2.png'),
        skinPatchEye2Mask = love.graphics.newImage('assets/ui/icons/skinpatchEye2-mask.png'),
        skinPatchSnout = love.graphics.newImage('assets/ui/icons/skinpatchSnout.png'),
        skinPatchSnoutMask = love.graphics.newImage('assets/ui/icons/skinpatchSnout-mask.png'),
        teeth = love.graphics.newImage('assets/ui/icons/teeth.png'),
        teethMask = love.graphics.newImage('assets/ui/icons/teeth-mask.png'),
        lowerlip = love.graphics.newImage('assets/ui/icons/lowerlip.png'),
        lowerlipMask = love.graphics.newImage('assets/ui/icons/lowerlip-mask.png'),
        upperlip = love.graphics.newImage('assets/ui/icons/upperlip.png'),
        upperlipMask = love.graphics.newImage('assets/ui/icons/upperlip-mask.png'),
        head = love.graphics.newImage('assets/ui/icons/head.png'),
        headMask = love.graphics.newImage('assets/ui/icons/head-mask.png'),
        pupils = love.graphics.newImage('assets/ui/icons/pupil.png'),
        pupilsMask = love.graphics.newImage('assets/ui/icons/pupil-mask.png'),
        patches = love.graphics.newImage('assets/ui/icons/patches.png'),
        patchesMask = love.graphics.newImage('assets/ui/icons/patches-mask.png'),
        mouth = love.graphics.newImage('assets/ui/icons/mouth.png'),
        mouthMask = love.graphics.newImage('assets/ui/icons/mouth-mask.png'),
        eyes2 = love.graphics.newImage('assets/ui/icons/eyes.png'),
        eyes2Mask = love.graphics.newImage('assets/ui/icons/eyes-mask.png'),
    }
    ui2.headz             = {}
    for i = 1, 8 do
        ui2.headz[i] = {
            img = love.graphics.newImage('assets/ui/blups/headz' .. i .. '.png'),
            x = love.math.random(),
            y = love.math.random(),
            r = love.math.random() * math.pi * 2
        }
    end
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path

        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
            -- myWorld:emit('breath', biped)
        end
    end
    --print('handling audio message from editGuy')
end

function scene.load()
    bgColor = creamColor


    loadUIImages()
    attachCallbacks()
    scroller = {
        xPos = 0,
        position = 5,
        isDragging = false,
        isThrown = nil,
        visibleOnScreen = 5
    }
    grid = {
        position = 0,
        isDragging = false,
        isThrown = nil,
        data = nil -- extra data about scissor area min max and scrolling yes/no
    }
    uiState = {
        selectedTab = 'part',
        selectedCategory = 'body',
        selectedColoringLayer = 'bgPal'
    }

    uiTickSound = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
    uiClickSound = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')

    parts = generateParts()
    categories = {}
    setCategories()

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });
end

function scene.unload()

end

local function updateTheScrolling(dt, thrown, pos)
    local oldPos = pos
    if (thrown) then
        thrown.velocity = thrown.velocity * .9

        pos = pos + ((thrown.velocity * thrown.direction) * .1 * dt)

        if (math.floor(oldPos) ~= math.floor(pos)) then
            if grid.data and not grid.data.noScroll then
                playSound(uiTickSound)
            end
        end
        if (thrown.velocity < 0.01) then
            thrown.velocity = 0
            thrown = nil
        end
    end
    return pos
end

function scene.update(dt)
    if introSound:isPlaying() then
        local volume = introSound:getVolume()
        introSound:setVolume(volume * .90)
        if (volume < 0.01) then
            introSound:stop()
        end
    end
    if splashSound:isPlaying() then
        local volume = splashSound:getVolume()
        splashSound:setVolume(volume * .90)
        if volume < 0.01 then
            splashSound:stop()
        end
    end



    --delta = delta + dt
    Timer.update(dt)

    if grid and grid.data and grid.data.min then
        if grid.position > grid.data.min then
            grid.position = grid.data.min
        end
        if grid.position < grid.data.max then
            grid.position = grid.data.max
        end
    end

    scroller.position = updateTheScrolling(dt, scroller.isThrown, scroller.position)

    if grid then
        grid.position = updateTheScrolling(dt, grid.isThrown, grid.position)
    end
end

local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end

function setSecondaryColor(alpha)
    --0xf8 / 255, 0xa0 / 255, 0x67 / 255,
    love.graphics.setColor(pink[1], pink[2], pink[3], alpha)
end

function setTernaryColor(alpha)
    love.graphics.setColor(green[1], green[2], green[3], alpha)
end

local function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

-- scroll list is the main thing that has all categories
function scrollList(draw, clickX, clickY)
    local w, h = love.graphics.getDimensions()
    local margin = w / 80

    local marginHeight = 2
    local size = (h / scroller.visibleOnScreen) - marginHeight * 2

    scroller.xPos = margin --h / 12 ----margin * 2 -- this is updating a global!!!

    local offset = scroller.position % 1
    local xPos = scroller.xPos

    if #categories > 0 then
        for i = -1, (scroller.visibleOnScreen - 1) do
            local newScroll = i + offset
            local yPosition = marginHeight + (newScroll * (h / scroller.visibleOnScreen))
            local index = math.ceil( -scroller.position) + i

            index = (index % #categories) + 1
            if index < 1 then
                index = index + #categories
            end
            if index > #categories then
                index = 1
            end
            local alpha = 0.8

            local whiterectIndex = math.ceil( -scroller.position) + i
            whiterectIndex = (whiterectIndex % #ui2.whiterects) + 1
            local marginb = size / 10
            local scaleX, scaleY = createFittingScale(ui2.whiterects[whiterectIndex], size, size)


            if draw then
                local sm = 1
                local sm2 = 1
                if uiState.selectedCategory == categories[index] then
                    local offset = math.sin(love.timer.getTime() * 5) * 0.02
                    sm = sm + offset
                    sm2 = sm2 + offset + offset + offset
                    alpha = 1
                    --pixelOffset = (ui2.scrollIcons[categories[index]]:getWidth()) * offset
                    --print(pixelOffset)
                end

                love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha)

                if uiState.selectedCategory == categories[index] then
                    love.graphics.setColor(.1, .1, .1, 0.2)
                    love.graphics.draw(ui2.whiterects[whiterectIndex], xPos + 4, yPosition + 4, 0,
                        scaleX, scaleY)
                end
                love.graphics.setColor(255 / 255, 240 / 255, 200 / 255, alpha)
                love.graphics.draw(ui2.whiterects[whiterectIndex], xPos, yPosition, 0, scaleX, scaleY)

                love.graphics.setColor(0.5, 0.5, 0.5, alpha)
                if uiState.selectedCategory == categories[index] then
                    --setSecondaryColor(alpha)
                    love.graphics.setColor(0, 0, 0, alpha)
                    local sx, sy = createFittingScale(ui2.rects[1], size, size)

                    local diffx = ((sx * sm) - sx) * ui2.rects[1]:getWidth()
                    local diffy = ((sy * sm) - sy) * ui2.rects[1]:getHeight()

                    love.graphics.draw(ui2.rects[1], xPos - diffx / 2, yPosition - diffy / 2, 0, sx * sm, sy * sm)
                    love.graphics.setColor(0, 0, 0, alpha)
                end


                if (ui2.scrollIcons[categories[index]]) then
                    local sx, sy = createFittingScale(ui2.scrollIcons[categories[index]], size, size)

                    local diffx = ((sx * sm2) - sx) * ui2.scrollIcons[categories[index]]:getWidth()
                    local diffy = ((sy * sm2) - sy) * ui2.scrollIcons[categories[index]]:getHeight()

                    love.graphics.draw(ui2.scrollIcons[categories[index]], xPos - diffx / 2, yPosition - diffy / 2, 0,
                        sx * sm2,
                        sy * sm2,
                        alpha)

                    local m = ui2.scrollIcons[categories[index] .. 'Mask']

                    if (m) then
                        if findPart(categories[index]).kind == 'body' then
                            setTernaryColor(alpha)
                        else
                            setSecondaryColor(alpha)
                        end

                        local sx, sy = createFittingScale(m, size, size)
                        love.graphics.draw(m, xPos - diffx / 2, yPosition - diffy / 2, 0, sx * sm2, sy * sm2)
                    end
                else
                    love.graphics.print(categories[index], xPos, yPosition)
                end
            else
                if (hit.pointInRect(clickX, clickY, xPos, yPosition, size, size)) then
                    uiState.selectedCategory = categories[index]
                    local f = findPart(uiState.selectedCategory)
                    if f.children then
                        selectedChildCategory = f.children[1]
                    end
                    if f.kind == 'body' then
                        -- tweenCameraToHeadAndBody()
                    end
                    if f.kind == 'head' then
                        --tweenCameraToHead()
                    end
                    playSound(uiClickSound)
                end
            end
        end
    end
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    -- local x, y = love.mouse.getPosition()

    -- if x >= 0 and x <= scrollListXPosition then
    -- this could be clicking in the head or body buttons
    --  headOrBody(false, x, y)
    --end


    local scrollItemWidth = (h / scroller.visibleOnScreen)
    if x >= scroller.xPos and x < scroller.xPos + scrollItemWidth then
        scroller.isDragging = true
        scroller.isThrown = nil
        -- scrollListIsThrown = nil
        print('hello!')
        gesture.add('scroll-list', id, love.timer.getTime(), x, y)
    end
    if (grid and grid.data) then
        if (hit.pointInRect(x, y, grid.data.x, grid.data.y, grid.data.w, grid.data.h)) then
            grid.isDragging = true
            grid.isThrown = nil
            gesture.add('settings-scroll-area', id, love.timer.getTime(), x, y)
        end
    end
end


local function pointerMoved(x, y, dx, dy, id)
    local somethingWasDragged = false


    -- only do this when the scroll ui is visible (always currently)
    if scroller.isDragging and not somethingWasDragged then
        local w, h = love.graphics.getDimensions()
        local oldScrollPos = scroller.position
        scroller.position = scroller.position + dy / (h / scroller.visibleOnScreen)
        local newScrollPos = scroller.position
        if (math.floor(oldScrollPos) ~= math.floor(newScrollPos)) then
            -- play sound
            playSound(uiTickSound)
        end
    end

    if grid and grid.isDragging and not somethingWasDragged then
        local old = grid.position

        grid.position = grid.position + dy / grid.data.cellsize

        if math.floor(old) ~= math.floor(grid.position) then
            if not grid.data.noScroll then
                playSound(uiTickSound)
            end
        end
    end
end

function pointerReleased(x, y, id)
    scroller.isDragging = false
    --grid.isDragging = false

    gesture.maybeTrigger(id, x, y)
    -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen

    --partSettingsSurroundings(false, x, y)
    --collectgarbage()
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    pointerPressed(x, y, id)
    ui.addToPressedPointers(x, y, id)
end

function love.mousepressed(x, y, button, istouch, presses)
    if not istouch then
        pointerPressed(x, y, 'mouse')
        ui.addToPressedPointers(x, y, 'mouse')
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if not istouch then
        pointerMoved(x, y, dx, dy, 'mouse')
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    pointerMoved(x, y, dx, dy, id)
end

function love.mousereleased(x, y, button, istouch)
    lastDraggedElement = nil
    if not istouch then
        pointerReleased(x, y, 'mouse')
        ui.removeFromPressedPointers('mouse')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
    ui.removeFromPressedPointers(id)
end

function scene.draw()
    local w, h = love.graphics.getDimensions()
    if true then
        love.graphics.setColor(1, 1, 1, 1)
        --ui.handleMouseClickStart()
        love.graphics.clear(creamColor)

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(0, 0, 0)

        -- do these via vector sketch snf the scene graph
        love.graphics.setColor(0, 0, 0, 0.05)
        love.graphics.draw(ui2.tiles, 400, 0, .1)
        love.graphics.setColor(1, 0, 0, 0.05)
        love.graphics.draw(ui2.tiles2, 1000, 300, math.pi / 2, 2, 2)

        for i = 1, #ui2.headz do
            love.graphics.setColor(0, 0, 0, 0.05)
            love.graphics.draw(ui2.headz[i].img, ui2.headz[i].x * w, ui2.headz[i].y * h, ui2.headz[i].r)
        end

        love.graphics.setColor(1, 1, 1)
    end
    scrollList(true)
end

return scene
