function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        print(a)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

print('before wait for event')
waitForEvent()
print('after wait for event')

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
local vehicle          = require 'vehicle-creator'
local animParticles    = require 'frameAnimParticle'

function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

local function isDraggingAFrame()
    --
    local bodies = world:getBodies()
    local isBeingPointerJointed = false

    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()

        for j = 1, #pointerJoints do
            local mj = pointerJoints[j]
            if mj.jointBody == body then
                isBeingPointerJointed = true
            end
        end
        for _, fixture in ipairs(fixtures) do
            local userData = fixture:getUserData()
            if (userData) then
                if isBeingPointerJointed then
                    if userData.bodyType == 'frame' then
                        return true
                    end
                end
            end
        end
    end
    return false
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
local function getBodyMass(mipo)
    local total = 0
    for k, v in pairs(mipo.b2d) do
        --print(k,v)
        --v:setGravityScale(0)
        if (v) then
            total = total + v:getMass()
        end
    end

    return total
end
function hex2rgb(hex, alpha)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255, alpha and alpha or 1
end

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
    print(inspect(mipos[1].dna.multipliers))
    obstacles = {}

    -- try to insert some houses, with jumpy roofs.
    -- lets start with the roofs.


    -- first try and localte a point where these 2 conditions are met:
    -- my next step is higher then me
    -- the step after that is lower .


    --makeCow(0, -0, 15000, 8000)
    --makeCow(20000, -0, 15000, 8000)
    --makeCow(50000, -0, 15000, 8000)

    -- makeSlide(0, 0, 15000, 15000)
    -- makeSlide(25000, 0, 20000, 20000)
    -- makeSlide(50000, 0, 20000, 20000)
    -- makeSlide(75000, 0, 20000, 20000)

    if true then
        for i = 2, 100 do
            local rangeSize = 75

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

            local points = { x1, y1, x3, y3 - 1000, x3 + stepSize * 5, y3 - 1100 }
            local schansBody = love.physics.newBody(world, 0, 0, "static")
            local schansShape = love.physics.newChainShape(false, points)
            local fixture = love.physics.newFixture(schansBody, schansShape)
            fixture:setUserData(makeUserData('ground'))

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
            --  local o = makeRandomTriangle(i * 30, -500, 500)
            --  table.insert(obstacles, o)
        end
    end

    -- makeChain(0,-5000,10)
    for i = 0, 10 do
        --    makeCarousell(i * 5000, 0, 1500, 500, 1)
    end
    -- get data from the mipos[1] to make a fitted bike
    local c = mipos[1].dna.creation
    --print(inspect(c.lfoot))


    --isPedalBike = false


    bike, bikeData = vehicle.createVehicleUsingDNACreation('bike', c, -2000, -5000)
    print(bike, bikeData)
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
    --local h2 = love.math.noise(x / 10000)
    local STEEPNESS = 3000 -- * h2
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
    ground.fixture:setUserData(makeUserData("ground"))
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

-- vehicle stuff




