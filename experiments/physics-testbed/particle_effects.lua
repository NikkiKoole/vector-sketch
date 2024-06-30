local animParticles = require 'frameAnimParticle'
local numbers       = require 'lib.numbers'
local Timer         = require 'vendor.timer'
local dj            = require 'organicMusic'


local function getLoopingDegrees()
    return math.floor(((bikeFrameAngleAtJump - bike.frame.body:getAngle()) / (math.pi * 2)) * 360)
end
local function roundToQuarters(value)
    local result = math.floor(value * 4 + 0.5) / 4
    return result
end

local function startNumberParticle(num, x1, y1, x2, y2, color1, color2)
    local posData = { { x = x1, y = y1 }, { x = x2, y = y2 }, 2 }
    local color = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)
    local colorData = { { color, color, color }, { color, color, color - 0.3 }, 2 }
    local alphaData = { 1, 0.2, 2 }
    local scaleData = { 0.8, 1.2, 2 }
    local rotationData = { 0, 0, 2 }
    local frameData = {
        startFrame = num * 2,   -- frame where we will start playing
        loopBack = num * 2,     -- frame where we will start looping again (after reaching end)
        endFrame = num * 2 + 2, -- frame where we end playing (-1 for defaul behaviour == end)
    }

    animParticles.startAnimParticle('numbers', 10, frameData, posData, colorData, alphaData, scaleData, rotationData)
end

local function getDigits(number)
    local digits = {}

    while number > 0 do
        local digit = number % 10
        table.insert(digits, 1, digit) -- Insert digit at the beginning of the array
        number = math.floor(number / 10)
    end

    return digits
end

local function drawNumbersNicely(num, x, y, x2, y2)
    local rounded = roundToQuarters(math.abs(num))
    local integer = math.floor(rounded)
    local fraction = rounded % 1

    --  print(num, rounded, print(inspect(getDigits(math.abs(integer)))))
    local digits = getDigits(math.abs(integer))
    if (integer ~= 0) then
        for i = 1, #digits do
            startNumberParticle(digits[i], x + 0 + (50 * i), y, x2 + 50 + (50 * i), y2)
        end
    end
    if (fraction ~= 0) then
        startNumberParticle(9 + (fraction * 4), x + (50 * (#digits + 1)), y, x2 + (50 * (#digits + 2)), y2)
    end
end


function displayWheelieData()
    if (frontWheelFromGround > .4) then
        brrVolume = 0.1
        Timer.after(3, function() brrVolume = 0 end)
    end
    if frontWheelFromGround > 1 then
        --contact:getPosition()

        if (frontWheelFromGround > 1.4) then
            local w, h = love.graphics.getDimensions()
            local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
            local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
            local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 3)
            local posData = { { x = x1 - 50, y = y1 }, { x = x1 - 50, y = y2 }, 2 }
            local textColor = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)
            local colorData = { { textColor, textColor, textColor }, { textColor, textColor, textColor - 0.3 }, 1.5 }


            local alphaData = { 1, 0.2, 2.5 }
            local scaleData = { 0.3, 1.3, 2 }
            local rotationData = { 0, 0, 1 }
            local frameData = {
                startFrame = 0, -- frame where we will start playing
                loopBack = 6,   -- frame where we will start looping again (after reaching end)
                endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
            }

            animParticles.startAnimParticle('wheelie', 12, frameData, posData, colorData, alphaData, scaleData,
                rotationData)

            drawNumbersNicely(frontWheelFromGround, x1, y1, x1, y2)
        end
    end
end

function displayLoopingData()
    if (bikeFrameAngleAtJump ~= 0) then
        local l = getLoopingDegrees()
        local loops = ((l / 360))

        if math.abs(loops) >= 0.5 then
            local w, h = love.graphics.getDimensions()
            local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
            local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
            local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 3)
            local posData = { { x = x1 - 50, y = y1 }, { x = x1 - 50, y = y2 }, 2 }

            local textColor = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)
            local colorData = { { textColor, textColor, textColor }, { textColor, textColor, textColor - 0.3 }, 2 }
            local alphaData = { 1, 0.2, 2 }
            local scaleData = { 0.8, 1.3, 2 }
            local rotationData = { 0, 0, 2 }
            local frameData = {
                startFrame = 0, -- frame where we will start playing
                loopBack = 6,   -- frame where we will start looping again (after reaching end)
                endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
            }
            brrVolume = 0.1
            if love.math.random() < 0.5 then
                dj.queueClip(4, 2)
            else
                dj.queueClip(4, 8)
            end

            Timer.after(3, function() brrVolume = 0 end)
            animParticles.startAnimParticle('looping', 12, frameData, posData, colorData, alphaData,
                scaleData, rotationData)
            love.graphics.setColor(textColor, textColor, textColor)
            drawNumbersNicely(loops, x1, y1, x1, y2)
            --  addScoreMessage('looped: ' .. string.format("%02.1f", roundToQuarters(loops)))
        end
    end
end
