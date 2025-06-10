-- Love2D prototype: 5-way emotional blend with relative phoneme overlay
-- Uses normalized [-1, 1] shape data, scaled by mouth bounds and phoneme settings
local inspect = require 'inspect'
local mathutils = require 'math-utils'

function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function makeTrianglesFromPolygon(polygon)
    -- when this is true we also solve, self intersecting and everythign
    local triangles = {}
    local result = {}
    local success, err = pcall(function()
        mathutils.decompose(polygon, result)
    end)

    if not success then
        --logger:error("Error in decompose_complex_poly: " .. err)
        return nil -- Exit early if decomposition fails
    end

    for i = 1, #result do
        local success, tris = pcall(love.math.triangulate, result[i])
        if success then
            tableConcat(triangles, tris)
        else
            --logger:error("Failed to triangulate part of the polygon: " .. tris)
        end
    end
    return triangles
end

function love.load()
    numPoints = 8

    -- Shapes now defined with normalized coordinates (-1 to 1)
    shapesOpen = {
        neutral = {
            { x = -1.0, y = 0.0 }, { x = -0.5, y = -0.25 }, { x = 0.0, y = -0.5 }, { x = 0.5, y = -0.25 }, { x = 1.0, y = 0.0 },
            { x = 0.5,  y = 0.25 }, { x = 0.0, y = 0.5 }, { x = -0.5, y = 0.25 },
        },
        sad = {
            { x = -1.0, y = 0.5 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = 0.1 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.5 },
            { x = 0.75, y = 0.5 }, { x = 0.0, y = 0.3 }, { x = -0.75, y = 0.5 },
        },
        happy = {
            { x = -1.0, y = -0.5 }, { x = -0.5, y = -0.3 }, { x = 0.0, y = -0.3 }, { x = 0.5, y = -0.3 }, { x = 1.0, y = -0.5 },
            { x = 0.75, y = 0.6 }, { x = 0.0, y = 0.8 }, { x = -0.75, y = 0.6 },
        },
        angry = {
            { x = -1.0, y = 0.0 }, { x = -0.75, y = -0.3 }, { x = 0.0, y = -0.3 }, { x = 0.75, y = -0.3 }, { x = 1.0, y = 0.0 },
            { x = 0.75, y = 0.7 }, { x = 0.0, y = 0.8 }, { x = -0.75, y = 0.7 },
        },
        surprised = {
            { x = -1.0, y = 0.0 }, { x = -0.75, y = -0.2 }, { x = 0.0, y = -0.6 }, { x = 0.75, y = -0.2 }, { x = 1.0, y = 0.0 },
            { x = 0.75, y = 0.25 }, { x = 0.0, y = 0.5 }, { x = -0.75, y = 0.25 },
        },
    }

    shapesClosed = {
        neutral = {
            { x = -0.7, y = 0.0 }, { x = -0.5, y = -0 }, { x = 0.0, y = -0 }, { x = 0.5, y = -0 }, { x = 0.7, y = 0.0 },
            { x = 0.5,  y = 0 }, { x = 0.0, y = 0 }, { x = -0.5, y = 0 },
        },
        sad = {
            { x = -1.0, y = 0.25 }, { x = -0.5, y = -0 }, { x = 0.0, y = -0.05 }, { x = 0.5, y = -0 }, { x = 1.0, y = 0.25 },
            { x = 0.5,  y = 0 }, { x = 0.0, y = 0.05 }, { x = -0.5, y = 0 },
        },
        happy = {
            { x = -1.0, y = -0.3 }, { x = -0.5, y = -0 }, { x = 0.0, y = -0 }, { x = 0.5, y = -0 }, { x = 1.0, y = -0.3 },
            { x = 0.5,  y = -0 }, { x = 0.0, y = -0 }, { x = -0.5, y = -0 },
        },
        angry = {
            { x = -1.0, y = 0.0 }, { x = -0.75, y = -0.2 }, { x = 0.0, y = -0.3 }, { x = 0.75, y = -0.2 }, { x = 1.0, y = 0.0 },
            { x = 0.75, y = -0.2 }, { x = 0.0, y = -0.3 }, { x = -0.75, y = -0.2 },
        },
        surprised = {
            { x = -1.0, y = -0.2 }, { x = -0.75, y = -0 }, { x = 0.0, y = 0 }, { x = 0.75, y = -0 }, { x = 1.0, y = -0.2 },
            { x = 0.75, y = 0 }, { x = 0.0, y = 0 }, { x = -0.75, y = 0 },
        },
    }

    emotionDot = { x = 0.5, y = 0.5 }

    mouthBounds = {
        width = 80,
        height = 280
    }

    teethParams = {
        width = 0.5,    -- percentage of mouthBounds.width
        height = 0.08,  -- percentage of mouthBounds.height
        yOffset = -0.05 -- offset factor to pull toward lips
    }

    tongueParams = {
        width = 0.35,         -- percentage of mouthBounds.width
        height = 0.06,        -- percentage of mouthBounds.height
        baseOffset = 0.06,    -- from point 7
        stickOutOffset = 0.10 -- extra for TH and L
    }

    mouthShapesOLD = {
        ['A_I'] = { width = 1.2, jawDrop = 0.8 },
        ['OU_W_Q'] = { width = 0.4, jawDrop = 0.2 },
        ['CDEGK_NRS'] = { width = 1.0, jawDrop = 0.3 },
        ['TH_L'] = { width = 0.8, jawDrop = 0.4 },
        ['F_V'] = { width = 1.0, jawDrop = 0.1 },
        ['L_OU'] = { width = 0.5, jawDrop = 0.6 },
        ['O_U_AGH'] = { width = 0.7, jawDrop = 0.7 },
        ['UGH'] = { width = 1.1, jawDrop = 0.7 },
        ['M_B_P'] = { width = 0.9, jawDrop = 0.1 },
        ['MMM'] = { width = 0.8, jawDrop = 0 },
        ['CLOSED'] = { width = 1.0, jawDrop = 0 },
    }

    mouthShapes = {
        ['A_I'] = {
            width = 1.2,
            height = 0.8,
            topTeeth = true,
            bottomTeeth = true,
            tongue = false
        },
        ['OU_W_Q'] = {
            width = 0.4,
            height = 0.4,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
        ['CDEGK_NRS'] = {
            width = 1.0,
            height = 0.4,
            topTeeth = true,
            bottomTeeth = false,
            tongue = false
        },
        ['TH_L'] = {
            width = 0.8,
            height = 0.5,
            topTeeth = true,
            bottomTeeth = false,
            tongue = true
        },
        ['F_V'] = {
            width = 1.0,
            height = 0.3,
            topTeeth = true,
            bottomTeeth = false,
            tongue = false
        },
        ['L_OU'] = {
            width = 0.5,
            height = 0.6,
            topTeeth = true,
            bottomTeeth = false,
            tongue = true
        },
        ['O_U_AGH'] = {
            width = 0.7,
            height = 0.7,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
        ['UGH'] = {
            width = 1.1,
            height = 0.7,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
        ['M_B_P'] = {
            width = 0.9,
            height = 0.15,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
        ['MMM'] = {
            width = 0.9,
            height = 0.1,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
        ['CLOSED'] = {
            width = 1.0,
            height = 0.05,
            topTeeth = false,
            bottomTeeth = false,
            tongue = false
        },
    }


    phonemeKeys = { 'CLOSED', 'A_I', 'OU_W_Q', 'CDEGK_NRS', 'TH_L', 'F_V', 'L_OU', 'O_U_AGH', 'UGH', 'M_B_P', 'MMM' }
    currentPhoneme = mouthShapes['CLOSED']
    currentKey = 'CLOSED'
end

function lerpShape(a, b, t)
    local out = {}
    for i = 1, #a do
        local ax, ay = a[i].x, a[i].y
        local bx, by = b[i].x, b[i].y
        table.insert(out, {
            x = ax + (bx - ax) * t,
            y = ay + (by - ay) * t
        })
    end
    return out
end

function blend5(shapes, x, y)
    if math.abs(x - 0.5) < 0.001 and math.abs(y - 0.5) < 0.001 then
        return shapes.neutral
    end

    local tl, tr, bl, br, center = nil, nil, nil, nil, shapes.neutral
    local newX, newY

    if x < 0.5 and y < 0.5 then
        tl = shapes.sad
        tr = lerpShape(shapes.sad, shapes.happy, 0.5)
        bl = lerpShape(shapes.sad, shapes.angry, 0.5)
        br = center
        newX = x * 2
        newY = y * 2
    elseif x >= 0.5 and y < 0.5 then
        tl = lerpShape(shapes.sad, shapes.happy, 0.5)
        tr = shapes.happy
        bl = center
        br = lerpShape(shapes.happy, shapes.surprised, 0.5)
        newX = (x - 0.5) * 2
        newY = y * 2
    elseif x < 0.5 and y >= 0.5 then
        tl = lerpShape(shapes.sad, shapes.angry, 0.5)
        tr = center
        bl = shapes.angry
        br = lerpShape(shapes.angry, shapes.surprised, 0.5)
        newX = x * 2
        newY = (y - 0.5) * 2
    else
        tl = center
        tr = lerpShape(shapes.happy, shapes.surprised, 0.5)
        bl = lerpShape(shapes.angry, shapes.surprised, 0.5)
        br = shapes.surprised
        newX = (x - 0.5) * 2
        newY = (y - 0.5) * 2
    end

    local top = lerpShape(tl, tr, newX)
    local bot = lerpShape(bl, br, newX)
    return lerpShape(top, bot, newY)
end

function applyPhoneme(shape, phoneme, closed)
    if not phoneme then return shape end
    local width = phoneme.width or 1.0
    local jaw = phoneme.height or 0.0
    local result = {}

    for i, pt in ipairs(shape) do
        table.insert(result, {
            x = pt.x * mouthBounds.width * width,
            y = pt.y * mouthBounds.height * (closed and 1 or jaw)
        })
    end

    return result
end

function love.update(dt)
    local speed = 0.5
    if love.keyboard.isDown("left") then emotionDot.x = math.max(0, emotionDot.x - dt * speed) end
    if love.keyboard.isDown("right") then emotionDot.x = math.min(1, emotionDot.x + dt * speed) end
    if love.keyboard.isDown("up") then emotionDot.y = math.max(0, emotionDot.y - dt * speed) end
    if love.keyboard.isDown("down") then emotionDot.y = math.min(1, emotionDot.y + dt * speed) end

    if love.mouse.isDown(1) then
        local x, y = love.mouse.getPosition()
        if x > 50 and y > 50 and x < 250 and y < 250 then
            local nx = (x - 50) / 200
            local ny = (y - 50) / 200

            emotionDot.x = nx
            emotionDot.y = ny
        end
    end
end

function love.keypressed(key)
    local idx = tonumber(key)
    if idx and idx >= 1 and idx <= #phonemeKeys then
        currentPhoneme = mouthShapes[phonemeKeys[idx]]
        currentKey = phonemeKeys[idx]
    end
    if (key == '0') then
        currentPhoneme = mouthShapes[phonemeKeys[10]]
        currentKey = phonemeKeys[10]
    end
    if (key == '-') then
        currentPhoneme = mouthShapes[phonemeKeys[11]]
        currentKey = phonemeKeys[11]
    end
    if (key == 'escape') then love.event.quit() end
    --print(currentPhoneme)
end

function drawTopTeeth(s)
    local a, b, c = s[2], s[3], s[4]
    local tx = (a.x + b.x + c.x) / 3
    local ty = (a.y + b.y + c.y) / 3 - mouthBounds.height * teethParams.yOffset

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle(
        "fill",
        tx - (mouthBounds.width * teethParams.width * 0.5),
        ty - (mouthBounds.height * teethParams.height * 0.5),
        mouthBounds.width * teethParams.width,
        mouthBounds.height * teethParams.height,
        4, 4
    )
end

function drawBottomTeeth(s)
    local a, b, c = s[8], s[7], s[6]
    local tx = (a.x + b.x + c.x) / 3
    local ty = (a.y + b.y + c.y) / 3 + mouthBounds.height * teethParams.yOffset

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle(
        "fill",
        tx - (mouthBounds.width * teethParams.width * 0.5),
        ty - (mouthBounds.height * teethParams.height * 0.5),
        mouthBounds.width * teethParams.width,
        mouthBounds.height * teethParams.height,
        4, 4
    )
end

function drawTongue(s, currentKey)
    local t = s[7]
    local out = tongueParams.baseOffset

    if currentKey == "TH_L" or currentKey == "L_OU" then
        out = out + tongueParams.stickOutOffset
    end

    love.graphics.setColor(1, 0.3, 0.4)
    love.graphics.ellipse(
        "fill",
        t.x,
        t.y + mouthBounds.height * out,
        mouthBounds.width * tongueParams.width * 0.5,
        mouthBounds.height * tongueParams.height * 0.5
    )
end

function drawMouthFill(vertices)
    local cx, cy = 0, 0
    for i = 1, #vertices, 2 do
        cx = cx + vertices[i]
        cy = cy + vertices[i + 1]
    end
    cx = cx / (#vertices / 2)
    cy = cy / (#vertices / 2)

    local fan = { cx, cy }
    for i = 1, #vertices, 2 do
        table.insert(fan, vertices[i])
        table.insert(fan, vertices[i + 1])
    end
    -- close the loop
    table.insert(fan, vertices[1])
    table.insert(fan, vertices[2])

    love.graphics.polygon("fill", fan)
end

local function printPoly(name, poly)
    print("Polygon: " .. name)
    for i = 1, #poly, 2 do
        print(string.format("  [%d] = (%.2f, %.2f)", i, poly[i], poly[i + 1]))
    end
end

-- not in use currenlty
local function splitPolygonAtIndices(poly, i1, i2)
    print('xxxxx')
    local wrap = {}
    local backPoly = {}
    local function normalize(i)
        return ((i - 1) % #poly) + 1
    end

    local smallest = math.min(i1, i2)
    local biggest = math.max(i1, i2)

    -- Wrap: forward from biggest to smallest (looping)
    print('wrap')
    local i = biggest
    print(i)
    repeat
        i = normalize(i + 2)
        print(i)
        table.insert(wrap, poly[i])
        table.insert(wrap, poly[i + 1])
    until i == smallest

    -- Back: backward from biggest to smallest (looping)
    print('back')
    i = biggest
    print(i)
    repeat
        table.insert(backPoly, poly[i])
        table.insert(backPoly, poly[i + 1])
        i = normalize(i - 2)
        print(i)
    until i == smallest

    return wrap, backPoly
end

function love.draw()
    if currentKey then
        love.graphics.print(currentKey)
    end
    love.graphics.push()
    love.graphics.translate(400, 300)
    love.graphics.setColor(1, 1, 1)

    local closed = (currentKey == 'CLOSED')
    local shapes = closed and shapesClosed or shapesOpen

    local emotionShape = blend5(shapes, emotionDot.x, emotionDot.y)
    local s = applyPhoneme(emotionShape, currentPhoneme, closed)



    -- for i = 1, numPoints do
    --     local a = s[i]
    --     local b = s[(i % numPoints) + 1]
    --     love.graphics.line(a.x, a.y, b.x, b.y)
    -- end

    -- for _, p in ipairs(s) do
    --     love.graphics.circle("fill", p.x, p.y, 3)
    -- end


    local verticesOLD = { s[1].x, s[1].y, s[2].x, s[2].y, s[3].x, s[3].y, s[4].x, s[4].y, s[5].x, s[5].y, s[6].x, s[6].y,
        s[7].x, s[7].y, s[8].x, s[8].y }

    local up = { s[1].x, s[1].y, s[2].x, s[2].y, s[2].x, s[2].y, s[3].x, s[3].y, s[3].x, s[3].y, s[4].x, s[4].y, s[4].x,
        s[4].y, s[5].x, s[5].y }
    local down = { s[5].x, s[5].y, s[6].x, s[6].y, s[6].x, s[6].y, s[7].x, s[7].y, s[7].x, s[7].y, s[8].x, s[8].y, s[8]
        .x, s[8].y, s[1].x, s[1].y }
    love.graphics.setLineWidth(1)

    local upCurve = love.math.newBezierCurve(up)
    local downCurve = love.math.newBezierCurve(down)
    local upPoints = upCurve:render(1)
    local downPoints = downCurve:render(1)

    for i = 1, #downPoints, 2 do
        table.insert(upPoints, downPoints[i])
        table.insert(upPoints, downPoints[i + 1])
    end

    local function removeConsecutiveDuplicates(poly, epsilon)
        epsilon = epsilon or 1
        local result = {}

        local function isClose(a, b)
            return math.abs(a - b) < epsilon
        end

        local prevX, prevY = nil, nil
        for i = 1, #poly - 1, 2 do
            local x, y = poly[i], poly[i + 1]
            if not (prevX and isClose(x, prevX) and isClose(y, prevY)) then
                table.insert(result, x)
                table.insert(result, y)
                prevX, prevY = x, y
            end
        end

        return result
    end
    local vertices = removeConsecutiveDuplicates(upPoints) -- important !!!!


    --print(inspect(vertices))

    local tris = makeTrianglesFromPolygon(vertices)
    local i1 = math.floor(#vertices * 0.25)
    local i2 = math.floor(#vertices * 0.75)
    print('vertices, tris', #vertices, #tris)

    local stencilFunction = function()
        for i = 1, #tris do
            love.graphics.polygon("fill", tris[i])
        end
        -- drawMouthFill(vertices)
        --love.graphics.polygon("fill", leftPoly)
        --love.graphics.polygon("fill", rightPoly)
    end


    if not closed then
        love.graphics.stencil(stencilFunction, "replace", 1)
        love.graphics.setStencilTest("equal", 1)
        love.graphics.setColor(.5, 0, 0, 0.8)
        for i = 1, #tris do
            love.graphics.polygon("fill", tris[i])
        end
    end



    if currentPhoneme then
        --drawTopTeeth(s)
        if currentPhoneme.topTeeth then drawTopTeeth(s) end
        ---if currentPhoneme.bottomTeeth then drawBottomTeeth(s) end
        --if currentPhoneme.tongue then drawTongue(s, currentKey) end
    end
    if not closed then
        love.graphics.setStencilTest()
    end
    love.graphics.setColor(1, 0, 0)
    love.graphics.setLineWidth(5)

    love.graphics.line(upCurve:render())
    love.graphics.line(downCurve:render())
    love.graphics.pop()
    love.graphics.setLineWidth(5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 50, 50, 200, 200)
    love.graphics.circle("fill", 50 + emotionDot.x * 200, 50 + emotionDot.y * 200, 4)
    love.graphics.print("Use arrow keys to move the emotion dot", 50, 270)
    love.graphics.print("Press 1-9 to select phoneme", 50, 290)
end
