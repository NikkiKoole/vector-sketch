local bbox            = require 'lib.bbox'
local generatePolygon = require('lib.generate-polygon').generatePolygon
Vector                = require 'vendor.brinevector'
local camera          = require 'lib.camera'
local cam             = require('lib.cameraBase').getInstance()
local lib             = {}

local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

local function makeRectPoly(w, h, x, y)
    return love.physics.newPolygonShape(
            x, y,
            x + w, y,
            x + w, y + h,
            x, y + h
        )
end

function makeRectPoly2(w, h, x, y)
    local cx = x
    local cy = y
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx + w / 2, cy - h / 2,
            cx + w / 2, cy + h / 2,
            cx - w / 2, cy + h / 2
        )
end

local function capsuleXY(w, h, cs, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    local result = {
        x + -w2, y + bt,
        x + bl, y + -h2,
        x + br, y + -h2,
        x + w2, y + bt,
        x + w2, y + bb,
        x + br, y + h2,
        x + bl, y + h2,
        x + -w2, y + bb
    }
    return result
end

local function makeTrapeziumPoly(w, w2, h, x, y)
    local cx = x
    local cy = y
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx + w / 2, cy - h / 2,
            cx + w2 / 2, cy + h / 2,
            cx - w2 / 2, cy + h / 2
        )
end


local function makePointerJoint(id, bodyToAttachTo, wx, wy, fixture)
    local pointerJoint = {}
    pointerJoint.id = id

    local ud = fixture:getUserData()
    local force = ud and ud.bodyType == 'torso' and 5000000 or 50000

    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(.5)
    pointerJoint.joint:setMaxForce(force)
    return pointerJoint
end

local function makePrio(fixture)
    local ud = fixture:getUserData()
    if ud then
        if string.match(ud.bodyType, 'hand') then
            return 3
        end

        if string.match(ud.bodyType, 'arm') then
            return 2
        end
    end
    return 1
end

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end

local function getCenterOfPoints(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points, 2 do
        if points[ip + 0] < tlx then tlx = points[ip + 0] end
        if points[ip + 1] < tly then tly = points[ip + 1] end
        if points[ip + 0] > brx then brx = points[ip + 0] end
        if points[ip + 1] > bry then bry = points[ip + 1] end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2
end

local function getCentroidOfFixture(body, fixture)
    return { getCenterOfPoints({ body:getWorldPoints(fixture:getShape():getPoints()) }) }
end

function handlePointerPressed(x, y, id, cam)
    local wx, wy = cam:getWorldCoordinates(x, y)
    local bodies = world:getBodies()
    local temp = {}
    for _, body in ipairs(bodies) do
        if body:getType() ~= 'kinematic' then
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)
                local isSensor = fixture:isSensor()
                if (hitThisOne and not isSensor) then
                    table.insert(temp,
                        { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture), fixture = fixture })
                end
            end
        end
    end
    if #temp > 0 then
        table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
        lib.killMouseJointIfPossible(id)
        table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, temp[1].fixture))
    end

    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0
end

function getJointBetween2Connectors(to, at)
    local pos1 = getCentroidOfFixture(to:getBody(), to)
    local pos2 = getCentroidOfFixture(at:getBody(), at)
    local j = love.physics.newRevoluteJoint(at:getBody(), to:getBody(),
            pos2[1],
            pos2[2], pos1[1], pos1[2])
    return j
end

