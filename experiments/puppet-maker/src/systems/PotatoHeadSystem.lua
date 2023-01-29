local PotatoHeadSystem = Concord.system({ pool = { 'potato' } })

local numbers = require 'lib.numbers'

local function getPositionForNoseAttaching(e)
    local parent = e.biped.potatoHead and e.biped.body or e.biped.head
    print(parent)
    local parentName = e.biped.potatoHead and 'body' or 'head'
    if parent.children[2] and parent.children[2].type == 'meta' and #parent.children[2].points == 8 then
        local flipx = e.biped.values[parentName].flipx or 1
        local flipy = e.biped.values[parentName].flipy or 1
        local points = parent.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        local x = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
        local y = numbers.lerp(newPoints[7][2], newPoints[3][2], 0.5)
        local nx, ny = parent.transforms._g:transformPoint(x, y)
        return nx, ny
    end
end

function PotatoHeadSystem:init(e)
    print('awdfwfewq')
end

function PotatoHeadSystem:potatoInit(e)
    print('potatoInit', e)
end

return PotatoHeadSystem
