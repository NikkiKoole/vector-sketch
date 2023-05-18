local BipedSystem = Concord.system({ pool = { 'biped' } })
local node = require 'lib.node'
local mesh = require 'lib.mesh'
local transforms = require 'lib.transform'
local parentize = require 'lib.parentize'
local numbers = require 'lib.numbers'
local Timer = require 'vendor.timer'


--local pinnedFeet = true
--local pinnedHands = true

local function getMeta(parent)
    for i = 1, #parent.children do
        if (parent.children[i].type == 'meta' and #parent.children[i].points == 8) then
            return parent.children[i]
        end
    end
end

local function getHeadDeltaAttachement(e)
    local head = e.biped.head
    local meta = getMeta(head)
    if meta then
        local flipx = e.biped.values.head.flipx or 1
        local flipy = e.biped.values.head.flipy or 1
        local points = meta.points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)

        local hdx = newPoints[5][1] - e.biped.head.transforms.l[6]
        local hdy = newPoints[5][2] - e.biped.head.transforms.l[7]
        return hdx, hdy
    end
    return 0, 0
end

local function getPositionsForNeckAttaching(e)
    local body = e.biped.body
    local meta = getMeta(body)
    if meta then
        local flipx = e.biped.values.body.flipx or 1
        local flipy = e.biped.values.body.flipy or 1
        local points = meta.points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)


        local x, y = body.transforms._g:transformPoint(newPoints[1][1], newPoints[1][2])
        x, y = e.biped.guy.transforms._g:inverseTransformPoint(x, y)
        return x, y
    else
        local neck = node.findNodeByName(body, 'neck')
        if neck then
            local x, y = body.transforms._g:transformPoint(neck.points[1][1], neck.points[1][2])
            return x, y
        end
    end
end

local function getPositionsForArmsAttaching(e)
    local body = e.biped.body
    local meta = getMeta(body)
    if meta then
        local flipx = e.biped.values.body.flipx or 1
        local flipy = e.biped.values.body.flipy or 1
        local points = meta.points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)

        if e.biped.values.potatoHead then
            local a1x, a1y = body.transforms._g:transformPoint(newPoints[7][1], newPoints[7][2])
            local a2x, a2y = body.transforms._g:transformPoint(newPoints[3][1], newPoints[3][2])
            a1x, a1y = e.biped.guy.transforms._g:inverseTransformPoint(a1x, a1y)
            a2x, a2y = e.biped.guy.transforms._g:inverseTransformPoint(a2x, a2y)
            return a1x, a1y, a2x, a2y
        else
            local a1x, a1y = body.transforms._g:transformPoint(newPoints[8][1], newPoints[8][2])
            local a2x, a2y = body.transforms._g:transformPoint(newPoints[2][1], newPoints[2][2])
            a1x, a1y = e.biped.guy.transforms._g:inverseTransformPoint(a1x, a1y)
            a2x, a2y = e.biped.guy.transforms._g:inverseTransformPoint(a2x, a2y)
            return a1x, a1y, a2x, a2y
        end
    else
        local lc1 = node.findNodeByName(body, 'arm1')
        local lc2 = node.findNodeByName(body, 'arm2')
        if lc1 and lc2 then
            local a1x, a1y = body.transforms._g:transformPoint(lc1.points[1][1], lc1.points[1][2])
            local a2x, a2y = body.transforms._g:transformPoint(lc2.points[1][1], lc2.points[1][2])
            --return lc1.points[1], lc2.points[1]
            return a1x, a1y, a2x, a2y
        end
    end
end

local function getPositionsForLegsAttaching(e)
    local body = e.biped.body
    local meta = getMeta(body)
    if meta then
        local flipx     = e.biped.values.body.flipx or 1
        local flipy     = e.biped.values.body.flipy or 1
        local points    = meta.points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        local t         = e.biped.values.legXAxis
        local mx        = numbers.lerp(newPoints[6][1], newPoints[5][1], t)
        local l1x, l1y  = body.transforms._g:transformPoint(mx, newPoints[6][2])
        local mx2       = numbers.lerp(newPoints[4][1], newPoints[5][1], t)
        local l2x, l2y  = body.transforms._g:transformPoint(mx2, newPoints[4][2])
        -- this -50 on the y axis is to make the legs always more or less touch the body
        -- usually the lines have some margin in the drawings.

        l1x, l1y        = e.biped.guy.transforms._g:inverseTransformPoint(l1x, l1y)
        l2x, l2y        = e.biped.guy.transforms._g:inverseTransformPoint(l2x, l2y)

        return l1x, l1y - 25, l2x, l2y - 25
    else
        local lc1 = node.findNodeByName(body, 'leg1')
        local lc2 = node.findNodeByName(body, 'leg2')
        if lc1 and lc2 then
            local l1x, l1y = body.transforms._g:transformPoint(lc1.points[1])
            local l2x, l2y = body.transforms._g:transformPoint(lc2.points[1])
            return l1x, l1y, l2x, l2y
        end
    end
