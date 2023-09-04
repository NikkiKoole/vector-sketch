package.path          = package.path .. ";../../?.lua"
local lurker          = require 'vendor.lurker'
local inspect         = require 'vendor.inspect'
Vector                = require 'vendor.brinevector'
local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'
local generatePolygon = require('lib.generate-polygon').generatePolygon
local geom = require 'lib.geom'

require 'box2dGuyCreation'
local creation = getCreation()

lurker.quiet = true
require 'palette'

-- check this for multiple fixtures, -> sensor for gorund
-- https://love2d.org/forums/viewtopic.php?t=80950
-- lift the rendering from windfield :
--https://github.com/a327ex/windfield/blob/master/windfield/init.lua
lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    grabDevelopmentScreenshot()
end

function bool2str(bool)
    return bool and 'true' or 'false'
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

function grabDevelopmentScreenshot()
    love.graphics.captureScreenshot('ScreenShot-' .. os.date("%Y-%m-%d-[%H-%M-%S]") .. '.png')
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

local motorSpeed = 0
local motorTorque = 1500
local carIsTouching = 0

local function makePointerJoint(id, bodyToAttachTo, wx, wy)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(0.5)
    pointerJoint.joint:setMaxForce(500000)
    return pointerJoint
end

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end

local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    --print(inspect(result))
    return result
end

function npoly(radius, sides)
    local angle = 0
    local angle_increment = (math.pi * 2) / sides
    local result = {}
    for i = 1, sides do
        x = 0 + radius * math.cos(angle)
        y = 0 + radius * math.sin(angle)
        angle = angle + angle_increment
        table.insert(result, x)
        table.insert(result, y)
    end
    return result
end

function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

-- https://www.iforce2d.net/b2dtut/one-way-walls
-- in the original tutorial they hack box2d to stop reenabling contacts every frame, i cannot do that. so i must keep a list around.

function contactShouldBeDisabled(a, b, contact)
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

function isContactBetweenGroundAndCarGroundSensor(contact)
    local fixtureA, fixtureB = contact:getFixtures()
    if fixtureA:getUserData() and fixtureB:getUserData() then
        return (fixtureA:getUserData().bodyType == 'ground' and fixtureB:getUserData().bodyType == 'carGroundSensor') or
            (fixtureB:getUserData().bodyType == 'ground' and fixtureA:getUserData().bodyType == 'carGroundSensor')
    else
        return false
    end
end

function beginContact(a, b, contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also waht touch id or mouse this is..


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
                -- do i need to keep something in the pointerJoints too ???
                -- positionOfLastDisabledContact
                pointerJoints[i].bodyLastDisabledContact = bodyLastDisabledContact
                pointerJoints[i].positionOfLastDisabledContact = point
                table.insert(disabledContacts, contact)
            end
        end
    end
    if isContactBetweenGroundAndCarGroundSensor(contact) then
        --print('touching', carIsTouching)

        carIsTouching = carIsTouching + 1
    end
end

function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end
    if isContactBetweenGroundAndCarGroundSensor(contact) then
        -- print('no touching', carIsTouching)
        carIsTouching = carIsTouching - 1
    end
end

function preSolve(a, b, contact)
    -- this is so contacts keep on being disabled if they are on that list (sadly they are being re-enabled by box2d.... )
    for i = 1, #disabledContacts do
        disabledContacts[i]:setEnabled(false)
    end
end

function postSolve(a, b, contact, normalimpulse, tangentimpulse)

end

function capsule(w, h, cs)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2
    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    local result = {
        -w2, bt,
        bl, -h2,
        br, -h2,
        w2, bt,
        w2, bb,
        br, h2,
        bl, h2,
        -w2, bb
    }
    return result
end

function capsuleXY(w, h, cs, x, y)
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

function makeRectPoly(w, h, x, y)
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

function makeCarShape(w, h, cx, cy)
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx - w / 2, cy + h / 2 - h / 5,
            cx - w / 2 + w / 8, cy + h / 2,
            cx + w / 2 - w / 8, cy + h / 2,
            cx + w / 2, cy + h / 2 - h / 5,
            --cx + w / 2, cy + h / 4
            cx + w / 2, cy - h / 2
        )
end

function makeUShape(w, h, thickness)
    return love.physics.newPolygonShape(
            -w / 2, -h / 2,
            -w / 2, h / 2,
            w / 2, h / 2,
            w / 2, -h / 2,
            w / 2 - thickness, -h / 2,
            w / 2 - thickness, h / 2 - thickness,
            -w / 2 + thickness, h / 2 - thickness,
            -w / 2 + thickness, -h / 2
        )
end

function makeShapeFromCreationPart(part)
    return makeShape(part.shape, part.w, part.h)
end

function makeShape(shapeType, w, h)
    if (shapeType == 'rect2') then
        return makeRectPoly2(w, h, 0, h / 2)
    elseif (shapeType == 'rect1') then
        return makeRectPoly(w, h, -w / 2, -h / 8)
    elseif (shapeType == 'capsule') then
        -- ipv hardcoded 10 i use w/5
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0,
                h / 2))
    elseif (shapeType == 'trapezium') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, 0)
    elseif (shapeType == 'trapezium2') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, h / 2)
    end
