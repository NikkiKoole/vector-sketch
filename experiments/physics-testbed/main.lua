package.path = package.path .. ";../../?.lua"
require 'lib.printC'
local inspect          = require 'vendor.inspect'
local cam              = require('lib.cameraBase').getInstance()
local camera           = require 'lib.camera'
local phys             = require 'lib.mainPhysics'
local numbers          = require 'lib.numbers'
local generatePolygon  = require('lib.generate-polygon').generatePolygon
local gradient         = require 'lib.gradient'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local texturedBox2d    = require 'lib.texturedBox2d'
local addMipos         = require 'addMipos'
local gradient         = require 'lib.gradient'
local skygradient      = gradient.makeSkyGradient(10)
local ui               = require "lib.ui"
local connect          = require 'lib.connectors'
local updatePart       = require 'lib.updatePart'
local Timer            = require 'vendor.timer'
local text             = require "lib.text"


function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()


local function getAngle(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local angle = math.atan2(dy, dx)
    return angle
end

local function calculateEndPoint(startPoint, angleRad, distance)
    -- Convert angle from degrees to radians
    local angleRadians = angleRad

    -- Calculate the change in x and y using trigonometry
    local deltaX = distance * math.cos(angleRadians)
    local deltaY = distance * math.sin(angleRadians)


    -- Calculate the end point
    local endPoint = {
        x = startPoint.x + deltaX,
        y = startPoint.y + deltaY
    }

    return endPoint.x, endPoint.y
end



function locatePeakX(startX, endX, stepSize)
    local bestPos = nil
    local bestValue = math.huge
    --local bestDiff = math.huge

    for i = 0, (endX - startX) / stepSize do
        local x = startX + i * stepSize
        local nx = startX + (i + 1) * stepSize
        local nnx = startX + (i + 2) * stepSize

        local y = getYAtX(x, stepSize)
        local ny = getYAtX(nx, stepSize)
        local nny = getYAtX(nnx, stepSize)
        --print(nx > x , nx > nnx  , nx > bestValue)
        --print(ny < y , ny < nny, ny)
        if ny < nny and bestValue > ny then
            bestPos = nx
            bestValue = ny
        end
    end
    return bestPos - stepSize
end

function startExample(number)
    atlasImg = love.graphics.newArrayImage('assets/sprieten.png')
    --atlasArray = love.graphics.newArrayImage({ 'assets/sprieten.png' })
    q1 = love.graphics.newQuad(0, 0, 49, 192, atlasImg)
    q2 = love.graphics.newQuad(51, 164, 40, 197, atlasImg)
    q3 = love.graphics.newQuad(51, 0, 41, 162, atlasImg)
    q4 = love.graphics.newQuad(94, 0, 46, 186, atlasImg)
    q5 = love.graphics.newQuad(0, 194, 47, 231, atlasImg)
    q6 = love.graphics.newQuad(94, 188, 45, 236, atlasImg)
    q7 = love.graphics.newQuad(142, 197, 47, 208, atlasImg)
    q8 = love.graphics.newQuad(142, 0, 52, 195, atlasImg)
    quads = { q1, q2, q3, q4, q5, q6, q7, q8 }
    origins = { { 22, 185 }, { 12, 187 }, { 19, 144 }, { 25, 176 }, { 27, 224 }, { 16, 210 }, { 22, 190 }, { 30, 173 } }


    phys.setupWorld()
    stepSize = 300
    ground = initGround()
    mipos = addMipos.make(1)
    obstacles = {}

    -- try to insert some houses, with jumpy roofs.
    -- lets start with the roofs.


    -- first try and localte a point where these 2 conditions are met:
    -- my next step is higher then me
    -- the step after that is lower .

    -- locate peak basically

    if false then
        for i = 0, 100 do
            local rangeSize = 150

            local psx = 0 + (i * rangeSize * stepSize)
            local pex = rangeSize * stepSize + (i * rangeSize * stepSize)


            local x1 = locatePeakX(psx, pex, stepSize)


            local y1 = getYAtX(x1, stepSize)
            local x2 = x1 + stepSize
            local y2 = getYAtX(x2, stepSize)
            local distance = stepSize * 10
            local x3, y3 = calculateEndPoint({ x = x1, y = y1 }, getAngle(x2, y2, x1, y1), distance)
            -- get the angle between these 2
            --print(x1,y1,x2,y2)

            local points = { x1, y1, x3, y3 - 1000, x3 + stepSize * 5, y3 - 1200 }
            local schansBody = love.physics.newBody(world, 0, 0, "static")
            local schansShape = love.physics.newChainShape(false, points)
            local fixture = love.physics.newFixture(schansBody, schansShape)


            local body = love.physics.newBody(world, x1, y1, 'static')
            local shape = love.physics.newRectangleShape(1, 1)
            local fixture = love.physics.newFixture(body, shape, .3)


            local body = love.physics.newBody(world, x3, y3, 'static')
            local shape = love.physics.newRectangleShape(1, 1)
            local fixture = love.physics.newFixture(body, shape, .3)
        end
    end
    if false then
        for i = 1, 100 do
            local o = makeRandomPoly(i * 30, -500, 10 + love.math.random() * 200)
            table.insert(obstacles, o)
        end

        for i = 1, 100 do
            local o = makeRandomTriangle(i * 30, -500, 500)
            table.insert(obstacles, o)
        end
    end

    -- makeChain(0,-5000,10)
    for i = 0, 10 do
        --    makeCarousell(i * 5000, 0, 1500, 500, 1)
    end
    -- get data from the mipos[1] to make a fitted bike
    local c = mipos[1].dna.creation
    --print(inspect(c.lfoot))
    local scooterData = {
        type = 'scooter',
        steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = math.max(c.lfoot.h * 3, c.torso.w * 1.2),
        radius = 200
    }

    local bikeData = {
        type = 'bike',
        steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.luleg.h + c.llleg.h + c.torso.h,
        radius = 250
    }

    local busData = {
        type = 'bus',
        -- steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.luleg.h + c.llleg.h + c.torso.h,
        legLength = c.luleg.h + c.llleg.h,
        radius = 100
    }
    local rollerL = {
        type = 'rollerblade',
        -- steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.lfoot.h * 1.3,
        radius = 100,
        connector = 'left'
    }
    local rollerR = {
        type = 'rollerblade',
        -- steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.lfoot.h * 1.3,
        radius = 100,
        connector = 'right'
    }
    local skate = {
        type = 'skate',
        -- steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.lfoot.h * 2.5,
        radius = 100,

    }

    bikeData2 = {
        type = 'bike',
        steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.luleg.h + c.llleg.h + c.torso.h / 1,
        radius = math.max((c.luleg.h + c.llleg.h) / 2, 150)
    }

    local connectLessData = {
        type = 'connectLess',
        radius = (c.luleg.h + c.llleg.h) / 2,
        floorWidth = (c.lfoot.h) * 2 + ((c.luleg.h + c.llleg.h)),
        footH = c.lfoot.h,
        footW = c.lfoot.w
    }
    --
    --bike = makeRollerBlade(-2000, -4000, rollerL)
    -- bike = makeRollerBlade(-2000, -5000, rollerR)
    --bike = makeSkateBoard(-2000, -5000, skate)
    -- bike = makeScooter(-2000, -5000, scooterData)
    --bike = makePedalBike(-2000, -5000, bikeData)
    --   bike = makeBusThing(-2000, -5000, busData)
    --bike = makeConnectLess(-2000, -5000, connectLessData)
    bike = makeBike2(-2000, -5000, bikeData2)


    --isPedalBike = false

    --bike.frontWheel
    rollingAverageVelX = {}
    rollingAverageVelY = {}
    rollingDistance = {}
    rollingMemoryUsage = {}

    for i = 1, 10 do
        rollingAverageVelX[i] = 0
        rollingAverageVelY[i] = 0
        rollingDistance[i] = 0
        rollingMemoryUsage[i] = 0
    end
end

-- GROUND STUFF

function initGround()
    local thing = {
        body = love.physics.newBody(world, 0, 0)
    }
    updateGround(thing)
    return thing
end

function getYAtX(x, stepSize)
    local STEEPNESS = 2000
    local index = math.floor(x / stepSize)

    local function generateWave(amplitude, frequency)
        local h = love.math.noise(index / frequency, 1, 1) * amplitude
        return h - (amplitude / 2)
    end

    local y1 = generateWave(200 * 10.78, 30)
    local y2 = generateWave(70 * 10.78, 17)
    local y3 = generateWave(20 * 10.78, 5)

    y3 = y3 * ((math.sin(x / 30) + 1) / 2) -- Apply roughness condition

    local c = x / stepSize
    local linear = numbers.mapInto(c, -20, 20, -STEEPNESS, STEEPNESS)

    return y1 + y2 + y3 + linear
end

function updateGround(ground)
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly
    local steps = math.ceil(boxWorldWidth / stepSize)

    local points = {}

    if ground.fixture then
        ground.fixture:destroy()
    end

    local extraSteps = 10

    for i = 1 - extraSteps, steps + 2 + extraSteps do
        local x = (math.floor(camtlx / stepSize) * stepSize) + (i - 1) * stepSize
        local y = getYAtX(x, stepSize)

        table.insert(points, x)
        table.insert(points, y)
    end

    ground.shape = love.physics.newChainShape(false, points)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
    ground.fixture:setUserData("ground")
    ground.fixture:setFriction(1)
    ground.points = points
end

-- GROUND AND ITS ITEMS STUFF

function lerpYAtX(targetX, stepSize)
    local x1 = math.floor(targetX / stepSize) * stepSize
    local x2 = math.ceil(targetX / stepSize) * stepSize

    local y1 = getYAtX(x1, stepSize)
    local y2 = getYAtX(x2, stepSize)

    local y3 = numbers.mapInto(targetX, x1, x2, y1, y2)
    return y3
end

function enableDisableMipos()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly

    -- local steps = math.ceil(boxWorldWidth / stepSize)

    local extraSteps = 10
    local xMinR = camtlx - extraSteps * stepSize
    local xMaxR = cambrx + extraSteps * stepSize

    for i = 1, #mipos do
        local b = mipos[i]
        local bx, by = b.b2d.torso:getPosition()

        if bx < xMinR or bx > xMaxR then
            --local y = lerpYAtX(bx, stepSize)
            --local dy = y - by
            for k, v in pairs(b.b2d) do
                -- local b2x, b2y = v:getPosition()
                v:setActive(false)
                v:setGravityScale(0)
                --  print('setting', b2x, b2y)
                --v:setPosition(b2x, b2y )
            end
        end

        if bx >= xMinR and bx <= xMaxR then
            for k, v in pairs(b.b2d) do
                v:setActive(true)
                v:setGravityScale(1)
            end
        end
    end
end

function enableDisableBikes()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly

    -- local steps = math.ceil(boxWorldWidth / stepSize)

    local extraSteps = 10
    local xMinR = camtlx - extraSteps * stepSize
    local xMaxR = cambrx + extraSteps * stepSize

    --    for i = 1, #mipos do
    local b = bike --mipos[i]
    --local bx, by = b.b2d.torso:getPosition()
    local bx, by = b.frontWheel.body:getPosition()

    --local parts = {b.frontWheel.body, }
    if bx < xMinR or bx > xMaxR then
        local y = lerpYAtX(bx, stepSize)
        for k, v in pairs(b) do
            if v.body then
                v.body:setActive(false)
                v.body:setGravityScale(0)
                local b2x, b2y = v.body:getPosition()
                v.body:setPosition(b2x, b2y)
            end
        end
    end

    if bx >= xMinR and bx <= xMaxR then
        for k, v in pairs(b) do
            if v.body then
                v.body:setActive(true)
                v.body:setGravityScale(1)
            end
        end
    end
end

function enableDisableObstacles()
    --Body:setGravityScale( scale )
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly


    -- local steps = math.ceil(boxWorldWidth / stepSize)

    local extraSteps = 100

    local xMinR = camtlx - extraSteps * stepSize
    local xMaxR = cambrx + extraSteps * stepSize

    -- print(#obstacles)
    for i = 1, #obstacles do
        local b = obstacles[i]
        local bx, by = b:getPosition()
        local scale = b:getGravityScale()
        --print(scale)

        if bx < xMinR or bx > xMaxR then
            b:setActive(false)
            b:setGravityScale(0)
            local y = lerpYAtX(bx, stepSize)

            if by > y then
                b:setPosition(bx, y)
            end
            -- print('setting scale to 0')
        end

        if bx >= xMinR and bx <= xMaxR then
            b:setActive(true)
            b:setGravityScale(1)
            -- print('setting scale to 1')
        end
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


-- vehicle stuff



function makeCarShape2(w, h, cx, cy)
    return love.physics.newPolygonShape(
        cx - w / 2, cy - h / 2,
        cx - w / 2, cy + h / 2 - h / 5,
        cx - w / 2 + w / 8, cy + h / 2,
        cx + w / 2 - w / 8, cy + h / 2,
        cx + w / 2, cy + h / 2 - h / 5,
        cx + w / 2, cy - h / 2
    )
end

function makeCarShape(w, h, cx, cy)
    return love.physics.newPolygonShape(
        cx + w / 2 - w / 3, cy - h,
        cx - w / 2, cy - h,
        cx - w / 2, cy - h / 2,
        cx - w / 2, cy + h / 2 - h / 5,
        cx - w / 2 + w / 8, cy + h / 2,
        cx + w / 2 - w / 8, cy + h / 2,
        cx + w / 2, cy + h / 2 - h / 5,
        cx + w / 2, cy - h / 2

    )
end

function makeBusThing(x, y, data)
    local floorWidth = data.floorWidth or data.radius
    local radius = data.radius
    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 3, y + 100, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)
    ball1.body:setAngularVelocity(10000)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 3, y + 100, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball2.fixture:setFriction(1)
    ball2.body:setAngularVelocity(10000)

    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = makeCarShape(floorWidth, 200, 0, 0) -- love.physics.newRectangleShape(floorWidth, 300)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
    frame.fixture:setUserData(makeUserData("frame"))


    local back = {}
    back.shape = love.physics.newRectangleShape(-floorWidth / 2, -400, 100, 400)
    back.fixture = love.physics.newFixture(frame.body, back.shape, 1)

    --local back = {}
    --back.shape = love.physics.newRectangleShape(floorWidth/3,-400,100, 100)
    --back.fixture = love.physics.newFixture(frame.body, back.shape, 1)


    local seat = {}
    local seatXOffset = -200
    local seatYOffset = -300
    -- seat.body = love.physics.newBody(world, x+seatXOffset, y + seatYOffset, "dynamic")
    -- seat.shape = love.physics.newRectangleShape(seatXOffset,   seatYOffset, 100, 100)
    -- seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)

    connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)
    connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)
    connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)


    connect.makeAndAddConnector(frame.body, seatXOffset + data.legLength * 0.75, seatYOffset, { type = 'feet' }, 100, 100)
    -- connect.makeAndAddConnector(frame.body, seatXOffset,  seatYOffset, { type = 'seat' }, 100, 100)

    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    return { frontWheel = ball1, backWheel = ball2, frame = frame }
