package.path  = package.path .. ";../../?.lua"

local lurker  = require 'vendor.lurker'
local inspect = require 'vendor.inspect'
Vector        = require 'vendor.brinevector'
local cam     = require('lib.cameraBase').getInstance()
local camera  = require 'lib.camera'

lurker.quiet  = true
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

function grabDevelopmentScreenshot()
    love.graphics.captureScreenshot('ScreenShot-' .. os.date("%Y-%m-%d-[%H-%M-%S]") .. '.png')
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

local motorSpeed = 0
local motorTorque = 1500
local carIsTouching = 0

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == '1' then startExample(1) end
    if k == '2' then startExample(2) end
    if k == '3' then startExample(3) end
    if example == 2 then
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

                local n = Vector.angled(Vector(200, 0), angle)
                objects.carbody.body:applyLinearImpulse(n.x, n.y)
                --local delta = Vector(x1 - x2, y1 - y2)
            end
        end
    end
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
    if (mouseJoints.jointBody) then
        --print(fixtureB:getUserData())
        if (bb == mouseJoints.jointBody and fixtureA:getUserData() == 'ground') then
            result = true
        end
    end

    -- this disables contact between  balls and the ground if ballcenterY < collisionY (ball below ground)
    if fixtureA:getUserData() == 'ground' and fixtureB:getUserData() == 'ball' then
        local x1, y1 = contact:getPositions()
        if y1 < bb:getY() then
            result = true
        end
    end

    return result
end

function isContactBetweenGroundAndCarGroundSensor(contact)
    local fixtureA, fixtureB = contact:getFixtures()
    --print(fixtureA:getUserData(), fixtureB:getUserData())
    --print(fixtureA:isSensor(), fixtureB:isSensor())
    return (fixtureA:getUserData() == 'ground' and fixtureB:getUserData() == 'carGroundSensor') or
        (fixtureB:getUserData() == 'ground' and fixtureA:getUserData() == 'carGroundSensor')
end

