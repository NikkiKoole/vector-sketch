package.path = package.path .. ";../../?.lua"

local lurker = require 'vendor.lurker'
lurker.quiet = true
require 'palette'

lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    grabDevelopmentScreenshot()
end

function grabDevelopmentScreenshot()
    love.graphics.captureScreenshot('ScreenShot-' .. os.date("%Y-%m-%d-[%H-%M-%S]") .. '.png')
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function beginContact(a, b, coll)

end

function endContact(a, b, coll)

end

function preSolve(a, b, coll)

end

function postSolve(a, b, coll, normalimpulse, tangentimpulse)

end

function love.load()
    local font = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    love.graphics.setFont(font)

    vlooienspel = love.graphics.newImage('vlooienspel.jpg')

    local width = 800
    local height = 600

    love.physics.setMeter(100)

    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    objects = {}
    objects.border = {}
    objects.border.body = love.physics.newBody(world, 0, 0)

    margin = 20
    --angularVelocity = 5
    objects.border.shape = love.physics.newChainShape(true,
            margin, margin,
            width - margin, margin,
            width - margin, height - margin,
            margin, height - margin)

    objects.border.fixture = love.physics.newFixture(objects.border.body, objects.border.shape)
    objects.border.fixture:setUserData("border")
    objects.border.fixture:setFriction(.5)

    ballRadius = love.physics.getMeter() / 2
    objects.ball = {}
    objects.ball.body = love.physics.newBody(world, width / 2, height / 2, "dynamic")
    objects.ball.body:setFixedRotation(true)
    objects.ball.shape = love.physics.newCircleShape(ballRadius)
    objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
    objects.ball.fixture:setRestitution(.4) -- let the ball bounce
    objects.ball.fixture:setUserData("ball")
    objects.ball.fixture:setFriction(.5)
    --objects.ball.fixture:setDensity(3)
    -- objects.ball.body:setLinearDamping(5)


    angularVelocity = 2
    objects.carousel = {}
    objects.carousel.body = love.physics.newBody(world, width / 2, height / 2, "kinematic")
    --objects.carousel.shape = love.physics.newCircleShape(20)
    objects.carousel.shape = love.physics.newRectangleShape(width / 5, width / 10)
    objects.carousel.fixture = love.physics.newFixture(objects.carousel.body, objects.carousel.shape, 1)
    objects.carousel.body:setAngularVelocity(angularVelocity)
    objects.carousel.fixture:setUserData("wall")


    mouseJoints = {
        joint = nil,
        jointBody = nil
    }


    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])
    love.window.setMode(width, height, { resizable = true })

    grabDevelopmentScreenshot()
end

function killMouseJointIfPossible()
    if (mouseJoints.joint) then
        mouseJoints.joint:destroy()
        mouseJoints.joint     = nil
        mouseJoints.jointBody = nil
    end
end

function love.mousereleased()
    killMouseJointIfPossible()
end

function love.mousepressed(x, y)
    local bx, by = objects.ball.body:getPosition()
    local dx, dy = x - bx, y - by
    local distance = math.sqrt(dx * dx + dy * dy)

    if (distance < ballRadius) then
        mouseJoints.jointBody = objects.ball.body
        mouseJoints.joint = love.physics.newMouseJoint(mouseJoints.jointBody, x, y)
        mouseJoints.joint:setDampingRatio(1)
    else
        killMouseJointIfPossible()
    end
end

function drawBlock(thing)
    local cx, cy = thing.body:getWorldCenter()
    local d = thing.fixture:getDensity()
    love.graphics.setColor(0.20 * (d * 3), 1.0 - d * 5, 0.20)
    love.graphics.polygon("fill", thing.body:getWorldPoints(thing.shape:getPoints()))
    love.graphics.setColor(1, 0.5, 0.20)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", thing.body:getWorldPoints(thing.shape:getPoints()))
    love.graphics.setColor(1, 1, 1)
end

function drawCircle(body, shape)
    love.graphics.setColor(palette[colors.orange][1], palette[colors.orange][2], palette[colors.orange][3])

    love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
    love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])


    love.graphics.setLineWidth(3)
    love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
end

function drawCenteredBackgroundText(str)
    local width, height = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local textw, wrappedtext = font:getWrap(str, width)
    local texth = font:getHeight() * #wrappedtext
    love.graphics.print(str, width / 2 - textw / 2, height / 2 - texth / 2)
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    drawMeterGrid()

    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
    love.graphics.rectangle("fill", 0, 0, width, margin)
    love.graphics.rectangle("fill", 0, height - margin, width, margin)
    love.graphics.rectangle("fill", 0, 0, margin, height)
    love.graphics.rectangle("fill", width - margin, 0, margin, height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(vlooienspel, width / 2, height / 4, 0, 1, 1,
        vlooienspel:getWidth() / 2, vlooienspel:getHeight() / 2)
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
    drawCenteredBackgroundText('Pull back to aim and shoot.')
    drawBlock(objects.carousel)
    drawCircle(objects.ball.body, objects.ball.shape)
end

function drawMeterGrid()
    local width, height = love.graphics.getDimensions()
    local ppm = love.physics.getMeter()
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3], 0.2)
    for x = 0, width, ppm do
        love.graphics.line(x, 0, x, height)
    end
    for y = 0, height, ppm do
        love.graphics.line(0, y, width, y)
    end
end

function love.update(dt)
    lurker.update()
    if (mouseJoints.joint) then
        mouseJoints.joint:setTarget(love.mouse.getPosition())
    end
    world:update(dt)
end
