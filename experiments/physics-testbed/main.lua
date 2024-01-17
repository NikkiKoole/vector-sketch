package.path  = package.path .. ";../../?.lua"

local cam     = require('lib.cameraBase').getInstance()
local camera  = require 'lib.camera'
local phys    = require 'lib.mainPhysics'

local numbers = require 'lib.numbers'

function makeChainGround()
    local width, height = love.graphics.getDimensions()
    local points = {}

    for i = -1500, 1500 do
        local cool = 4.78
        local amplitude = 50 * cool
        local frequency = 30 + love.math.random() * 3
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y1 = h - (amplitude / 2)

        local cool = 1.78
        local amplitude = 200 * cool
        local frequency = 17
        local h = love.math.noise(i / frequency, 1, 1) * amplitude
        local y2 = h - (amplitude / 2)

        table.insert(points, i * 100)

        -- how to get this to be a hill slope ?
        -- well, i just want -1000 to be at some height and 1000 to rets is linear map


        local linear = numbers.mapInto(i, -1500, 1500, -25000, 25000)

        table.insert(points, y1 + y2 + linear)
    end

    print(#points)

    local thing = {}
    thing.body = love.physics.newBody(world, 0, 0)
    thing.shape = love.physics.newChainShape(false, points)
    thing.fixture = love.physics.newFixture(thing.body, thing.shape)
    thing.fixture:setUserData("border")
    thing.fixture:setFriction(1)
    return thing
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
    ground = makeChainGround()
    makeBall(0 + 1000, -200, 1200)
    makeBall(0 + 1000, -200, 200)
    makeBall(0, -100, 50)
    -- world:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

function love.load()
    startExample()
    local w, h = love.graphics.getDimensions()

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)
end

function love.update(dt)
    world:update(dt)
    phys.handleUpdate(dt, cam)
end

function love.draw()
    cam:push()
    phys.drawWorld(world)
    cam:pop()
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
    pointerPressed(x, y, 'mouse')
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
