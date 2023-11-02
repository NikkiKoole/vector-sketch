package.path  = package.path .. ";../../?.lua"
local bbox    = require 'lib.bbox'
local inspect = require 'vendor.inspect'




-- todo make helper that creates symmetrical data for legs, arms, hand, feet and ears
local creation = {
    isPotatoHead = false, -- if true then in dont have a neck or head
    hasPhysicsHair = false,
    hasNeck = true,
    torso = { flipx = 1, flipy = 1, w = 300, h = 300, d = 2.15, shape = 'trapezium' },
    neck = { w = 140, h = 150, d = 1, shape = 'capsule', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    neck1 = { w = 140, h = 110, d = 1, shape = 'capsule', limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    head = { flipx = 1, flipy = 1, w = 100, h = 200, d = 1, shape = 'capsule', limits = { low = -math.pi / 4, up = math.pi / 4, enabled = true } },
    --ear = { w = 100, h = 100, d = .1, shape = 'capsule', stanceAngle = math.pi, limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    lear = { w = 100, h = 100, d = .1, shape = 'capsule', stanceAngle = math.pi / 2, limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    rear = { w = 100, h = 100, d = .1, shape = 'capsule', stanceAngle = -math.pi / 2, limits = { low = -math.pi / 16, up = math.pi / 16, enabled = true } },
    --upArm = { w = 40, h = 280, d = 2.5, shape = 'capsule', limits = { side = 'left', low = 0, up = math.pi, enabled = false }, friction = 4000 },
    luarm = { w = 40, h = 280, d = 2.5, shape = 'capsule', limits = { low = 0, up = math.pi, enabled = false }, friction = 4000 },
    ruarm = { w = 40, h = 280, d = 2.5, shape = 'capsule', limits = { low = -math.pi, up = 0, enabled = false }, friction = 4000 },
    llarm = { w = 40, h = 160, d = 2.5, shape = 'capsule', limits = { low = 0, up = math.pi - 0.5, enabled = false }, friction = 2000 },
    rlarm = { w = 40, h = 160, d = 2.5, shape = 'capsule', limits = { low = (math.pi - 0.5) * -1, up = 0, enabled = false }, friction = 2000 },
    --lowArm = { w = 40, h = 160, d = 2.5, shape = 'capsule', limits = { side = 'left', low = 0, up = math.pi - 0.5, enabled = false }, friction = 2000 },
    --hand = { w = 40, h = 40, d = 2, shape = 'rect2', limits = { side = 'left', low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    lhand = { w = 40, h = 40, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    rhand = { w = 40, h = 40, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    luleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = 0, up = math.pi / 2, enabled = true } },
    ruleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = -math.pi / 2, up = 0, enabled = true } },
    --upLeg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { side = 'left', low = 0, up = math.pi / 2, enabled = true } },


    llleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = -math.pi / 8, up = 0, enabled = true } },
    rlleg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { low = 0, up = math.pi / 8, enabled = true } },
    --lowLeg = { w = 40, h = 200, d = 2.5, shape = 'capsule', stanceAngle = 0, limits = { side = 'left', low = -math.pi / 8, up = 0, enabled = true } },
    --foot = { w = 20, h = 150, d = 2, shape = 'rect1', limits = { side = 'left', low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    lfoot = { w = 80, h = 150, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    rfoot = { w = 80, h = 150, d = 2, shape = 'rect1', limits = { low = -math.pi / 8, up = math.pi / 8, enabled = true } },
    hair1 = { w = 180, h = 200, d = 0.1, shape = 'capsule', limits = { low = -math.pi / 2, up = math.pi / 2, enabled = true }, friction = 5000 },
    hair2 = { w = 150, h = 100, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair3 = { w = 150, h = 150, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair4 = { w = 150, h = 100, d = 0.1, shape = 'capsule2', limits = { low = -math.pi / 3, up = math.pi / 3, enabled = true }, friction = 5000 },
    hair5 = { w = 180, h = 200, d = 0.1, shape = 'capsule', limits = { low = -math.pi / 2, up = math.pi / 2, enabled = true }, friction = 5000 },
    eye = { w = 10, h = 10 },
    pupil = { w = 10, h = 10 },
    nose = { w = 10, h = 10 },
    upperlip = { w = 10, h = 10 },
    lowerlip = { w = 10, h = 10 },
    teeth = { w = 10, h = 10 },
}
function getCreation()
    return creation
end

function getParentAndChildrenFromPartName(partName, creation)
    local map = {
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
    --print(partName)
    return map[partName]
end

function getScaledTorsoMetaPoint(index)
    local wscale = creation.torso.w / creation.torso.metaPointsW
    local hscale = creation.torso.h / creation.torso.metaPointsH
    return creation.torso.metaPoints[index][1] * wscale, creation.torso.metaPoints[index][2] * hscale
end

function getScaledHeadMetaPoint(index)
    local wscale = creation.head.w / creation.head.metaPointsW
    local hscale = creation.head.h / creation.head.metaPointsH

    if creation.head.metaOffsetX or creation.head.metaOffsetY then
        return (creation.head.metaPoints[index][1] + creation.head.metaOffsetX) * wscale,
            (creation.head.metaPoints[index][2] + creation.head.metaOffsetY) * hscale
    end
    return creation.head.metaPoints[index][1] * wscale, creation.head.metaPoints[index][2] * hscale
end

function getOffsetFromParent(partName)
    local data = getParentAndChildrenFromPartName(partName)

    if partName == 'neck' then
        if creation.torso.metaPoints then
            return getScaledTorsoMetaPoint(1)
        end

        return 0, -creation.torso.h / 2
    elseif partName == 'luarm' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(7)
            end
        else
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(8)
            end
        end
        return -creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'ruarm' then
        if creation.isPotatoHead then
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(3)
            end
        else
            if creation.torso.metaPoints then
                return getScaledTorsoMetaPoint(2)
            end
        end

        return creation.torso.w / 2, -creation.torso.h / 2
    elseif partName == 'luleg' then
        if creation.torso.metaPoints then
            return getScaledTorsoMetaPoint(6)
        end
        return -creation.torso.w / 2, creation.torso.h / 2
    elseif partName == 'ruleg' then
        if creation.torso.metaPoints then
            return getScaledTorsoMetaPoint(4)
        end
        return creation.torso.w / 2, creation.torso.h / 2
    elseif partName == 'hair1' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(3)
        end
    elseif partName == 'hair2' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(4)
        end
    elseif partName == 'hair3' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(5)
        end
    elseif partName == 'hair4' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(6)
        end
    elseif partName == 'hair5' then
        if creation.head.metaPoints then
            return getScaledHeadMetaPoint(7)
        end
    elseif partName == 'lear' then
        -- if creation.torso.metaPoints then
        --     return getScaledTorsoMetaPoint(4)
        -- end
        if creation.isPotatoHead then
            if creation.head.metaPoints then
                return getScaledTorsoMetaPoint(8)
            end
        else
            if creation.head.metaPoints then
                return getScaledHeadMetaPoint(7)
            end
        end
        return -creation.head.w / 2, creation.head.h / 2
    elseif partName == 'rear' then
        -- if creation.torso.metaPoints then
        --     return getScaledTorsoMetaPoint(4)
        -- end
        if creation.isPotatoHead then
            if creation.head.metaPoints then
                return getScaledTorsoMetaPoint(2)
            end
        else
            if creation.head.metaPoints then
                return getScaledHeadMetaPoint(3)
            end
        end
        return creation.head.w / 2, creation.head.h / 2
    else
        if (partName == 'head') then
            if creation.hasNeck then
                return 0, creation.neck1.h / (creation.neck1.links or 1)
            else
                if creation.torso.metaPoints then
                    return getScaledTorsoMetaPoint(1)
                end

                return 0, -creation.torso.h / 2
            end
        end

        local p = data.p
        -- now look for the alias of the parent...
        local temp = getParentAndChildrenFromPartName(p)
        local part = temp.alias or p
        return 0, creation[part].h
    end
end

local function getAngleOffset(key, side, creation)
    -- print(key, side)
    if key == 'neck' then
        return -math.pi
    elseif key == 'neck1' then
        return 0
        --elseif key == 'ear' then
    elseif key == 'lear' then
        return creation.lear.stanceAngle
    elseif key == 'rear' then
        return creation.rear.stanceAngle
    elseif key == 'lfoot' then
        return math.pi / 2
    elseif key == 'rfoot' then
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
        return creation.luleg.stanceAngle
        --return creation.upLeg.stanceAngle
    elseif (key == 'llleg') then
        return creation.llleg.stanceAngle
        --return creation.lowLeg.stanceAngle
    elseif (key == 'ruleg') then
        return creation.ruleg.stanceAngle
        --return creation.upLeg.stanceAngle * -1
    elseif (key == 'rlleg') then
        return creation.rlleg.stanceAngle
        --return creation.lowLeg.stanceAngle * -1
    elseif key == 'head' then
        --print('jojo')
        --print(creation.hasNeck)
        if (not creation.hasNeck) then
            return 0
        else
            return math.pi
        end
        return 0
    else
        print('??', key)
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
    --print('making usrDAta', bodyType)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end




function changeMetaPoints(key, value, data)
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

function changeMetaTexture(key, data)
    local tlx, tly, brx, bry = bbox.getPointsBBox(data.texturePoints)
    local bbw = (brx - tlx)
    local bbh = (bry - tly)

    creation[key].metaURL = data.url
    creation[key].metaTexturePoints = data.texturePoints
    creation[key].metaTexturePointsW = bbw
    creation[key].metaTexturePointsH = bbh
    creation[key].metaPivotX = data.pivotX
    creation[key].metaPivotY = data.pivotY
end

function getFlippedMetaObject(flipx, flipy, points)
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

local function tableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function toggleAllJointLimits(guy, value)
    setJointLimitBetweenBodies(guy.head, guy.neck1, value, 'revolute')
    setJointLimitBetweenBodies(guy.neck1, guy.neck, value, 'revolute')
    setJointLimitBetweenBodies(guy.neck, guy.torso, value, 'revolute')

    setJointLimitBetweenBodies(guy.torso, guy.luleg, value, 'revolute')
    setJointLimitBetweenBodies(guy.luleg, guy.llleg, value, 'revolute')

    setJointLimitBetweenBodies(guy.torso, guy.ruleg, value, 'revolute')
    setJointLimitBetweenBodies(guy.ruleg, guy.rlleg, value, 'revolute')
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

function setJointLimitBetweenBodies(body1, body2, state, ofType)
    local joints = findJointBetween2Bodies(body1, body2)
    if joints then
        for i = 1, #joints do
            print(joints[i]:getType())
            if ofType == nil or joints[i]:getType() == ofType then
                print('doing it', state)
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

    -- friction
    if data.friction then
        local fjoint = love.physics.newFrictionJoint(from, this, this:getX(), this:getY(), false)
        fjoint:setMaxTorque(data.friction)
    end
    return joint
end

local function makeGuyFixture(data, key, groupId, body, shape)
    local fixture = love.physics.newFixture(body, shape, data.d)
    if (string.match(key, 'hair')) then
        -- haird doesnt collide

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


local function makePart_(cd, key, offsetX, offsetY, parent, groupId, side)
    local x, y = parent:getWorldPoint(offsetX, offsetY)
    local prevA = parent:getAngle()


    local xangle = getAngleOffset(key, side, creation)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = makeShapeFromCreationPart(cd)
    local fixture = makeGuyFixture(cd, key, groupId, body, shape)


    body:setAngle(prevA + xangle)
    local joint = makeConnectingRevoluteJoint(cd, body, parent, side)

    return body
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
        end
    end
    return result
end


-- we want to add a connector
local function useRecreateConnectorData(recreateConnectorData, body)
    local data = recreateConnectorData.ud.data
    local type = data.type
    assert(type)
    if type == 'foot' then
        makeAndReplaceConnector(recreateConnectorData, body, 0, creation.foot.h / 2, data, creation.foot.w * 2)
    elseif type == 'lhand' then
        makeAndReplaceConnector(recreateConnectorData, body, 0, creation.lhand.h / 2, data, creation.lhand.w * 2)
    elseif type == 'rhand' then
        makeAndReplaceConnector(recreateConnectorData, body, 0, creation.rhand.h / 2, data, creation.rhand.w * 2)
    end
end

function genericBodyPartUpdate(box2dGuy, groupId, partName)
    -- look up who is my parent and what are my children

    --print(partName)
    local data = getParentAndChildrenFromPartName(partName, creation)
    local parentName = data.p
    print(partName, parentName)
    local recreateConnectorData = getRecreateConnectorData(box2dGuy[partName]:getFixtures())
    local recreatePointerJoint = getRecreatePointerJoint(box2dGuy[partName])
    local thisA = box2dGuy[partName]:getAngle()

    if parentName then
        --print(parentName, partName)
        local jointWithParentToBreak = findJointBetween2Bodies(box2dGuy[parentName], box2dGuy[partName])

        if jointWithParentToBreak then
            local offsetX, offsetY = getOffsetFromParent(partName)
            local hx, hy = box2dGuy[parentName]:getWorldPoint(offsetX, offsetY)
            local prevA = box2dGuy[parentName]:getAngle()
            for i = 1, #jointWithParentToBreak do
                jointWithParentToBreak[i]:destroy()
            end
            box2dGuy[partName]:destroy()

            local createData = creation[data.alias or partName]
            local body = love.physics.newBody(world, hx, hy, "dynamic")
            local shape = makeShapeFromCreationPart(createData)
            local fixture = makeGuyFixture(createData, partName, groupId, body, shape)

            local leftOrRight = (partName):find('l', 1, true) == 1 and 'left' or 'right'
            local xangle 
            if string.match(partName, 'leg') then
                xangle = getAngleOffset(partName, leftOrRight, creation) -- what LEFT!

            else
                xangle =  getAngleOffset(data.alias or partName, leftOrRight, creation) -- what LEFT! 
            end
            --local xangle = getAngleOffset(data.alias or partName, leftOrRight, creation) -- what LEFT!
            --if string.match(partName, 'leg') then
            --    body:setAngle(xangle)
            --else
            body:setAngle(prevA + xangle)
            --end

            local joint = makeConnectingRevoluteJoint(createData, body, box2dGuy[parentName], leftOrRight)

            box2dGuy[partName] = body
            --if not string.match(partName, 'leg') then
            body:setAngle(thisA)
            --end
            -- print('breaking someting')
        end
    end

    if not parentName or partName == 'torso' then
        local aa = box2dGuy[partName]:getAngle()
        local hx, hy = box2dGuy[partName]:getWorldPoint(0, 0)
        box2dGuy[partName]:destroy()
        local createData = creation[partName]
        local body = love.physics.newBody(world, hx, hy, "dynamic")
        local shape = makeShapeFromCreationPart(createData)
        local fixture = makeGuyFixture(createData, partName, groupId, body, shape)
        box2dGuy[partName] = body
        box2dGuy[partName]:setAngle(aa)
    end

    if (recreatePointerJoint) then
        useRecreatePointerJoint(recreatePointerJoint, box2dGuy[partName])
    end

    if (recreateConnectorData) then
        useRecreateConnectorData(recreateConnectorData, box2dGuy[partName])
    end
    -- reattach children


    local function reAttachChild(childName)
        local childData = getParentAndChildrenFromPartName(childName)
        local offsetX, offsetY = getOffsetFromParent(childName)
        local nx, ny = box2dGuy[partName]:getWorldPoint(offsetX, offsetY)
        -- print(childName)
        box2dGuy[childName]:setPosition(nx, ny)
        local aa = box2dGuy[childName]:getAngle()
        local data2 = getParentAndChildrenFromPartName(childName)

        local leftOrRight = childName:find('l', 1, true) == 1 and 'left' or 'right'

        local xangle
        if string.match(childName, 'leg') then
            xangle = getAngleOffset(childName, leftOrRight, creation) -- what LEFT!

        else
            xangle =  getAngleOffset(data2.alias or childName, leftOrRight, creation) -- what LEFT! 
        end

       -- local xangle = getAngleOffset(data2.alias or childName, leftOrRight, creation) -- what LEFT!
        box2dGuy[childName]:setAngle(thisA + xangle)
        local joint = makeConnectingRevoluteJoint(creation[childData.alias or childName], box2dGuy[childName],
                box2dGuy[partName], leftOrRight)
        box2dGuy[childName]:setAngle(aa)
    end


    local childName = data.c
    if childName and (type(childName) == 'string') then
        reAttachChild(childName)
    end
    if childName and (type(childName) == 'table') then
        for i = 1, #childName do
            --  print(childName[i])
            local skip = false
            if creation.isPotatoHead and childName[i] == 'neck' then
                -- do not reattach neck wehnwe are a potato
                skip = true
            end
            if not creation.hasPhysicsHair and string.match(childName[i], 'hair') then
                skip = true
            end
            --if not creation.hasNeck and string.match(childName[i], 'neck') then
            --    skip = true
            --end
            if not skip then
                reAttachChild(childName[i])
            end
        end
    end
end

function handlePhysicsHairOrNo(hair, box2dGuy, groupId)
    -- we need to find out if we can leave early..
    if hair and box2dGuy.hair1 then return end
    if not hair and not box2dGuy.hair1 then return end

    local function makePart(name, parent)
        -- needed to wrap groupid

        local data = getParentAndChildrenFromPartName(name)
        local creationName = data.alias or name
        local offsetX, offsetY = getOffsetFromParent(name)
        local key = name
        local side = nil
        return makePart_(creation[creationName], key, offsetX, offsetY, parent, groupId, side)
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

function handleNeckAndHeadForHasNeck(willHaveNeck, box2dGuy, groupId)
    --if not willHaveNeck and box2dGuy.neck == nil
    local function makePart(name, parent)
        -- needed to wrap groupid

        local data = getParentAndChildrenFromPartName(name)
        local creationName = data.alias or name
        local offsetX, offsetY = getOffsetFromParent(name)
        local side = nil
        local key = name
        return makePart_(creation[creationName], key, offsetX, offsetY, parent, groupId, side)
    end

    if not willHaveNeck then
        box2dGuy.neck:destroy()
        box2dGuy.neck1:destroy()
        box2dGuy.head:destroy()
        box2dGuy.neck = nil
        box2dGuy.neck1 = nil

        local torso = box2dGuy.torso
        local head = makePart('head', torso)
        box2dGuy.head = head
        -- head:setAngle( -math.pi)
        --  head:setAngle(0)
    else
        box2dGuy.head:destroy()
        local torso = box2dGuy.torso
        local neck = makePart('neck', torso)
        local neck1 = makePart('neck1', neck)
        local head = makePart('head', neck1)
        --head:setAngle( -math.pi)
        -- head:setAngle(0)
        box2dGuy.neck = neck
        box2dGuy.neck1 = neck1
        box2dGuy.head = head
    end
end

function handleNeckAndHeadForPotato(willBePotato, box2dGuy, groupId)
    if willBePotato and box2dGuy.head == nil or not willBePotato and box2dGuy.head then
        return
    end

    local function makePart(name, parent)
        -- needed to wrap groupid

        local data = getParentAndChildrenFromPartName(name)
        local creationName = data.alias or name
        local offsetX, offsetY = getOffsetFromParent(name)
        local key = name
        local side = nil
        return makePart_(creation[creationName], key, offsetX, offsetY, parent, groupId, side)
    end

    if willBePotato then
        box2dGuy.neck:destroy()
        box2dGuy.neck1:destroy()
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

        local neck = makePart('neck', torso)
        local neck1 = makePart('neck1', neck)
        local head = makePart('head', neck1)
        local lear = makePart('lear', head)
        local rear = makePart('rear', head)

        box2dGuy.lear = lear
        box2dGuy.rear = rear
        box2dGuy.neck = neck
        box2dGuy.neck1 = neck1
        box2dGuy.head = head
    end
end

function makeGuy(x, y, groupId)
    local function makePart(name, parent)
        -- needed to wrap groupid
        local data = getParentAndChildrenFromPartName(name)
        local creationName = data.alias or name
        local offsetX, offsetY = getOffsetFromParent(name)
        local key = name
        local side = nil
        return makePart_(creation[creationName], key, offsetX, offsetY, parent, groupId, side)
    end

    local torso = love.physics.newBody(world, x, y, "dynamic")
    local torsoShape = makeShapeFromCreationPart(creation.torso)
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

    makeAndAddConnector(rhand, 0, creation.rhand.h / 2, { id = 'guy' .. groupId, type = 'hand' }, creation.rhand.w + 10,
        creation.rhand.h + 10)

    local luarm = makePart('luarm', torso)
    local llarm = makePart('llarm', luarm)
    local lhand = makePart('lhand', llarm)
    makeAndAddConnector(lhand, 0, creation.lhand.h / 2, { id = 'guy' .. groupId, type = 'hand' }, creation.lhand.w + 10,
        creation.lhand.h + 10)

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