function beginContact(a, b, contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also waht touch id or mouse this is..

        positionOfLastDisabledContact = point
        -- we want to know if a or b was the mousejoint thing.
        if a:getBody() == mouseJoints.jointBody then
            bodyLastDisabledContact = a
        end
        if b:getBody() == mouseJoints.jointBody then
            bodyLastDisabledContact = b
        end

        table.insert(disabledContacts, contact)
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

function makeRectPoly(w, h, x, y)
    return love.physics.newPolygonShape(
            x, y,
            x + w, y,
            x + w, y + h,
            x, y + h
        )
end

function makeGuy(x, y, groupId)
    -- a body
    -- attached are 2 upperlegs
    -- attached to the upperlegs are lowerlegs
    -- attached to the lowerlegs are feet

    --local torso = {}


    local function limitsAround(value, range, joint)
        local low = value - range
        local high = value + range
        --return value - range, value + range

        --if low < high then
        --    low = low - math.pi * 2
            --high = high + math.pi * 2
        --end
        --print(low, high)
        joint:setLowerLimit(low)
        joint:setUpperLimit(high)
        joint:setLimitsEnabled(true)
    end



    local torsoWidth = love.math.random() * 10 + 50
    local torsoHeight = love.math.random() * 20 + 50

    local ulWidth = 10
    local ulHeight = 50 + love.math.random() * 70

    local llWidth = 10
    local llHeight = ulHeight


    -- TORSO
    local torso = love.physics.newBody(world, x, y, "dynamic")
    local torsoShape = love.physics.newRectangleShape(torsoWidth, torsoHeight)
    local fixture = love.physics.newFixture(torso, torsoShape, 1)
    fixture:setFilterData(1, 65535, -1 * groupId)
    fixture:setUserData('torso')

    -- UPPER LEFT LEG
    local ulleg = love.physics.newBody(world, x - torsoWidth / 2, y + torsoHeight / 2, "dynamic")
    local ullegShape = makeRectPoly(ulWidth, ulHeight, -ulWidth / 2, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(ulleg, ullegShape, 1)
    fixture:setUserData('legpart')
    fixture:setFilterData(1, 65535, -1 * groupId)

    local torsoULjoint1 = love.physics.newRevoluteJoint(torso, ulleg, ulleg:getX(), ulleg:getY(), false)
    --torsoULjoint1:setDampingRatio(0.5)
    --limitsAround((math.pi / 4) , math.pi / 8, torsoULjoint1)
    --limitsAround(0, math.pi / 4, torsoULjoint1)

   -- print(torsoULjoint1:getJointAngle())
    limitsAround(0, math.pi / 16, torsoULjoint1)

    -- LOWER LEFT LEG
    local llleg = love.physics.newBody(world, x - torsoWidth / 2, y + torsoHeight / 2 + ulHeight, "dynamic")
    local lllegShape = makeRectPoly(llWidth, llHeight, -llWidth / 2, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(llleg, lllegShape, 1)
    fixture:setUserData('legpart')
    fixture:setFilterData(1, 65535, -1 * groupId)
    local torsoULjoint1 = love.physics.newRevoluteJoint(ulleg, llleg, llleg:getX(), llleg:getY(), false)

    --limitsAround( -(math.pi / 4), math.pi / 4, torsoULjoint1)
   -- limitsAround(0, math.pi / 4, torsoULjoint1)
    limitsAround(0, math.pi / 16, torsoULjoint1)


    -- LEFT FOOT
    if false then
    local leftFoot = love.physics.newBody(world, x - torsoWidth / 2, y + torsoHeight / 2 + ulHeight + llHeight, "dynamic")
    local leftFootShape = makeRectPoly(10, 50, -5, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(leftFoot, leftFootShape, 1)
    fixture:setFilterData(1, 65535, -1 * groupId)
    fixture:setFriction(1)
    leftFoot:setAngle(math.pi/2)
    local ULFeetjoint1 = love.physics.newRevoluteJoint(llleg, leftFoot, leftFoot:getX(), leftFoot:getY(), false)
   -- limitsAround( -math.pi / 2 - math.pi, math.pi / 8, ULFeetjoint1)
    limitsAround(0, math.pi / 16, ULFeetjoint1)
    end
    -- local dj = love.physics.newDistanceJoint(llleg, leftFoot, llleg:getX(), llleg:getY(), leftFoot:getX(),
    --         leftFoot:getY())


    -- UPPER RIGHT LEG
    local urleg = love.physics.newBody(world, x + torsoWidth / 2, y + torsoHeight / 2, "dynamic")
    local urlegShape = makeRectPoly(ulWidth, ulHeight, -ulWidth / 2, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(urleg, urlegShape, .5)
    fixture:setUserData('legpart')
    fixture:setFilterData(1, 65535, -1 * groupId)
    local torsoULjoint2 = love.physics.newRevoluteJoint(torso, urleg, urleg:getX(), urleg:getY(), false)
    limitsAround(0, math.pi / 16, torsoULjoint2)

    --limitsAround(0, math.pi / 4, torsoULjoint2)

    -- LOWER RIGHT LEG

    local lrleg = love.physics.newBody(world, x + torsoWidth / 2, y + torsoHeight / 2 + ulHeight, "dynamic")
    local lrlegShape = makeRectPoly(llWidth, llHeight, -llWidth / 2, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(lrleg, lrlegShape, 1)
    fixture:setUserData('legpart')
    fixture:setFilterData(1, 65535, -1 * groupId)
    local torsoULjoint1 = love.physics.newRevoluteJoint(urleg, lrleg, lrleg:getX(), lrleg:getY(), false)
    limitsAround(0, math.pi / 16, torsoULjoint1)
    --limitsAround(0, math.pi / 4, torsoULjoint1)


    if false then
    local leftFoot = love.physics.newBody(world, x + torsoWidth / 2, y + torsoHeight / 2 + ulHeight + llHeight, "dynamic")
    leftFoot:setAngle(-math.pi/2)
    local leftFootShape = makeRectPoly(10, 50, -5, 0) --  love.physics.newRectangleShape(ulWidth, ulHeight)
    local fixture = love.physics.newFixture(leftFoot, leftFootShape, .5)
    fixture:setFilterData(1, 65535, -1 * groupId)
    fixture:setFriction(1)


    local ULFeetjoint2 = love.physics.newRevoluteJoint(lrleg, leftFoot, leftFoot:getX(), leftFoot:getY(), false)
    limitsAround( 0, math.pi / 8, ULFeetjoint2)
    end
    -- local dj = love.physics.newDistanceJoint(lrleg, leftFoot, lrleg:getX(), lrleg:getY(), leftFoot:getX(),
    --         leftFoot:getY())



    return torso
end

function makeChain(x, y)
    --https://mentalgrain.com/box2d/creating-a-chain-with-box2d/
    local linkHeight = 70
    local linkWidth = 40
    local dir = 1
    local amt = 3


    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth, linkHeight)
        local fixture = love.physics.newFixture(body, shape, .3)
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


    local weight = love.physics.newBody(world, x, y + ((amt + 1) * linkHeight) * dir, "dynamic")
    local shape = love.physics.newRectangleShape(linkWidth, linkHeight)
    local fixture = love.physics.newFixture(weight, shape, 1)


    local joint = love.physics.newRevoluteJoint(lastLink, weight, weight:getX(), weight:getY(), false)
    local dj = love.physics.newDistanceJoint(lastLink, weight, lastLink:getX(), lastLink:getY(), weight:getX(),
            weight:getY())
    joint:setLowerLimit( -math.pi / 32)
    joint:setUpperLimit(math.pi / 32)
    joint:setLimitsEnabled(true)
    weight:setFixedRotation(true)
    table.insert(objects.blocks, weight)
    -- objects.joint2 = love.physics.newRevoluteJoint(carbody.body, objects.wheel2.body, objects.wheel2.body:getX(),
    --             objects.wheel2.body:getY(), false)
end

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    --ball.body:setFixedRotation(true)
    --objects.ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20,
    --        ballRadius * 3 + love.math.random() * 20, 5))
    ball.shape = love.physics.newCircleShape(ballRadius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData("ball")
    ball.fixture:setFriction(.5)
    return ball
end

function makeBlock(x, y, size)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    ball.body:setFixedRotation(true)
    ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20,
            ballRadius * 3 + love.math.random() * 20, 5))
    --ball.shape = love.physics.newCircleShape(ballRadius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData("ball")
    ball.fixture:setFriction(.5)
    return ball
end

function makeCarousell(x, y, width, height, angularVelocity)
    local carousel = {}
    carousel.body = love.physics.newBody(world, x, y, "kinematic")
    carousel.shape = love.physics.newRectangleShape(width, height)
    carousel.fixture = love.physics.newFixture(carousel.body, carousel.shape, 1)
    carousel.body:setAngularVelocity(angularVelocity)
    carousel.fixture:setUserData("caroussel")
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
    border.fixture:setUserData("border")
    border.fixture:setFriction(.5)
    return border
end

function makeChainGround()
    local width, height = love.graphics.getDimensions()
    local points = {}
    for i = -1000, 1000 do
        local cool = 1.78
        local amplitude = 100 * cool
        local frequency = 33
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y1 = h - (amplitude / 2)


        local cool = 1.78
        local amplitude = 200 * cool
        local frequency = 17
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y2 = h - (amplitude / 2)


        --   h = h + height / 2
        table.insert(points, i * 100)
        table.insert(points, y1 + y2)
    end
    --print(inspect(points))
    local thing = {}
    thing.body = love.physics.newBody(world, 0, 0)
    thing.shape = love.physics.newChainShape(false, unpack(points))
    thing.fixture = love.physics.newFixture(thing.body, thing.shape)
    thing.fixture:setUserData("border")
    thing.fixture:setFriction(.5)
    return thing
end

function startExample(number)
    local width, height = love.graphics.getDimensions()
    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    objects = {}
    ballRadius = love.physics.getMeter() / 4
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

        objects.ground.fixture:setUserData("ground")

        if false then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, height - (height / 10), "static")
            objects.ground.shape = love.physics.newRectangleShape(width, height / 4)
            objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
            objects.ground.fixture:setUserData("ground")
        end
        objects.ground.body:setTransform(width / 2, height - (height / 10), 0) --  <= here we se an anlgle to the ground!!
        objects.ground.fixture:setFriction(0.01)
    end
    ----
    ---- VEHICLES
    -----
    if number == 2 then
        world:setCallbacks(beginContact, endContact, preSolve, postSolve)




        local margin = 20




        -- objects.border = makeBorderChain(width, height, margin)

        objects.ground = makeChainGround()
        objects.ground.fixture:setUserData("ground")
        if true then
            objects.ground = {}
            objects.ground.body = love.physics.newBody(world, width / 2, -500, "static")
            objects.ground.shape = love.physics.newRectangleShape(width * 10, height / 4)
            objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
            objects.ground.fixture:setUserData("ground")
            --objects.ground.body:setTransform(width / 2, height - (height / 10), 0) --  <= here we se an anlgle to the ground!!
            objects.ground.fixture:setFriction(1)
        end


        objects.blocks = {}
        for i = 1, 30 do
            objects.blocks[i] = makeBlock(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * -height / 2, ballRadius)
        end







        local carbody = {}

        carbody.body = love.physics.newBody(world, width / 2, 0, "dynamic")
        carbody.shape = love.physics.newRectangleShape(300, 100)
        carbody.fixture = love.physics.newFixture(carbody.body, carbody.shape, .5)
        carbody.fixture:setUserData("carbody")
        --carbody.fixture:setFilterData(1, 65535, -1)
        --carbody.body:setFixedRotation(true)
        -- objects.blocks = { carbody }
        objects.carbody = carbody
        table.insert(objects.blocks, carbody)

        local xOffset = -100
        local polyWidth = 20
        local polyLength = -110

        local backside = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        local backfixture = love.physics.newFixture(carbody.body, backside, .5)


        local xOffset = 80
        local polyWidth = 20
        local polyLength = -110

        local backside = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                polyLength,
                xOffset, polyLength)
        local backfixture = love.physics.newFixture(carbody.body, backside, .5)

        if true then
            local carsensor = {}
            -- carsensor.body = love.physics.newBody(world, width / 2, 0, "dynamic")
            --carsensor.shape = love.physics.newRectangleShape(5, 300)
            local xOffset = 100
            local polyWidth = 20
            local polyLength = 110
            carsensor.shape = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                    polyLength,
                    xOffset, polyLength)
            carsensor.fixture = love.physics.newFixture(carbody.body, carsensor.shape, .5)
            carsensor.fixture:setSensor(true)
            carsensor.fixture:setUserData("carGroundSensor")

            --table.insert(objects.blocks, carsensor)
        end

        if true then
            local carsensor = {}
            -- carsensor.body = love.physics.newBody(world, width / 2, 0, "dynamic")
            --carsensor.shape = love.physics.newRectangleShape(5, 300)
            local xOffset = -100
            local polyWidth = 20
            local polyLength = 110
            carsensor.shape = love.physics.newPolygonShape(xOffset, 0, xOffset + polyWidth, 0, xOffset + polyWidth,
                    polyLength,
                    xOffset, polyLength)
            carsensor.fixture = love.physics.newFixture(carbody.body, carsensor.shape, .5)
            carsensor.fixture:setSensor(true)
            carsensor.fixture:setUserData("carGroundSensor")

            --table.insert(objects.blocks, carsensor)
        end

        objects.wheel1 = {}
        objects.wheel1.body = love.physics.newBody(world, width / 2 - 110, 40, "dynamic")
        objects.wheel1.shape = love.physics.newCircleShape(25)
        objects.wheel1.fixture = love.physics.newFixture(objects.wheel1.body, objects.wheel1.shape, .5)
        objects.wheel1.fixture:setFilterData(1, 65535, -1)
        objects.wheel1.fixture:setFriction(2.5)

        objects.joint1 = love.physics.newRevoluteJoint(carbody.body, objects.wheel1.body, objects.wheel1.body:getX(),
                objects.wheel1.body:getY(), false)
        objects.joint1:setMotorEnabled(true)
        objects.joint1:setMotorSpeed(motorSpeed)
        objects.joint1:setMaxMotorTorque(motorTorque)

        objects.wheel2 = {}
        objects.wheel2.body = love.physics.newBody(world, width / 2 + 110, 40, "dynamic")
        objects.wheel2.shape = love.physics.newCircleShape(25)
        objects.wheel2.fixture = love.physics.newFixture(objects.wheel2.body, objects.wheel2.shape, .5)
        objects.wheel2.fixture:setFilterData(1, 65535, -1)
        objects.wheel2.fixture:setFriction(2.5)

        objects.joint2 = love.physics.newRevoluteJoint(carbody.body, objects.wheel2.body, objects.wheel2.body:getX(),
                objects.wheel2.body:getY(), false)
        objects.joint2:setMotorEnabled(true)
        objects.joint2:setMotorSpeed(motorSpeed)
        objects.joint2:setMaxMotorTorque(motorTorque)

        objects.balls = {}

        for i = 1, 13 do
            --ballRadius = love.math.random() * 300 + 130
            objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                    margin + love.math.random() * -height / 2, ballRadius)
        end

        for i = 1, 3 do
            makeChain(i * 20, -1000)
        end



        for i = 1, 30 do
            makeGuy(i * 200, -1000, i)
        end
        ballRadius = love.physics.getMeter() / 4
        if false then
            for i = 1, 20 do
                objects.balls[i] = makeBall(ballRadius + (love.math.random() * (width - ballRadius * 2)),
                        margin + love.math.random() * height / 2, ballRadius)
            end
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
    positionOfLastDisabledContact = nil
    bodyLastDisabledContact = nil

    mouseJoints = {
        joint = nil,
        jointBody = nil
    }
    example = nil
    startExample(2)
    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2, w * 2, h * 2)
    --grabDevelopmentScreenshot()