local function maybeConnectThisConnector(f, mj)
    local found = false


    for j = 1, #connectors do
        if connectors[j].to and connectors[j].to == f then
            found = true
        end
    end

    if found == false then
        local pos1 = getCentroidOfFixture(f:getBody(), f)
        local done = false

        for j = 1, #connectors do
            if (connectors[j].at:isDestroyed()) then
                print('THIS IS A DESTROYED CONNECTOR, WHY IS IT  STILL HEREE??')
            end
            local theOtherBody = connectors[j].at:getBody()

            -- maybe verify that both connector dont point to the same agent (as in are both part of the same character)
            local skipCausePointingToSameAgent = false
            if (f:getUserData().data and connectors[j].at:getUserData() and connectors[j].at:getUserData().data) then
                if f:getUserData().data.id and connectors[j].at:getUserData().data.id then
                    if f:getUserData().data.id == connectors[j].at:getUserData().data.id then
                        skipCausePointingToSameAgent = true
                    end
                end
            end

            if not skipCausePointingToSameAgent and theOtherBody ~= f:getBody() and connectors[j].to == nil then
                local pos2 = getCentroidOfFixture(theOtherBody, connectors[j].at)

                local a = pos1[1] - pos2[1]
                local b = pos1[2] - pos2[2]
                local d = math.sqrt(a * a + b * b)

                local isOnCooldown = false

                for p = 1, #connectorCooldownList do
                    if connectorCooldownList[p].index == j then
                        isOnCooldown = true
                    end
                end

                local topLeftX, topLeftY, bottomRightX, bottomRightY = f:getBoundingBox(1)
                local w1 = bottomRightX - topLeftX
                local topLeftX, topLeftY, bottomRightX, bottomRightY = theOtherBody:getFixtures()[1]
                    :getBoundingBox(1)
                local w2 = bottomRightX - topLeftX
                local maxD = (w1 + w2) / 2

                if d < maxD and not isOnCooldown then
                    connectors[j].to = f --mj.jointBody
                    local joint = getJointBetween2Connectors(connectors[j].to, connectors[j].at)
                    connectors[j].joint = joint
                end
            end
        end
    end
end

if false then
    function handleConnectors(cam)
        if false then
            for j = 1, #connectors do
                maybeConnectThisConnector(connectors[j].at)
            end
        end

        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            if (mj.joint) then
                local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                mj.joint:setTarget(wx, wy)

                local fixtures = mj.jointBody:getFixtures();
                for k = 1, #fixtures do
                    local f = fixtures[k]
                    if f:getUserData() and f:getUserData().bodyType then
                        print(f:getUserData().bodyType)
                        if f:getUserData().bodyType == 'connector' then
                            print('well helo1')
                            maybeConnectThisConnector(f)
                        end
                    end
                end
            end
        end
    end
end

function handleUpdate(dt, cam)
    -- connect connectors
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            mj.joint:setTarget(wx, wy)

            local fixtures = mj.jointBody:getFixtures()
            for k = 1, #fixtures do
                local f = fixtures[k]
                if f:getUserData() and f:getUserData().bodyType then
                    if f:getUserData().bodyType == 'connector' then
                        maybeConnectThisConnector(f)
                    end

                    if f:getUserData().bodyType == 'carbody' then
                        local body = mj.jointBody
                        if body then
                            -- i dont have a cartouching per car, its global so wont work for all
                            --if (carIsTouching < 1) then
                            rotateToHorizontal(body, 0, 30)
                            --end
                        end
                    end
                end
            end
        end
    end

    -- diconnect connectors
    if true then
        if connectors then
            for i = #connectors, 1, -1 do
                -- we can only break a  joint if we have one

                if connectors[i].joint then
                    local reaction2 = { connectors[i].joint:getReactionForce(1 / dt) }
                    local delta = Vector(reaction2[1], reaction2[2])
                    local l = delta:getLength()
                    local found = false

                    for j = 1, #pointerJoints do
                        local mj = pointerJoints[j]
                        if mj.jointBody == connectors[i].to:getBody() or mj.jointBody == connectors[i].at:getBody() then
                            found = true
                        end
                    end

                    local b1, b2 = connectors[i].joint:getBodies()

                    local breakForce = 50000 * math.max(1, (b1:getMass() * b2:getMass()))


                    local breakForceWhenNotMouseJointed = 2000000 * (b1:getMass() * b2:getMass())
                    --if (not found) then
                    --    print(l, )
                    --end


                    if ((found and l > breakForce) or (not found and l > breakForceWhenNotMouseJointed)) then
                        print('broke when foudn', found)
                        connectors[i].joint:destroy()
                        connectors[i].joint = nil

                        connectors[i].to = nil
                        --print('broke it', i, l, breakForce)
                        table.insert(connectorCooldownList, { runningFor = 0, index = i })
                    end
                end
            end
        end
    end
    local now = love.timer.getTime()
    for i = #connectorCooldownList, 1, -1 do
        connectorCooldownList[i].runningFor = connectorCooldownList[i].runningFor + dt
        if (connectorCooldownList[i].runningFor > 0.5) then
            table.remove(connectorCooldownList, i)
        end
    end
end