end

function makeConnectLess(x, y, data)
    local floorWidth = data.floorWidth
    local radius = data.radius
    print(data.footW, data.footH)
    print(inspect(data))

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
    ball1.fixture:setFriction(.10)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
    --ball2.fixture:setRestitution(.2) -- let the ball bounce
    ball2.fixture:setFriction(.1)

    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 150)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
    frame.fixture:setUserData(makeUserData("frame"))
    --frame.fixture:setSensor(true)

    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)

    -- now we need a type of hook that will keep feet in place



    --ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    local shape = love.physics.newPolygonShape(
        0, 0 - data.footW - 150,
        0 + data.footH * 1.5, 0 - data.footW - 150,
        0 + data.footH * 1.5, 0 - 150

    )
    local fixture = love.physics.newFixture(frame.body, shape, 1)

    return { frontWheel = ball1, backWheel = ball2, frame = frame }
end

function makePedalBike(x, y, data)
    local floorWidth = data.floorWidth or data.radius
    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
    ball1.fixture:setFriction(.10)
    --ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball1.body:setAngularVelocity(10000)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
    --ball2.fixture:setRestitution(.2) -- let the ball bounce
    ball2.fixture:setFriction(.1)
    --ball2.body:setAngularVelocity(10000)

    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 150)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
    frame.fixture:setUserData(makeUserData("frame"))
    --frame.fixture:setSensor(true)


    local back = {}
    back.shape = love.physics.newRectangleShape(-floorWidth / 2, -400, 300, 400)
    back.fixture = love.physics.newFixture(frame.body, back.shape, 1)


    local groundFeeler = {}
    --groundFeeler.body = love.physics.newBody(world, x, y+600, "dynamic")
    groundFeeler.shape = love.physics.newRectangleShape(0, 750, 10, 10)
    groundFeeler.fixture = love.physics.newFixture(frame.body, groundFeeler.shape, 1)
    groundFeeler.fixture:setSensor(true)

    local seat = {}
    local seatXOffset = -0
    local seatYOffset = -300
    seat.body = love.physics.newBody(world, x + seatXOffset, y - data.steeringHeight / 1.2 + seatYOffset, "dynamic")
    seat.shape = love.physics.newRectangleShape(seatXOffset, -data.steeringHeight / 1.2 + seatYOffset, 100, 100)
    seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)

    connect.makeAndAddConnector(frame.body, seatXOffset, -data.steeringHeight / 1.2 + seatYOffset, { type = 'seat' }, 105,
        105)

    if false then
        local seat2 = {}
        seat2.shape = love.physics.newRectangleShape(-1000, -600, 200, 200)
        seat2.fixture = love.physics.newFixture(frame.body, seat2.shape, 1)
        connect.makeAndAddConnector(frame.body, -1000, -600, {}, 205, 205)
    end

    local steerHeight = data.steeringHeight
    local steer = {}

    steer.shape = love.physics.newRectangleShape(floorWidth / 2, -steerHeight / 2, 10, steerHeight)
    steer.fixture = love.physics.newFixture(frame.body, steer.shape, 0)
    steer.fixture:setSensor(true)

    if true then
        connect.makeAndAddConnector(frame.body, floorWidth / 2 - 40, -steerHeight - 40, {}, 125, 125)
        connect.makeAndAddConnector(frame.body, floorWidth / 2, -steerHeight, {}, 125, 125)
    end


    local pedalRadius = 150
    local connectorRadius = 50
    local connectorD = connectorRadius * 2
    local pedalXOffset = -0
    local pedal = {}
    pedal.body = love.physics.newBody(world, x + pedalXOffset, y - data.steeringHeight * 0.5 + seatYOffset / 2, "dynamic")
    pedal.shape = love.physics.newRectangleShape(pedalRadius * 2, pedalRadius * 2)

    pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, .1)
    pedal.fixture:setSensor(true)
    pedal.fixture:setFriction(0)
    connect.makeAndAddConnector(pedal.body, -(pedalRadius + connectorRadius), 0, { type = 'lfoot' }, connectorD,
        connectorD)
    connect.makeAndAddConnector(pedal.body, (pedalRadius + connectorRadius), 0, { type = 'rfoot' }, connectorD,
        connectorD)

    local joint1 = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)
    pedal.fixture:setSensor(true)


    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    joint1:setMotorEnabled(true)
    joint1:setMotorSpeed(-500000)
    joint1:setMaxMotorTorque(20000)


    return {
        frontWheel = ball1,
        backWheel = ball2,
        pedalWheel = pedal,
        frame = frame,
        seat = seat,
        groundFeeler =
            groundFeeler
    }
