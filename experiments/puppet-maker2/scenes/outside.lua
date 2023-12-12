local scene       = {}

local gradient    = require 'lib.gradient'
local skygradient = gradient.makeSkyGradient(10)
local hit         = require 'lib.hit'
local cam         = require('lib.cameraBase').getInstance()
local phys        = require 'src.mainPhysics'

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local interacted = handlePointerPressed(x, y, id, cam)


    local size = (h / 8) -- margin around panel
    if (hit.pointInRect(x, y, w - size, 0, size, size)) then
        print('jo transition baby!')
        --local sx, sy = getPointToCenterTransitionOn()
        SM.unload('outside')
        --Timer.clear()

        -- doCircleInTransition(sx, sy, function() if scene then SM.load('fiveGuys') end end)
        SM.load('editGuy')
        --transitionHead(true, 'fiveGuys')
    end
end
function love.mousepressed(x, y, button, istouch, presses)
    if not istouch then
        print('mousepreseed outside')
        pointerPressed(x, y, 'mouse')
        -- ui.addToPressedPointers(x, y, 'mouse')
    end
end

function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

function scene.load()
    phys.resetLists()
    cloud          = love.graphics.newImage('assets/world/clouds1.png', { mipmaps = true })
    borderImage    = love.graphics.newImage("assets/ui/border_shaduw.png")
    spriet         = {
        love.graphics.newImage('assets/world/spriet1.png'),
        love.graphics.newImage('assets/world/spriet2.png'),
        love.graphics.newImage('assets/world/spriet3.png'),
        love.graphics.newImage('assets/world/spriet4.png'),
        love.graphics.newImage('assets/world/spriet5.png'),
        love.graphics.newImage('assets/world/spriet6.png'),
        love.graphics.newImage('assets/world/spriet7.png'),
        love.graphics.newImage('assets/world/spriet8.png'),
    }
    ui2            = {}
    ui2.bigbuttons = {
        fiveguys = love.graphics.newImage('assets/ui/big-button-fiveguys.png'),
        fiveguysmask = love.graphics.newImage('assets/ui/big-button-fiveguys-mask.png'),
    }
    ui2.circles    = {
        love.graphics.newImage('assets/ui/circle1.png'),
        love.graphics.newImage('assets/ui/circle2.png'),
        love.graphics.newImage('assets/ui/circle3.png'),
        love.graphics.newImage('assets/ui/circle4.png'),
    }
    sprietUnder    = {}
    sprietOver     = {}

    setupBox2dScene(5)
end

function scene.unload()
    local b = world:getBodies()
    for i = #b, 1, -1 do
        b[i]:destroy()
    end
end

function scene.update(dt)
    handleUpdate(dt, cam)
    rotateAllBodies(world:getBodies(), dt)
end

function scene.draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.setColor(1, 1, 1, .6)
    local sx, sy = createFittingScale(cloud, width, height)
    local bgscale = math.min(sx, sy)
    love.graphics.draw(cloud, 0, 0, 0, bgscale, bgscale)


    cam:push()
    -- phys.drawWorld(world)
    -- prof.push('editGuy.draw drawSkinOver')
    for i = 1, #box2dGuys do
        drawSkinOver(box2dGuys[i], editingGuy.values, editingGuy.creation, editingGuy.multipliers, editingGuy
        .positioners)
    end
    for i = 1, #box2dGuys do
        --     drawNumbersOver(box2dGuys[i])
    end

    -- prof.pop('editGuy.draw drawSkinOver')
    cam:pop()


    local bw, bh = borderImage:getDimensions()
    local w, h = love.graphics.getDimensions();
    love.graphics.setColor(.9, .8, .8, 0.9)
    love.graphics.draw(borderImage, 0, 0, 0, w / bw, h / bh)

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
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
        end
    end
end

return scene
