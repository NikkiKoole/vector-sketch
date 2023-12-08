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

require 'src.editguy-ui'
require 'src.dna'
require 'src.box2dGuyCreation'

local creation = getCreation()

require 'src.texturedBox2d'


function rotateToHorizontal(body, desiredAngle, divider, pr)
    local DEGTORAD = 1 / 57.295779513
    --https://www.iforce2d.net/b2dtut/rotate-to-angle
    if true then
        local angle = body:getAngle()
        local a = angle


        local angularVelocity = body:getAngularVelocity()
        local inertia = body:getInertia()
        local didSomething = false
        if false then
            if false then
                while a > (2 * math.pi) do
                    a = a - (2 * math.pi)
                    body:setAngle(a)
                    --                    print('getting in first one', a, angle)
                    didSomething = true
                end
                while a < -(2 * math.pi) do
                    a = a + (2 * math.pi)
                    body:setAngle(a)
                    --                    print('getting in second one')
                    didSomething = true
                end
            end
        end
        if didSomething then
            --            print('jo')
            return
        end
        angle = a -- body:getAngle()
        local nextAngle = angle + angularVelocity / divider
        local totalRotation = desiredAngle - nextAngle

        while (totalRotation < -180 * DEGTORAD) do
            totalRotation = totalRotation + 360 * DEGTORAD
        end
        while (totalRotation > 180 * DEGTORAD) do
            totalRotation = totalRotation - 360 * DEGTORAD
        end

        local desiredAngularVelocity = (totalRotation * divider)
        --local impulse = body:getInertia() * desiredAngularVelocity
        -- body:applyAngularImpulse(impulse)

        local torque = inertia * desiredAngularVelocity / (1 / divider)
        body:applyTorque(torque)
    end
end

local function getRidOfBigRotationsInBody(body)
    --local angle = body:getAngle()
    --if angle > 0 then
    --    body:setAngle(angle % (2 * math.pi))
    --else
    --    body:setAngle(angle % ( -2 * math.pi))
    --end
    local a = body:getAngle()
    if false then
        while a > (2 * math.pi) do
            a = a - (2 * math.pi)
            body:setAngle(a)
        end
        while a < -(2 * math.pi) do
            a = a + (2 * math.pi)
            body:setAngle(a)
        end
    end
end

function rotateAllBodies(bodies, dt)
    --print('hi hello!')
    --local upsideDown = false
    lastDt = dt
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()


        local isBeingPointerJointed = false
        for j = 1, #pointerJoints do
            local mj = pointerJoints[j]
            if mj.jointBody == body then
                isBeingPointerJointed = true
            end
        end
        for _, fixture in ipairs(fixtures) do
            if isBeingPointerJointed then
                --     getRidOfBigRotationsInBody(body)
            end
            local userData = fixture:getUserData()
            if (userData) then
                -- print(userData.bodyType)
                if userData.bodyType == 'keep-rotation' then
                    --  print(inspect(userData))
                    rotateToHorizontal(body, userData.data.rotation, 50)
                end
            end


            if (true) and not isBeingPointerJointed then
                --local userData = fixture:getUserData()



                if userData then
                    -- getRidOfBigRotationsInBody(body)
                    --print(userData.bodyType)
                    if userData.bodyType == 'balloon' then
                        --getRidOfBigRotationsInBody(body)
                        --local desired = upsideDown and -math.pi or 0
                        --rotateToHorizontal(body, desired, 50)
                        local up = -9.81 * love.physics.getMeter() * 2.5 --4.5

                        body:applyForce(0, up)
                    end
                    --print(userData.bodyType)
                    --if not upsideDown then
                    --    if userData.bodyType == 'lfoot' or userData.bodyType == 'rfoot' then
                    --        getRidOfBigRotationsInBody(body)
                    --    end
                    --end

                    if userData.bodyType == 'hand' then
                        -- getRidOfBigRotationsInBody(body)
                    end
                    if userData.bodyType == 'hand' then
                        --   getRidOfBigRotationsInBody(body)
                    end
                    if userData.bodyType == 'torso' then
                        getRidOfBigRotationsInBody(body)
                        local desired = upsideDown and -math.pi or 0
                        rotateToHorizontal(body, desired, 25)
                    end

                    if not upsideDown then
                        if userData.bodyType == 'neck1' then
                            getRidOfBigRotationsInBody(body)
                            --  -- rotateToHorizontal(body, -math.pi, 40)
                            --rotateToHorizontal(body, 0, 10)
                            rotateToHorizontal(body, -math.pi, 15)
                        end
                        if userData.bodyType == 'neck' then
                            getRidOfBigRotationsInBody(body)
                            -- rotateToHorizontal(body, -math.pi, 40)
                            --rotateToHorizontal(body, 0, 10)
                            rotateToHorizontal(body, -math.pi, 15)
                        end

                        if userData.bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)
                            --rotateToHorizontal(body, -math.pi, 15)

                            --  print(body:getAngle())
                            rotateToHorizontal(body, 0, 15)
                        end
                    end

                    if not upsideDown then
                        if userData.bodyType == 'luleg' then
                            local a = creation.luleg.stanceAngle
                            --  print(a)
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'ruleg' then
                            local a = creation.ruleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'llleg' then
                            local a = creation.llleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'rlleg' then
                            local a = creation.rlleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                    end
                    if upsideDown then
                        if userData.bodyType == 'luarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'llarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'ruarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'rlarm' then
                            -- print('doing stuff!')
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        -- if userData.bodyType == 'legpart' then
                        --getRidOfBigRotationsInBody(body)
                        --rotateToHorizontal(body, math.pi, 10)
                        -- end
                    end

                    if false then
                        if userData.bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)

                            rotateToHorizontal(body, math.pi, 15)
                        end
                    end
                end
            end
        end
    end
