-- Minimal physics test for love.js
local world
local bodies = {}
local ground

function love.load()
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)

    -- Ground
    ground = {}
    ground.body = love.physics.newBody(world, 400, 550, "static")
    ground.shape = love.physics.newRectangleShape(700, 30)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
    ground.fixture:setRestitution(0.3)

    -- A few shapes to tumble
    for i = 1, 5 do
        local b = {}
        b.body = love.physics.newBody(world, 200 + i * 80, 100 + i * 30, "dynamic")
        if i % 2 == 0 then
            b.shape = love.physics.newCircleShape(20 + i * 5)
            b.type = "circle"
        else
            b.shape = love.physics.newRectangleShape(30 + i * 5, 30 + i * 5)
            b.type = "rect"
        end
        b.fixture = love.physics.newFixture(b.body, b.shape, 1)
        b.fixture:setRestitution(0.5)
        b.color = { 0.2 + i * 0.15, 0.3, 0.8 - i * 0.1 }
        table.insert(bodies, b)
    end
end

function love.update(dt)
    world:update(dt)
end

function love.draw()
    love.graphics.clear(245/255, 245/255, 220/255)

    -- Ground
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.polygon("fill", ground.body:getWorldPoints(ground.shape:getPoints()))

    -- Bodies
    for _, b in ipairs(bodies) do
        love.graphics.setColor(b.color)
        if b.type == "circle" then
            local x, y = b.body:getPosition()
            love.graphics.circle("fill", x, y, b.shape:getRadius())
        else
            love.graphics.polygon("fill", b.body:getWorldPoints(b.shape:getPoints()))
        end
    end

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print("Click/tap to add shapes!", 10, 10)
    love.graphics.print("Bodies: " .. #bodies, 10, 35)

    love.graphics.setColor(1, 1, 1)
end

function love.mousepressed(x, y)
    local b = {}
    b.body = love.physics.newBody(world, x, y, "dynamic")
    if math.random() > 0.5 then
        b.shape = love.physics.newCircleShape(math.random(15, 35))
        b.type = "circle"
    else
        b.shape = love.physics.newRectangleShape(math.random(20, 50), math.random(20, 50))
        b.type = "rect"
    end
    b.fixture = love.physics.newFixture(b.body, b.shape, 1)
    b.fixture:setRestitution(0.5)
    b.color = { math.random(), math.random(), math.random() }
    table.insert(bodies, b)
end

function love.touchpressed(_, x, y)
    love.mousepressed(x, y)
end