function handlePointerReleased(x, y, id)
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        -- if false then
        if mj.id == id then
            if (mj.joint) then --- UNUSED
                if false then -- this is to shoot objects when you drag then below the groud (pim pam pet effect])
                    if (mj.jointBody and objects.ground) then
                        local points = { objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()) }
                        local tl = { points[1], points[2] }
                        local tr = { points[3], points[4] }
                        -- fogure out if we are below the ground, and if so whatthe ange is we want to be shot at.
                        -- oh wait, this is actually kinda good enough-ish (tm)
                        if (mj.bodyLastDisabledContact and mj.bodyLastDisabledContact:getBody() == mj.jointBody) then
                            local x1, y1 = mj.jointBody:getPosition()
                            if (#mj.positionOfLastDisabledContact > 0) then
                                local x2 = mj.positionOfLastDisabledContact[1]
                                local y2 = mj.positionOfLastDisabledContact[2]

                                local delta = Vector(x1 - x2, y1 - y2)
                                local l = delta:getLength()

                                local v = delta:getNormalized() * l * -2
                                if v.y > 0 then
                                    v.y = 0
                                    v.x = 0
                                end -- i odnt want  you shoooting downward!
                                mj.bodyLastDisabledContact:getBody():applyLinearImpulse(v.x, v.y)
                            end
                            mj.bodyLastDisabledContact = nil
                            mj.positionOfLastDisabledContact = nil
                            --
                        end
                    end
                end
            end
            --   end
        end
    end
    lib.killMouseJointIfPossible(id)
end

function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

local function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return { 1, 0, 0, 1 } --palette[colors.peach]
    end
    if body:getType() == 'dynamic' then
        return { 0, 1, 0, 1 } --palette[colors.blue]
    end
    if body:getType() == 'static' then
        return { 1, 1, 0, 1 } --palette[colors.green]
    end
end

---- physics contacs

local function contactShouldBeDisabled(a, b, contact)
    local ab = a:getBody()
    local bb = b:getBody()

    local fixtureA, fixtureB = contact:getFixtures()
    local result = false

    -- for some reason the other way around doesnt happen so fixtureA is the ground and the other one might be ball
    -- this disables contact between a dragged item and the ground
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.jointBody) then
            if (bb == mj.jointBody and fixtureA:getUserData() and fixtureA:getUserData().bodyType == 'ground') then
                result = true
            end
        end
    end
    -- this disables contact between  balls and the ground if ballcenterY < collisionY (ball below ground)
    if fixtureA:getUserData() and fixtureB:getUserData() then
        if fixtureA:getUserData().bodyType == 'ground' and fixtureB:getUserData().bodyType == 'ball' then
            local x1, y1 = contact:getPositions()
            if y1 < bb:getY() then
                result = true
            end
        end
    end
    --return result

    return false
end

local function beginContact(a, b, contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also what touch id or mouse this is..

        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]

            local bodyLastDisabledContact = nil
            if mj.jointBody == a:getBody() then
                bodyLastDisabledContact = a
            end
            if mj.jointBody == b:getBody() then
                bodyLastDisabledContact = b
            end
            if bodyLastDisabledContact then
                pointerJoints[i].bodyLastDisabledContact = bodyLastDisabledContact
                pointerJoints[i].positionOfLastDisabledContact = point
                table.insert(disabledContacts, contact)
            end
        end
    end
    --if isContactBetweenGroundAndCarGroundSensor(contact) then
    --    carIsTouching = carIsTouching + 1
    --end
end


local function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end
    -- if isContactBetweenGroundAndCarGroundSensor(contact) then
    --     carIsTouching = carIsTouching - 1
    -- end
end

local function preSolve(a, b, contact)
    -- this is so contacts keep on being disabled if they are on that list (sadly they are being re-enabled by box2d.... )
    for i = 1, #disabledContacts do
        disabledContacts[i]:setEnabled(false)
    end
end

local function postSolve(a, b, contact, normalimpulse, tangentimpulse)

end



-- this should be in physicsworld
function rebuildPhysicsBorderForScreen()
    for i = 1, #borders do
        if not borders[i]:isDestroyed() then
            borders[i]:destroy()
        end
    end
    borders = {}
    local w, h = love.graphics.getDimensions()
    -- camera.setCameraViewport(cam, w, h)
    -- camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly

    local wallThick = 4000
    local sideHigh = 20000
    local half = wallThick / 2

    local top = love.physics.newBody(world, w / 2, camtly - sideHigh, "static")
    local topshape = love.physics.newRectangleShape(boxWorldWidth, 3000)
    local topfixture = love.physics.newFixture(top, topshape, 1)

    local bottom = love.physics.newBody(world, w / 2, cambry + half, "static")
    local bottomshape = love.physics.newRectangleShape(boxWorldWidth, wallThick)
    local bottomfixture = love.physics.newFixture(bottom, bottomshape, 1)

    local left = love.physics.newBody(world, camtlx - half, 2500 - 15000, "static")
    local leftshape = love.physics.newRectangleShape(wallThick, 30000)
    local leftfixture = love.physics.newFixture(left, leftshape, 1)

    local right = love.physics.newBody(world, cambrx + half, 2500 - 15000, "static")
    local rightshape = love.physics.newRectangleShape(wallThick, 30000)
    local rightfixture = love.physics.newFixture(right, rightshape, 1)

    borders = { topfixture, bottomfixture, leftfixture, rightfixture }