end

function makeAndAddConnector(parent, x, y, data, size)
    size = size or 10
    local bandshape2 = makeRectPoly2(size, size, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 0)
    --print(inspect(data))
    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)
    table.insert(connectors, { at = fixture, to = nil, joint = nil })
end

function getJointBetween2Connectors(to, at)
    local pos1 = getCentroidOfFixture(to:getBody(), to)
    local pos2 = getCentroidOfFixture(at:getBody(), at)
    local j = love.physics.newRevoluteJoint(at:getBody(), to:getBody(),
            pos2[1],
            pos2[2], pos1[1], pos1[2])
    return j
end

function makeAndReplaceConnector(recreate, parent, x, y, data, size)
    size = size or 10
    local bandshape2 = makeRectPoly2(size, size, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 1)

    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)

    -- we are remaking a connector, keep all its connections working here!
    for i = 1, #connectors do
        if connectors[i].at and connectors[i].at == recreate.oldFixture then
            connectors[i].at = fixture
            if connectors[i].to then
                local j = getJointBetween2Connectors(connectors[i].to, connectors[i].at)
                connectors[i].joint = j
            end
        end

        if connectors[i].to and connectors[i].to == recreate.oldFixture then
            connectors[i].to = fixture

            local j = getJointBetween2Connectors(connectors[i].to, connectors[i].at)
            connectors[i].joint = j
        end
    end
end

function makeSnappyElastic(x, y)
    -- ceiling

    local bandW = 20
    local bandH = 100 + love.math.random() * 100
    local ceiling = love.physics.newBody(world, x, y, "static")

    makeAndAddConnector(ceiling, 0, 0)

    local band = love.physics.newBody(world, x, y, "dynamic")
    local bandshape = makeRectPoly2(bandW, bandH, 0, bandH / 2)
    local fixture = love.physics.newFixture(band, bandshape, 1)

    makeAndAddConnector(band, 0, 0)
    makeAndAddConnector(band, 0, bandH)
end



function makeSpine(x,y, amt, groupId, totalHeight)
    local linkHeight = totalHeight/ (amt)
    local linkWidth = 50
    local dir = 1
    local count = 1

    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape =  makeShape('rect2', linkWidth, linkHeight)  
        local fixture = love.physics.newFixture(body, shape, .3)
        fixture:setFilterData(1, 65535, -1 * groupId)
        fixture:setUserData(makeUserData('neck'))
       -- body:setAngle(-math.pi)
        count = count + 1
        return body
    end

    local lastLink = makeLink(x, y)
   -- lastLink:setAngle(-math.pi)
    local firstLink = lastLink
    for i = 1, amt do
        local link = makeLink(x, y + (i * (linkHeight + 2)) * dir)
        
        local joint = love.physics.newRevoluteJoint(lastLink, link, link:getX(), link:getY(), true)

        joint:setLowerLimit( -math.pi / 8)
        joint:setUpperLimit(math.pi / 8)
        joint:setLimitsEnabled(true)

        local dj = love.physics.newDistanceJoint(lastLink, link, lastLink:getX(), lastLink:getY(), link:getX(),
                link:getY())
        
                lastLink:setAngle(math.pi)
        lastLink = link
    end
    return firstLink, lastLink
end

function makeChain2(x, y, amt, groupId, totalHeight)
    local linkHeight = totalHeight/ (amt)
    local linkWidth = 50
    local dir = 1
    -- local amt = 3
    local count = 1
    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth, linkHeight)
        local fixture = love.physics.newFixture(body, shape, .3)
        fixture:setFilterData(1, 65535, -1 * groupId)
        fixture:setUserData(makeUserData('neck'))
        count = count + 1
        return body
    end

    local lastLink = makeLink(x, y)
    local firstLink = lastLink
    for i = 1, amt do
        local link = makeLink(x, y + (i * linkHeight) * dir)
        local joint = love.physics.newRevoluteJoint(lastLink, link, link:getX(), link:getY(), true)

        joint:setLowerLimit( -math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)

        local dj = love.physics.newDistanceJoint(lastLink, link, lastLink:getX(), lastLink:getY(), link:getX(),
                link:getY())
        lastLink = link
    end

    return firstLink, lastLink
end

function makeChain(x, y, amt)
    --https://mentalgrain.com/box2d/creating-a-chain-with-box2d/
    local linkHeight = 20
    local linkWidth = 50
    local dir = 1
    -- local amt = 3
    local count = 1

    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth + count * 5, linkHeight)
        local fixture = love.physics.newFixture(body, shape, .3)
        count = count + 1
        return body
    end

    local lastLink = makeLink(x, y)
    for i = 1, amt do
        local link = makeLink(x, y + (i * linkHeight) * dir)
        local joint = love.physics.newRevoluteJoint(lastLink, link, link:getX(), link:getY(), true)

        joint:setLowerLimit( -math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)

        local dj = love.physics.newDistanceJoint(lastLink, link, lastLink:getX(), lastLink:getY(), link:getX(),
                link:getY())
        lastLink = link
    end

    if false then
        local weight = love.physics.newBody(world, x, y + ((amt + 1) * linkHeight) * dir, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth, linkHeight)
        local fixture = love.physics.newFixture(weight, shape, 1)


        local joint = love.physics.newRevoluteJoint(lastLink, weight, weight:getX(), weight:getY(), false)
        local dj = love.physics.newDistanceJoint(lastLink, weight, lastLink:getX(), lastLink:getY(), weight:getX(),
                weight:getY())
        joint:setLowerLimit( -math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)
        table.insert(objects.blocks, weight)
    end
