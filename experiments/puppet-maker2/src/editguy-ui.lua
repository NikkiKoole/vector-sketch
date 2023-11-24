local hit    = require 'lib.hit'

local pink   = { 201 / 255, 135 / 255, 155 / 255 }
local yellow = { 239 / 255, 219 / 255, 145 / 255 }
local green  = { 192 / 255, 212 / 255, 171 / 255 }
local colors = { pink, yellow, green }
local tabs   = { "part", "colors", "pattern" }


function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

function setSecondaryColor(alpha)
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



require 'src.ui-grid-tab-thing'


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
