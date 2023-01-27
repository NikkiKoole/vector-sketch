local BipedSystem = Concord.system({ pool = { 'biped' } })
local node = require 'lib.node'
local mesh = require 'lib.mesh'
local transforms = require 'lib.transform'
local parentize = require 'lib.parentize'
local bbox = require 'lib.bbox'
local numbers = require 'lib.numbers'

local function getAngleAndDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local angle = math.atan2(dy, dx)
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return angle, distance
end

local function setAngleAndDistance(sx, sy, angle, distance)
    local newx = sx + distance * math.cos(angle)
    local newy = sy + distance * math.sin(angle)
    return newx, newy
end

-- getting positions for attachments via the 8way meta object
-- this should also work in the furture for parts that are flipped vertically
-- this way i can, for free, have double the amount of shapes, no extra sprites needed.

-- another thing that needs to happen, now i just deirectly get apoint on the 8way polygon
-- i want to lerp between 2 or more points to get a position, this way i can move attachements positions in the editor


local function getFlippedMetaObject(flipx, flipy, points)
    local tlx, tly, brx, bry = bbox.getPointsBBox(points)
    local mx = tlx + (brx - tlx) / 2
    local my = tly + (bry - tly) / 2
    local newPoints = {}

    for i = 1, #points do
        local newY = points[i][2]
        if flipy == -1 then
            local dy = my - points[i][2]
            newY = my + dy
        end
        local newX = points[i][1]
        if flipx == -1 then
            local dx = mx - points[i][1]
            newX = mx + dx
        end
        newPoints[i] = { newX, newY }
    end
    local temp = copy3(newPoints)
    if flipy == -1 and flipx == 1 then
        newPoints[1] = temp[5]
        newPoints[2] = temp[4]
        newPoints[3] = temp[3]
        newPoints[4] = temp[2]
        newPoints[5] = temp[1]
        newPoints[6] = temp[8]
        newPoints[7] = temp[7]
        newPoints[8] = temp[6]
    end
    if flipx == -1 and flipy == 1 then
        newPoints[1] = temp[1]
        newPoints[2] = temp[8]
        newPoints[3] = temp[7]
        newPoints[4] = temp[6]
        newPoints[5] = temp[5]
        newPoints[6] = temp[4]
        newPoints[7] = temp[3]
        newPoints[8] = temp[2]
    end
    if flipx == -1 and flipy == -1 then
        newPoints[1] = temp[5]
        newPoints[2] = temp[6]
        newPoints[3] = temp[7]
        newPoints[4] = temp[8]
        newPoints[5] = temp[1]
        newPoints[6] = temp[2]
        newPoints[7] = temp[3]
        newPoints[8] = temp[4]
    end


    return newPoints
end

local function getPositionsForNeckAttaching(e)
    local body = e.biped.body
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
        local flipx = e.biped.values.body.flipx or 1
        local flipy = e.biped.values.body.flipy or 1
        local points = body.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)

        local x,y = body.transforms._g:transformPoint(newPoints[1][1], newPoints[1][2])
        return x,y
    else
        local neck = node.findNodeByName(body, 'neck')
        if neck then
            local x,y = body.transforms._g:transformPoint(neck.points[1][1], neck.points[1][2])
            return x,y
        end
    end
end


local function getPositionsForArmsAttaching(e)

    local body = e.biped.body
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then

        local flipx = e.biped.values.body.flipx or 1
        local flipy = e.biped.values.body.flipy or 1
        local points = body.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)

        if e.biped.potatoHead then
            local a1x, a1y = body.transforms._g:transformPoint(newPoints[7][1], newPoints[7][2])
            local a2x, a2y = body.transforms._g:transformPoint(newPoints[3][1], newPoints[3][2])
            return a1x, a1y, a2x, a2y
        else
            local a1x, a1y = body.transforms._g:transformPoint(newPoints[8][1], newPoints[8][2])
            local a2x, a2y = body.transforms._g:transformPoint(newPoints[2][1], newPoints[2][2])
 
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
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
        local flipx = e.biped.values.body.flipx or 1
        local flipy = e.biped.values.body.flipy or 1
        local points = body.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        local l1x, l1y  = body.transforms._g:transformPoint(newPoints[6][1], newPoints[6][2])
        local l2x, l2y  = body.transforms._g:transformPoint(newPoints[4][1], newPoints[4][2])
        return l1x, l1y, l2x, l2y
    else
        local lc1 = node.findNodeByName(body, 'leg1')
        local lc2 = node.findNodeByName(body, 'leg2')
        if lc1 and lc2 then
            local l1x, l1y  = body.transforms._g:transformPoint( lc1.points[1])
            local l2x, l2y  = body.transforms._g:transformPoint(lc2.points[1])
            return l1x, l1y, l2x, l2y
        end
    end
