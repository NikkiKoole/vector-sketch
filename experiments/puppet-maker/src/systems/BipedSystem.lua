local BipedSystem = Concord.system({ pool = { 'biped' } })
local node = require 'lib.node'
local mesh = require 'lib.mesh'
local transforms = require 'lib.transform'


local function getPositionsForNeckAttaching(body)
    -- this should return
    if body.children[2] and body.children[2].type == 'meta' and #body.children[2].points == 8 then
        return body.children[2].points[1]
    else
        local neck = node.findNodeByName(body, 'neck')
        if neck then
            return neck.points[1]
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
        e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
        e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]
        mesh.remeshNode(e.biped.leg1)

        local dx1, dy1 = body.transforms._g:transformPoint(lc2[1], lc2[2])
        e.biped.leg2.points[1] = { dx1, dy1 }
        e.biped.leg2.points[2] = { dx1, dy1 + (leg2.data.length / 4.46) / 1 }
        e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
        e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]
        e.biped.feet2.transforms.l[4] = -1
        mesh.remeshNode(e.biped.leg2)
    end


    local nc = getPositionsForNeckAttaching(body)
    local dx1, dy1 = body.transforms._g:transformPoint(nc[1], nc[2])
    e.biped.head.transforms.l[1] = dx1
    e.biped.head.transforms.l[2] = dy1


    local derivative = e.biped.leg1._curve:getDerivative()
    local dx, dy = derivative:evaluate(0.9)
    local angle = math.atan2(dy, dx) + math.pi / 2


end

function BipedSystem:update(dt)

end

function BipedSystem:bipedDirection(e, dir)

    if dir == 'left' then

        e.biped.guy.children = { e.biped.leg1, e.biped.feet1, e.biped.body, e.biped.leg2, e.biped.feet2,e.biped.neck, e.biped.head }
        e.biped.leg1.data.flop = -1
        e.biped.leg2.data.flop = -1
        e.biped.feet1.transforms.l[4] = 1
        e.biped.feet2.transforms.l[4] = 1
    elseif dir == 'right' then

        e.biped.guy.children = { e.biped.leg2, e.biped.feet2, e.biped.body, e.biped.leg1, e.biped.feet1, e.biped.neck,e.biped.head }
        e.biped.leg1.data.flop = 1
        e.biped.leg2.data.flop = 1

        e.biped.feet1.transforms.l[4] = -1
        e.biped.feet2.transforms.l[4] = -1
    elseif dir == 'down' then

        e.biped.guy.children = { e.biped.body, e.biped.leg1, e.biped.leg2, e.biped.feet1, e.biped.feet2, e.biped.neck,e.biped.head }
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

function BipedSystem:itemRotate(elem, dx, dy, scale)
    for _, e in ipairs(self.pool) do

        if e.biped.body == elem.item then
            local body = e.biped.body
            e.biped.body.transforms.l[3] = e.biped.body.transforms.l[3] + 0.1
            transforms.setTransforms(e.biped.body)
            setLegs(body, e)
            BipedSystem:bipedAttachHead(e)
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

function BipedSystem:bipedAttachHead(e)
    local body = e.biped.body
    local nc = getPositionsForNeckAttaching(body)
    local dx1, dy1 = body.transforms._g:transformPoint(nc[1], nc[2])

    e.biped.head.transforms.l[1] = dx1
    e.biped.head.transforms.l[2] = dy1
    e.biped.head.dirty = true
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
        if e.biped.body == elem.item then

            local body = e.biped.body
            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale
            e.biped.body.dirty = true
            transforms.setTransforms(e.biped.body)

            local nc = getPositionsForNeckAttaching(body) --   node.findNodeByName(body, 'neck')
            local dx1, dy1 = body.transforms._g:transformPoint(nc[1], nc[2])
            e.biped.head.transforms.l[1] = dx1
            e.biped.head.transforms.l[2] = dy1
            e.biped.head.dirty = true

            setLegs(body, e)
        end
        if e.biped.head == elem.item then
            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale

            e.biped.head.transforms.l[1] = e.biped.head.transforms.l[1] + dx / scale
            e.biped.head.transforms.l[2] = e.biped.head.transforms.l[2] + dy / scale

            e.biped.leg1.points[1] = { e.biped.leg1.points[1][1] + dx / scale, e.biped.leg1.points[1][2] + dy / scale }
            e.biped.leg1.points[2] = { e.biped.leg1.points[2][1] + dx / scale, e.biped.leg1.points[2][2] + dy / scale }

            e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
            e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]


            e.biped.leg2.points[1] = { e.biped.leg2.points[1][1] + dx / scale, e.biped.leg2.points[1][2] + dy / scale }
            e.biped.leg2.points[2] = { e.biped.leg2.points[2][1] + dx / scale, e.biped.leg2.points[2][2] + dy / scale }

            e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
            e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]

            mesh.remeshNode(e.biped.leg1)
            mesh.remeshNode(e.biped.leg2)

            e.biped.feet1.dirty = true
            e.biped.feet2.dirty = true
            transforms.setTransforms(e.biped.body)
            transforms.setTransforms(e.biped.head)
        end
    end

end

return BipedSystem
