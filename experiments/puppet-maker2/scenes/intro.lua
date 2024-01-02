local scene            = {}
local poppetjeMaker    = love.graphics.newImage('assets/intro/puppetmaker2.png')
local darkness         = love.graphics.newImage('assets/img/worldparts/darkness.png')
local time             = 0

local Timer            = require 'vendor.timer'
local fluxObject       = {
    headerOffset = 0,
    guyY = 0,
    darknessAlpha = 0,
    puppetMakerAlpha = 0,
    circlesOpacity = 0,
    circlesY1 = 2.5,
    circlesY2 = 2.5,
    circlesY3 = 2.5,
    circlesY4 = 2.5,
    circlesY5 = 2.5,
    mipoAlpha = 0,
}

--require 'lib.printC'
local parentize        = require 'lib.parentize'
local mesh             = require 'lib.mesh'
local render           = require 'lib.render'
local camera           = require 'lib.camera'
local cam              = require('lib.cameraBase').getInstance()
local bbox             = require 'lib.bbox'
local parse            = require 'lib.parse-file'
local bbox             = require 'lib.bbox'

local swipes           = require 'src.screen-transitions'
local audioHelper      = require 'lib.audio-helper'
local ui               = require 'lib.ui'
local readAndParse     = require 'src.readAndParse'

local updatePart       = require 'src.updatePart'
local texturedBox2d    = require 'src.texturedBox2d'
local box2dGuyCreation = require 'src.box2dGuyCreation'
local cam              = require('lib.cameraBase').getInstance()

local gradient         = require 'lib.gradient'
local skygradient      = gradient.makeSkyGradient(16)
-- cream -> blauw
-- achtergrond pencil lines ding
-- mipo showing tween in
-- mipo done, puppetmaker shown
-- 5 circles
-- next state

local function randomTweenLetterPoints(letters, origins)
    for k = 1, #letters do
        local l           = letters[k]
        local originIndex = 1
        for i = 1, #l.children do
            for j = 1, #l.children[i].points do
                Timer.tween(0.4, l.children[i].points[j],
                    {
                        [1] = origins[k][originIndex][1] + love.math.random() * 10 - 5,
                        [2] = origins[k][originIndex][2] + love.math.random() * 40 - 20
                    })

                originIndex = originIndex + 1
            end
        end
    end
end