end

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    ball.shape = love.physics.newCircleShape(ballRadius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData(makeUserData("ball"))
    ball.fixture:setFriction(.5)
    return ball
end

function makeBlock(x, y, size)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20,
            ballRadius * 3 + love.math.random() * 20, 5))
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData(makeUserData("ball"))
    ball.fixture:setFriction(.5)
    return ball
end

function makeCarousell(x, y, width, height, angularVelocity)
    local carousel = {}
    carousel.body = love.physics.newBody(world, x, y, "kinematic")
    carousel.shape = love.physics.newRectangleShape(width, height)
    carousel.fixture = love.physics.newFixture(carousel.body, carousel.shape, 1)
    carousel.body:setAngularVelocity(angularVelocity)
    carousel.fixture:setUserData(makeUserData("caroussel"))
    return carousel
end

function makeBorderChain(width, height, margin)
    local border = {}
    border.body = love.physics.newBody(world, 0, 0)
    border.shape = love.physics.newChainShape(true,
            margin, margin,
            width - margin, margin,
            width - margin, height - margin,
            margin, height - margin)

    border.fixture = love.physics.newFixture(border.body, border.shape)
    border.fixture:setUserData(makeUserData("border"))
    border.fixture:setFriction(.5)
    return border
end

function makeBalloon(x, y)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    ball.shape = love.physics.newCircleShape(180)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 0)
    --  ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData(makeUserData("balloon"))
    -- ball.fixture:setFriction(.5)

    makeAndAddConnector(ball.body, 0, 200, nil, 50)
    return ball
end

function makeChainGround()
    local width, height = love.graphics.getDimensions()
    local points = {}
    for i = -1000, 1000 do
        local cool = 1.78
        local amplitude = 150 * cool
        local frequency = 33
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y1 = h - (amplitude / 2)

        local cool = 1.78
        local amplitude = 100 * cool
        local frequency = 17
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y2 = h - (amplitude / 2)

        table.insert(points, i * 100)
        table.insert(points, y1 + y2)
    end

    local thing = {}
    thing.body = love.physics.newBody(world, 0, 0)
    thing.shape = love.physics.newChainShape(false, unpack(points))
    thing.fixture = love.physics.newFixture(thing.body, thing.shape)
    thing.fixture:setUserData("border")
    thing.fixture:setFriction(.5)
    return thing
end

function makeSeeSaw(x, y)
    local plank = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(1800, 60)
    local fixture = love.physics.newFixture(plank, shape, 1)

    local shape1 = makeRectPoly2(20, 150, -900, 0)
    local fixture = love.physics.newFixture(plank, shape1, 1)

    local shape2 = makeRectPoly2(20, 150, 900, 0)
    local fixture = love.physics.newFixture(plank, shape2, 1)

    local axis = love.physics.newBody(world, x, y, "static")
    local shape = makeTrapeziumPoly(20, 480, 600, 0, 0)
    local fixture = love.physics.newFixture(axis, shape, 1)

    local joint = love.physics.newRevoluteJoint(axis, plank, plank:getX(), plank:getY(), false)
    joint:setLowerLimit( -math.pi / 4)
    joint:setUpperLimit(math.pi / 4)
    joint:setLimitsEnabled(true)
end

