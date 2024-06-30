function makeBall(x, y, radius)
    local ball = {}
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.shape = love.physics.newCircleShape(radius)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, .1)
    ball.fixture:setRestitution(.2) -- let the ball bounce

    ball.fixture:setFriction(.5)
    ball.body:setAngularVelocity(10000)
    return ball
end

function makeCarousell(x, y, width, height, angularVelocity)
    local carousel = {}
    carousel.body = love.physics.newBody(world, x, y, "kinematic")
    carousel.shape = love.physics.newRectangleShape(width, height)
    carousel.fixture = love.physics.newFixture(carousel.body, carousel.shape, 1)
    carousel.body:setAngularVelocity(angularVelocity)

    return carousel
end

function makeSlide(x, y, w, h)
    -- this thing has 2 poles it stands on.
    -- and the slide surface

    function makePole(x, y, w, h)
        local pole = {}
        pole.body = love.physics.newBody(world, x, y, "static")
        pole.shape = makeRectPoly2(w, h, 0, -h / 2)
        pole.fixture = love.physics.newFixture(pole.body, pole.shape, 10)
        pole.fixture:setSensor(true)
        return pole
    end

    local x1 = x - w / 2
    local y1 = getYAtX(x1, stepSize)
    local y1Top = y1 - h
    local p1 = makePole(x1, y1, w / 25, h)

    local x2 = x + w / 2
    local y2 = getYAtX(x2, stepSize)
    local y2Top = y2 - h / 5
    local p2 = makePole(x2, y2, w / 25, h / 5)

    -- now describe a curve in a few steps
    local xb = numbers.lerp(x1, x2, 0.5)
    local yb = numbers.lerp(y1Top, y2Top, 0.75)
    local xb2 = numbers.lerp(x1, x2, 0.75)
    local yb2 = numbers.lerp(y1Top, y2Top, 0.95)
    local xover = numbers.lerp(x1, x2, 1.1)
    local yover = numbers.lerp(y1Top, y2Top, 0.995)
    local curve = love.math.newBezierCurve({ x1, y1Top, xb, yb, xb2, yb2, x2, y2Top, xover, yover })

    local points = {}
    for i = 0, 10, 1 do
        local t = i / 10
        local px, py = curve:evaluate(t)
        table.insert(points, px)
        table.insert(points, py)
    end

    local slide = {}
    slide.body = love.physics.newBody(world, 0, 0, "static")
    slide.shape = love.physics.newChainShape(false, points)
    slide.fixture = love.physics.newFixture(slide.body, slide.shape, 1)
    -- ground.shape = love.physics.newChainShape(false, points)
    -- ground.fixture = love.physics.newFixture(ground.body, ground.shape)
end

function makeCow(x, y, bodyWidth, bodyHeight)
    local cow = {}
    cow.torso = {}
    cow.torso.body = love.physics.newBody(world, x, y, "dynamic")
    cow.torso.shape = love.physics.newRectangleShape(bodyWidth, bodyHeight)
    cow.torso.fixture = love.physics.newFixture(cow.torso.body, cow.torso.shape, 10)

    function makeLeg(x, y, w, h, j)
        local leg = {}
        leg.body = love.physics.newBody(world, x, y, "static")
        leg.shape = makeRectPoly2(w, h, 0, h / 2)
        leg.fixture = love.physics.newFixture(leg.body, leg.shape, 10)
        leg.fixture:setSensor(true)
        if j then
            local joint = love.physics.newRevoluteJoint(cow.torso.body, leg.body, x, y, false)
            joint:setLowerLimit(-math.pi / 32)
            joint:setUpperLimit(math.pi / 32)
            joint:setLimitsEnabled(true)
        end
        return leg
    end

    local legW = bodyWidth / 10
    local legH = bodyHeight

    local l1 = makeLeg(x - bodyWidth / 3, y + bodyHeight / 2, legW, legH, true)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x - bodyWidth / 5, y + bodyHeight / 2, legW, legH, false)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x + bodyWidth / 5, y + bodyHeight / 2, legW, legH, false)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
    local l1 = makeLeg(x + bodyWidth / 3, y + bodyHeight / 2, legW, legH, true)
    l1.body:setPosition(l1.body:getX(), getYAtX(l1.body:getX(), stepSize) - legH)
end

function makeChain(x, y, amt)
    --https://mentalgrain.com/box2d/creating-a-chain-with-box2d/
    local linkHeight = 20 * 10
    local linkWidth = 50 * 10
    local dir = 1
    -- local amt = 3
    local count = 1

    function makeLink(x, y)
        local body = love.physics.newBody(world, x, y, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth + count * 5, linkHeight)
        local fixture = love.physics.newFixture(body, shape, .3)
        count = count + 1
        return body
    end

    local lastLink = makeLink(x, y)
    for i = 1, amt do
        local link = makeLink(x, y + (i * linkHeight) * dir)
        local joint = love.physics.newRevoluteJoint(lastLink, link, link:getX(), link:getY(), true)

        joint:setLowerLimit(-math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)

        local dj = love.physics.newDistanceJoint(lastLink, link, lastLink:getX(), lastLink:getY(), link:getX(),
            link:getY())
        lastLink = link
    end

    if false then
        local weight = love.physics.newBody(world, x, y + ((amt + 1) * linkHeight) * dir, "dynamic")
        local shape = love.physics.newRectangleShape(linkWidth, linkHeight)
        local fixture = love.physics.newFixture(weight, shape, 1)


        local joint = love.physics.newRevoluteJoint(lastLink, weight, weight:getX(), weight:getY(), false)
        local dj = love.physics.newDistanceJoint(lastLink, weight, lastLink:getX(), lastLink:getY(), weight:getX(),
            weight:getY())
        joint:setLowerLimit(-math.pi / 32)
        joint:setUpperLimit(math.pi / 32)
        joint:setLimitsEnabled(true)
        table.insert(objects.blocks, weight)
    end
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
