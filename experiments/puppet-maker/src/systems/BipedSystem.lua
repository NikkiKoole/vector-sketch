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

function BipedSystem:birthGuy(e)
    --print('good morning!')

    local bodySX = e.biped.body.transforms.l[4]
    local bodySY = e.biped.body.transforms.l[5]
    local headSX = e.biped.head.transforms.l[4]
    local headSY = e.biped.head.transforms.l[5]

    -- ok lets hide everything but the body
    e.biped.head.transforms.l[4] = 0
    e.biped.head.transforms.l[5] = 0
    e.biped.neck.color[4] = 0
    e.biped.leg1.color[4] = 0
    e.biped.leghair1.color[4] = 0
    e.biped.arm1.color[4] = 0
    e.biped.armhair1.color[4] = 0
    e.biped.leg2.color[4] = 0
    e.biped.leghair2.color[4] = 0
    e.biped.arm2.color[4] = 0
    e.biped.armhair2.color[4] = 0
    e.biped.feet1.transforms.l[4] = 0
    e.biped.feet1.transforms.l[5] = 0
    e.biped.feet2.transforms.l[4] = 0
    e.biped.feet2.transforms.l[5] = 0
    e.biped.hand1.transforms.l[4] = 0
    e.biped.hand1.transforms.l[5] = 0
    e.biped.hand2.transforms.l[4] = 0
    e.biped.hand2.transforms.l[5] = 0

    e.biped.body.transforms.l[4] = 0
    e.biped.body.transforms.l[5] = 0

    Timer.tween(2, e.biped.body.transforms.l, { [4] = bodySX,[5] = bodySY }, 'out-elastic')

    for i = 1, 10 do
        Timer.after((i * 0.05 * love.math.random()), function()
            Timer.tween(0.1, e.biped.body.transforms.l, { [3] = love.math.random() - 0.5 })
        end)
    end
    Timer.after(0.6, function()
        Timer.tween(0.1, e.biped.body.transforms.l, { [3] = 0 })
    end)
    Timer.after(0.7, function()
        Timer.tween(1.5, e.biped.head.transforms.l, { [4] = headSX,[5] = headSY }, 'out-elastic', nil, 1, .3)
    end)


    Timer.during(3, function()
        mesh.remeshNode(e.biped.leg1)
        mesh.remeshNode(e.biped.leghair1)
        mesh.remeshNode(e.biped.body)
        --BipedSystem:movedBody(e)
        setLegs(e)
        setArms(e)
        BipedSystem:bipedAttachFeet(e)
        BipedSystem:bipedAttachHands(e)
        attachHeadWithOrWithoutNeck(e, false)
    end)

    if false then
        local hasLegHair = e.biped.leghair1.data

        local leg1SX = e.biped.leg1.data.scaleX
        local leg1SY = e.biped.leg1.data.scaleY

        local leg1PX = e.biped.leg1.points[2][1]
        local leg1PY = e.biped.leg1.points[2][2]
        local leg1Alpha = e.biped.leg1.color[4] or 1
        -- todo IF leghair only do this

        local feet1SX = e.biped.feet1.transforms.l[4]
        local feet1SY = e.biped.feet1.transforms.l[5]

        local bodySX = e.biped.body.transforms.l[4]
        local bodySY = e.biped.body.transforms.l[5]
        local bodyR = e.biped.body.transforms.l[3]

        local headR = e.biped.head.transforms.l[3]
        local headSX = e.biped.head.transforms.l[4]
        local headSY = e.biped.head.transforms.l[5]


        e.biped.body.transforms.l[4] = 0.01
        e.biped.body.transforms.l[5] = 0.01

        e.biped.body.transforms.l[3] = -math.pi

        e.biped.head.transforms.l[3] = math.pi * 1
        e.biped.head.transforms.l[4] = 0.01
        e.biped.head.transforms.l[5] = 0.01

        e.biped.leg1.points[2][1] = e.biped.leg1.points[1][1] + 20
        e.biped.leg1.points[2][2] = e.biped.leg1.points[1][2] + 20
        e.biped.leg1.color[4] = 0
        --e.biped.leg2.color[4] = 0

        e.biped.leg1.data.scaleX = 0.1
        e.biped.leg1.data.scaleY = 0.1

        e.biped.feet1.transforms.l[4] = 0.1
        e.biped.feet1.transforms.l[5] = 0.1
        Timer.clear()

        Timer.tween(2, e.biped.leg1.data, { scaleX = leg1SX, scaleY = leg1SY }, 'out-elastic')
        Timer.tween(1, e.biped.leg1.color, { [4] = leg1Alpha }, 'in-bounce')
        Timer.tween(2, e.biped.feet1.transforms.l, { [4] = feet1SX,[5] = feet1SY }, 'out-elastic')
        Timer.tween(4, e.biped.body.transforms.l, { [3] = bodyR,[4] = bodySX,[5] = bodySX }, 'out-elastic')
        Timer.tween(6, e.biped.head.transforms.l, { [3] = headR,[4] = headSX,[5] = headSY }, 'out-elastic')
        if hasLegHair then
            local legH1SX = e.biped.leghair1.data.scaleX
            local legH1SY = e.biped.leghair1.data.scaleY
            e.biped.leghair1.data.scaleX = 0.1
            e.biped.leghair1.data.scaleY = 0.1
            e.biped.leghair1.color[4] = 0
            Timer.tween(5, e.biped.leghair1.color, { [4] = leg1Alpha }, 'out-elastic')
            Timer.tween(2, e.biped.leghair1.data, { scaleX = legH1SX, scaleY = legH1SY }, 'out-elastic')
        end

        Timer.tween(1, e.biped.leg1.points[2], { [1] = leg1PX,[2] = leg1PY },
            'out-elastic')


        Timer.during(7, function()
            mesh.remeshNode(e.biped.leg1)
            mesh.remeshNode(e.biped.leghair1)
            mesh.remeshNode(e.biped.body)
            --BipedSystem:movedBody(e)
            setLegs(e)
            setArms(e)
            BipedSystem:bipedAttachFeet(e)
            BipedSystem:bipedAttachHands(e)
            attachHeadWithOrWithoutNeck(e, false)
        end)
    end
end

function BipedSystem:bipedInit(e)
    --  print('bipedInit', e, e.biped)
    e.biped.body.transforms.l[3] = 0 -- math.pi / 2
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
            e.biped.neck.points[2] = { neckX, neckY - ((e.biped.neck.data.length * e.biped.neck.data.scaleY) / 4.46) / 1 }
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
    local offset = getBodyYOffsetForDefaultStance(e)
    print('offset')
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
