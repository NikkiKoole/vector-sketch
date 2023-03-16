local scene       = {}
local gradient    = require 'lib.gradient'
local hit         = require 'lib.hit'
local skygradient = gradient.makeSkyGradient(8)
local Timer = require 'vendor.timer'

local transition = nil

local function myCircleStencilFunction(x,y,r)
	love.graphics.circle ("fill", x,y,r, 7)
end
local function drawCircleMask(backgroundAlpha, x,y, size)

    love.graphics.stencil (function() myCircleStencilFunction(x,y,size) end, "replace", 1)
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w,h = love.graphics.getDimensions()
    love.graphics.setStencilTest ("less", 1)
    love.graphics.rectangle('fill',0,0,w,h)
    love.graphics.setStencilTest ()

end

local function doCircleMaskTransition(x,y, onAfter)
    local w,h = love.graphics.getDimensions()
    transition = {alpha=0,x=x, y=y, radius=math.max(w,h)}
    Timer.tween(.3, transition, { alpha= 1})
    Timer.tween(1, transition, { radius= 0}, 'out-back')
    Timer.after(1, onAfter)
end

local function pointerPressed(x, y, id)
    print('five guys pressd')
    local w, h = love.graphics.getDimensions()
    if (hit.pointInRect(x, y, w - 22, 0, 25, 25)) then
       
        local w,h = love.graphics.getDimensions()
        doCircleMaskTransition(love.math.random()*w, love.math.random()*h, function()   transition= nil;SM.load("editGuy"); end)

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

   -- local x,y = love.mouse.getPosition()
   if transition then
    drawCircleMask(transition.alpha, transition.x,transition.y, transition.radius)
   end
end

function scene.update(dt)
    function love.touchpressed(id, x, y, dx, dy, pressure)
        pointerPressed(x, y, id)
    end

    function love.mousepressed(x, y, button, istouch, presses)
        if not istouch then
            pointerPressed(x, y, 'mouse')
        end
    end
    function love.keypressed(k)
        if k == 'c' then
            local w,h = love.graphics.getDimensions()
            doCircleMaskTransition(love.math.random()*w, love.math.random()*h, function() print('done!') end)
        end
    end
    Timer.update(dt)
end

return scene
