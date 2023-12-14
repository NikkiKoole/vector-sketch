local pink       = { 201 / 255, 135 / 255, 155 / 255 }
local yellow     = { 239 / 255, 219 / 255, 145 / 255 }
local green      = { 192 / 255, 212 / 255, 171 / 255 }
local colors     = { pink, yellow, green }
local tabs       = { "part", "colors", "pattern" }
local hit        = require 'lib.hit'
local numbers    = require 'lib.numbers'
local ui         = require "lib.ui"
local text       = require 'lib.text'

local imageCache = {}

local dna        = require 'src.dna'
require 'src.box2dGuyCreation'
local creation = dna.getCreation()

function changePart(name)
    updatePart(name)
end

function tweenCameraToHeadAndBody()

end

function tweenCameraToHead()

end

function growl()

end

function setSelectedCategory(name)
    uiState.selectedCategory = name

    local result = findPart(uiState.selectedCategory)
    if result.children then
        uiState.selectedChildCategory = result.children[1]
    end
    return result
end

local function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

local function setSecondaryColor(alpha)
    --0xf8 / 255, 0xa0 / 255, 0x67 / 255,
    love.graphics.setColor(pink[1], pink[2], pink[3], alpha)
end

local function setTernaryColor(alpha)
    love.graphics.setColor(green[1], green[2], green[3], alpha)
end

local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
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
        thumb6 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb6.png'),
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
        chestHairInner = love.graphics.newImage('assets/ui/icons/chesthair-inner.png'),
        chestHairOuter = love.graphics.newImage('assets/ui/icons/chesthair-outer.png'),
        neckYes = love.graphics.newImage('assets/ui/icons/neck-yes.png'),
        neckNo = love.graphics.newImage('assets/ui/icons/neck-no.png'),
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
        chestHair = love.graphics.newImage('assets/ui/icons/chesthair.png'),
        chestHairMask = love.graphics.newImage('assets/ui/icons/chesthair-mask.png'),
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

local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end