end

local function getPositionForNoseAttaching(e)
    local parent =  e.biped.potatoHead and e.biped.body or e.biped.head
    print(parent)
    local parentName =  e.biped.potatoHead and 'body' or 'head'
    if parent.children[2] and parent.children[2].type == 'meta' and #parent.children[2].points == 8 then
        local flipx = e.biped.values[parentName].flipx or 1
        local flipy = e.biped.values[parentName].flipy or 1
        local points = parent.children[2].points
        local newPoints = getFlippedMetaObject(flipx, flipy, points)
        local x = numbers.lerp(newPoints[7][1], newPoints[3][1], 0.5)
        local y = numbers.lerp(newPoints[7][2], newPoints[3][2], 0.5)
        local nx, ny = parent.transforms._g:transformPoint(x,y)
        return nx, ny
    end
end

function BipedSystem:bipedInit(e)
  --  local body     = e.biped.body
    local l1x, l1y, l2x, l2y = getPositionsForLegsAttaching(e)
    e.biped.body.transforms.l[3] = 0

   
    e.biped.leg1.points[1] = { l1x, l1y }
    e.biped.leg1.points[2] = { l1x, l1y + (leg1.data.length / 4.46) / 1 }
    e.biped.leg2.points[1] = { l2x, l2y }
    e.biped.leg2.points[2] = { l2x, l2y + (leg2.data.length / 4.46) / 1 }

    e.biped.feet2.transforms.l[4] = -1
    BipedSystem:bipedAttachFeet(e)
    mesh.remeshNode(e.biped.leg1)
    mesh.remeshNode(e.biped.leg2)

    local a1x, a1y, a2x, a2y = getPositionsForArmsAttaching(e)

    e.biped.arm1.points[1] = { a1x, a1y }
    e.biped.arm1.points[2] = { a1x - (arm1.data.length / 4.46) / 1, a1y }

    e.biped.arm2.points[1] = { a2x, a2y }
    e.biped.arm2.points[2] = { a2x + (arm2.data.length / 4.46) / 1, a2y }

    e.biped.hand2.transforms.l[4] = -1
    BipedSystem:bipedAttachHands(e)
    mesh.remeshNode(e.biped.arm1)
    mesh.remeshNode(e.biped.arm2)


    attachHeadWithOrWithoutNeck(e, false)

    local nx, ny = getPositionForNoseAttaching(e)
    e.biped.nose.transforms.l[1] =  0 --400 + nx
    e.biped.nose.transforms.l[2] = 0--ny
    print(nx, ny)
    mesh.remeshNode(e.biped.nose)
end

function BipedSystem:update(dt)

end

function BipedSystem:bipedUsePotatoHead(e, value)

    e.biped.potatoHead = value

    guy.children = guyChildren(biped)

    parentize.parentize(root)
    mesh.meshAll(root)
    BipedSystem:bipedAttachArms(e)
    BipedSystem:bipedAttachHands(e)
end

function BipedSystem:bipedDirection(e, dir)

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
end

function setLegs(e)
    local body = e.biped.body
    --local lc1, lc2 = getPositionsForLegsAttaching(e)
    local l1x, l1y, l2x, l2y = getPositionsForLegsAttaching(e)
    --if lc1 and lc2 then
        --local dx1, dy1 = body.transforms._g:transformPoint(lc1[1], lc1[2])
        e.biped.leg1.points[1] = { l1x, l1y }
        mesh.remeshNode(e.biped.leg1)


        --local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
        e.biped.leg2.points[1] = { l2x, l2y }
        mesh.remeshNode(e.biped.leg2)

    --end
end

function BipedSystem:bipedAttachLegs(e)
    setLegs(e)
end

