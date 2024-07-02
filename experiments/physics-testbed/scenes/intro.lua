local scene      = {}
local gradient   = require 'lib.gradient'
local fluxObject = { blobScale = 0, blobOffset = 0, headerOffset = 0, alpha1 = 0.1, alpha2 = .25 }
local Timer      = require 'vendor.timer'
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }

local isGoing    = false
function gotoNext()
    if not isGoing then
        isGoing = true

        Timer.tween(.3, fluxObject, { alpha1 = 0, alpha2 = 0 }, 'out-bounce')
        Timer.after(.4,
            function()
                Timer.clear()
                SM.load("downhill")
            end)
    end
end

function scene.load()

end

function scene.update(dt)
    function love.keypressed(key, unicode)
        if key == 'm' then
            --   makeMarketingScreenshots('phys')
        end
        if key == 'escape' then love.event.quit() end


        if key == '1' or key == '2' or key == '3' or key == '4' or key == '5' then
            print('key', key)
            gotoNext()
        else
            gotoNext()
        end
    end

    function love.touchpressed(key, unicode)
        gotoNext()
    end

    function love.mousepressed(key, unicode)
        gotoNext()
    end

    Timer.update(dt)
end

local dayTimeTransition = { t = 0 }

function scene.draw()
    love.graphics.setColor(1, 1, 1, 1)
    local skyGradient2 = gradient.lerpSkyGradient(10, 22, dayTimeTransition.t)
    love.graphics.draw(skyGradient2, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.print('press 1 - 5 to pick a mipo')
    --love.graphics.clear(creamColor)
end

return scene
