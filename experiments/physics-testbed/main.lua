if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

if jit then
    jit.off()
end


function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()




package.path = package.path .. ";../../?.lua"
SM = require 'vendor.SceneMgr'

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
--local skygradient      = gradient.makeSkyGradient(10)
--local skygradient      = gradient.makeSkyGradient(23)

local ui               = require "lib.ui"
local connect          = require 'lib.connectors'
local updatePart       = require 'lib.updatePart'
local Timer            = require 'vendor.timer'
local text             = require "lib.text"
local vehicle          = require 'vehicle-creator'
local animParticles    = require 'frameAnimParticle'

local dj               = require 'organicMusic'



function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
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
    local angleRadians = angleRad
    local deltaX = distance * math.cos(angleRadians)
    local deltaY = distance * math.sin(angleRadians)
    local endPoint = {
        x = startPoint.x + deltaX,
        y = startPoint.y + deltaY
    }

    return endPoint.x, endPoint.y
end

function locatePeakX(startX, endX, stepSize)
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

function startExample(number)
    phys.setupWorld(500)
    stepSize = 300
    ground = initGround()
    mipos = addMipos.make(1)
    schansjes = {}
    --print(inspect(mipos[1].dna.multipliers))
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

-- vehicle stuff

function cycleStep()
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

-- more general physics stuff

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.shape = love.physics.newCircleShape(radius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, .1)
    ball.fixture:setRestitution(.2) -- let the ball bounce

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
        return tx, ty
        --print('somethign wrong with POI')
        --return 0, 0
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

function bikeGroundFeelerUpIsTouchingGround(bike)
    if bike.groundFeelerUp then
        local centroid = getCentroidOfFixture(bike.frame.body, bike.groundFeelerUp.fixture)
        local y = getYAtX(centroid[1], stepSize)
        --print(y, centroid[2])
        return centroid[2] > y
    end
    return true
end

