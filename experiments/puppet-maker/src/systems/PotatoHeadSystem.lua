local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })

local numbers = require 'lib.numbers'

local function getPositionForNoseAttaching(e)
    local parent = e.potato.potatoHead and e.potato.body or e.potato.head
    print(parent)
    local parentName = e.potato.potatoHead and 'body' or 'head'
    if parent.children[2] and parent.children[2].type == 'meta' and #parent.children[2].points == 8 then
        local flipx = e.potato.values[parentName].flipx or 1
        local flipy = e.potato.values[parentName].flipy or 1
        local points = parent.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        local x = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
        local y = numbers.lerp(newPoints[7][2], newPoints[3][2], 0.5)
        print(x,y)
        --local nx, ny = parent.transforms._g:inverseTransformPoint(x, y)
        return x, y
    end
end

function PotatoHeadSystem:init(e)
    print('awdfwfewq')
end

function PotatoHeadSystem:potatoInit(e)
    local  nosex, nosey = getPositionForNoseAttaching(e)
    print(nosex, nosey)
    local pivx = e.potato.head.transforms.l[6]
    local pivy= e.potato.head.transforms.l[7]
    --print('potatoInit', e, e.potato.head) 
    --print(e.potato.head.transforms.l[6],e.potato.head.transforms.l[7])
    e.potato.nose.transforms.l[1] = nosex
    e.potato.nose.transforms.l[2] = nosey
    
end



return PotatoHeadSystem