end

function BipedSystem:init(e)
    -- print('auto caled init', e)
end

function getDefaultHandPositions(e)
    local a1x, a1y, a2x, a2y = getPositionsForArmsAttaching(e)
    local rot = e.biped.body.transforms.l[3]
    local armlength = getMaxArmLength(e) * 0.7
    local x2, y2 = setAngleAndDistance(a1x, a1y, rot + (math.pi / 8) * 5, armlength)
    local x3, y3 = setAngleAndDistance(a2x, a2y, rot + (math.pi / 8) * 3, armlength)
    return x2, y2, x3, y3
end

function getDataBefore(e)
    -- from a list of bodyparts, I want to get the sx, sy and alphas
    local list = { 'body', 'head', 'neck', 'leg1', 'leghair1', 'leg2', 'leghair2', 'arm1', 'armhair1', 'armhair2',
        'arm2', 'feet1', 'feet2', 'hand1', 'hand2', }
    local values = {}

    for k, v in pairs(list) do
        -- for i = 1, #list do
        local data = {}

        if (e.biped[v].transforms) then
            data.px = e.biped[v].transforms.l[1]
            data.py = e.biped[v].transforms.l[2]
            data.r = e.biped[v].transforms.l[3]
            data.sx = e.biped[v].transforms.l[4]
            data.sy = e.biped[v].transforms.l[5]
        end
        if e.biped[v].color then
            data.a = e.biped[v].color[4] or 1
        end
        values[v] = data
    end
    return values
end

function setAllToZero(e, values)
    local list = { 'body', 'head', 'neck', 'leg1', 'leghair1', 'leg2', 'leghair2', 'arm1', 'armhair1', 'armhair2',
        'arm2', 'feet1', 'feet2', 'hand1', 'hand2', }
    for k, v in pairs(values) do
        if v.sx then
            e.biped[k].transforms.l[4] = 0
            e.biped[k].transforms.l[5] = 0
        end
        if (v.a) then
            e.biped[k].color[4] = 0
        end
    end
end

function applyDataAgain(e, values)
    local list = { 'body', 'head', 'neck', 'leg1', 'leghair1', 'leg2', 'leghair2', 'arm1', 'armhair1', 'armhair2',
        'arm2', 'feet1', 'feet2', 'hand1', 'hand2', }
    --for i = 1, #list do
    for k, v in pairs(values) do
        if v.sx then
            e.biped[k].transforms.l[1] = v.px
            e.biped[k].transforms.l[2] = v.py
            e.biped[k].transforms.l[3] = v.r

            e.biped[k].transforms.l[4] = v.sx
            e.biped[k].transforms.l[5] = v.sy
        end
        if (v.a) then
            e.biped[k].color[4] = v.a
        end
    end
end

local birthData = {}

function BipedSystem:finishBirth(e)
    applyDataAgain(e, birthData)
end

