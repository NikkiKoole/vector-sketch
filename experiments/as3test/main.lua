
local world
local car
local leftWheelRevoluteJoint
local rightWheelRevoluteJoint
local left = false
local right = false
local motorSpeed = 0
local leftAxlePrismaticJoint
local rightAxlePrismaticJoint

-- Constants
local degreesToRadians = 0.0174532925
local worldScale = 30

-- Car configuration values
local carPosX = 320
local carPosY = 250
local carWidth = 45
local carHeight = 10
local axleContainerDistance = 30
local axleContainerWidth = 5
local axleContainerHeight = 20
local axleContainerDepth = 10
local axleAngle = 20
local wheelRadius = 25


function fixtureMaker(body, shape, density, friction, restitution ) 
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setFriction(1)
    fixture:setRestitution(1)
end

function love.load()
    -- Initialize Box2D world
    love.physics.setMeter(worldScale)
    world = love.physics.newWorld(0, 10, true)

    -- Create the floor
    local floorBody = love.physics.newBody(world, 320, 480)
    local floorShape = love.physics.newRectangleShape(640, 10)
    fixtureMaker(floorBody, floorShape, 0, 10, 0)

    -- Create the car
    car = love.physics.newBody(world, carPosX, carPosY, "dynamic")
    local carShape = love.physics.newRectangleShape(carWidth, carHeight)
    fixtureMaker(car, carShape, 5, 3, 0.3 )
    
    -- Create left axle container
    local leftAxleContainerShape = love.physics.newRectangleShape(axleContainerWidth, axleContainerHeight, -axleContainerDistance, axleContainerDepth, degreesToRadians * axleAngle)
    fixtureMaker(car, leftAxleContainerShape, 3, 3, 0.3)

    -- Create right axle container
    local rightAxleContainerShape = love.physics.newRectangleShape(axleContainerWidth, axleContainerHeight, axleContainerDistance, axleContainerDepth, -degreesToRadians * axleAngle)
    fixtureMaker(car, rightAxleContainerShape, 3, 3, 0.3)

    -- Create left axle
    local leftAxle = love.physics.newBody(world, carPosX - axleContainerDistance - axleContainerHeight * math.cos((90 - axleAngle) * degreesToRadians), carPosY + axleContainerDepth + axleContainerHeight * math.sin((90 - axleAngle) * degreesToRadians), "dynamic")
    local leftAxleShape = love.physics.newRectangleShape(axleContainerWidth / 2, axleContainerHeight, 0, 0, degreesToRadians * axleAngle)
    fixtureMaker(leftAxle, leftAxleShape, 0.5, 3, 0)

    -- Create right axle
    local rightAxle = love.physics.newBody(world, carPosX + axleContainerDistance + axleContainerHeight * math.cos((90 - axleAngle) * degreesToRadians), carPosY + axleContainerDepth + axleContainerHeight * math.sin((90 - axleAngle) * degreesToRadians), "dynamic")
    local rightAxleShape = love.physics.newRectangleShape(axleContainerWidth / 2, axleContainerHeight, 0, 0, -degreesToRadians * axleAngle)
    fixtureMaker(rightAxle, rightAxleShape, 0.5, 3, 0)

    -- Create left wheel
    local leftWheel = love.physics.newBody(world, carPosX - axleContainerDistance - 2 * axleContainerHeight * math.cos((90 - axleAngle) * degreesToRadians), carPosY + axleContainerDepth + 2 * axleContainerHeight * math.sin((90 - axleAngle) * degreesToRadians), "dynamic")
    local leftWheelShape = love.physics.newCircleShape(wheelRadius)
    fixtureMaker(leftWheel, leftWheelShape, 1, 15, 0.2)

    -- Create right wheel
    local rightWheel = love.physics.newBody(world, carPosX + axleContainerDistance + 2 * axleContainerHeight * math.cos((90 - axleAngle) * degreesToRadians), carPosY + axleContainerDepth + 2 * axleContainerHeight * math.sin((90 - axleAngle) * degreesToRadians), "dynamic")
    local rightWheelShape = love.physics.newCircleShape(wheelRadius)
    fixtureMaker(rightWheel, rightWheelShape, 1, 15, 0.2)

    -- Create left wheel revolute joint
    leftWheelRevoluteJoint = love.physics.newRevoluteJoint(car, leftWheel, leftWheel:getX(), leftWheel:getY(), true)
    leftWheelRevoluteJoint:setMotorEnabled(true)
    leftWheelRevoluteJoint:setMaxMotorTorque(10)

    -- Create right wheel revolute joint
    rightWheelRevoluteJoint = love.physics.newRevoluteJoint(car, rightWheel, rightWheel:getX(), rightWheel:getY(), true)
    rightWheelRevoluteJoint:setMotorEnabled(true)
    rightWheelRevoluteJoint:setMaxMotorTorque(10)

    -- Create left axle prismatic joint
    leftAxlePrismaticJoint = love.physics.newPrismaticJoint(car, leftAxle, leftAxle:getX(), leftAxle:getY(), -math.cos((90 - axleAngle) * degreesToRadians), math.sin((90 - axleAngle) * degreesToRadians), true)
    leftAxlePrismaticJoint:setLimitsEnabled(true)
    leftAxlePrismaticJoint:setLimits(0, axleContainerDepth)
    leftAxlePrismaticJoint:setMotorEnabled(true)
    leftAxlePrismaticJoint:setMotorForce(10)
    leftAxlePrismaticJoint:setMotorSpeed(10)

    -- Create right axle prismatic joint
    rightAxlePrismaticJoint = love.physics.newPrismaticJoint(car, rightAxle, rightAxle:getX(), rightAxle:getY(), math.cos((90 - axleAngle) * degreesToRadians), math.sin((90 - axleAngle) * degreesToRadians), true)
    rightAxlePrismaticJoint:setLimitsEnabled(true)
    rightAxlePrismaticJoint:setLimits(0, axleContainerDepth)
    rightAxlePrismaticJoint:setMotorEnabled(true)
    rightAxlePrismaticJoint:setMotorForce(10)
    rightAxlePrismaticJoint:setMotorSpeed(10)

    -- Set up Love2D callbacks
    love.graphics.setBackgroundColor(255, 255, 255)
    love.window.setTitle("Box2D Car Example")
