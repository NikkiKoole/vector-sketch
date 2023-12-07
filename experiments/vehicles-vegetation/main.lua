package.path = package.path .. ";../../?.lua"

require 'lib.printC'
local lurker          = require 'vendor.lurker'
lurker.quiet          = true
local inspect         = require 'vendor.inspect'
Vector                = require 'vendor.brinevector'
local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'
local generatePolygon = require('lib.generate-polygon').generatePolygon
local geom            = require 'lib.geom'
local bbox            = require 'lib.bbox'
local mesh            = require 'lib.mesh'
local ui              = require 'lib.ui'
require 'box2dGuyCreation'
require 'texturedBox2d'
local creation = getCreation()
local canvas   = require 'lib.canvas'
local text     = require 'lib.text'
require 'palette'
local gradient    = require 'lib.gradient'
local skygradient = gradient.makeSkyGradient(10)
local manual_gc   = require 'vendor.batteries.manual_gc'

PROF_CAPTURE      = false
prof              = require 'vendor.jprof'
ProFi             = require 'vendor.ProFi'

if true then
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        --print(a, b, c, d, e)
    until a == "focus" or a == 'mousepressed'
end
love.math.setRandomSeed(2)
--love.math.setRandomSeed(love.timer.getTime())
palettes   = {}
local base = {
    '020202', '333233', '814800', 'e6c800', 'efebd8',
    '808b1c', '1a5f8f', '66a5bc', '87727b', 'a23d7e',
    'f0644d', 'fa8a00', 'f8df00', 'ff7376', 'fef1d0',
    'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
    '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
    'CB433A', '8F4839', '8A934E', '69445D', 'EEC488',
    'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
    '798091', '4C5575', '6E4431', '626964', '613D41',
}

local base = {
    '020202',
    '4f3166', '6f323a', '872f44', 'efebd8', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
    'dca941', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
    '938541', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
    '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
    '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'a95c42', 'c37c61',
    'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
    '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'd76656', 'b16890'

}

local base = {
    '020202',
    '4f3166', '69445D', '613D41', 'efebd8', '6f323a', '872f44', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
    'dca941', 'e6c800', 'f8df00', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
    '938541', '808b1c', '8A934E', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
    '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
    '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'CB433A', 'a95c42',
    'c37c61', 'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
    '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'f0644d', 'ff7376', 'd76656', 'b16890',
    '020202', '333233', '814800', 'efebd8',
    '1a5f8f', '66a5bc', '87727b', 'a23d7e',
    'fa8a00', 'fef1d0',
    'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
    '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
    '8F4839', 'EEC488',
    'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
    '798091', '4C5575', '6E4431', '626964',
}




textures = {
    love.graphics.newImage('assets/bodytextures/texture-type0.png'),
    love.graphics.newImage('assets/bodytextures/texture-type2t.png'),
    love.graphics.newImage('assets/bodytextures/texture-type1.png'),
    love.graphics.newImage('assets/bodytextures/texture-type3.png'),
    love.graphics.newImage('assets/bodytextures/texture-type4.png'),
    love.graphics.newImage('assets/bodytextures/texture-type5.png'),
    love.graphics.newImage('assets/bodytextures/texture-type6.png'),
    love.graphics.newImage('assets/bodytextures/texture-type7.png'),

}

function hex2rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255
end

for i = 1, #base do
    local r, g, b = hex2rgb(base[i])
    table.insert(palettes, { r, g, b })
end

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
    pointerJoint.joint:setDampingRatio(.5)
    pointerJoint.joint:setMaxForce(5000000)
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

function isContactThatShouldJustAffectOneParty(contact)
    local fixtureA, fixtureB = contact:getFixtures()
    if fixtureA:getUserData() and fixtureB:getUserData() then
        if fixtureA:getUserData().bodyType == 'no-effect' then
            print('jo!')
            return true
        end
        --print(fixtureA:getUserData().bodyType, fixtureB:getUserData().bodyType)
    else
    end
end

function beginContact(a, b, contact)
    isContactThatShouldJustAffectOneParty(contact)
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
                pointerJoints[i].bodyLastDisabledContact = bodyLastDisabledContact
                pointerJoints[i].positionOfLastDisabledContact = point
                table.insert(disabledContacts, contact)
            end
        end
    end
    if isContactBetweenGroundAndCarGroundSensor(contact) then
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
    --print(inspect(part))
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
            --print('dcwjicojie')
            offsetX = part.metaOffsetX
            offsetY = part.metaOffsetY
        end

        for i = 1, #part.metaPoints do
            table.insert(flatted, (offsetX + part.metaPoints[i][1]) * wscale)
            table.insert(flatted, (offsetY + part.metaPoints[i][2]) * hscale)
        end
        return love.physics.newPolygonShape(flatted)
    else
        --  print(inspect(part))
        return makeShape(part.shape, part.w, part.h)
    end
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
    elseif (shapeType == 'capsule2') then
        -- ipv hardcoded 10 i use w/5
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0,
                0))
    elseif (shapeType == 'capsule3') then
        -- ipv hardcoded 10 i use w/5
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0,
                -h / 2))
    elseif (shapeType == 'trapezium') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, 0)
    elseif (shapeType == 'trapezium2') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, h / 2)
    end
end

function makeAndAddConnector(parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = makeRectPoly2(size, size2, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 0)
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

function makeSpine(x, y, amt, groupId, totalHeight)
    local linkHeight = totalHeight / (amt)
    local linkWidth = 50
    local dir = 1
    local count = 1

    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = makeShape('rect2', linkWidth, linkHeight)
        local fixture = love.physics.newFixture(body, shape, .3)
        fixture:setFilterData(1, 65535, -1 * groupId)
        fixture:setUserData(makeUserData('neck'))
        -- body:setAngle(-math.pi)
        count = count + 1
        return body
    end

    local lastLink = makeLink(x, y)
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
    local linkHeight = totalHeight / (amt)
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

    ball.shape = love.physics.newCircleShape(480)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 0)
    --  ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData(makeUserData("balloon"))
    -- ball.fixture:setFriction(.5)

    makeAndAddConnector(ball.body, 0, 600, nil, 50)
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

function makeBodyFromData(data, x, y)
    local ball           = {}
    ball.body            = love.physics.newBody(world, x, y, "dynamic")

    local flatted        = {}

    local requiredWidth  = 300
    local requiredHeight = 300


    local tlx, tly, brx, bry = bbox.getPointsBBox(data.points)
    local bbw = (brx - tlx)
    local bbh = (bry - tly)

    local wscale = requiredWidth / bbw
    local hscale = requiredHeight / bbh

    ball.scaleData = {
        wscale = wscale,
        hscale = hscale
    }

    for i = 1, #data.points do -- these are them meta points drawn in vector sketch
        table.insert(flatted, data.points[i][1] * wscale)
        table.insert(flatted, data.points[i][2] * hscale)
    end

    ball.shape = love.physics.newPolygonShape(flatted)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.textureData = data

    return ball
