local numbers = require 'lib.numbers'
local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })


local function getPositionForNoseAttaching(e)
    local newPoints = getHeadPoints(e)

    local tX = numbers.mapInto(e.potato.values.noseXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.potato.values.noseYAxis, -3, 3, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

local function getPositionForMouthAttaching(e)
    local newPoints = getHeadPoints(e)

    local tX = numbers.mapInto(e.potato.values.mouthXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.potato.values.mouthYAxis, -3, 3, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

function getPositionsForEyesAttaching(e)
    local newPoints = getHeadPoints(e)

    local mx = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
    local x1 = numbers.lerp(newPoints[7][1], mx, 0.5)
    local x2 = numbers.lerp(newPoints[3][1], mx, 0.5)

    local tY = numbers.mapInto(e.potato.values.eyeYAxis, -3, 3, 0, 1)
    local y1 = numbers.lerp(newPoints[7][2], newPoints[8][2], tY)
    local y2 = numbers.lerp(newPoints[3][2], newPoints[2][2], tY)

    return x1, y1, x2, y2
end

function PotatoHeadSystem:init(e)
    print('awdfwfewq')
end

function PotatoHeadSystem:potatoInit(e)
    local nosex, nosey = getPositionForNoseAttaching(e)

    e.potato.nose.transforms.l[1] = nosex
    e.potato.nose.transforms.l[2] = nosey


    local mouthx, mouthy = getPositionForMouthAttaching(e)
    e.potato.upperlip.transforms.l[1] = mouthx
    e.potato.upperlip.transforms.l[2] = mouthy -- - love.math.random() * 50
    e.potato.lowerlip.transforms.l[1] = mouthx
    e.potato.lowerlip.transforms.l[2] = mouthy -- + love.math.random() * 50

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
    --e.potato.brow2.transforms.l[4] = -1 --browY
    --print(inspect(e.potato))
    --print(inspect(e.potato.ear1.transforms.l))

    local tY = numbers.mapInto(e.potato.values.earYAxis, -3, 3, 0, 1)
    e.potato.ear1.transforms.l[1] = numbers.lerp(newPoints[7][1], newPoints[8][1], .5)
    e.potato.ear1.transforms.l[2] = numbers.lerp(newPoints[2][2], newPoints[4][2], tY)
    e.potato.ear1.transforms.l[4] = -1

    e.potato.ear2.transforms.l[1] = numbers.lerp(newPoints[3][1], newPoints[2][1], .5)
    e.potato.ear2.transforms.l[2] = numbers.lerp(newPoints[8][2], newPoints[6][2], tY)
    e.potato.ear2.transforms.l[4] = 1
end

return PotatoHeadSystem