function BipedSystem:birthGuy(e)
    birthData = getDataBefore(e)
    setAllToZero(e, birthData)


    Timer.tween(2, e.biped.body.transforms.l, { [4] = birthData.body.sx,[5] = birthData.body.sy }, 'out-elastic')

    for i = 1, 10 do
        Timer.after((i * 0.05 * love.math.random()), function()
            Timer.tween(0.1, e.biped.body.transforms.l, { [3] = love.math.random() - 0.5 })
        end)
    end
    Timer.after(0.6, function()
        Timer.tween(0.1, e.biped.body.transforms.l, { [3] = 0 })
    end)

    Timer.after(0.7, function()
        Timer.tween(1.5, e.biped.head.transforms.l, { [4] = birthData.head.sx,[5] = birthData.head.sy }, 'out-elastic',
            nil, .5, .3)
    end)
    Timer.after(1, function()
        Timer.tween(.5, e.biped.neck.color, { [4] = birthData.neck.a }, 'out-elastic',
            nil, .5, .3)
    end)
    Timer.after(0.9, function()
        Timer.tween(1.5, e.biped.arm1.color, { [4] = 1 }, 'out-elastic', nil, .5, .3)
        Timer.tween(1.5, e.biped.arm2.color, { [4] = 1 }, 'out-elastic', nil, .8, .3)
        if e.biped.armhair1 and e.biped.armhair1.color then
            Timer.tween(1.8, e.biped.armhair1.color, { [4] = 1 }, 'out-elastic', nil, .5, .3)
            Timer.tween(1.8, e.biped.armhair2.color, { [4] = 1 }, 'out-elastic', nil, .8, .3)
        end
    end)
    Timer.after(1.2, function()
        Timer.tween(.5, e.biped.hand1.transforms.l, { [4] = birthData.hand1.sx,[5] = birthData.hand1.sy }, 'out-elastic',
            nil, .5, .3)
        Timer.tween(.5, e.biped.hand2.transforms.l, { [4] = birthData.hand2.sx,[5] = birthData.hand2.sy }, 'out-elastic',
            nil, .8, .3)
    end)

    Timer.after(0.9, function()
        Timer.tween(1.5, e.biped.leg1.color, { [4] = 1 }, 'out-elastic', nil, .5, .3)
        Timer.tween(1.5, e.biped.leg2.color, { [4] = 1 }, 'out-elastic', nil, .8, .3)
        if e.biped.leghair1 and e.biped.leghair1.color then
            Timer.tween(1.8, e.biped.leghair1.color, { [4] = 1 }, 'out-elastic', nil, .5, .3)
            Timer.tween(1.8, e.biped.leghair2.color, { [4] = 1 }, 'out-elastic', nil, .8, .3)
        end
    end)

    Timer.after(1.3, function()
        Timer.tween(.5, e.biped.feet1.transforms.l, { [4] = birthData.feet1.sx,[5] = birthData.feet1.sy }, 'out-elastic',
            nil, .5, .3)
        Timer.tween(.5, e.biped.feet2.transforms.l, { [4] = birthData.feet2.sx,[5] = birthData.feet2.sy }, 'out-elastic',
            nil, .8, .3)
    end)

    Timer.after(2, function()
        e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + 200
        BipedSystem:tweenIntoDefaultStance(e, false)
    end)
    Timer.after(2.5, function()
        e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + 200
        BipedSystem:tweenIntoDefaultStance(e, false)
    end)

    Timer.during(4, function()
        mesh.remeshNode(e.biped.leg1)
        mesh.remeshNode(e.biped.leghair1)
        mesh.remeshNode(e.biped.body)
        mesh.remeshNode(e.biped.arm1)
        mesh.remeshNode(e.biped.arm2)

        BipedSystem:bipedAttachFeet(e)
        BipedSystem:bipedAttachHands(e)
        attachHeadWithOrWithoutNeck(e, false)
    end)

    Timer.after(3, function()
        BipedSystem:finishBirth(e)
    end)
end

function BipedSystem:bipedInit(e)
    e.biped.body.transforms.l[3] = 0
    transforms.setTransforms(e.biped.body)
    local l1x, l1y, l2x, l2y = getPositionsForLegsAttaching(e)



    e.biped.leg1.points[1] = { l1x, l1y }
    e.biped.leg1.points[2] = { l1x, l1y + (e.biped.leg1.data.length / 4.46) / 1 }

    e.biped.leghair1.points[1] = e.biped.leg1.points[1]
    e.biped.leghair1.points[2] = e.biped.leg1.points[2]


    e.biped.leg2.points[1] = { l2x, l2y }
    e.biped.leg2.points[2] = { l2x, l2y + (e.biped.leg2.data.length / 4.46) / 1 }

    e.biped.leghair2.points[1] = e.biped.leg2.points[1]
    e.biped.leghair2.points[2] = e.biped.leg2.points[2]

    e.biped.feet2.transforms.l[4] = -1 * e.biped.values.feetLengthMultiplier
    BipedSystem:bipedAttachFeet(e)
    mesh.remeshNode(e.biped.leg1)
    mesh.remeshNode(e.biped.leg2)
    mesh.remeshNode(e.biped.leghair1)
    mesh.remeshNode(e.biped.leghair2)






    local a1x, a1y, a2x, a2y = getPositionsForArmsAttaching(e)
    local h1x, h1y, h2x, h2y = getDefaultHandPositions(e)

    e.biped.arm1.points[1] = { a1x, a1y }

    --local armlength = getMaxArmLength(e)*0.7
    --local x2,y2 = setAngleAndDistance(a1x, a1y, (math.pi/8)*5, armlength)
    --e.biped.arm1.points[2] = { a1x - (e.biped.arm1.data.length / 4.46) / 1, a1y }
    e.biped.arm1.points[2] = { h1x, h1y }

    e.biped.armhair1.points[1] = e.biped.arm1.points[1]
    e.biped.armhair1.points[2] = e.biped.arm1.points[2]
    -- e.biped.armhair1.transforms.l[5] = -1

    e.biped.arm2.points[1] = { a2x, a2y }
    --local x3, y3 = setAngleAndDistance(a2x, a2y, (math.pi / 8) * 3, armlength)
    --e.biped.arm2.points[2] = { a2x + (e.biped.arm2.data.length / 4.46) / 1, a2y }
    --e.biped.arm2.points[2] = { x3, y3 }

    e.biped.armhair2.points[1] = e.biped.arm2.points[1]
    e.biped.armhair2.points[2] = e.biped.arm2.points[2]
    e.biped.arm2.points[2] = { h2x, h2y }

    e.biped.hand2.transforms.l[4] = -1
    BipedSystem:bipedAttachHands(e)
    mesh.remeshNode(e.biped.arm1)
    mesh.remeshNode(e.biped.arm2)

    mesh.remeshNode(e.biped.armhair1)
    mesh.remeshNode(e.biped.armhair2)
    attachHeadWithOrWithoutNeck(e, false)

    BipedSystem:keepFeetPlantedAndStraightenLegs(e)
    --local nx, ny = getPositionForNoseAttaching(e)
    --e.biped.nose.transforms.l[1] =  0 --400 + nx
    --e.biped.nose.transforms.l[2] = 0--ny
    --print(nx, ny)
    --mesh.remeshNode(e.biped.nose)
