package.path  = package.path .. ";../../?.lua"

local cam     = require('lib.cameraBase').getInstance()
local camera  = require 'lib.camera'
local phys    = require 'lib.mainPhysics'

local numbers = require 'lib.numbers'


function initGround()
    local thing = {}
    thing.body = love.physics.newBody(world, 0, 0)
    updateGround(thing)
    return thing
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
    local stepSize = 100
    local steps = math.ceil(boxWorldWidth / stepSize)
    --print(math.ceil(steps))

    local points = {}

    if ground.fixture then
        ground.fixture:destroy()
    end

    local extraSteps = 100
    for i = 1 - extraSteps, steps + 2 + extraSteps do
        local index = math.floor(camtlx / stepSize) + (i - 1)
        --print(i, index)

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


        -- the downhiill steepness
        local linear = numbers.mapInto(index, -20 * stepSize, 20 * stepSize, -500 * stepSize, 500 * stepSize)
        local x = (math.floor(camtlx / stepSize) * stepSize) + (i - 1) * stepSize

        table.insert(points, x)
        table.insert(points, y1 + y2 + y3 + linear)
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
    ball.fixture:setFriction(1)
    return ball
end

function startExample(number)
    phys.setupWorld()
    --  local width, height = love.graphics.getDimensions()
    --  love.physics.setMeter(500)
    --  world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    ground = initGround()
    ball = makeBall( -100, -500, 100)
    ball = makeBall( -299, -500, 100)
    ball = makeBall(0, -500, 100)
    -- makeBall(0 + 1000, -200, 200)
    -- makeBall(0, -100, 50)
    -- world:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

function love.load()
    startExample()
    local w, h = love.graphics.getDimensions()
    -- ground = initGround()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)
end

function love.update(dt)
    updateGround(ground)
    world:update(dt)
    phys.handleUpdate(dt, cam)


    -- center camera on wheel
    -- do this stuff
    -- https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer
    -- https://www.youtube.com/watch?v=aAKwZt3aXQM&t=315s
    local worldX, worldY = ball.body:getWorldPoint(0, 0)


    local velX, velY = ball.body:getLinearVelocity()
    local viewWidth = numbers.mapInto(math.abs(velX), 0, 10000, 3000, 4000)
    camera.centerCameraOnPosition(worldX, worldY, viewWidth, viewWidth)
    --    print(velX)

    -- print(worldX, worldY)
end

function love.draw()
    cam:push()
    phys.drawWorld(world)
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
    local interacted = phys.handlePointerPressed(cx, cy, id)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        pointerPressed(x, y, 'mouse')
    end
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