function cycleStep()
    -- bike.frontWheel.body:setAngularVelocity(120000)
    --  bike.backWheel.body:setAngularVelocity(120000)
    --bike.frame.body:applyLinearImpulse(10000, -1000)
    if bike.pedalWheel then
        bike.backWheel.body:applyAngularImpulse(1000000)
        -- bike.frontWheel.body:applyAngularImpulse(1000000)
        bike.pedalWheel.body:applyAngularImpulse(1000000)
    end
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


    -- dit truukje werkt hier niet omdat als active = fals e je de mipo niet meer kan lanceren,
    for k, v in pairs(b2d) do
        v:setGravityScale(0)
        --v:setActive(false)
    end
    Timer.after(.2, function()
        for k, v in pairs(b2d) do
            v:setGravityScale(1)
            v:setActive(true)
        end
    end)

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


                setSensorValueBody(b2d.torso, false)
                if (b2d.head) then
                    setSensorValueBody(b2d.head, false)
                end
                if (b2d.neck) then
                    setSensorValueBody(b2d.neck, false)
                    setSensorValueBody(b2d.neck1, false)
                end

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


    local bodyMass = getBodyMass(mipos[1])
    print(bodyMass)
    b2d.torso:applyLinearImpulse(0, -1500 * bodyMass)

    updatePart.resetPositions(mipos[1])
    b2d.torso:applyLinearImpulse(0, -1500 * bodyMass)
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



        v:setActive(false)
    end
    Timer.after(.2, function()
        for k, v in pairs(b2d) do
            --print(k,v)
            v:setGravityScale(0)



            v:setActive(true)
        end
    end)

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
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.lear, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rear, { sleeping = true })

        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })

        box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.torso, { sleeping = true })
        if b2d.head then
            box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.head, { sleeping = true })
        end
        -- box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
        --box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')
        ----box2dGuyCreation.setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, false, 'revolute')
        --box2dGuyCreation.setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, false, 'revolute')
        if true then
            --   setSensorValueBody(b2d.luleg, true)
            --   setSensorValueBody(b2d.llleg, true)
            --setSensorValueBody(b2d.lfoot, true)
            --   setSensorValueBody(b2d.ruleg, true)
            --   setSensorValueBody(b2d.rlleg, true)
            -- setSensorValueBody(b2d.rfoot, true)
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
        --  box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.torso, { sleeping = true })

        --box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
        --box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
        -- box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
        -- box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })
        --   box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.lfoot, { sleeping = true })
        --   box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rfoot, { sleeping = true })

        -- b2d.luleg:setAngle(math.pi / 2)
        -- b2d.ruleg:setAngle(math.pi / 2)
        -- disableLegs()
        if true then
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, -math.pi, math.pi / 2, 'revolute')
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, -math.pi, math.pi / 2, 'revolute')

            box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
            box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')

            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, 0, 'revolute')
            box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, 0, 'revolute')

            box2dGuyCreation.setJointLimitBetweenBodies(b2d.ruleg, b2d.rlleg, false, 'revolute')
            box2dGuyCreation.setJointLimitBetweenBodies(b2d.luleg, b2d.llleg, false, 'revolute')
        end


        if true then
            setSensorValueBody(b2d.luleg, true)
            setSensorValueBody(b2d.llleg, true)
            setSensorValueBody(b2d.lfoot, true)
            setSensorValueBody(b2d.ruleg, true)
            setSensorValueBody(b2d.rlleg, true)
            setSensorValueBody(b2d.rfoot, true)

            setSensorValueBody(b2d.rhand, true)
            setSensorValueBody(b2d.lhand, true)
            setSensorValueBody(b2d.luarm, true)
            setSensorValueBody(b2d.llarm, true)
            setSensorValueBody(b2d.ruarm, true)
            setSensorValueBody(b2d.rlarm, true)

            setSensorValueBody(b2d.torso, true)

            if (b2d.head) then
                setSensorValueBody(b2d.head, true)
            end
            if (b2d.neck) then
                setSensorValueBody(b2d.neck, true)
                setSensorValueBody(b2d.neck1, true)
            end
        end

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

function makeSlide(x, y, w, h)
    -- this thing has 2 poles it stands on.
    -- and the slide surface

    function makePole(x, y, w, h)
        local pole = {}
        pole.body = love.physics.newBody(world, x, y, "static")
        pole.shape = makeRectPoly2(w, h, 0, -h / 2)
        pole.fixture = love.physics.newFixture(pole.body, pole.shape, 10)
        pole.fixture:setSensor(true)
        return pole
    end

    local x1 = x - w / 2
    local y1 = getYAtX(x1, stepSize)
    local y1Top = y1 - h
    local p1 = makePole(x1, y1, w / 25, h)

    local x2 = x + w / 2
    local y2 = getYAtX(x2, stepSize)
    local y2Top = y2 - h / 5
    local p2 = makePole(x2, y2, w / 25, h / 5)

    -- now describe a curve in a few steps
    local xb = numbers.lerp(x1, x2, 0.5)
    local yb = numbers.lerp(y1Top, y2Top, 0.75)
    local xb2 = numbers.lerp(x1, x2, 0.75)
    local yb2 = numbers.lerp(y1Top, y2Top, 0.95)
    local xover = numbers.lerp(x1, x2, 1.1)
    local yover = numbers.lerp(y1Top, y2Top, 0.995)
    local curve = love.math.newBezierCurve({ x1, y1Top, xb, yb, xb2, yb2, x2, y2Top, xover, yover })

    local points = {}
    for i = 0, 10, 1 do
        local t = i / 10
        local px, py = curve:evaluate(t)
        table.insert(points, px)
        table.insert(points, py)
    end

    local slide = {}
    slide.body = love.physics.newBody(world, 0, 0, "static")
    slide.shape = love.physics.newChainShape(false, points)
    slide.fixture = love.physics.newFixture(slide.body, slide.shape, 1)
    -- ground.shape = love.physics.newChainShape(false, points)
    -- ground.fixture = love.physics.newFixture(ground.body, ground.shape)