end

function BipedSystem:update(dt)

end

function BipedSystem:bipedUsePotatoHead(e, value)
    editingGuy.guy.children = guyChildren(editingGuy)
    parentize.parentize(root)
    mesh.meshAll(root)
    BipedSystem:bipedAttachArms(e)
    BipedSystem:bipedAttachHands(e)
end

function BipedSystem:bipedDirection(e, dir)
    --[[
    if dir == 'left' then

        e.biped.guy.children = { e.biped.leg1, e.biped.feet1, e.biped.body, e.biped.leg2, e.biped.feet2, e.biped.neck,
            e.biped.head }
        e.biped.leg1.data.flop = -1
        e.biped.leg2.data.flop = -1
        e.biped.feet1.transforms.l[4] = 1
        e.biped.feet2.transforms.l[4] = 1
    elseif dir == 'right' then

        e.biped.guy.children = { e.biped.leg2, e.biped.feet2, e.biped.body, e.biped.leg1, e.biped.feet1, e.biped.neck,
            e.biped.head }
        e.biped.leg1.data.flop = 1
        e.biped.leg2.data.flop = 1

        e.biped.feet1.transforms.l[4] = -1
        e.biped.feet2.transforms.l[4] = -1
    elseif dir == 'down' then

        e.biped.guy.children = { e.biped.body, e.biped.leg1, e.biped.leg2, e.biped.feet1, e.biped.feet2, e.biped.neck,
            e.biped.head }
        e.biped.leg1.data.flop = -1
        e.biped.leg2.data.flop = 1

        e.biped.feet1.transforms.l[4] = 1
        e.biped.feet2.transforms.l[4] = -1
    end
    e.biped.feet1.dirty = true
    e.biped.feet2.dirty = true

    --- pff really
    local derivative = e.biped.leg1._curve:getDerivative()
    local dx, dy = derivative:evaluate(1)
    local angle = math.atan2(dy, dx) - math.pi / 2
    e.biped.feet1.transforms.l[3] = angle

    local derivative = e.biped.leg2._curve:getDerivative()
    local dx, dy = derivative:evaluate(1)
    local angle = math.atan2(dy, dx) - math.pi / 2
    e.biped.feet2.transforms.l[3] = angle

    mesh.remeshNode(e.biped.leg1)
    mesh.remeshNode(e.biped.leg2)

    transforms.setTransforms(e.biped.feet2)
    transforms.setTransforms(e.biped.feet1)
    --]]
end