end

function makeScooter(x, y, data)
    local floorWidth = data.floorWidth or data.radius
    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 2, y + 150, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)
    ball1.body:setAngularVelocity(10000)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 2, y + 150, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius * 1)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball2.fixture:setFriction(1)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 100)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
    frame.fixture:setUserData(makeUserData("frame"))

    local back = {}
    back.shape = love.physics.newRectangleShape(-floorWidth / 2, -200, 100, 100)
    back.fixture = love.physics.newFixture(frame.body, back.shape, 1)
    --frame.fixture:setSensor(true)
    if false then
        local seat = {}
        seat.shape = love.physics.newRectangleShape(-200, -600, 200, 200)
        seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)
        connect.makeAndAddConnector(frame.body, -200, -600, {}, 205, 205)

        local seat2 = {}
        seat2.shape = love.physics.newRectangleShape(-1000, -600, 200, 200)
        seat2.fixture = love.physics.newFixture(frame.body, seat2.shape, 1)
        connect.makeAndAddConnector(frame.body, -1000, -600, {}, 205, 205)
    end

    --local achterWielSpat = {}
    --achterWielSpat.shape = love.physics.newRectangleShape(-radius/1.4, -500, 20, 500)
    --achterWielSpat.fixture = love.physics.newFixture(frame.body, achterWielSpat.shape, 1)

    local steer = {}
    local steerHeight = data.steeringHeight
    --steer.body = love.physics.newBody(world, x, y, "dynamic")
    steer.shape = love.physics.newRectangleShape(floorWidth / 2, -steerHeight / 2, 10, steerHeight)
    steer.fixture = love.physics.newFixture(frame.body, steer.shape, .1)
    --steer.fixture:setSensor(true)
    connect.makeAndAddConnector(frame.body, floorWidth / 2 - 40, -steerHeight - 40, { type = 'lhand' }, 125, 125)
    connect.makeAndAddConnector(frame.body, floorWidth / 2, -steerHeight, { type = 'rhand' }, 125, 125)


    connect.makeAndAddConnector(frame.body, 0, -100, { type = 'left' }, 100, 100)
    connect.makeAndAddConnector(frame.body, 0, -100, { type = 'right' }, 100, 100)

    if false then
        local pedal = {}
        pedal.body = love.physics.newBody(world, x + radius, y - 500, "dynamic")
        pedal.shape = love.physics.newRectangleShape(300, 300)
        pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, 1)
        connect.makeAndAddConnector(pedal.body, -150, 0, {}, 150, 150)
        connect.makeAndAddConnector(pedal.body, 150, 0, {}, 150, 150)

        local joint1 = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)
        pedal.fixture:setSensor(true)
    end

    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    joint1:setMotorEnabled(true)
    joint1:setMotorSpeed(500000)
    joint1:setMaxMotorTorque(20000)


    return { frontWheel = ball1, backWheel = ball2, pedalWheel = pedal, frame = frame, steer = steer }
