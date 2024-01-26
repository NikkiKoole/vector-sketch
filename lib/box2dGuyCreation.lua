package.path  = package.path .. ";../../?.lua"
local bbox    = require 'lib.bbox'
local inspect = require 'vendor.inspect'
local phys    = require 'lib.mainPhysics'
local dna     = require 'lib.dna'

local lib     = {}

-- todo make helper that creates symmetrical data for legs, arms, hand, feet and ears


local function getParentAndChildrenFromPartName(partName, guy)
    local creation = guy.dna.creation

    local map      = {
        torso = { c = { 'neck', 'luarm', 'ruarm', 'luleg', 'ruleg' } },
        neck = { p = 'torso', c = 'neck1' },
        neck1 = { p = 'neck', c = 'head' },
        head = { p = 'neck1', c = { 'lear', 'rear', 'hair1', 'hair2', 'hair3', 'hair4', 'hair5' } },
        hair1 = { p = 'head' },
        hair2 = { p = 'head' },
        hair3 = { p = 'head' },
        hair4 = { p = 'head' },
        hair5 = { p = 'head' },
        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = 'torso', c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = 'torso', c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = 'torso', c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = 'torso', c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' }
    }

    if creation and partName == 'head' and creation.hasNeck == false then
        return { p = 'torso', c = { 'lear', 'rear', 'hair1', 'hair2', 'hair3', 'hair4', 'hair5' } }
    end

    if creation and partName == 'torso' and creation.isPotatoHead then
        return { c = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear', 'hair1', 'hair2', 'hair3', 'hair4', 'hair5' } }
    end
    if creation and partName == 'torso' and creation.hasNeck == false then
        return { c = { 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' } }
    end

    local result = map[partName]

    if result.p == 'head' and creation.isPotatoHead then
        result.p = 'torso'
    end
    return map[partName]
end

local function getScaledTorsoMetaPoint(index, guy)
    local creation = guy.dna.creation
    local wscale = creation.torso.w / creation.torso.metaPointsW
    local hscale = creation.torso.h / creation.torso.metaPointsH

    return creation.torso.metaPoints[index][1] * wscale, creation.torso.metaPoints[index][2] * hscale
end

local function getScaledHeadMetaPoint(index, guy)
    local creation = guy.dna.creation
    local wscale = creation.head.w / creation.head.metaPointsW
    local hscale = creation.head.h / creation.head.metaPointsH

    if creation.head.metaOffsetX or creation.head.metaOffsetY then
        return (creation.head.metaPoints[index][1] + creation.head.metaOffsetX) * wscale,
            (creation.head.metaPoints[index][2] + creation.head.metaOffsetY) * hscale
    end
    return creation.head.metaPoints[index][1] * wscale, creation.head.metaPoints[index][2] * hscale
end

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end

local function lerp(a, b, amount)
    return a + (b - a) * clamp(amount, 0, 1)
end

local function getOffsetFromParent(partName, guy)
    local creation    = guy.dna.creation
    local positioners = guy.dna.positioners
    local data        = getParentAndChildrenFromPartName(partName, guy)



    if partName == 'neck' then
        if creation.torso.metaPoints then
            return getScaledTorsoMetaPoint(1, guy)
        end

        return 0, -creation.torso.h / 2
    elseif partName == 'luarm' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(7, guy)
            end
        else
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(8, guy)
            end
        end
        return -creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'ruarm' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(3, guy)
            end
        else
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(2, guy)
            end
        end
        return creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'luleg' then
        local t = positioners.leg.x
        if creation.torso.metaPoints then
            local ax, ay = getScaledTorsoMetaPoint(6, guy)
            local bx, by = getScaledTorsoMetaPoint(5, guy)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        end
        return ( -creation.torso.w / 2) * (1 - t), creation.torso.h / 2
    elseif partName == 'ruleg' then
        local t = positioners.leg.x
        if creation.torso.metaPoints then
            local ax, ay = getScaledTorsoMetaPoint(4, guy)
            local bx, by = getScaledTorsoMetaPoint(5, guy)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        end
        return (creation.torso.w / 2) * (1 - t), creation.torso.h / 2
    elseif partName == 'hair1' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(3, guy)
        end
    elseif partName == 'hair2' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(4, guy)
        end
    elseif partName == 'hair3' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(5, guy)
        end
    elseif partName == 'hair4' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(6, guy)
        end
    elseif partName == 'hair5' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(7, guy)
        end
    elseif partName == 'lear' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                local t = positioners.ear.y
                local ax, ay = getScaledTorsoMetaPoint(8, guy)
                local bx, by = getScaledTorsoMetaPoint(7, guy)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

                return rx, ry
            end
        else
            if creation.head.metaPoints then
                local t = positioners.ear.y
                local ax, ay = getScaledHeadMetaPoint(8, guy)
                local bx, by = getScaledHeadMetaPoint(6, guy)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

                return rx, ry
            end
        end

        return -creation.head.w / 2, -creation.head.h / 2
    elseif partName == 'rear' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                local t = positioners.ear.y
                local ax, ay = getScaledTorsoMetaPoint(2, guy)
                local bx, by = getScaledTorsoMetaPoint(3, guy)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

                return rx, ry
            end
        else
            if creation.head.metaPoints then
                local t = positioners.ear.y
                local ax, ay = getScaledHeadMetaPoint(2, guy)
                local bx, by = getScaledHeadMetaPoint(4, guy)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

                return rx, ry
            end
        end
        return creation.head.w / 2, -creation.head.h / 2
    else
        if (partName == 'head') then
            if creation.hasNeck then
                return 0, creation.neck1.h / (creation.neck1.links or 1)
            else
                if creation.torso.metaPoints then
                    return getScaledTorsoMetaPoint(1, guy)
                end

                return 0, -creation.torso.h / 2
            end
        end

        local p = data.p
        -- now look for the alias of the parent...
        local temp = getParentAndChildrenFromPartName(p, guy)
        local part = p
        --  local s = canvas.getShrinkFactor()
        -- wscale = wscale * s
        --  hscale = hscale * s
        return 0, creation[part].h --/ s
    end
end

local function getAngleOffset(key, creation, data)
    if key == 'neck' then
        return -math.pi
    elseif key == 'neck1' then
        return 0
    elseif key == 'lear' then
        return creation.lear.stanceAngle
    elseif key == 'rear' then
        return creation.rear.stanceAngle
    elseif key == 'lfoot' then
        --print('hello', inspect(data.facing))
        if data.facing.legs == 'right' then
            return -math.pi / 2
        end
        return math.pi / 2
    elseif key == 'rfoot' then
        if data.facing.legs == 'left' then
            return math.pi / 2
        end
        return -math.pi / 2
    elseif (key == 'hair1') then
        return -math.pi / 2
    elseif (key == 'hair2') then
        return -math.pi / 4
    elseif (key == 'hair3') then
        return 0
    elseif (key == 'hair4') then
        return math.pi / 4
    elseif (key == 'hair5') then
        return math.pi / 2
    elseif (key == 'luleg') then
        if data.facing.legs == 'right' then
            return creation.ruleg.stanceAngle
        end
        return creation.luleg.stanceAngle
    elseif (key == 'llleg') then
        if data.facing.legs == 'right' then
            return creation.rlleg.stanceAngle
        end
        return creation.llleg.stanceAngle
    elseif (key == 'ruleg') then
        if data.facing.legs == 'left' then
            return creation.luleg.stanceAngle
        end
        return creation.ruleg.stanceAngle
    elseif (key == 'rlleg') then
        if data.facing.legs == 'left' then
            return creation.llleg.stanceAngle
        end
        return creation.rlleg.stanceAngle
    elseif key == 'head' then
        if (not creation.hasNeck) then
            return 0
        else
            return math.pi
        end
        return 0
    else
        --  print('??', key)
    end
    return 0
end

local function makePointerJoint(id, bodyToAttachTo, wx, wy)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(0.5)
    pointerJoint.joint:setMaxForce(500000)
    return pointerJoint
end

local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

local function tableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function findJointBetween2Bodies(body1, body2)
    local joints1 = body1:getJoints()
    local joints2 = body2:getJoints()

    local result = {}
    for i = 1, #joints2 do
        if tableContains(joints1, joints2[i]) then
            table.insert(result, joints2[i])
        end
    end

    return result
end

local function setJointLimitBetweenBodies(body1, body2, state, ofType)
    local joints = findJointBetween2Bodies(body1, body2)
    if joints then
        for i = 1, #joints do
            --     print(joints[i]:getType())
            if ofType == nil or joints[i]:getType() == ofType then
                joints[i]:setLimitsEnabled(state)
            end
        end
    end
end

local function getRecreatePointerJoint(body)
    local recreatePointerJoint = nil
    for i = 1, #pointerJoints do
        if (pointerJoints[i].jointBody == body) then
            local tx, ty = pointerJoints[i].joint:getTarget()
            x1, y1, x2, y2 = pointerJoints[i].joint:getAnchors()
            recreatePointerJoint = { targetX = x2, targetY = y2, id = pointerJoints[i].id }
        end
    end
    return recreatePointerJoint
end

local function useRecreatePointerJoint(recreatePointerJoint, body)
    phys.killMouseJointIfPossible(recreatePointerJoint.id)
    table.insert(pointerJoints,
        makePointerJoint(recreatePointerJoint.id, body, recreatePointerJoint.targetX,
            recreatePointerJoint.targetY))
end

local function makeConnectingRevoluteJoint(data, this, from)
    local joint = love.physics.newRevoluteJoint(from, this, this:getX(), this:getY(), false)

    local n = data.partName
    local myData = data.creation[data.partName]
    if (data.facing.legs == 'right') then
        if n == 'luleg' then
            myData = data.creation['ruleg']
        end
        if n == 'llleg' then
            myData = data.creation['rlleg']
        end
        if n == 'lfoot' then
            myData = data.creation['rfoot']
        end
    end
    if (data.facing.legs == 'left') then
        if n == 'ruleg' then
            myData = data.creation['luleg']
        end
        if n == 'rlleg' then
            myData = data.creation['llleg']
        end
        if n == 'rfoot' then
            myData = data.creation['lfoot']
        end
    end





    if myData.limits then
        joint:setLowerLimit(myData.limits.low)
        joint:setUpperLimit(myData.limits.up)
        joint:setLimitsEnabled(myData.limits.enabled)
    end

    if myData.friction then
        local fjoint = love.physics.newFrictionJoint(from, this, this:getX(), this:getY(), false)
        fjoint:setMaxTorque(myData.friction)
    end
    return joint
end

local function makeGuyFixture(data, key, groupId, body, shape)
    local fixture = love.physics.newFixture(body, shape, data.d)
    if (string.match(key, 'hair')) then
        -- hair does not collide
        fixture:setFilterData(0, 65535, -1 * groupId)
    else
        fixture:setFilterData(1, 65535, -1 * groupId)
    end

    local fixedKey = key
    if string.match(key, 'neck') then
        fixedKey = 'neck'
    end

    fixture:setUserData(makeUserData(fixedKey))
    return fixture
end

local function makePart_(key, parent, guy)
    local groupId = guy.id
    local creation = guy.dna.creation -- dna.getCreation()
    local facing = guy.facingVars
    local offsetX, offsetY = getOffsetFromParent(key, guy)
    local cd = creation[key]
    local x, y = parent:getWorldPoint(offsetX, offsetY)
    local prevA = parent:getAngle()

    local data = { creation = creation, partName = key, facing = facing }
    local xangle = getAngleOffset(key, creation, data)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = phys.makeShapeFromCreationPart(cd)
    local fixture = makeGuyFixture(cd, key, groupId, body, shape)

    body:setAngle(prevA + xangle)

    local joint = makeConnectingRevoluteJoint(data, body, parent)

    return body
end

local function makeAndReplaceConnector(recreate, parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = phys.makeRectPoly2(size, size, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 1)

    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)

    -- we are remaking a connector, keep all its connections working here!
    for i = 1, #connectors do
        if connectors[i].at and connectors[i].at == recreate.oldFixture then
            connectors[i].at = fixture
            if connectors[i].to then
                local j = phys.getJointBetween2Connectors(connectors[i].to, connectors[i].at)
                connectors[i].joint = j
            end
        end

        if connectors[i].to and connectors[i].to == recreate.oldFixture then
            connectors[i].to = fixture

            local j = phys.getJointBetween2Connectors(connectors[i].to, connectors[i].at)
            connectors[i].joint = j
        end
    end
end

local function getRecreateConnectorData(allAttachedFixtures)
    local result = nil
    for i = 1, #allAttachedFixtures do
        local f = allAttachedFixtures[i]
        if f:getUserData() and f:getUserData().bodyType == 'connector' then
            for j = 1, #connectors do
                if connectors[j].at == f then
                    result = { oldFixture = f, userData = f:getUserData() }
                    return result
                end
            end
        end
    end
    return result
end

local function useRecreateConnectorData(recreateConnectorData, body, guy)
    local creation = guy.dna.creation
    local data = recreateConnectorData.userData.data
    local type = data.type
    assert(type)
    if type == 'foot' then
        makeAndReplaceConnector(recreateConnectorData, body, 0, creation.foot.h / 2, data,
            creation.foot.w + 10,
            creation.foot.h + 10)
    elseif type == 'hand' then
        makeAndReplaceConnector(recreateConnectorData, body, 0, creation.lhand.h / 2, data, creation.lhand.w,
            creation.lhand.h)
        -- elseif type == 'rhand' then
        --     makeAndReplaceConnector(recreateConnectorData, body, 0, creation.rhand.h / 2, data, creation.rhand.w * 2)
    end
end


local function makeAndAddConnector(parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = phys.makeRectPoly2(size, size2, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 0)
    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)
    table.insert(connectors, { at = fixture, to = nil, joint = nil })
    --print('jo hello!', #connectors)
end

lib.makeGuy = function(x, y, guy)
    local creation = guy.dna.creation
    local groupId = guy.id

    local function makePart(name, parent)
        return makePart_(name, parent, guy)
    end


    local torso = love.physics.newBody(world, x, y, "dynamic")
    local torsoShape = phys.makeShapeFromCreationPart(creation.torso)
    local fixture = makeGuyFixture('torso', 'torso', groupId, torso, torsoShape)

    local head, neck, neck1, lear, rear
    if creation.isPotatoHead then
        lear = makePart('lear', torso)
        rear = makePart('rear', torso)
    else
        if creation.hasNeck then
            neck = makePart('neck', torso)
            neck1 = makePart('neck1', neck)
            head = makePart('head', neck1)
        else
            head = makePart('head', torso)
        end
        lear = makePart('lear', head)
        rear = makePart('rear', head)
    end

    local hair1, hair2, hair3, hair4, hair5
    if creation.hasPhysicsHair then
        local attachTo = creation.isPotatoHead and torso or head
        hair1 = makePart('hair1', attachTo)
        hair2 = makePart('hair2', attachTo)
        hair3 = makePart('hair3', attachTo)
        hair4 = makePart('hair4', attachTo)
        hair5 = makePart('hair5', attachTo)
    end

    local luleg = makePart('luleg', torso)
    local llleg = makePart('llleg', luleg)

    local lfoot = makePart('lfoot', llleg)
    local ruleg = makePart('ruleg', torso)
    local rlleg = makePart('rlleg', ruleg)
    local rfoot = makePart('rfoot', rlleg)
    local ruarm = makePart('ruarm', torso)
    local rlarm = makePart('rlarm', ruarm)
    local rhand = makePart('rhand', rlarm)

    local handConnector = true
    if handConnector then
        makeAndAddConnector(rhand, 0, creation.rhand.h / 2, { id = 'guy' .. groupId, type = 'hand' },
            creation.rhand.h / 2 + 10,
            creation.rhand.w / 2 + 10)
    end

    local luarm = makePart('luarm', torso)
    local llarm = makePart('llarm', luarm)
    local lhand = makePart('lhand', llarm)
    if handConnector then
        makeAndAddConnector(lhand, 0, creation.lhand.h / 2, { id = 'guy' .. groupId, type = 'hand' },
            creation.lhand.h + 10,
            creation.lhand.w + 10)
    end

    local fixtures = lhand:getFixtures()
    -- print('lhand has', #fixtures, 'fxitrues')
    for _, fixture in ipairs(fixtures) do
        if fixture:getUserData() then
            -- print(inspect(fixture:getUserData()))
        end
    end


    local data = {
        torso = torso,
        neck = neck,
        neck1 = neck1,
        head = head,
        lear = lear,
        rear = rear,
        luarm = luarm,
        llarm = llarm,
        lhand = lhand,
        ruarm = ruarm,
        rlarm = rlarm,
        rhand = rhand,
        luleg = luleg,
        llleg = llleg,
        lfoot = lfoot,
        ruleg = ruleg,
        rlleg = rlleg,
        rfoot = rfoot,
        hair1 = hair1,
        hair2 = hair2,
        hair3 = hair3,
        hair4 = hair4,
        hair5 = hair5
    }
    return data
end

local function rotateToHorizontal(body, desiredAngle, divider, pr)
    local DEGTORAD = 1 / 57.295779513
    --https://www.iforce2d.net/b2dtut/rotate-to-angle
    if true then
        local angle = body:getAngle()
        local a = angle


        local angularVelocity = body:getAngularVelocity()
        local inertia = body:getInertia()
        local didSomething = false
        if false then
            if false then
                while a > (2 * math.pi) do
                    a = a - (2 * math.pi)
                    body:setAngle(a)
                    --                    print('getting in first one', a, angle)
                    didSomething = true
                end
                while a < -(2 * math.pi) do
                    a = a + (2 * math.pi)
                    body:setAngle(a)
                    --                    print('getting in second one')
                    didSomething = true
                end
            end
        end
        if didSomething then
            --            print('jo')
            return
        end
        angle = a -- body:getAngle()
        local nextAngle = angle + angularVelocity / divider
        local totalRotation = desiredAngle - nextAngle

        while (totalRotation < -180 * DEGTORAD) do
            totalRotation = totalRotation + 360 * DEGTORAD
        end
        while (totalRotation > 180 * DEGTORAD) do
            totalRotation = totalRotation - 360 * DEGTORAD
        end

        local desiredAngularVelocity = (totalRotation * divider)
        --local impulse = body:getInertia() * desiredAngularVelocity
        -- body:applyAngularImpulse(impulse)

        local torque = inertia * desiredAngularVelocity / (1 / divider)
        body:applyTorque(torque)
    end
end

local function getRidOfBigRotationsInBody(body)
    --local angle = body:getAngle()
    --if angle > 0 then
    --    body:setAngle(angle % (2 * math.pi))
    --else
    --    body:setAngle(angle % ( -2 * math.pi))
    --end
    local a = body:getAngle()
    if false then
        while a > (2 * math.pi) do
            a = a - (2 * math.pi)
            body:setAngle(a)
        end
        while a < -(2 * math.pi) do
            a = a + (2 * math.pi)
            body:setAngle(a)
        end
    end
end

lib.rotateAllBodies = function(bodies, dt)
    -- I want to be able to rotate all bodies in one go.
    -- This means I cannot fetch the guy with its creation here.
    -- So that means the creation below , which is used for some stance-angles, this needs another solution.
    -- probably data in userData on thos limbs...

    -- for now i will just assume the same data for all.

    local creation = dna.getCreation()
    -- local upsideDown = false
    lastDt = dt
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()


        local isBeingPointerJointed = false
        for j = 1, #pointerJoints do
            local mj = pointerJoints[j]
            if mj.jointBody == body then
                isBeingPointerJointed = true
            end
        end
        for _, fixture in ipairs(fixtures) do
            if isBeingPointerJointed then
                --     getRidOfBigRotationsInBody(body)
            end
            local userData = fixture:getUserData()
            if (userData) then
                -- print(userData.bodyType)
                if userData.bodyType == 'keep-rotation' then
                    --  print(inspect(userData))
                    rotateToHorizontal(body, userData.data.rotation, 50)
                end
            end


            if (jointsEnabled) and not isBeingPointerJointed then
                --local userData = fixture:getUserData()



                if userData then
                    -- getRidOfBigRotationsInBody(body)
                    -- print(userData.bodyType)
                    if userData.bodyType == 'balloon' then
                        --getRidOfBigRotationsInBody(body)
                        --local desired = upsideDown and -math.pi or 0
                        --rotateToHorizontal(body, desired, 50)
                        local up = -9.81 * love.physics.getMeter() * 2.5 --4.5

                        body:applyForce(0, up)
                    end
                    --print(userData.bodyType)
                    --if not upsideDown then
                    --    if userData.bodyType == 'lfoot' or userData.bodyType == 'rfoot' then
                    --        getRidOfBigRotationsInBody(body)
                    --    end
                    --end


                    if userData.bodyType == 'lear' then
                        -- getRidOfBigRotationsInBody(body)
                        -- rotateToHorizontal(body, math.pi / 2, 25)
                    end
                    if userData.bodyType == 'rear' then
                        -- getRidOfBigRotationsInBody(body)
                        -- rotateToHorizontal(body, -math.pi / 2, 25)
                    end


                    if userData.bodyType == 'hand' then
                        -- getRidOfBigRotationsInBody(body)
                    end
                    if userData.bodyType == 'hand' then
                        --   getRidOfBigRotationsInBody(body)
                    end
                    if userData.bodyType == 'torso' then
                        getRidOfBigRotationsInBody(body)
                        local desired = upsideDown and -math.pi or 0

                        rotateToHorizontal(body, desired, 25)
                    end

                    if not upsideDown then
                        if userData.bodyType == 'neck1' then
                            getRidOfBigRotationsInBody(body)
                            --  -- rotateToHorizontal(body, -math.pi, 40)
                            --rotateToHorizontal(body, 0, 10)
                            rotateToHorizontal(body, -math.pi, 15)
                        end
                        if userData.bodyType == 'neck' then
                            getRidOfBigRotationsInBody(body)
                            -- rotateToHorizontal(body, -math.pi, 40)
                            --rotateToHorizontal(body, 0, 10)
                            rotateToHorizontal(body, -math.pi, 15)
                        end

                        if userData.bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)
                            --rotateToHorizontal(body, -math.pi, 15)

                            --  print(body:getAngle())
                            rotateToHorizontal(body, 0, 15)
                        end
                    end

                    if not upsideDown then
                        if userData.bodyType == 'luleg' then
                            local a = creation.luleg.stanceAngle
                            --  print(a)
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'ruleg' then
                            local a = creation.ruleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'llleg' then
                            local a = creation.llleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                        if userData.bodyType == 'rlleg' then
                            local a = creation.rlleg.stanceAngle
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, a, 30)
                        end
                    end
                    if upsideDown then
                        if userData.bodyType == 'luarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'llarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'ruarm' then
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if userData.bodyType == 'rlarm' then
                            -- print('doing stuff!')
                            --getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        -- if userData.bodyType == 'legpart' then
                        --getRidOfBigRotationsInBody(body)
                        --rotateToHorizontal(body, math.pi, 10)
                        -- end
                    end

                    if false then
                        if userData.bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)

                            rotateToHorizontal(body, math.pi, 15)
                        end
                    end
                end
            end
        end
    end
end

lib.genericBodyPartUpdate = function(guy, partName)
    local groupId = guy.id
    local box2dGuy = guy.b2d
    local creation = guy.dna.creation
    local facing = guy.facingVars
    local data = getParentAndChildrenFromPartName(partName, guy)
    local parentName = data.p
    local recreateConnectorData = getRecreateConnectorData(box2dGuy[partName]:getFixtures())
    --  print(recreateConnectorData)
    local recreatePointerJoint = getRecreatePointerJoint(box2dGuy[partName])
    local thisA = box2dGuy[partName]:getAngle()

    if parentName then
        local jointWithParentToBreak = findJointBetween2Bodies(box2dGuy[parentName], box2dGuy[partName])

        if jointWithParentToBreak then
            local offsetX, offsetY = getOffsetFromParent(partName, guy)
            local hx, hy = box2dGuy[parentName]:getWorldPoint(offsetX, offsetY)
            local prevA = box2dGuy[parentName]:getAngle()
            for i = 1, #jointWithParentToBreak do
                jointWithParentToBreak[i]:destroy()
            end
            box2dGuy[partName]:destroy()

            local createData = creation[partName]
            local body = love.physics.newBody(world, hx, hy, "dynamic")
            local shape = phys.makeShapeFromCreationPart(createData)
            local fixture = makeGuyFixture(createData, partName, groupId, body, shape)
            local data = { creation = creation, partName = partName, facing = facing }
            local xangle = getAngleOffset(partName, creation, data)
            body:setAngle(prevA + xangle)



            local joint = makeConnectingRevoluteJoint(data, body, box2dGuy[parentName])

            box2dGuy[partName] = body
            body:setAngle(thisA)
        end
    end

    if not parentName or partName == 'torso' then
        local aa = box2dGuy[partName]:getAngle()
        local hx, hy = box2dGuy[partName]:getWorldPoint(0, 0)
        box2dGuy[partName]:destroy()
        local createData = creation[partName]
        local body = love.physics.newBody(world, hx, hy, "dynamic")
        local shape = phys.makeShapeFromCreationPart(createData)
        local fixture = makeGuyFixture(createData, partName, groupId, body, shape)
        box2dGuy[partName] = body
        box2dGuy[partName]:setAngle(aa)
    end

    if (recreatePointerJoint) then
        useRecreatePointerJoint(recreatePointerJoint, box2dGuy[partName])
    end

    if (recreateConnectorData) then
        useRecreateConnectorData(recreateConnectorData, box2dGuy[partName], guy)
    end
    -- reattach children


    local function reAttachChild(childName)
        local offsetX, offsetY = getOffsetFromParent(childName, guy)
        local nx, ny = box2dGuy[partName]:getWorldPoint(offsetX, offsetY)
        box2dGuy[childName]:setPosition(nx, ny)
        local aa = box2dGuy[childName]:getAngle()
        local data = { creation = creation, partName = childName, facing = facing }
        local xangle = getAngleOffset(childName, creation, data) -- what LEFT!

        box2dGuy[childName]:setAngle(thisA + xangle)


        local joint = makeConnectingRevoluteJoint(data, box2dGuy[childName],
                box2dGuy[partName])
        box2dGuy[childName]:setAngle(aa)
    end


    local childName = data.c
    if childName and (type(childName) == 'string') then
        reAttachChild(childName)
    end
    if childName and (type(childName) == 'table') then
        for i = 1, #childName do
            local skip = false
            if creation.isPotatoHead and childName[i] == 'neck' then
                skip = true
            end
            if not creation.hasPhysicsHair and string.match(childName[i], 'hair') then
                skip = true
            end

            if not skip then
                reAttachChild(childName[i])
            end
        end
    end
end

lib.handlePhysicsHairOrNo = function(box2dGuy, guy, hair)
    local creation = guy.dna.creation
    -- local groupId = guy.id
    -- we need to find out if we can leave early..
    if hair and box2dGuy.hair1 then return end
    if not hair and not box2dGuy.hair1 then return end
    local function makePart(name, parent)
        return makePart_(name, parent, guy)
    end

    if not hair then
        box2dGuy.hair1:destroy()
        box2dGuy.hair2:destroy()
        box2dGuy.hair3:destroy()
        box2dGuy.hair4:destroy()
        box2dGuy.hair5:destroy()
        box2dGuy.hair1 = nil
        box2dGuy.hair2 = nil
        box2dGuy.hair3 = nil
        box2dGuy.hair4 = nil
        box2dGuy.hair5 = nil
    else
        local attachTo = creation.isPotatoHead and box2dGuy.torso or box2dGuy.head
        local hair1 = makePart('hair1', attachTo)
        local hair2 = makePart('hair2', attachTo)
        local hair3 = makePart('hair3', attachTo)
        local hair4 = makePart('hair4', attachTo)
        local hair5 = makePart('hair5', attachTo)
        box2dGuy.hair1 = hair1
        box2dGuy.hair2 = hair2
        box2dGuy.hair3 = hair3
        box2dGuy.hair4 = hair4
        box2dGuy.hair5 = hair5
    end
end

lib.handleNeckAndHeadForHasNeck = function(box2dGuy, guy, willHaveNeck)
    local groupId = guy.id
    --if not willHaveNeck and box2dGuy.neck == nil
    --if creation.isPotatoHead then return end
    --print(box2dGuy.isPotatoHead)
    local function makePart(name, parent)
        return makePart_(name, parent, guy)
    end

    if not willHaveNeck then
        if (box2dGuy.neck) then
            box2dGuy.neck:destroy()
        end
        if (box2dGuy.neck1) then
            box2dGuy.neck1:destroy()
        end
        if (box2dGuy.head) then
            box2dGuy.head:destroy()
        end
        box2dGuy.neck = nil
        box2dGuy.neck1 = nil
        local torso = box2dGuy.torso
        local head = makePart('head', torso)
        box2dGuy.head = head
    else
        -- if not  box2dGuy.isPotatoHead then
        if box2dGuy.head then
            box2dGuy.head:destroy()
        end
        local torso = box2dGuy.torso
        local neck = makePart('neck', torso)
        local neck1 = makePart('neck1', neck)
        local head = makePart('head', neck1)
        box2dGuy.neck = neck
        box2dGuy.neck1 = neck1
        box2dGuy.head = head
        -- end
    end
end

lib.handleNeckAndHeadForPotato = function(box2dGuy, guy, willBePotato, hasNeck)
    local groupId = guy.id
    if willBePotato and box2dGuy.head == nil or not willBePotato and box2dGuy.head then
        return
    end

    local function makePart(name, parent)
        return makePart_(name, parent, guy)
    end

    if willBePotato then
        if (box2dGuy.neck) then
            box2dGuy.neck:destroy()
        end
        if (box2dGuy.neck1) then
            box2dGuy.neck1:destroy()
        end
        box2dGuy.head:destroy()
        box2dGuy.lear:destroy()
        box2dGuy.rear:destroy()
        box2dGuy.lear = nil
        box2dGuy.rear = nil
        box2dGuy.neck = nil
        box2dGuy.neck1 = nil
        box2dGuy.head = nil

        local torso = box2dGuy.torso
        local lear = makePart('lear', torso)
        local rear = makePart('rear', torso)
        box2dGuy.lear = lear
        box2dGuy.rear = rear
    else
        -- destroy ears from torso
        box2dGuy.lear:destroy()
        box2dGuy.rear:destroy()

        local torso = box2dGuy.torso
        local neck
        local neck1

        if hasNeck then
            neck = makePart('neck', torso)
            neck1 = makePart('neck1', neck)
        end

        local head = makePart('head', hasNeck and neck1 or torso)
        local lear = makePart('lear', head)
        local rear = makePart('rear', head)

        box2dGuy.lear = lear
        box2dGuy.rear = rear
        box2dGuy.neck = neck
        box2dGuy.neck1 = neck1
        box2dGuy.head = head
    end
end

lib.toggleAllJointLimits = function(guy, value)
    local creation = guy.dna.creation
    local b2d = guy.b2d
    if not creation.isPotatoHead and creation.hasNeck then
        setJointLimitBetweenBodies(b2d.head, b2d.neck1, value, 'revolute')
        setJointLimitBetweenBodies(b2d.neck1, b2d.neck, value, 'revolute')
        setJointLimitBetweenBodies(b2d.neck, b2d.torso, value, 'revolute')
    end
    setJointLimitBetweenBodies(b2d.torso, b2d.luleg, value, 'revolute')
    setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, value, 'revolute')
    setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, value, 'revolute')
    setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, value, 'revolute')