function setLegs(e)
    local keep = not e.biped.values.feetPinned --  pinnedFeet
    --print('setting legs')
    local body = e.biped.body
    --local lc1, lc2 = getPositionsForLegsAttaching(e)
    local l1x, l1y, l2x, l2y = getPositionsForLegsAttaching(e)

    l1x = l1x or 0
    l1y = l1y or 0
    l2x = l2x or 0
    l2y = l2y or 0


    local angle, dist = getAngleAndDistance(e.biped.leg1.points[2][1], e.biped.leg1.points[2][2],
            e.biped.leg1.points[1][1], e.biped.leg1.points[1][2])


    e.biped.leg1.points[1] = { l1x, l1y }
    if keep then
        local newx, newy = setAngleAndDistance(l1x, l1y, angle, dist)
        e.biped.leg1.points[2] = { newx, newy }
    end
    mesh.remeshNode(e.biped.leg1)

    e.biped.leghair1.points[1] = e.biped.leg1.points[1]
    e.biped.leghair1.points[2] = e.biped.leg1.points[2]
    mesh.remeshNode(e.biped.leghair1)




    local angle, dist = getAngleAndDistance(e.biped.leg2.points[2][1], e.biped.leg2.points[2][2],
            e.biped.leg2.points[1][1], e.biped.leg2.points[1][2])

    --local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
    e.biped.leg2.points[1] = { l2x, l2y }
    if keep then
        local newx, newy = setAngleAndDistance(l2x, l2y, angle, dist)
        e.biped.leg2.points[2] = { newx, newy }
    end
    mesh.remeshNode(e.biped.leg2)

    e.biped.leghair2.points[1] = e.biped.leg2.points[1]
    e.biped.leghair2.points[2] = e.biped.leg2.points[2]
    mesh.remeshNode(e.biped.leghair2)

    --end
end

function BipedSystem:bipedAttachLegs(e)
    setLegs(e)
end

function setArms(e, optionalData)
    local keep = not e.biped.values.handsPinned --not pinnedHands


    local a1x, a1y, a2x, a2y = getPositionsForArmsAttaching(e)
    a1x = a1x or 0
    a1y = a1y or 0
    a2x = a2x or 0
    a2y = a2y or 0
    local body = e.biped.body
    local angle, dist = getAngleAndDistance(e.biped.arm1.points[2][1], e.biped.arm1.points[2][2],
            e.biped.arm1.points[1][1], e.biped.arm1.points[1][2])


    e.biped.arm1.points[1] = { a1x, a1y }
    if keep then
        local newx, newy = setAngleAndDistance(a1x, a1y, angle, dist)
        e.biped.arm1.points[2] = { newx, newy }
    end

    mesh.remeshNode(e.biped.arm1)


    e.biped.armhair1.points[1] = e.biped.arm1.points[1]
    e.biped.armhair1.points[2] = e.biped.arm1.points[2]
    mesh.remeshNode(e.biped.armhair1)



    local angle, dist = getAngleAndDistance(e.biped.arm2.points[2][1], e.biped.arm2.points[2][2],
            e.biped.arm2.points[1][1], e.biped.arm2.points[1][2])

    e.biped.arm2.points[1] = { a2x, a2y }
    if keep then
        -- instead of angle use  e.biped.body.transforms.l[3]
        local newx, newy = setAngleAndDistance(a2x, a2y, angle, dist)
        e.biped.arm2.points[2] = { newx, newy }
    end
    mesh.remeshNode(e.biped.arm2)

    --if e.biped.armhair2.points then
    e.biped.armhair2.points[1] = e.biped.arm2.points[1]
    e.biped.armhair2.points[2] = e.biped.arm2.points[2]
    mesh.remeshNode(e.biped.armhair2)
    --end

    --end
end

function BipedSystem:bipedAttachArms(e)
    setArms(e)
end

function BipedSystem:itemRotate(elem, dx, dy, scale)
    for _, e in ipairs(self.pool) do
        if e.biped.body == elem.item then
            e.biped.body.transforms.l[3] = e.biped.body.transforms.l[3] + 0.1
            BipedSystem:movedBody(e)

            --transforms.setTransforms(e.biped.body)
            --setLegs(e)
            --setArms(e)
            --BipedSystem:bipedAttachHead(e)
            --BipedSystem:bipedAttachHands(e)
        end
        if e.biped.hand1 == elem.item then
            e.biped.hand1.transforms.l[3] = e.biped.hand1.transforms.l[3] + 0.1
            e.biped.hand1.dirty = true
            transforms.setTransforms(e.biped.hand1)
        end
        if e.biped.hand2 == elem.item then
            e.biped.hand2.transforms.l[3] = e.biped.hand2.transforms.l[3] + 0.1
            e.biped.hand2.dirty = true
            transforms.setTransforms(e.biped.hand2)
        end
        if e.biped.feet1 == elem.item then
            e.biped.feet1.transforms.l[3] = e.biped.feet1.transforms.l[3] + 0.1
            e.biped.feet1.dirty = true
            transforms.setTransforms(e.biped.feet1)
        end
        if e.biped.feet2 == elem.item then
            e.biped.feet2.transforms.l[3] = e.biped.feet2.transforms.l[3] + 0.1
            e.biped.feet2.dirty = true
            transforms.setTransforms(e.biped.feet2)
        end
    end
