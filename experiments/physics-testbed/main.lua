package.path = package.path .. ";../../?.lua"
require 'lib.printC'
local inspect         = require 'vendor.inspect'
local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'
local phys            = require 'lib.mainPhysics'
local numbers         = require 'lib.numbers'
local generatePolygon = require('lib.generate-polygon').generatePolygon


local gradient = require 'lib.gradient'
--local skygradient = gradient.makeSkyGradient(16)




--[[
puppet maker
no adds
preschool
monsters
makeup
character
kids
free
monster
play
customize
]]
--

--[[
nikki, puppetmaker, character, dolls, mipo, mipolai , maker, puppet, customize, doll, kids, children
]]
--
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
    local amplitude = 70 * cool
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
    --local stepSize = 100
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
    ball.fixture:setRestitution(.2) -- let the ball bounce
    --ball.fixture:setUserData(phys.makeUserData("ball"))
    ball.fixture:setFriction(.5)

    ball.body:setAngularVelocity(10000)
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
    stepSize = 100
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

    for i = 1, 100 do
        local x = -200000 + love.math.random() * 400000
        local y = lerpYAtX(x, stepSize)
        table.insert(pointsOfInterest,
            { x = x, y = y - 500 + love.math.random() * 1000, radius = 400 })
    end

    -- ground = initGround()
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
    local targetY = worldY --+ avgVelY / 5

    -- this will look at the ground at the x iam looking at
    targetY = lerpYAtX(targetX, stepSize)
    -- this will average with my own pos
    targetY = (worldY + targetY) / 2

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
        --print(val)
        if val < closestDistance then
            closestDistance = val
            closest = list[i]
        end
    end

    return closest
    --local distance = getDistance(pos.x, pos.y, closest.x, closest.y)
    --print('closest', closestDistance, distance)
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
    camera.centerCameraOnPosition(smoothX, smoothY, viewWidth, viewWidth)
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
    local velX, velY = ball.body:getLinearVelocity()
    love.graphics.print('ball speed: ' .. math.floor(velX), 10, 30)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then ball.body:setAngularVelocity(10000) end
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