end

function makeCow(x, y, bodyWidth, bodyHeight)
    local cow = {}
    cow.torso = {}
    cow.torso.body = love.physics.newBody(world, x, y, "dynamic")
    cow.torso.shape = love.physics.newRectangleShape(bodyWidth, bodyHeight)
    cow.torso.fixture = love.physics.newFixture(cow.torso.body, cow.torso.shape, 10)

    function makeLeg(x, y, w, h, j)
        local leg = {}
        leg.body = love.physics.newBody(world, x, y, "static")
        leg.shape = makeRectPoly2(w, h, 0, h / 2)
        leg.fixture = love.physics.newFixture(leg.body, leg.shape, 10)
        leg.fixture:setSensor(true)
        if j then
            local joint = love.physics.newRevoluteJoint(cow.torso.body, leg.body, x, y, false)
            joint:setLowerLimit(-math.pi / 32)
            joint:setUpperLimit(math.pi / 32)
            joint:setLimitsEnabled(true)
        end
        return leg
    end

    local legW = bodyWidth / 10
    local legH = bodyHeight

    local l1 = makeLeg(x - bodyWidth / 3, y + bodyHeight / 2, legW, legH, true)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x - bodyWidth / 5, y + bodyHeight / 2, legW, legH, false)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x + bodyWidth / 5, y + bodyHeight / 2, legW, legH, false)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x + bodyWidth / 3, y + bodyHeight / 2, legW, legH, true)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
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


function bikeGroundFeelerIsTouchingGround(bike)
    if bike.groundFeeler then
        local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeeler.fixture)
        local y = getYAtX(centroid[1], stepSize)
        --print(y, centroid[2])
        return centroid[2] > y
    end
    return true
end

local timeSpent = 0

function love.update(dt)
    animParticles.updateAnimParticles(dt)
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


    if (backWheelFromGround >= 0) then
        backWheelFromGround = backWheelFromGround + dt
    end
    if (frontWheelFromGround >= 0) then
        frontWheelFromGround = frontWheelFromGround + dt
    end

    if mipoOnVehicle then
        if love.keyboard.isDown('q') then
            local mass = getVehicleMass(bike) + getBodyMass(mipos[1])
            -- print(mass)
            mass = 30
            --bike.frame.body:applyLinearImpulse(0, -(mass * 1000))
            bike.frame.body:setAngularVelocity(-mass * .2)
        end

        if love.keyboard.isDown('e') then
            local mass = getVehicleMass(bike) + getBodyMass(mipos[1])
            --bike.frame.body:applyLinearImpulse(0, (mass * 1000))
            mass = 30
            bike.frame.body:setAngularVelocity(mass * .2)
        end

        -- try to apply angular velocity in opposite direction

        -- local bikeFrameAngle = bike.frame.body:getAngle()

        -- local mipoBody = mipos[1].b2d.torso
        --mipoBody:applyAngularImpulse(bikeFrameAngle*-1000)
        --bike.frame.body:applyAngularImpulse(bikeFrameAngle*-1000)
        -- print(bikeFrameAngle, mipoBody:getAngle())
        local b2d = mipos[1].b2d
        if bike.pedalWheel and true then
            if false then
                local lfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'lfoot')
                local centroid = getCentroidOfFixture(bike.pedalWheel.body, lfootPedalFixture)
                b2d.lfoot:setPosition(centroid[1], centroid[2])

                local rfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.pedalWheel.body, 'rfoot')
                local centroid = getCentroidOfFixture(bike.pedalWheel.body, rfootPedalFixture)
                b2d.rfoot:setPosition(centroid[1], centroid[2])
            end


            local seatFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'seat')
            local centroid = getCentroidOfFixture(bike.frame.body, seatFixture)
            --b2d.torso:setPosition(centroid[1], centroid[2])
            local buttFixture = getConnectorFixtureAtBodyOfType(b2d.torso, 'butt')
            if buttFixture then
                local buttCentroid = getCentroidOfFixture(b2d.torso, buttFixture)
                local bodyX, bodyY = b2d.torso:getPosition()
                local dx, dy = buttCentroid[1] - bodyX, buttCentroid[2] - bodyY
                b2d.torso:setPosition(centroid[1] - dx, centroid[2] - dy)
            end
            -- print(buttCentroid[1], buttCentroid[2], bodyX, bodyY) end

            --print('doing it')
        end
        --  b2d.lfoot:setAngle(math.pi + math.pi / 2)
        --  b2d.rfoot:setAngle(math.pi + math.pi / 2)
        if bike.pedalWheel and bike.pedalWheel.body then
            --bike.pedalWheel.body:setAngle(a / 13)
            --bike.pedalWheel.body:setAngularVelocity(v * 10)
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

    -- NOTE change the 5 below into something like 500 to have much slower scrolling
    -- this is usefull when you are dragging a vehicle, how to figure out if i am dragging a vehicle is the question
    local isDragging = isDraggingAFrame()
    local value = isDragging and 500 or 5

    local damping = numbers.mapInto(math.abs(avgVelX), 0, 10000, 0.0001, value)
    --print('damping', damping)
    thingToFollow:setLinearDamping(damping)

    local curCamX, curCamY = cam:getTranslation()
    local newDistance = numbers.getDistance(curCamX, curCamY, targetX, targetY)


    -- print(isDragging)

    --print(value)
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