end

function BipedSystem:bipedAttachFeet(e)
    e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
    e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]

    e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
    e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]
end

function BipedSystem:bipedAttachHands(e)
    e.biped.hand1.transforms.l[1] = e.biped.arm1.points[2][1]
    e.biped.hand1.transforms.l[2] = e.biped.arm1.points[2][2]

    e.biped.hand2.transforms.l[1] = e.biped.arm2.points[2][1]
    e.biped.hand2.transforms.l[2] = e.biped.arm2.points[2][2]
end

function BipedSystem:bipedAttachHead(e)
    attachHeadWithOrWithoutNeck(e, true)
end

function BipedSystem:bipedAttachHeadKeepAngleChangeDistance(e)
    local neckX, neckY = getPositionsForNeckAttaching(e)
    neckX = neckX or 0
    neckY = neckY or 0
    local angle, dist = getAngleAndDistance(e.biped.neck.points[2][1], e.biped.neck.points[2][2],
            e.biped.neck.points[1][1], e.biped.neck.points[1][2])
    local newx, newy = setAngleAndDistance(neckX, neckY, angle, necklengths[e.biped.values.neckLength])
    e.biped.neck.points[1] = { neckX, neckY }

    e.biped.neck.points[2] = { newx, newy }

    mesh.remeshNode(e.biped.neck)

    local hx, hy = getHeadDeltaAttachement(e)

    e.biped.head.transforms.l[1] = e.biped.neck.points[2][1] - hx
    e.biped.head.transforms.l[2] = e.biped.neck.points[2][2] - hy
    e.biped.head.dirty = true
    e.biped.neck.dirty = true
    transforms.setTransforms(e.biped.neck)
end

function attachHeadWithOrWithoutNeck(e, keepAngleAndDistance)
    local neckX, neckY = getPositionsForNeckAttaching(e)
    neckX = neckX or 0
    neckY = neckY or 0
    if (e.biped.neck) then
        if keepAngleAndDistance then
            local angle, dist = getAngleAndDistance(e.biped.neck.points[2][1], e.biped.neck.points[2][2],
                    e.biped.neck.points[1][1], e.biped.neck.points[1][2])

            local newx, newy = setAngleAndDistance(neckX, neckY, angle, dist)
            e.biped.neck.points[1] = { neckX, neckY }

            e.biped.neck.points[2] = { newx, newy }
        else
            --    print(inspect(e.biped.neck.data))
            e.biped.neck.points[1] = { neckX, neckY }
            e.biped.neck.points[2] = { neckX,
                neckY - ((e.biped.neck.data.length * e.biped.neck.data.scaleY) / 4.46) / 1 }
        end


        mesh.remeshNode(e.biped.neck)

        local hx, hy = getHeadDeltaAttachement(e)

        e.biped.head.transforms.l[1] = e.biped.neck.points[2][1] - hx
        e.biped.head.transforms.l[2] = e.biped.neck.points[2][2] - hy
        e.biped.head.dirty = true
        e.biped.neck.dirty = true
        transforms.setTransforms(e.biped.neck)
    else
        local hx, hy = getHeadDeltaAttachement(e)
        e.biped.head.transforms.l[1] = neckX - hx
        e.biped.head.transforms.l[2] = neckY - hy
    end
end

function BipedSystem:setArmHairToArms(e)
    e.biped.armhair1.points[1] = e.biped.arm1.points[1]
    e.biped.armhair1.points[2] = e.biped.arm1.points[2]
    mesh.remeshNode(e.biped.armhair1)
    e.biped.armhair2.points[1] = e.biped.arm2.points[1]
    e.biped.armhair2.points[2] = e.biped.arm2.points[2]
    mesh.remeshNode(e.biped.armhair2)
end

function BipedSystem:setLegHairToLegs(e)
    e.biped.leghair1.points[1] = e.biped.leg1.points[1]
    e.biped.leghair1.points[2] = e.biped.leg1.points[2]
    mesh.remeshNode(e.biped.leghair1)
    e.biped.leghair2.points[1] = e.biped.leg2.points[1]
    e.biped.leghair2.points[2] = e.biped.leg2.points[2]
    mesh.remeshNode(e.biped.leghair2)
end