end

lib.isNullObject = function(partName, values)
    local p = findPart(partName)
    local url = p.imgs[values[partName].shape]
    return url == 'assets/parts/null.png'
end


lib.changeMetaPoints = function(key, guy, value, data)
    local creation = guy.dna.creation
    creation[key].metaPoints = value

    local tlx, tly, brx, bry = bbox.getPointsBBox(value)
    local bbw = (brx - tlx)
    local bbh = (bry - tly)

    creation[key].metaPointsW = bbw
    creation[key].metaPointsH = bbh

    if key == 'head' then
        creation[key].metaOffsetX = value[1][1]
        creation[key].metaOffsetY = value[1][2]
    end
    if key == 'torso' then
        creation[key].metaOffsetX = 0
        creation[key].metaOffsetY = 0
    end
end

lib.changeMetaTexture = function(key, guy, data)
    local creation                   = guy.dna.creation
    local tlx, tly, brx, bry         = bbox.getPointsBBox(data.texturePoints)
    local bbw                        = (brx - tlx)
    local bbh                        = (bry - tly)

    creation[key].metaURL            = data.url
    creation[key].metaTexturePoints  = data.texturePoints
    creation[key].metaTexturePointsW = bbw
    creation[key].metaTexturePointsH = bbh
    creation[key].metaPivotX         = data.pivotX
    creation[key].metaPivotY         = data.pivotY
end

lib.getFlippedMetaObject = function(flipx, flipy, points)
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




return lib
