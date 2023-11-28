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

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path

        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
            -- myWorld:emit('breath', biped)
        end
    end
    --print('handling audio message from editGuy')
end

function updatePart(name)
    if name == 'potato' then
        for i = 1, #box2dGuys do
            handleNeckAndHeadForPotato(creation.isPotatoHead, box2dGuys[i], i)
            handlePhysicsHairOrNo(creation.hasPhysicsHair, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
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
        -- torsoCanvas = createRandomColoredBlackOutlineTexture(creation.torso.metaURL)

        local body = box2dGuys[1].torso
        local longestLeg = math.max(creation.luleg.h + creation.llleg.h, creation.ruleg.h + creation.rlleg.h)
        local oldLegLength = longestLeg + creation.torso.h

        --creation.hasPhysicsHair = not creation.hasPhysicsHair
        creation.torso.w = mesh.getImage(creation.torso.metaURL):getWidth() * multipliers.torso.wMultiplier
        creation.torso.h = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier

        local newLegLength = longestLeg + creation.torso.h
        local bx, by = body:getPosition()
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


    editingGuy = {
        values = generateValues()
    }

    parts = generateParts()
    categories = {}
    setCategories()

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });

    setupBox2dScene()
    Timer.tween(.5, scroller, { position = 7 })
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
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    -- local x, y = love.mouse.getPosition()

    -- if x >= 0 and x <= scrollListXPosition then
    -- this could be clicking in the head or body buttons
    --  headOrBody(false, x, y)
    --end
    local interacted = handlePointerPressed(x, y, id, cam)

    if not interacted then
        local scrollItemWidth = (h / scroller.visibleOnScreen)
        if x >= scroller.xPos and x < scroller.xPos + scrollItemWidth then
            scroller.isDragging = true
            scroller.isThrown = nil
            -- scrollListIsThrown = nil
            --print('hello!')
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
    drawWorld(world)
    cam:pop()
end

return scene