end

function makeRollerBlade(x, y, data)
    local floorWidth = data.floorWidth or data.radius
    floorWidth = floorWidth * 2
    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)

    local groupId = 1
    ball1.fixture:setFilterData(1, 65535, -1 * groupId)
    ball1.body:setAngularVelocity(10000)



    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius * 1)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball2.fixture:setFriction(1)
    ball2.fixture:setFilterData(1, 65535, -1 * groupId)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 50)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
    --frame.fixture:setSensor(true)
    -- frame.fixture:setFilterData(1, 65535, -1 * groupId)
    frame.fixture:setUserData(makeUserData("frame"))

    connect.makeAndAddConnector(frame.body, 0, 0, { type = data.connector }, floorWidth / 1.5, 100 + 50)
    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    return { frontWheel = ball1, backWheel = ball2, frame = frame }
end

function makeSkateBoard(x, y, data)
    local floorWidth = data.floorWidth or data.radius

    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)

    local groupId = 1
    ball1.fixture:setFilterData(1, 65535, -1 * groupId)
    ball1.body:setAngularVelocity(10000)



    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius * 1)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball2.fixture:setFriction(1)
    ball2.fixture:setFilterData(1, 65535, -1 * groupId)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 50)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
    --frame.fixture:setSensor(true)
    -- frame.fixture:setFilterData(1, 65535, -1 * groupId)
    frame.fixture:setUserData(makeUserData("frame"))

    connect.makeAndAddConnector(frame.body, -floorWidth / 4, -100, { type = 'left' }, 100, 100)
    connect.makeAndAddConnector(frame.body, -floorWidth / 4 + 200, -100, { type = 'right' }, 100, 100)

    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    return { frontWheel = ball1, backWheel = ball2, frame = frame }
end

function makeBikeFrameShape(w, h, cx, cy)
    return love.physics.newPolygonShape(
        cx - w / 2, cy - h / 2,
        cx - w / 2, cy + h / 2,
        cx, cy + h / 2,
        cx + w / 2, cy,
        cx + w / 2, cy - h,
        cx, cy - h / 2
    )
end

function makeBike2(x, y, data)
    local floorWidth = data.floorWidth or data.radius

    local frameHeight = 300
    local radius = data.radius
    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = makeBikeFrameShape(floorWidth, frameHeight, 0, 0)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
    frame.fixture:setUserData(makeUserData("frame"))

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)

    local seat = {}
    local seatYOffset = -radius * .5
    seat.body = love.physics.newBody(world, x, y - frameHeight + seatYOffset, "dynamic")
    seat.shape = love.physics.newRectangleShape(0, -frameHeight + seatYOffset, 100, 100)
    seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)
    connect.makeAndAddConnector(frame.body, 0, -frameHeight + seatYOffset, { type = 'seat' }, 105, 105)

    local wheelJoint = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    local pedalRadius = radius / 3
    local connectorRadius = pedalRadius / 3
    local connectorD = connectorRadius * 2
    local pedalXOffset = 0 --radius * .5
    local pedalYOffset = 0 ---radius * .5
    local pedal = {}
    pedal.body = love.physics.newBody(world, x + pedalXOffset, y + pedalYOffset, "dynamic")
    pedal.shape = love.physics.newCircleShape(pedalRadius)

    pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, .1)
    pedal.fixture:setSensor(true)
    pedal.fixture:setFriction(0)
    connect.makeAndAddConnector(pedal.body, -(pedalRadius + connectorRadius), 0, { type = 'lfoot' }, connectorD,
        connectorD)
    connect.makeAndAddConnector(pedal.body, (pedalRadius + connectorRadius), 0, { type = 'rfoot' }, connectorD,
        connectorD)

    local pedalJoint = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)

    joint = love.physics.newGearJoint(wheelJoint, pedalJoint, -3)

    return { frontWheel = ball1, backWheel = ball2, frame = frame, seat = seat, pedalWheel = pedal, }
end

function cycleStep()
    -- bike.frontWheel.body:setAngularVelocity(120000)
    --  bike.backWheel.body:setAngularVelocity(120000)
    bike.frame.body:applyLinearImpulse(10000, -1000)
    bike.pedalWheel.body:applyAngularImpulse(10000)
end

local function setSensorValueBody(body, value)
    -- not allowed to change sensortype of connectors.

    local fixtures = body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        local skip = false
        local ud = fixture:getUserData()
        if ud then
            if ud.bodyType == "connector" then
                skip = true
            end
        end

        if not skip then
            fixture:setSensor(value)
        end
    end
end

local function getConnectorFixtureAtBodyOfType(body, type)
    local fixtures = body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        local ud = fixture:getUserData()
        if ud then
            if ud.bodyType == "connector" then
                if ud.data then
                    if (ud.data.type == type) then
                        return fixture
                    end
                else

                end
            end
        end
    end
end


function disconnectMipoAndVehicle()
    print('disconnect')
    local b2d = mipos[1].b2d

    connect.breakAllConnectionsAtBody(b2d.lhand)
    connect.breakAllConnectionsAtBody(b2d.rhand)
    connect.breakAllConnectionsAtBody(b2d.lfoot)
    connect.breakAllConnectionsAtBody(b2d.rfoot)

    connect.breakAllConnectionsAtBody(b2d.torso)

    local isPedalBike = bike.pedalWheel
    for k, v in pairs(b2d) do
        v:setGravityScale(1)
    end

    local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')
    if seatFixture then
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = false })
    end


    if isPedalBike then
        local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')
        local sx, sy = seatFixture:getBody():getPosition()

        local centroid = getCentroidOfFixture(bike.frame.body, seatFixture)
        b2d.torso:setPosition(centroid[1], centroid[2] - 1000)


        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = false })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = false })
        --  box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rfoot, { sleeping = nil })
        --  box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.lfoot, { sleeping = nil })



        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, -math.pi / 2, 0, 'revolute')
        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, -math.pi / 2, 0, 'revolute')

        box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, true, 'revolute')
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, true, 'revolute')


        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, math.pi / 8, 'revolute')
        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi / 8, 'revolute')

        if true then
            Timer.after(.2, function()
                setSensorValueBody(b2d.luleg, false)
                setSensorValueBody(b2d.llleg, false)
                setSensorValueBody(b2d.lfoot, false)
                setSensorValueBody(b2d.ruleg, false)
                setSensorValueBody(b2d.rlleg, false)
                setSensorValueBody(b2d.rfoot, false)

                setSensorValueBody(b2d.rhand, false)
                setSensorValueBody(b2d.lhand, false)

                local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lfoot, 'foot')
                local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rfoot, 'foot')

                --  print( 'lfoot fixture ', lfootFixture:getFilterData())
                --   print( 'rfoot fixture ', rfootFixture:getFilterData())
            end)
        end
    end

    local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lfoot, 'foot')
    local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rfoot, 'foot')

    --  print( 'lfoot fixture ', lfootFixture:getFilterData())
    --  print( 'rfoot fixture ', rfootFixture:getFilterData())


    b2d.torso:applyLinearImpulse(-1000, -10000)

    updatePart.resetPositions(mipos[1])
    b2d.torso:applyLinearImpulse(-10000, -10000)
end

