local numbers = require 'lib.numbers'


local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })


function getPoints(e)
    local parent = e.potato.head 
    local parentName = e.potato.values.potatoHead and 'body' or 'head'
    if parent.children[2] and parent.children[2].type == 'meta' and #parent.children[2].points == 8 then
        local flipx = e.potato.values[parentName].flipx or 1
        local flipy = e.potato.values[parentName].flipy or 1
        local points = parent.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        return newPoints
    end
    return {}
end  

local function getPositionForNoseAttaching(e)
    local newPoints = getPoints(e)
    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
    local y = numbers.lerp(newPoints[7][2], newPoints[3][2], 0.5)
      
    return x, y
   
end

function getPositionsForEyesAttaching(e)
    local newPoints = getPoints(e)
    local mx = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
    local x1 = numbers.lerp(newPoints[7][1], mx, 0.5)
    local x2 = numbers.lerp(newPoints[3][1], mx, 0.5)
    local y1 =  numbers.lerp(newPoints[7][2], newPoints[8][2], 0.5)
    local y2 =  numbers.lerp(newPoints[2][2], newPoints[3][2], 0.5)

    return x1,y1, x2,y2
end

function PotatoHeadSystem:init(e)
    print('awdfwfewq')
end

function PotatoHeadSystem:potatoInit(e)
    print('potatoinit')
    local  nosex, nosey = getPositionForNoseAttaching(e)
    
    e.potato.nose.transforms.l[1] = nosex
    e.potato.nose.transforms.l[2] = nosey

    local eyex1, eyey1, eyex2, eyey2 = getPositionsForEyesAttaching(e)

    e.potato.eye1.transforms.l[1] = eyex1
    e.potato.eye1.transforms.l[2] = eyey1
    e.potato.eye2.transforms.l[4] = -1

    e.potato.eye2.transforms.l[1] = eyex2
    e.potato.eye2.transforms.l[2] = eyey2
end



return PotatoHeadSystem
