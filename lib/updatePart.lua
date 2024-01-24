local texturedBox2d    = require 'lib.texturedBox2d'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local mesh             = require 'lib.mesh'

local lib              = {}


local text = require 'lib.text'

function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end

-- optimize thingie
function getOriginalImageForShape(guy, name)
    local values = guy.dna.values
    local index = math.ceil(values[name].shape)
    local part = findPart(name)
    local url = part.imgs[index]
    local img = mesh.getImage(url)
    return img
end

function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end

lib.updatePart     = function(name, guy)
    local values = guy.dna.values
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local canvasCache = guy.canvasCache

    if name == 'chestHair' then
        local img = getOriginalImageForShape(guy, 'chestHair')
        canvasCache.chestHairCanvas = texturedBox2d.partToTexturedCanvasWrap('chestHair', guy)
    end

    if name == 'lowerlip' then
        canvasCache.lowerlipCanvas = texturedBox2d.partToTexturedCanvasWrap('lowerlip', guy)
    end

    if name == 'upperlip' then
        canvasCache.upperlipCanvas = texturedBox2d.partToTexturedCanvasWrap('upperlip', guy)
    end

    if name == 'teeth' then
        canvasCache.teethCanvas = texturedBox2d.partToTexturedCanvasWrap('teeth', guy)
        local teethdata = findPart('teeth').p
        local teethIndex = values.teeth.shape
        if not box2dGuyCreation.isNullObject('teeth', values) then
            box2dGuyCreation.changeMetaTexture('teeth', guy, teethdata[teethIndex])
        end
    end

    if name == 'brows' then
        local browIndex        = math.ceil(values.brows.shape)
        local part             = findPart('brows')
        local img              = part.imgs[browIndex]
        canvasCache.browCanvas = texturedBox2d.partToTexturedCanvasWrap('brows', guy)
    end

    if name == 'hair' then
        local hairIndex        = math.ceil(values.hair.shape)
        local part             = findPart('hair')
        local img              = part.imgs[hairIndex]
        local legW             = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH             = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2

        local img              = getOriginalImageForShape(guy, 'hair')
        canvasCache.hairCanvas = texturedBox2d.partToTexturedCanvasWrap('hair', guy)
    end

    if name == 'eyes' then
        local eyedata = findPart('eyes').p
        local eyeIndex = values.eyes.shape
        box2dGuyCreation.changeMetaTexture('eye', guy, eyedata[eyeIndex])
        creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
        creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
        canvasCache.eyeCanvas = texturedBox2d.createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)
    end

    if name == 'nose' then
        local nosedata = findPart('nose').p
        local noseIndex = values.nose.shape
        box2dGuyCreation.changeMetaTexture('nose', guy, nosedata[noseIndex])
        creation.nose.w        = mesh.getImage(creation.nose.metaURL):getHeight()
        creation.nose.h        = mesh.getImage(creation.nose.metaURL):getWidth()

        canvasCache.noseCanvas = texturedBox2d.partToTexturedCanvasWrap('nose', guy)
    end

    if name == 'pupils' then
        local pupildata = findPart('pupils').p
        local pupilIndex = values.pupils.shape
        box2dGuyCreation.changeMetaTexture('pupil', guy, pupildata[pupilIndex])
        creation.pupil.w        = mesh.getImage(creation.pupil.metaURL):getHeight() / 2
        creation.pupil.h        = mesh.getImage(creation.pupil.metaURL):getWidth() / 2

        canvasCache.pupilCanvas = texturedBox2d.partToTexturedCanvasWrap('pupils', guy)
    end

    if name == 'ears' then
        local eardata = findPart('ears').p
        local earIndex = values.ears.shape
        box2dGuyCreation.changeMetaTexture('lear', guy, eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4

        box2dGuyCreation.changeMetaTexture('rear', guy, eardata[earIndex])
        creation.rear.w       = mesh.getImage(creation.rear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.rear.h       = mesh.getImage(creation.rear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4

        canvasCache.earCanvas = texturedBox2d.partToTexturedCanvasWrap('ears', guy)
        canvasCache.earmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.earCanvas)


        box2dGuyCreation.genericBodyPartUpdate(guy, 'lear')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rear')
    end

    if name == 'feet' then
        local feetdata = findPart('feet').p
        local footIndex = values.feet.shape

        box2dGuyCreation.changeMetaTexture('lfoot', guy, feetdata[footIndex])
        creation.lfoot.w = mesh.getImage(creation.lfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.lfoot.h = mesh.getImage(creation.lfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2
        box2dGuyCreation.changeMetaTexture('rfoot', guy, feetdata[footIndex])
        creation.rfoot.w       = mesh.getImage(creation.rfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.rfoot.h       = mesh.getImage(creation.rfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2

        canvasCache.footCanvas = texturedBox2d.partToTexturedCanvasWrap('feet', guy)
        canvasCache.footmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.footCanvas)

        box2dGuyCreation.genericBodyPartUpdate(guy, 'lfoot')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rfoot')
    end

    if name == 'hands' then
        local feetdata = findPart('hands').p --  loadVectorSketch('assets/feet.polygons.txt', 'feet')
        local handIndex = values.hands.shape
        box2dGuyCreation.changeMetaTexture('lhand', guy, feetdata[handIndex])
        box2dGuyCreation.changeMetaTexture('rhand', guy, feetdata[handIndex])
        creation.lhand.w       = mesh.getImage(creation.lhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.lhand.h       = mesh.getImage(creation.lhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2
        creation.rhand.w       = mesh.getImage(creation.rhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.rhand.h       = mesh.getImage(creation.rhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2

        canvasCache.handCanvas = texturedBox2d.partToTexturedCanvasWrap('hands', guy)
        canvasCache.handmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.handCanvas)


        box2dGuyCreation.genericBodyPartUpdate(guy, 'lhand')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rhand')
    end

    if name == 'head' or name == 'skinPatchEye1' or name == 'skinPatchEye2' or name == 'skinPatchSnout' then
        -- if not creation.isPotatoHead then
        local data = findPart('head').p --loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local headRndIndex = math.ceil(values.head.shape)
        local flippedFloppedHeadPoints = box2dGuyCreation.getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                data[headRndIndex]
                .points)

        box2dGuyCreation.changeMetaPoints('head', guy, flippedFloppedHeadPoints)
        box2dGuyCreation.changeMetaTexture('head', guy, data[headRndIndex])

        canvasCache.headCanvas = texturedBox2d.partToTexturedCanvasWrap('head', guy)
        creation.head.w        = mesh.getImage(creation.head.metaURL):getWidth() * multipliers.head.wMultiplier / 2
        creation.head.h        = mesh.getImage(creation.head.metaURL):getHeight() * multipliers.head.hMultiplier / 2


        box2dGuyCreation.genericBodyPartUpdate(guy, 'head')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'lear')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rear')
    end

    if name == 'potato' then
        box2dGuyCreation.handleNeckAndHeadForPotato(guy.b2d, guy, creation.isPotatoHead, creation.hasNeck)
        if (not creation.isPotatoHead and creation.hasNeck and not canvasCache.neckCanvas) then
            lib.updatePart('neck', guy)
        end
        if not creation.isPotatoHead then
            lib.updatePart('head', guy)
        end
        box2dGuyCreation.handlePhysicsHairOrNo(guy.b2d, guy, creation.hasPhysicsHair)
        box2dGuyCreation.genericBodyPartUpdate(guy, 'torso')
        setCategories(guy)
    end

    if name == 'hasNeck' then
        box2dGuyCreation.handleNeckAndHeadForHasNeck(guy.b2d, guy, creation.hasNeck)
        if creation.hasNeck then
            lib.updatePart('neck', guy)
        end

        box2dGuyCreation.genericBodyPartUpdate(guy, 'head')
        setCategories(guy)
    end


    if name == 'neck' then
        local neckIndex        = math.ceil(values.neck.shape)
        local part             = findPart('neck')
        local img              = part.imgs[neckIndex]
        local neckW            = mesh.getImage(img):getWidth() * multipliers.neck.wMultiplier / 2
        local neckH            = mesh.getImage(img):getHeight() * multipliers.neck.hMultiplier / 2

        canvasCache.neckCanvas = texturedBox2d.partToTexturedCanvasWrap('neck', guy)
        canvasCache.neckmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.neckCanvas)

        creation.neck.w        = neckW
        creation.neck.h        = neckH / 2
        creation.neck1.w       = neckW
        creation.neck1.h       = neckH / 2

        box2dGuyCreation.genericBodyPartUpdate(guy, 'neck')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'neck1')
    end

    if name == 'legs' then
        local legIndex        = math.ceil(values.legs.shape)
        local part            = findPart('legs')
        local img             = part.imgs[legIndex]
        local legW            = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH            = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2

        canvasCache.legCanvas = texturedBox2d.partToTexturedCanvasWrap('legs', guy)
        canvasCache.legmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.legCanvas)

        creation.luleg.w      = legW
        creation.ruleg.w      = legW
        creation.luleg.h      = legH / 2
        creation.ruleg.h      = legH / 2
        creation.llleg.w      = legW
        creation.rlleg.w      = legW
        creation.llleg.h      = legH / 2
        creation.rlleg.h      = legH / 2

        box2dGuyCreation.genericBodyPartUpdate(guy, 'luleg')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'ruleg')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'llleg')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rlleg')
    end

    if name == 'leghair' then
        local img                 = getOriginalImageForShape(guy, 'leghair')
        canvasCache.leghairCanvas = texturedBox2d.partToTexturedCanvasWrap('leghair', guy)
        canvasCache.leghairMesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.leghairCanvas)
    end

    if name == 'armhair' then
        local img                 = getOriginalImageForShape(guy, 'armhair')
        canvasCache.armhairCanvas = texturedBox2d.partToTexturedCanvasWrap('armhair', guy)
        canvasCache.armhairMesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.armhairCanvas)
    end

    if name == 'arms' then
        local armIndex = math.ceil(values.arms.shape)
        local part     = findPart('arms')
        local img      = part.imgs[armIndex]
        local legW     = mesh.getImage(img):getWidth() * multipliers.arm.wMultiplier / 2
        local legH     = mesh.getImage(img):getHeight() * multipliers.arm.lMultiplier / 2


        canvasCache.armCanvas = texturedBox2d.partToTexturedCanvasWrap('arms', guy)
        canvasCache.armmesh   = texturedBox2d.createTexturedTriangleStrip(canvasCache.armCanvas)

        creation.luarm.w      = legW / 2
        creation.ruarm.w      = legW / 2

        creation.luarm.h      = legH / 2
        creation.ruarm.h      = legH / 2

        creation.llarm.w      = legW / 2
        creation.rlarm.w      = legW / 2

        creation.llarm.h      = legH / 2
        creation.rlarm.h      = legH / 2


        box2dGuyCreation.genericBodyPartUpdate(guy, 'luarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'ruarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'llarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rlarm')
    end

    if name == 'body' then
        local data = findPart('body').p
        local bodyRndIndex = math.ceil(values.body.shape)
        local flippedFloppedBodyPoints = box2dGuyCreation.getFlippedMetaObject(creation.torso.flipx, creation.torso
            .flipy,
                data[bodyRndIndex]
                .points)
        box2dGuyCreation.changeMetaPoints('torso', guy, flippedFloppedBodyPoints)
        box2dGuyCreation.changeMetaTexture('torso', guy, data[bodyRndIndex])
        canvasCache.torsoCanvas = texturedBox2d.partToTexturedCanvasWrap('body', guy)
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


        box2dGuyCreation.handleNeckAndHeadForPotato(guy.b2d, guy, creation.isPotatoHead, creation.hasNeck)
        box2dGuyCreation.handlePhysicsHairOrNo(guy.b2d, guy, creation.hasPhysicsHair)
        box2dGuyCreation.genericBodyPartUpdate(guy, 'torso')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'luarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'llarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'ruarm')
        box2dGuyCreation.genericBodyPartUpdate(guy, 'rlarm')

        if (not creation.isPotatoHead) then
            box2dGuyCreation.genericBodyPartUpdate(guy, 'lear')
            box2dGuyCreation.genericBodyPartUpdate(guy, 'rear')
        end
    end
