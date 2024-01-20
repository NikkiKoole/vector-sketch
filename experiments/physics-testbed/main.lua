package.path          = package.path .. ";../../?.lua"

local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'
local phys            = require 'lib.mainPhysics'
local numbers         = require 'lib.numbers'
local generatePolygon = require('lib.generate-polygon').generatePolygon

function initGround()
    local thing = {}
    thing.body = love.physics.newBody(world, 0, 0)
    updateGround(thing)
    return thing
end

function getYAtX(x, stepSize)
    -- we need to be able to get the world height at a specific X
    local index = math.floor(x / stepSize)

    -- smooth waves
    local cool = 10.78
    local amplitude = 150 * cool
    --local f2 = 30
    local frequency = 30
    local h = love.math.noise(index / frequency, 1, 1) * amplitude
    local y1 = h - (amplitude / 2)


    --uphills
    local cool = 10.78
    local amplitude = 170 * cool
    local frequency = 17
    local h = love.math.noise(index / frequency, 1, 1) * amplitude
    local y2 = h - (amplitude / 2)



    -- the roughness
    local cool = 10.78
    local amplitude = 20 * cool
    local frequency = 3
    local h = love.math.noise(index / frequency, 1, 1) * amplitude
    local y3 = h - (amplitude / 2)

    -- sometimes i want roughness, sometimes i odnt
    local r = ((math.sin(index / 30) + 1) / 2)
    y3 = y3 * r

    -- the downhill steepness
    local linear = numbers.mapInto(index, -20 * stepSize, 20 * stepSize, -500 * stepSize, 500 * stepSize)
    --local x = (math.floor(camtlx / stepSize) * stepSize) + (i - 1) * stepSize

    return y1 + y2 + y3 + linear
end

function updateGround(ground)
    local w, h = love.graphics.getDimensions()
    -- camera.setCameraViewport(cam, w, h)
    -- camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly

    -- get the correct steps to calulate values at
    -- think about the end parts..
    --print(camtlx, cambrx)
    local stepSize = 50
    local steps = math.ceil(boxWorldWidth / stepSize)
    --print(math.ceil(steps))

    local points = {}

    if ground.fixture then
        ground.fixture:destroy()
    end

    local extraSteps = 100
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
    --print(boxWorldWidth, boxWorldHeight)
end

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.shape = love.physics.newCircleShape(radius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, .1)
    ball.fixture:setRestitution(.7) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    ball.fixture:setFriction(1)
    return ball
end

function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

function makeRandomPoly(x, y, radius)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newPolygonShape(getRandomConvexPoly(radius, 8)) --love.physics.newRectangleShape(width, height / 4)
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

function startExample(number)
    phys.setupWorld()
    ground = initGround()
    ball = makeBall(0, -500, 100)

    obstacles = {}
    for i = 1, 100 do
        local o = makeRandomPoly(i * 30, -500, 100)
        table.insert(obstacles, o)
    end
    rollingAverageVelX = {}
    for i = 1, 10 do
        rollingAverageVelX[i] = 0
    end

    rollingAverageVelY = {}
    for i = 1, 10 do
        rollingAverageVelY[i] = 0
    end

    rollingDistance = {}
    for i = 1, 10 do
        rollingDistance[i] = 0
    end
end

function love.load()
    startExample()

    pointsOfInterest = {}
    local w, h = love.graphics.getDimensions()

    for i = 1, 1000 do
        table.insert(pointsOfInterest,
            { x = -200000 + love.math.random() * 400000, y = -20000 + love.math.random() * 40000, radius = 800 })
    end

    -- ground = initGround()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

local function calculateRollingAverage(valueList)
    local sum = 0
    for _, value in ipairs(valueList) do
        sum = sum + value
    end
    return sum / #valueList
end

function getTargetPos(thing)
    local avgVelX = calculateRollingAverage(rollingAverageVelX)
    local avgVelY = calculateRollingAverage(rollingAverageVelY)
    local worldX, worldY = thing.body:getWorldPoint(0, 0)

    local targetX = worldX + avgVelX
    local targetY = worldY + avgVelY

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

function love.update(dt)
    local velX, velY = ball.body:getLinearVelocity()
    table.insert(rollingAverageVelX, velX)
    table.remove(rollingAverageVelX, 1)

    table.insert(rollingAverageVelY, velY)
    table.remove(rollingAverageVelY, 1)

    updateGround(ground)

    world:update(dt)
    phys.handleUpdate(dt, cam)


    local targetX, targetY = getTargetPos(ball)

    --print(targetX, targetX2)
    -- https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer
    -- https://www.youtube.com/watch?v=aAKwZt3aXQM&t=315s



    local avgVelX = calculateRollingAverage(rollingAverageVelX)
    --local avgVelX = calculateRollingAverage(rollingAverageVelY)
    local damping = numbers.mapInto(math.abs(avgVelX), 0, 10000, 0.0001, 5)
    ball.body:setLinearDamping(damping)

    local curCamX, curCamY = cam:getTranslation()
    local newDistance = getDistance(curCamX, curCamY, targetX, targetY)

    local divider = numbers.mapInto(newDistance, 0, 1000, 1, 15)
    local delta = love.timer.getAverageDelta() or dt
    delta = 1 / 300
    local smoothX = lerp(curCamX, targetX, divider / (1 / delta))
    local smoothY = lerp(curCamY, targetY, divider / (1 / delta))
    --print((1 / delta), divider)
    --local distance = getDistance(curCamX, curCamY, targetX, targetY)
    -- print('distance', newDistance)
    --print(targetX, targetY)
    local viewWidth = numbers.mapInto(math.abs(avgVelX), 0, 2000, 2000, 2500)


    --print(distance)
    --if distance > 300 then
    --camera.centerCameraOnPosition(targetX, targetY, viewWidth, viewWidth)
    camera.centerCameraOnPosition(smoothX, smoothY, viewWidth, viewWidth)
end

--end

function love.draw()
    cam:push()
    phys.drawWorld(world)

    love.graphics.setColor(0.3, 0.3, 0.3)
    for i = 1, #pointsOfInterest do
        local poi = pointsOfInterest[i]
        love.graphics.circle('line', poi.x, poi.y, poi.radius)
    end
    love.graphics.setColor(1, 1, 1)
    local targetX, targetY = getTargetPos(ball)
    love.graphics.rectangle('line', targetX, targetY, 40, 40)

    local curCamX, curCamY = cam:getTranslation()
    love.graphics.circle('line', curCamX, curCamY, 20)
    cam:pop()


    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    local velX, velY = ball.body:getLinearVelocity()
    love.graphics.print('ball speed: ' .. math.floor(velX), 10, 30)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
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
        pointerForceFunc = function(fixture) return 400 end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
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
