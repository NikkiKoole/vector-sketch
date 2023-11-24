local audioHelper = require 'lib.audio-helper'
local gradient    = require 'lib.gradient'
local Timer       = require 'vendor.timer'
local scene       = {}


local skygradient = gradient.makeSkyGradient(16)

local hit         = require 'lib.hit'


local ui     = require 'lib.ui'
local Signal = require 'vendor.signal'

require 'src.editguy-ui'
require 'src.dna'


local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end


function attachCallbacks()
    Signal.register('click-settings-scroll-area-item', function(x, y)
        partSettingsScrollable(false, x, y)
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

    parts = generateParts()
    categories = {}
    setCategories()

    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });
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
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    -- local x, y = love.mouse.getPosition()

    -- if x >= 0 and x <= scrollListXPosition then
    -- this could be clicking in the head or body buttons
    --  headOrBody(false, x, y)
    --end


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
    --grid.isDragging = false

    gesture.maybeTrigger(id, x, y)
    -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen

    partSettingsSurroundings(false, x, y)
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

function scene.draw()
    local w, h = love.graphics.getDimensions()
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
    tabbedGridScroller()
end

return scene
