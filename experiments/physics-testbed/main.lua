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
local connect = require 'lib.connectors'



function prepareMipoAndVehicleForConnection(mipo, vehicle)
    -- what are the steps that need to be taken?
 

    -- the legs possibly (but not always) need to be turned off (both for collsiiosn and for straightening every frame)
    -- body and feet need to be positioned with their connector over at the right connector at the ibike
    -- the arms need to be positioned in a way they can be connected to the steer (if needed)
    -- the connections can be made (hand/feet/butt)
    --- we need some kind of flag somewhere for rendering, so i can render the mipo and bike in 1 function. (to fix order issue (both behind and over))

    -- .....



    -- diconnecting is sort of the same stuff but reversed..
    -- remove flag
    -- break connections
    -- turn all body parts back on
    -- straighten again
end

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

    local y1 = generateWave(150 * 10.78, 30)
    local y2 = generateWave(70 * 10.78, 17)
    local y3 = generateWave(20 * 10.78, 5)

    y3 = y3 * ((math.sin(x / 30) + 1) / 2) -- Apply roughness condition

    local linear = numbers.mapInto(x / stepSize, -20, 20, -STEEPNESS, STEEPNESS)

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

    -- why is this numbers growing so much when i add more mipos ?
    --print(camtlx / stepSize, cambrx / stepSize)

    for i = 1 - extraSteps, steps + 2 + extraSteps do
        local x = (math.floor(camtlx / stepSize) * stepSize) + (i - 1) * stepSize
        local y = getYAtX(x, stepSize)

        table.insert(points, x)
        table.insert(points, y)
    end
    -- print(inspect(points))

    ground.shape = love.physics.newChainShape(false, points)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
    ground.fixture:setUserData("ground")
    ground.fixture:setFriction(1)

    ground.points = points
end

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

local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
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



function makePedalBike(x, y, data)
    local floorWidth = data.floorWidth or data.radius 
    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth/2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)
    ball1.body:setAngularVelocity(10000)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth/2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius * 1.3)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
   --ball2.fixture:setFriction(1)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 100)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 5)
    frame.fixture:setSensor(true)
   
    local seat = {}
    seat.body = love.physics.newBody(world, x, y-data.steeringHeight*1.5, "dynamic")
    seat.shape = love.physics.newRectangleShape(0, -data.steeringHeight*1.5, 200, 200)
    seat.fixture = love.physics.newFixture(frame.body, seat.shape, 2)
    connect.makeAndAddConnector(frame.body, 0,  -data.steeringHeight*1.5, {type='seat'}, 205, 205)
    
    if false then
    local seat2 = {}
    seat2.shape = love.physics.newRectangleShape(-1000, -600, 200, 200)
    seat2.fixture = love.physics.newFixture(frame.body, seat2.shape, 1)
    connect.makeAndAddConnector(frame.body, -1000, -600, {}, 205, 205)
    end

    --local achterWielSpat = {}
    --achterWielSpat.shape = love.physics.newRectangleShape(-radius/1.4, -500, 20, 500)
    --achterWielSpat.fixture = love.physics.newFixture(frame.body, achterWielSpat.shape, 1)
    local steerHeight =  data.steeringHeight
    
    local steer = {}
  
   -- steer.shape = love.physics.newRectangleShape(floorWidth/2, -steerHeight/2, 10, steerHeight)
   -- steer.fixture = love.physics.newFixture(frame.body, steer.shape, 0)
    --steer.fixture:setSensor(true)
    if false then
    connect.makeAndAddConnector(frame.body, floorWidth/2 - 40, -steerHeight - 40, {}, 125, 125)
    connect.makeAndAddConnector(frame.body, floorWidth/2, -steerHeight, {}, 125, 125)
    end
  
    local pedal = {}
    pedal.body = love.physics.newBody(world, x , y-data.steeringHeight , "dynamic")
    pedal.shape = love.physics.newRectangleShape(200, 200)
    pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, 1)
    pedal.fixture:setSensor(true)
    connect.makeAndAddConnector(pedal.body, -150, 0, {type='lfoot'}, 110, 110)
    connect.makeAndAddConnector(pedal.body, 150, 0, {type='rfoot'}, 110, 110)

    local joint1 = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)
    pedal.fixture:setSensor(true)
  

    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


    --joint1:setMotorEnabled(true)
    --joint1:setMotorSpeed(500000)
    --joint1:setMaxMotorTorque(20000)


    return { frontWheel = ball1, backWheel = ball2, pedalWheel = pedal, frame = frame, seat= seat }
