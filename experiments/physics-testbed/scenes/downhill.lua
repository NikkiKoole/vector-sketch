local scene             = {}
local animParticles     = require 'frameAnimParticle'
local gradient          = require 'lib.gradient'
local ui                = require "lib.ui"
local texturedBox2d     = require 'lib.texturedBox2d'
local text              = require "lib.text"
local camera            = require 'lib.camera'
local cam               = require('lib.cameraBase').getInstance()
local dj                = require 'organicMusic'
local phys              = require 'lib.mainPhysics'
local Timer             = require 'vendor.timer'
local numbers           = require 'lib.numbers'
local box2dGuyCreation  = require 'lib.box2dGuyCreation'
local connect           = require 'lib.connectors'
local updatePart        = require 'lib.updatePart'

local dayTimeTransition = { t = 0 }
local timeSpent         = 0
local brrVolume         = 0


local brownColor = { hex2rgb('5b3e05', 1) }
local sunColor1 = { hex2rgb('ddc800', 1) }
local sunColor1b = { hex2rgb('ffc800', .8) }
local sunColor1c = { hex2rgb('ffc800', .05) }
local sunColor2 = { hex2rgb('ddc490', 0.2) }

local darkGrassColor = { hex2rgb('2a5b3e') }
local darkGrassColorTrans = { hex2rgb('2a5b3e', 0.5) }
local lightGrassColor = { hex2rgb('86a542') }
local anotherGrassColor = { hex2rgb('45783c') }

local pastelColors = {
    { hex2rgb('FFB3BA') },
    { hex2rgb('FFDFBA') },
    { hex2rgb('FFFFBA') },
    { hex2rgb('BAFFC9') },
    { hex2rgb('BAE1FF') },
    { hex2rgb('FFCCE5') },
    { hex2rgb('D4A5A5') },
    { hex2rgb('F0D9FF') },
    { hex2rgb('C4FCEF') },
    { hex2rgb('FFEBB7') },
}

local flowerColors = {
    { hex2rgb('FEDF00') },
    { hex2rgb('FFD700') },
    { hex2rgb('F9A602') },
    { hex2rgb('FFC40C') },
    --  { hex2rgb('FFDB58') },
    ---  { hex2rgb('F4C430') },
    --  { hex2rgb('E9A900') },
    --  { hex2rgb('FFD800') },
    --  { hex2rgb('FFC300') },
    --  { hex2rgb('E3A857') },
}