sunColor1 = { hex2rgb('e6c800', 0.6) }
sunColor1b = { hex2rgb('e6c800', 0.8) }
sunColor2 = { hex2rgb('ddc490', 0.8) }

darkGrassColor = { hex2rgb('2a5b3e') }
darkGrassColorTrans = { hex2rgb('2a5b3e', 0.5) }
lightGrassColor = { hex2rgb('86a542') }
anotherGrassColor = { hex2rgb('45783c') }




function drawRepeatedPatternUsingStencilFunction(stencilFunc, img, color, repeatScale)
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    love.graphics.stencil(stencilFunc, "replace", 1)
    love.graphics.setStencilTest("greater", 0)


    local pw, ph = img:getDimensions()
    local screenW = cambrx - camtlx
    local screenH = cambry - camtly
    -- first render....
    local repeats = (screenW / pw) * repeatScale
    local tileOffsetX = (camtlx / screenW) * repeats
    local tileOffsetY = (camtly / screenH) * repeats
    local mesh = love.graphics.newMesh({
        { camtlx, camtly, 0 + tileOffsetX,       0 + tileOffsetY,      1, 1, 1 },
        { cambrx, camtly, repeats + tileOffsetX, 0 + tileOffsetY,      1, 1, 1 },
        { cambrx, cambry, repeats + tileOffsetX, repeats + tileOffsetY },
        { camtlx, cambry, 0 + tileOffsetX,       repeats + tileOffsetY }
    })
    mesh:setTexture(img)

    love.graphics.setColor(color)
    love.graphics.draw(mesh, 0, 0)
    love.graphics.setStencilTest()
end

function drawHillGround()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    --grassPattern

    for i = 1, #ground.points - 2, 2 do
        -- the 'road' part

        love.graphics.setColor(lightGrassColor)
        -- love.graphics.setColor({ .5, .5, .5, .5 })
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] - 100,
            ground.points[i + 2], ground.points[i + 3] - 100,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 0], ground.points[i + 1] + 200)

        -- the side part
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] + 200,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 2], cambry,
            ground.points[i + 0], cambry)
    end


    local doTextureStuff = true
    if (doTextureStuff) then
        local sideHillFunc = function()
            for i = 1, #ground.points - 2, 2 do
                love.graphics.setColor(1, 1, 1)


                love.graphics.polygon("fill",
                    ground.points[i + 0], ground.points[i + 1] + 200,
                    ground.points[i + 2], ground.points[i + 3] + 200,
                    ground.points[i + 2], cambry,
                    ground.points[i + 0], cambry)
            end
        end
        local topHillFunc = function()
            for i = 1, #ground.points - 2, 2 do
                love.graphics.setColor(1, 1, 1)

                love.graphics.polygon("fill",
                    ground.points[i + 0], ground.points[i + 1] - 100,
                    ground.points[i + 2], ground.points[i + 3] - 100,
                    ground.points[i + 2], ground.points[i + 3] + 200,
                    ground.points[i + 0], ground.points[i + 1] + 200)
            end
        end

        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 0.5 / 2)
        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 0.7 / 2)
        drawRepeatedPatternUsingStencilFunction(topHillFunc, grassPattern2, darkGrassColor, 10 / 2)
    end