end

function love.keypressed(key)
    if key == "left" then
        left = true
    elseif key == "right" then
        right = true
    end
end

function love.keyreleased(key)
    if key == "left" then
        left = false
    elseif key == "right" then
        right = false
    end
end

function love.update(dt)
    if left then
        motorSpeed = motorSpeed + 0.1
    end

    if right then
        motorSpeed = motorSpeed - 0.1
    end

    motorSpeed = motorSpeed
    motorSpeed = motorSpeed * 0.99

    if motorSpeed > 10 then
        motorSpeed = 10
    end

    leftWheelRevoluteJoint:setMotorSpeed(motorSpeed)
    rightWheelRevoluteJoint:setMotorSpeed(motorSpeed)

    world:update(dt)
end

function love.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Press LEFT and RIGHT arrow keys to control the car", 10, 10)

    -- Draw the car body
    love.graphics.setColor(0, 0, 255)
    love.graphics.polygon("fill", car:getWorldPoints(car:getFixtures()[1]:getShape():getPoints()))

    -- Draw the left axle container
    love.graphics.setColor(255, 0, 0)
    love.graphics.polygon("fill", car:getWorldPoints(car:getFixtures()[2]:getShape():getPoints()))

    -- Draw the right axle container
    love.graphics.polygon("fill", car:getWorldPoints(car:getFixtures()[3]:getShape():getPoints()))

    -- Draw the left axle
    love.graphics.setColor(0, 255, 0)
    love.graphics.polygon("fill", leftAxle:getWorldPoints(leftAxle:getFixtures()[1]:getShape():getPoints()))

    -- Draw the right axle
    love.graphics.polygon("fill", rightAxle:getWorldPoints(rightAxle:getFixtures()[1]:getShape():getPoints()))

    -- Draw the left wheel
    love.graphics.setColor(255, 255, 0)
    love.graphics.circle("fill", leftWheel:getX(), leftWheel:getY(), wheelRadius)

    -- Draw the right wheel
    love.graphics.circle("fill", rightWheel:getX(), rightWheel:getY(), wheelRadius)
end
