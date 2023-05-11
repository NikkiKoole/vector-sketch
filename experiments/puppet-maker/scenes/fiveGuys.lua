local scene       = {}
local gradient    = require 'lib.gradient'
local hit         = require 'lib.hit'
local skygradient = gradient.makeSkyGradient(6)
local Timer       = require 'vendor.timer'


local parentize   = require 'lib.parentize'
local render      = require 'lib.render'
local mesh        = require 'lib.mesh'

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
            --print(inspect(pointerInteractees[i]))
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
    local size = (h / 12) -- margin around panel
    if (hit.pointInRect(x, y, 0, 0, size, size)) then
        transitionHead(false) 
       
    end
end

function transitionHead(transitionIn) 
    local w, h = love.graphics.getDimensions()
    local focusOn = editingGuy.values.potatoHead and editingGuy.body or editingGuy.head
    --getHeadPoints(editingGuy.potato)
    local newPoints = getHeadPointsFromValues(editingGuy.values, focusOn,
            editingGuy.values.potatoHead and 'body' or 'head')
 
    local tX = numbers.mapInto(editingGuy.values.noseXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(editingGuy.values.noseYAxis, -3, 3, 0, 1)
 
    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)
    local bx, by = focusOn.transforms._g:transformPoint(x, y)
    local sx, sy = cam:getScreenCoordinates(bx, by)
    
    if transitionIn then
       doCircleOutTransition(sx, sy, function()  print('jo!') end)
    else
       doCircleInTransition(sx, sy, function() SM.load("editGuy")end)
    end
 
    --doCircleInTransition(sx, sy, function() SM.load("editGuy") end)
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


function scene.unload()
    myWorld:clear()
end

function scene.load()
    if (PROF_CAPTURE) then
        ProFi:start()
    end

    prof.push('frame')
    -- print(myWorld)

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }

    local fg = {}
    prof.push('initguys')

    for i = 1, #fiveGuys do
        table.insert(root.children, fiveGuys[i].guy)

        local biped = Concord.entity()
        local potato = Concord.entity()
        myWorld:addEntity(biped)
        myWorld:addEntity(potato)


        biped:give('biped', bipedArguments(fiveGuys[i]))
        potato:give('potato', potatoArguments(fiveGuys[i]))

        attachAllFaceParts(fiveGuys[i])
        editingGuy = fiveGuys[i]

        changePart('hair')
        table.insert(fg, { biped = biped, potato = potato })
    end
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
        fiveGuys[i].body.transforms.l[2] = -700
        myWorld:emit("bipedInit", fg[i].biped)
        myWorld:emit("potatoInit", fg[i].potato)
        --
        -- myWorld:emit("potatoInit", potato)
    end
    prof.pop('moveguys')

    local centerGuyIndex = math.ceil(#fiveGuys / 2)
    local bx, by = fiveGuys[centerGuyIndex].body.transforms._g:transformPoint(0, 0)
    local w, h = love.graphics.getDimensions()

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(bx, by, w * 8, h * 5)
    cam:update(w, h)
    prof.pop('frame')

    depthMinMax = { min = -1.0, max = 1.0 }
    -- foregroundFactors = { far=.5, near=1}
    --backgroundFactors = { far=.4, near=.7}
    tileSize = 800
    foregroundFar = camera.generateCameraLayer('foregroundFar', 1)
    foregroundNear = camera.generateCameraLayer('foregroundNear', 1)
    groundimg8 = love.graphics.newImage('assets/img/worldparts/ground3.png', { mipmaps = true })
    ding = love.graphics.newImage('assets/img/worldparts/ground52.png', { mipmaps = true })
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
    transitionHead(true) 
    local w, h = love.graphics.getDimensions()
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
            local x1, y1 = x4, y4 - s * tileSize
            local x2, y2 = x3, y3 - s * tileSize

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
                .92, .95 - .09 } --width and height

            local rect1 = { x1, y1, x2, y2, x3, y3, x4, y4 }
            local outward = geom.coloredOutsideTheLines(rect1, newuvs)

            local m = mesh.createTexturedRectangle(ding)
            m:setVertex(1, { outward[1], outward[2], 0, 0 })
            m:setVertex(2, { outward[3], outward[4], 1, 0 })
            m:setVertex(3, { outward[5], outward[6], 1, 1 })
            m:setVertex(4, { outward[7], outward[8], 0, 1 })


            -- love.graphics.setColor(168 / 255, 175 / 255, 97 / 255, .9)
            love.graphics.setColor(.4, .8, .2, .8)
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
        local size = (h / 12) -- margin around panel
        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(circles[1], size, size)
        love.graphics.draw(circles[1], 0, 0, 0, sx, sy)

        --love.graphics.rectangle('fill', w - size, 0, size, size)
        --love.graphics.setColor(1, 0, 1)
        local sx, sy = createFittingScale(bigbuttons.editguys, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bigbuttons.editguysmask, 0, 0, 0, sx, sy)
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(bigbuttons.editguys, 0, 0, 0, sx, sy)
    end




    -- local x,y = love.mouse.getPosition()
    drawGroundPlaneLinesSimple('foregroundFar', 'foregroundNear')
    cam:push()
    render.renderThings(root, true)
    if false then
        for i = 1, #root.children do
            local px, py = root.children[i].transforms._g:transformPoint(0, 0)
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

    function love.keypressed(k)
        if k == 'escape' then
            love.event.quit()
        end

        if k == 'c' then
            local w, h = love.graphics.getDimensions()
            doCircleInTransition(love.math.random() * w, love.math.random() * h, function() print('done!') end)
        end
        if k == 'w' then
            local w, h = love.graphics.getDimensions()
            doCircleOutTransition(love.math.random() * w, love.math.random() * h, function() print('done!') end)
        end
        if k == 'r' then
            local w, h = love.graphics.getDimensions()
            local offset = w * 0.25
            local rand = love.math.random()
            -- I am drawing a rectangle that is 3 times the height of the screen
            -- that is to make it able to rotate and still cover the whole screen
            h = math.max(w, h) * 3
            if rand < 0.5 then
                doRectOutTransition( -offset, -h, function() print('done!') end)
            else
                doRectOutTransition(w + offset, -h, function() print('done!') end)
            end
        end
        if k == 't' then
            local w, h = love.graphics.getDimensions()
            local offset = w * 0.25
            local rand = love.math.random()
            -- I am drawing a rectangle that is 3 times the height of the screen
            -- that is to make it able to rotate and still cover the whole screen
            h = math.max(w, h) * 3
            if rand < 0.5 then
                doRectInTransition( -offset, -h, function() print('done!') end)
            else
                doRectInTransition(w + offset, -h, function() print('done!') end)
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