end

function killMouseJointIfPossible()
    if (mouseJoints.joint) then
        mouseJoints.joint:destroy()
        mouseJoints.joint     = nil
        mouseJoints.jointBody = nil
    end
end

function love.mousereleased()
    -- now we have to find a few things out to check if i want to shoot my thing
    -- first off, are we below the ground ?
    if (mouseJoints.joint) then
        if (mouseJoints.jointBody) then
            local points = { objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()) }
            local tl = { points[1], points[2] }
            local tr = { points[3], points[4] }
            -- fogure out if we are below the ground, and if so whatthe ange is we want to be shot at.
            -- oh wait, this is actually kinda good enough-ish (tm)
            if (bodyLastDisabledContact and bodyLastDisabledContact:getBody() == mouseJoints.jointBody) then
                local x1, y1 = mouseJoints.jointBody:getPosition()
                if (#positionOfLastDisabledContact > 0) then
                    local x2 = positionOfLastDisabledContact[1]
                    local y2 = positionOfLastDisabledContact[2]

                    local delta = Vector(x1 - x2, y1 - y2)
                    local l = delta:getLength()
                    -- print(l)
                    local v = delta:getNormalized() * l * -2
                    if v.y > 0 then
                        v.y = 0
                        v.x = 0
                    end -- i odnt want  you shoooting downward!
                    bodyLastDisabledContact:getBody():applyLinearImpulse(v.x, v.y)
                end
                bodyLastDisabledContact = nil
                positionOfLastDisabledContact = nil
                --
            end
        end
    end
    killMouseJointIfPossible()
end

function love.mousepressed(mx, my)
    -- killMouseJointIfPossible()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    --local bodies = { objects.ball.body, objects.ball2.body }
    local hitAny = false
    local epsilon = 10


    local containers = { 'balls', 'blocks' }


    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local bx, by = body:getPosition()
        local dx, dy = wx - bx, wy - by
        local distance = math.sqrt(dx * dx + dy * dy)

        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
            local hitThisOne = fixture:testPoint(wx, wy)
            local isSensor = fixture:isSensor()
            if (hitThisOne and not isSensor) then
                killMouseJointIfPossible()
                mouseJoints.jointBody = body
                mouseJoints.joint = love.physics.newMouseJoint(mouseJoints.jointBody, wx, wy)
                --mouseJoints.joint = love.physics.newMouseJoint(mouseJoints.jointBody, body:getX(), body:getY())

                mouseJoints.joint:setDampingRatio(0.5)
                mouseJoints.joint:setMaxForce(50000)
                --print(mouseJoints.joint:getMaxForce())
                local vx, vy = body:getLinearVelocity()
                body:setPosition(body:getX(), body:getY() - 1)

                hitAny = true
            end
        end
        -- end
    end


    if hitAny == false then killMouseJointIfPossible() end
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

function drawCenteredBackgroundText(str)
    local width, height = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local textw, wrappedtext = font:getWrap(str, width)
    local texth = font:getHeight() * #wrappedtext
    love.graphics.print(str, width / 2 - textw / 2, height / 2 - texth / 2)
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

        drawWorld(world)

        cam:pop()

        love.graphics.print(
            bool2str(carIsTouching >= 2) .. ' motorspeed = ' .. motorSpeed .. ', torque = ' .. motorTorque, 0,
            0)
        if (objects.carbody) then
            love.graphics.print(objects.carbody.body:getY(), 0, 40)
        end
    end


    cam:push()

    if positionOfLastDisabledContact and #positionOfLastDisabledContact > 0 then
        -- print(inspect(positionOfLastDisabledContact))
        love.graphics.circle('fill', positionOfLastDisabledContact[1], positionOfLastDisabledContact[2], 10)
        if (bodyLastDisabledContact) then
            local posx, posy = bodyLastDisabledContact:getBody():getPosition()
            love.graphics.line(positionOfLastDisabledContact[1], positionOfLastDisabledContact[2], posx, posy)
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
    local angle = body:getAngle()
    local nextAngle = angle + body:getAngularVelocity() / divider




    local totalRotation = desiredAngle - nextAngle
    while (totalRotation < -180 * DEGTORAD) do
        totalRotation = totalRotation + 360 * DEGTORAD
    end

    while (totalRotation > 180 * DEGTORAD) do
        totalRotation = totalRotation - 360 * DEGTORAD
    end

    local desiredAngularVelocity = totalRotation * divider
    local impulse = body:getInertia() * desiredAngularVelocity
    body:applyAngularImpulse(impulse)
end

function love.update(dt)
    lurker.update()
    if (mouseJoints.joint) then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        mouseJoints.joint:setTarget(wx, wy)


        local fixtures = mouseJoints.jointBody:getFixtures();
        for i = 1, #fixtures do
            local f = fixtures[i]
            if f:getUserData() == 'carbody' then
                local body = mouseJoints.jointBody
                if body then
                    if (carIsTouching < 1) then
                        rotateToHorizontal(body, 0, 10)
                    end
                end

                -- next issue, if we throw a car it needs to NOT spina orund too, for tha t I prolly need somethign like
                -- https://www.iforce2d.net/b2dtut/jumpability
                -- magic word -- SENSORS
                -- yeah this just kinda sucks, its less fun and more buggy...


                --mouseJoints.jointBody:applyTorque(angle * 0.125)
            end
            if f:getUserData() == 'torso' then
                --print('jo found a torso to rotate!')
                local body = mouseJoints.jointBody
                if body then
                    rotateToHorizontal(body, 0, 10)
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
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
            if fixture:getUserData() == 'torso' then
                local a = body:getAngle()
                --if math.abs(a) > math.pi then
                -- print(a, a % math.pi)
                --    body:setAngle(a % math.pi)
                --end

                if false then
                    if a > (2 * math.pi) then
                        a = a - (2 * math.pi)
                        body:setAngle(a)
                    end
                    if a < -(2 * math.pi) then
                        a = a + (2 * math.pi)
                        body:setAngle(a)
                    end
                end



               rotateToHorizontal(body, 0, 50)
            end

            if fixture:getUserData() == 'legpart' then
                --print('rotating legpart')
                --if body:setAngle( angle )
                local a = body:getAngle()
                --if math.abs(a) > math.pi then
                -- print(a, a % math.pi)
                --     body:setAngle(a % math.pi)
                --end


                if false then
                    if a > (2 * math.pi) then
                        a = a - (2 * math.pi)
                        body:setAngle(a)
                    end
                    if a < -(2 * math.pi) then
                        a = a + (2 * math.pi)
                        body:setAngle(a)
                    end
                end


               -- rotateToHorizontal(body, 0, 2)
            end
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

        -- cam:setTranslation(x, y)
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
