local scene       = {}
local gradient    = require 'lib.gradient'
local hit         = require 'lib.hit'
local skygradient = gradient.makeSkyGradient(6)
local Timer       = require 'vendor.timer'

local parentize   = require 'lib.parentize'
local render      = require 'lib.render'
local mesh        = require 'lib.mesh'

local audioHelper = require 'lib.melody-paint-audio-helper'

local camera      = require 'lib.camera'
local cam         = require('lib.cameraBase').getInstance()
local transforms  = require 'lib.transform'
local geom        = require 'lib.geom'
local bbox        = require 'lib.bbox'
local numbers     = require 'lib.numbers'
local text        = require 'lib.text'

require 'src.reuse'
require 'src.screen-transitions'

local pointerInteractees = {}

local function pointerReleased(x, y, id)
    for i = #pointerInteractees, 1, -1 do
        if pointerInteractees[i].id == id then
            myWorld:emit('itemReleased', pointerInteractees[i])
            --print(inspect(pointerInteractees[i].id))

            for j = 1, #fg do
                if (pointerInteractees[i].item and pointerInteractees[i].item == fiveGuys[j].body) then
                    local soundArray = hum;
                    local pitch = love.math.random() * 0.25 + 0.8
                    local index = math.ceil(love.math.random() * #soundArray)
                    local sndLength = soundArray[math.ceil(index)]:getDuration() / pitch
                    playingSound = playSound(soundArray[math.ceil(index)], pitch, 2)

                    myWorld:emit('mouthSaySomething', fg[j].mouth, fiveGuys[j], sndLength)
                    myWorld:emit('blinkEyes', fg[j].potato)
                else
                    local item = pointerInteractees[i].item
                    if (item and item == fiveGuys[j].hand1 or item == fiveGuys[j].hand2) then
                        local sfx = pickRandomFrom(rubberplonks)
                        local pitch = 1
                        playSound(sfx, pitch, sfx:getDuration() / pitch)
                    end
                end
            end

            table.remove(pointerInteractees, i)
        end
    end

    --scrollerIsDragging = false
    --settingsScrollAreaIsDragging = false

    gesture.maybeTrigger(id, x, y)
    -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen
    --partSettingsSurroundings(false, x, y)
    --collectgarbage()
end

local function pointerMoved(x, y, dx, dy, id)
    --print('pointermoved', x, y)
    for i = 1, #pointerInteractees do
        if pointerInteractees[i].id == id then
            local scale = cam:getScale()

            if love.mouse.isDown(1) then
                myWorld:emit("itemDrag", pointerInteractees[i], dx, dy, scale)
            end
            if love.mouse.isDown(2) then
                myWorld:emit("itemRotate", pointerInteractees[i], dx, dy, scale)
            end
        end
    end
end



local function pointerPressed(x, y, id)
    local wx, wy = cam:getWorldCoordinates(x, y)
    for j = 1, #root.children do
        local guy = root.children[j]
        if guy.children then
            for i = 1, #guy.children do
                local item = guy.children[i]
                local b = bbox.getBBoxRecursiveVersion2(item) --- this is breaking now because i have smaller children that end up becoming the bbox
                if b and item.folder then
                    local mx, my = item.transforms._g:inverseTransformPoint(wx, wy)
                    local tlx, tly = item.transforms._g:inverseTransformPoint(b[1], b[2])
                    local brx, bry = item.transforms._g:inverseTransformPoint(b[3], b[4])

                    if (hit.pointInRect(mx, my, tlx, tly, brx - tlx, bry - tly)) then
                        local romp = hasChildNamedRomp(item)
                        if romp then
                            local maskUrl = (getPNGMaskUrl(romp.texture.url))
                            local mask = mesh.getImage(maskUrl)
                            local imageData = love.image.newImageData(maskUrl)

                            local imgW, imgH = imageData:getDimensions()
                            local xx = numbers.mapInto(mx, tlx, brx, 0, imgW)
                            local yy = numbers.mapInto(my, tly, bry, 0, imgH)

                            if xx > 0 and xx < imgW then
                                if yy > 0 and my < imgH then
                                    local r, g, b, a = imageData:getPixel(xx, yy)
                                    if (r + g + b > 1.5) then
                                        table.insert(pointerInteractees,
                                            { state = 'pressed', item = item, x = x, y = y, id = id })
                                        editingGuy = fiveGuys[j]
                                    end
                                end
                            end
                        else
                            table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
                            editingGuy = fiveGuys[j]
                        end
                    end
                end
            end
        end
    end
    myWorld:emit("eyeLookAtPoint", x, y)

    local w, h = love.graphics.getDimensions()
    local size = (h / 8) -- margin around panel
    if (hit.pointInRect(x, y, w - size, 0, size, size)) then
        local sx, sy = getPointToCenterTransitionOn()
        SM.unload('fiveGuys')
        Timer.clear()

        doCircleInTransition(sx, sy, function() SM.load("editGuy") end)
    end
end


local function pointerPressed2(x, y, id)
    local w, h = love.graphics.getDimensions()
    if (hit.pointInRect(x, y, w - 22, 0, 25, 25)) then
        local w, h = love.graphics.getDimensions()
        local bx, by = editingGuy.head.transforms._g:transformPoint(0, 0)
        local sx, sy = cam:getScreenCoordinates(bx, by)
        doCircleInTransition(sx, sy, function() SM.load("editGuy") end)
    end
    myWorld:emit("eyeLookAtPoint", x, y)
end


function getCameraZoom()
    local bboxes = {}
    for i = 1, #fiveGuys do
        local b = bbox.getBBoxRecursive(fiveGuys[i].head)
        table.insert(bboxes, b)
        local b = bbox.getBBoxRecursive(fiveGuys[i].feet1)
        table.insert(bboxes, b)
    end

    local tlx, tly, brx, bry = bbox.combineBboxes(unpack(bboxes))

    local x2, y2, w2, h2     = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)

    --return x2, y2, w, h * 1.2
    --local w, h               = love.graphics.getDimensions()
    return x2, y2, w2, h2
