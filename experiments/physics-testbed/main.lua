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

function initGround()
    local thing = {
        body = love.physics.newBody(world, 0, 0)
    }
    updateGround(thing)
    return thing
end

function getYAtX(x, stepSize)
    local index = math.floor(x / stepSize)
    local function generateWave(amplitude, frequency)
        local h = love.math.noise(index / frequency, 1, 1) * amplitude
        return h - (amplitude / 2)
    end

    local y1 = generateWave(150 * 10.78, 30)
    local y2 = generateWave(70 * 10.78, 17)
    local y3 = generateWave(20 * 10.78, 5)

    y3 = y3 * ((math.sin(x / 30) + 1) / 2) -- Apply roughness condition

    local linear = numbers.mapInto(x / stepSize, -20, 20, -1000, 1000)

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

    local extraSteps = 100

    for i = 1 - extraSteps, steps + 2 + extraSteps do
        local x = (math.floor(camtlx / stepSize) * stepSize) + (i - 1) * stepSize
        local y = getYAtX(x, stepSize)

        table.insert(points, x)
        table.insert(points, y)
    end
    --print(inspect(points))

    ground.shape = love.physics.newChainShape(false, points)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
    ground.fixture:setUserData("ground")
    ground.fixture:setFriction(1)
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

function makeBike(x, y, radius)
    local ball1 = {}
    ball1.body = love.physics.newBody(world, x + radius * 1.5, y, "dynamic")
    ball1.shape = love.physics.newCircleShape(radius)
    ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, .1)
    ball1.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    ball1.fixture:setFriction(1)
    ball1.body:setAngularVelocity(10000)


    local ball2 = {}
    ball2.body = love.physics.newBody(world, x - radius * 1.5, y, "dynamic")
    ball2.shape = love.physics.newCircleShape(radius)
    ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, .1)
    ball2.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    ball2.fixture:setFriction(1)
    ball2.body:setAngularVelocity(10000)


    local frame = {}
    frame.body = love.physics.newBody(world, x, y, "dynamic")
    frame.shape = love.physics.newRectangleShape(radius * 3, 100)
    frame.fixture = love.physics.newFixture(frame.body, frame.shape, .1)


    local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
    local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)

    --joint1:setMotorEnabled(true)
    --joint1:setMotorSpeed(500000)
    --joint1:setMaxMotorTorque(20000)


    return ball1
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
    stepSize = 100
    ground = initGround()
    addMipos.make(4)
    obstacles = {}
    for i = 1, 100 do
        local o = makeRandomPoly(i * 30, -500, 10 + love.math.random() * 100)
        table.insert(obstacles, o)
    end

    for i = 1, 100 do
        local o = makeRandomTriangle(i * 30, -500, 50)
        table.insert(obstacles, o)
    end

    ball = makeBike(0, -1500, 450)

    rollingAverageVelX = {}
    rollingAverageVelY = {}
    rollingDistance = {}

    for i = 1, 10 do
        rollingAverageVelX[i] = 0
        rollingAverageVelY[i] = 0
        rollingDistance[i] = 0
    end
end

function love.load()
    jointsEnabled = true
    followCamera = true
    startExample()

    pointsOfInterest = {}
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

function getTargetPositionBeforeMe(me)
    local avgVelX = calculateRollingAverage(rollingAverageVelX)
    local avgVelY = calculateRollingAverage(rollingAverageVelY)
    local worldX, worldY = me.body:getWorldPoint(0, 0)

    local targetX = worldX + avgVelX / 2
    local targetY = worldY --+ avgVelY / 2

    -- this will look at the ground at the   x iam looking at
    targetY = lerpYAtX(targetX, stepSize)
    -- this will average with my own pos

    targetY = (worldY + targetY) / 2

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