function setArms(e, optionalData)


    local keep = true
    local a1x, a1y, a2x, a2y = getPositionsForArmsAttaching(e)

        local body = e.biped.body
        local angle, dist = getAngleAndDistance(e.biped.arm1.points[2][1], e.biped.arm1.points[2][2],
            e.biped.arm1.points[1][1], e.biped.arm1.points[1][2])


        e.biped.arm1.points[1] = { a1x, a1y }
        if keep then
            local newx, newy = setAngleAndDistance(a1x, a1y, angle, dist)
            e.biped.arm1.points[2] = { newx, newy }
        end
        mesh.remeshNode(e.biped.arm1)


        local angle, dist = getAngleAndDistance(e.biped.arm2.points[2][1], e.biped.arm2.points[2][2],
            e.biped.arm2.points[1][1], e.biped.arm2.points[1][2])

        e.biped.arm2.points[1] = { a2x, a2y }
        if keep then
            -- instead of angle use  e.biped.body.transforms.l[3]
            local newx, newy = setAngleAndDistance(a2x, a2y, angle, dist)
            e.biped.arm2.points[2] = { newx, newy }
        end
        mesh.remeshNode(e.biped.arm2)

    --end
end

function BipedSystem:bipedAttachArms(e)

    --local body = e.biped.body
    setArms(e)
end

function BipedSystem:itemRotate(elem, dx, dy, scale)
    for _, e in ipairs(self.pool) do

        if e.biped.body == elem.item then

            e.biped.body.transforms.l[3] = e.biped.body.transforms.l[3] + 0.1
            transforms.setTransforms(e.biped.body)
            setLegs(e)
            setArms(e)
            BipedSystem:bipedAttachHead(e)
            BipedSystem:bipedAttachHands(e)
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

function attachHeadWithOrWithoutNeck(e, keepAngleAndDistance)

    local neckX, neckY       = getPositionsForNeckAttaching(e)

    if (e.biped.neck) then

        if keepAngleAndDistance then
            local angle, dist = getAngleAndDistance(e.biped.neck.points[2][1], e.biped.neck.points[2][2],
                e.biped.neck.points[1][1], e.biped.neck.points[1][2])
            e.biped.neck.points[1] = { neckX, neckY }
            local newx, newy = setAngleAndDistance(neckX, neckY, angle, dist)
            e.biped.neck.points[2] = { newx, newy }
        else
            e.biped.neck.points[1] = { neckX, neckY }
            e.biped.neck.points[2] = { neckX, neckY - (neck.data.length / 4.46) / 1 }
        end


        mesh.remeshNode(e.biped.neck)

        e.biped.head.transforms.l[1] = e.biped.neck.points[2][1]
        e.biped.head.transforms.l[2] = e.biped.neck.points[2][2]
    else
        e.biped.head.transforms.l[1] = neckX
        e.biped.head.transforms.l[2] = neckY
    end
    e.biped.head.dirty = true
    e.biped.neck.dirty = true
    transforms.setTransforms(e.biped.neck)
end

function BipedSystem:itemDrag(elem, dx, dy, scale)
    --print(elem.item.name)
    for _, e in ipairs(self.pool) do
        if e.biped.feet1 == elem.item then
            e.biped.feet1.transforms.l[1] = e.biped.feet1.transforms.l[1] + dx / scale
            e.biped.feet1.transforms.l[2] = e.biped.feet1.transforms.l[2] + dy / scale
            e.biped.leg1.points[2] = { e.biped.feet1.transforms.l[1], e.biped.feet1.transforms.l[2] }
            mesh.remeshNode(e.biped.leg1)

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

        end
        if e.biped.hand2 == elem.item then
            e.biped.hand2.transforms.l[1] = e.biped.hand2.transforms.l[1] + dx / scale
            e.biped.hand2.transforms.l[2] = e.biped.hand2.transforms.l[2] + dy / scale
            e.biped.arm2.points[2] = { e.biped.hand2.transforms.l[1], e.biped.hand2.transforms.l[2] }
            mesh.remeshNode(e.biped.arm2)

        end

        if e.biped.body == elem.item then

            --local body = e.biped.body
            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale
            e.biped.body.dirty = true
            transforms.setTransforms(e.biped.body)

            attachHeadWithOrWithoutNeck(e, true)

            setLegs(e)
            setArms(e)
            BipedSystem:bipedAttachHands(e)
        end
        if e.biped.head == elem.item then


            e.biped.head.transforms.l[1] = e.biped.head.transforms.l[1] + dx / scale
            e.biped.head.transforms.l[2] = e.biped.head.transforms.l[2] + dy / scale
            if e.biped.neck then
                e.biped.neck.points[2] = { e.biped.head.transforms.l[1], e.biped.head.transforms.l[2] }
                -- todo figure out the angle between head and neck, and thus set the flop
                mesh.remeshNode(e.biped.neck)
            end

         
        end
    end

end

return BipedSystem
