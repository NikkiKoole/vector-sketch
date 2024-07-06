local scene            = {}
local animParticles    = require 'frameAnimParticle'
local gradient         = require 'lib.gradient'
local ui               = require "lib.ui"
local texturedBox2d    = require 'lib.texturedBox2d'
local text             = require "lib.text"
local camera           = require 'lib.camera'
local cam              = require('lib.cameraBase').getInstance()
local dj               = require 'organicMusic'
local phys             = require 'lib.mainPhysics'
local Timer            = require 'vendor.timer'
local numbers          = require 'lib.numbers'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local connect          = require 'lib.connectors'
local updatePart       = require 'lib.updatePart'
local addMipos         = require 'addMipos'
local vehicle          = require 'vehicle-creator'
local swipes           = require 'lib.screen-transitions'

dayTimeTransition      = { t = 0 }
local timeSpent        = 0


local darkGrassColor = { hex2rgb('2a5b3e') }
local lightGrassColor = { hex2rgb('86a542') }

require 'particle_effects'
require 'renderJoy'



local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end



local function getAngle(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local angle = math.atan2(dy, dx)
    return angle
end

local function calculateEndPoint(startPoint, angleRad, distance)
    local angleRadians = angleRad
    local deltaX = distance * math.cos(angleRadians)
    local deltaY = distance * math.sin(angleRadians)
    local endPoint = {
        x = startPoint.x + deltaX,
        y = startPoint.y + deltaY
    }

    return endPoint.x, endPoint.y
end

local function locatePeakX(startX, endX, stepSize)
    local bestPos = nil
    local bestValue = math.huge

    for i = 0, (endX - startX) / stepSize do
        local x = startX + i * stepSize
        local nx = startX + (i + 1) * stepSize
        local nnx = startX + (i + 2) * stepSize

        local y = getYAtX(x, stepSize)
        local ny = getYAtX(nx, stepSize)
        local nny = getYAtX(nnx, stepSize)

        if ny < nny and bestValue > ny then
            bestPos = nx
            bestValue = ny
        end
    end
    return bestPos - stepSize
end


-- GROUND STUFF

function initGround()
    local thing = {
        body = love.physics.newBody(world, 0, 0)
    }
    updateGround(thing)
    return thing
end

function getYAtX(x, stepSize, buildOptions)
    --local h2 = love.math.noise(x / 10000)
    -- local STEEPNESS = 150 -- * h2 --3000
    local c = x / stepSize
    local index = math.floor(c)

    local function generateWave(amplitude, frequency)
        local h = love.math.noise(index / frequency, 1, 1) * amplitude
        return h - (amplitude / 2)
    end

    local aLengthInSteps = 125 -- the steep part
    local bLengthInSteps = 0   --  the flat part
    local steepA = 150
    local steepB = 20

    local divved = index / (aLengthInSteps + bLengthInSteps)
    local wholePart = math.floor(divved)
    local fractionalPart = divved - wholePart
    local restIndex = fractionalPart * (aLengthInSteps + bLengthInSteps)

    local insideB = restIndex > aLengthInSteps
    local y1, y2, y3 = 0, 0, 0


    y1 = generateWave(200 * 10.78, 30)
    y2 = generateWave(70 * 10.78, 17)
    y3 = generateWave(20 * 10.78, 5)

    if insideB then
        y3 = y3 * ((math.sin(x / 30) + 1) / 2) -- Apply roughness condition
    end


    -- print(index, index % (aLengthInSteps + bLengthInSteps))

    local v = math.min(restIndex, aLengthInSteps)
    local v2 = math.max(restIndex - aLengthInSteps, 0)
    local v3 = wholePart * (aLengthInSteps * steepA + bLengthInSteps * steepB)

    local linear = v * steepA + v2 * steepB + v3
    -- numbers.mapInto(c, -20, 20, -STEEPNESS, STEEPNESS)
    --print(stepSize, aLengthInSteps, bLengthInSteps)
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

----


-- GROUND AND ITS ITEMS STUFF

function lerpYAtX(targetX, stepSize)
    local x1 = math.floor(targetX / stepSize) * stepSize
    local x2 = math.ceil(targetX / stepSize) * stepSize

    local y1 = getYAtX(x1, stepSize)
    local y2 = getYAtX(x2, stepSize)

    local y3 = numbers.mapInto(targetX, x1, x2, y1, y2)
    return y3
end

function enableDisableWinegums()
    -- for i = 1, #mipos do
    --     local b = mipos[i]
    --     local bx, by = b.b2d.torso:getPosition()
    -- end
    local mainGuy = mipos[1]
    local mainGuyX, mainGuyY = mainGuy.b2d.torso:getPosition()

    for i = #winegums, 1, -1 do
        local b = winegums[i].body
        local bx, by = b:getPosition()

        if math.abs(mainGuyX - bx) > 20000 or math.abs(mainGuyY - by) > 20000 then
            winegums[i].body:destroy()
            print('removed')
            table.remove(winegums, i)
        end
    end
end

function enableDisableTurboButtons()
    -- for i = 1, #mipos do
    --     local b = mipos[i]
    --     local bx, by = b.b2d.torso:getPosition()
    -- end
    local mainGuy = mipos[1]
    local mainGuyX, mainGuyY = mainGuy.b2d.torso:getPosition()

    for i = #turbobuttons, 1, -1 do
        local b = turbobuttons[i].body
        local bx, by = b:getPosition()

        if math.abs(mainGuyX - bx) > 20000 or math.abs(mainGuyY - by) > 20000 then
            turbobuttons[i].body:destroy()
            print('removed')
            table.remove(turbobuttons, i)
        end
    end
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
            for k, v in pairs(b.b2d) do
                v:setActive(false)
                v:setGravityScale(0)
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

    local extraSteps = 10
    local xMinR = camtlx - extraSteps * stepSize
    local xMaxR = cambrx + extraSteps * stepSize


    local b = bike --mipos[i]
    local bx, by = b.frontWheel.body:getPosition()

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
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly
    local extraSteps = 100
    local xMinR = camtlx - extraSteps * stepSize
    local xMaxR = cambrx + extraSteps * stepSize

    for i = 1, #obstacles do
        local b = obstacles[i]
        local bx, by = b:getPosition()
        local scale = b:getGravityScale()

        if bx < xMinR or bx > xMaxR then
            b:setActive(false)
            b:setGravityScale(0)
            local y = lerpYAtX(bx, stepSize)

            if by > y then
                b:setPosition(bx, y)
            end
        end

        if bx >= xMinR and bx <= xMaxR then
            b:setActive(true)
            b:setGravityScale(1)
        end
    end
end

local function cycleStep()
    -- bike.frontWheel.body:setAngularVelocity(120000)
    --  bike.backWheel.body:setAngularVelocity(120000)
    --bike.frame.body:applyLinearImpulse(10000, -1000)
    if bike.pedalWheel then
        local force = 1000000
        if turboCharged > 0 then
            force = 2000000
        end
        bike.backWheel.body:applyAngularImpulse(force)
        if frontWheelFromGround == 0 then
            bike.frontWheel.body:applyAngularImpulse(force)
        end
        bike.pedalWheel.body:applyAngularImpulse(force)
        if turboCharged > 0 then
            bike.frame.body:applyLinearImpulse(20000, -1000)
        end
    end
end

local function startExample(number)
    -- mipos = addMipos.make(1)
    ground = initGround()
    schansjes = {}
    --print(inspect(mipos[1].dna.multipliers))
    obstacles = {}



    if true then
        for i = 1, 100 do
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
            table.insert(schansjes, points)
            --local body = love.physics.newBody(world, x1, y1, 'static')
            --local shape = love.physics.newRectangleShape(1, 1)
            --local fixture = love.physics.newFixture(body, shape, .3)


            -- local body = love.physics.newBody(world, x3, y3, 'static')
            -- local shape = love.physics.newRectangleShape(1, 1)
            -- local fixture = love.physics.newFixture(body, shape, .3)
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

    bike, bikeData = vehicle.createVehicleUsingDNACreation('bike', c, -2000, -5000)

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


function removeTurboButtonFromContainer(ding)
    for i = #turbobuttons, 1, -1 do
        local it = turbobuttons[i]
        if (it.fixture == ding) then
            table.remove(turbobuttons, i)
        end
    end
end

local function addTurboButton(x, y)
    -- how do we do this? the buttons ought to be static and ou can colide with them


    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx

    local shape = phys.makeShape('ruit', 300, 300)
    local yy = getYAtX(camtlx + boxWorldWidth, stepSize)
    local body = love.physics.newBody(world, camtlx + boxWorldWidth, yy - 100, "kinematic")
    local fixture = love.physics.newFixture(body, shape, .2)
    fixture:setUserData(makeUserData('turbo', {}))

    if true then
        table.insert(turbobuttons, {
            body = body,
            fixture = fixture,
            color = palettes[12],
            index = math.ceil(love.math.random() * 7),
            --type = 'circle',
            --type = 'capsule',
            type = 'ruit',
            w = 300,
            h = 300
        })
    end
    print(#winegums)
end

local function addWineGums()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx

    local subPalettes = { 1, 8, 9, 9, 9, 10, 14, 15, 15, 15, 23, 32, 77, 87 }
    local amt = 3 + math.ceil(love.math.random() * 23)

    local types = {
        'capsule2', 'ruit', 'octagon', 'circle', 'rect3'
    }
    local dims = {
        { 350, 150 }, { 300, 200 }, { 200, 200 }, { 100, 100 }, { 200, 150 }
    }

    for i = 1, amt do
        local middleX = camtlx + boxWorldWidth / 2
        local x = 2000 + middleX - (amt / 2) * 5 + (i * 5)
        local y = cambry - 2000 + love.math.random() * 10
        local body = love.physics.newBody(world, x, y, "dynamic")

        --local shape = love.physics.newPolygonShape(getRandomConvexPoly(150, 8)) --love.physics.newRectangleShape(width, height / 4)
        --local shape = phys.makeShape('capsule', 350, 150)
        --local shape = phys.makeShape('ruit', 300, 200)
        --local shape = phys.makeShape('octagon', 200, 200)
        --local shape = phys.makeShape('circle', 100)
        --local shape = phys.makeShape('rect3', 100, 200)

        local typeIndex = math.ceil(math.random() * #types)
        local wrnd = dims[typeIndex][1]
        local hrnd = dims[typeIndex][2]
        local shape = phys.makeShape(types[typeIndex], wrnd, hrnd)
        local fixture = love.physics.newFixture(body, shape, .2)

        fixture:setUserData(makeUserData('winegum', {}))
        -- fixture.
        local paletteIndex = subPalettes[math.ceil(math.random() * #subPalettes)]
        table.insert(winegums, {
            body = body,
            color = palettes[paletteIndex],
            index = math.ceil(love.math.random() * 7),
            --type = 'circle',
            --type = 'capsule',
            type = types[typeIndex],
            w = wrnd,
            h = hrnd
        })
        -- print(#winegums)
    end
end

function scene.load()
    atlasImg = love.graphics.newArrayImage('assets/sprieten.png')
    --atlasArray = love.graphics.newArrayImage({ 'assets/sprieten.png' })
    local q1 = love.graphics.newQuad(0, 0, 49, 192, atlasImg)
    local q2 = love.graphics.newQuad(51, 164, 40, 197, atlasImg)
    local q3 = love.graphics.newQuad(51, 0, 41, 162, atlasImg)
    local q4 = love.graphics.newQuad(94, 0, 46, 186, atlasImg)
    local q5 = love.graphics.newQuad(0, 194, 47, 231, atlasImg)
    local q6 = love.graphics.newQuad(94, 188, 45, 236, atlasImg)
    local q7 = love.graphics.newQuad(142, 197, 47, 208, atlasImg)
    local q8 = love.graphics.newQuad(142, 0, 52, 195, atlasImg)
    quads = { q1, q2, q3, q4, q5, q6, q7, q8 }
    origins = { { 22, 185 }, { 12, 187 }, { 19, 144 }, { 25, 176 }, { 27, 224 }, { 16, 210 }, { 22, 190 }, { 30, 173 } }



    dayTime = 10
    skyGradient = gradient.makeSkyGradient(dayTime)

    jointsEnabled = true
    followCamera = 'mipo'
    print('scene load downlhill')
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


    dj.loadJizzJazzSong('assets/jizzjazz/mountmi.jizzjazz2.txt')
    dj.setAllInstrumentsVolume(0)

    --if true then
    url = 'assets/sounds/mountainmipo/bikesound.wav'
    wheeliesource = love.audio.newSource(url, 'static')
    wheeliesource:setLooping(true)
    wheeliesource:setPitch(1)
    wheeliesource:setVolume(0)
    wheeliesource:play()
    --end


    -- s
    local ffont = "WindsorBT-Roman.otf"
    font = love.graphics.newFont(ffont, 24)
    love.graphics.setFont(font)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)


    swipes.fadeInTransition(1) 
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

local function getLoopingDegrees()
    return math.floor(((bikeFrameAngleAtJump - bike.frame.body:getAngle()) / (math.pi * 2)) * 360)
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


local function disconnectMipoAndVehicle()
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

local function connectMipoAndVehicle()
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


function beginContact(a, b, contact)
    -- local fixtureA, fixtureB = contact:getFixtures()
    if a:getUserData() and b:getUserData() then
        --   print(a:getUserData().bodyType, b:getUserData().bodyType)
        if (a:getUserData().bodyType == 'ground' and b:getUserData().bodyType == 'backWheel') then
            backWheelFromGround = -1
            displayLoopingData()

            bikeFrameAngleAtJump = 0
        end
        if (a:getUserData().bodyType == 'ground' and b:getUserData().bodyType == 'frontWheel') then
            displayWheelieData()
            frontWheelFromGround = -1
            displayLoopingData()
            bikeFrameAngleAtJump = 0
            --print('beginning contatc front')
        end
    end

    if (a:getUserData() and a:getUserData().bodyType == 'turbo') then
        removeTurboButtonFromContainer(a)
        guiro:clone():play()
        a:destroy()
        turboCharged = turboCharged + 1000
        dj.toggleTurbo(true)
    end
    if (b:getUserData() and b:getUserData().bodyType == 'turbo') then
        removeTurboButtonFromContainer(b)
        guiro:clone():play()
        b:destroy()
        turboCharged = turboCharged + 1000
        dj.toggleTurbo(true)
    end
end

function endContact(a, b, contact)
    local au = a:getUserData()
    local bu = b:getUserData()
    if au and bu then
        if (au.bodyType == 'ground' and bu.bodyType == 'backWheel') then
            backWheelFromGround = 0
        end
        if (au.bodyType == 'ground' and bu.bodyType == 'frontWheel') then
            frontWheelFromGround = 0
        end

        if (backWheelFromGround >= 0 and frontWheelFromGround >= 0) and au.bodyType == 'ground'
            and (bu.bodyType == 'backWheel' or bu.bodyType == 'frontWheel') then
            bikeFrameAngleAtJump = bike.frame.body:getAngle()
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


-- skygradient
local function lerp(a, b, t)
    return a + (b - a) * t
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


    if swipes.getTransition() then
        swipes.renderTransition(swipes.getTransition())
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
        return tx, ty
        --print('somethign wrong with POI')
        --return 0, 0
    end
end

-- rest
--
--
--
--

local function bikeGroundFeelerIsTouchingGround(bike)
    if bike.groundFeeler then
        local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeeler.fixture)
        local y = getYAtX(centroid[1], stepSize)
        --print(y, centroid[2])
        return centroid[2] > y
    end
    return true
end

local function bikeGroundFeelerUpIsTouchingGround(bike)
    if bike.groundFeelerUp then
        local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeelerUp.fixture)
        local y = getYAtX(centroid[1], stepSize)
        --print(y, centroid[2])
        return centroid[2] > y
    end
    return true
end

-- end rest

local function toggleDayTime()
    if dayTime == 22 then
        dayTime = 10
        Timer.tween(1, dayTimeTransition, { t = 0 })
    else
        dayTime = 22
        Timer.tween(1, dayTimeTransition, { t = 1 })
    end
    skyGradient = gradient.makeSkyGradient(dayTime)

    dj.toggleInstrumentAtIndex(toggledState, 1)
    toggledState = not toggledState
end


local function isSunMoonPressed(x, y)
    local dx = sunMoonPositions.x - x
    local dy = sunMoonPositions.y - y
    local distance = math.sqrt(dx * dx + dy * dy)
    return (distance < sunMoonPositions.radius)
end



local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            --print(inspect(ud))
            local force =
                (ud and ud.bodyType == 'torso' and 1000000) or
                (ud and ud.bodyType == 'frame' and 1000000) or
                50000
            -- print(force)
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
    ui.addToPressedPointers(x, y, id)


    if isSunMoonPressed(x, y) then
        toggleDayTime()
    end
end

local function disableLegs()
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

local function playRandomMiPoSound()
    if miposoundplaying == false or not miposoundplaying:isPlaying() then
        local index = math.ceil(math.random() * #miposounds)
        local sound = miposounds[index]:clone()
        sound:play()
        miposoundplaying = sound
    end
end

function handleInputs()
    function love.keypressed(k)
        if k == 't' then
            addTurboButton()
            -- turboCharged = 1000
        end
        if k == 'd' then

        end
        if k == 'g' then
            addWineGums()
        end
        if k == 'f' then
            if bikeGroundFeelerUpIsTouchingGround(bike) then
                print('jo hello!, bike is upside down ')
            end
        end
        if k == 'c' then
            if love.math.random() < 0.5 then
                dj.queueClip(4, 2)
            else
                dj.queueClip(4, 8)
            end
        end





        if k == 'escape' then love.event.quit() end
        if k == 'space' and mipoOnVehicle then
            cycleStep()
        end
        if k == 'w' then
            if bikeGroundFeelerIsTouchingGround(bike) then
                local mass = getVehicleMass(bike) + getBodyMass(mipos[1])

                mass = mass * 3
                local body = bike.frame.body
                body:applyLinearImpulse(0, -(mass * 1000))
                body:applyAngularImpulse(-1000)


                brrVolume = 0.1
                Timer.after(3, function() brrVolume = 0 end)
            end
        end
        if k == 'p' then
            disableLegs()
        end
    end

    function love.mousepressed(x, y, button, istouch)
        -- print('mousepresed')
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
end

function scene.update(dt)
    if splashSound:isPlaying() then
        local volume = splashSound:getVolume()
        splashSound:setVolume(volume * .90)
        if volume < 0.01 then
            splashSound:stop()
        end
    end
    handleInputs()

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
        if turboCharged <= 0 then
            dj.toggleTurbo(false)
        end
        -- print(turboCharged)
    end


    local thingToFollow = followCamera == 'mipo' and mipos[1].b2d.torso or bike.backWheel.body
    local velX, velY = thingToFollow:getLinearVelocity()
    --print('isDestroyed', thingToFollow:isDestroyed())

    if frontWheelFromGround > .1 then
        local v = numbers.mapInto(frontWheelFromGround, 0, 20, 0, 1)
        if v < 0.01 then v = 0.01 end
        wheeliesource:setVolume(v)
        local p = numbers.mapInto(velX, -1000, 1000, 0.5, 1)
        if p < 0.01 then p = 0.01 end
        wheeliesource:setPitch(p)
    else
        wheeliesource:setVolume(0)
    end

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
    --print('isDestroyed2', thingToFollow:isDestroyed())
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