function scene.load()
    dayTime = 10
    skyGradient = gradient.makeSkyGradient(dayTime)

    jointsEnabled = true
    followCamera = 'mipo'

    startExample()

    backWheelFromGround = 0
    frontWheelFromGround = 0
    bikeFrameAngleAtJump = 0
    mipoOnVehicle = false

    turboCharged = 0

    sunMoonPositions = { x = 0, y = 0, radius = 0 }
    dipper = {

        { 70,   573 },
        { 377,  370 },
        { 625,  392 },
        { 904,  420 },
        { 1399, 183 },
        { 1444, 462 },
        { 1034, 624 }
    }

    for i = 1, #dipper do
        dipper[i][1] = dipper[i][1] / 1522
        dipper[i][2] = dipper[i][2] / 1522
    end

    dipperRest = {

    }
    for i = 1, 25 do
        dipperRest[i] = {}
        dipperRest[i][1] = love.math.random()
        dipperRest[i][2] = (love.math.random() * 0.75)
    end

    turbobuttons = {}
    winegums     = {
        ruits = {
            love.graphics.newImage('assets/img/candyparts/ruit1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/ruit1-line.png'),
            love.graphics.newImage('assets/img/candyparts/ruit2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/ruit2-line.png'),

        },
        capsules = {
            love.graphics.newImage('assets/img/candyparts/capsule1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/capsule1-line.png'),
            love.graphics.newImage('assets/img/candyparts/capsule2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/capsule2-line.png'),

        },
        circs = {
            love.graphics.newImage('assets/img/candyparts/circle1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/circle1-line.png'),
            love.graphics.newImage('assets/img/candyparts/circle2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/circle2-line.png'),
        },
        octas = {
            love.graphics.newImage('assets/img/candyparts/octa1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/octa1-line.png'),
            love.graphics.newImage('assets/img/candyparts/octa2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/octa2-line.png'),

        },
        rekts = {
            love.graphics.newImage('assets/img/candyparts/rect1-shape.png'),
            love.graphics.newImage('assets/img/candyparts/rect1-line.png'),
            love.graphics.newImage('assets/img/candyparts/rect2-shape.png'),
            love.graphics.newImage('assets/img/candyparts/rect2-line.png'),

        }
    }

    stars        = {
        love.graphics.newImage('assets/world/star1.png'),
    }



    world:setCallbacks(beginContact, endContact)
    pointsOfInterest = {}

    animParticles.prepareAnimParticle('wheelie', love.graphics.newImage('assets/anims/wheelie.png'), 110, 110)
    animParticles.prepareAnimParticle('looping', love.graphics.newImage('assets/anims/looping.png'), 110, 110)
    animParticles.prepareAnimParticle('numbers', love.graphics.newImage('assets/anims/numbers.png'), 110, 110)

    --startNumberParticle(9, 0, 0, 100, 100)
    --startNumberParticle(11, 70, 0, 170, 100)

    stengelImage = love.graphics.newImage('assets/world/stengel1.png')
    bloemHoofdImage = love.graphics.newImage('assets/world/bloemHoofd1.png')
    grassImage = love.graphics.newImage('assets/world/grass1.png')
    bloemBladImage = love.graphics.newImage('assets/world/bloemBlad2.png')

    moonImage = love.graphics.newImage('assets/world/maan.png')

    sunImage = love.graphics.newImage('assets/world/zon3.png')

    sunEye = love.graphics.newImage('assets/parts/pupil5.png')
    sunNose = love.graphics.newImage('assets/parts/nose13.png')
    sunTeeth = love.graphics.newImage('assets/parts/teeth1-mask.png')
    sunSpot = love.graphics.newImage('assets/parts/pupil6.png')
    sunSpot2 = love.graphics.newImage('assets/parts/pupil2.png')
    achtervork = love.graphics.newImage('assets/vehicleparts/achtervork.png')
    voorvork = love.graphics.newImage('assets/vehicleparts/voorvork.png')
    stok1 = love.graphics.newImage('assets/vehicleparts/stok1.png')
    stok1R = love.graphics.newImage('assets/vehicleparts/stok1R.png')
    stokdik = love.graphics.newImage('assets/vehicleparts/stokdik.png')
    wheelImages = { love.graphics.newImage('assets/vehicleparts/wheel6.png')
    , love.graphics.newImage('assets/vehicleparts/wheel6.png')
    , love.graphics.newImage('assets/vehicleparts/wheel6.png')
    , love.graphics.newImage('assets/vehicleparts/wheel6.png') }

    tireImage = love.graphics.newImage('assets/vehicleparts/wheel6back.png')
    tireOverImage = love.graphics.newImage('assets/vehicleparts/wheel4.png')

    frontWheelImgIndex = math.ceil(#wheelImages * love.math.random())
    backWheelImgIndex = math.ceil(#wheelImages * love.math.random())

    grassPattern1 = love.graphics.newImage('assets/world/grasspattern4.png')
    grassPattern1:setWrap('repeat', 'repeat')

    grassPattern2 = love.graphics.newImage('assets/world/grasspattern2.png')
    grassPattern2:setWrap('repeat', 'repeat')

    --source = love.audio.newSource(url, 'static')
    miposounds = { love.audio.newSource('assets/sounds/mi.wav', 'static'), love.audio.newSource('assets/sounds/po.wav',
        'static'), love.audio.newSource('assets/sounds/mo.wav', 'static'), love.audio.newSource('assets/sounds/pi.wav',
        'static') }
    miposoundplaying = false

    guiro = love.audio.newSource('samples/cr78/Guiro 1.wav', 'static')

    if false then
        for i = 1, 1 do
            local x = -200000 + love.math.random() * 400000
            local y = lerpYAtX(x, stepSize)
            table.insert(pointsOfInterest,
                { x = x, y = y - 500 + love.math.random() * 1000, radius = 400 })
        end
    end
end

function scene.unload()
end

local function getBodyMass(mipo)
    local total = 0
    for k, v in pairs(mipo.b2d) do
        if (v) then
            total = total + v:getMass()
        end
    end

    return total
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


local function isUserDataWithBodyTypeOf(fixture, type)
    local ud = fixture:getUserData()
    if ud then
        return ud.bodyType == type
    end
    return false
end

local function setSensorValueBody(body, value)
    -- not allowed to change sensortype of connectors.

    local fixtures = body:getFixtures()
    for _, fixture in ipairs(fixtures) do
        if (isUserDataWithBodyTypeOf(fixture, 'connector')) then
            -- doing nothing
        else
            fixture:setSensor(value)
        end
        -- local skip = false
        -- local ud = fixture:getUserData()
        -- if ud then
        --     if ud.bodyType == "connector" then
        --         skip = true
        --     end
        -- end

        -- if not skip then
        --     fixture:setSensor(value)
        -- end
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
            end)
        end
    end

    local lfootFixture = getConnectorFixtureAtBodyOfType(b2d.lfoot, 'foot')
    local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rfoot, 'foot')




    local bodyMass = getBodyMass(mipos[1])
    --  print(bodyMass)
    b2d.torso:applyLinearImpulse(0, -3000 * bodyMass)

    updatePart.resetPositions(mipos[1])
    b2d.torso:applyLinearImpulse(0, -3000 * bodyMass)