end

local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end


function attachCallbacks()
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
            table.insert(categories, parts[i].name)
        end
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

local function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end



function updatePart(name)
    local multipliers = editingGuy.multipliers

    if name == 'chestHair' then
        chestHairCanvas = partToTexturedCanvasWrap('chestHair', editingGuy.values)
    end

    if name == 'lowerlip' then
        lowerlipCanvas = partToTexturedCanvasWrap('lowerlip', editingGuy.values)
    end

    if name == 'upperlip' then
        upperlipCanvas = partToTexturedCanvasWrap('upperlip', editingGuy.values)
    end

    if name == 'teeth' then
        teethCanvas = partToTexturedCanvasWrap('teeth', editingGuy.values)
        local teethdata = loadVectorSketch('assets/faceparts.polygons.txt', 'teeths')
        local teethIndex = editingGuy.values.teeth.shape
        changeMetaTexture('teeth', teethdata[teethIndex])
    end

    if name == 'brows' then
        local browIndex = math.ceil(editingGuy.values.brows.shape)
        local part      = findPart('brows')
        local img       = part.imgs[browIndex]
        browCanvas      = partToTexturedCanvasWrap('brows', editingGuy.values)
    end

    if name == 'hair' then
        local hairIndex = math.ceil(editingGuy.values.hair.shape)
        local part      = findPart('hair')
        local img       = part.imgs[hairIndex]
        local legW      = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH      = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2
        hairCanvas      = partToTexturedCanvasWrap('hair', editingGuy.values)
    end

    if name == 'eyes' then
        local eyedata = loadVectorSketch('assets/faceparts.polygons.txt', 'eyes')
        local eyeIndex = editingGuy.values.eyes.shape
        changeMetaTexture('eye', eyedata[eyeIndex])
        creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
        creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
        eyeCanvas = createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)
    end

    if name == 'nose' then
        local nosedata = loadVectorSketch('assets/faceparts.polygons.txt', 'noses')
        local noseIndex = editingGuy.values.nose.shape
        changeMetaTexture('nose', nosedata[noseIndex])
        creation.nose.w = mesh.getImage(creation.nose.metaURL):getHeight()
        creation.nose.h = mesh.getImage(creation.nose.metaURL):getWidth()

        noseCanvas      = partToTexturedCanvasWrap('nose', editingGuy.values)
    end

    if name == 'pupils' then
        local pupildata = loadVectorSketch('assets/faceparts.polygons.txt', 'pupils')
        local pupilIndex = editingGuy.values.pupils.shape
        changeMetaTexture('pupil', pupildata[pupilIndex])
        creation.pupil.w = mesh.getImage(creation.pupil.metaURL):getHeight() / 2
        creation.pupil.h = mesh.getImage(creation.pupil.metaURL):getWidth() / 2

        pupilCanvas      = partToTexturedCanvasWrap('pupils', editingGuy.values)
    end

    if name == 'ears' then
        local eardata = loadVectorSketch('assets/faceparts.polygons.txt', 'ears')
        local earIndex = editingGuy.values.ears.shape
        changeMetaTexture('lear', eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4
        earCanvas = createRandomColoredBlackOutlineTexture(creation.lear.metaURL)

        changeMetaTexture('rear', eardata[earIndex])
        creation.rear.w = mesh.getImage(creation.rear.metaURL):getHeight() * multipliers.ear.wMultiplier / 4
        creation.rear.h = mesh.getImage(creation.rear.metaURL):getWidth() * multipliers.ear.hMultiplier / 4

        earCanvas       = partToTexturedCanvasWrap('ears', editingGuy.values)
        earmesh         = createTexturedTriangleStrip(earCanvas)
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end

    if name == 'feet' then
        local feetdata = loadVectorSketch('assets/feet.polygons.txt', 'feet')
        local footIndex = editingGuy.values.feet.shape

        changeMetaTexture('lfoot', feetdata[footIndex])
        creation.lfoot.w = mesh.getImage(creation.lfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.lfoot.h = mesh.getImage(creation.lfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2
        changeMetaTexture('rfoot', feetdata[footIndex])
        creation.rfoot.w = mesh.getImage(creation.rfoot.metaURL):getHeight() * multipliers.feet.wMultiplier / 2
        creation.rfoot.h = mesh.getImage(creation.rfoot.metaURL):getWidth() * multipliers.feet.hMultiplier / 2

        footCanvas       = partToTexturedCanvasWrap('feet', editingGuy.values)
        footmesh         = createTexturedTriangleStrip(footCanvas)

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lfoot')
            genericBodyPartUpdate(box2dGuys[i], i, 'rfoot')
        end
    end

    if name == 'hands' then
        local feetdata = loadVectorSketch('assets/feet.polygons.txt', 'feet')
        local handIndex = editingGuy.values.hands.shape
        changeMetaTexture('lhand', feetdata[handIndex])
        changeMetaTexture('rhand', feetdata[handIndex])
        creation.lhand.w = mesh.getImage(creation.lhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.lhand.h = mesh.getImage(creation.lhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2

        creation.rhand.w = mesh.getImage(creation.rhand.metaURL):getHeight() * multipliers.hand.wMultiplier / 2
        creation.rhand.h = mesh.getImage(creation.rhand.metaURL):getWidth() * multipliers.hand.hMultiplier / 2
        handCanvas       = partToTexturedCanvasWrap('hands', editingGuy.values)
        --handCanvas = createRandomColoredBlackOutlineTexture(creation.lhand.metaURL)
        handmesh         = createTexturedTriangleStrip(handCanvas)

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lhand')
            genericBodyPartUpdate(box2dGuys[i], i, 'rhand')
        end
    end

    if name == 'head' or name == 'skinPatchEye1' or name == 'skinPatchEye2' or name == 'skinPatchSnout' then
        -- if not creation.isPotatoHead then
        local data = loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local headRndIndex = math.ceil(editingGuy.values.head.shape)
        local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                data[headRndIndex]
                .points)

        changeMetaPoints('head', flippedFloppedHeadPoints)
        changeMetaTexture('head', data[headRndIndex])

        headCanvas      = partToTexturedCanvasWrap('head', editingGuy.values)
        creation.head.w = mesh.getImage(creation.head.metaURL):getWidth() * multipliers.head.wMultiplier / 2
        creation.head.h = mesh.getImage(creation.head.metaURL):getHeight() * multipliers.head.hMultiplier / 2

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'head')
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
        -- end
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
        local neckIndex  = math.ceil(editingGuy.values.neck.shape)
        local part       = findPart('neck')
        local img        = part.imgs[neckIndex]
        local neckW      = mesh.getImage(img):getWidth() * multipliers.neck.wMultiplier / 2
        local neckH      = mesh.getImage(img):getHeight() * multipliers.neck.hMultiplier / 2

        neckCanvas       = partToTexturedCanvasWrap('neck', editingGuy.values)
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
        local legIndex   = math.ceil(editingGuy.values.legs.shape)
        local part       = findPart('legs')
        local img        = part.imgs[legIndex]
        local legW       = mesh.getImage(img):getWidth() * multipliers.leg.wMultiplier / 2
        local legH       = mesh.getImage(img):getHeight() * multipliers.leg.lMultiplier / 2

        legCanvas        = partToTexturedCanvasWrap('legs', editingGuy.values)
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
        local index   = math.ceil(editingGuy.values.leghair.shape)
        local part    = findPart('leghair')
        local img     = part.imgs[index]
        leghairCanvas = partToTexturedCanvasWrap('leghair', editingGuy.values)
        leghairMesh   = createTexturedTriangleStrip(leghairCanvas)
        --print(armhairCanvas)
    end

    if name == 'armhair' then
        local index   = math.ceil(editingGuy.values.armhair.shape)
        local part    = findPart('armhair')
        local img     = part.imgs[index]
        armhairCanvas = partToTexturedCanvasWrap('armhair', editingGuy.values)
        armhairMesh   = createTexturedTriangleStrip(armhairCanvas)
        --print(armhairCanvas)
    end

    if name == 'arms' then
        local armIndex   = math.ceil(editingGuy.values.arms.shape)
        local part       = findPart('arms')
        local img        = part.imgs[armIndex]
        local legW       = mesh.getImage(img):getWidth() * multipliers.arm.wMultiplier / 2
        local legH       = mesh.getImage(img):getHeight() * multipliers.arm.lMultiplier / 2

        armCanvas        = createRandomColoredBlackOutlineTexture(img)
        armCanvas        = partToTexturedCanvasWrap('arms', editingGuy.values)
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
        local data = loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local bodyRndIndex = math.ceil(editingGuy.values.body.shape)
        --bodyRndIndex = math.ceil(love.math.random() * #data)
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        changeMetaTexture('torso', data[bodyRndIndex])
        torsoCanvas        = partToTexturedCanvasWrap('body', editingGuy.values)
        -- torsoCanvas = createRandomColoredBlackOutlineTexture(creation.torso.metaURL, editingGuy.values.body)

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

function setupBox2dScene()
    -- clear
    -- add new
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)

    box2dGuys = {}
    local top = love.physics.newBody(world, w / 2, 1000, "static")
    local topshape = love.physics.newRectangleShape(4000, 1000)
    local topfixture = love.physics.newFixture(top, topshape, 1)

    if false then
        for i = 1, 100 do
            local body = love.physics.newBody(world, i * 10, -2000, "dynamic")
            local shape = love.physics.newPolygonShape(getRandomConvexPoly(130, 8)) --love.physics.newRectangleShape(width, height / 4)
            local fixture = love.physics.newFixture(body, shape, 2)
        end
    end


    --

    if false then
        local data = loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        local bodyRndIndex = math.ceil(editingGuy.values.body.shape)

        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        changeMetaTexture('torso', data[bodyRndIndex])

        --  local torsoCanvas = createRandomColoredBlackOutlineTexture(creation.torso.metaURL)
        creation.torso.w = mesh.getImage(creation.torso.metaURL):getWidth() * multipliers.torso.wMultiplier
        creation.torso.h = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier
    end
    for i = 1, 5 do
        table.insert(box2dGuys, makeGuy( -1000 + i * 500, -1300, i))
    end

    local k = 'b'
    if (k == 'b') then

    end
end

function scene.load()
    bgColor = creamColor
    loadUIImages()
    attachCallbacks()

    image11 = love.graphics.newImage('assets/parts/hair9.png')
    mesh11 = createTexturedTriangleStrip(image11)


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
        selectedColoringLayer = 'bgPal'
    }

    uiTickSound = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
    uiClickSound = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')

    editingGuy = {
        multipliers = getMultipliers(),
        creation = getCreation(),
        values = generateValues(),
        positioners = getPositioners()
    }

    parts = generateParts()
    categories = {}
    setCategories()

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });


    setupBox2dScene()
    updatePart('ears')
    updatePart('hands')
    updatePart('feet')
    updatePart('head')
    updatePart('body')
    updatePart('arms')
    updatePart('legs')
    updatePart('neck')
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
    Timer.tween(.5, scroller, { position = 4 })
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

    handleUpdate(dt, cam)

    rotateAllBodies(world:getBodies(), dt)
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    -- local x, y = love.mouse.getPosition()

    -- if x >= 0 and x <= scrollListXPosition then
    -- this could be clicking in the head or body buttons
    --  headOrBody(false, x, y)
    --end
    local interacted = handlePointerPressed(x, y, id, cam)
    --print(x, y, interacted)
    if not interacted then
        local scrollItemWidth = (h / scroller.visibleOnScreen)
        if x >= scroller.xPos and x < scroller.xPos + scrollItemWidth then
            scroller.isDragging = true
            scroller.isThrown = nil
            -- scrollListIsThrown = nil
            -- print('hello!')
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
        end
    end
end

function scene.draw()
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
    end

    scrollList(true)

    configPanel()

    cam:push()
    --drawWorld(world)

    for i = 1, #box2dGuys do
        drawSkinOver(box2dGuys[i], editingGuy.values, editingGuy.creation, editingGuy.multipliers, editingGuy
        .positioners)
    end

    cam:pop()

    love.graphics.setColor(0, 0, 0)
    love.graphics.print(inspect(love.graphics.getStats()), 10, 10)

    local a = h_slider('mainVolume', 0, 0, 100, mainVolume, 0, 1)
    if a.value then
        mainVolume = a.value
        audioHelper.sendMessageToAudioThread({ type = "volume", data = mainVolume });
    end
end

return scene