end

function setupBox2dScene(amountOfGuys)
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)

    box2dGuys = {}
    rebuildPhysicsBorderForScreen()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local stepSize = boxWorldWidth / (amountOfGuys + 1)


    for i = 1, amountOfGuys do
        table.insert(box2dGuys, makeGuy(camtlx + i * stepSize, camtly, i))
    end
end

lib.killMouseJointIfPossible = function(id)
    local index = -1
    for i = 1, #pointerJoints do
        if pointerJoints[i].id == id then
            index = i
            if (pointerJoints[i].joint and not pointerJoints[i].joint:isDestroyed()) then
                pointerJoints[i].joint:destroy()
            end
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
        end
    end
    table.remove(pointerJoints, index)
end

lib.makeShapeFromCreationPart = function(part)
    if part.metaPoints then
        local tlx, tly, brx, bry = bbox.getPointsBBox(part.metaPoints)
        local bbw = (brx - tlx)
        local bbh = (bry - tly)
        local wscale = part.w / bbw
        local hscale = part.h / bbh
        local flatted = {}

        local offsetX = 0
        local offsetY = 0

        if part.metaOffsetX or part.metaOfsetY then
            offsetX = part.metaOffsetX
            offsetY = part.metaOffsetY
        end

        for i = 1, #part.metaPoints do
            table.insert(flatted, (offsetX + part.metaPoints[i][1]) * wscale)
            table.insert(flatted, (offsetY + part.metaPoints[i][2]) * hscale)
        end
        return love.physics.newPolygonShape(flatted)
    else
        return lib.makeShape(part.shape, part.w, part.h)
    end
end

lib.makeShape = function(shapeType, w, h)
    if (shapeType == 'rect2') then
        return makeRectPoly2(w, h, 0, h / 2)
    elseif (shapeType == 'rect1') then
        return makeRectPoly(w, h, -w / 2, -h / 8)
    elseif (shapeType == 'capsule') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, h / 2))
    elseif (shapeType == 'capsule2') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, 0))
    elseif (shapeType == 'capsule3') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, -h / 2))
    elseif (shapeType == 'trapezium') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, 0)
    elseif (shapeType == 'trapezium2') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, h / 2)
    end
end


lib.makeAndAddConnector = function(parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = makeRectPoly2(size * 10, size2 * 10, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 0)
    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)
    table.insert(connectors, { at = fixture, to = nil, joint = nil })
    print('jo hello from lib!', #connectors)
end


lib.setupWorld = function()
    love.physics.setMeter(500)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)
    disabledContacts = {}
    pointerJoints = {}
    connectorCooldownList = {}
    connectors = {}
end

lib.resetLists = function()
    connectors = {}
    pointerJoints = {}
end

lib.drawWorld = function(world)
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8

    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    love.graphics.setLineWidth(10)
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()

        for _, fixture in ipairs(fixtures) do
            --if fixture:getUserData() then
            --     print(inspect(fixture:getUserData()))
            --end
            if fixture:getShape():type() == 'PolygonShape' then
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
            elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
                for i = 1, #points, 2 do
                    if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
                end
            elseif fixture:getShape():type() == 'CircleShape' then
                local body_x, body_y = body:getPosition()
                local shape_x, shape_y = fixture:getShape():getPoint()
                local r = fixture:getShape():getRadius()
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, r, 360)
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.circle('line', body_x + shape_x, body_y + shape_y, r, 360)
            end
        end
    end
    love.graphics.setColor(255, 255, 255, alpha)
    -- Joint debug
    love.graphics.setColor(1, 0, 0, alpha)
    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        local x1, y1, x2, y2 = joint:getAnchors()
        if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
        if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
    end

    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(1)
end


return lib