end

function connectMipoAndVehicle()
    -- print('connect')
    updatePart.resetPositions(mipos[1])

    local tx, ty = mipos[1].b2d.rfoot:getPosition()
    local yy = getYAtX(tx, stepSize)
    local b2d = mipos[1].b2d

    -- i want to better position a bike.
    -- given a posiiton of torso,
    -- and lookup a width of bike frame, or well i know position of front and backwheel.
    --
    local isPedalBike = bike.pedalWheel

    if true then
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
        v:setGravityScale(0.3)
        v:setActive(false)
    end
    --  updatePart.resetPositions(mipos[1])
    Timer.after(10, function()
        for k, v in pairs(b2d) do
            --print(k,v)
            v:setGravityScale(0.3)
            v:setActive(true)
        end
    end)


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
    end

    if isPedalBike then
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
            setSensorValueBody(b2d.lear, true)

            setSensorValueBody(b2d.rear, true)


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

            connect.forceConnection(lfootPedalFixture, lfootFixture)

            local rfootPedalFixture = getConnectorFixtureAtBodyOfType(bike.frame.body, 'rhand')
            local rfootFixture = getConnectorFixtureAtBodyOfType(b2d.rhand, 'hand')
            connect.forceConnection(rfootPedalFixture, rfootFixture)
        end)
    end

    if (b2d.torso) then b2d.torso:setAngle(0) end
    if (b2d.head) then b2d.head:setAngle(0) end
    if (b2d.neck1) then b2d.neck1:setAngle(-math.pi) end
    if (b2d.neck) then b2d.neck:setAngle(-math.pi) end

    b2d.lear:setAngle(math.pi / 2)
    b2d.rear:setAngle(-math.pi / 2)
end

local function getRidOfBigRotationsInBody(body)
    --local angle = body:getAngle()
    --if angle > 0 then
    --    body:setAngle(angle % (2 * math.pi))
    --else
    --    body:setAngle(angle % ( -2 * math.pi))
    --end
    local a = body:getAngle()
    if true then
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

