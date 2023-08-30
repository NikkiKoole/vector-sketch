package.path  = package.path .. ";../../?.lua"
local inspect = require 'vendor.inspect'

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


local creation = {
    torso = { w = 100, h = 200, d = .5, shape = 'trapezium' },
    neck = { w = 12, h = 230, d = 1, shape = 'rect2', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    head = { w = 50, h = 100, d = .1, shape = 'capsule', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    upArm = { w = 20, h = 80, d = 1, shape = 'capsule', limits = { side = 'left', low = 0, up = math.pi, enabled = false } },
    lowArm = { w = 20, h = 80, d = 1, shape = 'capsule', limits = { side = 'left', low = 0, up = math.pi - 0.5, enabled = true } },
    hand = { w = 20, h = 20, d = 2, shape = 'rect2', limits = { side = 'left', low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    upLeg = { w = 20, h = 100, d = 1, shape = 'capsule', limits = { side = 'left', low = 0, up = math.pi / 2, enabled = true } },
    lowLeg = { w = 20, h = 100, d = 1, shape = 'capsule', limits = { side = 'left', low = -math.pi / 8, up = 0, enabled = true } },
    foot = { w = 20, h = 50, d = 2, shape = 'rect1', limits = { side = 'left', low = -math.pi / 8, up = math.pi / 8, enabled = true } },
}

function getCreation()
    return creation
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
    if #result <= 1 then
        return result[1]
    end
    return nil
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
    killMouseJointIfPossible(recreatePointerJoint.id)
    table.insert(pointerJoints,
        makePointerJoint(recreatePointerJoint.id, body, recreatePointerJoint.targetX,
            recreatePointerJoint.targetY))
end

local function makeConnectingRevoluteJoint(data, this, from, optionalSide)
    local joint = love.physics.newRevoluteJoint(from, this, this:getX(), this:getY(), false)
    if data.limits then
        local needsFlipping = false
        if (optionalSide) then
            if data.limits.side then
                if (optionalSide ~= data.limits.side) then
                    needsFlipping = true
                end
            end
        end

        if needsFlipping then
            joint:setLowerLimit( -1 * data.limits.up)
            joint:setUpperLimit( -1 * data.limits.low)
        else
            joint:setLowerLimit(data.limits.low)
            joint:setUpperLimit(data.limits.up)
        end
        joint:setLimitsEnabled(data.limits.enabled)
    end
    return joint
end

local function makeGuyFixture(data, key, groupId, body, shape)
    local fixture = love.physics.newFixture(body, shape, data.d)
    fixture:setFilterData(1, 65535, -1 * groupId)
    fixture:setUserData(makeUserData(key))
    return fixture
end

local function getAngleOffset(key, side)
    if key == 'neck' then
        return math.pi
    elseif key == 'foot' then
        if side == 'left' then
            return math.pi / 2
        else
            return -math.pi / 2
        end
    end
    return 0
end

local function makePart_(cd, key, offsetX, offsetY, parent, groupId, side)
    local x, y = parent:getWorldPoint(offsetX, offsetY)

    local prevA = parent:getAngle()
    local xangle = getAngleOffset(key, side)

    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = makeShapeFromCreationPart(cd)
    local fixture = makeGuyFixture(cd, key, groupId, body, shape)

    body:setAngle(prevA + xangle)
    local joint = makeConnectingRevoluteJoint(cd, body, parent, side)

    return body
end


function getParentAndChildrenFromPartName(partName)
    local map = {
        torso = { c = { 'neck', 'luarm', 'ruarm', 'luleg', 'ruleg' } },
        neck = { p = 'torso', c = 'head' },
        head = { p = 'neck' },
        luarm = { p = 'torso', c = 'llarm', alias = 'upArm' },
        llarm = { p = 'luarm', c = 'lhand', alias = 'lowArm' },
        lhand = { p = 'llarm', alias = 'hand' },
        ruarm = { p = 'torso', c = 'rlarm', alias = 'upArm' },
        rlarm = { p = 'ruarm', c = 'rhand', alias = 'lowArm' },
        rhand = { p = 'rlarm', alias = 'hand' },
        luleg = { p = 'torso', c = 'llleg', alias = 'upLeg' },
        llleg = { p = 'luleg', c = 'lfoot', alias = 'lowLeg' },
        lfoot = { p = 'llleg', alias = 'foot' },
        ruleg = { p = 'torso', c = 'rlleg', alias = 'upLeg' },
        rlleg = { p = 'ruleg', c = 'rfoot', alias = 'lowLeg' },
        rfoot = { p = 'rlleg', alias = 'foot' }
    }
    return map[partName]
end

local function getRecreateConnectorData(allAttachedFixtures)
    local result = nil
    for i = 1, #allAttachedFixtures do
        local f = allAttachedFixtures[i]
        if f:getUserData() and f:getUserData().bodyType == 'connector' then
            for j = 1, #connectors do
                if connectors[j].at == f then
                    result = { oldFixture = f, ud = f:getUserData() }

                    return result
                end
            end

            --table.insert(connectors, { at = fixture, to = nil, joint = nil })
        end
    end
    return result
end

local function useRecreateConnectorData(recreateConnectorData, body)
    --print(recreateConnectorData.fixture) -- its broken already, just use this to find in connecto list
    --print(inspect(recreateConnectorData.ud))
    --print(inspect(recreateConnectorData.ud.data))

    makeAndReplaceConnector(recreateConnectorData, body, 0, creation.foot.h / 2, recreateConnectorData.ud.data,
        creation.foot.w * 2)
end

function genericBodyPartUpdate(box2dGuy, groupId, partName)
    -- look up who is my parent and what are my children


    local data = getParentAndChildrenFromPartName(partName)
    local parentName = data.p
    --print(partName, parentName)
    --  assert(parentName)
    --  assert(box2dGuy[parentName] and box2dGuy[partName])




    -- check if we have an attached connector here
    -- also check what the other thing attached to that connector is btw
    --print(inspect(box2dGuy[partName]:getFixtures()))

    local recreateConnectorData = getRecreateConnectorData(box2dGuy[partName]:getFixtures())

    local recreatePointerJoint = getRecreatePointerJoint(box2dGuy[partName])

    if parentName then
        local jointWithParentToBreak = findJointBetween2Bodies(box2dGuy[parentName], box2dGuy[partName])


        if jointWithParentToBreak then
            local offsetX, offsetY = getOffsetFromParent(partName)
            local hx, hy = box2dGuy[parentName]:getWorldPoint(offsetX, offsetY)
            local prevA = box2dGuy[parentName]:getAngle()
            local thisA = box2dGuy[partName]:getAngle()
            jointWithParentToBreak:destroy()

            box2dGuy[partName]:destroy()

            local createData = creation[data.alias or partName]
            local body = love.physics.newBody(world, hx, hy, "dynamic")
            local shape = makeShapeFromCreationPart(createData)
            local fixture = makeGuyFixture(createData, data.alias or partName, groupId, body, shape)


            local xangle = getAngleOffset(data.alias or partName, 'left') -- what LEFT!
            body:setAngle(prevA + xangle)



            local joint = makeConnectingRevoluteJoint(createData, body, box2dGuy[parentName])


            box2dGuy[partName] = body
            body:setAngle(thisA)

            if (recreatePointerJoint) then
                useRecreatePointerJoint(recreatePointerJoint, box2dGuy[partName])
            end

            if (recreateConnectorData) then
                useRecreateConnectorData(recreateConnectorData, box2dGuy[partName])
            end
            -- reattach children

            local childName = data.c
            if childName then
                local childData = getParentAndChildrenFromPartName(childName)
                local offsetX, offsetY = getOffsetFromParent(childName)
                local nx, ny = box2dGuy[partName]:getWorldPoint(offsetX, offsetY)
                box2dGuy[childName]:setPosition(nx, ny)
                box2dGuy[childName]:setAngle(thisA)
                local joint = makeConnectingRevoluteJoint(creation[childData.alias or childName], box2dGuy[childName],
                        box2dGuy[partName])
            end
        end
    end


    --local jointToBreak = findJointBetween2Bodies(box2dGuy.neck, box2dGuy.head)
    --local recreatePointerJoint = getRecreatePointerJoint(box2dGuy.head)
end

function getOffsetFromParent(partName)
    local data = getParentAndChildrenFromPartName(partName)

    if partName == 'neck' then
        return 0, -creation.torso.h / 2
    elseif partName == 'luarm' then
        return -creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'ruarm' then
        return creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'luleg' then
        return -creation.torso.w / 2, creation.torso.h / 2
    elseif partName == 'ruleg' then
        return creation.torso.w / 2, creation.torso.h / 2
    else
        local p = data.p
        -- now look for the alias of the parent...
        local temp = getParentAndChildrenFromPartName(p)
        local part = temp.alias or p
        return 0, creation[part].h
    end
end

function makeGuy(x, y, groupId)
    local function makePart(name, key, parent, side)
        -- needed to wrap groupid
        local data = getParentAndChildrenFromPartName(name)
        local creationName = data.alias or name
        local offsetX, offsetY = getOffsetFromParent(name)
        return makePart_(creation[creationName], key, offsetX, offsetY, parent, groupId, side)
    end


    local torso = love.physics.newBody(world, x, y, "dynamic")
    local torsoShape = makeShapeFromCreationPart(creation.torso)
    local fixture = makeGuyFixture('torso', 'torso', groupId, torso, torsoShape)

    getOffsetFromParent('llarm')
    local neck = makePart('neck', 'neck', torso)
    local head = makePart('head', 'head', neck)

    local luleg = makePart('luleg', 'legpart', torso, 'left')
    local llleg = makePart('llleg', 'legpart', luleg, 'left')
    local lfoot = makePart('lfoot', 'foot', llleg, 'left')

    makeAndAddConnector(lfoot, 0, creation.foot.h / 2, { id = 'guy' .. groupId, type = 'foot' }, creation.foot.w * 2)

    local ruleg = makePart('ruleg', 'legpart', torso, 'right')
    local rlleg = makePart('rlleg', 'legpart', ruleg, 'right')
    local rfoot = makePart('rfoot', 'foot', rlleg, 'right')

    makeAndAddConnector(rfoot, 0, creation.foot.h / 2, { id = 'guy' .. groupId, type = 'foot' }, creation.foot.w * 2)


    local ruarm = makePart('ruarm', 'armpart', torso, 'right')
    local rlarm = makePart('rlarm', 'armpart', ruarm, 'right')
    local rhand = makePart('rhand', 'hand', rlarm, 'right')

    local luarm = makePart('luarm', 'armpart', torso, 'left')
    local llarm = makePart('llarm', 'armpart', luarm, 'left')
    local lhand = makePart('lhand', 'hand', llarm, 'left')

    local data = {
        torso = torso,
        neck = neck,
        head = head,
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
    }
    return data
end