function makeVehicle(x, y)
    local carBodyHeight = 150
    local carBodyWidth  = 400

    local carbody       = love.physics.newBody(world, x, y, "dynamic")
    local shape         = makeCarShape(carBodyWidth, carBodyHeight, 0, 0) --makeRectPoly2(300, 100, 0, 0)  --love.physics.newRectangleShape(300, 100)
    local fixture       = love.physics.newFixture(carbody, shape, .5)


    fixture:setUserData(makeUserData("carbody"))

    makeAndAddConnector(carbody, carBodyWidth / 2 + 25, carBodyHeight / 2 - 15)
    makeAndAddConnector(carbody, -carBodyWidth / 2 - 25, carBodyHeight / 2 - 15)

    if false then
        local xOffset = -100
        local polyWidth = 20
        local polyLength = -110

        local backside = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        local backfixture = love.physics.newFixture(carbody, backside, .5)


        local xOffset = 80
        local polyWidth = 20
        local polyLength = -110

        local backside = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        local backfixture = love.physics.newFixture(carbody, backside, .5)
    end

    if true then
        local carsensor = {}
        local xOffset = 100
        local polyWidth = 20
        local polyLength = 110
        carsensor.shape = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        carsensor.fixture = love.physics.newFixture(carbody, carsensor.shape, .5)
        carsensor.fixture:setSensor(true)
        carsensor.fixture:setUserData(makeUserData("carGroundSensor"))
    end

    if true then
        local carsensor = {}
        local xOffset = -100
        local polyWidth = 20
        local polyLength = 110
        carsensor.shape = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        carsensor.fixture = love.physics.newFixture(carbody, carsensor.shape, .5)
        carsensor.fixture:setSensor(true)
        carsensor.fixture:setUserData(makeUserData("carGroundSensor"))
    end

    local wheel1 = love.physics.newBody(world, x - (carBodyWidth / 3), y + carBodyHeight / 2 -
        50 / 2, "dynamic")
    local shape = love.physics.newCircleShape(50)
    local fixture = love.physics.newFixture(wheel1, shape, .5)
    fixture:setFilterData(1, 65535, -1)
    fixture:setFriction(2.5)

    local joint1 = love.physics.newRevoluteJoint(carbody, wheel1, wheel1:getX(), wheel1:getY(), false)
    joint1:setMotorEnabled(true)
    joint1:setMotorSpeed(motorSpeed)
    joint1:setMaxMotorTorque(motorTorque)


    -- how to add pedals to this ?

    local pedalwheel = love.physics.newBody(world, x, y - carBodyHeight / 2, "dynamic")
    local shape = love.physics.newPolygonShape(npoly(50, 7)) --love.physics.newRectangleShape(100, 100) --(50)-- love.physics.newCircleShape(50)
    local fixture = love.physics.newFixture(pedalwheel, shape, .5)
    fixture:setFilterData(1, 65535, -1)
    fixture:setFriction(2.5)
    fixture:setSensor(true)
    local joint2 = love.physics.newRevoluteJoint(carbody, pedalwheel, pedalwheel:getX(), pedalwheel:getY(), false)

    table.insert(vehiclePedalConnection, { wheelJoint = joint1, pedalJoint = joint2, pedalWheel = pedalwheel })


    --local wheel2 = {}
    local wheel2 = love.physics.newBody(world, x + (carBodyWidth / 3), y + carBodyHeight / 2 - 25 / 2, "dynamic")
    local shape = love.physics.newCircleShape(35)
    local fixture = love.physics.newFixture(wheel2, shape, .5)
    fixture:setFilterData(1, 65535, -1)
    fixture:setFriction(2.5)

    local joint2 = love.physics.newRevoluteJoint(carbody, wheel2, wheel2:getX(), wheel2:getY(), false)
    joint2:setMotorEnabled(true)
    joint2:setMotorSpeed(motorSpeed)
    joint2:setMaxMotorTorque(motorTorque)
end

function startExample(number)
    local width, height = love.graphics.getDimensions()
    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter() * 4, true)
    objects = {}
    ballRadius = love.physics.getMeter() / 4
    vehiclePedalConnection = {}
    box2dGuys = {}
    connectors = {}
    ----
    ---- VLOOIENSPEL
    -----
    if number == 1 then
        world:setCallbacks(beginContact, endContact, preSolve, postSolve)

        local margin = 20

        objects.balls = {}
        for i = 1, 120 do
            objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * height / 2, ballRadius)
        end


        objects.blocks = {}
        for i = 1, 120 do
            objects.blocks[i] = makeBlock(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * height / 2, ballRadius)
        end


        angularVelocity = 2
        objects.carousel = makeCarousell(width / 2, height / 2, width / 4, width / 20, angularVelocity)
        objects.carousel2 = makeCarousell(width / 2 + width / 4, height / 2, width / 4, width / 20, -angularVelocity)

        objects.ground = makeChainGround()

        objects.ground.fixture:setUserData(makeUserData("ground"))

        if false then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, height - (height / 10), "static")
            objects.ground.shape = love.physics.newRectangleShape(width, height / 4)
            objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
            objects.ground.fixture:setUserData(makeUserData("ground"))
        end
        objects.ground.body:setTransform(width / 2, height - (height / 10), 0) --  <= here we se an anlgle to the ground!!
        objects.ground.fixture:setFriction(0.01)
    end
    ----
    ---- VEHICLES
    -----
    if number == 2 then
        world:setCallbacks(beginContact, endContact, preSolve, postSolve)

        snapJoints = {}
        connectors = {}

        local margin = 20
        -- objects.border = makeBorderChain(width, height, margin)

        objects.ground = makeChainGround()
        objects.ground.fixture:setUserData(makeUserData("ground"))
        if true then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, -500, "static")
            objects.ground.shape = love.physics.newRectangleShape(width * 10, height / 4)
            objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
            objects.ground.fixture:setUserData(makeUserData("ground"))
            objects.ground.fixture:setFriction(1)
        end


        objects.blocks = {}
        for i = 1, 3 do
            objects.blocks[i] = makeBlock(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * -height / 2, ballRadius)
        end

        for i = 1, 10 do
            local body = love.physics.newBody(world, i * 100, -2000, "dynamic")
            local shape = love.physics.newPolygonShape(getRandomConvexPoly(130, 8)) --love.physics.newRectangleShape(width, height / 4)
            local fixture = love.physics.newFixture(body, shape, 2)
        end

        objects.balls = {}

        for i = 1, 1 do
            ballRadius = 10 --love.math.random() * 300 + 130
            objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * -height / 2, ballRadius)
        end



        for i = 1, 5 do
            makeBalloon(i * 100, -1000)
        end

        for i = 1, 3 do
            makeChain(i * 20, -3000, 8)
        end

        for i = 1, 10 do
            makeVehicle(width / 2 + i * 400, -3000)
        end

        for i = 1, 50 do
            table.insert(box2dGuys, makeGuy(i * 200, -1000, i))
        end

        for i = 1, 3 do
            makeSnappyElastic(i * 100, -1500)
        end


        makeSeeSaw(6000, -500)


        ballRadius = love.physics.getMeter() / 4
        if false then
            for i = 1, 20 do
                objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                        margin + love.math.random() * height / 2, ballRadius)
            end
        end
    end

    if number == 3 then
        world:setCallbacks(beginContact, endContact, preSolve, postSolve)

        snapJoints = {}
        connectors = {}

        local margin = 20
        -- objects.border = makeBorderChain(width, height, margin)

        objects.ground = makeChainGround()
        objects.ground.fixture:setUserData(makeUserData("ground"))

        if true then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, -2000, "static")
            objects.ground.shape = love.physics.newRectangleShape(width * 10, height / 4)
            objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
            objects.ground.fixture:setUserData(makeUserData("ground"))
            objects.ground.fixture:setFriction(1)
        end


        for i = 1, 2 do
            table.insert(box2dGuys, makeGuy(i * 200, -1000, i))
        end

        for i = 1, 5 do
            makeBalloon(i * 100, -1000)
        end
    end

    example = number
