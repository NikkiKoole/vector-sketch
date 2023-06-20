function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'left' then
        motorSpeed = motorSpeed - 10
        joint2:setMotorSpeed(motorSpeed)
        joint3:setMotorSpeed(motorSpeed)
    end
    if k == 'right' then
        motorSpeed = motorSpeed + 10
        joint2:setMotorSpeed(motorSpeed)
        joint3:setMotorSpeed(motorSpeed)
    end
end

colors = {
    peach = { 255 / 255, 204 / 255, 170 / 255 },
    blue = { 41 / 255, 173 / 255, 255 / 255 },
    black = { 0, 0, 0 },
    orange = { 255 / 255, 163 / 255, 0 },
    green = { 0, 231 / 255, 86 / 255 },
    cream = { 238 / 255, 226 / 255, 188 / 255 }
}

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

function love.load()
    local width, height = love.graphics.getDimensions()
    love.graphics.setBackgroundColor(colors.cream)
    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)

    objects = {}
    joints = {}

    local obj1 = {}
    obj1.body = love.physics.newBody(world, width * 20, height - (height / 10), "static")
    obj1.shape = love.physics.newRectangleShape(width * 20, height / 4)
    obj1.fixture = love.physics.newFixture(obj1.body, obj1.shape, 1)
    obj1.body:setTransform(width / 2, height - (height / 10), -0.1)
    obj1.fixture:setFriction(1)
    table.insert(objects, obj1)

    local obj2 = {}
    obj2.body = love.physics.newBody(world, width / 2, 100, "dynamic")
    obj2.shape = love.physics.newRectangleShape(400, 80)
    obj2.fixture = love.physics.newFixture(obj2.body, obj2.shape, .1)
    table.insert(objects, obj2)

    local obj3 = {}
    obj3.body = love.physics.newBody(world, width / 2 - 100, 100, "dynamic")
    --obj3.shape = love.physics.newRectangleShape(100, 100)
    obj3.shape = love.physics.newCircleShape(100)
    -- obj3.shape = love.physics.newPolygonShape(capsule(120, 120, 30))
    -- obj3.shape = love.physics.newPolygonShape(npoly(120, 8))
    obj3.fixture = love.physics.newFixture(obj3.body, obj3.shape, .1)
    obj3.fixture:setFriction(1)
    obj3.fixture:setFilterData(1, 65535, -1)
    table.insert(objects, obj3)

    local obj4 = {}
    obj4.body = love.physics.newBody(world, width / 2 + 100, 100, "dynamic")
    --obj3.shape = love.physics.newRectangleShape(100, 100)
    obj4.shape = love.physics.newCircleShape(80)
    obj4.shape = love.physics.newPolygonShape(npoly(70, 8))
    -- obj4.shape = love.physics.newPolygonShape(capsule(180, 160, 30))
    obj4.fixture = love.physics.newFixture(obj4.body, obj4.shape, .1)
    obj4.fixture:setFriction(1)
    obj4.fixture:setFilterData(1, 65535, -1)
    table.insert(objects, obj4)

    --joint = love.physics.newDistanceJoint(obj2.body, obj3.body, obj2.body:getX(), obj2.body:getY(), obj3.body:getX(),
    --        obj3.body:getY())
    --joint:setLength(5)


    local torque = 10000
    motorSpeed = 20
    joint2 = love.physics.newRevoluteJoint(obj2.body, obj3.body, obj3.body:getX(), obj3.body:getY(), false)
    --joint2 = love.physics.newRevoluteJoint(obj2.body, obj3.body, 0, 0, false)
    joint2:setMotorEnabled(true)
    joint2:setMotorSpeed(motorSpeed)
    joint2:setMaxMotorTorque(torque)


    joint3 = love.physics.newRevoluteJoint(obj2.body, obj4.body, obj4.body:getX(), obj4.body:getY(), false)
    --joint2 = love.physics.newRevoluteJoint(obj2.body, obj3.body, 0, 0, false)
    joint3:setMotorEnabled(true)
    joint3:setMotorSpeed(motorSpeed)
    joint3:setMaxMotorTorque(torque)
end

function drawThing(thing)
    --local cx, cy = thing.body:getWorldCenter()
    --local d = thing.fixture:getDensity()
    local t = thing.body:getType()

    local shape = thing.shape
    local body = thing.body

    if t == 'kinematic' then
        love.graphics.setColor(colors.peach)
    elseif (t == 'dynamic') then
        love.graphics.setColor(colors.blue)
    elseif (t == 'static') then
        love.graphics.setColor(colors.green)
    end
    local r, g, b = love.graphics.getColor()
    love.graphics.setColor(r, g, b, 0.5)

    if (shape:getType() == 'polygon') then
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
        love.graphics.setColor(colors.black)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    end

    if (shape:getType() == 'circle') then
        love.graphics.setColor(colors.orange)
        local r, g, b = love.graphics.getColor()
        love.graphics.setColor(r, g, b, 0.5)
        love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
        love.graphics.setColor(colors.black)

        love.graphics.setLineWidth(3)
        love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
    end

    if shape:getType() == 'chain' then
        love.graphics.setColor(colors.black)

        local points = { body:getWorldPoints(shape:getPoints()) }
        for i = 1, #points, 2 do
            if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
        end
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(0.15, 0.15) -- reduce everything by 50% in both X and Y coordinates




    for i = 1, #objects do
        drawThing(objects[i])
    end

    love.graphics.pop()

    love.graphics.print(motorSpeed, 0, 0)
end

function love.update(dt)
    world:update(dt)
end
