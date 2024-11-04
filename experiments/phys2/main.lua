-- main.lua

-- Define the scale: pixels per meter
local scale = 64

-- Physics world
local world

-- Table to hold all our physical objects
local objects = {}

-- Variables for mouse joint
local mouseJoint = nil
local mouseBody = nil
local selectedBody = nil
local isDragging = false

-- Window dimensions
local windowWidth = 650
local windowHeight = 650

function love.load()
    -- Set window title and dimensions
    love.window.setTitle("Love2D + Box2D with Mouse Interaction")
    love.window.setMode(windowWidth, windowHeight)

    -- Create the physics world with gravity (0, 9.81 m/s²)
    -- Convert gravity to pixels/s²
    local gravityX = 0
    local gravityY = 9.81 * scale
    world = love.physics.newWorld(gravityX, gravityY, true) -- Gravity downwards

    -- Create the ground
    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, windowWidth / 2, windowHeight - 25, "static") -- y = 650 - 50/2 = 625
    objects.ground.shape = love.physics.newRectangleShape(windowWidth, 50)                          -- Width 650px, Height 50px
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape)

    -- Create the ball
    objects.ball = {}
    objects.ball.body = love.physics.newBody(world, windowWidth / 2, windowHeight / 2, "dynamic")
    objects.ball.shape = love.physics.newCircleShape(20)                                     -- Radius 20px
    objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1) -- Density 1
    objects.ball.fixture:setRestitution(0.9)                                                 -- Bounciness

    -- Create Block 1
    objects.block1 = {}
    objects.block1.body = love.physics.newBody(world, 200, 550, "dynamic")
    objects.block1.shape = love.physics.newRectangleShape(0, 0, 50, 100)                           -- Position (0,0) relative to body
    objects.block1.fixture = love.physics.newFixture(objects.block1.body, objects.block1.shape, 5) -- Density 5

    -- Create Block 2
    objects.block2 = {}
    objects.block2.body = love.physics.newBody(world, 200, 400, "dynamic")
    objects.block2.shape = love.physics.newRectangleShape(0, 0, 100, 50)                           -- Position (0,0) relative to body
    objects.block2.fixture = love.physics.newFixture(objects.block2.body, objects.block2.shape, 2) -- Density 2

    -- Create a kinematic body for the mouse joint
    mouseBody = love.physics.newBody(world, 0, 0, "kinematic")

    -- Initial graphics setup
    love.graphics.setBackgroundColor(0.41, 0.53, 0.97) -- Nice blue background
end

function love.update(dt)
    -- Update the physics world
    world:update(dt)

    -- Handle keyboard input for the ball
    if love.keyboard.isDown("right") then
        objects.ball.body:applyForce(400, 0)                             -- Push right
    elseif love.keyboard.isDown("left") then
        objects.ball.body:applyForce(-400, 0)                            -- Push left
    elseif love.keyboard.isDown("up") then
        objects.ball.body:setPosition(windowWidth / 2, windowHeight / 2) -- Reset position
        objects.ball.body:setLinearVelocity(0, 0)                        -- Reset velocity
    end

    -- If dragging, update the mouseBody position to follow the mouse
    if isDragging and mouseJoint then
        local mouseX, mouseY = love.mouse.getPosition()
        mouseBody:setPosition(mouseX, mouseY)
    end
end

function love.draw()
    -- Draw the ground
    love.graphics.setColor(0.28, 0.63, 0.05) -- Green color
    love.graphics.polygon("fill", objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()))

    -- Draw the ball
    love.graphics.setColor(0.76, 0.18, 0.05) -- Red color
    love.graphics.circle("fill", objects.ball.body:getX(), objects.ball.body:getY(), objects.ball.shape:getRadius())

    -- Draw Block 1
    love.graphics.setColor(0.20, 0.20, 0.20) -- Grey color
    love.graphics.polygon("fill", objects.block1.body:getWorldPoints(objects.block1.shape:getPoints()))

    -- Draw Block 2
    love.graphics.polygon("fill", objects.block2.body:getWorldPoints(objects.block2.shape:getPoints()))
end

-- Function to check if a point is inside a shape
local function isMouseOver(shape, x, y)
    return shape:testPoint(x, y)
end

-- Function to find the topmost object under the mouse
local function getObjectAtPosition(x, y)
    -- Check ball first
    if isMouseOver(objects.ball.shape, x, y) then
        return objects.ball.body
    end

    -- Check blocks
    if isMouseOver(objects.block1.shape, x, y) then
        return objects.block1.body
    end
    if isMouseOver(objects.block2.shape, x, y) then
        return objects.block2.body
    end

    -- No object found
    return nil
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then -- Left mouse button
        -- Find the object under the mouse
        local body = getObjectAtPosition(x, y)
        if body then
            -- Create a pivot joint between mouseBody and the selected body
            mouseJoint = love.physics.newPivotJoint(mouseBody, body, x, y)
            mouseJoint:setMaxForce(1000 * body:getMass()) -- Adjust max force based on mass
            isDragging = true
            selectedBody = body
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then -- Left mouse button
        if isDragging and mouseJoint then
            mouseJoint:destroy()
            mouseJoint = nil
            isDragging = false
            selectedBody = nil
        end
    end
end