end

function love.load()
    local font = love.graphics.newFont('WindsorBT-Roman.otf', 40)
    love.graphics.setFont(font)

    vlooienspel = love.graphics.newImage('vlooienspel.jpg')
    pedal = love.graphics.newImage('pedal.jpg')

    -- before these were local but that didnt work with lurker
    -- all of these are relevant to the vlooienspel experiment, and not to others (I think)

    disabledContacts = {}
    pointerJoints = {}
    connectorCooldownList = {}


    image3 = love.graphics.newImage("assets/leg1.png")
   --image3:setMipmapFilter( 'nearest', 1 )
   mesh3 = createTexturedTriangleStrip(image3)

   image4 = love.graphics.newImage("assets/leg7.png")
   --image3:setMipmapFilter( 'nearest', 1 )
   mesh4 = createTexturedTriangleStrip(image4)

   image5 = love.graphics.newImage("assets/leg2.png")
   --image3:setMipmapFilter( 'nearest', 1 )
   mesh5 = createTexturedTriangleStrip(image5)



    example = nil
    startExample(3)
    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2, w * 2, h * 2)
    --grabDevelopmentScreenshot()
end

local function pointerReleased(id, x, y)
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        -- if false then
        if mj.id == id then
            if (mj.joint) then
                if (mj.jointBody) then
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
                            -- print(l)
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
            --   end
        end
    end
    killMouseJointIfPossible(id)
end

function love.touchreleased(id, x, y)
    pointerReleased(id, x, y)
end

function love.mousereleased(x, y)
    -- now we have to find a few things out to check if i want to shoot my thing
    -- first off, are we below the ground ?

    pointerReleased('mouse', x, y)
end

function killMouseJointIfPossible(id)
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

function love.touchpressed(id, x, y)
    pointerPressed(id, x, y)
end

function love.mousepressed(x, y)
    pointerPressed('mouse', x, y)
end

function pointerPressed(id, x, y)
    local wx, wy = cam:getWorldCoordinates(x, y)
    local hitAny = false
    local bodies = world:getBodies()

    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
            local hitThisOne = fixture:testPoint(wx, wy)
            local isSensor = fixture:isSensor()
            if (hitThisOne and not isSensor) then
                killMouseJointIfPossible(id)

                table.insert(pointerJoints, makePointerJoint(id, body, wx, wy))

                local vx, vy = body:getLinearVelocity()
                -- body:setPosition(body:getX(), body:getY() - 10)

                hitAny = true
            end
        end
    end

    if hitAny == false then killMouseJointIfPossible(id) end
end

function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return palette[colors.peach]
    end
    if body:getType() == 'dynamic' then
        return palette[colors.blue]
    end
    if body:getType() == 'static' then
        return palette[colors.green]
    end
    --fixture:getShape():type() == 'PolygonShape' then
end

function drawWorld(world)
    -- get the current color values to reapply
    local r, g, b, a = love.graphics.getColor()
    -- alpha value is optional
    alpha = .8
    -- Colliders debug
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    love.graphics.setLineWidth(3)
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
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
end

