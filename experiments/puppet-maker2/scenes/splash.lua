local Timer = require 'vendor.timer'
local fluxObject = { blobScale = 0, blobOffset = 0, headerOffset = 0, alpha1 = 0.1, alpha2 = .25 }
local scene = {}
local header = love.graphics.newImage('assets/intro/splash-header.png')
local blob = love.graphics.newImage('assets/intro/splash-blob.png')

function scene.modify(obj)
end

function gotoNext()
    Timer.tween(.5, fluxObject, { alpha1 = 0, alpha2 = 0 }, 'out-bounce')
    Timer.after(.6,
        function()
            Timer.clear()
            SM.load("intro")
        end)
end

function scene.handleAudioMessage()

end

function scene.load()
    splashSound:setVolume(.25)

    Timer.after(.5, function() splashSound:play() end)
    Timer.after(7, gotoNext)
    Timer.after(
        .2,
        function()
            Timer.tween(3, fluxObject, { blobScale = 1 }, 'out-elastic')
        end
    )
    Timer.after(
        .2,
        function()
            Timer.tween(1, fluxObject, { blobOffset = 1 })
        end
    )
    Timer.after(
        .1,
        function()
            Timer.tween(3, fluxObject, { headerOffset = 1 }, 'out-elastic')
        end
    )
end

function scene.update(dt)
    function love.keypressed(key, unicode)
        if key == 'm' then
            makeMarketingScreenshots('puppet2')
        end
        if key == 'escape' then love.event.quit() end
        gotoNext()
    end

    function love.touchpressed(key, unicode)
        gotoNext()
    end

    function love.mousepressed(key, unicode)
        gotoNext()
    end
end

function scene.draw()
    --print(unpack(creamColor))
    love.graphics.clear(creamColor)

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local blobWidth, blobHeight = blob:getDimensions()
    local scaleX = screenWidth / blobWidth
    local scaleY = screenHeight / blobHeight
    local scale = math.min(scaleX, scaleY)
    scale = scale * 0.8
    scale = scale * fluxObject.blobScale
    love.graphics.setColor(0, 0, 0, fluxObject.alpha1)
    love.graphics.draw(blob, screenWidth / 2, (screenHeight / 2) + ((1 - fluxObject.blobOffset) * blobHeight), 0, scale,
        scale, blobWidth / 2, blobHeight / 2)

    headerWidth, headerHeight = header:getDimensions()

    scaleX = screenWidth / headerWidth
    scaleY = screenHeight / headerHeight
    scale = math.min(scaleX, scaleY)
    scale = scale * 0.8
    love.graphics.setColor(222 / 255, 166 / 255, 40 / 255, fluxObject.alpha2)
    love.graphics.draw(header, screenWidth / 2, screenHeight + (1 - fluxObject.headerOffset) * headerHeight, 0, scale,
        scale, headerWidth / 2, headerHeight)
end

return scene
