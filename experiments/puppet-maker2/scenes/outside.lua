local scene       = {}

local gradient    = require 'lib.gradient'
local skygradient = gradient.makeSkyGradient(10)
local hit         = require 'lib.hit'
local cam         = require('lib.cameraBase').getInstance()
local phys        = require 'src.mainPhysics'
local swipes      = require 'src.screen-transitions'
local Timer       = require 'vendor.timer'


local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local interacted = handlePointerPressed(x, y, id, cam)


    local size = (h / 8) -- margin around panel
    if (hit.pointInRect(x, y, w - size, 0, size, size)) and not swipes.getTransition() then
        local sx, sy = 0, 0 --getPointToCenterTransitionOn()
        Timer.clear()
        swipes.doCircleInTransition(sx, sy, function()
            if scene then
                SM.unload('outside')
                SM.load('editGuy')
                swipes.fadeInTransition()
            end
        end)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if not istouch then
        -- print('mousepreseed outside')
        pointerPressed(x, y, 'mouse')
        -- ui.addToPressedPointers(x, y, 'mouse')
    end
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

    setupBox2dScene()

    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local dist = 30 --  screenWorldWidth / 200
    sprietWidthAmt = boxWorldWidth / dist
    local startX = camtlx
    local startY = cambry + 100
    for i = 1, sprietWidthAmt do
        sprietUnder[i] = { startX + i * dist, startY - 500, math.ceil(love.math.random() * #spriet), 0, 2.1 }
        sprietUnder[sprietWidthAmt + i] = { startX + i * dist, startY - 400, math.ceil(love.math.random() * #spriet),
            0, 1.8 }
        sprietUnder[(sprietWidthAmt * 2) + i] = { startX + i * dist, startY - 300,
            math.ceil(love.math.random() * #spriet), 0, 1.5 }
        sprietUnder[(sprietWidthAmt * 3) + i] = { startX + i * dist, startY - 200,
            math.ceil(love.math.random() * #spriet), 0, 1.2 }
        sprietOver[i] = { startX + i * dist, startY - 100, math.ceil(love.math.random() * #spriet), 0, 1 }
    end


    local wallThick = 200
    -- local sideHigh = 20000
    local half = wallThick / 2
    local bottom = love.physics.newBody(world, w / 2, cambry, "static")
    local bottomshape = love.physics.newRectangleShape(boxWorldWidth, wallThick)
    local bottomfixture = love.physics.newFixture(bottom, bottomshape, 1)
end

function scene.unload()
    local b = world:getBodies()
    for i = #b, 1, -1 do
        b[i]:destroy()
    end
end

local delta = 0
function scene.update(dt)
    delta = delta + dt
    Timer.update(dt)
    handleUpdate(dt, cam)
    rotateAllBodies(world:getBodies(), dt)
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
        end
    end
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


    love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)

    local amplitude = 50
    local freq = 2
    local a = math.sin(((delta or 0) + .2) * freq) / amplitude
    local a2 = math.sin((delta or 0) * freq) / amplitude

    for i = 1, sprietWidthAmt do
        local s = sprietUnder[i]
        s = sprietUnder[(sprietWidthAmt * 2) + i]
        drawSpriet(s[1], s[2], s[3], s[4] + (a2), s[5])
        s = sprietUnder[(sprietWidthAmt * 3) + i]
        drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
    end

    for i = 1, #fiveGuys do
        drawSkinOver(fiveGuys[i].b2d, editingGuy)
    end


    for i = 1, #fiveGuys do
        --     drawNumbersOver(box2dGuys[i])
    end


    love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)
    local a = math.sin((delta or 0) * freq) / amplitude
    for i = 1, sprietWidthAmt do
        local s = sprietOver[i]
        drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
        s = sprietOver[sprietWidthAmt + i]
        --drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
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

    if swipes.getTransition() then
        -- print('transition found in outside')
        swipes.renderTransition()
    end
end

return scene