end

local function texturedCurve(curve, image, mesh, dir, scaleW)
    if not dir then dir = 1 end
    if not scaleW then scaleW = 1 end
    local dl = curve:getDerivative()

    for i = 1, 1 do
        local w, h = image:getDimensions()
        local count = mesh:getVertexCount()

        for j = 1, count, 2 do
            local index                  = (j - 1) / (count - 2)
            local xl, yl                 = curve:evaluate(index)
            local dx, dy                 = dl:evaluate(index)
            local a                      = math.atan2(dy, dx) + math.pi / 2
            local a2                     = math.atan2(dy, dx) - math.pi / 2
            local line                   = (w * dir) * scaleW --- here we can make the texture wider!!, also flip it
            local x2                     = xl + line * math.cos(a)
            local y2                     = yl + line * math.sin(a)
            local x3                     = xl + line * math.cos(a2)
            local y3                     = yl + line * math.sin(a2)

            local x, y, u, v, r, g, b, a = mesh:getVertex(j)
            mesh:setVertex(j, { x2, y2, u, v })
            x, y, u, v, r, g, b, a = mesh:getVertex(j + 1)
            mesh:setVertex(j + 1, { x3, y3, u, v })
        end
    end
end

-- end lifted

function drawSinglePaardenBloem(x, y, randomNumber)
    local stengelScaleY = 1.2 - randomNumber * 3
    local h = stengelImage:getHeight() * stengelScaleY
    local x1 = math.sin(timeSpent * .4) * (h / 7)
    local x2 = 0
    local c = love.math.newBezierCurve({ 0, 0, x1, 0 - h / 2, x2, 0 - h + math.abs(x1) })
    local m = texturedBox2d.createTexturedTriangleStrip(stengelImage)
    local eindX, eindY = c:evaluate(1)
    texturedCurve(c, stengelImage, m, 1, .5)
    love.graphics.setColor(darkGrassColor)

    love.graphics.draw(m, x, y, 0, 1, stengelScaleY, 0, 0)


    love.graphics.setColor(1, 1, 0)
    love.graphics.draw(bloemHoofdImage, x + eindX, y + eindY * stengelScaleY, math.sin(timeSpent),
        1, 1,
        bloemHoofdImage:getWidth() / 2, bloemHoofdImage:getHeight() / 2)



    love.graphics.setColor(darkGrassColor)
    love.graphics.draw(bloemBladImage, x, y, -math.pi / 2 + 0.5, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
    love.graphics.draw(bloemBladImage, x, y, math.pi / 2, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
end

function drawPaardenBloemen()
    local startX = ground.points[1]
    local startY = ground.points[2]
    local eindX = ground.points[#ground.points - 1]
    local eindY = ground.points[#ground.points]
    for i = 1, #ground.points, 2 do
        local x = ground.points[i]
        local y = ground.points[i + 1]

        local hh = love.math.noise((x) / 1000, .1, .1)

        if (x % 8 == 0) then
            --print(i, hh)
            if (hh < .4) then
                love.graphics.setColor(1, 0, 0)
                --  love.graphics.circle('fill', x, y - 1000, 100)
                --  love.graphics.print('none', x, y)
            elseif (hh > .4 and hh < .5) then
                love.graphics.setColor(1, 1, 0)
                --   love.graphics.circle('fill', x, y - 1000, 100)
                --  love.graphics.print('none', x, y)
            else
                drawSinglePaardenBloem(x, y, hh - 0.5)
            end
        end
    end
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
                local indx2 = math.ceil(love.math.noise((x + j) / .1, yOffset * 0.01, hMultiplier) * count)

                local ori = origins[indx2]
                local angle = math.sin(hh) / 10
                angle = angle + math.sin(timeSpent) / 10

                batch:addLayer(1, quads[indx2], x + j + xOffset, yy + yOffset, angle, 2, 2 * hh / 200, ori[1], ori[2])
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



local function drawCelestialBodies()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)

    local w, h           = love.graphics.getDimensions()
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local img            = sunImage
    local dimsW, dimsH   = img:getDimensions()
    local sunRadius      = math.max(w, h) / 7
    local sx, sy         = createFittingScale(img, sunRadius, sunRadius)
    local x, y           = sunRadius / 2, sunRadius / 2

    local sunX           = numbers.mapInto(camtlx, 800000, -100000, 0, w)
    local sunY           = numbers.mapInto(camtly, 800000, -100000, 0, h)

    --love.graphics.setBlendMode('add')

    --love.graphics.setColor(1, 1, 1, 0.06)
    --love.graphics.draw(img, sunX, sunY - (h - sunRadius), 0, sx * 1.1, sy * 1.1, dimsH / 2, dimsW / 2)

    --love.graphics.setBlendMode('alpha')




    local sunScale = ((math.sin(timeSpent) + 1) / 2) / 100

    local sunAngle = (((math.sin(timeSpent) + 1) / 2) / 100) * (math.pi * 2)
    love.graphics.setColor(sunColor1b)
    love.graphics.draw(img, sunX, sunY - (h - sunRadius), sunAngle, sx + sunScale, sy + sunScale, dimsH / 2, dimsW / 2)

    love.graphics.setColor(sunColor1)
    love.graphics.draw(img, sunX, sunY - (h - sunRadius), 0, sx * 0.8, sy * 0.8, dimsH / 2, dimsW / 2)
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


    drawCelestialBodies()

    cam:push()

    drawHillGround()

    local batch1 = love.graphics.newSpriteBatch(atlasImg, 2000, 'stream')
    local batch2 = love.graphics.newSpriteBatch(atlasImg, 2000, 'stream')


    -- print('b2', batch2:getCount())


    --
    drawPaardenBloemen()
    drawGrassLeaves(100, -90, 0, 1.5, batch2)
    love.graphics.setColor(darkGrassColor)
    if batch2:getCount() <= 500 then
        love.graphics.draw(batch2)
    end
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
    textureTheBike(bike, bikeData)

    --
    drawGrassLeaves(.3, 250, 25, 2.05, batch1)
    love.graphics.setColor(lightGrassColor)
    if batch1:getCount() <= 500 then
        love.graphics.draw(batch1)
    end
    --print('b1', batch1:getCount())





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

            --   love.graphics.draw(grassImage, x, y, angle, sx, sx)
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

    animParticles.drawAnimParticles()
    love.graphics.setColor(0, 0, 0, 0.5)

    local stats = love.graphics.getStats()
    local memavg = numbers.calculateRollingAverage(rollingMemoryUsage)
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = tostring(love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'

    --print(backWheelFromGround, frontWheelFromGround)
    if false then
        local wheelie = ''
        if (frontWheelFromGround > 1 and backWheelFromGround <= 1) then
            wheelie = ' wheelie: ' .. string.format("%02.1f", frontWheelFromGround)
        end


        --bikeFrameAngleAtJump
        local loopings = ''
        if (bikeFrameAngleAtJump ~= 0) then
            loopings = ' loops: ' .. getLoopingDegrees() .. '°'
        end
    end
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

function disableLegs()
    local b2d = mipos[1].b2d
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.luleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.llleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.ruleg, { sleeping = true })
    box2dGuyCreation.updateUserDatasMoreDataAtBodyPart(b2d.rlleg, { sleeping = true })
    --box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.luleg, math.pi / 2, math.pi, 'revolute')
    --box2dGuyCreation.setJointLimitsBetweenBodies(b2d.torso, b2d.ruleg, math.pi / 2, math.pi, 'revolute')

    box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.ruleg, false, 'revolute')
    box2dGuyCreation.setJointLimitBetweenBodies(b2d.torso, b2d.luleg, false, 'revolute')

    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.luleg, b2d.llleg, 0, math.pi / 2, 'revolute')
    box2dGuyCreation.setJointLimitsBetweenBodies(b2d.ruleg, b2d.rlleg, 0, math.pi / 2, 'revolute')
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then
        cycleStep()
        if bikeGroundFeelerIsTouchingGround(bike) then
            --  print('jo!')
        end

        --local body = bike.frame.body
        --body:applyLinearImpulse(1000,0)
    end
    -- if k == '.' then
    --     followCamera = not followCamera
    -- end
    --
    --
    --
    if k == 'w' then
        if bikeGroundFeelerIsTouchingGround(bike) then
            local mass = getVehicleMass(bike) + getBodyMass(mipos[1])

            mass = 130
            local body = bike.frame.body
            body:applyLinearImpulse(0, -(mass * 1000))
            body:applyAngularImpulse(-10000)
        end
    end
    if k == 'd' then
        disableLegs()
    end
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
            print(inspect(ud))
            local force =
                (ud and ud.bodyType == 'torso' and 1000000) or
                (ud and ud.bodyType == 'frame' and 1000000) or
                50000
            print(force)
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