function connectMipoAndVehicle()
    print('connect')
    updatePart.resetPositions(mipos[1])
    local tx, ty = mipos[1].b2d.rfoot:getPosition()
    local yy = getYAtX(tx, stepSize)
    local b2d = mipos[1].b2d

    -- i want to better position a bike.
    -- given a posiiton of torso,
    -- and lookup a width of bike frame, or well i know position of front and backwheel.
    --
    local isPedalBike = bike.pedalWheel
    --print(bike.type)
    if true then
        -- print()
        if bike.pedalWheel then
            tx = tx - 300
        end
        for k, v in pairs(bike) do
            --v.body:setActive(false)
            --v.body:setGravityScale(0)
            if v.body then
                v.body:setPosition(tx, yy - 300)
                v.body:setAngle(0)
                v.body:setLinearVelocity(0, 0)
                v.body:setAngularVelocity(0)
                --v.body:applyLinearImpulse(0, -1000)
            end
        end
    end

    for k, v in pairs(b2d) do
        --print(k,v)
        v:setGravityScale(0)
    end

    if bike.frame then
        --    bike.frame.body:setPosition(tx, ty)
    end


    connect.breakAllConnectionsAtBody(b2d.lhand)
    connect.breakAllConnectionsAtBody(b2d.rhand)
    connect.breakAllConnectionsAtBody(b2d.lfoot)
    connect.breakAllConnectionsAtBody(b2d.rfoot)
    connect.breakAllConnectionsAtBody(b2d.torso)
    connect.inspectAllConnectors()

    local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')
    if seatFixture then
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })

        box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, false, 'revolute')
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, false, 'revolute')
        if true then
            --   setSensorValueBody(b2d.luleg, true)
            --   setSensorValueBody(b2d.llleg, true)
            setSensorValueBody(b2d.lfoot, true)
            --   setSensorValueBody(b2d.ruleg, true)
            --   setSensorValueBody(b2d.rlleg, true)
            setSensorValueBody(b2d.rfoot, true)
            -- Timer.after(.2, function()
            --     setSensorValueBody(b2d.lfoot, false)
            --   setSensorValueBody(b2d.ruleg, true)
            --   setSensorValueBody(b2d.rlleg, true)
            --     setSensorValueBody(b2d.rfoot, false)
            -- end)

            --     setSensorValueBody(b2d.rhand, true)
            --     setSensorValueBody(b2d.lhand, true)
        end
    end





    if isPedalBike then
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
        -- box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
        -- box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })
        --   box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.lfoot, { sleeping = true })
        --   box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rfoot, { sleeping = true })

        -- b2d.luleg:setAngle(math.pi / 2)
        -- b2d.ruleg:setAngle(math.pi / 2)
        disableLegs()
        if false then
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, -math.pi, math.pi / 2, 'revolute')
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, -math.pi, math.pi / 2, 'revolute')

            box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
            box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')

            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, math.pi, 'revolute')
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi, 'revolute')
        end
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, false, 'revolute')
        box2dGuyCreation.setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, false, 'revolute')

        if true then
            setSensorValueBody(b2d.luleg, true)
            setSensorValueBody(b2d.llleg, true)
            setSensorValueBody(b2d.lfoot, true)
            setSensorValueBody(b2d.ruleg, true)
            setSensorValueBody(b2d.rlleg, true)
            setSensorValueBody(b2d.rfoot, true)

            setSensorValueBody(b2d.rhand, true)
            setSensorValueBody(b2d.lhand, true)
        end
        -- maybe i can rotate legs in advance so they wont end up like flamingo legs

        if false then
            b2d.luleg:setAngle(-math.pi / 2)
            b2d.ruleg:setAngle(-math.pi / 2)

            b2d.llleg:setAngle(math.pi / 2)
            b2d.rlleg:setAngle(math.pi / 2)

            b2d.torso:setAngle(0)
        end
        -- lets alse put the arms in front of the body
        -- b2d.luarm:setAngle(math.pi)
        -- b2d.llarm:setAngle(math.pi)
        -- b2d.ruarm:setAngle(math.pi)
        -- b2d.rlarm:setAngle(math.pi)


        local buttFixture = getConnectorFixtureAtBodyOfType(b2d.torso, 'butt')
        local bx, by = buttFixture:getBody():getPosition()

        local localX, localY = b2d.torso:getLocalPoint(bx, by)


        local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')
        local sx, sy = seatFixture:getBody():getPosition()

        local centroid = getCentroidOfFixture(bike.frame.body, seatFixture)

        b2d.torso:setPosition(centroid[1], centroid[2])

        connect.forceConnection(buttFixture, seatFixture)

        local lfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'lfoot')
        local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lfoot, 'foot')
        local lfcentroid = getCentroidOfFixture(bike.pedalWheel.body, lfootPedalFixture)
        b2d.lfoot:setPosition(lfcentroid[1], lfcentroid[2])

        connect.forceConnection(lfootPedalFixture, lfootFixture)
        b2d.lfoot:setPosition(lfcentroid[1], lfcentroid[2])


        local rfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'rfoot')
        local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rfoot, 'foot')
        local rfcentroid = getCentroidOfFixture(bike.pedalWheel.body, rfootPedalFixture)
        b2d.rfoot:setPosition(rfcentroid[1], rfcentroid[2])


        connect.forceConnection(rfootPedalFixture, rfootFixture)
        b2d.rfoot:setPosition(rfcentroid[1], rfcentroid[2])



        -- print( 'lfoot fixture ', lfootFixture:getFilterData())
        -- print( 'rfoot fixture ', rfootFixture:getFilterData())
    end

    if not isPedalBike then
        local bx, by = bike.frame.body:getPosition()
        local lx, ly = b2d.lfoot:getPosition()
        local rx, ry = b2d.lfoot:getPosition()
        b2d.lfoot:setPosition(lx, by - 200)
        b2d.rfoot:setPosition(rx, by - 200)

        --b2d.torso:applyLinearImpulse(0,-20000)
        Timer.after(.2, function()
            local lfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'lhand')
            local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lhand, 'hand')
            --print(lfootPedalFixture, lfootFixture)


            connect.forceConnection(lfootPedalFixture, lfootFixture)

            local rfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'rhand')
            local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rhand, 'hand')
            connect.forceConnection(rfootPedalFixture, rfootFixture)
        end)

        --print('doing some forcing I believe?')
    end


    if (b2d.head) then b2d.head:setAngle(0) end
    if (b2d.neck1) then b2d.neck1:setAngle(-math.pi) end
    if (b2d.neck) then b2d.neck:setAngle(-math.pi) end
end

-- more general physics stuff

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.shape = love.physics.newCircleShape(radius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, .1)
    ball.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    ball.fixture:setFriction(.5)
    ball.body:setAngularVelocity(10000)
    return ball
end

function makeCarousell(x, y, width, height, angularVelocity)
    local carousel = {}
    carousel.body = love.physics.newBody(world, x, y, "kinematic")
    carousel.shape = love.physics.newRectangleShape(width, height)
    carousel.fixture = love.physics.newFixture(carousel.body, carousel.shape, 1)
    carousel.body:setAngularVelocity(angularVelocity)
    --    carousel.fixture:setUserData(makeUserData("caroussel"))
    return carousel
end

function makeChain(x, y, amt)
    --https://mentalgrain.com/box2d/creating-a-chain-with-box2d/
    local linkHeight = 20 * 10
    local linkWidth = 50 * 10
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

        joint:setLowerLimit(-math.pi / 32)
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
        joint:setLowerLimit(-math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)
        table.insert(objects.blocks, weight)
    end
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

function getRandomConvexPoly(radius, numVerts)
    local irregularity = 0.1
    local spikeyness = 0.1
    local vertices = generatePolygon(0, 0, radius, irregularity, spikeyness, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, irregularity, spikeyness, numVerts)
    end
    return vertices
end

function makeRandomPoly(x, y, radius)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newPolygonShape(getRandomConvexPoly(radius, 8)) --love.physics.newRectangleShape(width, height / 4)
    local fixture = love.physics.newFixture(body, shape, .1)
    return body