function createTexturedTriangleStrip(image)
    -- this assumes an strip that is oriented vertically
    
    local w, h = image:getDimensions( )
    local vertices = {}
    local segments = 8
    local hPart = h / (segments-1)
    local hv = 1/ (segments-1)
    local runningHV = 0
    local runningHP = 0
    local index = 0
    for i =1, segments do
       
       vertices[index + 1] = {-w/2, runningHP, 0,runningHV }
       vertices[index +  2] = {w/2, runningHP, 1,runningHV }
 
       runningHV = runningHV + hv
       runningHP = runningHP + hPart
       index = index + 2
    end
 
    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)
 
    return mesh
 end


function texturedCurve(curve, image, mesh) 

    local dl = curve:getDerivative()
   --local curveR = love.math.newBezierCurve({w, 0, w+offsetW, h/2, w, h})
   --local dr = curveR:getDerivative()

   
   
   --local curve = love.math.newBezierCurve({mx, my,  mx+50, my + 100, mx, my + 5})
   for i =1, 1 do


    local w, h = image:getDimensions( )
      local count = mesh:getVertexCount( )

      for j =1, count, 2 do

         local index = (j-1)/ (count-2)
         local xl,yl = curve:evaluate(index)
         --local xr,yr = curveR:evaluate(index) 

         local dx, dy = dl:evaluate(index)
         local a = math.atan2(dy,dx) + math.pi/2
         local a2 = math.atan2(dy,dx) - math.pi/2

         local line  = w/2.5  --- here we can make the texture wider!! 
         local x2 =   xl + line * math.cos(a)
         local y2 =  yl + line * math.sin(a)
         local x3 =   xl + line * math.cos(a2)
         local y3 =  yl + line * math.sin(a2)
         
         if false then
         --love.graphics.line(xl,yl, x2, y2)
         --love.graphics.line(xl,yl, x3, y3)
         end
         
         local x, y, u, v, r, g, b, a = mesh:getVertex(j )
         mesh:setVertex(j, {x2, y2, u,v})
         x, y, u, v, r, g, b, a = mesh:getVertex(j +1)
         mesh:setVertex(j+1, {x3, y3, u,v})
      end
    end
      --love.graphics.draw(mesh2, mx, my, 0, flip, .5)
      --love.graphics.draw(mesh2, mx+488, my, 0, flip, .5)
      love.graphics.draw(mesh, 0, 0, 0, 1, 1)
end

function drawSkinOver(box2dGuy) 
   -- print(inspect(box2dGuy))
    love.graphics.setColor(0,0,0,1)
   local ax, ay = box2dGuy.luleg:getPosition()
   local bx, by = box2dGuy.llleg:getPosition()
   local cx, cy = box2dGuy.lfoot:getPosition()


    local curve = love.math.newBezierCurve({ax,ay, bx,by,bx,by,cx,cy})
    love.graphics.line( curve:render())


    texturedCurve(curve, image3, mesh3)




    -----
    local ax, ay = box2dGuy.ruleg:getPosition()
    local bx, by = box2dGuy.rlleg:getPosition()
    local cx, cy = box2dGuy.rfoot:getPosition()
 
 
     local curve = love.math.newBezierCurve({ax,ay, bx,by, bx,by,cx,cy})
     love.graphics.line( curve:render())

    ----
    local ax, ay = box2dGuy.luarm:getPosition()
    local bx, by = box2dGuy.llarm:getPosition()
    local cx, cy = box2dGuy.lhand:getPosition()
 

     local curve = love.math.newBezierCurve({ax,ay, bx,by, bx,by, bx,by,cx,cy})
     love.graphics.line( curve:render())

     texturedCurve(curve, image5, mesh5)



      ----
    local ax, ay = box2dGuy.ruarm:getPosition()
    local bx, by = box2dGuy.rlarm:getPosition()
    local cx, cy = box2dGuy.rhand:getPosition()
 

     local curve = love.math.newBezierCurve({ax,ay, bx,by, bx,by, bx,by,cx,cy})
     love.graphics.line( curve:render())

     texturedCurve(curve, image5, mesh5)
end

function drawCenteredBackgroundText(str)
    local width, height = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local textw, wrappedtext = font:getWrap(str, width)
    local texth = font:getHeight() * #wrappedtext
    love.graphics.print(str, width / 2 - textw / 2, height / 2 - texth / 2)
end