function getLoopingDegrees()
    return math.floor(((bikeFrameAngleAtJump - bike.frame.body:getAngle()) / (math.pi * 2)) * 360)
end

function addScoreMessage(msg)
    print(msg)
end

local function roundToQuarters(value)
    local result = math.floor(value * 4 + 0.5) / 4
    print(value, result)
    return result
end
function beginContact(a, b, contact)
    -- local fixtureA, fixtureB = contact:getFixtures()
    if a:getUserData() and b:getUserData() then
        --   print(a:getUserData().bodyType, b:getUserData().bodyType)
        if (a:getUserData().bodyType == 'ground' and b:getUserData().bodyType == 'backWheel') then
            backWheelFromGround = -1
            if (bikeFrameAngleAtJump ~= 0) then
                local l = getLoopingDegrees()
                local loops = ((l / 360))
                if math.abs(loops) > 0.3 then
                    addScoreMessage('looped: ' .. string.format("%02.1f", roundToQuarters(loops)))

                    if math.abs(loops) >= 0.9 then
                        local w, h = love.graphics.getDimensions()
                        local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
                        local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12
                        local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
                        local posData = { { x = x1, y = y1 }, { x = x1, y = y2 }, 1.5 }
                        local colorData = { { 1, 1, 1 }, { 1, 1, 0.7 }, 1.5 }
                        local alphaData = { 1, 0.2, 2.5 }
                        local scaleData = { 0.3, 1.3, 2 }
                        local rotationData = { 0, 0, 1 }

                        local frameData = {
                            startFrame = 0, -- frame where we will start playing
                            loopBack = 6,   -- frame where we will start looping again (after reaching end)
                            endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
                        }
                        animParticles.startAnimParticle('looping', 12, frameData, posData, colorData, alphaData,
                            scaleData, rotationData)
                    end
                end
            end

            bikeFrameAngleAtJump = 0
        end
        if (a:getUserData().bodyType == 'ground' and b:getUserData().bodyType == 'frontWheel') then
            if frontWheelFromGround > 1 then
                --contact:getPosition()
                if (frontWheelFromGround > 1.4) then
                    local w, h = love.graphics.getDimensions()
                    local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
                    local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12
                    local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
                    local posData = { { x = x1, y = y1 }, { x = x1, y = y2 }, 1.5 }

                    local colorData = { { 1, 1, 1 }, { 1, 1, 0.7 }, 1.5 }
                    local alphaData = { 1, 0.2, 2.5 }
                    local scaleData = { 0.3, 1.3, 2 }
                    local rotationData = { 0, 0, 1 }
                    local frameData = {
                        startFrame = 0, -- frame where we will start playing
                        loopBack = 6,   -- frame where we will start looping again (after reaching end)
                        endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
                    }
                    animParticles.startAnimParticle('wheelie', 12, frameData, posData, colorData, alphaData, scaleData,
                        rotationData)
                end


                addScoreMessage('wheelied: ' ..
                    string.format("%02.1f", roundToQuarters(frontWheelFromGround)) .. 'seconds')
            end

            frontWheelFromGround = -1
            if (bikeFrameAngleAtJump ~= 0) then
                local l = getLoopingDegrees()
                local loops = ((l / 360))
                if math.abs(loops) > 0.3 then
                    if math.abs(loops) >= 0.9 then
                        local w, h = love.graphics.getDimensions()
                        local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
                        local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12
                        local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
                        local posData = { { x = x1, y = y1 }, { x = x1, y = y2 }, 1.5 }
                        local colorData = { { 1, 1, 1 }, { 1, 1, 0.7 }, 1.5 }
                        local alphaData = { 1, 0.2, 2.5 }
                        local scaleData = { 0.3, 1.3, 2 }
                        local rotationData = { 0, 0, 1 }
                        local frameData = {
                            startFrame = 0, -- frame where we will start playing
                            loopBack = 6,   -- frame where we will start looping again (after reaching end)
                            endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
                        }
                        animParticles.startAnimParticle('looping', 12, frameData, posData, colorData, alphaData,
                            scaleData, rotationData)
                    end
                    addScoreMessage('looped: ' .. string.format("%02.1f", roundToQuarters(loops)))
                end
            end

            -- figure out if my wheelie has just endedn
            --


            bikeFrameAngleAtJump = 0
            --print('beginning contatc front')
        end
    end
