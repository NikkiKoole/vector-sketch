local audioHelper = require 'lib.audio-helper'
local gradient    = require 'lib.gradient'
local Timer       = require 'vendor.timer'
local scene       = {}
local skygradient = gradient.makeSkyGradient(16)
local hit         = require 'lib.hit'
local ui          = require 'lib.ui'
local Signal      = require 'vendor.signal'
local cam         = require('lib.cameraBase').getInstance()
local camera      = require 'lib.camera'
local mesh        = require 'lib.mesh'
local phys        = require 'src.mainPhysics'

local swipes      = require 'src.screen-transitions'
require 'src.editguy-ui'
require 'src.dna'
require 'src.box2dGuyCreation'
require 'src.texturedBox2d'

local findSample = function(path)
    for i = 1, #samples do
        if samples[i].p == path then
            return samples[i]
        end
    end
end


local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

local function attachCallbacks()
    Signal.register('click-settings-scroll-area-item', function(x, y)
        configPanelScrollGrid(false, x, y)
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

    for i = 1, #parts do
        if parts[i].child ~= true then
            local skip = false
            if editingGuy.creation.isPotatoHead then
                local name = parts[i].name
                if name == 'head' or name == 'neck' or name == 'patches' then
                    skip = true
                end
            end

            if not skip then
                table.insert(categories, parts[i].name)
            end
        end
    end
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
        end
    end
end

function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

function updatePart(name)
    local values = editingGuy.values
    local creation = editingGuy.creation
    local multipliers = editingGuy.multipliers

    if name == 'chestHair' then
        chestHairCanvas = partToTexturedCanvasWrap('chestHair', values)
    end

    if name == 'lowerlip' then
        lowerlipCanvas = partToTexturedCanvasWrap('lowerlip', values)
    end

    if name == 'upperlip' then
        upperlipCanvas = partToTexturedCanvasWrap('upperlip', values)
    end

    if name == 'teeth' then
        teethCanvas = partToTexturedCanvasWrap('teeth', values)
        local teethdata = findPart('teeth').p
        local teethIndex = values.teeth.shape
        if not isNullObject('teeth', editingGuy.values) then
            changeMetaTexture('teeth', teethdata[teethIndex])
        end
    end

    if name == 'brows' then
        local browIndex = math.ceil(values.brows.shape)
        local part      = findPart('brows')
        local img       = part.imgs[browIndex]
        browCanvas      = partToTexturedCanvasWrap('brows', values)
    end

    if name == 'hair' then
        local hairIndex = math.ceil(values.hair.shape)
        local part      = findPart('hair')
        local img       = part.imgs[hairIndex]
        local legW      = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH      = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2
        hairCanvas      = partToTexturedCanvasWrap('hair', values)
    end

    if name == 'eyes' then
        local eyedata = findPart('eyes').p
        local eyeIndex = values.eyes.shape
        changeMetaTexture('eye', eyedata[eyeIndex])
        creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
        creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
        eyeCanvas = createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)
    end

    if name == 'nose' then
        local nosedata = findPart('nose').p
        local noseIndex = values.nose.shape
        changeMetaTexture('nose', nosedata[noseIndex])
        creation.nose.w = mesh.getImage(creation.nose.metaURL):getHeight()
        creation.nose.h = mesh.getImage(creation.nose.metaURL):getWidth()

        noseCanvas      = partToTexturedCanvasWrap('nose', values)
    end

    if name == 'pupils' then
        local pupildata = findPart('pupils').p
        local pupilIndex = values.pupils.shape
        changeMetaTexture('pupil', pupildata[pupilIndex])
        creation.pupil.w = mesh.getImage(creation.pupil.metaURL):getHeight() / 2
        creation.pupil.h = mesh.getImage(creation.pupil.metaURL):getWidth() / 2

        pupilCanvas      = partToTexturedCanvasWrap('pupils', values)
    end

    if name == 'ears' then
        local eardata = findPart('ears').p
        local earIndex = values.ears.shape
        changeMetaTexture('lear', eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4
        earCanvas = createRandomColoredBlackOutlineTexture(creation.lear.metaURL)

        changeMetaTexture('rear', eardata[earIndex])
        creation.rear.w = mesh.getImage(creation.rear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.rear.h = mesh.getImage(creation.rear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4

        earCanvas       = partToTexturedCanvasWrap('ears', values)
        earmesh         = createTexturedTriangleStrip(earCanvas)
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end

    if name == 'feet' then
        local feetdata = findPart('feet').p
        local footIndex = values.feet.shape

        changeMetaTexture('lfoot', feetdata[footIndex])
        creation.lfoot.w = mesh.getImage(creation.lfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.lfoot.h = mesh.getImage(creation.lfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2
        changeMetaTexture('rfoot', feetdata[footIndex])
        creation.rfoot.w = mesh.getImage(creation.rfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.rfoot.h = mesh.getImage(creation.rfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2

        footCanvas       = partToTexturedCanvasWrap('feet', values)
        footmesh         = createTexturedTriangleStrip(footCanvas)

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lfoot')
            genericBodyPartUpdate(box2dGuys[i], i, 'rfoot')
        end
    end

    if name == 'hands' then
        local feetdata = findPart('hands').p --  loadVectorSketch('assets/feet.polygons.txt', 'feet')
        local handIndex = values.hands.shape
        changeMetaTexture('lhand', feetdata[handIndex])
        changeMetaTexture('rhand', feetdata[handIndex])
        creation.lhand.w = mesh.getImage(creation.lhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.lhand.h = mesh.getImage(creation.lhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2
        creation.rhand.w = mesh.getImage(creation.rhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.rhand.h = mesh.getImage(creation.rhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2

        handCanvas       = partToTexturedCanvasWrap('hands', values)
        handmesh         = createTexturedTriangleStrip(handCanvas)

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lhand')
            genericBodyPartUpdate(box2dGuys[i], i, 'rhand')
        end
    end

    if name == 'head' or name == 'skinPatchEye1' or name == 'skinPatchEye2' or name == 'skinPatchSnout' then
        -- if not creation.isPotatoHead then
        local data = findPart('head').p --loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local headRndIndex = math.ceil(values.head.shape)
        local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                data[headRndIndex]
                .points)

        changeMetaPoints('head', flippedFloppedHeadPoints)
        changeMetaTexture('head', data[headRndIndex])

        headCanvas      = partToTexturedCanvasWrap('head', values)
        creation.head.w = mesh.getImage(creation.head.metaURL):getWidth() * multipliers.head.wMultiplier / 2
        creation.head.h = mesh.getImage(creation.head.metaURL):getHeight() * multipliers.head.hMultiplier / 2

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'head')
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end

    if name == 'potato' then
        for i = 1, #box2dGuys do
            handleNeckAndHeadForPotato(creation.isPotatoHead, box2dGuys[i], i, creation.hasNeck)
            handlePhysicsHairOrNo(creation.hasPhysicsHair, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
    end

    if name == 'hasNeck' then
        for i = 1, #box2dGuys do
            handleNeckAndHeadForHasNeck(creation.hasNeck, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'head')
        end
    end


    if name == 'neck' then
        local neckIndex  = math.ceil(values.neck.shape)
        local part       = findPart('neck')
        local img        = part.imgs[neckIndex]
        local neckW      = mesh.getImage(img):getWidth() * multipliers.neck.wMultiplier / 2
        local neckH      = mesh.getImage(img):getHeight() * multipliers.neck.hMultiplier / 2

        neckCanvas       = partToTexturedCanvasWrap('neck', values)
        neckmesh         = createTexturedTriangleStrip(neckCanvas)

        creation.neck.w  = neckW
        creation.neck.h  = neckH / 2
        creation.neck1.w = neckW
        creation.neck1.h = neckH / 2

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'neck')
            genericBodyPartUpdate(box2dGuys[i], i, 'neck1')
        end
    end

    if name == 'legs' then
        local legIndex   = math.ceil(values.legs.shape)
        local part       = findPart('legs')
        local img        = part.imgs[legIndex]
        local legW       = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH       = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2

        legCanvas        = partToTexturedCanvasWrap('legs', values)
        legmesh          = createTexturedTriangleStrip(legCanvas)

        creation.luleg.w = legW
        creation.ruleg.w = legW
        creation.luleg.h = legH / 2
        creation.ruleg.h = legH / 2
        creation.llleg.w = legW
        creation.rlleg.w = legW
        creation.llleg.h = legH / 2
        creation.rlleg.h = legH / 2

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'llleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlleg')
        end
    end

    if name == 'leghair' then
        local index   = math.ceil(values.leghair.shape)
        local part    = findPart('leghair')
        local img     = part.imgs[index]
        leghairCanvas = partToTexturedCanvasWrap('leghair', values)
        leghairMesh   = createTexturedTriangleStrip(leghairCanvas)
    end

    if name == 'armhair' then
        local index   = math.ceil(values.armhair.shape)
        local part    = findPart('armhair')
        local img     = part.imgs[index]
        armhairCanvas = partToTexturedCanvasWrap('armhair', values)
        armhairMesh   = createTexturedTriangleStrip(armhairCanvas)
    end

    if name == 'arms' then
        local armIndex   = math.ceil(values.arms.shape)
        local part       = findPart('arms')
        local img        = part.imgs[armIndex]
        local legW       = mesh.getImage(img):getWidth() * multipliers.arm.wMultiplier / 2
        local legH       = mesh.getImage(img):getHeight() * multipliers.arm.lMultiplier / 2

        armCanvas        = createRandomColoredBlackOutlineTexture(img)
        armCanvas        = partToTexturedCanvasWrap('arms', values)
        armmesh          = createTexturedTriangleStrip(armCanvas)

        creation.luarm.w = legW / 2
        creation.ruarm.w = legW / 2

        creation.luarm.h = legH / 2
        creation.ruarm.h = legH / 2

        creation.llarm.w = legW / 2
        creation.rlarm.w = legW / 2

        creation.llarm.h = legH / 2
        creation.rlarm.h = legH / 2

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'llarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlarm')
        end
    end

    if name == 'body' then
        local data = findPart('body').p
        local bodyRndIndex = math.ceil(values.body.shape)
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        changeMetaTexture('torso', data[bodyRndIndex])
        torsoCanvas        = partToTexturedCanvasWrap('body', values)
        local body         = box2dGuys[1].torso
        local longestLeg   = math.max(creation.luleg.h + creation.llleg.h, creation.ruleg.h + creation.rlleg.h)
        local oldLegLength = longestLeg + creation.torso.h

        --creation.hasPhysicsHair = not creation.hasPhysicsHair
        creation.torso.w   = mesh.getImage(creation.torso.metaURL):getWidth() * multipliers.torso.wMultiplier
        creation.torso.h   = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier

        local newLegLength = longestLeg + creation.torso.h
        local bx, by       = body:getPosition()
        if (newLegLength > oldLegLength) then
            body:setPosition(bx, by - (newLegLength - oldLegLength) * 1.2)
        end

        creation.luarm.h = 250
        creation.llarm.h = 250
        creation.ruarm.h = creation.luarm.h
        creation.rlarm.h = creation.llarm.h

        for i = 1, #box2dGuys do
            handleNeckAndHeadForPotato(creation.isPotatoHead, box2dGuys[i], i)
            handlePhysicsHairOrNo(creation.hasPhysicsHair, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
            genericBodyPartUpdate(box2dGuys[i], i, 'luarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'llarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlarm')

            if (not creation.isPotatoHead) then
                genericBodyPartUpdate(box2dGuys[i], i, 'lear')
                genericBodyPartUpdate(box2dGuys[i], i, 'rear')
            end
        end
    end
end

function scene.load()
    phys.resetLists()
    bgColor = creamColor
    loadUIImages()
    attachCallbacks()

    scroller = {
        xPos = 0,
        position = 1,
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
        selectedCategory = 'feet',
        selectedColoringLayer = 'bgPal',
        selectedChildCategory = nil,
    }

    uiTickSound = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
    uiClickSound = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')


    if not editingGuy then
        editingGuy = {
            multipliers = getMultipliers(),
            creation = getCreation(),
            values = generateValues(),
            positioners = getPositioners()
        }
    end
    borders = {}
    parts = generateParts()
    categories = {}
    setCategories()

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });

    setupBox2dScene(5)
    updateAllParts()
    Timer.tween(.5, scroller, { position = 4 })
end

function randomizeGuy()
    local creation = editingGuy.creation
    local multipliers = editingGuy.multipliers
    local values = editingGuy.values

    function randomizePart(part)
        local p = findPart(part)
        local maximum = #p.imgs
        values[part].shape = math.ceil(love.math.random() * maximum)
        values[part].bgPal = math.ceil(love.math.random() * #palettes)
        values[part].fgPal = math.ceil(love.math.random() * #palettes)
    end

    function randValue(min, max, step, preferMiddle)
        local steps = ((max - min) / step) + 1
        if preferMiddle then steps = steps - 2 end
        local index = math.floor(love.math.random() * steps)
        if preferMiddle then index = index + 1 end
        local r = min + (index * step)
        return r
    end

    local hairColor = math.ceil(love.math.random() * #palettes)

    randomizePart('body')
    --multipliers.torso.wMultiplier = randValue(.5, 3, .5, true)
    --multipliers.torso.hMultiplier = randValue(.5, 3, .5, true)

    if not creation.isPotatoHead then
        randomizePart('head')
        multipliers.head.wMultiplier = randValue(.5, 3, .5, true)
        multipliers.head.hMultiplier = randValue(.5, 3, .5, true)
        randomizePart('neck')
        multipliers.neck.hMultiplier = randValue(0.5, 3, .5, true)
        multipliers.neck.wMultiplier = randValue(0.5, 3, .5, true)
    end

    local oldHasNeck = creation.hasNeck
    local oldPotato = creation.isPotatoHead
    creation.isPotatoHead = love.math.random() < .5 and true or false
    creation.hasNeck = love.math.random() < .5 and true or false

    if (creation.isPotatoHead) then creation.hasNeck = false end

    if creation.hasNeck ~= oldHasNeck then
        changePart('hasNeck')
    end

    if creation.isPotatoHead ~= oldPotato then
        changePart('potato')
    end

    randomizePart('ears')
    randomizePart('chestHair')
    values['chestHair'].linePal = hairColor
    randomizePart('armhair')
    values['armhair'].linePal = hairColor
    randomizePart('hair')
    values['hair'].linePal = hairColor

    randomizePart('leghair')
    values['leghair'].linePal = hairColor

    randomizePart('legs')
    multipliers.leg.lMultiplier = randValue(0.5, 4, .5, true)
    multipliers.leg.wMultiplier = randValue(0.5, 4, .5, true)

    randomizePart('arms')
    multipliers.arm.lMultiplier = randValue(0.5, 4, .5, true)
    multipliers.arm.wMultiplier = randValue(0.5, 4, .5, true)

    randomizePart('hands')
    multipliers.hand.hMultiplier = randValue(0.5, 3, .5, true)
    multipliers.hand.wMultiplier = randValue(0.5, 3, .5, true)

    randomizePart('feet')
    multipliers.feet.hMultiplier = randValue(0.5, 3, .5, true)
    multipliers.feet.wMultiplier = randValue(0.5, 3, .5, true)

    randomizePart('eyes')
    randomizePart('pupils')
    randomizePart('brows')
    values['brows'].linePal = hairColor

    randomizePart('eyes')
    randomizePart('nose')

    randomizePart('teeth')
    values['teeth'].bgPal = 5
    values['teeth'].fgPal = 5

    randomizePart('upperlip')
    randomizePart('lowerlip')

    randomizePart('skinPatchSnout')
    local bgAlpha = randValue(1, 5, 1)
    local fgAlpha = randValue(1, 5, 1)
    local lineAlpha = randValue(1, 5, 1)
    values['skinPatchSnout'].bgAlpha = randValue(1, 5, 1)
    values['skinPatchSnout'].fgAlpha = randValue(1, 5, 1)
    values['skinPatchSnout'].lineAlpha = randValue(1, 5, 1)

    randomizePart('skinPatchEye1')
    values['skinPatchEye1'].bgAlpha = bgAlpha
    values['skinPatchEye1'].fgAlpha = fgAlpha
    values['skinPatchEye1'].lineAlpha = lineAlpha

    randomizePart('skinPatchEye2')
    values['skinPatchEye2'].bgAlpha = bgAlpha
    values['skinPatchEye2'].fgAlpha = fgAlpha
    values['skinPatchEye2'].lineAlpha = lineAlpha


    updateAllParts()
    setCategories()

    if creation.isPotatoHead and uiState.selectedCategory == 'head' or uiState.selectedCategory == 'neck' or uiState.selectedCategory == 'patches' then
        setSelectedCategory('body')
        Timer.tween(.5, scroller, { position = 8 })
    end
end

function updateAllParts()
    updatePart('ears')
    updatePart('hands')
    updatePart('feet')
    if not editingGuy.creation.isPotatoHead then
        updatePart('head')
        if editingGuy.creation.hasNeck then updatePart('neck') end
    end
    updatePart('body')
    updatePart('arms')
    updatePart('legs')

    updatePart('eyes')
    updatePart('pupils')
    updatePart('nose')
    updatePart('hair')
    updatePart('armhair')
    updatePart('leghair')
    updatePart('brows')
    updatePart('teeth')
    updatePart('upperlip')
    updatePart('lowerlip')
    updatePart('chestHair')
end

function scene.unload()
    local b = world:getBodies()
    for i = #b, 1, -1 do
        b[i]:destroy()
    end
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
    --handleConnectors(cam)
    handleUpdate(dt, cam)
    rotateAllBodies(world:getBodies(), dt)
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local interacted = handlePointerPressed(x, y, id, cam)

    if not interacted then
        local scrollItemWidth = (h / scroller.visibleOnScreen)
        if x >= scroller.xPos and x < scroller.xPos + scrollItemWidth then
            scroller.isDragging = true
            scroller.isThrown = nil
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

    local size = (h / 8) -- margin around panel



    if (hit.pointInRect(x, y, w - size, 0, size, size)) and not swipes.getTransition() then
        local sx, sy = 0, 0 --getPointToCenterTransitionOn()
        Timer.clear()
        swipes.doCircleInTransition(sx, sy, function()
            if scene then
                SM.unload('editGuy')
                SM.load('outside')
                swipes.fadeInTransition(.2)
            end
        end)
    end


    if (hit.pointInRect(x, y, w - size, h - size, size, size)) then
        print('RANDOMIZE!')
        randomizeGuy()
        local s = findSample('mp7/Quijada')
        if s then
            playSound(s.s, 1, 1)
        end
        --partRandomize(editingGuy.values, true)

        -- this seems to fi the issue the best, 2 inits and this order of operations, now we
        -- have an identical stance in 5 guys and in edit!!

        --myWorld:emit('bipedInit', biped)
        --myWorld:emit('keepFeetPlantedAndStraightenLegs', biped)
        --myWorld:emit('bipedInit', biped)
        --myWorld:emit("tweenIntoDefaultStance", biped, true)
        --tweenCameraToHeadAndBody()
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
    grid.isDragging = false

    gesture.maybeTrigger(id, x, y)
    -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen

    configPanelSurroundings(false, x, y)

    handlePointerReleased(x, y, id)
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

function love.wheelmoved(dx, dy)
    if true then
        local newScale = cam.scale * (1 + dy / 10)
        if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
            rebuildPhysicsBorderForScreen()
        end
    end
end

function scene.draw()
    prof.push('editGuy.draw ')
    prof.push('editGuy.draw ui')

    local w, h = love.graphics.getDimensions()
    ui.handleMouseClickStart()

    if true then
        love.graphics.setColor(1, 1, 1, 1)
        --ui.handleMouseClickStart()
        love.graphics.clear(creamColor)

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(0, 0, 0)


        love.graphics.setColor(0, 0, 0, 0.05)
        love.graphics.draw(ui2.tiles, 400, 0, .1)
        love.graphics.setColor(1, 0, 0, 0.05)
        love.graphics.draw(ui2.tiles2, 1000, 300, math.pi / 2, 2, 2)

        for i = 1, #ui2.headz do
            love.graphics.setColor(0, 0, 0, 0.05)
            love.graphics.draw(ui2.headz[i].img, ui2.headz[i].x * w, ui2.headz[i].y * h, ui2.headz[i].r)
        end

        love.graphics.setColor(1, 1, 1)


        scrollList(true)
        configPanel()
    end
    prof.pop('editGuy.draw ui')
    cam:push()
    phys.drawWorld(world)
    prof.push('editGuy.draw drawSkinOver')
    for i = 1, #box2dGuys do
        drawSkinOver(box2dGuys[i], editingGuy.values, editingGuy.creation, editingGuy.multipliers, editingGuy
        .positioners)
    end
    for i = 1, #box2dGuys do
        --     drawNumbersOver(box2dGuys[i])
    end

    prof.pop('editGuy.draw drawSkinOver')
    cam:pop()

    love.graphics.setColor(0, 0, 0)
    --l
    local a = h_slider('mainVolume', 0, 0, 100, mainVolume, 0, 1)
    if a.value then
        mainVolume = a.value
        audioHelper.sendMessageToAudioThread({ type = "volume", data = mainVolume });
    end



    if true then
        local size = (h / 8) -- margin around panel
        local x = w - size
        local y = 0

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        --love.graphics.rectangle('fill', w - size, 0, size, size)
        --love.graphics.setColor(1, 0, 1)
        local sx, sy = createFittingScale(ui2.bigbuttons.fiveguys, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ui2.bigbuttons.fiveguysmask, x, y, 0, sx, sy)
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(ui2.bigbuttons.fiveguys, x, y, 0, sx, sy)
    end

    if true then
        local size = (h / 8) -- margin around panel
        local x = w - size
        local y = h - size

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        --love.graphics.rectangle('fill', w - size, 0, size, size)
        --love.graphics.setColor(1, 0, 1)
        local sx, sy = createFittingScale(ui2.bigbuttons.dice, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ui2.bigbuttons.dicemask, x, y, 0, sx, sy)
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(ui2.bigbuttons.dice, x, y, 0, sx, sy)
    end
    if swipes.getTransition() then
        swipes.renderTransition()
    end
    prof.pop('editGuy.draw ')
end

return scene
