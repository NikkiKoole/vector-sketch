local numbers          = require 'lib.numbers'
local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })
local Timer            = require 'vendor.timer'
local cam              = require('lib.cameraBase').getInstance()
local mesh             = require 'lib.mesh'
local parentize        = require 'lib.parentize'

local function getPositionForNoseAttaching(e)
    local newPoints = getHeadPoints(e)

    local tX = numbers.mapInto(e.potato.values.noseXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.potato.values.noseYAxis, -2, 2, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

local function getPositionForMouthAttaching(e)
    --local headPart = e.mouth.values.potatoHead and editingGuy.body or editingGuy.head
    --local headPartName = e.mouth.values.potatoHead and 'body' or 'head'
    --local newPoints = getHeadPointsFromValues(e.mouth.values, headPart, headPartName)

    local newPoints = getHeadPoints(e)

    local tX = numbers.mapInto(e.potato.values.mouthXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.potato.values.mouthYAxis, -3, 3, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

function getPositionsForEyesAttaching(e)
    --print(inspect(e.potato))
    local newPoints = getHeadPoints(e)

    local mx = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
    local tX = numbers.mapInto(e.potato.values.eyeXAxisBetween, -3, 3, 0, 1)
    local x1 = numbers.lerp(newPoints[7][1], mx, tX)
    local x2 = numbers.lerp(newPoints[3][1], mx, tX)

    local tY = numbers.mapInto(e.potato.values.eyeYAxis, -3, 3, 0, 1)
    local y1 = numbers.lerp(newPoints[7][2], newPoints[8][2], tY)
    local y2 = numbers.lerp(newPoints[3][2], newPoints[2][2], tY)

    return x1, y1, x2, y2
end

function PotatoHeadSystem:update(dt)
    --print('potato headupdate')
    for _, e in ipairs(self.pool) do
        e.potato.blinkCounter = e.potato.blinkCounter - dt
        if e.potato.blinkCounter < 0 then
            PotatoHeadSystem:blinkEyes(e)
            e.potato.blinkCounter = 5.0 - love.math.random()
        end
    end
end

function PotatoHeadSystem:init(e)

end

function getFaceScale(e)
    local values = e.potato.values
    local sx, sy
    if (e.potato.values.potatoHead) then
        e.potato.head.transforms.l[4] = values.bodyWidthMultiplier
        e.potato.head.transforms.l[5] = values.bodyHeightMultiplier
        sx = values.faceScaleX / values.bodyWidthMultiplier
        sy = values.faceScaleY / values.bodyHeightMultiplier
    else
        e.potato.head.transforms.l[4] = values.headWidthMultiplier
        e.potato.head.transforms.l[5] = values.headHeightMultiplier
        sx = values.faceScaleX / values.headWidthMultiplier
        sy = values.faceScaleY / values.headHeightMultiplier
    end
    return sx, sy
end

function PotatoHeadSystem:rescaleFaceparts(e)
    local values = e.potato.values

    local sx, sy = getFaceScale(e)


    e.potato.eye1.transforms.l[4] = values.eyeWidthMultiplier * sx
    e.potato.eye1.transforms.l[5] = values.eyeHeightMultiplier * sy * e.potato.eyeBlink
    e.potato.pupil1.transforms.l[4] = values.pupilSizeMultiplier * sx
    e.potato.pupil1.transforms.l[5] = values.pupilSizeMultiplier * sy

    e.potato.eye2.transforms.l[4] = -1 * values.eyeWidthMultiplier * sx
    e.potato.eye2.transforms.l[5] = values.eyeHeightMultiplier * sy * e.potato.eyeBlink
    e.potato.pupil2.transforms.l[4] = values.pupilSizeMultiplier * sx
    e.potato.pupil2.transforms.l[5] = values.pupilSizeMultiplier * sy



    e.potato.nose.transforms.l[4] = values.noseWidthMultiplier * sx
    e.potato.nose.transforms.l[5] = values.noseHeightMultiplier * sy

    e.potato.ear1.transforms.l[4] = -1 * values.earWidthMultiplier * sx
    e.potato.ear1.transforms.l[5] = values.earWidthMultiplier * sy

    e.potato.ear2.transforms.l[4] = values.earWidthMultiplier * sx
    e.potato.ear2.transforms.l[5] = values.earWidthMultiplier * sy

    e.potato.mouth.transforms.l[4] = 1 * sx
    e.potato.mouth.transforms.l[5] = 1 * sy
end

function PotatoHeadSystem:potatoInit(e)
    --print('potatoint')
    local nosex, nosey = getPositionForNoseAttaching(e)
    if e.potato.nose then
        e.potato.nose.transforms.l[1] = nosex
        e.potato.nose.transforms.l[2] = nosey
    end



    local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)

    e.potato.eye1.transforms.l[1] = eyex1
    e.potato.eye1.transforms.l[2] = eyey1
    e.potato.eye2.transforms.l[4] = e.potato.eye1.transforms.l[4] * -1

    e.potato.eye2.transforms.l[1] = eyex2
    e.potato.eye2.transforms.l[2] = eyey2



    e.potato.pupil1.transforms.l[1] = eyex1
    e.potato.pupil1.transforms.l[2] = eyey1
    e.potato.pupil2.transforms.l[1] = eyex2
    e.potato.pupil2.transforms.l[2] = eyey2


    local newPoints = getHeadPoints(e)
    local browY = numbers.lerp(eyey1, newPoints[1][2], 0.5)

    e.potato.brow1.transforms.l[1] = eyex1
    e.potato.brow1.transforms.l[2] = browY

    e.potato.brow2.transforms.l[1] = eyex2
    e.potato.brow2.transforms.l[2] = browY

    local tY = numbers.mapInto(e.potato.values.earYAxis, -3, 3, 0, 1)
    e.potato.ear1.transforms.l[1] = numbers.lerp(newPoints[7][1], newPoints[8][1], .5)
    e.potato.ear1.transforms.l[2] = numbers.lerp(newPoints[2][2], newPoints[4][2], tY)

    local sx, sy = getFaceScale(e)
    e.potato.ear1.transforms.l[4] = -1 * sx * e.potato.values.earWidthMultiplier

    e.potato.ear2.transforms.l[1] = numbers.lerp(newPoints[3][1], newPoints[2][1], .5)
    e.potato.ear2.transforms.l[2] = numbers.lerp(newPoints[8][2], newPoints[6][2], tY)
    e.potato.ear2.transforms.l[4] = 1 * sx * e.potato.values.earWidthMultiplier

    local mx, my = getPositionForMouthAttaching(e)
    e.potato.mouth.transforms.l[1] = mx
    e.potato.mouth.transforms.l[2] = my
end

-- blink eyes
-- loos at position

local function getAngleAndDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local angle = math.atan2(dy, dx)
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return angle, distance
end
local function setAngleAndDistance(sx, sy, angle, distance, scaleX, scaleY)
    local newx = sx + (distance * scaleX) * math.cos(angle)
    local newy = sy + (distance * scaleY) * math.sin(angle)
    return newx, newy
end


function PotatoHeadSystem:eyeLookAtPoint(x, y)
    for _, e in ipairs(self.pool) do
        local wx, wy = cam:getWorldCoordinates(x, y)

        local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)
        ------
        -- print(inspect(e.potato.potato))
        e.potato.pupil1.transforms.l[1] = eyex1
        e.potato.pupil1.transforms.l[2] = eyey1


        local mx, my = e.potato.pupil1.transforms._g:transformPoint(0, 0)
        local angle, distance = getAngleAndDistance(wx, wy, mx, my)
        local t = e.potato.pupil1.transforms
        local sx, sy = 1 / e.potato.head.transforms.l[4], 1 / e.potato.head.transforms.l[5]
        sx = sx * e.potato.eye1.transforms.l[4]
        sy = sy * e.potato.eye1.transforms.l[5]

        local nx, ny = setAngleAndDistance(t.l[1], t.l[2], angle, 20, sx, sy)

        Timer.tween(.1, e.potato.pupil1.transforms.l, { [1] = nx,[2] = ny }, 'out-quad')
        Timer.after(1, function()
            local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)
            Timer.tween(.1, e.potato.pupil1.transforms.l, { [1] = eyex1,[2] = eyey1 }, 'out-quad')
        end)
        -------
        e.potato.pupil2.transforms.l[1] = eyex2
        e.potato.pupil2.transforms.l[2] = eyey2

        mx, my = e.potato.pupil2.transforms._g:transformPoint(0, 0)
        angle, distance = getAngleAndDistance(wx, wy, mx, my)
        t = e.potato.pupil2.transforms
        nx, ny = setAngleAndDistance(t.l[1], t.l[2], angle, 20, sx, sy)

        Timer.tween(.1, e.potato.pupil2.transforms.l, { [1] = nx,[2] = ny }, 'out-quad')
        Timer.after(1, function()
            local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)
            Timer.tween(.1, e.potato.pupil2.transforms.l, { [1] = eyex2,[2] = eyey2 }, 'out-quad')
        end)
        if e.potato.blinkCounter > 1 then
            e.potato.blinkCounter = e.potato.blinkCounter - 1
        end
    end
end

function PotatoHeadSystem:blinkEyes(e)
    if e.potato.eyeTimer then
        Timer.cancel(e.potato.eyeTimer)
    end
    e.potato.eyeTimer = Timer.tween(.1, e.potato, { eyeBlink = 0 }, 'out-quad')
    Timer.after(
        .1,
        function()
            e.potato.eyeTimer = Timer.tween(.15, e.potato, { eyeBlink = 1 }, 'out-quad')
        end
    )

    Timer.during(.6, function(dt)
        local values = e.potato.values
        local sx, sy = getFaceScale(e)

        e.potato.eye1.transforms.l[5] = values.eyeHeightMultiplier * sy * e.potato.eyeBlink
        e.potato.eye2.transforms.l[5] = values.eyeHeightMultiplier * sy * e.potato.eyeBlink
    end)
end

return PotatoHeadSystem