-- this is about legs, need a similar one for arms
function getBodyYOffsetForDefaultStance(e)
    local magic = 4.46
    local d = e.biped.leg1.data
    print(e.biped.values.legDefaultStance)
    return -((d.length / magic) * d.scaleY) * (d.borderRadius + .66) * e.biped.values.legDefaultStance
end

function getMaxArmLength(e)
    local magic = 4.46
    local d = e.biped.arm1.data
    return ((d.length / magic) * d.scaleY) * (d.borderRadius + .66)
end

function BipedSystem:keepFeetPlantedAndStraightenLegs(e)
    -- print('doing it', leglengths[e.biped.values.legLength])
    --print(leglengths[e.biped.values.legLength])
    --print(inspect(e.biped.leg1.data))

    local d = e.biped.leg1.data
    --print(d.length / d.scaleY)
    -- todo ouch I odnt understand the .66 magic numebr, it sort of works though...

    e.biped.body.transforms.l[2] = getBodyYOffsetForDefaultStance(e) -- -( (d.length / magic)  * d.scaleY)   *(d.borderRadius+.66    )  *  e.biped.values.legDefaultStance   -- leglengths[e.biped.values.legLength] / d.scaleY
    BipedSystem:movedBody(e)
end

function BipedSystem:breath(e)
    e.biped.body.transforms.l[2] = e.biped.body.transforms.l[1] - 100
    Timer.tween(0.5, e.biped.body.transforms.l, { [4] = 1.1 }, 'out-elastic')
    Timer.during(0.6, function()
        BipedSystem:movedBody(e)
    end)
end

function BipedSystem:doinkBody(e)
    local dir = 1
    local str = 2
    local oldX = 0
    local oldY = 0
    e.biped.body.transforms.l[3] = str * dir
    e.biped.body.transforms.l[1] = oldX + (dir * str * 100)

    Timer.tween(2, e.biped.body.transforms.l, { [3] = 0,[1] = oldX }, 'out-elastic')

    e.biped.head.transforms.l[3] = str * dir
    Timer.tween(1.2, e.biped.head.transforms.l, { [3] = 0 }, 'out-elastic')

    Timer.during(2, function()
        BipedSystem:movedBody(e)
    end)
    -- Timer
end

function BipedSystem:itemReleased(elem)
    for _, e in ipairs(self.pool) do
        if e.biped.head == elem.item then
            --print('head released')
        end
        if not e.biped.values.handsPinned then
            if e.biped.hand1 == elem.item then
                local h1x, h1y, h2x, h2y = getDefaultHandPositions(e)
                Timer.tween(1.2, e.biped.arm1.points[2], { [1] = h1x,[2] = h1y }, 'out-elastic')
                Timer.during(1.3, function()
                    e.biped.hand1.transforms.l[1] = e.biped.arm1.points[2][1]
                    e.biped.hand1.transforms.l[2] = e.biped.arm1.points[2][2]
                    e.biped.armhair1.points[2] = e.biped.arm1.points[2]
                    mesh.remeshNode(e.biped.armhair1)
                    mesh.remeshNode(e.biped.arm1)
                end)
            end
            if e.biped.hand2 == elem.item then
                local h1x, h1y, h2x, h2y = getDefaultHandPositions(e)
                Timer.tween(1.2, e.biped.arm2.points[2], { [1] = h2x,[2] = h2y }, 'out-elastic')
                Timer.during(1.3, function()
                    e.biped.hand2.transforms.l[1] = e.biped.arm2.points[2][1]
                    e.biped.hand2.transforms.l[2] = e.biped.arm2.points[2][2]
                    e.biped.armhair2.points[2] = e.biped.arm2.points[2]
                    mesh.remeshNode(e.biped.armhair2)
                    mesh.remeshNode(e.biped.arm2)
                end)
            end
        end
        if e.biped.body == elem.item then
            --e.biped.body.transforms.l[3] = -1

            BipedSystem:tweenIntoDefaultStance(e, true)
        end
    end
end

function BipedSystem:tweenIntoDefaultStance(e, clear)
    print('tweenIntoDefaultStance')
    local offset = getBodyYOffsetForDefaultStance(e)
    --print('offset')
    e.biped.head.transforms.l[3] = -.3
    -- Timer.clear()
    if clear then Timer.clear() end
    Timer.tween(1.2, e.biped.head.transforms.l, { [3] = 0 }, 'out-elastic')
    Timer.tween(2, e.biped.body.transforms.l, { [1] = 0,[2] = offset }, 'out-elastic')
    BipedSystem:movedBody(e)
    Timer.during(2.2, function()
        BipedSystem:movedBody(e)
    end)