local function drawChildPicker(draw, startX, currentY, width, clickX, clickY)
    local childrenTabHeight = 0

    local p = findPart(uiState.selectedCategory)
    if p.children then
        childrenTabHeight = width / 5 --((width-cellMargin*2)/(#p.children * 1.5))
        if draw then
            drawTapesForBackground(startX, currentY, width, childrenTabHeight * 1.2)
        end

        local offset = childrenTabHeight * 0.1
        for i = 1, #p.children do
            local xPosition = offset + startX + ((i - 1) * childrenTabHeight)
            local yPosition = currentY + offset
            if draw then
                local sx, sy = createFittingScale(ui2.whiterects[1], childrenTabHeight, childrenTabHeight)

                love.graphics.setColor(0, 0, 0, 0.1)
                love.graphics.draw(ui2.whiterects[1], xPosition + 2, yPosition + 2, 0, sx, sy)
                love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
                love.graphics.draw(ui2.whiterects[1], xPosition, yPosition, 0, sx, sy)

                if uiState.selectedChildCategory == p.children[i] then
                    love.graphics.setColor(0, 0, 0, .8)
                    local sx, sy = createFittingScale(ui2.rects[1], childrenTabHeight, childrenTabHeight)
                    love.graphics.draw(ui2.rects[1], xPosition, yPosition, 0, sx, sy)
                end

                sx, sy = createFittingScale(ui2.scrollIcons[p.children[i]], childrenTabHeight, childrenTabHeight)

                setSecondaryColor(1)
                love.graphics.draw(ui2.scrollIcons[p.children[i] .. 'Mask'], xPosition, yPosition, 0, sx, sy)
                love.graphics.setColor(0, 0, 0, .8)
                love.graphics.draw(ui2.scrollIcons[p.children[i]], xPosition, yPosition, 0, sx, sy)
            else
                -- todo this isnt working because the scrollarea is not correct so this will only be called whne i click in the scrollarea
                -- print(clickX, clickY,  xPosition, yPosition, childrenTabHeight, childrenTabHeight)
                if (hit.pointInRect(clickX, clickY, xPosition, yPosition, childrenTabHeight, childrenTabHeight)) then
                    uiState.selectedChildCategory = p.children[i]
                    playSound(uiClickSound)
                end
            end
        end
    end
    return childrenTabHeight * 1.2
end

function configPanelSurroundings(draw, clickX, clickY)
    -- this thing will render the panel where the big scrollable area is in
    -- also the tabs on top and the sliders/other settngs in the header.
    --   basically everything except the scrollable thing itself..

    local startX, startY, width, height = configPanelPanelDimensions()
    local tabWidth, tabHeight, marginBetweenTabs = configPanelTabsDimensions(tabs, width)

    local currentY = startY + tabHeight
    local tabWidthMultipliers = { 0.85, 1.05, 1.10 }

    if draw then
        -- these dimensions come from the tab images, don't know which precisely
        local iw = 650
        local ih = 1240

        local scaleX = width / iw
        local scaleY = height / ih

        local uiOffX = 18 * scaleX
        local uiOffY = 40 * scaleY

        local drawunder = { { 2, 3, 1 }, { 1, 3, 2 }, { 1, 2, 3 } }

        local selectedTabIndex = -1
        for i = 1, #tabs do
            if uiState.selectedTab == tabs[i] then
                selectedTabIndex = i
            end
        end

        for i = 1, #drawunder[selectedTabIndex] do
            local index = drawunder[selectedTabIndex][i]
            love.graphics.setColor(colors[index][1], colors[index][2], colors[index][3], 1)
            love.graphics.draw(ui2.tabuimask[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.tabui[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)

            if true then
                local w1 = (tabWidth) - marginBetweenTabs
                local h1 = tabHeight

                local x = nil
                if (index == 1) then
                    x = startX
                elseif (index == 2) then
                    x = startX + tabWidthMultipliers[1] * tabWidth
                elseif (index == 3) then
                    x = startX + (tabWidthMultipliers[1] + tabWidthMultipliers[2]) * tabWidth
                end

                local sx, sy = createFittingScale(ui2.tabuilogo[index], w1 * 0.9, h1 * 0.9)
                if index == 2 then
                    if selectedTabIndex == index then
                        love.graphics.setColor(1, 1, 1, 0.9)
                    else
                        love.graphics.setColor(1, 1, 1, 0.3)
                    end
                else
                    if selectedTabIndex == index then
                        love.graphics.setColor(0, 0, 0, 0.9)
                    else
                        love.graphics.setColor(0, 0, 0, 0.3)
                    end
                end
                love.graphics.draw(ui2.tabuilogo[index], x + w1 * 0.05, startY + h1 * 0.05, 0, sx, sy)
            end
        end
    end

    for i = 1, #tabs do
        local x = nil
        if (i == 1) then
            x = startX
        elseif (i == 2) then
            x = startX + tabWidthMultipliers[1] * tabWidth
        elseif (i == 3) then
            x = startX + (tabWidthMultipliers[1] + tabWidthMultipliers[2]) * tabWidth
        end

        local y = startY
        local w1 = (tabWidth * tabWidthMultipliers[i]) - marginBetweenTabs
        local h1 = tabHeight

        if draw then

        else
            if (hit.pointInRect(clickX, clickY, x, y, w1, h1)) then
                uiState.selectedTab = tabs[i]
                playSound(uiClickSound)
            end
        end
    end

    local minimumHeight = drawImmediateSlidersEtc(false, startX, currentY, width, uiState.selectedCategory)
    currentY = currentY + minimumHeight
    drawChildPicker(draw, startX, currentY, width, clickX, clickY)

    if findPart(uiState.selectedCategory).children then
        local minimumHeight = drawImmediateSlidersEtc(false, startX, currentY, width, uiState.selectedChildCategory)
        currentY = currentY + minimumHeight
    end
end


local function getValueByPath(root, path)
    local keys = {}
    for key in string.gmatch(path, '([^%.]+)') do
        table.insert(keys, key)
    end

    local current = root
    for _, key in ipairs(keys) do
        if type(current) == "table" and current[key] ~= nil then
            current = current[key]
        else
            return nil -- Key not found or not a table
        end
    end

    return current
end

local function setValueByPath(root, path, value)
    local keys = {}
    for key in string.gmatch(path, '([^%.]+)') do
        table.insert(keys, key)
    end

    local current = root
    local lastKey = table.remove(keys) -- Remove the last key to handle it separately

    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            current[key] = {} -- Create tables if they don't exist
        end
        current = current[key]
    end

    current[lastKey] = value
end


local function draw_toggle_with_2_buttons(prop, startX, currentY, buttonSize, sliderWidth, toggleValue, toggleFunc, img1,
                                          img2)
    local sx, sy = createFittingScale(ui2.rects[1], buttonSize, buttonSize)

    love.graphics.setColor(0, 0, 0, .1)
    love.graphics.draw(ui2.rects[1], startX, currentY, 0, sx, sy)
    if img1 then
        love.graphics.setColor(0, 0, 0, 1)
        local imgsx, imgsy = createFittingScale(img1, buttonSize, buttonSize)
        love.graphics.draw(img1, startX, currentY, 0, imgsx, imgsy)
    end
    love.graphics.setColor(0, 0, 0, 1)
    local less = ui.getUIRect('less-' .. prop, startX, currentY, buttonSize, buttonSize)
    if less then
        growl(1 + love.math.random() * 2)

        toggleFunc(false)
    end
    local offset = buttonSize

    local sx, sy = createFittingScale(ui2.toggle.body3, sliderWidth, buttonSize)
    local scale = math.min(sx, sy)

    local tbw, tbh = ui2.toggle.body3:getDimensions()
    local extraOffset = 0

    if tbw * scale < sliderWidth then
        extraOffset = (sliderWidth - (tbw * scale)) / 2
        offset = offset
    end

    local yOff = (buttonSize - (tbh * scale)) / 2
    local yOffThumb = (scale * ui2.toggle.thumb3:getHeight() / 2)
    love.graphics.draw(ui2.toggle.body3, offset + extraOffset + startX, yOff + currentY, 0, scale, scale)

    if toggleValue then
        love.graphics.draw(ui2.toggle.thumb3, offset + extraOffset + startX + (15 * scale),
            yOff + currentY + yOffThumb,
            0,
            scale,
            scale)
    else
        love.graphics.draw(ui2.toggle.thumb3,
            offset + extraOffset + startX + -(15 * scale) +
            (((tbw * scale)) - (ui2.toggle.thumb3:getWidth() * scale)),
            yOff + currentY + yOffThumb,
            0,
            scale,
            scale)
    end
    local sx, sy = createFittingScale(ui2.rects[1], buttonSize, buttonSize)
    love.graphics.setColor(0, 0, 0, .1)
    love.graphics.draw(ui2.rects[1], offset + startX + sliderWidth, currentY, 0, sx, sy)
    if img2 then
        love.graphics.setColor(0, 0, 0, 1)
        local imgsx, imgsy = createFittingScale(img2, buttonSize, buttonSize)
        love.graphics.draw(img2, offset + startX + sliderWidth, currentY, 0, imgsx, imgsy)
    end
    local more = ui.getUIRect('more-' .. prop, offset + startX + sliderWidth, currentY,
            buttonSize, buttonSize)
    if more then
        growl(1 + love.math.random() * 2)

        toggleFunc(true)
    end
    local w, h = ui2.toggle.body3:getDimensions()
    local t = ui.getUIRect('t-' .. prop, offset + startX, yOff + currentY, w * scale, h * scale)
    if t then
        growl(1 + love.math.random() * 2)
        toggleFunc(toggleValue)
    end
end

local function draw_slider_with_2_buttons(path, startX, currentY, buttonSize, sliderWidth, propupdate, update,
                                          valmin, valmax, valstep, img1, img2)
    local val = getValueByPath(editingGuy, path)
 
    local sx, sy = createFittingScale(ui2.rects[1], buttonSize, buttonSize)
    love.graphics.setColor(0, 0, 0, .1)
    love.graphics.draw(ui2.rects[1], startX, currentY, 0, sx, sy)
    if img1 then
        love.graphics.setColor(0, 0, 0, 1)
        local imgsx, imgsy = createFittingScale(img1, buttonSize, buttonSize)
        love.graphics.draw(img1, startX, currentY, 0, imgsx, imgsy)
    end
    local less = ui.getUIRect('less-' .. path, startX, currentY, buttonSize, buttonSize)
    if less then
        local newValue = math.max(val - valstep, valmin)
        setValueByPath(editingGuy, path, newValue)
        propupdate(newValue)
        --changeValue(prop, -valstep, valmin, valmax)
        --propupdate(getValueMaybeNested(prop))
        if update then update() end

        -- local value = getValueMaybeNested(prop)
        local pitch = numbers.mapInto(newValue, valmin, valmax, 1, 3)
        growl(pitch)
    end

    local sx, sy = createFittingScale(ui2.rects[1], buttonSize, buttonSize)
    love.graphics.setColor(0, 0, 0, .1)
    love.graphics.draw(ui2.rects[1], startX + buttonSize + sliderWidth, currentY, 0, sx, sy)
    if img2 then
        love.graphics.setColor(0, 0, 0, 1)
        local imgsx, imgsy = createFittingScale(img2, buttonSize, buttonSize)
        love.graphics.draw(img2, startX + buttonSize + sliderWidth, currentY, 0, imgsx, imgsy)
    end
    local more = ui.getUIRect('more-' .. path, startX + buttonSize + sliderWidth, currentY, buttonSize,
            buttonSize)
    if more then
        -- local current = getValueByPath()
        local newValue = math.min(val + valstep, valmax)
        setValueByPath(editingGuy, path, newValue)
        -- changeValue(prop, valstep, valmin, valmax)
        propupdate(newValue)
        if update then update() end

        --local value = getValueMaybeNested(prop)
        --local pitch =
        local pitch = numbers.mapInto(newValue, valmin, valmax, 1, 3)
        growl(pitch)
    end

    -- getValueMaybeNested(prop)
    -- print(val, path)
    local v = h_slider_textured("slider-" .. path, startX + buttonSize, currentY + (buttonSize / 4), sliderWidth,
            ui2.sliderimg.track2,
            ui2.sliderimg.thumb5,
            nil, val, valmin, valmax)
    if v.value then
        local m = math.ceil(1 / math.abs(valstep))
        v.value = math.floor(v.value * m) / m -- round to .5

        --  local changed = false
        local changed = (v.value ~= val)
        setValueByPath(editingGuy, path, v.value)
        -- print(v.value)
        --setValueMaybeNested(prop, v.value)
        propupdate(v.value)
        if (changed) then
            if playingSound then playingSound:stop() end
            growl(1 + love.math.random() * 2)
        end
        if update then update() end
    end
end

function drawImmediateSlidersEtc(draw, startX, currentY, width, category)
    local values = editingGuy.dna.values
    local currentHeight = 0
    local buttonSize = width < 320 and 24 or 48

    width = width - buttonSize
    local columnsCells = (math.ceil(width / buttonSize))
    local sliderWidth = (width / math.ceil((columnsCells / 6))) - (buttonSize * 2)
    local elementWidth = (sliderWidth + (buttonSize * 2))
    local elementsInRow = width / elementWidth
    local runningElem = 0
    width = width + buttonSize
    startX = startX + buttonSize / 2

    local rowMultiplier = 1.3

    function updateRowStuff()
        runningElem = runningElem + 1
        if runningElem >= elementsInRow then
            runningElem = 0
            currentY = currentY + buttonSize * rowMultiplier
        end
        return runningElem, currentY
    end

    function calcCurrentHeight(itemsHere)
        local rowsInUse = math.ceil(itemsHere / elementsInRow)
        return rowsInUse * (buttonSize) * rowMultiplier
    end

    if uiState.selectedTab == 'part' then
        if category == 'chestHair' then
            currentHeight = calcCurrentHeight(1)

            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('chestHair')
                end
                draw_slider_with_2_buttons('dna.multipliers.chesthair.mMultiplier', startX, currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 1.25, .25, ui2.icons.chestHairInner, ui2.icons.chestHairOuter)
            end
        end



        if category == 'teeth' then
            currentHeight = calcCurrentHeight(1)

            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('teeth')
                end
                draw_slider_with_2_buttons('dna.multipliers.teeth.hMultiplier', startX, currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 3, .5, ui2.icons.mouthup, ui2.icons.mouthdown)
            end
        end

        if category == 'upperlip' or category == 'lowerlip' then
            currentHeight = calcCurrentHeight(3)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('upperlip')
                    changePart('lowerlip')
                end
                draw_slider_with_2_buttons('dna.multipliers.mouth.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.mouthnarrow, ui2.icons.mouthwide)

                runningElem, currentY = updateRowStuff()
                draw_slider_with_2_buttons('dna.multipliers.mouth.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.mouthsmall, ui2.icons.mouthtall)

                runningElem, currentY = updateRowStuff()
                draw_slider_with_2_buttons('dna.positioners.mouth.y', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, .1, ui2.icons.mouthup, ui2.icons.mouthdown)
            end
        end

        if category == 'brows' then
            currentHeight = calcCurrentHeight(4)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    --arrangeBrows()
                    changePart('brows')
                end

                runningElem = 0

                draw_slider_with_2_buttons('dna.multipliers.brow.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .25, 2, .25, ui2.icons.browthin, ui2.icons.browthick)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.brow.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .25, 2, .25, ui2.icons.brownarrow, ui2.icons.browwide)

                runningElem, currentY = updateRowStuff()


                draw_slider_with_2_buttons('dna.positioners.brow.bend', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 1, 10, 1, ui2.icons.brow1, ui2.icons.brow10)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.brow.y', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, .1, ui2.icons.browsdown, ui2.icons.browsup)

                runningElem, currentY = updateRowStuff()
            end
        end

        if category == 'head' then
            local update = function()
                changePart('head')
            end

            currentHeight = calcCurrentHeight(5)

            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('head')
                end

                draw_slider_with_2_buttons('dna.multipliers.head.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.headnarrow, ui2.icons.headwide)

                runningElem, currentY = updateRowStuff()


                draw_slider_with_2_buttons('dna.multipliers.head.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.headsmall, ui2.icons.headtall)

                runningElem, currentY = updateRowStuff()
                -- TODO

                draw_slider_with_2_buttons('dna.multipliers.face.mMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.25, 2, .25, ui2.icons.facesmall, ui2.icons.facebig)

                runningElem, currentY = updateRowStuff()

                local f = function(v)
                    creation.head.flipy = v and -1 or 1
                    update()
                end

                draw_toggle_with_2_buttons('dna.creation.head.flipy', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth,
                    (creation.head.flipy == 1),
                    f, ui2.icons.headflipv1, ui2.icons.headflipv2)

                runningElem, currentY = updateRowStuff()

                local f = function(v)
                    creation.head.flipx = v and -1 or 1
                    -- values.head.flipx = v == false and -1 or 1
                    update()
                end

                draw_toggle_with_2_buttons('dna.creation.head.flipy', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth,
                    (creation.head.flipx == 1),
                    f, ui2.icons.headfliph1, ui2.icons.headfliph2)
                runningElem, currentY = updateRowStuff()
            end
        end

        if category == 'body' then
            -- we have 5 ui elements, how many will fit on 1 row ?
            local update = function()
                changePart('body')
            end

            currentHeight = calcCurrentHeight(6)

            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('body')
                end
                runningElem = 0

                draw_slider_with_2_buttons('dna.multipliers.torso.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    propupdate, .5, 3, .5, ui2.icons.bodynarrow, ui2.icons.bodywide)

                runningElem, currentY = updateRowStuff()



                draw_slider_with_2_buttons('dna.multipliers.torso.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    update, .5, 3, .5, ui2.icons.bodysmall, ui2.icons.bodytall)

                runningElem, currentY = updateRowStuff()

                local f = function(v)
                    creation.torso.flipy = v and -1 or 1
                    changePart('body')
                end

                draw_toggle_with_2_buttons('bodyflipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                    sliderWidth, (creation.torso.flipy == 1),
                    f, ui2.icons.bodyflipv1, ui2.icons.bodyflipv2)
                runningElem, currentY = updateRowStuff()

                local f = function(v)
                    creation.torso.flipx = v and -1 or 1
                    changePart('body')
                end
                draw_toggle_with_2_buttons('bodyflipx', startX + (runningElem * elementWidth), currentY, buttonSize,
                    sliderWidth, (creation.torso.flipx == 1),
                    f, ui2.icons.bodyfliph1, ui2.icons.bodyfliph2)
                runningElem, currentY = updateRowStuff()

                local f = function(v)
                    creation.isPotatoHead = v
                    -- creation.hasNeck = not creation.isPotatoHead
                    changePart('potato')
                end
                draw_toggle_with_2_buttons('bipedUsePotatoHead', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth,
                    not creation.isPotatoHead,
                    f, ui2.icons.bodynonpotato, ui2.icons.bodypotato)

                runningElem, currentY = updateRowStuff()


                if creation.isPotatoHead then
                    draw_slider_with_2_buttons('dna.multipliers.face.mMultiplier', startX + (runningElem * elementWidth),
                        currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        update, 0.25, 2, .25, ui2.icons.facesmall, ui2.icons.facebig)

                    runningElem, currentY = updateRowStuff()
                end
                if not creation.isPotatoHead then
                    local f = function(v)
                        print(v)
                        creation.hasNeck = v
                        changePart('hasNeck')
                    end

                    draw_toggle_with_2_buttons('dna.creation.hasNeck', startX + (runningElem * elementWidth), currentY,
                        buttonSize,
                        sliderWidth,
                        not creation.hasNeck,
                        f, ui2.icons.neckNo, ui2.icons.neckYes)


                    runningElem, currentY = updateRowStuff()
                end
            end
        end

        if category == 'hands' then
            currentHeight = calcCurrentHeight(2)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('hands')
                end

                draw_slider_with_2_buttons('dna.multipliers.hand.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.handshort, ui2.icons.handtall)

                runningElem, currentY = updateRowStuff()


                draw_slider_with_2_buttons('dna.multipliers.hand.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.handnarrow, ui2.icons.handwide)
                runningElem, currentY = updateRowStuff()

                
            end
        end

        if category == 'feet' then
            currentHeight = calcCurrentHeight(2)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('feet')
                end

                draw_slider_with_2_buttons('dna.multipliers.feet.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.footshort, ui2.icons.foottall)
                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.feet.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.footnarrow, ui2.icons.footwide)

                runningElem, currentY = updateRowStuff()

                
            end
        end

        if category == 'ears' then
            currentHeight = calcCurrentHeight(3)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local rotupdate = function(v)
                    if v then
                        creation.lear.stanceAngle = v
                        creation.rear.stanceAngle = -1 * v
                        changePart('ears')
                    end
                end

                draw_slider_with_2_buttons('dna.creation.lear.stanceAngle', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, rotupdate,
                    nil, 0, math.pi, .25, ui2.icons.earcw, ui2.icons.earccw)

                runningElem, currentY = updateRowStuff()

                local propupdate = function(v)
                    changePart('ears')
                end

                draw_slider_with_2_buttons('dna.multipliers.ear.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 3, .5, ui2.icons.earsmall, ui2.icons.earbig)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.ear.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 3, .5, ui2.icons.earsmall, ui2.icons.earbig)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.ear.y', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, .1, ui2.icons.earup, ui2.icons.eardown)

                runningElem, currentY = updateRowStuff()
               
            end
        end

        if category == 'legs' then
            currentHeight = calcCurrentHeight(3)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('legs')
                end


                draw_slider_with_2_buttons('dna.multipliers.leg.lMultiplier', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 4, .5, ui2.icons.legshort, ui2.icons.leglong)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.leg.wMultiplier', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 4, .5, ui2.icons.legthin, ui2.icons.legthick)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.leg.x', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, .25, ui2.icons.legwide, ui2.icons.legnarrow)

                runningElem, currentY = updateRowStuff()

                if false then
                    draw_slider_with_2_buttons('legDefaultStance', startX + (runningElem * elementWidth), currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        nil, 0.25, 1, .25, ui2.icons.legstance2, ui2.icons.legstance1)

                    runningElem, currentY = updateRowStuff()

                    local f = function(v)
                        values.legs.flipy = v == false and -1 or 1
                        changePart('legs')
                        --myWorld:emit("bipedAttachLegs", biped)
                    end

                    draw_toggle_with_2_buttons('legsflipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                        sliderWidth,
                        (values.legs.flipy == -1),
                        f, ui2.icons.legflip2, ui2.icons.legflip1)
                end
            end
        end

        if category == 'leghair' then
            currentHeight = calcCurrentHeight(1)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('leghair')
                end

                draw_slider_with_2_buttons('dna.multipliers.leghair.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 4, .5, ui2.icons.hairthin, ui2.icons.hairthick)

                runningElem, currentY = updateRowStuff()
            end
        end

        if category == 'armhair' then
            currentHeight = calcCurrentHeight(1)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('armhair')
                end

                draw_slider_with_2_buttons('dna.multipliers.armhair.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 4, .5, ui2.icons.hairthin, ui2.icons.hairthick)

                runningElem, currentY = updateRowStuff()
            end
        end

        if category == 'arms' then
            currentHeight = calcCurrentHeight(3)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('arms')
                end

                draw_slider_with_2_buttons('dna.multipliers.arm.lMultiplier', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.armsshort, ui2.icons.armslong)

                runningElem, currentY = updateRowStuff()


                draw_slider_with_2_buttons('dna.multipliers.arm.wMultiplier', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.armsthin, ui2.icons.armsthick)

                runningElem, currentY = updateRowStuff()

                if false then
                    local f = function(v)
                        values.arms.flipy = v == false and -1 or 1
                        changePart('arms')
                    end

                    draw_toggle_with_2_buttons('arms.flipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                        sliderWidth,
                        (values.arms.flipy == -1),
                        f, ui2.icons.armsflip1, ui2.icons.armsflip2)
                end
            end
        end

        if category == 'neck' then
            currentHeight = calcCurrentHeight(2)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('neck')
                end

                -- todo neck neds to show its change somehow, move the head further if need grows for example....
                draw_slider_with_2_buttons('dna.multipliers.neck.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.neckshort, ui2.icons.necklong)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.neck.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0.5, 3, .5, ui2.icons.neckthin, ui2.icons.neckthick)
            end
        end

        if category == 'pupils' then
            currentHeight = calcCurrentHeight(2)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
                runningElem = 0

                local propupdate = function(v)
                    changePart('pupils')
                end

                draw_slider_with_2_buttons('dna.multipliers.pupil.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .125, 2, .125, ui2.icons.pupilsmall, ui2.icons.pupilbig)
                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.pupil.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .125, 2, .125, ui2.icons.pupilsmall, ui2.icons.pupilbig)
            end
        end

        if category == 'eyes' then
            currentHeight = calcCurrentHeight(5)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
                local propupdate = function(v)
                    changePart('eyes')
                    -- myWorld:emit('rescaleFaceparts', potato)
                    -- myWorld:emit('potatoInit', potato)
                end

                draw_slider_with_2_buttons('dna.multipliers.eye.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .125, 3, .125, ui2.icons.eyesmall1, ui2.icons.eyewide)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.eye.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .125, 3, .125, ui2.icons.eyesmall2, ui2.icons.eyetall)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.eye.r', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, -2, 2, .25, ui2.icons.eyeccw, ui2.icons.eyecw)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.eye.y', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, 0.1, ui2.icons.eyedown, ui2.icons.eyeup)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.ositioners.eye.x', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 0.5, 0.1, ui2.icons.eyefar, ui2.icons.eyeclose)

                runningElem, currentY = updateRowStuff()
            end
        end

        if category == 'nose' then
            currentHeight = calcCurrentHeight(3)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
                runningElem = 0

                local propupdate = function(v)
                    changePart('nose')
                end

                draw_slider_with_2_buttons('dna.multipliers.nose.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 3, .5, ui2.icons.nosenarrow, ui2.icons.nosewide)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.multipliers.nose.hMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .5, 3, .5, ui2.icons.nosesmall, ui2.icons.nosetall)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.positioners.nose.y', startX + (runningElem * elementWidth), currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 1, .1, ui2.icons.noseup, ui2.icons.nosedown)
            end
        end

        if category == 'hair' then
            currentHeight = calcCurrentHeight(2)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
                runningElem = 0

                local f = function(v)
                    local lastOne = 12
                    if values['hair']['shape'] == #(findPart('hair').imgs) then
                        values['hair']['shape'] = 1
                    else
                        values['hair']['shape'] = 12
                    end
                    changePart('hair')
                end

                if false then
                    draw_toggle_with_2_buttons('useIt', startX + (runningElem * elementWidth), currentY, buttonSize,
                        sliderWidth,
                        not (values.potatoHead),
                        f, ui2.icons.bodynonpotato, ui2.icons.bodypotato)

                    runningElem, currentY = updateRowStuff()
                end

                local propupdate = function(v)
                    changePart('hair')
                end


                draw_slider_with_2_buttons('dna.multipliers.hair.wMultiplier', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, .00001, 2, .25, ui2.icons.hairthin, ui2.icons.hairthick)

                runningElem, currentY = updateRowStuff()
                if false then
                    draw_slider_with_2_buttons('dna.multipliers.hair.sMultiplier', startX + (runningElem * elementWidth),
                        currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        nil, .00001, 1, .25, ui2.icons.hairtloose, ui2.icons.hairthight)

                    runningElem, currentY = updateRowStuff()
                end
            end
        end

        if category == 'skinPatchSnout' or category == 'skinPatchEye1' or category == 'skinPatchEye2' then
            local posts = { 'PV.sx', 'PV.sy', 'PV.r', 'PV.tx', 'PV.ty' }
            local mins = { .25, .25, 0, -6, -6 }
            local maxs = { 3, 3, 15, 6, 6 }
            local fs = { 4.0, 4.0, 1, 1, 1 }

            currentHeight = calcCurrentHeight(#posts)
            if draw then
                runningElem = 0
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart('head')
                end

                for i = 1, #posts do
                    local p = posts[i]
                    local vv = 'dna.values.' .. category .. p
                    draw_slider_with_2_buttons(vv, startX + (runningElem * elementWidth), currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        nil, mins[i], maxs[i], 1.0 / fs[i], ui2.icons['patch' .. p .. 'less'],
                        ui2.icons['patch' .. p .. 'more'])

                    runningElem, currentY = updateRowStuff()
                end
            end
        end
    end

    if uiState.selectedTab == 'part' then

    end

    if uiState.selectedTab == 'pattern' then
        local isPatch = category == 'skinPatchSnout' or category == 'skinPatchEye1' or category == 'skinPatchEye2'
        if findPart(category).children then
            currentHeight = 0
        else
            currentHeight = isPatch and calcCurrentHeight(5) or calcCurrentHeight(3)
            if draw then
                drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

                local propupdate = function(v)
                    changePart(category)
                end
                runningElem = 0

                draw_slider_with_2_buttons('dna.values.' .. category .. '.texScale', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 1, 9, 1, ui2.icons.patterncoarse, ui2.icons.patternfine)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.values.' .. category .. '.texRot', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 15, 1, ui2.icons.patternccw, ui2.icons.patterncw)

                runningElem, currentY = updateRowStuff()

                draw_slider_with_2_buttons('dna.values.' .. category .. '.fgAlpha', startX + (runningElem * elementWidth),
                    currentY,
                    buttonSize,
                    sliderWidth, propupdate,
                    nil, 0, 5, 1, ui2.icons.patterntransparent, ui2.icons.patternopaque)

                runningElem, currentY = updateRowStuff()

                if isPatch then
                    draw_slider_with_2_buttons('dna.values.' .. category .. '.bgAlpha', startX + (runningElem * elementWidth),
                        currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        nil, 0, 5, 1, ui2.icons.patterntransparent, ui2.icons.patternopaque)

                    runningElem, currentY = updateRowStuff()

                    draw_slider_with_2_buttons('dna.values.' .. category .. '.lineAlpha',
                        startX + (runningElem * elementWidth), currentY,
                        buttonSize,
                        sliderWidth, propupdate,
                        nil, 0, 5, 1, ui2.icons.patterntransparent, ui2.icons.patternopaque)

                    runningElem, currentY = updateRowStuff()
                end
            end
        end
    end

    if uiState.selectedTab == 'colors' then

        if findPart(category).children then
            currentHeight = 0
        else
            local colorkeys = { 'bgPal', 'fgPal', 'linePal' }
            local pickedColors = {
                palettes[values[category].bgPal],
                palettes[values[category].fgPal],
                palettes[values[category].linePal],
            }

            local amount = #pickedColors
            local buttonWidth = (width / amount) * 0.8
            local originY = currentY
            local originX = startX
            currentY = currentY + 10

            startX = startX + (width / amount) * 0.3
            local rowStartX = startX
            currentHeight = buttonWidth + 10
            if draw then
                drawTapesForBackground(originX, originY, width - (buttonSize / 2), currentHeight)
            end
            for i = 1, 3 do
                if draw then
                    local sx, sy = createFittingScale(ui2.colorpickerui[i], buttonWidth, buttonWidth)
                    if uiState.selectedColoringLayer == colorkeys[i] then
                        local offset = math.sin(love.timer.getTime() * 5) * 0.02
                        sx = sx * (1.0 + offset)
                        sy = sy * (1.0 + offset)
                    end
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.draw(ui2.colorpickerui[i], startX, currentY, 0, sx, sy)
                    love.graphics.setColor(pickedColors[i])
                    love.graphics.draw(ui2.colorpickeruimask[i], startX, currentY, 0, sx, sx)
                end
                if ui.getUIRect('r' .. i, startX, currentY, buttonWidth, buttonWidth) then
                    uiState.selectedColoringLayer = colorkeys[i]
                end
                startX = startX + buttonWidth
            end
        end
    end
    return currentHeight
end

function drawTapesForBackground(x, y, w, h)
    local ratio = h / w
    local index = ratio < 0.3 and 1 or 2
    local sx, sy = createFittingScale(ui2.uiheaders[index], w, h)
    love.graphics.setColor(1, 1, 1, .4)
    love.graphics.draw(ui2.uiheaders[index], x, y, 0, sx, sy, 0, 0)
end

function configPanelPanelDimensions()
    local w, h = love.graphics.getDimensions()
    local margin = (h / 16) -- margin around panel
    local width = (w / 3) -- width of panel
    local height = (h - margin * 2) -- height of panel
    local beginX = 0
    local beginY = 0
    local startX = beginX + w - width - margin
    local startY = beginY + margin

    return startX, startY, width, height
end

function configPanelTabsDimensions(tabs, width)
    local tabWidth = (width / #tabs)
    local tabHeight = math.max((tabWidth / 2.5), 32)
    local marginBetweenTabs = tabWidth / 16

    return tabWidth, tabHeight, marginBetweenTabs
end

local function getScaleAndOffsetsForImage(img, desiredW, desiredH)
    local sx, sy = createFittingScale(img, desiredW, desiredH)
    local scale = math.min(sx, sy)
    local xOffset = 0
    local yOffset = 0
    if scale == sx then
        xOffset = -desiredW / 2 -- half the height
        local something = sx * img:getHeight()
        local something2 = sy * img:getHeight()
        yOffset = -desiredH / 2 - (something - something2) / 2
    elseif scale == sy then
        yOffset = -desiredH / 2 -- half the height
        local something = sx * img:getWidth()
        local something2 = sy * img:getWidth()
        xOffset = -desiredW / 2 + (something - something2) / 2
    end
    return scale, xOffset, yOffset
end

local function configPanelCellDimensions(amount, columns, width)
    local rows = math.ceil(amount / columns)
    local cellMargin = width / 48
    local useWidth = width - (2 * cellMargin) - (columns - 1) * cellMargin
    local cellWidth = (useWidth / columns)
    local cellSize = cellWidth + cellMargin
    return rows, cellWidth, cellMargin, cellSize
end

local function renderElement(category, type, value, container, x, y, w, h)
    local values = editingGuy.dna.values

    if (type == "test") then
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.print(value, x, y)
    end
    if (type == "dot") then
        if (value <= #container) then
            local dotindex = (value % #ui2.dots)

            local pickedBG = values[category].bgPal == value
            local pickedFG = values[category].fgPal == value
            local pickedLP = values[category].linePal == value
            if dotindex == 0 then
                dotindex = #ui2.dots
            end

            local dot = ui2.dots[dotindex]

            if pickedBG or pickedFG or pickedLP then
                local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w * 1.5, h * 1.5)
                local offset = (0.1 * scale * w) / 2

                love.graphics.setColor(container[value])
                love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
                love.graphics.setColor(0, 0, 0, .99)
                local sx, sy = createFittingScale(ui2.circles[1], w * 1.5, h * 1.5)
                love.graphics.draw(ui2.circles[1], x + (xoff + w / 2), y + (yoff + h / 2), 0, sx, sy)
            else
                local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)
                love.graphics.setColor(container[value])
                love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
            end
        end
    end
    if (type == "img") then
        if (value <= #container) then
            local dotindex = (value % #container)
            if dotindex == 0 then
                dotindex = #container
            end

            local url = container[dotindex]
            local dot = imageCache[url] or love.graphics.newImage(url)
            imageCache[url] = dot
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)
            local maskUrl = getPNGMaskUrl(url)
            local info = love.filesystem.getInfo(maskUrl)
            local picked = values[category].shape == dotindex
            if picked then
                scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))

                local sx, sy = createFittingScale(ui2.whiterects[1], w, h)
                love.graphics.setColor(1, 1, 1, .3)
                love.graphics.draw(ui2.whiterects[1], -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, sx, sy, 0, 0)
            end

            if info then
                local mask = imageCache[maskUrl] or love.graphics.newImage(maskUrl)
                imageCache[maskUrl] = mask

                love.graphics.setBlendMode('subtract')
                local pal = palettes[values[category].bgPal]

                if picked then
                    love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 1)
                else
                    love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 0.5)
                end
                love.graphics.draw(mask, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)
                love.graphics.setBlendMode('alpha')
            end

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale, 0, 0)
        end
    end

    if (type == "texture") then
        if (value <= #container) then
            local dotindex = (value % #container)
            if dotindex == 0 then
                dotindex = #container
            end

            local circleindex = (value % #ui2.circles) + 1
            local picked = values[category].fgTex == dotindex
            local bpal = (palettes[values[category].bgPal])
            local pal = (palettes[values[category].fgPal])
            local lpal = (palettes[values[category].linePal])
            local dot = container[dotindex]
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)

            if picked then
                scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
            end

            local function myStencilFunction()
                local r = w / 2
                if picked then
                    r = r + (math.sin(love.timer.getTime() * 5) * (r / 20))
                end
                love.graphics.circle('fill', x + r, y + r, r)
            end

            love.graphics.stencil(myStencilFunction, "replace", 1)
            love.graphics.setStencilTest("greater", 0)
            love.graphics.setColor(bpal[1], bpal[2], bpal[3], 1)
            love.graphics.rectangle('fill', x, y, w, h)
            love.graphics.setColor(pal[1], pal[2], pal[3], 1)
            love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
            love.graphics.setStencilTest()

            local scale, xoff, yoff = getScaleAndOffsetsForImage(ui2.circles[circleindex], w * 1.2, h * 1.2)
            love.graphics.setColor(lpal[1], lpal[2], lpal[3], 1)
            if picked then
                scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
            end
            love.graphics.draw(ui2.circles[circleindex], x + (xoff + w / 2), y + (yoff + h / 2), 0, scale,
                scale)
        end
    end
end

local function buttonClickHelper(category, value)
    local values = editingGuy.dna.values
    local f = findPart(category)

    if uiState.selectedTab == 'part' then
        values[category]['shape'] = value
        changePart(category)

        if (f.kind == 'body') then
            tweenCameraToHeadAndBody()
        else
            tweenCameraToHead()
        end

        growl(1 + love.math.random() * 2)
    end
    if uiState.selectedTab == 'colors' then
        values[category][uiState.selectedColoringLayer] = value
        changePart(category)
        playSound(uiClickSound)
    end

    if uiState.selectedTab == 'pattern' then
        values[category]['fgTex'] = value
        changePart(category)
        playSound(uiClickSound)
    end
end

local function childPickerDimensions(width)
    local p = findPart(uiState.selectedCategory)
    local childrenTabHeight = 0
    if p.children then
        childrenTabHeight = width / 5
    end
    return childrenTabHeight * 1.2
end

function configPanelScrollGrid(draw, clickX, clickY)
    local startX, startY, width, height = configPanelPanelDimensions()
    local tabWidth, tabHeight, marginBetweenTabs = configPanelTabsDimensions(tabs, width)
    local currentY = startY + tabHeight
    local amount = #palettes
    local renderType = "dot"
    local renderContainer = palettes
    local columns = 3
    local category = uiState.selectedCategory

    local p = findPart(uiState.selectedCategory)
    --print(uiState.selectedCategory, p, inspect(p))
    if p.children then
        p = findPart(uiState.selectedChildCategory)
        category = uiState.selectedChildCategory
    end

    if uiState.selectedTab == "fg" or uiState.selectedTab == "bg" or uiState.selectedTab == "line" or uiState.selectedTab == "colors" then
        amount = #palettes
        renderType = "dot"
        columns = 5
        renderContainer = palettes
    end

    if uiState.selectedTab == "part" then
        amount = p.imgs and #p.imgs or 0
        renderType = "img"
        renderContainer = p.imgs
    end

    if uiState.selectedTab == "pattern" then
        amount = #textures
        renderType = "texture"
        renderContainer = textures
    end

    local rows, cellWidth, cellMargin, cellSize = configPanelCellDimensions(amount, columns, width)
    local cellHeight = cellWidth
    local currentX = startX + cellMargin
    local minimumHeight = drawImmediateSlidersEtc(draw, startX, currentY, width, uiState.selectedCategory)
    local otherHeight = 0
    local childrenTabHeight = childPickerDimensions(width) --drawChildPicker(draw, startX, currentY , width, clickX, clickY)

    if findPart(uiState.selectedCategory).children then
        currentY = currentY + childrenTabHeight
        otherHeight = drawImmediateSlidersEtc(draw, startX, currentY, width, uiState.selectedChildCategory)
        currentY = currentY + otherHeight
    end

    currentY = currentY + minimumHeight + cellMargin
    local scrollAreaHeight = (height - minimumHeight - otherHeight - tabHeight - childrenTabHeight)

    grid.data = {
        x = startX,
        y = currentY - cellMargin,
        w = width,
        h = scrollAreaHeight,
        cellsize = cellSize,
    }

    if draw then
        love.graphics.setScissor(grid.data.x, grid.data.y, grid.data.w, grid.data.h)
    end

    local rowsInPanel = math.ceil((scrollAreaHeight - cellMargin) / (cellSize))
    local endlesssScroll = true

    renderFunc = function(xPosition, yPosition, value)
        renderElement(
            category,
            renderType,
            value,
            renderContainer,
            xPosition,
            yPosition,
            cellWidth,
            cellHeight
        )
    end

    if rowsInPanel > rows then
        grid.data.noScroll = true
        for j = -1, rows - 1 do
            for i = 1, columns do
                local newScroll = j --+ offset
                local yPosition = currentY + (newScroll * (cellSize))
                local xPosition = currentX + (i - 1) * (cellSize)
                local index = math.ceil(0) + j

                if (index >= 0 and index <= rows - 1) then
                    local value = ((index % rows) * columns) + i

                    if true or renderContainer[value] ~= 'assets/parts/null.png' then
                        if draw then
                            renderFunc(xPosition, yPosition, value)
                        else
                            if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                                if value <= #renderContainer then buttonClickHelper(category, value) end
                            end
                        end
                    end
                end
            end
        end
    else
        local offset = grid.position % 1
        if endlesssScroll == true then
            for j = -1, rowsInPanel - 1 do
                for i = 1, columns do
                    local newScroll = j + offset
                    local yPosition = currentY + (newScroll * (cellSize))
                    local xPosition = currentX + (i - 1) * (cellSize)
                    local index = math.ceil( -grid.position) + j
                    local value = ((index % rows) * columns) + i

                    if true or renderContainer[value] ~= 'assets/parts/null.png' then
                        if draw then
                            renderFunc(xPosition, yPosition, value)
                        else
                            if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                                if value <= #renderContainer then buttonClickHelper(category, value) end
                            end
                        end
                    end
                end
            end
        else
            local mx = (((rows * (cellHeight + (cellMargin))) - (scrollAreaHeight - cellMargin)) / (cellSize))

            grid.data.min = 0
            grid.data.max = -mx

            for j = -1, rows - 1 do
                for i = 1, columns do
                    local newScroll = j + offset
                    local yPosition = currentY + (newScroll * (cellSize))
                    local xPosition = currentX + (i - 1) * (cellSize)
                    local index = math.ceil( -grid.position) + j

                    if (index >= 0 and index <= rows - 1) then
                        local value = ((index % rows) * columns) + i
                        if true or renderContainer[value] ~= 'assets/parts/null.png' then
                            if draw then
                                renderFunc(xPosition, yPosition, value)
                            else
                                if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                                    if value <= #renderContainer then buttonClickHelper(category, value) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if draw then
        love.graphics.setScissor()
    end
end

function configPanel()
    configPanelSurroundings(true)
    configPanelScrollGrid(true)
end

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
                    local f = setSelectedCategory(categories[index])


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