end



function makeScooter(x, y, data)
    local floorWidth = data.floorWidth or data.radius 
    local radius = data.radius

    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + floorWidth/2, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 3)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    --ball1.fixture:setFriction(1)
    ball1.body:setAngularVelocity(10000)

    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - floorWidth/2, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius * 1.3)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 3)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
   --ball2.fixture:setFriction(1)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(floorWidth, 100)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, 3)
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
    local steerHeight =  data.steeringHeight
    steer.shape = love.physics.newRectangleShape(floorWidth/2, -steerHeight/2, 10, steerHeight)
    steer.fixture = love.physics.newFixture(frame.body, steer.shape, 0)
    --steer.fixture:setSensor(true)
    connect.makeAndAddConnector(frame.body, floorWidth/2 - 40, -steerHeight - 40, {}, 125, 125)
    connect.makeAndAddConnector(frame.body, floorWidth/2, -steerHeight, {}, 125, 125)

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


    return { frontWheel = ball1, backWheel = ball2, pedalWheel = pedal, frame = frame }
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
    local b = bike     --mipos[i]
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
            v.body:setPosition(b2x, b2y ) end
        end
    end

    if bx >= xMinR and bx <= xMaxR then
        for k, v in pairs(b) do
            if v.body then
            v.body:setActive(true)
            v.body:setGravityScale(1) end
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

function startExample(number)
    phys.setupWorld()
    stepSize = 300
    ground = initGround()
    mipos = addMipos.make(1)
    obstacles = {}

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


    -- get data from the mipos[1] to make a fitted bike 
    local c= mipos[1].dna.creation
   --print(inspect(c.lfoot))
    local scooterData = {
        type = 'scooter',
        steeringHeight = c.luleg.h + c.llleg.h + c.torso.h/2,
        floorWidth = math.max(c.lfoot.h * 2,  c.torso.w * 1.2),
        radius = 100
    }
    local bikeData = {
        type = 'bike',
        steeringHeight = c.luleg.h + c.llleg.h,
        floorWidth = c.luleg.h + c.llleg.h + c.torso.h,
        radius = 200
    }
    bike = makeScooter(-2000, -5000, scooterData)
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

function love.load()
    local ffont = "WindsorBT-Roman.otf"

    font = love.graphics.newFont(ffont, 24)

    love.graphics.setFont(font)
    jointsEnabled = true
    followCamera = 'bike'
    startExample()

    pointsOfInterest = {}

    grassImage = love.graphics.newImage('world-assets/grass1.png')
    local w, h = love.graphics.getDimensions()

    for i = 1, 100 do
        local x = -200000 + love.math.random() * 400000
        local y = lerpYAtX(x, stepSize)
        table.insert(pointsOfInterest,
            { x = x, y = y - 500 + love.math.random() * 1000, radius = 400 })
    end

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) }
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