function playRandomMiPoSound()
    if miposoundplaying == false or not miposoundplaying:isPlaying() then
        local index = math.ceil(math.random() * #miposounds)
        local sound = miposounds[index]:clone()
        sound:play()
        miposoundplaying = sound
    end
end

function love.update(dt)
    SM.update(dt)
    dj.update()
    animParticles.updateAnimParticles(dt)
end

--flowerColors = pastelColors
local function drawRepeatedPatternUsingStencilFunction(stencilFunc, img, color, alpha, repeatScale)
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

    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.draw(mesh, 0, 0)
    love.graphics.setStencilTest()
end

local function drawLineImage(img, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    local scale = distance / img:getWidth()
    love.graphics.draw(img, x1, y1, angle, scale, 1, 0, img:getHeight() / 2)
end

local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end

local function subdivide2D(x1, y1, x2, y2, stepsize)
    local result = {}

    -- Calculate the distance between the two points
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Calculate the angle of the line segment
    local angle = math.atan2(dy, dx)

    -- Calculate the number of steps needed
    local numSteps = distance / stepsize

    -- Calculate the step increments for x and y
    local stepX = dx / numSteps
    local stepY = dy / numSteps

    -- Iterate through the line segment and add the subdivided points to the result
    for i = 0, numSteps do
        local x = x1 + stepX * i
        local y = y1 + stepY * i
        table.insert(result, { x, y })
    end

    return result
end




function rndOffset(offset)
    return (love.math.random() * offset) - offset / 2
end

function love.draw()
    SM.draw()
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

function toggleDayTime()
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

    if k == 's' then
        --  toggledState = not toggledState
        --  dj.toggleInstrumentAtIndex(toggledState, 1)
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

    return result
end




local function startNumberParticle(num, x1, y1, x2, y2, color1, color2)
    local posData = { { x = x1, y = y1 }, { x = x2, y = y2 }, 2 }
    local color = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)

    local colorData = { { color, color, color }, { color, color, color - 0.3 }, 2 }
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

local function getDigits(number)
    local digits = {}

    while number > 0 do
        local digit = number % 10
        table.insert(digits, 1, digit) -- Insert digit at the beginning of the array
        number = math.floor(number / 10)
    end

    return digits
end

local function drawNumbersNicely(num, x, y, x2, y2)
    local rounded = roundToQuarters(math.abs(num))
    local integer = math.floor(rounded)
    local fraction = rounded % 1

    --  print(num, rounded, print(inspect(getDigits(math.abs(integer)))))
    local digits = getDigits(math.abs(integer))
    if (integer ~= 0) then
        for i = 1, #digits do
            startNumberParticle(digits[i], x + 0 + (50 * i), y, x2 + 50 + (50 * i), y2)
        end
    end
    if (fraction ~= 0) then
        startNumberParticle(9 + (fraction * 4), x + (50 * (#digits + 1)), y, x2 + (50 * (#digits + 2)), y2)
    end
end

function displayWheelieData()
    if (frontWheelFromGround > .4) then
        brrVolume = 0.1
        Timer.after(3, function() brrVolume = 0 end)
    end
    if frontWheelFromGround > 1 then
        --contact:getPosition()

        if (frontWheelFromGround > 1.4) then
            local w, h = love.graphics.getDimensions()
            local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
            local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
            local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 3)
            local posData = { { x = x1 - 50, y = y1 }, { x = x1 - 50, y = y2 }, 2 }
            local textColor = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)
            local colorData = { { textColor, textColor, textColor }, { textColor, textColor, textColor - 0.3 }, 1.5 }


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

            drawNumbersNicely(frontWheelFromGround, x1, y1, x1, y2)

            --   addScoreMessage('wheelied: ' ..
            --      string.format("%02.1f", roundToQuarters(frontWheelFromGround)) .. 'seconds')
        end
    end
end

function displayLoopingData()
    if (bikeFrameAngleAtJump ~= 0) then
        local l = getLoopingDegrees()
        local loops = ((l / 360))

        if math.abs(loops) >= 0.5 then
            local w, h = love.graphics.getDimensions()
            local x1 = w / 2 + (love.math.random() * (w / 6)) - w / 12
            local y1 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 6)
            local y2 = h / 2 + (love.math.random() * (h / 6)) - h / 12 - (h / 3)
            local posData = { { x = x1 - 50, y = y1 }, { x = x1 - 50, y = y2 }, 2 }

            local textColor = numbers.mapInto(dayTimeTransition.t, 1, 0, 1, .1)
            local colorData = { { textColor, textColor, textColor }, { textColor, textColor, textColor - 0.3 }, 2 }
            local alphaData = { 1, 0.2, 2 }
            local scaleData = { 0.8, 1.3, 2 }
            local rotationData = { 0, 0, 2 }
            local frameData = {
                startFrame = 0, -- frame where we will start playing
                loopBack = 6,   -- frame where we will start looping again (after reaching end)
                endFrame = -1,  -- frame where we end playing (-1 for defaul behaviour == end)
            }
            brrVolume = 0.1
            if love.math.random() < 0.5 then
                dj.queueClip(4, 2)
            else
                dj.queueClip(4, 8)
            end

            Timer.after(3, function() brrVolume = 0 end)
            animParticles.startAnimParticle('looping', 12, frameData, posData, colorData, alphaData,
                scaleData, rotationData)
            love.graphics.setColor(textColor, textColor, textColor)
            drawNumbersNicely(loops, x1, y1, x1, y2)
            --  addScoreMessage('looped: ' .. string.format("%02.1f", roundToQuarters(loops)))
        end
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
    end
    if (b:getUserData() and b:getUserData().bodyType == 'turbo') then
        removeTurboButtonFromContainer(b)
        guiro:clone():play()
        b:destroy()
        turboCharged = turboCharged + 1000
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

function addTurboButton(x, y)
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

function addWineGums()
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
        print(#winegums)
    end
end

function love.load()
    dj.loadJizzJazzSong('assets/jizzjazz/mountmipo2.jizzjazz2.txt')
    dj.setAllInstrumentsVolume(0)
    local url = 'assets/sounds/mountainmipo/bikesound.wav'
    source = love.audio.newSource(url, 'static')
    source:setLooping(true)
    source:setPitch(0.05)
    source:play()


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




    -- s
    local ffont = "WindsorBT-Roman.otf"
    font = love.graphics.newFont(ffont, 24)
    love.graphics.setFont(font)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)

    SM.setPath("scenes/")
    SM.load("downhill")
end