end

function makeRandomTriangle(x, y, radius)
    local body = love.physics.newBody(world, x, y, "dynamic")

    local w = (radius * 2) + love.math.random() * (radius * 2)
    local h = radius / 2 + love.math.random() * (radius / 2)


    local points = {
        -w / 2, 0,
        w / 2, -h,
        w / 2, h
    }

    local shape = love.physics.newPolygonShape(points) --love.physics.newRectangleShape(width, height / 4)
    local fixture = love.physics.newFixture(body, shape, .1)
    return body
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

function makeNPoly(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.shape = love.physics.newPolygonShape(npoly(radius, 8)) --love.physics.newRectangleShape(100, 100) --(50)-- love.physics.newCircleShape(50)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, .1)
    return ball
end

-- skygradient
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) }
end

function skyGradient(camYTop, camYBottom)
    local function safeColor(colors, index, tt)
        local blue = { 173 / 255, 192 / 255, 199 / 255 } -- { 208 / 255, 230 / 255, 239 / 255 }
        local col1 = index <= 0 and blue or { 0, 0, 0 }
        local col2 = index <= 0 and blue or { 0, 0, 0 }
        if index > 0 and index <= #colors then
            col1 = colors[index]
        end
        if index + 1 > 0 and index + 1 <= #colors then
            col2 = colors[index + 1]
        end
        return lerpColor(col1, col2, tt % 1)
    end


    local skyColors = {
        { 208 / 255, 230 / 255, 239 / 255 },
        { 173 / 255, 192 / 255, 199 / 255 },
        { 54 / 255,  195 / 255, 240 / 255 },
        --   { 0.7,       0.4,       0.9 }, -- Purple Haze
        { 208 / 255, 230 / 255, 239 / 255 },
        { 173 / 255, 192 / 255, 199 / 255 },
        { 0.4,       0.6,       0.9 }, -- Gentle Blue
        { 54 / 255,  195 / 255, 240 / 255 },
        { 208 / 255, 230 / 255, 239 / 255 },
        { 173 / 255, 192 / 255, 199 / 255 },
        { 0.95,      0.8,       0.8 }, -- Soft Pink near the horizon
        { 208 / 255, 230 / 255, 239 / 255 },
        { 173 / 255, 192 / 255, 199 / 255 },
        { 51 / 255,  63 / 255,  166 / 255 },
        { 33 / 255,  37 / 255,  78 / 255 },

        { 0,         0,         0 }
    }

    local range = 50000

    local tTop = numbers.mapInto(camYTop, range, -range, 1, #skyColors)
    local indexTop = math.floor(tTop)
    local interpolatedColorTop = safeColor(skyColors, indexTop, tTop)

    local tBottom = numbers.mapInto(camYBottom, range, -range, 1, #skyColors)
    local indexBottom = math.floor(tBottom)
    local interpolatedColorBottom = safeColor(skyColors, indexBottom, tBottom)

    local sky = gradient.makeSkyGradientList({ interpolatedColorTop, interpolatedColorBottom })
    return sky
end

-- positioning targetting camera

function getTargetPositionBeforeMe(body)
    local avgVelX = numbers.calculateRollingAverage(rollingAverageVelX)
    local avgVelY = numbers.calculateRollingAverage(rollingAverageVelY)
    local worldX, worldY = body:getWorldPoint(0, 0)

    local targetX = worldX + avgVelX / 2
    local targetY = worldY + avgVelY / 2

    -- this will look at the ground at the   x iam looking at
    targetY = lerpYAtX(targetX, stepSize)
    -- this will average with my own pos

    -- targetY = (worldY + targetY) / 2

    -- targetX = worldX
    -- targetY = worldY

    -- up untill now we assume we alsways are going forwards with the bike.
    -- what if we are being dragged high up in the air..

    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    -- this sort of describes how far in front of your vehicle you want to point the camera.
    -- when its at /4  the item will be /4 behind half screen (in other words at /4 from left)
    -- when its at /2 the item will be /2 behind half screen  (in other words at 0 from left)
    local bound = (cambrx - camtlx) / 4

    targetX = numbers.clamp(targetX, worldX - bound, worldX + bound)
    targetY = numbers.clamp(targetY, worldY - bound, worldY + bound)

    return targetX, targetY
end

function getTargetPos(body)
    local tx, ty = getTargetPositionBeforeMe(body)

    local x, y = body:getPosition()

    local poi = numbers.getClosestPointFromList({ x = x, y = y }, pointsOfInterest)
    if poi then
        local distance = numbers.getDistance(x, y, poi.x, poi.y)

        -- how to blend targets ?
        -- if pos is in smallest radius then completely look at poi
        -- if pos is in outside radius ring (radisu *2) mapinto the blend
        -- else just use tx, ty

        local t = 0
        if (distance < poi.radius) then
            t = 1
        elseif distance < poi.radius * 3 then
            t = numbers.mapInto(distance, poi.radius * 3, poi.radius, 0, 1)
        end

        local nx = numbers.lerp(tx, poi.x, t)
        local ny = numbers.lerp(ty, poi.y, t)

        --print(nx, ny, tx, ty)
        return nx, ny
    else
        print('somethign wrong with POI')
        return 0, 0
    end
end

----- rest



local timeSpent = 0

function love.update(dt)
    -- print(dt)
    --local thingToFollow = bike.frontWheel.body
    local thingToFollow = followCamera == 'mipo' and mipos[1].b2d.torso or bike.frontWheel.body

    local velX, velY = thingToFollow:getLinearVelocity()
    -- print(velX, velY)
    table.insert(rollingAverageVelX, velX)
    table.remove(rollingAverageVelX, 1)

    table.insert(rollingAverageVelY, velY)
    table.remove(rollingAverageVelY, 1)

    table.insert(rollingMemoryUsage, collectgarbage("count") / 1000)
    table.remove(rollingMemoryUsage, 1)

    updateGround(ground)
    enableDisableObstacles()
    enableDisableMipos()
    enableDisableBikes()


    --enableDisableObjects(mipos)
    -- enableDisableObjects({bike})  -- wrap the single bike in a table to make it consistent
    -- enableDisableObjects(obstacles)


    local a = bike.backWheel.body:getAngle()
    local v = bike.backWheel.body:getAngularVelocity()




    if mipoOnVehicle then
        -- try to apply angular velocity in opposite direction

        -- local bikeFrameAngle = bike.frame.body:getAngle()

        -- local mipoBody = mipos[1].b2d.torso
        --mipoBody:applyAngularImpulse(bikeFrameAngle*-1000)
        --bike.frame.body:applyAngularImpulse(bikeFrameAngle*-1000)
        -- print(bikeFrameAngle, mipoBody:getAngle())
        local b2d = mipos[1].b2d
        --  b2d.lfoot:setAngle(math.pi + math.pi / 2)
        --  b2d.rfoot:setAngle(math.pi + math.pi / 2)
        if bike.pedalWheel and bike.pedalWheel.body then
            --bike.pedalWheel.body:setAngle(a / 13)
            --bike.pedalWheel.body:setAngularVelocity(v * 10)
        end

        if bike.groundFeeler then
            local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeeler.fixture)
            local y = getYAtX(centroid[1], stepSize)
            --print(y, centroid[2])
            if centroid[2] < y then
                -- AIRTIME!!!!
                rotateToHorizontal(bike.frame.body, 0, 15, .3, dt)
                --   print('airtime')
            else
                -- print('ground')
            end
        end
    end


    world:update(dt)
    phys.handleUpdate(dt, cam)
    Timer.update(dt)
    box2dGuyCreation.rotateAllBodies(world:getBodies(), dt)

    --   print(mipos[1].b2d.torso)
    --   print(bike.frontWheel.body)
    --mipos[1].b2d.torso
    local targetX, targetY = getTargetPos(thingToFollow)
    targetY = targetY - 1000

    --  print(targetX, targetY)
    -- https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer
    -- https://www.youtube.com/watch?v=aAKwZt3aXQM&t=315s



    local avgVelX = numbers.calculateRollingAverage(rollingAverageVelX)
    --local avgVelX = numbers.calculateRollingAverage(rollingAverageVelY)
    local damping = numbers.mapInto(math.abs(avgVelX), 0, 10000, 0.0001, 5)
    --print('damping', damping)
    thingToFollow:setLinearDamping(damping)

    local curCamX, curCamY = cam:getTranslation()
    local newDistance = numbers.getDistance(curCamX, curCamY, targetX, targetY)

    local dividerFar = numbers.mapInto(newDistance, 500, 2000, 3, 5)
    --local dividerNear = numbers.mapInto(newDistance, 500, 0, 3, 0)
    local distance = numbers.getDistance(curCamX, curCamY, targetX, targetY)

    divider = dividerFar

    local delta = dt --love.timer.getAverageDelta() or dt

    local div = math.min(divider / (1 / delta), 1)
    -- print('div',div)
    -- print('newDistance', newDistance)
    --print(newDistance, div, divider)
    local smoothX = lerp(curCamX, targetX, div)
    local smoothY = lerp(curCamY, targetY, div)

    local viewWidth = 5000 ---numbers.mapInto(math.abs(avgVelX), 0, 2000, 2000, 2500)
    --if distance < 500 then viewWidth = 2000 end

    -- if distance > 500 then
    --print('yes')
    --camera.centerCameraOnPosition(targetX, targetY, viewWidth, viewWidth)
    if followCamera ~= 'free' then
        --print('****')
        --print(curCamX, targetX, divider / (1 / delta))
        --print(curCamY, targetY, divider / (1 / delta))
        --print(smoothX, smoothY, viewWidth, viewWidth)
        camera.centerCameraOnPosition(smoothX, smoothY, viewWidth, viewWidth)
    else
        -- camera.centerCameraOnPosition(smoothX, smoothY, viewWidth, viewWidth)
    end
    --  camera.centerCameraOnPosition(targetX, targetY, viewWidth, viewWidth)
    -- else
    --print('no')
    -- end
    --   love.timer.sleep(.005)
    timeSpent = timeSpent + dt
end

function drawHillGround()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)


    for i = 1, #ground.points - 2, 2 do
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] - 100,
            ground.points[i + 2], ground.points[i + 3] - 100,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 0], ground.points[i + 1] + 200)

        love.graphics.setColor(1, 1, 0)
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] + 200,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 2], cambry,
            ground.points[i + 0], cambry)
    end

    --love.graphics.polygon("fill", ground.points)
