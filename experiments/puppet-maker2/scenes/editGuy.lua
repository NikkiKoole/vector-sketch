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
local dna         = require 'src.dna'

require 'src.editguy-ui'
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
        configPanelScrollGrid(editingGuy, false, x, y)
    end)

    Signal.register('click-scroll-list-item', function(x, y)
        scrollList(editingGuy, false, x, y)
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

function setCategories(guy)
    local creation = guy.dna.creation
    categories = {}

    for i = 1, #parts do
        if parts[i].child ~= true then
            local skip = false
            if creation.isPotatoHead then
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

function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

function updatePart(name, guy)
    local values = guy.dna.values
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local canvasCache = guy.canvasCache

    if name == 'chestHair' then
        canvasCache.chestHairCanvas = partToTexturedCanvasWrap('chestHair', guy)
    end

    if name == 'lowerlip' then
        canvasCache.lowerlipCanvas = partToTexturedCanvasWrap('lowerlip', guy)
    end

    if name == 'upperlip' then
        canvasCache.upperlipCanvas = partToTexturedCanvasWrap('upperlip', guy)
    end

    if name == 'teeth' then
        canvasCache.teethCanvas = partToTexturedCanvasWrap('teeth', guy)
        local teethdata = findPart('teeth').p
        local teethIndex = values.teeth.shape
        if not isNullObject('teeth', values) then
            changeMetaTexture('teeth', guy, teethdata[teethIndex])
        end
    end

    if name == 'brows' then
        local browIndex        = math.ceil(values.brows.shape)
        local part             = findPart('brows')
        local img              = part.imgs[browIndex]
        canvasCache.browCanvas = partToTexturedCanvasWrap('brows', guy)
    end

    if name == 'hair' then
        local hairIndex        = math.ceil(values.hair.shape)
        local part             = findPart('hair')
        local img              = part.imgs[hairIndex]
        local legW             = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH             = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2
        canvasCache.hairCanvas = partToTexturedCanvasWrap('hair', guy)
    end

    if name == 'eyes' then
        local eyedata = findPart('eyes').p
        local eyeIndex = values.eyes.shape
        changeMetaTexture('eye', guy, eyedata[eyeIndex])
        creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
        creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
        canvasCache.eyeCanvas = createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)
    end

    if name == 'nose' then
        local nosedata = findPart('nose').p
        local noseIndex = values.nose.shape
        changeMetaTexture('nose', guy, nosedata[noseIndex])
        creation.nose.w        = mesh.getImage(creation.nose.metaURL):getHeight()
        creation.nose.h        = mesh.getImage(creation.nose.metaURL):getWidth()

        canvasCache.noseCanvas = partToTexturedCanvasWrap('nose', guy)
    end

    if name == 'pupils' then
        local pupildata = findPart('pupils').p
        local pupilIndex = values.pupils.shape
        changeMetaTexture('pupil', guy, pupildata[pupilIndex])
        creation.pupil.w        = mesh.getImage(creation.pupil.metaURL):getHeight() / 2
        creation.pupil.h        = mesh.getImage(creation.pupil.metaURL):getWidth() / 2

        canvasCache.pupilCanvas = partToTexturedCanvasWrap('pupils', guy)
    end

    if name == 'ears' then
        local eardata = findPart('ears').p
        local earIndex = values.ears.shape
        changeMetaTexture('lear', guy, eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4
        --earCanvas = createRandomColoredBlackOutlineTexture(creation.lear.metaURL)

        changeMetaTexture('rear', guy, eardata[earIndex])
        creation.rear.w       = mesh.getImage(creation.rear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.rear.h       = mesh.getImage(creation.rear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4

        canvasCache.earCanvas = partToTexturedCanvasWrap('ears', guy)
        canvasCache.earmesh   = createTexturedTriangleStrip(canvasCache.earCanvas)


        genericBodyPartUpdate(guy, 'lear')
        genericBodyPartUpdate(guy, 'rear')
    end

    if name == 'feet' then
        local feetdata = findPart('feet').p
        local footIndex = values.feet.shape

        changeMetaTexture('lfoot', guy, feetdata[footIndex])
        creation.lfoot.w = mesh.getImage(creation.lfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.lfoot.h = mesh.getImage(creation.lfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2
        changeMetaTexture('rfoot', guy, feetdata[footIndex])
        creation.rfoot.w       = mesh.getImage(creation.rfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.rfoot.h       = mesh.getImage(creation.rfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2

        canvasCache.footCanvas = partToTexturedCanvasWrap('feet', guy)
        canvasCache.footmesh   = createTexturedTriangleStrip(canvasCache.footCanvas)

        genericBodyPartUpdate(guy, 'lfoot')
        genericBodyPartUpdate(guy, 'rfoot')
    end

    if name == 'hands' then
        local feetdata = findPart('hands').p --  loadVectorSketch('assets/feet.polygons.txt', 'feet')
        local handIndex = values.hands.shape
        changeMetaTexture('lhand', guy, feetdata[handIndex])
        changeMetaTexture('rhand', guy, feetdata[handIndex])
        creation.lhand.w       = mesh.getImage(creation.lhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.lhand.h       = mesh.getImage(creation.lhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2
        creation.rhand.w       = mesh.getImage(creation.rhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.rhand.h       = mesh.getImage(creation.rhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2

        canvasCache.handCanvas = partToTexturedCanvasWrap('hands', guy)
        canvasCache.handmesh   = createTexturedTriangleStrip(canvasCache.handCanvas)


        genericBodyPartUpdate(guy, 'lhand')
        genericBodyPartUpdate(guy, 'rhand')
    end

    if name == 'head' or name == 'skinPatchEye1' or name == 'skinPatchEye2' or name == 'skinPatchSnout' then
        -- if not creation.isPotatoHead then
        local data = findPart('head').p --loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local headRndIndex = math.ceil(values.head.shape)
        local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                data[headRndIndex]
                .points)

        changeMetaPoints('head', guy, flippedFloppedHeadPoints)
        changeMetaTexture('head', guy, data[headRndIndex])

        canvasCache.headCanvas = partToTexturedCanvasWrap('head', guy)
        creation.head.w        = mesh.getImage(creation.head.metaURL):getWidth() * multipliers.head.wMultiplier / 2
        creation.head.h        = mesh.getImage(creation.head.metaURL):getHeight() * multipliers.head.hMultiplier / 2


        genericBodyPartUpdate(guy, 'head')
        genericBodyPartUpdate(guy, 'lear')
        genericBodyPartUpdate(guy, 'rear')
    end

    if name == 'potato' then
        handleNeckAndHeadForPotato(guy.b2d, guy, creation.isPotatoHead, creation.hasNeck)
        handlePhysicsHairOrNo(guy.b2d, guy, creation.hasPhysicsHair)
        genericBodyPartUpdate(guy, 'torso')
    end

    if name == 'hasNeck' then
        handleNeckAndHeadForHasNeck(guy.b2d, guy, creation.hasNeck)
        genericBodyPartUpdate(guy, 'head')
    end


    if name == 'neck' then
        local neckIndex        = math.ceil(values.neck.shape)
        local part             = findPart('neck')
        local img              = part.imgs[neckIndex]
        local neckW            = mesh.getImage(img):getWidth() * multipliers.neck.wMultiplier / 2
        local neckH            = mesh.getImage(img):getHeight() * multipliers.neck.hMultiplier / 2

        canvasCache.neckCanvas = partToTexturedCanvasWrap('neck', guy)
        canvasCache.neckmesh   = createTexturedTriangleStrip(canvasCache.neckCanvas)

        creation.neck.w        = neckW
        creation.neck.h        = neckH / 2
        creation.neck1.w       = neckW
        creation.neck1.h       = neckH / 2

        genericBodyPartUpdate(guy, 'neck')
        genericBodyPartUpdate(guy, 'neck1')
    end

    if name == 'legs' then
        local legIndex        = math.ceil(values.legs.shape)
        local part            = findPart('legs')
        local img             = part.imgs[legIndex]
        local legW            = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH            = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2

        canvasCache.legCanvas = partToTexturedCanvasWrap('legs', guy)
        canvasCache.legmesh   = createTexturedTriangleStrip(canvasCache.legCanvas)

        creation.luleg.w      = legW
        creation.ruleg.w      = legW
        creation.luleg.h      = legH / 2
        creation.ruleg.h      = legH / 2
        creation.llleg.w      = legW
        creation.rlleg.w      = legW
        creation.llleg.h      = legH / 2
        creation.rlleg.h      = legH / 2

        genericBodyPartUpdate(guy, 'luleg')
        genericBodyPartUpdate(guy, 'ruleg')
        genericBodyPartUpdate(guy, 'llleg')
        genericBodyPartUpdate(guy, 'rlleg')
    end

    if name == 'leghair' then
        local index               = math.ceil(values.leghair.shape)
        local part                = findPart('leghair')
        local img                 = part.imgs[index]
        canvasCache.leghairCanvas = partToTexturedCanvasWrap('leghair', guy)
        canvasCache.leghairMesh   = createTexturedTriangleStrip(canvasCache.leghairCanvas)
    end

    if name == 'armhair' then
        local index               = math.ceil(values.armhair.shape)
        local part                = findPart('armhair')
        local img                 = part.imgs[index]
        canvasCache.armhairCanvas = partToTexturedCanvasWrap('armhair', guy)
        canvasCache.armhairMesh   = createTexturedTriangleStrip(canvasCache.armhairCanvas)
    end

    if name == 'arms' then
        local armIndex        = math.ceil(values.arms.shape)
        local part            = findPart('arms')
        local img             = part.imgs[armIndex]
        local legW            = mesh.getImage(img):getWidth() * multipliers.arm.wMultiplier / 2
        local legH            = mesh.getImage(img):getHeight() * multipliers.arm.lMultiplier / 2

        --armCanvas        = createRandomColoredBlackOutlineTexture(img)
        canvasCache.armCanvas = partToTexturedCanvasWrap('arms', guy)
        canvasCache.armmesh   = createTexturedTriangleStrip(canvasCache.armCanvas)

        creation.luarm.w      = legW / 2
        creation.ruarm.w      = legW / 2

        creation.luarm.h      = legH / 2
        creation.ruarm.h      = legH / 2

        creation.llarm.w      = legW / 2
        creation.rlarm.w      = legW / 2

        creation.llarm.h      = legH / 2
        creation.rlarm.h      = legH / 2


        genericBodyPartUpdate(guy, 'luarm')
        genericBodyPartUpdate(guy, 'ruarm')
        genericBodyPartUpdate(guy, 'llarm')
        genericBodyPartUpdate(guy, 'rlarm')
    end

    if name == 'body' then
        local data = findPart('body').p
        local bodyRndIndex = math.ceil(values.body.shape)
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', guy, flippedFloppedBodyPoints)
        changeMetaTexture('torso', guy, data[bodyRndIndex])
        canvasCache.torsoCanvas = partToTexturedCanvasWrap('body', guy)
        local body              = guy.b2d.torso
        local longestLeg        = math.max(creation.luleg.h + creation.llleg.h, creation.ruleg.h + creation.rlleg.h)
        local oldLegLength      = longestLeg + creation.torso.h

        --creation.hasPhysicsHair = not creation.hasPhysicsHair
        creation.torso.w        = mesh.getImage(creation.torso.metaURL):getWidth() * multipliers.torso.wMultiplier
        creation.torso.h        = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier

        local newLegLength      = longestLeg + creation.torso.h
        local bx, by            = body:getPosition()
        if (newLegLength > oldLegLength) then
            body:setPosition(bx, by - (newLegLength - oldLegLength) * 1.2)
        end

        creation.luarm.h = 250
        creation.llarm.h = 250
        creation.ruarm.h = creation.luarm.h
        creation.rlarm.h = creation.llarm.h

        -- for i = 1, #fiveGuys do
        handleNeckAndHeadForPotato(guy.b2d, guy, creation.isPotatoHead, creation.hasNeck)
        handlePhysicsHairOrNo(guy.b2d, guy, creation.hasPhysicsHair)
        genericBodyPartUpdate(guy, 'torso')
        genericBodyPartUpdate(guy, 'luarm')
        genericBodyPartUpdate(guy, 'llarm')
        genericBodyPartUpdate(guy, 'ruarm')
        genericBodyPartUpdate(guy, 'rlarm')

        if (not creation.isPotatoHead) then
            genericBodyPartUpdate(guy, 'lear')
            genericBodyPartUpdate(guy, 'rear')
        end
        --end
    end
end

function resetPositions(guy)
    local box2dGuy = guy.b2d

    if (box2dGuy.head) then box2dGuy.head:setAngle(0) end
    if (box2dGuy.neck1) then box2dGuy.neck1:setAngle( -math.pi) end
    if (box2dGuy.neck) then box2dGuy.neck:setAngle( -math.pi) end

    box2dGuy.lear:setAngle(math.pi / 2)
    box2dGuy.rear:setAngle( -math.pi / 2)
    box2dGuy.torso:setAngle(0)
    box2dGuy.luleg:setAngle(0)
    box2dGuy.llleg:setAngle(0)
    box2dGuy.lfoot:setAngle(math.pi / 2)
    box2dGuy.ruleg:setAngle(0)
    box2dGuy.rlleg:setAngle(0)
    box2dGuy.rfoot:setAngle( -math.pi / 2)
    box2dGuy.luarm:setAngle(0)
    box2dGuy.llarm:setAngle(0)
    box2dGuy.lhand:setAngle(0)
    box2dGuy.ruarm:setAngle(0)
    box2dGuy.rlarm:setAngle(0)
    box2dGuy.rhand:setAngle(0)
end

function randomizeGuy(guy)
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local values = guy.dna.values

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
    -- if false then
    creation.isPotatoHead = love.math.random() < .5 and true or false
    creation.hasNeck = love.math.random() < .5 and true or false
    -- end
    if (creation.isPotatoHead) then creation.hasNeck = false end

    if creation.hasNeck ~= oldHasNeck then
        changePart('hasNeck', guy)
    end

    if creation.isPotatoHead ~= oldPotato then
        changePart('potato', guy)
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
    multipliers.hand.hMultiplier = randValue(0.5, 2, .5, true)
    multipliers.hand.wMultiplier = randValue(0.5, 2, .5, true)

    randomizePart('feet')
    multipliers.feet.hMultiplier = randValue(0.5, 2, .5, true)
    multipliers.feet.wMultiplier = randValue(0.5, 2, .5, true)

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

    updateAllParts(guy)
    resetPositions(guy)
end

function updateAllParts(guy)
    local creation = guy.dna.creation

    local _updatePart = function(name)
        updatePart(name, guy)
    end

    _updatePart('ears')
    _updatePart('hands')
    _updatePart('feet')
    if not creation.isPotatoHead then
        _updatePart('head')
        if creation.hasNeck then _updatePart('neck') end
    end
    _updatePart('body')
    _updatePart('arms')
    _updatePart('legs')

    _updatePart('eyes')
    _updatePart('pupils')
    _updatePart('nose')
    _updatePart('hair')
    _updatePart('armhair')
    _updatePart('leghair')
    _updatePart('brows')
    _updatePart('teeth')
    _updatePart('upperlip')
    _updatePart('lowerlip')
    _updatePart('chestHair')
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

-- pointer stuff

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
        for i = 1, #fiveGuys do
            randomizeGuy(fiveGuys[i])
        end
        setCategories(editingGuy)

        local creation = editingGuy.dna.creation
        if creation.isPotatoHead and uiState.selectedCategory == 'head' or uiState.selectedCategory == 'neck' or uiState.selectedCategory == 'patches' then
            setSelectedCategory('body')
            Timer.tween(.5, scroller, { position = 8 })
        end


        local s = findSample('mp7/Quijada')
        if s then
            playSound(s.s, 1, 1)
        end
    end

    for i = 1, #fiveGuys do
        lookAt(fiveGuys[i], x, y)
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

local function pointerReleased(x, y, id)
    scroller.isDragging = false
    grid.isDragging = false

    gesture.maybeTrigger(id, x, y)

    configPanelSurroundings(editingGuy, false, x, y)

    handlePointerReleased(x, y, id)
end

-- love callbacks
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

-- scene methods

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
        end
    end
end

function scene.unload()
    Timer.clear()
    local b = world:getBodies()
    for i = #b, 1, -1 do
        b[i]:destroy()
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


    print('fiveguys..', #fiveGuys, fiveGuys)
    --if not editingGuy then
    editingGuy = fiveGuys[pickedFiveGuyIndex]
    --end

    borders = {}
    parts = dna.generateParts()
    categories = {}
    setCategories(editingGuy)

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });

    setupBox2dScene()
    for i = 1, #fiveGuys do
        updateAllParts(fiveGuys[i])
    end
    Timer.tween(.5, scroller, { position = 4 })
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


        scrollList(editingGuy, true)
        configPanel(editingGuy)
    end
    prof.pop('editGuy.draw ui')
    cam:push()

    --phys.drawWorld(world)

    prof.push('editGuy.draw drawSkinOver')
    for i = 1, #fiveGuys do
        drawSkinOver(fiveGuys[i].b2d, fiveGuys[i])
    end
    for i = 1, #fiveGuys do
        --     drawNumbersOver(fiveGuys[i].b2d)
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