end

function endContact(a, b, contact)
    local au = a:getUserData()
    local bu = b:getUserData()
    if au and bu then
        if (au.bodyType == 'ground' and bu.bodyType == 'backWheel') then
            backWheelFromGround = 0
            -- print('ending contatc back')
        end
        if (au.bodyType == 'ground' and bu.bodyType == 'frontWheel') then
            frontWheelFromGround = 0
            -- print('ending contatc front')
        end

        --   print((backWheelFromGround >= 0.0 and frontWheelFromGround >= 0.0), au.bodyType == 'ground',
        --       (bu.bodyType == 'backWheel' or bu.bodyType == 'frontWheel'))
        if (backWheelFromGround >= 0 and frontWheelFromGround >= 0) and au.bodyType == 'ground'
            and (bu.bodyType == 'backWheel' or bu.bodyType == 'frontWheel') then
            --print('start a jump', backWheelFromGround, frontWheelFromGround)
            bikeFrameAngleAtJump = bike.frame.body:getAngle()
        end
    end
end

local function startNumberParticle(num, x1, y1, x2, y2)
    local posData = { { x = x1, y = y1 }, { x = x2, y = y2 }, 2 }
    local colorData = { { 1, 1, 1 }, { 1, 1, 0.7 }, 2 }
    local alphaData = { 1, 0.2, 2 }
    local scaleData = { 0.8, 1.2, 2 }
    local rotationData = { 0, 0, 2 }
    local frameData = {
        startFrame = num * 2,   -- frame where we will start playing
        loopBack = num * 2,     -- frame where we will start looping again (after reaching end)
        endFrame = num * 2 + 2, -- frame where we end playing (-1 for defaul behaviour == end)
    }
    animParticles.startAnimParticle('numbers', 10, frameData, posData, colorData, alphaData, scaleData, rotationData)