local function getDistanceSquared(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local result = (dx * dx) + (dy * dy)
    return result
end

local function calculateRollingAverage(valueList)
    local sum = 0
    for _, value in ipairs(valueList) do
        sum = sum + value
    end
    return sum / #valueList
end

function lerpYAtX(targetX, stepSize)
    local x1 = math.floor(targetX / stepSize) * stepSize
    local x2 = math.ceil(targetX / stepSize) * stepSize

    local y1 = getYAtX(x1, stepSize)
    local y2 = getYAtX(x2, stepSize)

    local y3 = numbers.mapInto(targetX, x1, x2, y1, y2)
    return y3
end

function getTargetPositionBeforeMe(body)
    local avgVelX = calculateRollingAverage(rollingAverageVelX)
    local avgVelY = calculateRollingAverage(rollingAverageVelY)
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

local function getClosestPointFromList(pos, list)
    local closestDistance = math.huge
    local closest = nil

    for i = 1, #list do
        local val = getDistanceSquared(pos.x, pos.y, list[i].x, list[i].y)
        if val < closestDistance then
            closestDistance = val
            closest = list[i]
        end
    end

    return closest
end

function getTargetPos(body)
    local tx, ty = getTargetPositionBeforeMe(body)

    local x, y = body:getPosition()

    local poi = getClosestPointFromList({ x = x, y = y }, pointsOfInterest)
    if poi then
        local distance = getDistance(x, y, poi.x, poi.y)

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
    
    local a = bike.frontWheel.body:getAngle()
    local v = bike.frontWheel.body:getAngularVelocity()

    if bike.pedalWheel then
    bike.pedalWheel.body:setAngle(a / 10)
   -- bike.pedalWheel.body:setAngularVelocity(v/100)
    end
    world:update(dt)
    phys.handleUpdate(dt, cam)

    box2dGuyCreation.rotateAllBodies(world:getBodies(), dt)


    --   print(mipos[1].b2d.torso)
    --   print(bike.frontWheel.body)
    --mipos[1].b2d.torso
    local targetX, targetY = getTargetPos(thingToFollow)

    --  print(targetX, targetY)
    -- https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer
    -- https://www.youtube.com/watch?v=aAKwZt3aXQM&t=315s



    local avgVelX = calculateRollingAverage(rollingAverageVelX)
    --local avgVelX = calculateRollingAverage(rollingAverageVelY)
    local damping = numbers.mapInto(math.abs(avgVelX), 0, 10000, 0.0001, 5)
    --print('damping', damping)
    thingToFollow:setLinearDamping(damping)

    local curCamX, curCamY = cam:getTranslation()
    local newDistance = getDistance(curCamX, curCamY, targetX, targetY)

    local dividerFar = numbers.mapInto(newDistance, 500, 2000, 3, 5)
    --local dividerNear = numbers.mapInto(newDistance, 500, 0, 3, 0)
    local distance = getDistance(curCamX, curCamY, targetX, targetY)

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

function countLines(str)
    local _, count = str:gsub('\n', '\n')
    return count + 1 -- Add 1 to account for the last line without a newline
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
    phys.drawWorld(world)

    for i = 1, #mipos do
        local bx = mipos[i].b2d.torso:getX()
        if (bx > camtlx - 1000 and bx < cambrx + 1000) then
            texturedBox2d.drawSkinOver(mipos[i].b2d, mipos[i])
        end
    end


    love.graphics.setColor(0, 0, 0)
    local sx = stepSize / grassImage:getWidth()
    local imgH = grassImage:getHeight()
    for i = 1, #ground.points, 2 do
        if i > 1 and i < #ground.points - 1 then
            local x = ground.points[i]
            local y = ground.points[i + 1]

            local x2 = ground.points[i + 2]
            local y2 = ground.points[i + 3]

            local dx = x2 - x
            local dy = y2 - y
            local angle = math.atan2(dy, dx)



            --love.graphics.draw(grassImage, x, y, angle, sx, sx)
            love.graphics.draw(grassImage, x, y - imgH, angle, sx, sx)
        end
    end


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
    local memavg = calculateRollingAverage(rollingMemoryUsage)
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = tostring(love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    love.graphics.print(mem .. '  ' .. vmem .. '  ' .. draws .. ' ' .. fps)




    -- CAMREA BUTTON
    local size = 100
    local x = size / 2
    local y = h - size + size / 2
    local a = ui.getUICircle(x, y, size / 2)
    love.graphics.circle('fill', x, y, size / 2)
    love.graphics.setColor(1, 1, 1, 1)

    -- local str = 'cam:\nfree'
    -- local str = 'cam:\nbike'
    -- local str = 'cam:\nmipo'
    local str = 'CAM\n' .. followCamera
    local strW = font:getWidth(str)
    local strH = font:getHeight() * countLines(str)
    love.graphics.print(str, x - strW / 2, y - strH / 2)

    if a then
        if followCamera == 'free' then
            followCamera = 'bike'
        elseif followCamera == 'bike' then
            followCamera = 'mipo'
        elseif followCamera == 'mipo' then
            followCamera = 'free'
        end
       -- print('click yo!')
    end
    -- CALL BIKE BUTTON

  local x = size / 2 + size
  love.graphics.setColor(0, 0, 0, 0.5)
  local a = ui.getUICircle(x, y, size / 2)
  love.graphics.circle('fill', x, y, size / 2)
  love.graphics.setColor(1, 1, 1, 1)
  local str = 'CALL\nBike'
    local strW = font:getWidth(str)
    local strH = font:getHeight() * countLines(str)
    love.graphics.print(str, x - strW / 2, y - strH / 2)
    if a then 
        --local tx, ty =  bike.frame.body:getPosition()
       -- print('bike before', tx,ty)
       --mipos[1].b2d.torso:applyLinearImpulse(0, -10000)
       --mipos[1].b2d.torso:setLinearVelocity(0, -10000)
        local tx, ty = mipos[1].b2d.torso:getPosition()
        --mipos[1].b2d.torso:setPosition(tx, ty -1000)
        --print('torso before', tx, ty)
      --  bike.frame.body:setPosition(tx, ty - 1000)
        for k, v in pairs(bike) do
            --v.body:setActive(false)
            --v.body:setGravityScale(0)
            if v.body then
            v.body:setPosition(tx , ty)
            v.body:setAngle(0)
            v.body:setLinearVelocity( 0,0 )
            v.body:setAngularVelocity( 0 )
           --v.body:applyLinearImpulse(0, -1000) 
        end
        end

        bike.seat.body:setPosition(tx , ty)



        local b2d = mipos[1].b2d

        connect.breakAllConnectionsAtBody(b2d.lhand)
        connect.breakAllConnectionsAtBody(b2d.rhand)
        connect.breakAllConnectionsAtBody(b2d.lfoot)
        connect.breakAllConnectionsAtBody(b2d.rfoot)
        connect.breakAllConnectionsAtBody(b2d.torso)
        connect.inspectAllConnectors()
        
        if false then

        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, {sleeping=true})
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, {sleeping=true})
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, {sleeping=true})
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, {sleeping=true})


        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, -math.pi, math.pi/2, 'revolute')
        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, -math.pi, math.pi/2,  'revolute')

        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, math.pi, 'revolute')
        box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi,  'revolute')



       -- box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, 0, math.pi 'revolute')
       -- box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, -math.pi, 0, 'revolute')
       -- box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, 0, math.pi, 'revolute')
       -- box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi, 'revolute')


        --box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')
        --box2dGuyCreation.setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, false, 'revolute')
      --  box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
       -- box2dGuyCreation.setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, false, 'revolute')
        end

        local function setSensorValueBody(body, value) 
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do 
                fixture:setSensor(value)
            end
        end

        local function getConnectorFixtureAtBodyOfType(body, type) 

            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do 
                local ud = fixture:getUserData()
                if ud then
                    if ud.bodyType == "connector" then 
                        --print(inspect(ud))
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
        if false then
        setSensorValueBody(b2d.luleg, true) 
        setSensorValueBody(b2d.llleg, true) 
      --  setSensorValueBody(b2d.lfoot, true) 
        setSensorValueBody(b2d.ruleg, true) 
        setSensorValueBody(b2d.rlleg, true) 

        local buttFixture = getConnectorFixtureAtBodyOfType(b2d.torso, 'butt')   
        local bx, by =  buttFixture:getBody():getPosition()

        local localX, localY = b2d.torso:getLocalPoint( bx, by )
        
        
        local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')   
        local sx, sy =  seatFixture:getBody():getPosition()

        local centroid = getCentroidOfFixture(bike.frame.body, seatFixture)
       -- print(centroid[1], centroid[2], sx, 

       --b2d.torso:setAngle(math.pi/2 )
        b2d.torso:setPosition(centroid[1], centroid[2]-100)


        --can we make a connection ?
            connect.forceConnection(buttFixture, seatFixture)

            local lfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'lfoot')   
            local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lfoot, 'foot')   
            connect.forceConnection(lfootPedalFixture, lfootFixture)

            local rfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'rfoot')   
            local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rfoot, 'foot')   
            connect.forceConnection(rfootPedalFixture, rfootFixture)



        --print(sx,sy)
        end
        
        --print(localX, localY)
        -- get butt fixture 






      --  setSensorValueBody(b2d.rfoot, true) 
       
        -- sensor 
        
        --b2d.luleg.
       -- prepareMipoAndVehicleForConnection(mipos[1], bike)

       -- local tx, ty =  bike.frame.body:getPosition()
       -- print('bike after', tx,ty)
        -- find posiition of mipo
        -- set posiiton of bike
    
    end
end






function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then bike.frontWheel.body:setAngularVelocity(10000) end
    -- if k == '.' then
    --     followCamera = not followCamera
    -- end
    if k == 'x' then
        bike.frontWheel.body:setAngularVelocity(-100000)
        -- bike.backWheel.body:setAngularVelocity(-1000)
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
end

function love.mousemoved(x, y, dx, dy)
    if love.keyboard.isDown('space') or love.mouse.isDown(3) then
        local x, y = cam:getTranslation()
        cam:setTranslation(x - dx / cam.scale, y - dy / cam.scale)
    end
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if (newScale > 0.01 and newScale < 50) then
        cam:scaleToPoint(1 + dy / 10)
    end
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            local force = ud and ud.bodyType == 'torso' and 1000000 or 50000
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
    ui.addToPressedPointers(x, y, id)
end

function love.mousepressed(x, y, button, istouch)
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
local TICKRATE = 1/60
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
            for name, a,b,c,d,e,f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a
                    end
                end
                love.handlers[name](a,b,c,d,e,f)
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