end

function drawGrassLeaves(secondParam, yOffset, xOffset, hMultiplier, batch)
    -- the individual grass leaves...
    local startX = ground.points[1]
    local startY = ground.points[2]
    local eindX = ground.points[#ground.points - 1]
    local eindY = ground.points[#ground.points]

    --for i = startX, eindX, 50 do
    --    love.graphics.line(i, startY, i, startY - 100)
    --end


    --  if true then
    -- atlasArray = love.graphics.newArrayImage({ 'floweratlas.png' })

    local count = #quads
    local rand = love.math.random
    local w, h = love.graphics.getDimensions()

    --  for i = 1, testsize do
    --      local a = rand() * math.pi / 4 - (math.pi / 8)
    --      local index = math.ceil(rand() * count)
    --      local ori = origins[index]
    --      batch2:addLayer(1, quads[index], rand() * w, h, a, 1, 1, ori[1], ori[2])
    --  end
    --end


    local ccc = 0
    for i = 1, #ground.points, 2 do
        if i > 1 and i < #ground.points - 1 then
            local x = ground.points[i]
            local y = ground.points[i + 1]
            local x2 = ground.points[i + 2]
            local y2 = ground.points[i + 3]

            for j = 0, stepSize - 1, 75 do
                local yy = lerpYAtX(x + j, stepSize)
                local hh = love.math.noise((x + j) / 1000, secondParam, j * 2) * 200 * hMultiplier
                -- love.graphics.line(x + j + xOffset, yy + yOffset, x + j + xOffset, yy - hh + yOffset)

                local index = math.ceil((j % count) + 1)
                --print(index)
                local ori = origins[index]
                local angle = math.sin(hh) / 10
                angle = angle + math.sin(timeSpent) / 10
                --print(angle)
                batch:addLayer(1, quads[index], x + j + xOffset, yy + yOffset, angle, 2, 2 * hh / 200, ori[1], ori[2])
                ccc = ccc + 1
            end
        end
    end
    -- print(ccc)
end

local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end


local function textureTheBike(bike, bikeData)
    local img          = wheelImages[frontWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)

    ----
    local img          = wheelImages[backWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.draw(img, x, y, a + math.pi, sx, sy, dimsH / 2, dimsW / 2)
end

function love.draw()
    ui.handleMouseClickStart()
    love.graphics.clear(1, 0, 1)
    love.graphics.setColor(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    local w, h = love.graphics.getDimensions()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    local sky = false --skyGradient(camtly, cambry)

    if sky then
        love.graphics.draw(sky, 0, 0, 0, w, h)
    end
    cam:push()

    drawHillGround()

    local batch1 = love.graphics.newSpriteBatch(atlasImg)
    local batch2 = love.graphics.newSpriteBatch(atlasImg)

    drawGrassLeaves(100, -100, 0, .5, batch2)
    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(batch2)
    phys.drawWorld(world)

    for i = 1, #mipos do
        local bx = mipos[i].b2d.torso:getX()
        if (bx > camtlx - 1000 and bx < cambrx + 1000) then
            texturedBox2d.drawSkinOver(mipos[i].b2d, mipos[i])
            --texturedBox2d.drawNumbersOver(mipos[i].b2d)
        end
    end

    -- texture the bike
    love.graphics.setColor(0, 0, 0)
    textureTheBike(bike, bikeData2)


    drawGrassLeaves(.3, 200, 25, .75, batch1)
    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(batch1)



    love.graphics.setColor(0, 0, 0)
    local sx = stepSize / grassImage:getWidth()
    local imgH = grassImage:getHeight()
    local vertsBackground = {}
    local vertsForground = {}

    for i = 1, #ground.points, 2 do
        if i > 1 and i < #ground.points - 1 then
            local x = ground.points[i]
            local y = ground.points[i + 1]

            local x2 = ground.points[i + 2]
            local y2 = ground.points[i + 3]

            local dx = x2 - x
            local dy = y2 - y
            local angle = math.atan2(dy, dx)

            table.insert(vertsBackground, x)
            table.insert(vertsBackground, y - 100)
            table.insert(vertsForground, x)
            table.insert(vertsForground, y + 200)


            --    curve = love.math.newBezierCurve( vertices )

            --love.graphics.draw(grassImage, x, y, angle, sx, sx)
            --   love.graphics.draw(grassImage, x, y - imgH, angle, sx, sx)
            --print(x)
        end
    end




    --print(startX, eindX, (eindX - startX) / 50)

    --curve = love.math.newBezierCurve(vertsBackground)
    --love.graphics.line(curve:render())
    --curve = love.math.newBezierCurve(vertsForground)
    --love.graphics.line(curve:render())


    love.graphics.setColor(1, 1, 1)
    local wx, wy = bike.frontWheel.body:getPosition()
    local yy = lerpYAtX(wx, stepSize)
    love.graphics.circle('fill', wx, yy, 10)
    love.graphics.setColor(0.3, 0.3, 0.3)

    for i = 1, #pointsOfInterest do
        local poi = pointsOfInterest[i]
        love.graphics.circle('line', poi.x, poi.y, poi.radius)
        love.graphics.circle('line', poi.x, poi.y, poi.radius * 3)
    end
    love.graphics.setColor(1, 1, 1)
    local targetX, targetY = getTargetPos(bike.frontWheel.body)
    love.graphics.rectangle('line', targetX, targetY, 40, 40)

    local curCamX, curCamY = cam:getTranslation()
    love.graphics.circle('line', curCamX, curCamY, 20)
    cam:pop()


    love.graphics.setColor(0, 0, 0, 0.5)

    local stats = love.graphics.getStats()
    local memavg = numbers.calculateRollingAverage(rollingMemoryUsage)
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = tostring(love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    love.graphics.print(mem .. '  ' .. vmem .. '  ' .. draws .. ' ' .. fps)

    function circleLabelButton(x, y, radius, label)
        love.graphics.setColor(0, 0, 0, 0.5)

        local a = ui.getUICircle(x, y, radius)
        love.graphics.circle('fill', x, y, radius)
        love.graphics.setColor(1, 1, 1, 1)
        local strW = font:getWidth(label)
        local strH = font:getHeight() * text.countLines(label)
        love.graphics.print(label, x - strW / 2, y - strH / 2)
        return a
    end

    -- CAMREA BUTTON
    local size = 100
    local x = size / 2
    local y = h - size + size / 2

    if circleLabelButton(x, y, size / 2, 'CAM\n' .. followCamera) then
        if followCamera == 'free' then
            followCamera = 'bike'
        elseif followCamera == 'bike' then
            followCamera = 'mipo'
        elseif followCamera == 'mipo' then
            followCamera = 'free'
        end
    end

    local x = size / 2 + size
    if circleLabelButton(x, y, size / 2, mipoOnVehicle and 'UNLINK' or 'LINK') then
        if not mipoOnVehicle then
            connectMipoAndVehicle()
        else
            disconnectMipoAndVehicle()
        end
        mipoOnVehicle = not mipoOnVehicle
    end

    if mipoOnVehicle then
        local x = size / 2 + size * 2
        if circleLabelButton(x, y, size / 2, 'PEDAL') then
            cycleStep()
        end
    end
end

local function getVehicleMass(vehicle)
    local mass = 0
    if vehicle.frame then
        mass = mass + vehicle.frame.body:getMass()
    end
    if vehicle.frontWheel then
        mass = mass + vehicle.frontWheel.body:getMass()
    end
    if vehicle.backWheel then
        mass = mass + vehicle.backWheel.body:getMass()
    end
    return mass
end

function disableLegs()
    local b2d = mipos[1].b2d
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })
    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, 0, math.pi / 2, 'revolute')
    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, 0, math.pi / 2, 'revolute')

    --   box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
    --   box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')

    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, math.pi / 2, 'revolute')
    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi / 2, 'revolute')
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then
        cycleStep()
        --local body = bike.frame.body
        --body:applyLinearImpulse(1000,0)
    end
    -- if k == '.' then
    --     followCamera = not followCamera
    -- end
    if k == 'd' then
        disableLegs()
    end
    if k == 'x' then
        bike.frontWheel.body:setAngularVelocity(-100000)
        -- bike.backWheel.body:setAngularVelocity(-1000)
    end
    if k == 'w' then
        local mass = getVehicleMass(bike)
        print(mass)
        bike.frame.body:applyLinearImpulse(0, -(mass * 1000))
        bike.frame.body:setAngularVelocity(-mass)
    end
    if k == 'a' then
        local f = -100
        for i = 1, #mipos do
            mipos[i].b2d.torso:setAngularVelocity(f)
            mipos[i].b2d.luleg:setAngularVelocity(f)
            mipos[i].b2d.ruleg:setAngularVelocity(f)
            if mipos[i].b2d.head then
                mipos[i].b2d.head:setAngularVelocity(f)
            end
        end
    end
    if k == 'left' then
        local body = bike.frame.body
        --  body:applyTorque(-100000)
        body:applyAngularImpulse(-10000)
        -- rotateToHorizontal(body, 0, 5, 0.1, dt)
    end
    if k == 'right' then
        local body = bike.frame.body
        --body:applyTorque(1000000)
        body:applyAngularImpulse(100000)
        --  rotateToHorizontal(body, 0, 5, 0.1, dt)
    end
