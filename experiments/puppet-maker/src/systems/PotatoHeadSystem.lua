local numbers = require 'lib.numbers'


local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })

local function getMeta(parent)
    for i = 1, #parent.children do
        if (parent.children[i].type == 'meta' and #parent.children[i].points == 8) then
            return parent.children[i]
        end
    end
end

function getPoints(e)
    local parent = e.potato.head
    local parentName = e.potato.values.potatoHead and 'body' or 'head'
    local meta = getMeta(parent)

    if meta then
        local flipx = e.potato.values[parentName].flipx or 1
        local flipy = e.potato.values[parentName].flipy or 1
        local points = meta.points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        return newPoints
    end
    return {}
end

local function getPositionForNoseAttaching(e)
    local newPoints = getPoints(e)

    local tX = numbers.mapInto(e.potato.values.noseXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.potato.values.noseYAxis, -3, 3, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

function getPositionsForEyesAttaching(e)
    local newPoints = getPoints(e)

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

    local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)

    e.potato.eye1.transforms.l[1] = eyex1
    e.potato.eye1.transforms.l[2] = eyey1
    e.potato.eye2.transforms.l[4] = e.potato.eye1.transforms.l[4] * -1

    e.potato.eye2.transforms.l[1] = eyex2
    e.potato.eye2.transforms.l[2] = eyey2


    local newPoints = getPoints(e)
    local browY = numbers.lerp(eyey1, newPoints[1][2], 0.5)

    e.potato.brow1.transforms.l[1] = eyex1
    e.potato.brow1.transforms.l[2] = browY

    e.potato.brow2.transforms.l[1] = eyex2
    e.potato.brow2.transforms.l[2] = browY

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
