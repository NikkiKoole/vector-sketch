package.path = package.path .. ";../../?.lua"

local lurker = require 'vendor.lurker'
local inspect = require 'vendor.inspect'
Vector = require 'vendor.brinevector'

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
    if k == '1' then startExample(1) end
    if k == '2' then startExample(2) end
end

-- https://www.iforce2d.net/b2dtut/one-way-walls
-- in the original tutorial they hack box2d to stop reenabling contacts every frame, i cannot do that. so i must keep a list around.

function contactShouldBeDisabled(a, b, contact)
    -- contacts should ONLY be dsiabled if it is betweena ground object and a thing that is dragged.
    local ab = a:getBody()
    local bb = b:getBody()

    local fixtureA, fixtureB = contact:getFixtures()
    local result = false
    if (mouseJoints.jointBody) then
        if (ab == mouseJoints.jointBody and fixtureB:getUserData() == 'ground') then
            result = true
        end
        if (bb == mouseJoints.jointBody and fixtureA:getUserData() == 'ground') then
            result = true
        end
    end

    return result
end

function beginContact(a, b, contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also waht touch id or mouse this is..

        positionOfLastDisabledContact = point
        -- we want to know if a or b was the mousejoint thing.
        if a:getBody() == mouseJoints.jointBody then
            bodyLastDisabledContact = a
        end
        if b:getBody() == mouseJoints.jointBody then
            bodyLastDisabledContact = b
        end

        table.insert(disabledContacts, contact)
    end
end

function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end
end

function preSolve(a, b, contact)
    -- this is so contacts keep on being disabled if they are on that list (sadly they are being re-enabled by box2d.... )
    for i = 1, #disabledContacts do
        disabledContacts[i]:setEnabled(false)
    end
end

function postSolve(a, b, contact, normalimpulse, tangentimpulse)

end

function capsule(w, h, cs)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2
    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    local result = {
        -w2, bt,
        bl, -h2,
        br, -h2,
        w2, bt,
        w2, bb,
        br, h2,
        bl, h2,
        -w2, bb
    }
    return result
end

function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")

    ball.body:setFixedRotation(true)
    --objects.ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20,
    --        ballRadius * 3 + love.math.random() * 20, 5))
    ball.shape = love.physics.newCircleShape(ballRadius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(.4) -- let the ball bounce
    ball.fixture:setUserData("ball")
    ball.fixture:setFriction(.5)
    return ball
end

function makeCarousell(x, y, width, height, angularVelocity)
    local carousel = {}
    carousel.body = love.physics.newBody(world, x, y, "kinematic")
    carousel.shape = love.physics.newRectangleShape(width, height)
    carousel.fixture = love.physics.newFixture(carousel.body, carousel.shape, 1)
    carousel.body:setAngularVelocity(angularVelocity)
    carousel.fixture:setUserData("caroussel")
    return carousel
end

function makeBorderChain(width, height, margin)
    local border = {}
    border.body = love.physics.newBody(world, 0, 0)


    --angularVelocity = 5
    border.shape = love.physics.newChainShape(true,
            margin, margin,
            width - margin, margin,
            width - margin, height - margin,
            margin, height - margin)

    border.fixture = love.physics.newFixture(border.body, border.shape)
    border.fixture:setUserData("border")
    border.fixture:setFriction(.5)
    return border
end

function startExample(number)
    local width, height = love.graphics.getDimensions()
    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    objects = {}
    margin = 20

    objects.border = makeBorderChain(width, height, margin)
    ballRadius = love.physics.getMeter() / 4

    objects.balls = {}
    for i = 1, 10 do
        objects.balls[i] = makeBall(margin * 2 + (love.math.random() * width) - margin * 4,
                margin + love.math.random() * height / 2, ballRadius)
    end

    angularVelocity = 2
    objects.carousel = makeCarousell(width / 2, height / 2, width / 4, width / 20, angularVelocity)
    objects.carousel2 = makeCarousell(width / 2 + width / 4, height / 2, width / 4, width / 20, -angularVelocity)


    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, width / 2, height - (height / 10), "static")
    objects.ground.shape = love.physics.newRectangleShape(width, height / 4)
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
    objects.ground.fixture:setUserData("ground")
    objects.ground.body:setTransform(width / 2, height - (height / 10), 0) --  <= here we se an anlgle to the ground!!
    objects.ground.fixture:setFriction(0.01)
end