local function nextState()
    if (statePointer < #states) then
        statePointer = statePointer + 1
        states[statePointer]()
    else
        -- print('next!?')
    end
end

local function backgroundCreamToBlue()
    Timer.clear()
    bgColor = { unpack(creamColor) }
    Timer.after(.1, function()
        Timer.tween(1, bgColor, { [1] = blueColor[1],[2] = blueColor[2],[3] = blueColor[3] }, 'out-cubic')
    end)
    Timer.after(1.2, function()
        nextState()
    end)
end

local function fadeInPencilBackground()
    Timer.clear()
    bgColor = { unpack(blueColor) }
    Timer.after(.1, function()
        Timer.tween(.5, fluxObject, { darknessAlpha = .25 }, 'out-cubic')
    end)
    Timer.after(.8, function()
        nextState()
    end)
end

local function tweenInMipoHeader()
    Timer.clear()
    bgColor = { unpack(blueColor) }
    fluxObject.darknessAlpha = .25


    -- MI
    Timer.after(0.25, function()
        for i = 1, #M.children do
            Timer.tween(0.5, M.children[i].color, { [4] = 1 })
        end
        Timer.after(0.1, function()
            for i = 1, #I.children do
                Timer.tween(0.5, I.children[i].color, { [4] = 1 })
            end
        end)
        local sound = miSound1
        if love.math.random() < 0.2 then
            sound = miSound2
        end
        playSound(sound, .7 + love.math.random() * 0.5)

        Timer.every(.5, function()
            local letters = { M, I }
            local origins = { originM, originI }

            randomTweenLetterPoints(letters, origins)
            mesh.meshAll(mipo)
        end)
    end)

    -- PO
    Timer.after(.75, function()
        for i = 1, #P.children do
            Timer.tween(0.5, P.children[i].color, { [4] = 1 })
        end
        Timer.after(0.1, function()
            for i = 1, #O.children do
                Timer.tween(0.5, O.children[i].color, { [4] = 1 })
            end
        end)

        local sound = poSound1
        if love.math.random() < 0.2 then
            sound = poSound2
        end
        playSound(sound, .7 + love.math.random() * 0.5)

        Timer.every(.5, function()
            local letters = { P, O }
            local origins = { originP, originO }
            randomTweenLetterPoints(letters, origins)

            mesh.meshAll(mipo)
        end)
    end)

    Timer.after(1.5, function()
        nextState()
    end)
end

local function moveMipoAround()
    local letters = { M, I, P, O }
    local origins = { originM, originI, originP, originO }
    randomTweenLetterPoints(letters, origins)
    mesh.meshAll(mipo)

    Timer.every(.5, function()
        randomTweenLetterPoints(letters, origins)
        mesh.meshAll(mipo)
    end)
end

local function setAllMipoLettersAlpha(v)
    for i = 1, #mipo.children do
        local letter = mipo.children[i]
        if letter.children then
            for j = 1, #letter.children do
                letter.children[j].color[4] = v
            end
        end
    end
end

local function tweenInMipoPuppetMakerHeader()
    Timer.clear()
    bgColor = { unpack(blueColor) }
    fluxObject.darknessAlpha = .25

    setAllMipoLettersAlpha(1)

    moveMipoAround()

    --Timer.after(.3, function()
    Timer.tween(.3, fluxObject, { puppetMakerAlpha = 1 }, 'out-cubic')
    --end)

    Timer.after(.1, function()
        nextState()
    end)
end

local function tweenIn5Circles()
    Timer.clear()
    setAllMipoLettersAlpha(1)
    moveMipoAround()
    fluxObject.puppetMakerAlpha = 1
    fluxObject.circlesOpacity = 1
    Timer.after(.2, function()
        nextState()
    end)
end

local function hideBigMipo()
    Timer.clear()
    --setAllMipoLettersAlpha(1)
    moveMipoAround()
    fluxObject.puppetMakerAlpha = 1
    fluxObject.circlesOpacity = 1
    fluxObject.mipoAlpha = 1

    Timer.after(.1, function()
        nextState()
    end)
end

local function moveHeaderAndCircles()
    Timer.clear()
    moveMipoAround()
    fluxObject.puppetMakerAlpha = 1
    fluxObject.circlesOpacity = 1

    Timer.tween(.4, fluxObject, { puppetMakerAlpha = 0.5 })

    Timer.after(.1, function()
        Timer.tween(1, fluxObject, { circlesY1 = 0.70 }, 'bounce')
    end)
    Timer.after(.2, function()
        Timer.tween(1, fluxObject, { circlesY2 = 0.72 }, 'out-elastic')
    end)
    Timer.after(.3, function()
        Timer.tween(.55, fluxObject, { circlesY3 = 0.74 }, 'in-out-quad')
    end)
    Timer.after(.4, function()
        Timer.tween(1, fluxObject, { circlesY4 = 0.74 }, 'bounce')
    end)
    Timer.after(.5, function()
        Timer.tween(.65, fluxObject, { circlesY5 = 0.65 })
    end)
    Timer.after(1.5, function()
        nextState()
    end)
end


local function makeRandomMipoSound()
    local rnd = .2 + love.math.random() * 2
    local rnd2 = .2 + love.math.random() * 1
    Timer.after(rnd, function()
        --say MI
        -- print('MI')
        local sound = miSound1
        if love.math.random() < 0.2 then
            sound = miSound2
        end

        local pitch = .7 + love.math.random() * 0.5
        local sndLength = sound:getDuration() / pitch
        playSound(sound, pitch)
        local index1 = math.ceil(love.math.random() * #fiveGuys)
        mouthSay(fiveGuys[index1], sndLength)


        Timer.after(rnd2, function()
            --say MI
            --print('PO')
            local sound = poSound1
            if love.math.random() < 0.2 then
                sound = poSound2
            end
            local pitch = .7 + love.math.random() * 0.5
            local sndLength = sound:getDuration() / pitch
            playSound(sound, pitch)
            local index2 = math.ceil(love.math.random() * #fiveGuys)
            if index2 == index2 then
                index2 = math.ceil(love.math.random() * #fiveGuys)
            end
            mouthSay(fiveGuys[index2], sndLength)
            makeRandomMipoSound()
        end)
    end)
end

local function last()
    Timer.clear()
    moveMipoAround()
    fluxObject.puppetMakerAlpha = 0.5
    fluxObject.circlesOpacity = 1
    fluxObject.circlesY1 = 0.7
    fluxObject.circlesY2 = 0.72
    fluxObject.circlesY3 = 0.74
    fluxObject.circlesY4 = 0.74
    fluxObject.circlesY5 = 0.65

    Timer.tween(.4, fluxObject, { puppetMakerAlpha = 0.15 })
    makeRandomMipoSound()
end

function scene.load()
    --backgroundCreamToBlue()


    if not ui2 then
        ui2 = {}
    end
    ui2.circles = {
        love.graphics.newImage('assets/ui/circle1.png'),
        love.graphics.newImage('assets/ui/circle2.png'),
        love.graphics.newImage('assets/ui/circle3.png'),
        love.graphics.newImage('assets/ui/circle4.png'),
    }

    states = {
        backgroundCreamToBlue,
        fadeInPencilBackground,
        tweenInMipoHeader,
        tweenInMipoPuppetMakerHeader,
        tweenIn5Circles,
        hideBigMipo,
        moveHeaderAndCircles,
        last
    }

    statePointer = 1


    bgColor = { unpack(creamColor) }
    introSound:setVolume(.5)
    introSound:setLooping(true)
    introSound:play()

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }


    mipo = parse.parseFile('/assets/intro/mipo.polygons.txt')[1]

    root.children = { mipo }

    readAndParse.stripPath(root, '/experiments/puppet%-maker2/')
    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)

    render.renderThings(root, true)

    local w, h = love.graphics.getDimensions()

    local w1 = w / 2
    local h1 = h / 2
    local y1 = 0
    local mipobb = bbox.getBBoxRecursive(mipo)

    local mw = mipobb[4] - mipobb[2]
    local mh = mipobb[3] - mipobb[1]
    local sx = w1 / mw
    local sy = h1 / mh
    mipo.transforms.l[2] = y1
    mipo.transforms.l[4] = math.max(sx, sy)
    mipo.transforms.l[5] = math.max(sx, sy)


    camera.centerCameraOnPosition(0, y1, w, h)
    cam:update(w, h)

    M = mipo.children[2]
    I = mipo.children[3]
    P = mipo.children[4]
    O = mipo.children[5]

    originM = {}
    originI = {}
    originP = {}
    originO = {}

    local function cachePoints(letter, cacheHere)
        for i = 1, #letter.children do
            for j = 1, #letter.children[i].points do
                table.insert(cacheHere, { letter.children[i].points[j][1], letter.children[i].points[j][2] })
            end
        end
    end

    cachePoints(M, originM)
    cachePoints(I, originI)
    cachePoints(P, originP)
    cachePoints(O, originO)


    setAllMipoLettersAlpha(0)

    circles = {}
    for i = 1, 5 do
        local index = math.ceil(love.math.random() * #ui2.circles)
        circles[i] = { index = index }
    end

    nextState()

    for i = 1, #fiveGuys do
        fiveGuys[i].b2d = box2dGuyCreation.makeGuy( -10000, 0, fiveGuys[i])
    end
    for i = 1, #fiveGuys do
        updatePart.updateAllParts(fiveGuys[i])
    end
    for i = 1, #fiveGuys do
        texturedBox2d.drawSkinOver(fiveGuys[i].b2d, fiveGuys[i])
    end
end

function scene.handleAudioMessage()

end

function scene.unload()
    Timer.clear()

    local b = world:getBodies()

    for i = #b, 1, -1 do
        b[i]:destroy()
    end
end

function gotoNext()
    nextState()
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end


function pointerPressed(x, y, id)
    --
    local w, h = love.graphics.getDimensions()
    local size = w / 5

    for i = 1, #circles do
        local x2 = (i - 1) * size
        local ys = { fluxObject.circlesY1, fluxObject.circlesY2, fluxObject.circlesY3, fluxObject.circlesY4,
            fluxObject.circlesY5, }
        local y2 = (h - size) * ys[i]
        if getDistance(x, y, x2 + size / 2, y2 + size / 2) < ((size / 2) - (size / 10)) then
            swipes.doCircleInTransition(x2 + size / 2, y2 + size / 2, function()
                pickedFiveGuyIndex = i
                SM.unload('intro')
                SM.load('editGuy')
            end)
        end
    end
    for i = 1, #fiveGuys do
        lookAt(fiveGuys[i], x * 4, y * 4)
    end
end

function scene.update(dt)
    if splashSound:isPlaying() then
        local volume = splashSound:getVolume()
        splashSound:setVolume(volume * .90)
        if volume < 0.01 then
            splashSound:stop()
        end
    end
    function love.keypressed(key, unicode)
        if key == 'escape' then love.event.quit() end
        if key == 'space' then
            gotoNext()
        end
    end

    function love.touchpressed(id, x, y)
        pointerPressed(x, y, id)
        gotoNext()
    end

    function love.mousepressed(x, y)
        pointerPressed(x, y, 'mouse')
        gotoNext()
    end

    time = time + dt


    function love.resize(w, h)
        local w, h = love.graphics.getDimensions()





        -- local x1, y1, w1, h1 = getCameraDataZoomOnHeadAndBody()
        -- tweenCameraData = { x = x1, y = y1, w = w1, h = h1 }

        -- camera.setCameraViewport(cam, w, h)
        --  camera.centerCameraOnPosition(x1, y1, w1, h1)
        --  cam:update(w, h)
    end
end

function scene.draw()
    --love.graphics.clear(238 / 255, 226 / 255, 188 / 255)
    love.graphics.clear(1, 1, 1)
    local w, h = love.graphics.getDimensions()
    -- print(unpack(creamColor))
    love.graphics.setColor(bgColor)
    love.graphics.rectangle('fill', 0, 0, w, h)

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local darkWidth, darkHeight = darkness:getDimensions()

    love.graphics.setColor(1, 1, 1, fluxObject.darknessAlpha)
    local dscaleX = screenWidth / darkWidth
    local dscaleY = screenHeight / darkHeight
    love.graphics.draw(darkness, 0, 0, 0, dscaleX, dscaleY)

    cam:push()
    render.renderThings(root, true)
    cam:pop()

    local blobWidth, blobHeight = poppetjeMaker:getDimensions()

    local bx, by = createFittingScale(poppetjeMaker, w / 2, w / 2)
    local scale = math.min(bx, by)
    scale = scale * (0.9 + (math.sin(time * 3) + 1) * 0.05)
    local r = (0.7 + math.sin(time) * 0.3) * 0.2

    love.graphics.setColor(1, 0.945, 0.91, fluxObject.puppetMakerAlpha)

    love.graphics.draw(poppetjeMaker, (screenWidth * 3 / 4), (screenHeight * 5 / 6), r, scale, scale, blobWidth / 2,
        blobHeight / 2)







    local size = w / 5



    local function myStencilFunction()
        --local r = w / 2
        --if picked then
        --    r = r + (math.sin(love.timer.getTime() * 5) * (r / 20))
        --end
        for i = 1, #fiveGuys do
            local x2 = (i - 1) * size
            local ys = { fluxObject.circlesY1, fluxObject.circlesY2, fluxObject.circlesY3, fluxObject.circlesY4,
                fluxObject.circlesY5, }
            local y2 = (h - size) * ys[i]
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', x2 + size / 2, y2 + size / 2, size / 2 - (size / 10))
        end
    end

    love.graphics.stencil(myStencilFunction, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.setStencilTest()

    local dpi = love.graphics.getDPIScale()
    for i = 1, #fiveGuys do


        local function myStencilFunctionIndexed()
            --local r = w / 2
            --if picked then
            --    r = r + (math.sin(love.timer.getTime() * 5) * (r / 20))
            --end
            --for i = 1, #fiveGuys do
                local x2 = (i - 1) * size
                local ys = { fluxObject.circlesY1, fluxObject.circlesY2, fluxObject.circlesY3, fluxObject.circlesY4,
                    fluxObject.circlesY5, }
                local y2 = (h - size) * ys[i]
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', x2 + size / 2, y2 + size / 2, size / 2 - (size / 10))
            --end
        end


        love.graphics.push()

        love.graphics.stencil(myStencilFunctionIndexed, "replace", 1)

        love.graphics.setStencilTest("greater", 0)


--        love.graphics.rectangle('fill', 0,0, w,h)


        local part = fiveGuys[i].b2d.head or fiveGuys[i].b2d.torso
        local dimW = fiveGuys[i].b2d.head and fiveGuys[i].dna.creation.head.w or fiveGuys[i].dna.creation.torso.w
        local dimH = fiveGuys[i].b2d.head and fiveGuys[i].dna.creation.head.h or fiveGuys[i].dna.creation.torso.h

        local myOptimalScale = math.min(size / dimW, size / dimH)  * 0.7
        love.graphics.scale(myOptimalScale, myOptimalScale) -- reduce everything by 50% in both X and Y coordinates


        local x = (i - 1) * size * 1 / myOptimalScale
        local ys = { fluxObject.circlesY1, fluxObject.circlesY2, fluxObject.circlesY3, fluxObject.circlesY4,
            fluxObject.circlesY5 }
        local y = (h - size) * ys[i] * (1 / myOptimalScale)
        local xPos = x + (size / 2) * (1 / myOptimalScale)

        local extraOffset = fiveGuys[i].b2d.head and (dimH/2) or 0
        local yPos = y + ((size / 2  )) * (1 / myOptimalScale)   + extraOffset 

        part:setPosition(xPos, yPos)
        texturedBox2d.drawSkinOver(fiveGuys[i].b2d, fiveGuys[i], true)
        love.graphics.setStencilTest()

        love.graphics.pop()
    end



    for i = 1, #circles do
        local c = circles[i]
        local sx, sy = createFittingScale(ui2.circles[c.index], size, size)
        love.graphics.setColor(1, 0.945, 0.91, fluxObject.circlesOpacity)
        local x = (i - 1) * size
        local ys = { fluxObject.circlesY1, fluxObject.circlesY2, fluxObject.circlesY3, fluxObject.circlesY4,
            fluxObject.circlesY5 }
        local y = (h - size) * ys[i]
        love.graphics.draw(ui2.circles[c.index], x, y, 0, sx, sy)


        --love.graphics.circle('fill', x + size / 2, y + size / 2, (size / 2) - (size / 10))
    end

    if swipes.getTransition() then
        swipes.renderTransition(swipes.getTransition())
    end
end

return scene