local function textureTheSchansjes()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    love.graphics.setColor(brownColor)

    for i = 1, #schansjes do
        local points = schansjes[i]
        --  print(inspect(points))
        local lx = points[1]
        local ly = points[2]
        local rx = points[#points - 1]
        local ry = points[#points]
        -- print(l, r)
        if (lx > camtlx and lx < cambrx) or (rx > camtlx and rx < cambrx) then
            --print('should render schansje #', i)
            --print(inspect(points))
            local startPoints = subdivide2D(points[1], points[2], points[3], points[4], 80)


            for j = 1, #startPoints do
                drawLineImage(stokdik, startPoints[j][1], startPoints[j][2] - 100, startPoints[j][1],
                    startPoints[j][2] + 200)
            end
            local startPoints = subdivide2D(points[3], points[4], points[5], points[6], 80)


            for j = 1, #startPoints do
                drawLineImage(stokdik, startPoints[j][1], startPoints[j][2] - 100, startPoints[j][1],
                    startPoints[j][2] + 200)
            end
        end
    end
end

local function textureTheBike(bike, bikeData)
    local img          = tireImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)


    local img          = tireOverImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.setColor(.2, .1, .1, 0.5)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)




    love.graphics.setColor(0, 0, 0)
    local img          = wheelImages[frontWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)

    ----


    local img          = tireImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)


    local img          = tireOverImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.setColor(.2, .1, .1, 0.5)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)

    love.graphics.setColor(0, 0, 0)
    local img          = wheelImages[backWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.draw(img, x, y, a + math.pi, sx, sy, dimsH / 2, dimsW / 2)


    local x1, y1 = bike.backWheel.body:getPosition()




    local shapePoints = { bike.frame.shape:getPoints() }
    --   print(inspect(shapePoints))
    local middlex     = numbers.lerp(shapePoints[1], shapePoints[9], 0.5)
    local topy        = shapePoints[2] - (bikeData.radius * 0.2)
    local bottomy     = shapePoints[4]
    local x2, y2      = bike.frame.body:getWorldPoint(middlex, topy)
    drawLineImage(stok1R, x1, y1, x2, y2)
    local x3, y3 = bike.frame.body:getWorldPoint(middlex, bottomy)
    drawLineImage(stok1R, x1, y1, x3, y3)



    local xvw, yvw           = bike.backWheel.body:getPosition()
    local gx, gy             = bike.frame.body:getLocalPoint(xvw, yvw)
    --bikeData.radius
    -- local x4, y4   = bike.frame.body:getWorldPoint(shapePoints[1],
    --  shapePoints[2])
    local steerSteepOffset   = (bikeData.radius * 0.2)
    local endFrameAboveWheel = gy - (bikeData.radius * 1.2)
    local x4, y4             = bike.frame.body:getWorldPoint(shapePoints[1] - steerSteepOffset, endFrameAboveWheel)
    drawLineImage(stok1R, x2, y2, x4, y4)
    drawLineImage(stok1R, x3, y3, x4, y4)

    -- achter wile vork
    local img          = achtervork
    local dimsW, dimsH = img:getDimensions()


    local shapeTL = { shapePoints[1], shapePoints[2] }
    local shapeBL = { shapePoints[3], shapePoints[4] }
    local shapeBR = { shapePoints[5], shapePoints[6] }
    local sx, sy  = createFittingScale(img, shapeTL[1] - shapeBR[1], shapeBL[2] - shapeTL[2])
    local x, y    = bike.backWheel.body:getPosition() --bike.frame.body:getWorldPoint(shapeTL[1], shapeTL[2])
    local a       = bike.frame.body:getAngle()

    --   love.graphics.draw(img, x, y, a, sx, sy, 40, 200)

    if false then
        local img          = voorvork
        local dimsW, dimsH = img:getDimensions()
        local shapePoints  = { bike.frame.shape:getPoints() }
        print(inspect(shapePoints))
        local shapeTR = { shapePoints[9], shapePoints[10] }
        local shapeBR = { shapePoints[7], shapePoints[8] }
        local shapeBL = { shapePoints[5], shapePoints[6] }
        local sx, sy  = createFittingScale(img, shapeTR[1] - shapeBL[1], (shapeBR[2] - shapeTR[2]) * 1.5)
        local x, y    = bike.frontWheel.body:getPosition() --bike.frame.body:getWorldPoint(shapeTL[1], shapeTL[2])
        local a       = bike.frame.body:getAngle()
        love.graphics.draw(img, x, y, a, sx * -1, sy, img:getWidth(), img:getHeight() / 2)
    end
end
-- skygradient
local function lerp(a, b, t)
    return a + (b - a) * t
end


local function lerpColor(color1, color2, t)
    local r = numbers.mapInto(t, 0, 1, color1[1], color2[1])
    local g = numbers.mapInto(t, 0, 1, color1[2], color2[2])
    local b = numbers.mapInto(t, 0, 1, color1[3], color2[3])
    return { r, g, b }
end

local function drawSinglePaardenBloem(x, y, randomNumber, randomNumber2)
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




    --if dayTime == 10 then
    local colorIndex = math.floor(numbers.mapInto(randomNumber2, .2, .8, 1, #flowerColors))
    local daycolors = flowerColors[colorIndex]
    --love.graphics.setColor(colors)
    --else
    local colorIndex = math.floor(numbers.mapInto(randomNumber2, .2, .8, 1, #pastelColors))
    local nightcolors = pastelColors[colorIndex]
    --l--ove.graphics.setColor(colors)
    --end
    local mixedColor = lerpColor(daycolors, nightcolors, dayTimeTransition.t)
    love.graphics.setColor(mixedColor)
    love.graphics.draw(bloemHoofdImage, x + eindX, y + eindY * stengelScaleY, math.sin(timeSpent),
        1, 1,
        bloemHoofdImage:getWidth() / 2, bloemHoofdImage:getHeight() / 2)

    love.graphics.setColor(darkGrassColor)
    love.graphics.draw(bloemBladImage, x, y, -math.pi / 2 + 0.5, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
    love.graphics.draw(bloemBladImage, x, y, math.pi / 2, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
end

local function drawPaardenBloemen()
    local startX = ground.points[1]
    local startY = ground.points[2]
    local eindX = ground.points[#ground.points - 1]
    local eindY = ground.points[#ground.points]


    for i = 1, #ground.points, 2 do
        local x = ground.points[i]
        local y = ground.points[i + 1]

        local hh = love.math.noise((x) / 1000, .1, .1)
        local hh2 = love.math.noise((x) / 100, .6, .1)

        if (x % 8 == 0) then
            if (hh < .4) then
                love.graphics.setColor(1, 0, 0)
            elseif (hh > .4 and hh < .5) then
                love.graphics.setColor(1, 1, 0)
            else
                drawSinglePaardenBloem(x, y, hh - 0.5, hh2)
            end
        end
    end
end

local function drawGrassLeaves(secondParam, yOffset, xOffset, hMultiplier, batch)
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


local function drawSunRays(x, y, radius)
    love.graphics.setColor(sunColor1b)
    love.graphics.setBlendMode('alpha')
    local sy = radius / 70
    --print(sy)
    for i = 1, 20 do
        local index = 1 --math.ceil(love.math.random() * #quads)
        love.graphics.draw(atlasImg, quads[index], x, y, (timeSpent / 2) + i * (math.pi * 2) / 20, sy, sy,
            origins[index][1],
            origins[index][2])
    end
end


local function drawSunFace(x, y, radius)
    love.graphics.setColor(1, 1, 1)


    love.graphics.setBlendMode("add")

    local spotSize = radius * 2.7
    local sx, sy   = createFittingScale(sunSpot, spotSize, spotSize)
    love.graphics.setColor(1, 1, 1, 0.025)

    local offset = radius / 5
    love.graphics.draw(sunSpot, x, y + offset, timeSpent, sx, sy, sunSpot:getWidth() / 2, sunSpot:getHeight() / 2)
    love.graphics.setBlendMode("subtract")
    love.graphics.draw(sunSpot, x, y + offset, timeSpent * 3.3, sx, sy, sunSpot:getWidth() / 2, sunSpot:getHeight() / 2)
    love.graphics.setBlendMode("add")
    love.graphics.draw(sunSpot, x, y + offset, timeSpent / 1.3, sx, sy, sunSpot:getWidth() / 2, sunSpot:getHeight() / 2)
    love.graphics.draw(sunSpot, x, y + offset, love.math.random(), sx, sy, sunSpot:getWidth() / 2, sunSpot:getHeight() /
        2)
    local sx, sy = createFittingScale(sunSpot2, spotSize, spotSize)
    local offset = radius / 5
    love.graphics.draw(sunSpot2, x, y + offset, timeSpent, sx, sy, sunSpot2:getWidth() / 2, sunSpot2:getHeight() / 2)

    love.graphics.setBlendMode("subtract")

    love.graphics.setColor(1, 1, 1, 0.03)
    local eyeSize = radius / 2
    local sx, sy  = createFittingScale(sunEye, eyeSize, eyeSize)



    love.graphics.draw(sunEye, rndOffset(5) + x - radius / 2 - eyeSize / 2, rndOffset(5) + y - radius / 2, 0, sx, sy)
    love.graphics.draw(sunEye, rndOffset(5) + x + radius / 2 - eyeSize / 2, rndOffset(5) + y - radius / 2, 0, sx, sy)


    local sx, sy = createFittingScale(sunNose, eyeSize, eyeSize)
    love.graphics.draw(sunNose, rndOffset(5) + x - eyeSize / 2, y + rndOffset(5), 0, sx, sy)

    local sx, sy = createFittingScale(sunTeeth, radius, radius / 3)
    love.graphics.draw(sunTeeth, rndOffset(5) + x - radius / 2, rndOffset(5) + y + radius / 2, 0, sx, sy)

    love.graphics.setBlendMode("alpha")
end


local function drawSun(sunX, sunY)
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)

    local w, h           = love.graphics.getDimensions()
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local img            = sunImage
    local dimsW, dimsH   = img:getDimensions()
    local sunRadius      = math.max(w, h) / 11
    local sx, sy         = createFittingScale(img, sunRadius, sunRadius)
    local x, y           = sunRadius / 2, sunRadius / 2



    local sunScale = 3 * ((math.sin(timeSpent) + 1) / 2) / 100
    local sunAngle = (((math.sin(timeSpent) + 1) / 2) / 10) * (math.pi * 2)


    drawSunRays(sunX, sunY, sunRadius * .8)

    love.graphics.setColor(sunColor1b)


    love.graphics.draw(img, sunX, sunY, timeSpent / 5, 2 * sx + sunScale, 2 * sy + sunScale, dimsH / 2,
        dimsW / 2)
    love.graphics.setColor(sunColor1c)
    love.graphics.setBlendMode("alpha")
    love.graphics.draw(img, sunX, sunY, -timeSpent / 5, 2 * sx + sunScale, 2 * sy + sunScale, dimsH / 2,
        dimsW / 2)

    drawSunFace(sunX, sunY - sunRadius / 8, sunRadius * .8)
    sunMoonPositions.x = sunX
    sunMoonPositions.y = sunY
    sunMoonPositions.radius = sunRadius * .8
end

local function drawMoon(x, y)
    local w, h         = love.graphics.getDimensions()
    local img          = moonImage
    local moonRadius   = math.max(w, h) / 11
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, moonRadius, moonRadius)

    love.graphics.setColor(181 / 255, 226 / 255, 196 / 255, 0.25)
    love.graphics.draw(img, x, y, 0, sx, sx, dimsH / 2, dimsW / 2)
    love.graphics.draw(img, x, y, 0, sx, sx, dimsH / 2, dimsW / 2)


    local radius  = moonRadius
    local eyeSize = radius / 7
    local sx, sy  = createFittingScale(sunEye, eyeSize, eyeSize)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.draw(sunEye, rndOffset(2) + x - radius / 1.2 - eyeSize / 2, rndOffset(2) + y + radius / 2, 0, sx, sy)
    love.graphics.draw(sunEye, rndOffset(2) + x - radius / 1 - eyeSize / 2, rndOffset(2) + y + radius / 2, 0, sx, sy)

    local sx, sy = createFittingScale(sunNose, eyeSize, eyeSize)
    love.graphics.draw(sunNose, rndOffset(2) + x - radius / 1.1 - eyeSize / 2, rndOffset(2) + y + radius / 1.5, 0, sx, sy)


    local sx, sy = createFittingScale(sunTeeth, radius / 4, radius / 5)
    love.graphics.draw(sunTeeth, rndOffset(2) + x - radius / 1.1 - eyeSize / 2, rndOffset(2) + y + radius / 1, 0, sx,
        sy)

    love.graphics.setBlendMode("alpha")

    sunMoonPositions.x = x
    sunMoonPositions.y = y
    sunMoonPositions.radius = moonRadius
end


local function drawCelestialBodies()
    local w, h = love.graphics.getDimensions()
    local sunX = w / 12 * 10 --numbers.mapInto(camtlx, 800000, -100000, 0, w)
    local sunY = h / 12      --numbers.mapInto(camtly, 800000, -100000, 0, h)
    --  print(dayTimeTransition.t)

    centerX = w / 2
    centerY = h / 2

    if dayTimeTransition.t >= 0 and dayTimeTransition.t < .5 then
        local angle = dayTimeTransition.t * math.pi
        local rotatedX = math.cos(angle) * (sunX - centerX) - math.sin(angle) * (sunY - centerY) + centerX
        local rotatedY = math.sin(angle) * (sunX - centerX) + math.cos(angle) * (sunY - centerY) + centerY
        drawSun(rotatedX, rotatedY)
    else
        local angle = math.pi + dayTimeTransition.t * -math.pi
        local rotatedX = math.cos(angle) * (sunX - centerX) - math.sin(angle) * (sunY - centerY) + centerX
        local rotatedY = math.sin(angle) * (sunX - centerX) + math.cos(angle) * (sunY - centerY) + centerY
        drawMoon(rotatedX, rotatedY)
    end
end


local function drawHillGround()
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

        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 1, 0.5 / 2)
        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 1, 0.7 / 2)
        drawRepeatedPatternUsingStencilFunction(topHillFunc, grassPattern2, darkGrassColor, 1, 1 / 2)
    end
end

function scene.draw()
    ui.handleMouseClickStart()
    love.graphics.clear(1, 0, 1)
    love.graphics.setColor(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 1)



    local skyGradient2 = gradient.lerpSkyGradient(10, 22, dayTimeTransition.t)
    love.graphics.draw(skyGradient2, 0, 0, 0, love.graphics.getDimensions())


    local w, h = love.graphics.getDimensions()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    local sky = false --skyGradient(camtly, cambry)

    if sky then
        love.graphics.draw(sky, 0, 0, 0, w, h)
    end



    local alphaMultiplier = numbers.mapInto(dayTimeTransition.t, 0, 1, 0.1, 1)
    love.graphics.setColor(1, 1, 1, .9 * alphaMultiplier)
    for i = 1, #dipper do
        local it = dipper[i]

        local x = w / 6 + it[1] * w / 2
        local y = it[2] * w / 2
        local fonkel = 0.9 + (love.math.noise(i, love.timer.getTime() / 10)) / 5
        local dimsw, dimsh = stars[1]:getDimensions()
        love.graphics.draw(stars[1], x, y, i % 12, 0.5 * fonkel, 0.5 * fonkel, dimsw / 2, dimsh / 2)
        --  love.graphics.rectangle('fill',x,y, 10, 10)
    end
    love.graphics.setColor(1, 1, 1, .6 * alphaMultiplier)
    for i = 1, #dipperRest do
        local it = dipperRest[i]
        local x = it[1] * w
        local y = it[2] * h
        local fonkel = 0.9 + (love.math.noise(i, love.timer.getTime() / 10)) / 5
        local dimsw, dimsh = stars[1]:getDimensions()

        love.graphics.draw(stars[1], x, y, i % 12, 0.23 * fonkel, 0.23 * fonkel, dimsw / 2, dimsh / 2)
        --love.graphics.rectangle('fill', x, y, 5, 5)
    end

    drawCelestialBodies()



    cam:push()

    drawHillGround()

    local batch1 = love.graphics.newSpriteBatch(atlasImg, 2000, 'stream')
    local batch2 = love.graphics.newSpriteBatch(atlasImg, 2000, 'stream')


    -- print('b2', batch2:getCount())


    --
    texturedBox2d.drawWineGums(winegums)

    drawPaardenBloemen()


    drawGrassLeaves(100, -90, 0, 1.5, batch2)

    love.graphics.setColor(darkGrassColor)
    if batch2:getCount() <= 500 then
        love.graphics.draw(batch2)
    end
    textureTheSchansjes()
    -- phys.drawWorld(world)

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
    if mipoOnVehicle then
        for i = 1, #mipos do
            local bx = mipos[i].b2d.torso:getX()
            if (bx > camtlx - 1000 and bx < cambrx + 1000) then
                texturedBox2d.renderLeftLegAndHair(mipos[i].b2d, mipos[i])
                texturedBox2d.renderLeftArmAndHair(mipos[i].b2d, mipos[i])

                --texturedBox2d.drawNumbersOver(mipos[i].b2d)
            end
        end
    end
    --
    drawGrassLeaves(.3, 250, 25, 2.05, batch1)
    love.graphics.setColor(lightGrassColor)
    if batch1:getCount() <= 500 then
        love.graphics.draw(batch1)
    end
    --print('b1', batch1:getCount())



    texturedBox2d.drawTurboButtons(turbobuttons)

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
        end
    end


    if false then
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
    end

    cam:pop()

    --if dayTimeTransition.t ~= 1 and dayTimeTransition.t ~= 0 then
    --    print(dayTimeTransition.t)
    --end



    -- dayTime
    if (dayTimeTransition.t >= 1) then
        love.graphics.setColor(0.1, 0.1, .35, 0.25)
        love.graphics.rectangle('fill', 0, 0, w, h)
    elseif (dayTimeTransition.t <= 0) then
        love.graphics.setColor(1, 1, 0, 0.05)
        love.graphics.rectangle('fill', 0, 0, w, h)
    else
        local r = numbers.mapInto(dayTimeTransition.t, 0, 1, 1, .1)
        local g = numbers.mapInto(dayTimeTransition.t, 0, 1, 1, .1)
        local b = numbers.mapInto(dayTimeTransition.t, 0, 1, 0, .35)
        local a = numbers.mapInto(dayTimeTransition.t, 0, 1, .05, .25)
        love.graphics.setColor(r, g, b, a)
        love.graphics.rectangle('fill', 0, 0, w, h)
    end
    animParticles.drawAnimParticles()
    love.graphics.setColor(0, 0, 0, 0.5)

    local stats = love.graphics.getStats()
    local memavg = numbers.calculateRollingAverage(rollingMemoryUsage)
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = tostring(love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    local numSources = love.audio.getActiveSourceCount()
    --print(backWheelFromGround, frontWheelFromGround)
    -- if true then
    local wheelie = ''
    if (frontWheelFromGround > 1 and backWheelFromGround <= 1) then
        wheelie = ' wheelie: ' .. string.format("%02.1f", frontWheelFromGround)
    end


    --bikeFrameAngleAtJump
    local loopings = ''
    if (bikeFrameAngleAtJump ~= 0) then
        loopings = ' loops: ' .. getLoopingDegrees() .. '°'
    end
    -- end
    love.graphics.print(mem .. '  ' .. vmem .. '  ' .. draws .. ' ' .. fps .. ' ' .. numSources .. ' ' .. wheelie)


    if frontWheelFromGround > 1 or getLoopingDegrees() > 360 then
        if #turbobuttons == 0 and math.random() < 0.001 then addTurboButton() end
    end
    if getLoopingDegrees() > 360 and #turbobuttons == 0 and math.random() < 0.01 then
        -- print(getLoopingDegrees())
        addTurboButton()
    end
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

    if false then
        if circleLabelButton(x, y, size / 2, 'CAM\n' .. followCamera) then
            if followCamera == 'free' then
                followCamera = 'bike'
            elseif followCamera == 'bike' then
                followCamera = 'mipo'
            elseif followCamera == 'mipo' then
                followCamera = 'free'
            end
        end
    end
    local x = size / 2 + size
    if circleLabelButton(x, y, size / 2, mipoOnVehicle and 'UNLINK' or 'LINK') then
        if not mipoOnVehicle then
            connectMipoAndVehicle()
            followCamera = 'bike'
        else
            disconnectMipoAndVehicle()
            followCamera = 'mipo'
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

local function bikeGroundFeelerUpIsBelowSchansje(bike)
    if bike.groundFeelerUp then
        local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeelerUp.fixture)
        local y = getYAtX(centroid[1], stepSize)

        for i = 1, #schansjes do
            local points = schansjes[i]
            local lx = points[1]
            local ly = points[2]
            local rx = points[#points - 1]
            local ry = points[#points]

            --print(y, centroid[2])
            -- return centroid[2] > y
            if centroid[1] > lx and centroid[1] < rx then
                if centroid[2] > math.min(ly, ry) then return true end
            end

            --return true
            --
            --  print(inspect(points))
        end
    end
    return false
end

function scene.update(dt)
    if bikeGroundFeelerUpIsTouchingGround(bike) or bikeGroundFeelerUpIsBelowSchansje(bike) then
        -- print('jo hello!, bike is upside down ')
        local mass = getVehicleMass(bike) + getBodyMass(mipos[1])

        mass = mass * 3
        local body = bike.frame.body
        body:applyLinearImpulse(0, -(mass * 1000))
        body:applyAngularImpulse(10000)
        playRandomMiPoSound()
    end


    if turboCharged > 0 then
        turboCharged = turboCharged - 1
        -- print(turboCharged)
    end


    local thingToFollow = followCamera == 'mipo' and mipos[1].b2d.torso or bike.backWheel.body
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
    enableDisableWinegums()
    enableDisableTurboButtons()



    local t = math.sin(math.abs(love.timer:getTime()))




    --enableDisableObjects(mipos)
    -- enableDisableObjects({bike})  -- wrap the single bike in a table to make it consistent
    -- enableDisableObjects(obstacles)


    local a = bike.backWheel.body:getAngle()
    local v = bike.backWheel.body:getAngularVelocity()



    if (frontWheelFromGround >= 0 and backWheelFromGround <= 0) then
        frontWheelFromGround = frontWheelFromGround + dt
    end

    if (backWheelFromGround >= 0) then
        backWheelFromGround = backWheelFromGround + dt
    end

    if mipoOnVehicle then
        --source:setVolume(brrVolume)
        dj.setAllInstrumentsVolume(1)
        local p = numbers.mapInto(math.abs(velX), 0, 10000, 50, 250)

        if backWheelFromGround > 0.15 and frontWheelFromGround > 0.15 and not bikeGroundFeelerIsTouchingGround(bike) then
            p = numbers.mapInto(velX, 0, 10000, 150, 350)
            dj.fadeInVolume(2, 0)
            -- dj.fadeOutAndFadeInVolume(1, 2)
            -- dj.setAllInstrumentsVolume(.5)
        else
            dj.fadeOutVolume(2)
            --dj.fadeOutAndFadeInVolume(2, 1)
            --dj.setAllInstrumentsVolume(.5)
        end

        if not bikeGroundFeelerIsTouchingGround(bike) then
            p = math.max(100, p)
        end

        dj.setTempo(p)

        if frontWheelFromGround > 0.8 then
            local a = bike.frame.body:getAngle()
            --  print(a)
            a = numbers.clamp(a, -math.pi * 2, math.pi * 2)

            local p = numbers.mapInto(a, -math.pi, math.pi, -5, 5)

            dj.setFreaky(p)
            --  dj.setAllInstrumentsVolume(.3)
        else
            dj.setFreaky(false)
        end


        --print(velX, velY)
    else
        -- source:setVolume(0.1 * t)
        -- local p = numbers.m   apInto(velX, 0, 10000, 0.25, 1)
        -- if p < 0.0001 then p = 0.0001 end
        -- source:setPitch(p)

        local p = numbers.mapInto(math.abs(velX), 0, 35000, 50, 130)
        --  print(p, velX)
        dj.setTempo(p)
        dj.setAllInstrumentsVolume(0)
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


        getRidOfBigRotationsInBody(b2d.torso)
        if (b2d.head) then
            getRidOfBigRotationsInBody(b2d.head)
        end
        if (b2d.neck) then
            getRidOfBigRotationsInBody(b2d.neck)
            getRidOfBigRotationsInBody(b2d.neck1)
        end

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

    timeSpent = timeSpent + dt
end

return scene