end

function love.mousemoved(x, y, dx, dy)
    if followCamera == 'free' then
        if love.keyboard.isDown('space') or love.mouse.isDown(3) then
            local x, y = cam:getTranslation()
            cam:setTranslation(x - dx / cam.scale, y - dy / cam.scale)
        end
    end
end

function love.wheelmoved(dx, dy)
    if followCamera == 'free' then
        local newScale = cam.scale * (1 + dy / 10)
        if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
        end
    end
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            local force = ud and (ud.bodyType == 'torso') and 1000000 or 50000
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
    ui.addToPressedPointers(x, y, id)
end

function love.mousepressed(x, y, button, istouch)
    print('mousepresed')
    if not istouch then
        if button == 1 then
            pointerPressed(x, y, 'mouse')
        end
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    pointerPressed(x, y, id)
    -- ui.addToPressedPointers(x, y, id)
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
    ui.removeFromPressedPointers(id)
end

function love.mousereleased(x, y, button, istouch)
    lastDraggedElement = nil
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
    --ui.removeFromPressedPointers(id)
end

if false then
    local TICKRATE = 1 / 60
    function love.run()
        if love.math then
            love.math.setRandomSeed(os.time())
        end

        if love.load then love.load(arg) end

        local previous = love.timer.getTime()
        local lag = 0.0
        while true do
            local current = love.timer.getTime()
            local elapsed = current - previous
            previous = current
            lag = lag + elapsed

            if love.event then
                love.event.pump()
                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            return a
                        end
                    end
                    love.handlers[name](a, b, c, d, e, f)
                end
            end

            while lag >= TICKRATE do
                if love.update then love.update(TICKRATE) end
                lag = lag - TICKRATE
            end

            if love.graphics and love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()
                if love.draw then love.draw(lag / TICKRATE) end
                love.graphics.present()
            end
        end
    end
end


function love.load()
    local ffont = "WindsorBT-Roman.otf"

    font = love.graphics.newFont(ffont, 24)

    love.graphics.setFont(font)
    jointsEnabled = true
    followCamera = 'bike'
    startExample()

    pointsOfInterest = {}

    grassImage = love.graphics.newImage('world-assets/grass1.png')
    mipoOnVehicle = false

    wheelImages = { love.graphics.newImage('assets/vehicleparts/wheel1.png')
    , love.graphics.newImage('assets/vehicleparts/wheel2.png')
    , love.graphics.newImage('assets/vehicleparts/wheel3.png')
    , love.graphics.newImage('assets/vehicleparts/wheel4.png') }

    frontWheelImgIndex = math.ceil(#wheelImages * love.math.random())
    backWheelImgIndex = math.ceil(#wheelImages * love.math.random())

    local w, h = love.graphics.getDimensions()

    for i = 1, 1 do
        local x = -200000 + love.math.random() * 400000
        local y = lerpYAtX(x, stepSize)
        table.insert(pointsOfInterest,
            { x = x, y = y - 500 + love.math.random() * 1000, radius = 400 })
    end

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)
end