end

function scene.unload()
    myWorld:clear()
end

function getBodyYOffsetForDefaultStance(e)
    local magic = 4.46
    local d = e.biped.leg1.data
    -- return -((d.length / magic) * d.scaleY) * (d.borderRadius + .66) * e.biped.values.legDefaultStance
    return -((d.length / magic) * d.scaleY) * (d.borderRadius + .66) * e.biped.values.legDefaultStance
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        -- print(inspect(msg))
        --print(msg.data.path)
        local path = msg.data.path
        if path == "mipo/po3" or path == 'mipo/pi' then
            local sndLength = msg.data.source:getDuration() / msg.data.pitch
            local index = math.ceil(math.random() * #fg)
            --myWorld:emit('mouthSaySomething', fg[index].mouth, fiveGuys[index], 1)
            myWorld:emit('mouthSaySomething', fg[index].mouth, fiveGuys[index], sndLength)
        elseif (path == 'Triangles 101' or path == 'Triangles 103') then
            local index = math.ceil(math.random() * #fg)
            myWorld:emit('breath', fg[index].biped)
            --  print(path)
        elseif (path == 'babirhodes/rhodes2') then
            local index = math.ceil(math.random() * #fg)
            myWorld:emit('doinkBodyLight', fg[index].biped)
        end
        --print(path)
        --print('handling audio message from fiveGuy')
    end
end

function scene.load()
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[1] });
    if (PROF_CAPTURE) then
        ProFi:start()
    end

    prof.push('frame2')
    -- print(myWorld)

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }

    fg = {}
    prof.push('initguys')

    local editingBefore = editingGuy
    for i = 1, #fiveGuys do
        table.insert(root.children, fiveGuys[i].guy)


        local biped = Concord.entity()
        local potato = Concord.entity()
        local mouth = Concord.entity()

        myWorld:addEntity(biped)
        myWorld:addEntity(potato)
        myWorld:addEntity(mouth)

        editingGuy = fiveGuys[i]

        biped:give('biped', bipedArguments(editingGuy))
        potato:give('potato', potatoArguments(editingGuy))
        mouth:give('mouth', mouthArguments(editingGuy))


        attachAllFaceParts(editingGuy)

        if isNullObject('leghair', editingGuy.values) then
            changePart('leghair')
        end
        if isNullObject('armhair', editingGuy.values) then
            changePart('armhair')
        end
        if isNullObject('hair', editingGuy.values) then
            changePart('hair')
        end

        -- this has an efect on the tteh somehow!!!
        changePart('hair')

        table.insert(fg, { biped = biped, potato = potato, mouth = mouth })
    end
    editingGuy = editingBefore
    prof.pop('initguys')
    -- editingGuy = fiveGuys[1]



    stripPath(root, '/experiments/puppet%-maker/')
    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)
    prof.push('moveguys')
    for i = 1, #fg do
        --- this will reset the position you made
        local resetPos = false
        if resetPos then
            fiveGuys[i].body.transforms.l[1] = 0
            fiveGuys[i].body.transforms.l[2] = 0
            myWorld:emit('movedBody', fg[i].biped)
        end
        fiveGuys[i].guy.transforms.l[1] = (i - math.ceil(#fiveGuys / 2)) * 1000
        fiveGuys[i].guy.transforms.l[2] = 0

        local offset = getBodyYOffsetForDefaultStance(fg[i].biped)
        fiveGuys[i].guy.transforms.l[2] = -offset - 700
        --fg[i].biped.biped.feet1.transforms.l[2] = -300
        --fiveGuys[i].body.transforms.l[2] = 800

        --myWorld:emit('movedBody', fg[i].biped)

        --root.children[i]
        --fiveGuys[i].transforms.l[2] = -200
        --fiveGuys[i].body.transforms.l[2] = -200 --getBodyYOffsetForDefaultStance(fg[i].biped)
        --print(fiveGuys[i].body.transforms, root.children[i].transforms, fiveGuys[i].guy.transforms)
        --root.children[i].transforms.l[2] = 700 - getBodyYOffsetForDefaultStance(fg[i].biped) -- -200
        --myWorld:emit('keepFeetPlantedAndStraightenLegs', biped)
        myWorld:emit('keepFeetPlantedAndStraightenLegs', fg[i].biped)
        myWorld:emit("bipedInit", fg[i].biped)
        myWorld:emit("potatoInit", fg[i].potato)
        myWorld:emit("tweenIntoDefaultStance", fg[i].biped, false)
        -- myWorld:emit('mouthSaySomething', fg[i].mouth, fiveGuys[i], 2)
        --
        -- myWorld:emit("potatoInit", potato)
    end
    prof.pop('moveguys')

    local centerGuyIndex = math.ceil(#fiveGuys / 2)
    local bx, by = fiveGuys[centerGuyIndex].body.transforms._g:transformPoint(0, 0)
    local w, h = love.graphics.getDimensions()

    camera.setCameraViewport(cam, w, h)
    --camera.centerCameraOnPosition(bx, by, w * 8, h * 5)

    local x2, y2, w2, h2 = getCameraZoom()
    --print(x2, y2, w2, h2)

    local left = fiveGuys[1].guy.transforms.l[1]
    local right = fiveGuys[#fiveGuys].guy.transforms.l[1]
    local wide = (right - left) * 1.5

    camera.centerCameraOnPosition(0, -h2 / 2, wide, h2)
    --camera.centerCameraOnPosition(tweenCameraData.x, tweenCameraData.y, tweenCameraData.w, tweenCameraData.h)
    --print(x, y, w, h)
    --camera.centerCameraOnPosition(x, y, w, h)
    -- tweenCameraTo(x, y, w, h)


    cam:update(w, h)
    prof.pop('frame2')




    depthMinMax = { min = -1.0, max = 1.0 }
    -- foregroundFactors = { far=.5, near=1}
    --backgroundFactors = { far=.4, near=.7}
    tileSize = 800
    foregroundFar = camera.generateCameraLayer('foregroundFar', 1)
    foregroundNear = camera.generateCameraLayer('foregroundNear', 1)
    groundimg8 = love.graphics.newImage('assets/img/worldparts/ground3.png')
    ding = love.graphics.newImage('assets/img/worldparts/ground52.png')
    cloud = love.graphics.newImage('assets/img/worldparts/clouds1.png')
    cloud3 = love.graphics.newImage('assets/img/worldparts/clouds3.png')
    --print(groundimg8)
    heights = {}
    minpos = -1000
    maxpos = 1000
    for i = minpos, maxpos do
        heights[i] = love.math.random() * (tileSize / 3)
    end


    if (PROF_CAPTURE) then
        ProFi:stop()
        ProFi:writeReport('profilingReportInit.txt')
    end

    local sx, sy = getPointToCenterTransitionOn()
    sx = 0
    sy = 0
    doRectOutTransition(w / 2, h / 2, function()
    end)
end

function drawGroundPlaneLinesSimple(far, near)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    local W, H = love.graphics.getDimensions()

    local x1, y1 = cam:getWorldCoordinates(0, 0, far)
    local x2, y2 = cam:getWorldCoordinates(W, 0, far)

    local s = math.floor(x1 / tileSize) * tileSize
    local e = math.ceil(x2 / tileSize) * tileSize

    local imgarr = { groundimg8 }

    local woohoo = 1

    for i = s, e, tileSize do
        local groundIndex = (i / tileSize)
        local tileIndex = (groundIndex % (#imgarr)) + 1
        --print(tileIndex)
        local index = (i - s) / tileSize

        if groundIndex >= minpos and groundIndex <= maxpos - 1 then
            local height1 = heights[groundIndex]
            local height2 = heights[groundIndex + 1]
            local s = cam:getScale() -- 50 -> 0.01


            local x4, y4 = cam:getScreenCoordinates(i + 0.0001, height1 * woohoo, near)
            local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2 * woohoo, near)
            -- a bit of an hack to get the ground drawn a bit stretched vertically (* 3)
            local x1, y1 = x4, y4 - s * tileSize
            local x2, y2 = x3, y3 - s * tileSize

            --y4 = y4 + 500
            -- y3 = y3 + 500

            local m = mesh.createTexturedRectangle(imgarr[tileIndex])

            m:setVertex(1, { x1, y1, 0, 0, 1, 1, 1, .5 })
            m:setVertex(2, { x2, y2, 1, 0, 1, 1, 1, .5 })
            m:setVertex(3, { x3, y3, 1, 1 })
            m:setVertex(4, { x4, y4, 0, 1 })

            love.graphics.setColor(.9, .9, .9, .9)
            love.graphics.draw(m)
            --love.graphics.setColor(.1, .9, .3, .9)
            --love.graphics.draw(m, 0, 400 * s)


            local newuvs = { .05, .08, -- tl x and y}
                .92, .95 - .09 }       --width and height

            local rect1 = { x1, y1, x2, y2, x3, y3, x4, y4 }
            local outward = geom.coloredOutsideTheLines(rect1, newuvs)

            local m = mesh.createTexturedRectangle(ding)
            m:setVertex(1, { outward[1], outward[2], 0, 0 })
            m:setVertex(2, { outward[3], outward[4], 1, 0 })
            m:setVertex(3, { outward[5], outward[6], 1, 1 })
            m:setVertex(4, { outward[7], outward[8], 0, 1 })


            -- love.graphics.setColor(168 / 255, 175 / 255, 97 / 255, .9)
            love.graphics.setColor(.4, .8, .2, .8)
            love.graphics.setColor(palettes[6][1], palettes[6][2], palettes[6][3])
            love.graphics.setColor(palettes[20][1], palettes[20][2], palettes[20][3])
            love.graphics.setColor(palettes[23][1], palettes[23][2], palettes[23][3])
            love.graphics.draw(m)
            --love.graphics.draw(m, 0, 400 * s)
        end
    end
end

function scene.draw()
    love.graphics.clear(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    -- love.graphics.setColor(1, 0, 1)
    local w, h = love.graphics.getDimensions()
    -- love.graphics.rectangle('fill', w - 25, 0, 25, 25)

    if true then
        local size = (h / 8) -- margin around panel
        local x = w - size
        local y = 0

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        --love.graphics.rectangle('fill', w - size, 0, size, size)
        --love.graphics.setColor(1, 0, 1)
        local sx, sy = createFittingScale(ui2.bigbuttons.editguys, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ui2.bigbuttons.editguysmask, x, y, 0, sx, sy)
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(ui2.bigbuttons.editguys, x, y, 0, sx, sy)
    end

    love.graphics.setColor(1, 1, 1, .6)
    local sx, sy = createFittingScale(cloud, w, h)
    local bgscale = math.min(sx, sy)
    love.graphics.draw(cloud, 0, 0, 0, bgscale, bgscale)

    -- local x,y = love.mouse.getPosition()
    drawGroundPlaneLinesSimple('foregroundFar', 'foregroundNear')
    cam:push()
    render.renderThings(root, true)
    if false then
        for i = 1, #root.children do
            local px, py = root.children[i].transforms._g:transformPoint(0, 0)
            love.graphics.rectangle('fill', px - 25, py - 25, 50, 50)

            -- the body
            local pivx = root.children[i].children[1].transforms.l[6]
            local pivy = root.children[i].children[1].transforms.l[7]
            local px, py = root.children[i].children[1].transforms._g:transformPoint(pivx, pivy)
            love.graphics.rectangle('fill', px - 25, py - 25, 50, 50)

            -- the foot
            local pivx = root.children[i].children[8].transforms.l[6]
            local pivy = root.children[i].children[8].transforms.l[7]
            local px, py = root.children[i].children[8].transforms._g:transformPoint(pivx, pivy)
            love.graphics.rectangle('fill', px - 25, py - 25, 50, 50)
        end
    end
    cam:pop()

    if false then -- this is leaking toop
        local stats = love.graphics.getStats()
        local str = string.format("texture memory used: %.2f MB", stats.texturememory / (1024 * 1024))
        --   print(inspect(stats))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(inspect(stats), 10, 30)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(inspect(stats), 11, 31)

        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end


    if transition then
        renderTransition(transition)
    end
end

function scene.update(dt)
    function love.touchpressed(id, x, y, dx, dy, pressure)
        pointerPressed(x, y, id)
    end

    function love.mousepressed(x, y, button, istouch, presses)
        if not istouch then
            pointerPressed(x, y, 'mouse')
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
        end
    end

    function love.touchreleased(id, x, y, dx, dy, pressure)
        pointerReleased(x, y, id)
    end

    if false then
        function love.resize(w, h)
            local centerGuyIndex = math.ceil(#fiveGuys / 2)
            local bx, by = fiveGuys[centerGuyIndex].body.transforms._g:transformPoint(0, 0)
            local w, h = love.graphics.getDimensions()

            camera.setCameraViewport(cam, w, h)
            --camera.centerCameraOnPosition(bx, by, w * 8, h * 5)

            local x2, y2, w2, h2 = getCameraZoom()
            --print(x2, y2, w2, h2)

            local left = fiveGuys[1].guy.transforms.l[1]
            local right = fiveGuys[#fiveGuys].guy.transforms.l[1]
            local wide = (right - left) * 1.5

            camera.centerCameraOnPosition(0, -h2 / 2, wide, h2)
            --camera.centerCameraOnPosition(tweenCameraData.x, tweenCameraData.y, tweenCameraData.w, tweenCameraData.h)
            --print(x, y, w, h)
            --camera.centerCameraOnPosition(x, y, w, h)
            -- tweenCameraTo(x, y, w, h)


            cam:update(w, h)
        end
    end

    function love.keypressed(k)
        if k == 'escape' then
            love.event.quit()
        end

        --if k == 'm' then
        --    print('M')
        --local index = math.ceil(math.random() * #fg)
        --myWorld:emit('mouthSaySomething', fg[index].mouth, fiveGuys[index], 1)
        --end
        if k == 'm' then
            makeMarketingScreenshots('overworld')
        end
        if k == 'c' then
            local w, h = love.graphics.getDimensions()
            doCircleInTransition(love.math.random() * w, love.math.random() * h, function()
            end)
        end
        if k == 'w' then
            local w, h = love.graphics.getDimensions()
            doCircleOutTransition(love.math.random() * w, love.math.random() * h, function()
            end)
        end
        if k == 'r' then
            local w, h = love.graphics.getDimensions()
            local offset = w * 0.25
            local rand = love.math.random()
            -- I am drawing a rectangle that is 3 times the height of the screen
            -- that is to make it able to rotate and still cover the whole screen
            h = math.max(w, h) * 3
            if rand < 0.5 then
                doRectOutTransition(-offset, -h, function()
                end)
            else
                doRectOutTransition(w + offset, -h, function()
                end)
            end
        end

        if (k == 'p') then
            if not profiling then
                ProFi:start()
            else
                ProFi:stop()
                ProFi:writeReport('profilingRunninggReportFiveGuys.txt')
            end
            profiling = not profiling
        end
    end

    Timer.update(dt)
    myWorld:emit("update", dt) -- this one is leaking the most actually
end

return scene