end

function BipedSystem:movedBody(e)
    e.biped.body.dirty = true

    transforms.setTransforms(e.biped.body)

    attachHeadWithOrWithoutNeck(e, true)

    setLegs(e)
    setArms(e)
    BipedSystem:bipedAttachHands(e)
    BipedSystem:bipedAttachFeet(e)
end

function BipedSystem:itemDrag(elem, dx, dy, scale)
    --print(elem.item.name)
    for _, e in ipairs(self.pool) do
        if e.biped.feet1 == elem.item then
            e.biped.feet1.transforms.l[1] = e.biped.feet1.transforms.l[1] + dx / scale
            e.biped.feet1.transforms.l[2] = e.biped.feet1.transforms.l[2] + dy / scale
            e.biped.leg1.points[2] = { e.biped.feet1.transforms.l[1], e.biped.feet1.transforms.l[2] }
            mesh.remeshNode(e.biped.leg1)

            e.biped.leghair1.points[2] = e.biped.leg1.points[2]
            mesh.remeshNode(e.biped.leghair1)


            local derivative = e.biped.leg1._curve:getDerivative()
            local dx, dy = derivative:evaluate(1)
            local angle = math.atan2(dy, dx) - math.pi / 2
            e.biped.feet1.transforms.l[3] = angle
            e.biped.feet1.dirty = true
        end
        if e.biped.feet2 == elem.item then
            e.biped.feet2.transforms.l[1] = e.biped.feet2.transforms.l[1] + dx / scale
            e.biped.feet2.transforms.l[2] = e.biped.feet2.transforms.l[2] + dy / scale
            e.biped.leg2.points[2] = { e.biped.feet2.transforms.l[1], e.biped.feet2.transforms.l[2] }
            mesh.remeshNode(e.biped.leg2)

            e.biped.leghair2.points[2] = e.biped.leg2.points[2]
            mesh.remeshNode(e.biped.leghair2)


            local derivative = e.biped.leg2._curve:getDerivative()
            local dx, dy = derivative:evaluate(1)
            local angle = math.atan2(dy, dx) - math.pi / 2
            e.biped.feet2.transforms.l[3] = angle
            e.biped.feet2.dirty = true
        end

        if e.biped.hand1 == elem.item then
            e.biped.hand1.transforms.l[1] = e.biped.hand1.transforms.l[1] + dx / scale
            e.biped.hand1.transforms.l[2] = e.biped.hand1.transforms.l[2] + dy / scale
            e.biped.arm1.points[2] = { e.biped.hand1.transforms.l[1], e.biped.hand1.transforms.l[2] }
            mesh.remeshNode(e.biped.arm1)

            -- if armhair1.points then
            e.biped.armhair1.points[2] = e.biped.arm1.points[2]
            mesh.remeshNode(e.biped.armhair1)
            -- end
        end
        if e.biped.hand2 == elem.item then
            e.biped.hand2.transforms.l[1] = e.biped.hand2.transforms.l[1] + dx / scale
            e.biped.hand2.transforms.l[2] = e.biped.hand2.transforms.l[2] + dy / scale
            e.biped.arm2.points[2] = { e.biped.hand2.transforms.l[1], e.biped.hand2.transforms.l[2] }
            mesh.remeshNode(e.biped.arm2)

            -- if armhair2.points then
            e.biped.armhair2.points[2] = e.biped.arm2.points[2]
            mesh.remeshNode(e.biped.armhair2)
            -- end
        end

        if e.biped.body == elem.item then
            -- this is still correct, to make the body move, but not the total location.
            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale
            --  print(e.biped.body.transforms.l[2])
            e.biped.body.dirty = true
            transforms.setTransforms(e.biped.body)

            attachHeadWithOrWithoutNeck(e, true)

            setLegs(e)
            setArms(e)
            BipedSystem:bipedAttachHands(e)
            BipedSystem:bipedAttachFeet(e)
        end
        if e.biped.head == elem.item then
            local hx, hy = getHeadDeltaAttachement(e)
            e.biped.head.transforms.l[1] = e.biped.head.transforms.l[1] + dx / scale
            e.biped.head.transforms.l[2] = e.biped.head.transforms.l[2] + dy / scale
            if e.biped.neck then
                e.biped.neck.points[2] = { e.biped.head.transforms.l[1] + hx, e.biped.head.transforms.l[2] + hy }
                -- todo figure out the angle between head and neck, and thus set the flop
                mesh.remeshNode(e.biped.neck)
            end
        end
    end
end

return BipedSystem