end

function makeGrassThing(x, y, i)
    local imgs = plantImages
    local index = (i % #imgs) + 1
    local w, h = imgs[index]:getDimensions()
    w = w / 3
    h = h / 3
    local body = love.physics.newBody(world, x, y, "static")
    local shape1 = makeRectPoly2(5, 5, 0, 0)
    local fixture = love.physics.newFixture(body, shape1, 1)
    fixture:setSensor(true)
    local grass = love.physics.newBody(world, x, y, "dynamic")
    local shape1 = makeRectPoly2(w, h, -w / 2, -h / 2)
    local fixture = love.physics.newFixture(grass, shape1, .1)
    fixture:setFilterData(1, 65535, -9999)
    fixture:setUserData(makeUserData("keep-rotation", { rotation = 0 + love.math.random() * 0.4 - 0.2 }))
    local joint1 = love.physics.newRevoluteJoint(grass, body, x - w / 2, y, false)

    return { grass }
end

function makeVehicle(x, y)
    local carBodyHeight = 150
    local carBodyWidth  = 800
    local carbody       = love.physics.newBody(world, x, y, "dynamic")
    local shape         = makeCarShape(carBodyWidth, carBodyHeight, 0, 0) --makeRectPoly2(300, 100, 0, 0)  --love.physics.newRectangleShape(300, 100)
    local fixture       = love.physics.newFixture(carbody, shape, .5)

    fixture:setUserData(makeUserData("carbody"))
    fixture:setFriction(1)
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

local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end
function createRandomColoredBlackOutlineTexture(url)
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[math.ceil(math.random() * #palettes)]
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[math.ceil(math.random() * #palettes)]

    return love.graphics.newImage(helperTexturedCanvas(url,
            tex1, pal1, 5,
            tex2, pal2, 2,
            0, 1,
            palettes[1], 5,
            1, 1, nil, nil))
end

function createBlackColoredBlackOutlineTexture(url)
    -- todo make this more optimal and readable, 5 is white in any case
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[1]
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[1]

    return love.graphics.newImage(helperTexturedCanvas(url,
            tex1, pal1, 5,
            tex2, pal2, 2,
            0, 1,
            palettes[1], 5,
            1, 1, nil, nil))
end

function createNonColoredRandomOutlineTexture(url)
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[5]
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[5]

    local rnd = palettes[math.ceil(math.random() * #palettes)]
    return love.graphics.newImage(helperTexturedCanvas(url,
            tex1, pal1, 5,
            tex2, pal2, 2,
            0, 1,
            rnd, 5,
            1, 1, nil, nil))
end

function createWhiteColoredBlackOutlineTexture(url)
    -- todo make this more optimal and readable, 5 is white in any case
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[5]
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[5]

    return love.graphics.newImage(helperTexturedCanvas(url,
            tex1, pal1, 5,
            tex2, pal2, 2,
            0, 1,
            palettes[1], 5,
            1, 1, nil, nil))
end

--- helper texture canvas
-- @param url

function helperTexturedCanvas(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, optionalSettings,
                              renderPatch)
    --print(url)
    local img = mesh.getImage(url, optionalSettings)
    local maskUrl = getPNGMaskUrl(url)
    local mask = mesh.getImage(maskUrl)
    -- print(url)
    -- print(love.graphics.getDPIScale())
    local cnv = canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy,
            renderPatch)

    return cnv
end

function randomFaceParts()
    eyeIndex = math.ceil(love.math.random() * #eyedata)
    changeMetaTexture('eye', eyedata[eyeIndex])
    --  print(#eyedata, eyeIndex)
    creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
    creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
    eyeCanvas = createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)

    pupilIndex = math.ceil(love.math.random() * #pupildata)
    changeMetaTexture('pupil', pupildata[pupilIndex])

    creation.pupil.w = mesh.getImage(creation.pupil.metaURL):getHeight() / 2
    creation.pupil.h = mesh.getImage(creation.pupil.metaURL):getWidth() / 2
    pupilCanvas = createBlackColoredBlackOutlineTexture(creation.pupil.metaURL)


    noseIndex = math.ceil(love.math.random() * #pupildata)
    changeMetaTexture('nose', nosedata[noseIndex])
    creation.nose.w = mesh.getImage(creation.nose.metaURL):getHeight()
    creation.nose.h = mesh.getImage(creation.nose.metaURL):getWidth()
    noseCanvas = createRandomColoredBlackOutlineTexture(creation.nose.metaURL)


    upperlipIndex = math.ceil(love.math.random() * #upperlipdata)
    changeMetaTexture('upperlip', upperlipdata[upperlipIndex])
    creation.upperlip.w = mesh.getImage(creation.upperlip.metaURL):getHeight()
    creation.upperlip.h = mesh.getImage(creation.upperlip.metaURL):getWidth()
    upperlipCanvas = createRandomColoredBlackOutlineTexture(creation.upperlip.metaURL)


    lowerlipIndex = math.ceil(love.math.random() * #lowerlipdata)
    changeMetaTexture('lowerlip', lowerlipdata[lowerlipIndex])
    creation.lowerlip.w = mesh.getImage(creation.lowerlip.metaURL):getHeight()
    creation.lowerlip.h = mesh.getImage(creation.lowerlip.metaURL):getWidth()
    lowerlipCanvas = createRandomColoredBlackOutlineTexture(creation.lowerlip.metaURL)

    teethIndex = math.ceil(love.math.random() * #teethdata)
    changeMetaTexture('teeth', teethdata[teethIndex])
    -- print(creation.teeth.metaURL)
    creation.teeth.w = mesh.getImage(creation.teeth.metaURL):getHeight()
    creation.teeth.h = mesh.getImage(creation.teeth.metaURL):getWidth()
    teethCanvas = createWhiteColoredBlackOutlineTexture(creation.teeth.metaURL)

    browIndex = math.ceil(love.math.random() * #eyebrowsdata)
    changeMetaTexture('brow', eyebrowsdata[browIndex])
    --print(inspect(eyebrowsdata[browIndex]))
    -- print(creation.brow.metaURL)
    creation.brow.w = mesh.getImage(creation.brow.metaURL):getHeight()
    creation.brow.h = mesh.getImage(creation.brow.metaURL):getWidth()
    browCanvas = createNonColoredRandomOutlineTexture(creation.brow.metaURL)
    --browCanvas = createWhiteColoredBlackOutlineTexture(creation.brow.metaURL)
end

function startExample(number)
    local width, height = love.graphics.getDimensions()
    love.physics.setMeter(500)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    objects = {}
    ballRadius = love.physics.getMeter() / 4
    vehiclePedalConnection = {}
    box2dGuys = {}
    box2dTorsos = {} -- these are th
    connectors = {}
    pointerJoints = {}
    grass = {}
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

        if true then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, -3500, "static")
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

        for i = 1, 20 do
            ballRadius = 50 --love.math.random() * 300 + 130
            objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * -height / 2, ballRadius)
        end



        for i = 1, 5 do
            makeBalloon(i * 100, -1000)
        end

        for i = 1, 3 do
            --     makeChain(i * 20, -3000, 8)
        end

        for i = 1, 10 do
            makeVehicle(width / 2 + i * 400, -3000)
        end

        for i = 1, 50 do
            table.insert(box2dGuys, makeGuy(i * 800, -1300, i))
        end

        for i = 1, 3 do
            --     makeSnappyElastic(i * 100, -1500)
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
        local w, h = love.graphics.getDimensions()
        camera.setCameraViewport(cam, w, h)
        camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)

        world:setCallbacks(beginContact, endContact, preSolve, postSolve)

        snapJoints = {}
        connectors = {}

        local margin = 20
        local w, h = love.graphics.getDimensions()


        local bw, bh = borderImage:getDimensions()
        local sx = w / bw
        local sy = h / bh

        local bmpTopThick = 40 * sy
        local bmpBottomThick = 40 * sy
        local bmpLeftThick = 50 * sx
        local bmpRightThick = 40 * sx


        local camtlx, camtly = cam:getWorldCoordinates(bmpLeftThick, bmpTopThick)
        local cambrx, cambry = cam:getWorldCoordinates(w - bmpRightThick, h - bmpBottomThick)
        local camcx, camcy = cam:getWorldCoordinates(w / 2, h / 2)

        local wallThickness = 5000
        local halft = wallThickness / 2
        local screenWorldWidth = cambrx - camtlx
        local screenWorldHeight = cambry - camtly
        local length = math.max(screenWorldWidth, screenWorldHeight) * 2


        local top = love.physics.newBody(world, width / 2, camtly - halft, "static")
        local topshape = love.physics.newRectangleShape(length, wallThickness)
        local topfixture = love.physics.newFixture(top, topshape, 1)

        local bottom = love.physics.newBody(world, width / 2, cambry + halft, "static")
        local bottomshape = love.physics.newRectangleShape(length, wallThickness)
        local bottomfixture = love.physics.newFixture(bottom, bottomshape, 1)

        local left = love.physics.newBody(world, camtlx - halft, height / 2, "static")
        local leftshape = love.physics.newRectangleShape(wallThickness, length)
        local leftfixture = love.physics.newFixture(left, leftshape, 1)

        local right = love.physics.newBody(world, cambrx + halft, height / 2, "static")
        local rightshape = love.physics.newRectangleShape(wallThickness, length)
        local rightfixture = love.physics.newFixture(right, rightshape, 1)


        local dist = 30 --  screenWorldWidth / 200
        sprietWidthAmt = screenWorldWidth / dist
        local startX = camtlx
        local startY = cambry + 200
        for i = 1, sprietWidthAmt do
            sprietUnder[i] = { startX + i * dist, startY - 500, math.ceil(love.math.random() * #spriet), 0, 2.1 }
            sprietUnder[sprietWidthAmt + i] = { startX + i * dist, startY - 400, math.ceil(love.math.random() * #spriet),
                0, 1.8 }
            sprietUnder[(sprietWidthAmt * 2) + i] = { startX + i * dist, startY - 300,
                math.ceil(love.math.random() * #spriet), 0, 1.5 }
            sprietUnder[(sprietWidthAmt * 3) + i] = { startX + i * dist, startY - 200,
                math.ceil(love.math.random() * #spriet), 0, 1.2 }
            sprietOver[i] = { startX + i * dist, startY - 100, math.ceil(love.math.random() * #spriet), 0, 1 }
        end



        --for i = 1, 100 do
        --table.insert(grass, makeGrassThing(i * 40, -500, i))
        --end

        data = loadVectorSketch('assets/bodies.polygons.txt', 'bodies')
        bodyRndIndex = math.ceil(love.math.random() * #data)

        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        changeMetaTexture('torso', data[bodyRndIndex])

        torsoCanvas = createRandomColoredBlackOutlineTexture(creation.torso.metaURL)
        creation.torso.w = mesh.getImage(creation.torso.metaURL):getWidth() * 1
        creation.torso.h = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier

        if true then
            headRndIndex = math.ceil(love.math.random() * #data)

            local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                    data[headRndIndex].points)

            changeMetaPoints('head', flippedFloppedHeadPoints)
            changeMetaTexture('head', data[headRndIndex])
            headCanvas = createRandomColoredBlackOutlineTexture(creation.head.metaURL)
        end
        --
        feetdata = loadVectorSketch('assets/feet.polygons.txt', 'feet')

        local footIndex = 12 --math.ceil(math.random() * #feetdata)

        changeMetaTexture('lfoot', feetdata[footIndex])
        creation.lfoot.w = mesh.getImage(creation.lfoot.metaURL):getHeight() / 2
        creation.lfoot.h = mesh.getImage(creation.lfoot.metaURL):getWidth() / 2

        changeMetaTexture('rfoot', feetdata[footIndex])
        creation.rfoot.w = mesh.getImage(creation.rfoot.metaURL):getHeight() / 2
        creation.rfoot.h = mesh.getImage(creation.rfoot.metaURL):getWidth() / 2

        footCanvas = createRandomColoredBlackOutlineTexture(creation.lfoot.metaURL)

        local handIndex = 12 --math.ceil(math.random() * #feetdata)

        changeMetaTexture('lhand', feetdata[handIndex])
        creation.lhand.w = mesh.getImage(creation.lhand.metaURL):getHeight() / 2
        creation.lhand.h = mesh.getImage(creation.lhand.metaURL):getWidth() / 2


        changeMetaTexture('rhand', feetdata[handIndex])
        creation.rhand.w = mesh.getImage(creation.rhand.metaURL):getHeight() / 2
        creation.rhand.h = mesh.getImage(creation.rhand.metaURL):getWidth() / 2

        handCanvas = createRandomColoredBlackOutlineTexture(creation.lhand.metaURL)

        eardata = loadVectorSketch('assets/faceparts.polygons.txt', 'ears')
        local earIndex = math.ceil(love.math.random() * #eardata)
        --print(eardata[earIndex])
        changeMetaTexture('lear', eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() / 4
        earCanvas = createRandomColoredBlackOutlineTexture(creation.lear.metaURL)

        changeMetaTexture('rear', eardata[earIndex])
        creation.rear.w = mesh.getImage(creation.rear.metaURL):getHeight() / 4
        creation.rear.h = mesh.getImage(creation.rear.metaURL):getWidth() / 4






        --earCanvas = createRandomColoredBlackOutlineTexture(creation.rear.metaURL)

        --changeMetaTexture('lear', eardata[earIndex])

        -- eyes
        eyedata = loadVectorSketch('assets/faceparts.polygons.txt', 'eyes')
        -- pupils
        pupildata = loadVectorSketch('assets/faceparts.polygons.txt', 'pupils')
        nosedata = loadVectorSketch('assets/faceparts.polygons.txt', 'noses')

        upperlipdata = loadVectorSketch('assets/faceparts.polygons.txt', 'upperlips')
        lowerlipdata = loadVectorSketch('assets/faceparts.polygons.txt', 'lowerlips')
        teethdata = loadVectorSketch('assets/faceparts.polygons.txt', 'teeths')
        eyebrowsdata = loadVectorSketch('assets/faceparts.polygons.txt', 'eyebrows')
        print(eyebrowsdata)
        randomFaceParts()
        image11 = love.graphics.newImage('assets/parts/hair9.png')
        mesh11 = createTexturedTriangleStrip(image11)
        local amt = 5
        for i = 1, amt do
            table.insert(box2dGuys, makeGuy(camtlx + (i * screenWorldWidth / (amt + 1)), camcy + (i % 2) * -1000, i))
        end

        for i = 1, 5 do
            --      makeBalloon(i * 100, -1000)
        end
    end

    example = number
end

function love.load()
    stiff = true
    local font = love.graphics.newFont('assets/WindsorBT-Roman.otf', 40)
    love.graphics.setFont(font)

    vlooienspel = love.graphics.newImage('assets/ui/vlooienspel.jpg')
    pedal = love.graphics.newImage('assets/ui/pedal.jpg')

    -- before these were local but that didnt work with lurker
    -- all of these are relevant to the vlooienspel experiment, and not to others (I think)

    disabledContacts = {}
    pointerJoints = {}
    connectorCooldownList = {}

    borderImage = love.graphics.newImage("assets/ui/border_shaduw.png")
    -- if (PROF_CAPTURE) then ProFi:start() end
    image1 = love.graphics.newImage("assets/parts/leg5.png")
    --image3:setMipmapFilter( 'nearest', 1 )
    mesh1 = createTexturedTriangleStrip(image1)

    image2 = love.graphics.newImage("assets/parts/leg5x.png")
    --image3:setMipmapFilter( 'nearest', 1 )
    mesh2 = createTexturedTriangleStrip(image2)

    image3 = love.graphics.newImage("assets/parts/leg1.png")
    --image3:setMipmapFilter( 'nearest', 1 )
    mesh3 = createTexturedTriangleStrip(image3)

    image4 = love.graphics.newImage("assets/parts/leg7.png")
    --image3:setMipmapFilter( 'nearest', 1 )
    mesh4 = createTexturedTriangleStrip(image4)

    image5 = love.graphics.newImage("assets/parts/leg2.png")
    --image3:setMipmapFilter( 'nearest', 1 )
    mesh5 = createTexturedTriangleStrip(image5)


    image6 = love.graphics.newImage('assets/parts/hair1x.png')
    mesh6 = createTexturedTriangleStrip(image6)

    image7 = love.graphics.newImage('assets/parts/hair2x.png')
    mesh7 = createTexturedTriangleStrip(image7)

    image8 = love.graphics.newImage('assets/parts/hair1.png')
    mesh8 = createTexturedTriangleStrip(image8)

    image9 = love.graphics.newImage('assets/parts/hair6.png')
    mesh9 = createTexturedTriangleStrip(image9)

    --image11 = love.graphics.newImage('assets/parts/hair9.png')
    -- mesh11 = createTexturedTriangleStrip(image11)

    cloud = love.graphics.newImage('assets/world/clouds1.png', { mipmaps = true })

    spriet = {
        love.graphics.newImage('assets/world/spriet1.png'),
        love.graphics.newImage('assets/world/spriet2.png'),
        love.graphics.newImage('assets/world/spriet3.png'),
        love.graphics.newImage('assets/world/spriet4.png'),
        love.graphics.newImage('assets/world/spriet5.png'),
        love.graphics.newImage('assets/world/spriet6.png'),
        love.graphics.newImage('assets/world/spriet7.png'),
        love.graphics.newImage('assets/world/spriet8.png'),
    }

    sprietUnder = {}
    sprietOver = {}


    legCanvas        = createRandomColoredBlackOutlineTexture('assets/parts/legp2.png')
    local l          = legCanvas:getHeight()
    creation.luleg.l = l / 2
    creation.ruleg.l = l / 2
    creation.llleg.l = l / 2
    creation.rlleg.l = l / 2
    local l          = legCanvas:getWidth()
    creation.luleg.w = l
    creation.ruleg.w = l
    creation.llleg.w = l
    creation.rlleg.w = l



    legmesh = createTexturedTriangleStrip(legCanvas)

    armCanvas = createRandomColoredBlackOutlineTexture('assets/parts/legp2.png')
    armmesh = createTexturedTriangleStrip(armCanvas)

    neckCanvas = createRandomColoredBlackOutlineTexture('assets/parts/legp2.png')

    creation.neck.w = neckCanvas:getWidth() / 2
    creation.neck.h = neckCanvas:getHeight() / 2
    neckmesh = createTexturedTriangleStrip(neckCanvas)

    local w, h = love.graphics.getDimensions()
    image10 = love.graphics.newImage('assets/parts/legp2.png')
    mesh10 = createTexturedTriangleStrip(image10)

    --print(inspect(cam:getScale()))
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 2000, 2000)

    --create()
    example = nil
    startExample(3)
    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])

    --grabDevelopmentScreenshot()
end

local function pointerReleased(id, x, y)
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        -- if false then
        if mj.id == id then
            if (mj.joint) then
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
            --   end
        end
    end
    killMouseJointIfPossible(id)
end

function love.touchreleased(id, x, y)
    -- lastDraggedElement = nil
    pointerReleased(id, x, y)
end

function love.mousereleased(x, y)
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
    lastDraggedElement = nil
    pointerPressed(id, x, y)
end

function love.mousepressed(x, y)
    lastDraggedElement = nil
    pointerPressed('mouse', x, y)
end

-- note: there is an issue in here, when you press on a hand that is over a body, you probaly want the hand but
-- to fix this i think we want to add all possible interactions of this click to a temp list.
-- then afterward find the best one to connect.

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

function pointerPressed(id, x, y)
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
                    table.insert(temp, { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture) })
                end
            end
        end
    end
    if #temp > 0 then
        table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
        killMouseJointIfPossible(id)
        table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy))
    end

    if #temp == 0 then killMouseJointIfPossible(id) end
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

function randInt(length)
    return math.ceil(math.random() * length)
end

function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

function drawTempSiders()
    -- hwat has a weird baked in scale ?
    -- feet /2
    -- ears / 2

    local s = h_slider('torsoHeightMultiplier', 20, 20, 100, multipliers.torso.hMultiplier, 0.25, 4)
    if s.value then
        multipliers.torso.hMultiplier = s.value
        creation.torso.h = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
    end
    local s = h_slider('torsoWidthMultiplier', 20, 50, 100, multipliers.torso.wMultiplier, 0.25, 4)
    if s.value then
        multipliers.torso.wMultiplier = s.value
        creation.torso.w = mesh.getImage(creation.torso.metaURL):getWidth() * multipliers.torso.wMultiplier
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
    end
    local s = h_slider('legLengthMultiplier', 20, 80, 100, multipliers.leg.lMultiplier, 0.25, 4)
    if s.value then
        local l                     = legCanvas:getHeight()
        creation.luleg.h            = l * s.value / 2
        creation.ruleg.h            = l * s.value / 2
        creation.llleg.h            = l * s.value / 2
        creation.rlleg.h            = l * s.value / 2
        multipliers.leg.lMultiplier = s.value
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'llleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlleg')
        end
    end
    local s = h_slider('legWidthMultiplier', 20, 110, 100, multipliers.leg.wMultiplier, 0.25, 2)
    if s.value then
        local l                     = legCanvas:getWidth()
        creation.luleg.w            = l * s.value
        creation.ruleg.w            = l * s.value
        creation.llleg.w            = l * s.value
        creation.rlleg.w            = l * s.value
        multipliers.leg.wMultiplier = s.value
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'llleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlleg')
        end
    end
    local s = h_slider('feetHeightMultiplier', 20, 130, 100, multipliers.feet.hMultiplier, 0.5, 4)
    if s.value then
        multipliers.feet.hMultiplier = s.value
        creation.lfoot.h             = mesh.getImage(creation.lfoot.metaURL):getWidth() / 2 *
            multipliers.feet.hMultiplier
        creation.rfoot.h             = creation.lfoot.h
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lfoot')
            genericBodyPartUpdate(box2dGuys[i], i, 'rfoot')
        end
    end
    local s = h_slider('feetWidthMultiplier', 20, 160, 100, multipliers.feet.wMultiplier, 0.5, 4)
    if s.value then
        multipliers.feet.wMultiplier = s.value
        creation.lfoot.w             = mesh.getImage(creation.lfoot.metaURL):getHeight() / 2 *
            multipliers.feet.wMultiplier
        creation.rfoot.w             = creation.lfoot.w
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lfoot')
            genericBodyPartUpdate(box2dGuys[i], i, 'rfoot')
        end
    end
    local s = h_slider('armLengthMultiplier', 20, 190, 100, multipliers.arm.lMultiplier, 0.25, 4)
    if s.value then
        local l                     = armCanvas:getHeight()
        creation.luarm.h            = l * s.value / 2
        creation.ruarm.h            = l * s.value / 2
        creation.llarm.h            = l * s.value / 2
        creation.rlarm.h            = l * s.value / 2
        multipliers.arm.lMultiplier = s.value
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'llarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlarm')
        end
    end
    local s = h_slider('armWidthMultiplier', 20, 220, 100, multipliers.arm.wMultiplier, 0.25, 4)
    if s.value then
        local l                     = armCanvas:getWidth()
        creation.luarm.w            = l * s.value / 2
        creation.ruarm.w            = l * s.value / 2
        creation.llarm.w            = l * s.value / 2
        creation.rlarm.w            = l * s.value / 2
        multipliers.arm.wMultiplier = s.value
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'llarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlarm')
        end
    end

    local s = h_slider('handHeightMultiplier', 20, 250, 100, multipliers.hand.hMultiplier, 0.5, 4)
    if s.value then
        multipliers.hand.hMultiplier = s.value
        creation.lhand.h             = mesh.getImage(creation.lhand.metaURL):getWidth() / 2 *
            multipliers.hand.hMultiplier
        creation.rhand.h             = creation.lhand.h
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lhand')
            genericBodyPartUpdate(box2dGuys[i], i, 'rhand')
        end
    end

    local s = h_slider('handWidthMultiplier', 20, 280, 100, multipliers.hand.wMultiplier, 0.5, 4)
    if s.value then
        multipliers.hand.wMultiplier = s.value
        creation.lhand.w             = mesh.getImage(creation.lhand.metaURL):getHeight() / 2 *
            multipliers.hand.wMultiplier
        creation.rhand.w             = creation.lhand.w
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lhand')
            genericBodyPartUpdate(box2dGuys[i], i, 'rhand')
        end
    end

    ----
    ---- second column

    local s = h_slider('neckWidthMultiplier', 180, 20, 100, multipliers.neck.wMultiplier, 0.25, 4)
    if s.value then
        multipliers.neck.wMultiplier = s.value
        creation.neck.w              = neckCanvas:getWidth() / 2 *
            multipliers.neck.wMultiplier
        creation.neck1.w             = creation.neck.w
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'neck')
            genericBodyPartUpdate(box2dGuys[i], i, 'neck1')
        end
    end
    local s = h_slider('neckHeightMultiplier', 180, 50, 100, multipliers.neck.hMultiplier, 0.25, 2)
    if s.value then
        multipliers.neck.hMultiplier = s.value
        creation.neck.h              = neckCanvas:getHeight() / 2 *
            multipliers.neck.hMultiplier
        creation.neck1.h             = creation.neck.h
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'neck')
            genericBodyPartUpdate(box2dGuys[i], i, 'neck1')
        end
    end

    local s = h_slider('headWidthMultiplier', 180, 80, 100, multipliers.head.wMultiplier, 0.25, 4)
    if s.value then
        multipliers.head.wMultiplier = s.value
        creation.head.w              = mesh.getImage(creation.head.metaURL):getWidth() *
            multipliers.head.wMultiplier

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'head')
        end
    end
    local s = h_slider('headHeightMultiplier', 180, 110, 100, multipliers.head.hMultiplier, 0.25, 4)
    if s.value then
        multipliers.head.hMultiplier = s.value
        creation.head.h              = mesh.getImage(creation.head.metaURL):getHeight() *
            multipliers.head.hMultiplier

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'head')
        end
    end

    local s = h_slider('earWidthMultiplier', 180, 140, 100, multipliers.ear.wMultiplier, 0.25, 8)
    if s.value then
        multipliers.ear.wMultiplier = s.value
        creation.lear.w             = mesh.getImage(creation.lear.metaURL):getWidth() / 2 *
            multipliers.ear.wMultiplier
        creation.rear.w             = creation.lear.w
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end
    local s = h_slider('earHeightMultiplier', 180, 170, 100, multipliers.ear.hMultiplier, 0.25, 8)
    if s.value then
        multipliers.ear.hMultiplier = s.value
        creation.lear.h             = mesh.getImage(creation.lear.metaURL):getHeight() / 2 *
            multipliers.ear.hMultiplier
        creation.rear.h             = creation.lear.h
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end

    local s = h_slider('earStanceThing', 180, 200, 100, creation.lear.stanceAngle, 0, math.pi)
    if s.value then
        creation.lear.stanceAngle = s.value
        creation.rear.stanceAngle = -1 * s.value

        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end


    local s = h_slider('hairWidthMultiplier', 180, 230, 100, multipliers.hair.wMultiplier, 0.01, 2)
    if s.value then
        multipliers.hair.wMultiplier = s.value
    end
    local s = h_slider('hairSpacingMultiplier', 180, 260, 100, multipliers.hair.sMultiplier, 1, 10)
    if s.value then
        multipliers.hair.sMultiplier = s.value
    end

    local s = h_slider('noseWidthMultiplier', 180, 290, 100, multipliers.nose.wMultiplier, 0.25, 4)
    if s.value then
        multipliers.nose.wMultiplier = s.value
    end
    local s = h_slider('noseHeightMultiplier', 180, 320, 100, multipliers.nose.hMultiplier, 0.25, 4)
    if s.value then
        multipliers.nose.hMultiplier = s.value
    end

    local s = h_slider('eyeWidthMultiplier', 180, 350, 100, multipliers.eye.wMultiplier, 0.25, 4)
    if s.value then
        multipliers.eye.wMultiplier = s.value
    end
    local s = h_slider('eyeHeightMultiplier', 180, 380, 100, multipliers.eye.hMultiplier, 0.25, 4)
    if s.value then
        multipliers.eye.hMultiplier = s.value
    end


    ----
    local s = h_slider('legStanceWidth', 320, 20, 100, positioners.leg.x, 0, 1)

    if s.value then
        positioners.leg.x = s.value
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'llleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlleg')
        end
    end
end

function love.draw()
    ui.handleMouseClickStart()
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.setColor(1, 1, 1, .6)
    local sx, sy = createFittingScale(cloud, width, height)
    local bgscale = math.min(sx, sy)
    love.graphics.draw(cloud, 0, 0, 0, bgscale, bgscale)

    --drawMeterGrid()

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
        drawWorld(world)
        local tlx, tly = cam:getWorldCoordinates( -1000, 0)
        local brx, bry = cam:getWorldCoordinates(width + 1000, height)
        for i = 1, #box2dGuys do
            local x, y = box2dGuys[i].torso:getPosition()

            if x >= tlx and x <= brx then
                drawSkinOver(box2dGuys[i], creation)
            end
        end
        for i = 1, #box2dTorsos do
            drawTorsoOver(box2dTorsos[i])
        end
        cam:pop()

        love.graphics.print(love.timer.getFPS(), 0, 0)
    end

    if example == 3 then
        love.graphics.setColor(1, 1, 1)

        love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
        cam:push()

        -- love.graphics.rectangle('fill', 200, -500, 100, 100)
        --i * 40, -500




        love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)

        local amplitude = 50
        local freq = 2
        local a = math.sin((delta or 0) * freq) / amplitude
        for i = 1, sprietWidthAmt do
            local s = sprietUnder[i]
            a = math.sin((delta or 0) * freq) / amplitude
            --drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
            a = math.sin(((delta or 0) + .2) * freq) / amplitude
            s = sprietUnder[(sprietWidthAmt) + i]
            --drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
            s = sprietUnder[(sprietWidthAmt * 2) + i]
            a = math.sin(((delta or 0) + .4) * freq) / amplitude
            drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])

            s = sprietUnder[(sprietWidthAmt * 3) + i]
            a = math.sin(((delta or 0) + .4) * freq) / amplitude
            drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
        end


        love.graphics.setColor(1, 1, 1, 1)
        local img = mesh.getImage('assets/world/stoelL.png')
        love.graphics.draw(img, 100, -100, 0, 1, 1, 0, img:getHeight())

        local img = mesh.getImage('assets/world/tafel.png')
        love.graphics.draw(img, 300, -100, 0, 1, 1, 0, img:getHeight())


        local img = mesh.getImage('assets/world/stoelR.png')
        love.graphics.draw(img, 800, -100, 0, 1, 1, 0, img:getHeight())

        drawWorld(world)

        for i = 1, #box2dGuys do
                drawSkinOver(box2dGuys[i], creation, cam)
        end

        for i = 1, #box2dGuys do
            --       drawNumbersOver(box2dGuys[i])
        end
        for i = 1, #grass do
            --   drawPlantOver(grass[i], i)
        end
        for i = 1, #box2dTorsos do
            drawTorsoOver(box2dTorsos[i])
        end

        love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)
        local a = math.sin((delta or 0) * freq) / amplitude
        for i = 1, sprietWidthAmt do
            local s = sprietOver[i]
            drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
            s = sprietOver[sprietWidthAmt + i]
            --drawSpriet(s[1], s[2], s[3], s[4] + a, s[5])
        end

        cam:pop()
        love.graphics.setColor(0, 0, 0)
        --drawCenteredBackgroundText(
        --    "b: ody, h:ead,  f: eet, t: bodyflip, j: hand\n, i:eye, e:ear, v:torsoflip\n, h:torsoflip, n:neck, u:psidedown, \np:profile, s:stiff  ")
        local bw, bh = borderImage:getDimensions()
        local w, h = love.graphics.getDimensions();
        love.graphics.setColor(.9, .8, .8, 0.9)
        love.graphics.draw(borderImage, 0, 0, 0, w / bw, h / bh)
        love.graphics.setColor(.4, .4, .4, 0.9)
        love.graphics.print(love.timer.getFPS(), 0, 0)
        drawTempSiders()
    end

    cam:push()

    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if mj.positionOfLastDisabledContact and #mj.positionOfLastDisabledContact > 0 then
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

function rotateToHorizontal(body, desiredAngle, divider, pr)
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


function maybeConnectThisConnector(f, mj)
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

lastDt = 0

function rotateAllBodies(bodies, dt)
    --local upsideDown = false
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


            if (stiff) and not isBeingPointerJointed then
                --local userData = fixture:getUserData()



                if userData then
                    -- getRidOfBigRotationsInBody(body)
                    --print(userData.bodyType)
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

delta = 0
function love.update(dt)
    delta = delta + dt
    lurker.update()
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
    rotateAllBodies(world:getBodies(), dt)

    -- snapJoint will break only if AND you are interacting on it AND the force is bigger then X

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

                    local breakForce = 100000 * math.max(1, (b1:getMass() * b2:getMass()))
                    --print(breakForce)
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

    manual_gc(0.002, 2)
end

function love.mousemoved(x, y, dx, dy)
    if love.keyboard.isDown('space') or love.mouse.isDown(3) then
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

function vloer_voor_theo()
    print('Ja Hallo is dit een vloer of zin het letters?')
end

local jointsEnabled = true

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == '1' then startExample(1) end
    if k == '2' then startExample(2) end
    if k == '3' then startExample(3) end
    if k == 'u' then
        upsideDown = not upsideDown
        if false then
            if not upsideDown then
                for i = 1, #box2dGuys do
                    if box2dGuys[i].head then
                        box2dGuys[i].head:setAngle( -math.pi)
                    end
                    if box2dGuys[i].neck then
                        box2dGuys[i].neck:setAngle(0)
                    end
                    if box2dGuys[i].neck1 then
                        box2dGuys[i].neck1:setAngle(0)
                    end

                    box2dGuys[i].luleg:setAngle(0)
                    box2dGuys[i].llleg:setAngle(0)
                    box2dGuys[i].ruleg:setAngle(0)
                    box2dGuys[i].rlleg:setAngle(0)
                end
            end
            if upsideDown then
                for i = 1, #box2dGuys do
                    box2dGuys[i].luleg:setAngle(math.pi * 2)
                    box2dGuys[i].llleg:setAngle(math.pi * 2)
                    box2dGuys[i].lfoot:setAngle(math.pi / 2)
                    box2dGuys[i].ruleg:setAngle(math.pi * 2)
                    box2dGuys[i].rlleg:setAngle(math.pi * 2)
                    box2dGuys[i].rfoot:setAngle( -math.pi / 2)
                end
            end
        end
    end
    if k == 's' then
        stiff = not stiff
    end

    if (k == 'p') then
        creation.isPotatoHead = not creation.isPotatoHead
        creation.hasNeck = not creation.isPotatoHead
        for i = 1, #box2dGuys do
            handleNeckAndHeadForPotato(creation.isPotatoHead, box2dGuys[i], i)
            handlePhysicsHairOrNo(creation.hasPhysicsHair, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
        if false then
            if not profiling then
                ProFi:start()
            else
                ProFi:stop()
                ProFi:writeReport('log/MyProfilingReport.txt')
            end
            profiling = not profiling
        end
    end
    --if example == 3 then
    if k == 'j' then
        jointsEnabled = not jointsEnabled
        for i = 1, #box2dGuys do
            toggleAllJointLimits(box2dGuys[i], jointsEnabled)
        end
    end
    if k == '-' then
        print('rest hard!')
        for i = 1, #box2dGuys do
            if (box2dGuys[i].head) then box2dGuys[i].head:setAngle(0) end
            if (box2dGuys[i].neck1) then box2dGuys[i].neck1:setAngle( -math.pi) end
            if (box2dGuys[i].neck) then box2dGuys[i].neck:setAngle( -math.pi) end
            box2dGuys[i].lear:setAngle(math.pi / 2)
            box2dGuys[i].rear:setAngle( -math.pi / 2)
            box2dGuys[i].torso:setAngle(0)
            box2dGuys[i].luleg:setAngle(0)
            box2dGuys[i].llleg:setAngle(0)
            box2dGuys[i].lfoot:setAngle(math.pi / 2)
            box2dGuys[i].ruleg:setAngle(0)
            box2dGuys[i].rlleg:setAngle(0)
            box2dGuys[i].rfoot:setAngle( -math.pi / 2)
            box2dGuys[i].luarm:setAngle(0)
            box2dGuys[i].llarm:setAngle(0)
            box2dGuys[i].lhand:setAngle(0)
            box2dGuys[i].ruarm:setAngle(0)
            box2dGuys[i].rlarm:setAngle(0)
            box2dGuys[i].rhand:setAngle(0)
        end
    end

    if k == 'n' then
        if not creation.isPotatoHead then
            creation.hasNeck = not creation.hasNeck
            for i = 1, #box2dGuys do
                handleNeckAndHeadForHasNeck(creation.hasNeck, box2dGuys[i], i)
                genericBodyPartUpdate(box2dGuys[i], i, 'head')
            end
        end
    end

    if (k == 't') then
        creation.torso.flipx = creation.torso.flipx == 1 and -1 or 1
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
    end

    if k == 'v' then
        creation.torso.flipy = creation.torso.flipy == 1 and -1 or 1
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
        end
    end

    if k == 'e' then
        local earIndex = math.ceil(love.math.random() * #eardata)
        changeMetaTexture('lear', eardata[earIndex])
        creation.lear.w = mesh.getImage(creation.lear.metaURL):getHeight() / 4
        creation.lear.h = mesh.getImage(creation.lear.metaURL):getWidth() / 4
        earCanvas = createRandomColoredBlackOutlineTexture(creation.lear.metaURL)

        changeMetaTexture('rear', eardata[earIndex])
        creation.rear.w = mesh.getImage(creation.rear.metaURL):getHeight() / 4
        creation.rear.h = mesh.getImage(creation.rear.metaURL):getWidth() / 4


        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lear')
            genericBodyPartUpdate(box2dGuys[i], i, 'rear')
        end
    end
    if k == 'i' then
        --eyedata = loadVectorSketch('assets/faceparts.polygons.txt', 'eyes')
        eyeIndex = math.ceil(math.random() * #eyedata)
        changeMetaTexture('eye', eyedata[eyeIndex])
        creation.eye.w = mesh.getImage(creation.eye.metaURL):getHeight()
        creation.eye.h = mesh.getImage(creation.eye.metaURL):getWidth()
        eyeCanvas = createWhiteColoredBlackOutlineTexture(creation.eye.metaURL)
        for i = 1, #box2dGuys do
            --    genericBodyPartUpdate(box2dGuys[i], i, 'eye')
        end
    end

    if k == 'l' then
        randomFaceParts()
    end

    if k == 'h' then
        if not creation.isPotatoHead then
            headRndIndex = math.ceil(love.math.random() * #data)
            local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                    data[headRndIndex]
                    .points)

            changeMetaPoints('head', flippedFloppedHeadPoints)
            changeMetaTexture('head', data[headRndIndex])
            headCanvas = createRandomColoredBlackOutlineTexture(creation.head.metaURL)

            creation.head.w = mesh.getImage(creation.head.metaURL):getWidth() / 2
            creation.head.h = mesh.getImage(creation.head.metaURL):getHeight() / 2

            for i = 1, #box2dGuys do
                genericBodyPartUpdate(box2dGuys[i], i, 'head')
                genericBodyPartUpdate(box2dGuys[i], i, 'lear')
                genericBodyPartUpdate(box2dGuys[i], i, 'rear')
            end
        end
    end

    if k == 'j' then
        local handIndex = math.ceil(math.random() * #feetdata)
        changeMetaTexture('lhand', feetdata[handIndex])
        changeMetaTexture('rhand', feetdata[handIndex])
        creation.lhand.w = mesh.getImage(creation.lhand.metaURL):getHeight() / 2
        creation.lhand.h = mesh.getImage(creation.lhand.metaURL):getWidth() / 2

        creation.rhand.w = mesh.getImage(creation.rhand.metaURL):getHeight() / 2
        creation.rhand.h = mesh.getImage(creation.rhand.metaURL):getWidth() / 2
        handCanvas = createRandomColoredBlackOutlineTexture(creation.lhand.metaURL)


        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lhand')
            genericBodyPartUpdate(box2dGuys[i], i, 'rhand')
        end
    end

    if k == 'r' then
        if not creation.isPotatoHead then
            creation.head.flipy = creation.head.flipy == 1 and -1 or 1
            local flippedFloppedHeadPoints = getFlippedMetaObject(creation.head.flipx, creation.head.flipy,
                    data[headRndIndex]
                    .points)

            changeMetaPoints('head', flippedFloppedHeadPoints)
            changeMetaTexture('head', data[headRndIndex])
            for i = 1, #box2dGuys do
                genericBodyPartUpdate(box2dGuys[i], i, 'head')
                genericBodyPartUpdate(box2dGuys[i], i, 'lear')
                genericBodyPartUpdate(box2dGuys[i], i, 'rear')
            end
        end
    end

    if k == 'y' then
        -- creation.upLeg.stanceAngle = love.math.random() * math.pi / 2
        creation.luleg.h = 100 + love.math.random() * 700
        creation.ruleg.h = creation.luleg.h
        creation.llleg.h = 100 + love.math.random() * 700
        creation.rlleg.h = creation.llleg.h
        --  print(creation.upLeg.stanceAngle)
        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'luleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'llleg')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlleg')
        end
    end


    if k == 'f' then
        local footIndex = math.ceil(math.random() * #feetdata)

        local multiplier = 1
        changeMetaTexture('lfoot', feetdata[footIndex])
        creation.lfoot.w = multiplier * mesh.getImage(creation.lfoot.metaURL):getHeight() / 2
        creation.lfoot.h = multiplier * mesh.getImage(creation.lfoot.metaURL):getWidth() / 2

        changeMetaTexture('rfoot', feetdata[footIndex])
        creation.rfoot.w = multiplier * mesh.getImage(creation.rfoot.metaURL):getHeight() / 2
        creation.rfoot.h = multiplier * mesh.getImage(creation.rfoot.metaURL):getWidth() / 2
        footCanvas = createRandomColoredBlackOutlineTexture(creation.lfoot.metaURL)


        for i = 1, #box2dGuys do
            genericBodyPartUpdate(box2dGuys[i], i, 'lfoot')
            genericBodyPartUpdate(box2dGuys[i], i, 'rfoot')
        end
    end

    if (k == 'b') then
        bodyRndIndex = math.ceil(love.math.random() * #data)
        local flippedFloppedBodyPoints = getFlippedMetaObject(creation.torso.flipx, creation.torso.flipy,
                data[bodyRndIndex]
                .points)
        changeMetaPoints('torso', flippedFloppedBodyPoints)
        changeMetaTexture('torso', data[bodyRndIndex])
        torsoCanvas = createRandomColoredBlackOutlineTexture(creation.torso.metaURL)

        local body = box2dGuys[1].torso
        local longestLeg = math.max(creation.luleg.h + creation.llleg.h, creation.ruleg.h + creation.rlleg.h)
        local oldLegLength = longestLeg + creation.torso.h

        --creation.hasPhysicsHair = not creation.hasPhysicsHair
        creation.torso.w = mesh.getImage(creation.torso.metaURL):getWidth() / 2
        creation.torso.h = mesh.getImage(creation.torso.metaURL):getHeight() * multipliers.torso.hMultiplier

        local newLegLength = longestLeg + creation.torso.h
        local bx, by = body:getPosition()
        if (newLegLength > oldLegLength) then
            body:setPosition(bx, by - (newLegLength - oldLegLength) * 1.2)
        end

        creation.luarm.h = 150 + love.math.random() * 100
        creation.llarm.h = 150 + love.math.random() * 100
        creation.ruarm.h = creation.luarm.h
        creation.rlarm.h = creation.llarm.h
        for i = 1, #box2dGuys do
            handleNeckAndHeadForPotato(creation.isPotatoHead, box2dGuys[i], i)
            handlePhysicsHairOrNo(creation.hasPhysicsHair, box2dGuys[i], i)
            genericBodyPartUpdate(box2dGuys[i], i, 'torso')
            genericBodyPartUpdate(box2dGuys[i], i, 'luarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'llarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'ruarm')
            genericBodyPartUpdate(box2dGuys[i], i, 'rlarm')

            if (not creation.isPotatoHead) then
                genericBodyPartUpdate(box2dGuys[i], i, 'lear')
                genericBodyPartUpdate(box2dGuys[i], i, 'rear')
            end
        end
    end
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

                local n = Vector.angled(Vector(400, 0), angle)
                objects.carbody.body:applyLinearImpulse(n.x, n.y)
                --local delta = Vector(x1 - x2, y1 - y2)
            end
        end
    end
end
