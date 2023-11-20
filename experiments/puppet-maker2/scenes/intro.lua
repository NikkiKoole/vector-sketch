local scene         = {}
local poppetjeMaker = love.graphics.newImage('assets/intro/puppetmaker2.png')
local doggie        = love.graphics.newImage('assets/intro/doggie.png')
local darkness      = love.graphics.newImage('assets/img/worldparts/darkness.png')
local time          = 0

local Timer         = require 'vendor.timer'
local fluxObject    = { headerOffset = 0, guyY = 0, darknessAlpha = 0, puppetMakerAlpha = 0 }
local numbers       = require 'lib.numbers'

--require 'lib.printC'
local parentize     = require 'lib.parentize'
local mesh          = require 'lib.mesh'
local render        = require 'lib.render'
local camera        = require 'lib.camera'
local cam           = require('lib.cameraBase').getInstance()
local bbox          = require 'lib.bbox'
local parse         = require 'lib.parse-file'
local bbox          = require 'lib.bbox'
local wipes         = require 'src.screen-transitions'

local audioHelper   = require 'lib.audio-helper'


function scene.load()
    bgColor = { unpack(creamColor) }
    introSound:setVolume(.5)
    introSound:setLooping(true)
    introSound:play()


    Timer.after(.1, function()
        Timer.tween(1, bgColor, { [1] = blueColor[1],[2] = blueColor[2],[3] = blueColor[3] }, 'out-cubic')
    end)

    Timer.after(1, function()
        Timer.tween(1, fluxObject, { darknessAlpha = .25 }, 'out-cubic')
    end)
    Timer.after(3, function()
        Timer.tween(3, fluxObject, { puppetMakerAlpha = 1 }, 'out-cubic')
    end)
    Timer.after(
        .1,
        function()
            Timer.tween(3, fluxObject, { headerOffset = 1 }, 'out-elastic')
        end
    )
    Timer.after(
        1,
        function()
            Timer.tween(2, fluxObject, { guyY = 1 }, 'out-elastic')
        end
    )

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }


    mipo = parse.parseFile('/assets/intro/mipo.polygons.txt')[1]

    root.children = { mipo }

    stripPath(root, '/experiments/puppet%-maker2/')
    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)

    render.renderThings(root, true)

    local w, h = love.graphics.getDimensions()

    local w1 = w / 1.5
    local h1 = h / 1.5
    local y1 = 100
    local mipobb = bbox.getBBoxRecursive(mipo)

    local mw = mipobb[4] - mipobb[2]
    local mh = mipobb[3] - mipobb[1]
    local sx = w1 / mw
    local sy = h1 / mh
    mipo.transforms.l[2] = y1 - 100
    mipo.transforms.l[4] = math.max(sx, sy)
    mipo.transforms.l[5] = math.max(sx, sy)

    cam:update(w, h)

    for i = 1, #mipo.children do
        local letter = mipo.children[i]
        if letter.children then
            for j = 1, #letter.children do
                letter.children[j].color[4] = 0
            end
        end
    end

    Timer.after(15, function()
        Timer.tween(1, fluxObject, { darknessAlpha = 0, puppetMakerAlpha = 0 })
    end)
    Timer.after(1.5, doTheMipoAnimation)
end

function playSound(sound, p, volumeMultiplier)
    local s = sound:clone()


    s:setPitch(p)

    love.audio.play(s)
    return s
end

function doTheMipoAnimation()
    -- show mipo letters

    local M = mipo.children[2]
    local I = mipo.children[3]
    local P = mipo.children[4]
    local O = mipo.children[5]

    local originM = {}
    local originI = {}
    local originP = {}
    local originO = {}

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

    local function randomTweenLetterPoints(letters, origins)
        for k = 1, #letters do
            local l           = letters[k]
            local originIndex = 1
            for i = 1, #l.children do
                for j = 1, #l.children[i].points do
                    Timer.tween(0.4, l.children[i].points[j],
                        {
                            [1] = origins[k][originIndex][1] + love.math.random() * 100 - 5,
                            [2] = origins[k][originIndex][2] + love.math.random() * 40 - 20
                        })

                    originIndex = originIndex + 1
                end
            end
        end
    end

    -- MI
    Timer.after(0.5, function()
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
    Timer.after(1, function()
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

    Timer.after(15, function()
        local w, h = love.graphics.getDimensions()
        fadeOutTransition(function()
            gotoNext()
        end)
        -- gotoNext()
    end)
end

function scene.handleAudioMessage()

end

function scene.unload()
    print('asdasd')

    Timer.clear()
end

function gotoNext()
    audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
    Timer.clear()
    SM.unload('intro')
    SM.load("editGuy")
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

    function love.touchpressed(key, unicode)
        gotoNext()
    end

    function love.mousepressed(key, unicode)
        gotoNext()
    end

    time = time + dt
    Timer.update(dt)

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
    print(unpack(creamColor))
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
    scaleX = screenWidth / blobWidth
    scaleY = screenHeight / blobHeight
    scale = math.min(scaleX, scaleY)
    scale = scale * 0.5
    scale = scale + (math.sin(time) * 0.01)

    love.graphics.setColor(1, 1, 1, 0.5 * (fluxObject.headerOffset) * fluxObject.puppetMakerAlpha)
    love.graphics.draw(poppetjeMaker, 1 + (screenWidth / 2) - ((1 - fluxObject.headerOffset) * screenWidth / 2),
        screenHeight - (blobHeight * scale), 0, scale, scale, blobWidth / 2, blobHeight / 2)

    love.graphics.setColor(1, 1, 1, fluxObject.puppetMakerAlpha)

    love.graphics.draw(poppetjeMaker, (screenWidth / 2) - ((1 - fluxObject.headerOffset) * screenWidth / 2),
        screenHeight - (blobHeight * scale), 0, scale, scale, blobWidth / 2, blobHeight / 2)

    if transition then
        wipes.renderTransition(transition)
    end
end

return scene
