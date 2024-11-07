local scene            = {}

local gradient         = require 'lib.gradient'
local skygradient      = gradient.makeSkyGradient(10)
local hit              = require 'lib.hit'
local cam              = require('lib.cameraBase').getInstance()
local phys             = require 'lib.mainPhysics'
local swipes           = require 'lib.screen-transitions'
local Timer            = require 'vendor.timer'
local audioHelper      = require 'lib.melody-paint-audio-helper'
local texturedBox2d    = require 'lib.texturedBox2d'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local updatePart       = require 'lib.updatePart'
local ui               = require "lib.ui"

local generatePolygon  = require('lib.generate-polygon').generatePolygon

local JUST_ONE_GUY     = false


local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()

    local cx, cy = cam:getWorldCoordinates(x, y)



    local check = function(body)
        if (fiveGuys) then -- TODO MOVE THIS OUT, WAY TOO SPECIFIC
            for i = 1, #fiveGuys do
                local g = fiveGuys[i]
                if (g.b2d) then
                    for k, v in pairs(g.b2d) do
                        if body == v then
                            pickedFiveGuyIndex = i
                            editingGuy = fiveGuys[pickedFiveGuyIndex]
                            if SM.cName == 'outside' then
                                editingGuy.b2d.torso:applyLinearImpulse(0, -5000)
                            end
                            growl(1)
                            -- pickedFiveGuyIndex = i
                            -- editingGuy = fiveGuys[pickedFiveGuyIndex]
                            -- if SM.cName == 'outside' then
                            --     editingGuy.b2d.torso:applyLinearImpulse(0, -5000)
                            -- end
                        end
                    end
                end
            end
        end
    end

    local onPressedParams = {
        onPressedFunc = check,
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            -- TODO parametrtize this...!
            --
            local force = ud and ud.bodyType == 'torso' and 5000000 or 50000

            return force
        end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, onPressedParams)


    for i = 1, #fiveGuys do
        lookAt(fiveGuys[i], x, y)
    end
end


local function pointerReleased(x, y, id)
    gesture.maybeTrigger(id, x, y)
    phys.handlePointerReleased(x, y, id)
end

local function attachCallbacks()
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



function scene.load()
    attachCallbacks()
    JointsPressedButtonScale = 1
    WinePressedButtonScale = 1
    OrientationPressedButtonScale = 1
    ScenePressedButtonScale = 1
    phys.resetLists()
    uiClickSound   = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')
    -- uiTickSound    = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
    cloud          = love.graphics.newImage('assets/world/clouds1.png')
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
        editguys = love.graphics.newImage('assets/ui/big-button-editguys.png'),
        editguysmask = love.graphics.newImage('assets/ui/big-button-editguys-mask.png'),
        dice = love.graphics.newImage('assets/ui/big-button-dice.png'),
        dicemask = love.graphics.newImage('assets/ui/big-button-dice-mask.png'),
        fiveguys = love.graphics.newImage('assets/ui/big-button-fiveguys.png'),
        fiveguysmask = love.graphics.newImage('assets/ui/big-button-fiveguys-mask.png'),
        limp = love.graphics.newImage('assets/ui/big-limp.png'),
        straight = love.graphics.newImage('assets/ui/big-straight.png'),
        upside = love.graphics.newImage('assets/ui/big-upside-down.png'),
        upsidemask = love.graphics.newImage('assets/ui/big-upside-down-mask.png'),
        downside = love.graphics.newImage('assets/ui/big-downside-down.png'),
        downsidemask = love.graphics.newImage('assets/ui/big-downside-down-mask.png'),
        winegum = love.graphics.newImage('assets/ui/big-winegum.png'),
        winegummask = love.graphics.newImage('assets/ui/big-winegum-mask.png'),
    }
    ui2.circles    = {
        love.graphics.newImage('assets/ui/circle1.png'),
        love.graphics.newImage('assets/ui/circle2.png'),
        love.graphics.newImage('assets/ui/circle3.png'),
        love.graphics.newImage('assets/ui/circle4.png'),
    }



    winegums = {

        ruits = {
            love.graphics.newImage('assets/img/candyparts/ruit1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/ruit1-line.png'),
            love.graphics.newImage('assets/img/candyparts/ruit2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/ruit2-line.png'),

        },
        capsules = {
            love.graphics.newImage('assets/img/candyparts/capsule1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/capsule1-line.png'),
            love.graphics.newImage('assets/img/candyparts/capsule2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/capsule2-line.png'),

        },
        circs = {
            love.graphics.newImage('assets/img/candyparts/circle1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/circle1-line.png'),
            love.graphics.newImage('assets/img/candyparts/circle2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/circle2-line.png'),
        },
        octas = {
            love.graphics.newImage('assets/img/candyparts/octa1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/octa1-line.png'),
            love.graphics.newImage('assets/img/candyparts/octa2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/octa2-line.png'),

        },
        rekts = {
            love.graphics.newImage('assets/img/candyparts/rect1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/rect1-line.png'),
            love.graphics.newImage('assets/img/candyparts/rect2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/rect2-line.png'),

        }
    }






    sprietUnder = {}
    sprietOver  = {}


    if JUST_ONE_GUY then
        phys.setupBox2dSceneWithFiveGuys(pickedFiveGuyIndex, box2dGuyCreation.makeGuy, fiveGuys)

        --for i = 1, #fiveGuys do
        updatePart.updateAllParts(fiveGuys[pickedFiveGuyIndex])
    else
        phys.setupBox2dSceneWithFiveGuys(nil, box2dGuyCreation.makeGuy, fiveGuys)

        for i = 1, #fiveGuys do
            updatePart.updateAllParts(fiveGuys[i])
        end
        --end
    end


    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[1] });

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
    bottomfixture:setUserData(makeUserData('border', {}))


    -- put in a lot of winegums
    -- if true then

    --end