function love.load()
    local font = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    love.graphics.setFont(font)

    vlooienspel = love.graphics.newImage('vlooienspel.jpg')

    local width = 800
    local height = 600

    -- before these were local but that didnt work with lurker
    -- all of these are relevant to the vlooienspel experiment, and not to others (I think)
    disabledContacts = {}
    positionOfLastDisabledContact = nil
    bodyLastDisabledContact = nil

    mouseJoints = {
        joint = nil,
        jointBody = nil
    }

    startExample(1)
    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])


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
    -- now we have to find a few things out to check if i want to shoot my thing
    -- first off, are we below the ground ?
    if (mouseJoints.joint) then
        if (mouseJoints.jointBody) then
            local points = { objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()) }
            local tl = { points[1], points[2] }
            local tr = { points[3], points[4] }
            -- fogure out if we are below the ground, and if so whatthe ange is we want to be shot at.
            -- oh wait, this is actually kinda good enough-ish (tm)
            if (bodyLastDisabledContact and bodyLastDisabledContact:getBody() == mouseJoints.jointBody) then
                local x1, y1 = mouseJoints.jointBody:getPosition()
                local x2 = positionOfLastDisabledContact[1]
                local y2 = positionOfLastDisabledContact[2]

                local delta = Vector(x1 - x2, y1 - y2)
                local l = delta:getLength()
                local v = delta:getNormalized() * l * -5
                if v.y > 0 then v.y = 0 end -- i odnt want  you shoooting downward!
                bodyLastDisabledContact:getBody():applyLinearImpulse(v.x, v.y)
                bodyLastDisabledContact = nil
                positionOfLastDisabledContact = nil
                --
            end
        end
    end
    killMouseJointIfPossible()
end

function love.mousepressed(x, y)
    --local bodies = { objects.ball.body, objects.ball2.body }
    local hit = false
    local epsilon = 0.01

    for i = 1, #objects.balls do
        local body = objects.balls[i].body
        local bx, by = body:getPosition()
        local dx, dy = x - bx, y - by
        local distance = math.sqrt(dx * dx + dy * dy)

        if (distance < ballRadius) then
            mouseJoints.jointBody = body
            mouseJoints.joint = love.physics.newMouseJoint(mouseJoints.jointBody, x, y)
            mouseJoints.joint:setDampingRatio(.5)

            local vx, vy = body:getLinearVelocity()

            if math.abs(vx) < epsilon and math.abs(vy) < epsilon then
                body:applyLinearImpulse(0, 200) -- so you can drag it through the floor from  there!!
            end
            hit = true
        end
    end
    if hit == false then killMouseJointIfPossible() end
end

function drawThing(thing)
    local cx, cy = thing.body:getWorldCenter()
    local d = thing.fixture:getDensity()
    local t = thing.body:getType()

    local shape = thing.shape
    local body = thing.body

    if t == 'kinematic' then
        love.graphics.setColor(palette[colors.peach][1], palette[colors.peach][2], palette[colors.peach][3])
    elseif (t == 'dynamic') then
        love.graphics.setColor(palette[colors.blue][1], palette[colors.blue][2], palette[colors.blue][3])
    elseif (t == 'static') then
        love.graphics.setColor(palette[colors.green][1], palette[colors.green][2], palette[colors.green][3])
    end

    if (shape:getType() == 'polygon') then
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
        love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    end

    if (shape:getType() == 'circle') then
        love.graphics.setColor(palette[colors.orange][1], palette[colors.orange][2], palette[colors.orange][3])
        love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
        love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
    end

    if shape:getType() == 'chain' then
        love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])
        local points = { body:getWorldPoints(shape:getPoints()) }
        for i = 1, #points, 2 do
            if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
        end
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    end
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


    love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])


    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(vlooienspel, width / 2, height / 4, 0, 1, 1,
        vlooienspel:getWidth() / 2, vlooienspel:getHeight() / 2)
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
    drawCenteredBackgroundText('Pull back to aim and shoot.')
    drawThing(objects.carousel)
    drawThing(objects.carousel2)
    drawThing(objects.ground)
    for i = 1, #objects.balls do
        drawThing(objects.balls[i])
    end

    if positionOfLastDisabledContact then
        love.graphics.circle('fill', positionOfLastDisabledContact[1], positionOfLastDisabledContact[2], 10)
        if (bodyLastDisabledContact) then
            local posx, posy = bodyLastDisabledContact:getBody():getPosition()
            love.graphics.line(positionOfLastDisabledContact[1], positionOfLastDisabledContact[2], posx, posy)
        end
    end

    drawThing(objects.border)

    --drawCircle(objects.ball.body, objects.ball.shape)
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
