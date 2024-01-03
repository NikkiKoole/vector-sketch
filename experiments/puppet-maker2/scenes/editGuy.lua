local audioHelper      = require 'lib.audio-helper'
local gradient         = require 'lib.gradient'
local Timer            = require 'vendor.timer'
local scene            = {}
local skygradient      = gradient.makeSkyGradient(16)
local hit              = require 'lib.hit'
local ui               = require 'lib.ui'
local Signal           = require 'vendor.signal'
local camera           = require 'lib.camera'
local cam              = require('lib.cameraBase').getInstance()
local phys             = require 'src.mainPhysics'
local swipes           = require 'src.screen-transitions'
local editGuyUI        = require 'src.editguy-ui'
local texturedBox2d    = require 'src.texturedBox2d'
local box2dGuyCreation = require 'src.box2dGuyCreation'

local updatePart       = require 'src.updatePart'
local findSample       = function(path)
    for i = 1, #samples do
        if samples[i].p == path then
            return samples[i]
        end
    end
end

local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
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
    local interacted = phys.handlePointerPressed(x, y, id, cam)
    -- print(interacted)
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
        Timer.clear()
        swipes.doCircleInTransitionOnPositionFunc(getPointToCenterTransitionOn, function()
            if scene then
                SM.unload('editGuy')
                SM.load('outside')
                saveDNA5File()
                swipes.fadeInTransition(.2)
            end
        end)
    end

    if (hit.pointInRect(x, y, w - size, h - size, size, size)) then
        if DEBUG_FIVE_GUYS_IN_EDIT then
            for i = 1, #fiveGuys do
                updatePart.randomizeGuy(fiveGuys[i])
            end
        else
            updatePart.randomizeGuy(editingGuy)
        end
        setCategories(editingGuy)
        handleCameraAfterCatgeoryChange(true)

        local creation = editingGuy.dna.creation
        if creation.isPotatoHead and uiState.selectedCategory == 'head' or uiState.selectedCategory == 'neck' or uiState.selectedCategory == 'patches' then
            editGuyUI.setSelectedCategory('body')
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

    editGuyUI.configPanelSurroundings(editingGuy, false, x, y)

    phys.handlePointerReleased(x, y, id)
end



if false then
    function love.wheelmoved(dx, dy)
        if true then
            local newScale = cam.scale * (1 + dy / 10)
            if (newScale > 0.01 and newScale < 50) then
                cam:scaleToPoint(1 + dy / 10)
                phys.rebuildPhysicsBorderForScreen()
            end
        end
    end
end


local function attachCallbacks()
    Signal.register('click-settings-scroll-area-item', function(x, y)
        editGuyUI.configPanelScrollGrid(editingGuy, false, x, y)
    end)

    Signal.register('click-scroll-list-item', function(x, y)
        editGuyUI.scrollList(editingGuy, false, x, y)
        handleCameraAfterCatgeoryChange()
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
end

-- scene methods

function handleCameraAfterCatgeoryChange(toBody)
    --print('maybeTweencamera')

    local p = findPart(uiState.selectedCategory)
    local categoryKind = p.kind
    --print(inspect(cam))

    local w, h = love.graphics.getDimensions()
    local vp = math.min(w, h) / cam.scale
    --print(vp, cam.scale)
    local camData = { x = cam.translationX, y = cam.translationY, w = vp, h = vp }

    --if categoryKind ~= camCenteredOn then
    -- print('need to tween!!')
    if (categoryKind == 'body' or toBody) then
        local w, h = love.graphics.getDimensions()
        camera.setCameraViewport(cam, w, h)
        camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)
        --local camData = {x= cam.translationX, y =cam.translationY }
        Timer.tween(.25, camData, { x = w / 2, y = h / 2 - 1000, w = 3000, h = 3000 })
    else
        if (categoryKind == 'head') then
            -- get the head position
            --print(editingGuy.dna.creation.isPotatoHead)

            local creation = editingGuy.dna.creation
            local isPotatoHead = creation.isPotatoHead
            local partToCenterOn = isPotatoHead and editingGuy.b2d.torso or editingGuy.b2d.head
            --print(partToCenterOn)
            local size = isPotatoHead and (math.max(creation.torso.w, creation.torso.h))
                or (math.max(creation.head.w, creation.head.h)) * 1.5
            local yOffset = isPotatoHead and 0 or creation.head.h / 2
            local px, py = partToCenterOn:getPosition()
            local w, h = love.graphics.getDimensions()
            camera.setCameraViewport(cam, w, h)
            camera.centerCameraOnPosition(px, py - yOffset, size, size)
            Timer.tween(.25, camData, { x = px, y = py - yOffset, w = size, h = size })
        end
    end
    Timer.during(.3, function(dt)
        camera.setCameraViewport(cam, camData.w, camData.h)
        camera.centerCameraOnPosition(camData.x, camData.y, camData.w, camData.h)
    end)
    camCenteredOn = categoryKind
    --end
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
        end
    end