function getIndexOfConnector(conn)
    for i = 1, #connectors do
        if connectors[i].at == conn then
            return i
        end
    end
    return -1
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    drawMeterGrid()

    if example == 1 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(vlooienspel, width / 2, height / 4, 0, 1, 1,
            vlooienspel:getWidth() / 2, vlooienspel:getHeight() / 2)
        love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
        drawCenteredBackgroundText('Pull back to aim and shoot.')
        cam:push()
        drawWorld(world)
        cam:pop()
    end
    if example == 2 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(pedal, width / 2, height / 4, 0, 1, 1,
            pedal:getWidth() / 2, pedal:getHeight() / 2)
        love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
        drawCenteredBackgroundText('Make me some vehicles.')
        cam:push()
       -- print(#box2dGuys)
        drawWorld(world)
        local tlx, tly =  cam:getWorldCoordinates(-200,0)
        local brx, bry =  cam:getWorldCoordinates(width+200, height)
        for i = 1 , #box2dGuys do
            local x, y = box2dGuys[i].torso:getPosition()
            
       
            if x >= tlx and x <=  brx then
               drawSkinOver(box2dGuys[i])
            end

            end

        cam:pop()


        love.graphics.print(love.timer.getFPS(), 0, 0)
    end



    if example == 3 then
        love.graphics.setColor(1, 1, 1)

        love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
        drawCenteredBackgroundText('Body moving, changing.\nPress q & w to change a body.')
        cam:push()

        drawWorld(world)
        for i = 1 , #box2dGuys do
            print(box2dGuys[i].torso:getPosition())
        drawSkinOver(box2dGuys[i])
        end
        

        cam:pop()


        love.graphics.print(love.timer.getFPS(), 0, 0)
    end

    cam:push()

    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if mj.positionOfLastDisabledContact and #mj.positionOfLastDisabledContact > 0 then
            -- print(inspect(positionOfLastDisabledContact))
            love.graphics.circle('fill', mj.positionOfLastDisabledContact[1], mj.positionOfLastDisabledContact[2], 10)
            if (mj.bodyLastDisabledContact) then
                local posx, posy = mj.bodyLastDisabledContact:getBody():getPosition()
                love.graphics.line(mj.positionOfLastDisabledContact[1], mj.positionOfLastDisabledContact[2], posx, posy)
            end
        end
    end
    cam:pop()
end

function drawMeterGrid()
    local width, height = love.graphics.getDimensions()
    local ppm = love.physics.getMeter() * cam.scale
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3], 0.2)
    for x = 0, width, ppm do
        love.graphics.line(x, 0, x, height)
    end
    for y = 0, height, ppm do
        love.graphics.line(0, y, width, y)
    end
end

function rotateToHorizontal(body, desiredAngle, divider)
    local DEGTORAD = 1 / 57.295779513
    --https://www.iforce2d.net/b2dtut/rotate-to-angle
    if true then
        local angle = body:getAngle()
        local nextAngle = angle + body:getAngularVelocity() / divider

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

        local torque = body:getInertia() * desiredAngularVelocity / (1 / divider)
        body:applyTorque(torque)
    end
end

local function getRidOfBigRotationsInBody(body)
    local a = body:getAngle()

    if true then
        if a > (2 * math.pi) then
            a = a - (2 * math.pi)
            body:setAngle(a)
        end
        if a < -(2 * math.pi) then
            a = a + (2 * math.pi)
            body:setAngle(a)
        end
    end
end


function maybeConnectThisConnector(f, mj)
    local found = false


    for j = 1, #connectors do
        if connectors[j].to and connectors[j].to == f then
            found = true
        end
    end

    if found == false then
        --print(mj.jointBody, f:getBody())
        local pos1 = getCentroidOfFixture(f:getBody(), f)
        local done = false

        for j = 1, #connectors do
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