end

function addWineGums()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx

    local subPalettes = { 1, 8, 9, 9, 9, 10, 14, 15, 15, 15, 23, 32, 77, 87 }
    local amt = 3 + math.ceil(love.math.random() * 23)

    local types = {
        'capsule2', 'ruit', 'octagon', 'circle', 'rect3'
    }
    local dims = {
        { 350, 150 }, { 300, 200 }, { 200, 200 }, { 100, 100 }, { 200, 150 }
    }

    for i = 1, amt do
        local middleX = camtlx + boxWorldWidth / 2
        local x = middleX - (amt / 2) * 5 + (i * 5)
        local y = -5000 + love.math.random() * 10
        local body = love.physics.newBody(world, x, y, "dynamic")

        --local shape = love.physics.newPolygonShape(getRandomConvexPoly(150, 8)) --love.physics.newRectangleShape(width, height / 4)
        --local shape = phys.makeShape('capsule', 350, 150)
        --local shape = phys.makeShape('ruit', 300, 200)
        --local shape = phys.makeShape('octagon', 200, 200)
        --local shape = phys.makeShape('circle', 100)
        --local shape = phys.makeShape('rect3', 100, 200)

        local typeIndex = math.ceil(math.random() * #types)
        local wrnd = dims[typeIndex][1]
        local hrnd = dims[typeIndex][2]
        local shape = phys.makeShape(types[typeIndex], wrnd, hrnd)
        local fixture = love.physics.newFixture(body, shape, .2)

        fixture:setUserData(makeUserData('winegum', {}))
        -- fixture.
        local paletteIndex = subPalettes[math.ceil(math.random() * #subPalettes)]
        table.insert(winegums, {
            body = body,
            color = palettes[paletteIndex],
            index = math.ceil(love.math.random() * 7),
            --type = 'circle',
            --type = 'capsule',
            type = types[typeIndex],
            w = wrnd,
            h = hrnd
        })
    end
end

function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

function scene.unload()
    Timer.clear()
    local b = world:getBodies()

    for i = #b, 1, -1 do
        b[i]:destroy()
    end
    winegums = {}
    jointsEnabled = true
    upsideDown = false
end

local delta = 0
function scene.update(dt)
    delta = delta + dt
    -- Timer.update(dt)
    phys.handleUpdate(dt, cam)
    box2dGuyCreation.rotateAllBodies(world:getBodies(), dt)
    --   print(love.audio.getActiveSourceCount())


    JointsPressedButtonScale = JointsPressedButtonScale + 0.01
    if JointsPressedButtonScale > 1 then JointsPressedButtonScale = 1 end
    WinePressedButtonScale = WinePressedButtonScale + 0.01
    if WinePressedButtonScale > 1 then WinePressedButtonScale = 1 end
    OrientationPressedButtonScale = OrientationPressedButtonScale + 0.01
    if OrientationPressedButtonScale > 1 then OrientationPressedButtonScale = 1 end
    ScenePressedButtonScale = ScenePressedButtonScale + 0.01
    if ScenePressedButtonScale > 1 then ScenePressedButtonScale = 1 end
end

function scene.handleAudioMessage(msg)
    if msg.type == 'played' then
        local path = msg.data.path
        local index = math.ceil(math.random() * #fiveGuys)
        if JUST_ONE_GUY then index = pickedFiveGuyIndex end
        if path == "mipo/po3" or path == 'mipo/pi' then
            local sndLength = msg.data.source:getDuration() / msg.data.pitch
            --print('gonna say something', index, sndLength)
            mouthSay(fiveGuys[index], sndLength)
        elseif (path == 'Triangles 101' or path == 'Triangles 103') then
            --print('gonna breath', index)
            breathBody(fiveGuys[index])
        elseif (path == 'babirhodes/rhodes2') then
            doinkBody(fiveGuys[index])
        else
            -- eyeBlink(fiveGuys[index])
        end
        --print(path)
        --print('handling audio message from fiveGuy')
    end
end

function scene.draw()
    ui.handleMouseClickStart()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.setColor(1, 1, 1, .6)
    local sx, sy = createFittingScale(cloud, width, height)
    local bgscale = math.min(sx, sy)
    love.graphics.draw(cloud, 0, 0, 0, bgscale, bgscale)


    cam:push()

    -- prof.push('editGuy.draw drawSkinOver')


    love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)

    local amplitude = 50
    local freq = 2
    local a = math.sin(((delta or 0) + .2) * freq) / amplitude
    local a2 = math.sin((delta or 0) * freq) / amplitude

    for i = 1, sprietWidthAmt do
        local s = sprietUnder[i]
        s = sprietUnder[(sprietWidthAmt * 2) + i]
        texturedBox2d.drawSpriet(s[1], s[2], s[3], s[4] + (a2), s[5])
        s = sprietUnder[(sprietWidthAmt * 3) + i]
        texturedBox2d.drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
    end


    -- phys.drawWorld(world)
    texturedBox2d.drawWineGums(winegums)
    if JUST_ONE_GUY then
        texturedBox2d.drawSkinOver(fiveGuys[pickedFiveGuyIndex].b2d, fiveGuys[pickedFiveGuyIndex])
    else
        for i = 1, #fiveGuys do
            texturedBox2d.drawSkinOver(fiveGuys[i].b2d, fiveGuys[i])
        end
    end


    for i = 1, #fiveGuys do
        --     texturedBox2d.drawNumbersOver(box2dGuys[i])
    end


    love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)
    local a = math.sin((delta or 0) * freq) / amplitude
    for i = 1, sprietWidthAmt do
        local s = sprietOver[i]
        texturedBox2d.drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
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

        local x = w - size + size / 2 - (size * ScenePressedButtonScale) / 2
        local y = 0 + size / 2 - (size * ScenePressedButtonScale) / 2


        -- local x = w - size - (size * ScenePressedButtonScale) / 2
        --  local y = 0

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        sx = sx * ScenePressedButtonScale
        sy = sy * ScenePressedButtonScale
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        local sx, sy = createFittingScale(ui2.bigbuttons.editguys, size, size)
        sx = sx * ScenePressedButtonScale
        sy = sy * ScenePressedButtonScale
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ui2.bigbuttons.editguysmask, x, y, 0, sx, sy)
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(ui2.bigbuttons.editguys, x, y, 0, sx, sy)
        local a = ui.getUIRect('poepscoop', x, y, size, size)
        if a then
            --print('clicked here')
            ScenePressedButtonScale = 0.5
            Timer.clear()
            swipes.doCircleInTransitionOnPositionFunc(getPointToCenterTransitionOn, function()
                if scene then
                    SM.unload('outside')
                    SM.load('editGuy')
                    swipes.fadeInTransition()
                end
            end)
        end
    end

    if true then
        local size = h / 8
        local x = 0
        local y = h - size * 2 * 1.2

        local x = size / 2 - (size * OrientationPressedButtonScale) / 2
        local y = h - size * 2 * 1.2 + size / 2 - (size * OrientationPressedButtonScale) / 2
        --love.graphics.rectangle('fill', x, y, size, size)
        local a = ui.getUIRect('less-1', x, y, size, size)

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        sx = sx * OrientationPressedButtonScale
        sy = sy * OrientationPressedButtonScale
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        if not upsideDown then
            local sx, sy = createFittingScale(ui2.bigbuttons.upside, size, size)
            sx = sx * OrientationPressedButtonScale
            sy = sy * OrientationPressedButtonScale
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.bigbuttons.upsidemask, x, y, 0, sx, sy)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(ui2.bigbuttons.upside, x, y, 0, sx, sy)
        else
            local sx, sy = createFittingScale(ui2.bigbuttons.downside, size, size)
            sx = sx * OrientationPressedButtonScale
            sy = sy * OrientationPressedButtonScale
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.bigbuttons.downsidemask, x, y, 0, sx, sy)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(ui2.bigbuttons.downside, x, y, 0, sx, sy)
        end

        if a then
            upsideDown = not upsideDown
            OrientationPressedButtonScale = 0.5
            playSound(uiClickSound)
        end

        local x = size / 2 - (size * JointsPressedButtonScale) / 2
        local y = h - size * 3 * 1.2 + size / 2 - (size * JointsPressedButtonScale) / 2
        --love.graphics.rectangle('fill', x, y, size, size)
        local a = ui.getUIRect('less-1', x, y, size, size)
        ---print(inspect(a))

        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        sx = sx * JointsPressedButtonScale
        sy = sy * JointsPressedButtonScale
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        if not jointsEnabled then
            local sx, sy = createFittingScale(ui2.bigbuttons.limp, size, size)
            sx = sx * JointsPressedButtonScale
            sy = sy * JointsPressedButtonScale
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(ui2.bigbuttons.limp, x, y, 0, sx, sy)
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.bigbuttons.limp, x + 3, y + 3, 0, sx, sy)
        else
            local sx, sy = createFittingScale(ui2.bigbuttons.straight, size, size)
            sx = sx * JointsPressedButtonScale
            sy = sy * JointsPressedButtonScale
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(ui2.bigbuttons.straight, x, y, 0, sx, sy)
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.bigbuttons.straight, x - 3, y + 3, 0, sx, sy)
        end

        if a then
            toggleJoints()
            JointsPressedButtonScale = 0.5
            playSound(uiClickSound)
        end

        local x = size / 2 - (size * WinePressedButtonScale) / 2
        local y = h - size * 1.2 + size / 2 - (size * WinePressedButtonScale) / 2

        --local x = 0
        --local y = h - size * 1.2
        --love.graphics.rectangle('fill', x, y, size, size)
        local a = ui.getUIRect('less-1', x, y, size, size)
        ---print(inspect(a))
        love.graphics.setColor(0, 0, 0, 0.5)
        local sx, sy = createFittingScale(ui2.circles[1], size, size)
        sx = sx * WinePressedButtonScale
        sy = sy * WinePressedButtonScale
        love.graphics.draw(ui2.circles[1], x, y, 0, sx, sy)

        local sx, sy = createFittingScale(ui2.bigbuttons.winegum, size, size)
        sx = sx * WinePressedButtonScale
        sy = sy * WinePressedButtonScale
        love.graphics.setColor(0, 0, 0)
        love.graphics.draw(ui2.bigbuttons.winegummask, x + 3, y + 3, 0, sx, sy)

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(ui2.bigbuttons.winegum, x, y, 0, sx, sy)

        if a then
            if #winegums < 200 then
                addWineGums()
                WinePressedButtonScale = 0.5
                playSound(uiClickSound)
            end

            -- print('Body:getLocalPoint(worldX (number), worldY (number))')
        end
    end

    if false then
        love.graphics.setColor(0, 0, 0, 0.5)

        local stats = love.graphics.getStats()
        local memavg = calculateRollingAverage(rollingMemoryUsage)
        local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
        local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
        local fps = tostring(love.timer.getFPS()) .. 'fps'
        local draws = stats.drawcalls .. 'draws'
        love.graphics.print(mem .. '  ' .. vmem .. '  ' .. draws .. ' ' .. fps)
    end



    if swipes.getTransition() then
        -- print('transition found in outside')
        swipes.renderTransition()
    end
end

return scene