end

function scene.unload()
    Signal.clear('click-settings-scroll-area-item')
    Signal.clear('click-scroll-list-item')
    Signal.clear('throw-settings-scroll-area')
    Signal.clear('throw-scroll-list')
    Signal.clearPattern('.*') -- clear all signals
    --Timer.clear()
    local b = world:getBodies()
    for i = #b, 1, -1 do
        b[i]:destroy()
    end
    upsideDown = false
    jointsEnabled = true
end

function scene.load()
    phys.resetLists()
    bgColor = creamColor
    editGuyUI.loadUIImages()
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
        selectedCategory = 'body',
        selectedColoringLayer = 'bgPal',
        selectedChildCategory = nil,
    }

    camCenteredOn = 'body'

    uiTickSound = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
    uiClickSound = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')


    -- print('fiveguys..', #fiveGuys, fiveGuys)
    --if not editingGuy then
    editingGuy = fiveGuys[pickedFiveGuyIndex]
    --end

    borders = {}

    categories = {}
    setCategories(editingGuy)

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });





    if DEBUG_FIVE_GUYS_IN_EDIT then
        phys.setupBox2dScene(nil, box2dGuyCreation.makeGuy)
        for i = 1, #fiveGuys do
            updatePart.updateAllParts(fiveGuys[i])
        end
    else
        phys.setupBox2dScene(pickedFiveGuyIndex, box2dGuyCreation.makeGuy)
        updatePart.updateAllParts(editingGuy)
    end


    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)

    handleCameraAfterCatgeoryChange()
    --  local w, h = love.graphics.getDimensions()
    --  camera.centerCameraOnPosition(0, 0, w, h)
    --  cam:update(w, h)

    Timer.tween(.5, scroller, { position = 8 })
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
    phys.handleUpdate(dt, cam)
    box2dGuyCreation.rotateAllBodies(world:getBodies(), dt)
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


        editGuyUI.scrollList(editingGuy, true)
        editGuyUI.configPanel(editingGuy)
    end
    prof.pop('editGuy.draw ui')
    cam:push()

    --phys.drawWorld(world)

    prof.push('editGuy.draw drawSkinOver')
    if DEBUG_FIVE_GUYS_IN_EDIT then
        for i = 1, #fiveGuys do
            texturedBox2d.drawSkinOver(fiveGuys[i].b2d, fiveGuys[i])
        end
    else
        texturedBox2d.drawSkinOver(editingGuy.b2d, editingGuy)
    end


    for i = 1, #fiveGuys do
        --     texturedBox2d.drawNumbersOver(fiveGuys[i].b2d)
    end

    prof.pop('editGuy.draw drawSkinOver')
    cam:pop()

    love.graphics.setColor(0, 0, 0)
    --l
    --local a = h_slider('mainVolume', 0, 0, 100, mainVolume, 0, 1)
    --if a.value then
    --mainVolume = a.value
    --audioHelper.sendMessageToAudioThread({ type = "volume", data = mainVolume });
    --end

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