end
function love.load()
    local ffont = "WindsorBT-Roman.otf"
    font = love.graphics.newFont(ffont, 24)
    love.graphics.setFont(font)
    jointsEnabled = true
    followCamera = 'bike'
    startExample()
    backWheelFromGround = 0
    frontWheelFromGround = 0
    bikeFrameAngleAtJump = 0
    world:setCallbacks(beginContact, endContact)
    pointsOfInterest = {}

    animParticles.prepareAnimParticle('wheelie', love.graphics.newImage('assets/anims/wheelie.png'), 110, 110)
    animParticles.prepareAnimParticle('looping', love.graphics.newImage('assets/anims/looping.png'), 110, 110)
    animParticles.prepareAnimParticle('numbers', love.graphics.newImage('assets/anims/numbers.png'), 110, 110)

    startNumberParticle(9, 0, 0, 100, 100)
    startNumberParticle(11, 70, 0, 170, 100)

    stengelImage = love.graphics.newImage('assets/world/stengel1.png')
    bloemHoofdImage = love.graphics.newImage('assets/world/bloemHoofd1.png')
    grassImage = love.graphics.newImage('assets/world/grass1.png')
    bloemBladImage = love.graphics.newImage('assets/world/bloemBlad2.png')
    mipoOnVehicle = false

    sunImage = love.graphics.newImage('assets/world/zon2.png')

    wheelImages = { love.graphics.newImage('assets/vehicleparts/wheel1.png')
    , love.graphics.newImage('assets/vehicleparts/wheel2.png')
    , love.graphics.newImage('assets/vehicleparts/wheel3.png')
    , love.graphics.newImage('assets/vehicleparts/wheel4.png') }

    frontWheelImgIndex = math.ceil(#wheelImages * love.math.random())
    backWheelImgIndex = math.ceil(#wheelImages * love.math.random())

    grassPattern1 = love.graphics.newImage('assets/world/grasspattern4.png')
    grassPattern1:setWrap('repeat', 'repeat')

    grassPattern2 = love.graphics.newImage('assets/world/grasspattern2.png')
    grassPattern2:setWrap('repeat', 'repeat')


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
