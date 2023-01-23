local BipedSystem = Concord.system({ pool = { 'biped' } })
local node = require 'lib.node'
local mesh = require 'lib.mesh'
local transforms = require 'lib.transform'
local parentize = require 'lib.parentize'


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

local function getPositionsForNeckAttaching(body)

    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
        return body.children[2].points[1]
    else
        local neck = node.findNodeByName(body, 'neck')
        if neck then
            return neck.points[1]
        end
    end
end

local function getPositionsForArmsAttaching(e)
    local body = e.biped.body
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
            if e.biped.potatoHead then
                return body.children[2].points[7], body.children[2].points[3]
            else
        return body.children[2].points[8], body.children[2].points[2]
            end
    else
        local lc1 = node.findNodeByName(body, 'arm1')
        local lc2 = node.findNodeByName(body, 'arm2')
        if lc1 and lc2 then
            return lc1.points[1], lc2.points[1]
        end
    end
end

local function getPositionsForLegsAttaching(body)
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
        return body.children[2].points[6], body.children[2].points[4]
    else
        local lc1 = node.findNodeByName(body, 'leg1')
        local lc2 = node.findNodeByName(body, 'leg2')
        if lc1 and lc2 then
            return lc1.points[1], lc2.points[1]
        end
    end
end

function BipedSystem:bipedInit(e)
    local body     = e.biped.body
    local lc1, lc2 = getPositionsForLegsAttaching(body)

    e.biped.body.transforms.l[3] = 0

    if lc1 and lc2 then
        local dx1, dy1 = body.transforms._g:transformPoint(lc1[1], lc1[2])
        e.biped.leg1.points[1] = { dx1, dy1 }
        e.biped.leg1.points[2] = { dx1, dy1 + (leg1.data.length / 4.46) / 1 }
        local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
        e.biped.leg2.points[1] = { dx1, dy1 }
        e.biped.leg2.points[2] = { dx1, dy1 + (leg2.data.length / 4.46) / 1 }

        e.biped.feet2.transforms.l[4] = -1
        BipedSystem:bipedAttachFeet(e)
        mesh.remeshNode(e.biped.leg1)
        mesh.remeshNode(e.biped.leg2)
    end


    local ac1, ac2 = getPositionsForArmsAttaching(e)
    if (ac1 and ac2) then
        local dx1, dy1 = body.transforms._g:transformPoint(ac1[1], ac1[2])
        e.biped.arm1.points[1] = { dx1, dy1 }
        e.biped.arm1.points[2] = { dx1 - (arm1.data.length / 4.46) / 1, dy1 }

        local dx1, dy1 = body.transforms._g:transformPoint(ac2[1], ac2[2])
        e.biped.arm2.points[1] = { dx1, dy1 }
        e.biped.arm2.points[2] = { dx1 + (arm2.data.length / 4.46) / 1, dy1 }

        e.biped.hand2.transforms.l[4] = -1
        BipedSystem:bipedAttachHands(e)
        mesh.remeshNode(e.biped.arm1)
        mesh.remeshNode(e.biped.arm2)
    end

    attachHeadWithOrWithoutNeck(e, false)
end

function BipedSystem:update(dt)

end

function BipedSystem:bipedUsePotatoHead(e, value)

    e.biped.potatoHead = value
    print('bipedUsePotatoHead', e.biped.potatoHead)
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

function setLegs(body, e)

    local lc1, lc2 = getPositionsForLegsAttaching(body)
    if lc1 and lc2 then
        local dx1, dy1 = body.transforms._g:transformPoint(lc1[1], lc1[2])
        e.biped.leg1.points[1] = { dx1, dy1 }
        mesh.remeshNode(e.biped.leg1)


        local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
        e.biped.leg2.points[1] = { dx1, dy1 }
        mesh.remeshNode(e.biped.leg2)

    end
end

function BipedSystem:bipedAttachLegs(e)

    local body = e.biped.body
    setLegs(body, e)
end

function setArms(body, e, optionalData)


    local keep = true
    local lc1, lc2 = getPositionsForArmsAttaching(e)
    if lc1 and lc2 then

        local angle, dist = getAngleAndDistance(e.biped.arm1.points[2][1], e.biped.arm1.points[2][2],
            e.biped.arm1.points[1][1], e.biped.arm1.points[1][2])

        local dx1, dy1 = body.transforms._g:transformPoint(lc1[1], lc1[2])
        e.biped.arm1.points[1] = { dx1, dy1 }
        if keep then

            -- instead of angle use  e.biped.body.transforms.l[3] - math.pi

            local newx, newy = setAngleAndDistance(dx1, dy1, angle, dist)
            e.biped.arm1.points[2] = { newx, newy }
        end
        mesh.remeshNode(e.biped.arm1)


        local angle, dist = getAngleAndDistance(e.biped.arm2.points[2][1], e.biped.arm2.points[2][2],
            e.biped.arm2.points[1][1], e.biped.arm2.points[1][2])
        local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
        e.biped.arm2.points[1] = { dx1, dy1 }
        if keep then
            -- instead of angle use  e.biped.body.transforms.l[3]
            local newx, newy = setAngleAndDistance(dx1, dy1, angle, dist)
            e.biped.arm2.points[2] = { newx, newy }
        end
        mesh.remeshNode(e.biped.arm2)

    end
