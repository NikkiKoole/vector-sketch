local scene       = {}
local gradient    = require 'lib.gradient'
local hit         = require 'lib.hit'
local skygradient = gradient.makeSkyGradient(8)

local function pointerPressed(x, y, id)
    print('five guys pressd')
    local w, h = love.graphics.getDimensions()
    if (hit.pointInRect(x, y, w - 22, 0, 25, 25)) then
        SM.load("editGuy")
    end
end



function scene.load()
    print(myWorld)
end

function scene.draw()
    love.graphics.clear(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    love.graphics.setColor(1, 0, 1)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('fill', w - 25, 0, 25, 25)
end

function scene.update()
    function love.touchpressed(id, x, y, dx, dy, pressure)
        pointerPressed(x, y, id)
    end

    function love.mousepressed(x, y, button, istouch, presses)
        if not istouch then
            pointerPressed(x, y, 'mouse')
        end
    end
end

return scene