end

lib.updateAllParts = function(guy)
    local creation = guy.dna.creation

    local _updatePart = function(name)
        lib.updatePart(name, guy)
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

lib.resetPositions = function(guy)
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

lib.randomizeGuy   = function(guy, noPhysicsUpdate)
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local values = guy.dna.values

    function randomizePart(part)
        local p = findPart(part)
        local maximum = #p.imgs
        values[part].shape = math.ceil(love.math.random() * maximum) -- maximum --math.ceil(maximum / 5)
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

    --if not creation.isPotatoHead then
    randomizePart('head')
    multipliers.head.wMultiplier = randValue(.5, 3, .5, true)
    multipliers.head.hMultiplier = randValue(.5, 3, .5, true)
    randomizePart('neck')
    multipliers.neck.hMultiplier = randValue(0.5, 3, .5, true)
    multipliers.neck.wMultiplier = randValue(0.5, 3, .5, true)
    --end

    --if not skipUpdate then
    local oldHasNeck = creation.hasNeck
    local oldPotato = creation.isPotatoHead
    -- if false then

    creation.isPotatoHead = love.math.random() < .5 and true or false
    creation.hasNeck = love.math.random() < .5 and true or false
    -- end
    if (creation.isPotatoHead) then creation.hasNeck = false end

    if not noPhysicsUpdate then
        if creation.hasNeck ~= oldHasNeck then
            lib.updatePart('hasNeck', guy)
            --print('complex I thik 2')
        end

        if creation.isPotatoHead ~= oldPotato then
            lib.updatePart('potato', guy)
            --print('complex I thik 2')
        end
    end
    --end
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

    if not noPhysicsUpdate then
        lib.updateAllParts(guy)
        lib.resetPositions(guy)
    end
end

return lib
