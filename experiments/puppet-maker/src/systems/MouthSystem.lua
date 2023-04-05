local MouthSystem = Concord.system({ pool = { 'mouth', 'potato' } })

local numbers     = require 'lib.numbers'
local Timer       = require 'vendor.timer'
local mesh        = require 'lib.mesh'
local parentize   = require 'lib.parentize'

function MouthSystem:update(dt)

end

local function getPositionForMouthAttaching(e)
    local headPart = e.mouth.values.potatoHead and editingGuy.body or editingGuy.head
    local headPartName = e.mouth.values.potatoHead and 'body' or 'head'
    local newPoints = getHeadPointsFromValues(e.mouth.values, headPart, headPartName)

    --local newPoints = getHeadPoints(e)

    local tX = numbers.mapInto(e.mouth.values.mouthXAxis, -2, 2, 0, 1)
    local tY = numbers.mapInto(e.mouth.values.mouthYAxis, -3, 3, 0, 1)

    local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
    local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)

    return x, y
end

function MouthSystem:mouthInit(e)
    print(inspect(e.potato))
    local mouthx, mouthy = getPositionForMouthAttaching(e)
    e.mouth.upperlip.transforms.l[1] = mouthx
    e.mouth.upperlip.transforms.l[2] = mouthy -- - love.math.random() * 50
    e.mouth.lowerlip.transforms.l[1] = mouthx
    e.mouth.lowerlip.transforms.l[2] = mouthy -- + love.math.random() * 50

    e.mouth.teeth.transforms.l[1] = e.mouth.upperlip.transforms.l[1]
    e.mouth.teeth.transforms.l[2] = e.mouth.upperlip.transforms.l[2] - 50
end

function MouthSystem:mouthSaySomething(e)
    print('jo biggity!')
    local maxOpen = .25 + love.math.random() * 0.5
    local minWide = .5 + love.math.random() * 0.5

    local value = { mouthOpen = 0, mouthWide = 1 }
    local wideness = 0.5 + love.math.random()
    Timer.tween(.3, value, { mouthOpen = maxOpen, mouthWide = minWide }, 'out-quad')
    Timer.after(.4, function()
        Timer.tween(.2, value, { mouthOpen = 0, mouthWide = 1 }, 'out-quad')
    end)

    Timer.during(1.1, function(dt)
        MouthSystem:mouthOpener(e, value.mouthOpen, value.mouthWide)
    end)
end

function MouthSystem:mouthOpener(e, openNess, wideness)
    if true then
        --editingGuy.mouthOpenNess = openNess
        local url = e.mouth.upperlip.children[1].texture.url
        local w, h = mesh.getImage(url):getDimensions()
        --local wideness = 0.5 --0.5 + love.math.random() * 0.5

        local open = openNess --love.math.random() * 1
        local p1 = { { (h / 2) * wideness, 0 }, { 0, -w * open }, { ( -h / 2) * wideness, 0 } }

        url = e.mouth.lowerlip.children[1].texture.url
        w, h = mesh.getImage(url):getDimensions()
        p2 = { p1[1], { 0, w * open }, p1[3] }

        -- would be much nicer/lighter if it could just work with this
        --editingGuy.upperlip.children[1].data.points = p1
        -- editingGuy.lowerlip.children[1].data.points = p2
        -- mesh.meshAll(editingGuy.upperlip.children[1])
        e.mouth.teeth.transforms.l[2] = e.mouth.upperlip.transforms.l[2] - 50 - (openNess * 100)
        editingGuy.upperlip = updateChild(e.mouth.head, editingGuy.upperlip,
                createUpperlipBezier(e.mouth.values, p1))
        editingGuy.lowerlip = updateChild(e.mouth.head, editingGuy.lowerlip,
                createLowerlipBezier(e.mouth.values, p2))


        parentize.parentize(editingGuy.guy)
        mesh.meshAll(editingGuy.guy)
        mouth:give('mouth', mouthArguments(editingGuy))
    end
end

return MouthSystem
