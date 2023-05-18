local Timer = require 'vendor.timer'

local function myCircleStencilFunction(x, y, r, s)
    love.graphics.circle("fill", x, y, r, s)
end
local function drawCircleMask(backgroundAlpha, x, y, size, segments)
    love.graphics.stencil(function() myCircleStencilFunction(x, y, size, segments) end, "replace", 1)
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.setStencilTest("less", 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setStencilTest()
end

local function myRectStencilFunction(x, y, w, h)
    love.graphics.push()
    --love.graphics.translate( -x, -y)
    --love.graphics.rotate(0.5)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.pop()
end
local function drawRectangleMask(backgroundAlpha, x, y, w, h)
    love.graphics.stencil(function() myRectStencilFunction(x, y, w, h) end, "replace", 1)
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.setStencilTest("less", 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setStencilTest()
end
local function drawRectangleFade(backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('fill', 0, 0, w, h)
end


function doCircleInTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()

    transition = { type = 'circle', segments = 17, alpha = 0, x = x, y = y, radius = math.max(w, h) }

    Timer.tween(.3, transition, { alpha = 1 })
    Timer.tween(.7, transition, { radius = 0 }, 'out-back')
    Timer.after(1.01, function()
        --transition = nil;
        onAfter();
    end)
end

function renderTransition(transition)
    if transition.type == 'circle' then
        drawCircleMask(transition.alpha, transition.x, transition.y, transition.radius, transition.segments)
    end
    if transition.type == 'rectangle' then
        drawRectangleMask(transition.alpha, transition.x, transition.y, transition.w, transition.h)
    end
    if transition.type == 'screenfade' then
        drawRectangleFade(transition.alpha)
    end
end

function doCircleOutTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    transition = { type = 'circle', segments = 17, alpha = 1, x = x, y = y, radius = 0 }
    Timer.tween(1, transition, { alpha = 0 })
    Timer.tween(.5, transition, { radius = math.max(w, h), segments = 7 }, 'in-back')
    Timer.after(1.6, function()
        --transition = nil;
        onAfter();
    end)
end

function doRectOutTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    -- I amdrawing a much higher rectangle so it will cover the screen when rotated
    local h2 = math.max(w, h) * 3
    transition = { type = 'rectangle', alpha = 1, x = x, y = y, w = 0, h = h2 * 3 }
    Timer.tween(1, transition, { alpha = 0 })
    -- Timer.tween(3, transition, { w = x < w / 2 and w * 1.5 or -w * 1.5 }, 'out-back')
    Timer.after(1, function()
        onAfter();
        --transition = nil;
    end)
end

function doRectInTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    -- I amdrawing a much higher rectangle so it will cover the screen when rotated
    local h2 = math.max(w, h) * 3
    --transition = { type = 'rectangle', alpha = 0, x = x, y = y, w = x < w / 2 and w * 1.5 or -w * 1.5, h = h2 * 3 }
    transition = { type = 'rectangle', alpha = 0, x = x, y = y, w = h2, h = h2 }
    Timer.tween(.6, transition, { alpha = 1 })
    --Timer.tween(1.2, transition, { w = 0 }, 'out-back')
    Timer.after(1.2, function()
        onAfter();
        transition = nil;
    end)
end

function fadeOutTransition(onAfter)
    local w, h = love.graphics.getDimensions()
    transition = { type = 'screenfade', alpha = 0 }
    Timer.tween(.6, transition, { alpha = 1 })
    Timer.after(1.2, function()
        onAfter();
        transition = nil;
    end)
end
