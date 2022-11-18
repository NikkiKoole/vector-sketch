local BipedSystem = Concord.system({ pool = { 'biped' } })
local node = require 'lib.node'
local mesh = require 'lib.mesh'
local transforms = require 'lib.transform'
function BipedSystem:update(dt)
    for _, e in ipairs(self.pool) do

        local body = e.biped.body
        local lc1 = node.findNodeByName(body, 'leg1')
        local lc2 = node.findNodeByName(body, 'leg2')
        local nc = node.findNodeByName(body, 'neck')
        local dx1, dy1 = body.transforms._g:transformPoint(nc.points[1][1], nc.points[1][2])

        e.biped.head.transforms.l[1] = dx1
        e.biped.head.transforms.l[2] = dy1

        if false and lc1 and lc2 then
            --left
            local dx1, dy1 = body.transforms._g:transformPoint(lc1.points[1][1], lc1.points[1][2])
            e.biped.leg1.points[1] = { dx1, dy1 }
            -- min 0.05
            e.biped.leg1.points[2] = { dx1, dy1 + (leg1.data.length / 4.46) / 1 }

            e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
            e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]
            e.biped.feet1.transforms.l[3] = 0

            mesh.remeshNode(e.biped.leg1)

            local dx1, dy1 = body.transforms._g:transformPoint(lc2.points[1][1], lc2.points[1][2])
            e.biped.leg2.points[1] = { dx1, dy1 }
            e.biped.leg2.points[2] = { dx1, dy1 + (leg2.data.length / 4.46) / 1 }

            e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
            e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]
            e.biped.feet2.transforms.l[4] = -1

            mesh.remeshNode(e.biped.leg2)

            --print(lc1)

        end
    end

end

function BipedSystem:bipedInit(e)

    local body = e.biped.body
    local lc1 = node.findNodeByName(body, 'leg1')
    local lc2 = node.findNodeByName(body, 'leg2')
    if lc1 and lc2 then
        local dx1, dy1 = body.transforms._g:transformPoint(lc1.points[1][1], lc1.points[1][2])
        e.biped.leg1.points[1] = { dx1, dy1 }
        e.biped.leg1.points[2] = { dx1, dy1 + (leg1.data.length / 4.46) / 1 }
        e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
        e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]
        mesh.remeshNode(e.biped.leg1)

        local dx1, dy1 = body.transforms._g:transformPoint(lc2.points[1][1], lc2.points[1][2])
        e.biped.leg2.points[1] = { dx1, dy1 }
        e.biped.leg2.points[2] = { dx1, dy1 + (leg2.data.length / 4.46) / 1 }
        e.biped.feet2.transforms.l[1] = e.biped.leg2.points[2][1]
        e.biped.feet2.transforms.l[2] = e.biped.leg2.points[2][2]
        e.biped.feet2.transforms.l[4] = -1
        mesh.remeshNode(e.biped.leg2)
    end

    local nc = node.findNodeByName(body, 'neck')
    local dx1, dy1 = body.transforms._g:transformPoint(nc.points[1][1], nc.points[1][2])

    e.biped.head.transforms.l[1] = dx1
    e.biped.head.transforms.l[2] = dy1
    print(e.biped.head)

end

function BipedSystem:itemDrag(elem, dx, dy, scale)

    for _, e in ipairs(self.pool) do
        if e.biped.feet1 == elem.item then
            --print("FEET1")
            e.biped.feet1.transforms.l[1] = e.biped.feet1.transforms.l[1] + dx / scale
            e.biped.feet1.transforms.l[2] = e.biped.feet1.transforms.l[2] + dy / scale
            e.biped.leg1.points[2] = { e.biped.feet1.transforms.l[1], e.biped.feet1.transforms.l[2] }
            mesh.remeshNode(e.biped.leg1)
        end
        if e.biped.feet2 == elem.item then
            --print("FEET1")
            e.biped.feet2.transforms.l[1] = e.biped.feet2.transforms.l[1] + dx / scale
            e.biped.feet2.transforms.l[2] = e.biped.feet2.transforms.l[2] + dy / scale
            e.biped.leg2.points[2] = { e.biped.feet2.transforms.l[1], e.biped.feet2.transforms.l[2] }
            mesh.remeshNode(e.biped.leg2)
        end
        if e.biped.body == elem.item then

            local body = e.biped.body

            e.biped.body.transforms.l[1] = e.biped.body.transforms.l[1] + dx / scale
            e.biped.body.transforms.l[2] = e.biped.body.transforms.l[2] + dy / scale

            e.biped.body.transforms.l[3] = e.biped.body.transforms.l[3] + 0.1
            local lc1 = node.findNodeByName(body, 'leg1')
            local lc2 = node.findNodeByName(body, 'leg2')

            if lc1 and lc2 then
                local dx1, dy1 = body.transforms._g:transformPoint(lc1.points[1][1], lc1.points[1][2])
                e.biped.leg1.points[1] = { dx1, dy1 }
                e.biped.feet1.transforms.l[1] = e.biped.leg1.points[2][1]
                e.biped.feet1.transforms.l[2] = e.biped.leg1.points[2][2]
                e.biped.feet1.transforms.l[3] = 0
                mesh.remeshNode(e.biped.leg1)


                local dx1, dy1 = body.transforms._g:transformPoint(lc2.points[1][1], lc2.points[1][2])
                e.biped.leg2.points[1] = { dx1, dy1 }
                mesh.remeshNode(e.biped.leg2)

            end


            -- cpoy pasta
            local nc = node.findNodeByName(body, 'neck')
            local dx1, dy1 = body.transforms._g:transformPoint(nc.points[1][1], nc.points[1][2])

            e.biped.head.transforms.l[1] = dx1
            e.biped.head.transforms.l[2] = dy1
            -- end
            transforms.setTransforms(e.biped.body)
            transforms.setTransforms(e.biped.head)

        end
    end

end

return BipedSystem