function getTargetPos(thing)
    local tx, ty = getTargetPositionBeforeMe(thing)

    local x, y = thing.body:getPosition()

    local poi = getClosestPointFromList({ x = x, y = y }, pointsOfInterest)
    local distance = getDistance(x, y, poi.x, poi.y)

    -- how to blend targets ?
    -- if pos is in smallest radius then completely look at poi
    -- if pos is in outside radius ring (radisu *2) mapinto the blend
    -- else just use tx, ty

    local t = 0
    if (distance < poi.radius) then
        t = 1
    elseif distance < poi.radius * 2 then
        t = numbers.mapInto(distance, poi.radius * 2, poi.radius, 0, 1)
    end

    local nx = numbers.lerp(tx, poi.x, t)
    local ny = numbers.lerp(ty, poi.y, t)

    return nx, ny
end

function love.update(dt)
    local velX, velY = ball.body:getLinearVelocity()
    table.insert(rollingAverageVelX, velX)
    table.remove(rollingAverageVelX, 1)

    table.insert(rollingAverageVelY, velY)
    table.remove(rollingAverageVelY, 1)

    updateGround(ground)
    enableDisableObstacles()
    world:update(dt)
    phys.handleUpdate(dt, cam)

    box2dGuyCreation.rotateAllBodies(world:getBodies(), dt)

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

    local dividerFar = numbers.mapInto(newDistance, 500, 2000, 3, 15)
    --local dividerNear = numbers.mapInto(newDistance, 500, 0, 3, 0)
    local distance = getDistance(curCamX, curCamY, targetX, targetY)

    divider = dividerFar

    local delta = love.timer.getAverageDelta() or dt

    local smoothX = lerp(curCamX, targetX, divider / (1 / delta))
    local smoothY = lerp(curCamY, targetY, divider / (1 / delta))

    local viewWidth = 3000 ---numbers.mapInto(math.abs(avgVelX), 0, 2000, 2000, 2500)
    --if distance < 500 then viewWidth = 2000 end

    -- if distance > 500 then
    --print('yes')
    --camera.centerCameraOnPosition(targetX, targetY, viewWidth, viewWidth)
    if followCamera then
        camera.centerCameraOnPosition(smoothX, smoothY, viewWidth, viewWidth)
    end
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

function love.draw()
    love.graphics.clear(1, 0, 1)
    love.graphics.setColor(1, 1, 1)




    local w, h = love.graphics.getDimensions()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    local sky = skyGradient(camtly, cambry)

    if sky then
        love.graphics.draw(sky, 0, 0, 0, w, h)
    end
    cam:push()
    phys.drawWorld(world)
    for i = 1, #fiveGuys do
        texturedBox2d.drawSkinOver(fiveGuys[i].b2d, fiveGuys[i])
    end

    local wx, wy = ball.body:getPosition()
    local yy = lerpYAtX(wx, stepSize)
    love.graphics.circle('fill', wx, yy, 10)

    love.graphics.setColor(0.3, 0.3, 0.3)
    for i = 1, #pointsOfInterest do
        local poi = pointsOfInterest[i]
        love.graphics.circle('line', poi.x, poi.y, poi.radius)
        love.graphics.circle('line', poi.x, poi.y, poi.radius * 2)
    end
    love.graphics.setColor(1, 1, 1)
    local targetX, targetY = getTargetPos(ball)
    love.graphics.rectangle('line', targetX, targetY, 40, 40)

    local curCamX, curCamY = cam:getTranslation()
    love.graphics.circle('line', curCamX, curCamY, 20)
    cam:pop()


    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    --local velX, velY = ball.body:getLinearVelocity()
    --love.graphics.print('ball speed: ' .. math.floor(velX), 10, 30)
    local stats = love.graphics.getStats()
    love.graphics.print(inspect(stats), 10, 10)
    love.graphics.print(
        world:getBodyCount() ..
        '  , ' .. world:getJointCount() .. '  , ' .. love.timer.getFPS() .. ', ' .. collectgarbage("count"), 180,
        10)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then ball.body:setAngularVelocity(10000) end
    if k == '.' then
        followCamera = not followCamera
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
            local force = ud and ud.bodyType == 'torso' and 5000000 or 50000
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
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