end

function BipedSystem:bipedAttachArms(e)

    local body = e.biped.body
    setArms(body, e)
end

function BipedSystem:itemRotate(elem, dx, dy, scale)
    for _, e in ipairs(self.pool) do

        if e.biped.body == elem.item then
            local body = e.biped.body
            -- todo, i ought to get the angle now to keep the arms, rotated the same way
            --local angle, dist = getAngleAndDistance(e.biped.arm1.points[2][1],e.biped.arm1.points[2][2], e.biped.arm1.points[1][1], e.biped.arm1.points[1][2])
            --local angle2, dist2 = getAngleAndDistance(e.biped.arm2.points[2][1],e.biped.arm2.points[2][2], e.biped.arm2.points[1][1], e.biped.arm2.points[1][2])
            --local data = {a1=angle, d1=dist, a2=angle2, dist2=dist}


            e.biped.body.transforms.l[3] = e.biped.body.transforms.l[3] + 0.1
            transforms.setTransforms(e.biped.body)
            setLegs(body, e)
            setArms(body, e)
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
    local body     = e.biped.body
    local nc       = getPositionsForNeckAttaching(body)
    local dx1, dy1 = body.transforms._g:transformPoint(nc[1], nc[2])

    if (e.biped.neck) then

        if keepAngleAndDistance then
            local angle, dist = getAngleAndDistance(e.biped.neck.points[2][1], e.biped.neck.points[2][2],
                e.biped.neck.points[1][1], e.biped.neck.points[1][2])
            e.biped.neck.points[1] = { dx1, dy1 }
            local newx, newy = setAngleAndDistance(dx1, dy1, angle, dist)
            e.biped.neck.points[2] = { newx, newy }
        else
            e.biped.neck.points[1] = { dx1, dy1 }
            e.biped.neck.points[2] = { dx1, dy1 - (neck.data.length / 4.46) / 1 }
        end


        mesh.remeshNode(e.biped.neck)

        e.biped.head.transforms.l[1] = e.biped.neck.points[2][1]
        e.biped.head.transforms.l[2] = e.biped.neck.points[2][2]
    else
        e.biped.head.transforms.l[1] = dx1
        e.biped.head.transforms.l[2] = dy1
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

            --local derivative = e.biped.leg1._curve:getDerivative()
            --local dx, dy = derivative:evaluate(1)
            --local angle = math.atan2(dy, dx) - math.pi / 2
            --e.biped.feet1.transforms.l[3] = angle
            --e.biped.feet1.dirty = true
        end
        if e.biped.hand2 == elem.item then
            e.biped.hand2.transforms.l[1] = e.biped.hand2.transforms.l[1] + dx / scale
            e.biped.hand2.transforms.l[2] = e.biped.hand2.transforms.l[2] + dy / scale
            e.biped.arm2.points[2] = { e.biped.hand2.transforms.l[1], e.biped.hand2.transforms.l[2] }
            mesh.remeshNode(e.biped.arm2)

            -- local derivative = e.biped.leg2._curve:getDerivative()
            -- local dx, dy = derivative:evaluate(1)
            -- local angle = math.atan2(dy, dx) - math.pi / 2
            -- e.biped.feet2.transforms.l[3] = angle
            -- e.biped.feet2.dirty = true

        end

        if e.biped.body == elem.item then

            local body = e.biped.body
            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale
            e.biped.body.dirty = true
            transforms.setTransforms(e.biped.body)

            attachHeadWithOrWithoutNeck(e, true)

            setLegs(body, e)
            setArms(body, e)
            BipedSystem:bipedAttachHands(e)
        end
        if e.biped.head == elem.item then
            -- e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            -- e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale

            e.biped.head.transforms.l[1] = e.biped.head.transforms.l[1] + dx / scale
            e.biped.head.transforms.l[2] = e.biped.head.transforms.l[2] + dy / scale
            if e.biped.neck then
                e.biped.neck.points[2] = { e.biped.head.transforms.l[1], e.biped.head.transforms.l[2] }
                -- todo figure out the angle between head and neck, and thus set the flop
                mesh.remeshNode(e.biped.neck)
            end

            --e.biped.neck.transforms.l[1] =
            -- e.biped.leg1.points[1] = { e.biped.leg1.points[1][1] + dx / scale, e.biped.leg1.points[1][2] + dy / scale }
            -- e.biped.leg1.points[2] = { e.biped.leg1.points[2][1] + dx / scale, e.biped.leg1.points[2][2] + dy / scale }

            -- e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
            -- e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]


            -- e.biped.leg2.points[1] = { e.biped.leg2.points[1][1] + dx / scale, e.biped.leg2.points[1][2] + dy / scale }
            -- e.biped.leg2.points[2] = { e.biped.leg2.points[2][1] + dx / scale, e.biped.leg2.points[2][2] + dy / scale }

            -- e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
            -- e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]

            -- mesh.remeshNode(e.biped.leg1)
            -- mesh.remeshNode(e.biped.leg2)

            -- e.biped.feet1.dirty = true
            -- e.biped.feet2.dirty = true
            -- transforms.setTransforms(e.biped.body)
            -- transforms.setTransforms(e.biped.head)
        end
    end

end

return BipedSystem