function love.update(dt)
    -- lurker.update()



    -- this is way too agressive, maybe firgure out a way where i go 1 or 2 nodes up and down to check
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
    if false then
        if objects.carbody then
            if (carIsTouching < 1) then
                rotateToHorizontal(objects.carbody.body, 0, 10)
            end
        end
    end




    local bodies = world:getBodies()

    local upsideDown = false

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
            --print(isBeingPointerJointed)
            if true and not isBeingPointerJointed then
                if fixture:getUserData() then
                    if fixture:getUserData().bodyType == 'balloon' then
                        --getRidOfBigRotationsInBody(body)
                        --local desired = upsideDown and -math.pi or 0
                        --rotateToHorizontal(body, desired, 50)
                        local up = -9.81 * love.physics.getMeter() * 4.5

                        body:applyForce(0, up)
                    end


                    if fixture:getUserData().bodyType == 'torso' then
                        getRidOfBigRotationsInBody(body)
                        local desired = upsideDown and -math.pi or 0
                        rotateToHorizontal(body, desired, 50)
                    end

                    if not upsideDown then
                        if fixture:getUserData().bodyType == 'neck' then
                            getRidOfBigRotationsInBody(body)
                             rotateToHorizontal(body, -math.pi, 10)
                        end

                        if fixture:getUserData().bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, -math.pi, 15)
                        end
                    end

                    if not upsideDown then
                        if fixture:getUserData().bodyType == 'legpart' then
                            getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 30)
                        end
                        if fixture:getUserData().bodyType == 'armpart' then
                            getRidOfBigRotationsInBody(body)
                        end
                    end
                    if upsideDown then
                        if fixture:getUserData().bodyType == 'armpart' then
                            getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, 0, 50)
                        end
                        if fixture:getUserData().bodyType == 'legpart' then
                            getRidOfBigRotationsInBody(body)
                            rotateToHorizontal(body, math.pi, 10)
                        end
                    end

                    if false then
                        if fixture:getUserData().bodyType == 'head' then
                            getRidOfBigRotationsInBody(body)

                            rotateToHorizontal(body, math.pi, 15)
                        end
                    end
                end
            end
        end
    end

    -- snapJoint will break only if AND you are interacting on it AND the force is bigger then X

    --print(#connectors)
    if connectors then
        for i = #connectors, 1, -1 do
            -- we can only break a  joint if we have one
            -- print(i, connectors[i].joint, connectors[i].to)

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

                local breakForce = 100000 * math.max(1, (b1:getMass() * b2:getMass()))
                if l > breakForce and found then
                    connectors[i].joint:destroy()
                    connectors[i].joint = nil

                    connectors[i].to = nil
                    print('broke it', i, l)
                    table.insert(connectorCooldownList, { runningFor = 0, index = i })
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

    if vehiclePedalConnection then
        for i = 1, #vehiclePedalConnection do
            local angle = vehiclePedalConnection[i].wheelJoint:getJointAngle()
            vehiclePedalConnection[i].pedalWheel:setAngle(angle / 3)
        end
    end

    world:update(dt)
    local w, h = love.graphics.getDimensions()
    if false then
        if (objects.carbody) then
            camera.centerCameraOnPosition(objects.carbody.body:getX(), objects.carbody.body:getY(), w * 2, h * 2)
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if love.keyboard.isDown('space') then
        local x, y = cam:getTranslation()
        cam:setTranslation(x - dx / cam.scale, y - dy / cam.scale)
    end
end

function love.wheelmoved(dx, dy)
    if true then
        local newScale = cam.scale * (1 + dy / 10)
        if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
        end
    end
end

function love.resize(w, h)
    world:update(0)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == '1' then startExample(1) end
    if k == '2' then startExample(2) end
    if k == '3' then startExample(3) end
    if (k == 'q' and example == 3) then
        -- local impulse = body:getInertia() * desiredAngularVelocity
        -- body:applyAngularImpulse(impulse)
        local body = box2dGuys[2].torso
        -- body:applyLinearImpulse(0, -10000)

        local oldLegLength = creation.upLeg.h + creation.lowLeg.h + creation.torso.h


        --creation.upLeg.h = 15 + love.math.random() * 400
        --- creation.lowLeg.h = 15 + love.math.random() * 400
        --creation.upLeg.w = 15 + love.math.random() * 100
        --creation.lowLeg.w = 15 + love.math.random() * 100
        creation.torso.h = 50 + love.math.random() * 500
        creation.torso.w = 50 + love.math.random() * 500


        local newLegLength = creation.upLeg.h + creation.lowLeg.h + creation.torso.h
        local bx, by = body:getPosition()
        --print('bx/by', bx, by)
        if (newLegLength > oldLegLength) then
            body:setPosition(bx, by - (newLegLength - oldLegLength) * 1.2)
        end
        --    creation.upArm.h = 150 + love.math.random() * 100
        --    creation.lowArm.h = 150 + love.math.random() * 100
        --    creation.foot.h = 50 + love.math.random() * 100
        --    creation.hand.h = 150 + love.math.random() * 100
        --    creation.head.w = 150 + love.math.random() * 100
        --    creation.head.h = 150 + love.math.random() * 100
            creation.neck.w = 12 + love.math.random() * 20
            creation.neck.h = 100 + love.math.random() * 200

        --updateHead(box2dGuys[1], 1)
        --updateNeck(box2dGuys[1], 1)
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'head')
        genericBodyPartUpdate(box2dGuys[2], 2, 'neck')
        genericBodyPartUpdate(box2dGuys[2], 2, 'torso')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'lhand')
        --  genericBodyPartUpdate(box2dGuys[1], 1, 'ruarm')
        --genericBodyPartUpdate(box2dGuys[2], 2, 'lfoot')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'luarm')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'llarm')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'luleg')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'ruleg')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'llleg')
        -- genericBodyPartUpdate(box2dGuys[2], 2, 'rlleg')
        --    genericBodyPartUpdate(box2dGuys[2], 2, 'ruleg')
    end
    if (k == 'w' and example == 3) then
        --print(inspect(box2dGuys[2]))
        --print('should randomize stuff on the second guy')
    end
    if example == 2 then
        if false then
            if k == 'left' then
                motorSpeed = motorSpeed - 100
                objects.joint1:setMotorSpeed(motorSpeed)
                objects.joint2:setMotorSpeed(motorSpeed)
            end
            if k == 'right' then
                motorSpeed = motorSpeed + 100
                objects.joint1:setMotorSpeed(motorSpeed)
                objects.joint2:setMotorSpeed(motorSpeed)
            end
            if k == 'up' then
                motorTorque = motorTorque + 100
                objects.joint1:setMaxMotorTorque(motorTorque)
                objects.joint2:setMaxMotorTorque(motorTorque)
            end
            if k == 'down' then
                motorTorque = motorTorque - 100
                objects.joint1:setMaxMotorTorque(motorTorque)
                objects.joint2:setMaxMotorTorque(motorTorque)
            end
            if k == 's' then
                if objects.carbody then
                    local angle = objects.carbody.body:getAngle()
                    --print(angle)

                    local n = Vector.angled(Vector(400, 0), angle)
                    objects.carbody.body:applyLinearImpulse(n.x, n.y)
                    --local delta = Vector(x1 - x2, y1 - y2)
                end
            end
        end
    end
end
