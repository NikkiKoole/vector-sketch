-- Love2D prototype: 5-way emotional blend with relative phoneme overlay
-- Uses normalized [-1, 1] shape data, scaled by mouth bounds and phoneme settings

function love.load()
    numPoints = 8

    -- Shapes now defined with normalized coordinates (-1 to 1)
    shapes = {
        neutral = {
            { x = -1.0, y = -0.0 }, { x = -0.5, y = -0.1 }, { x = 0.0, y = -0.1 }, { x = 0.5, y = -0.1 }, { x = 1.0, y = 0.0 },
            { x = 0.75, y = 0.2 }, { x = 0.0, y = 0.2 }, { x = -0.75, y = 0.2 },
        },
        sad = {
            { x = -1.0, y = 0.2 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = 0.1 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.2 },
            { x = 0.75, y = 0.5 }, { x = 0.0, y = 0.6 }, { x = -0.75, y = 0.5 },
        },
        happy = {
            { x = -1.0, y = 0.2 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = -0.4 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.2 },
            { x = 0.75, y = 0.6 }, { x = 0.0, y = 0.8 }, { x = -0.75, y = 0.6 },
        },
        surprised = {
            { x = -1.0, y = 0.2 }, { x = -0.5, y = -0.1 }, { x = 0.0, y = -0.3 }, { x = 0.5, y = -0.1 }, { x = 1.0, y = 0.2 },
            { x = 0.5,  y = 0.7 }, { x = 0.0, y = 0.8 }, { x = -0.5, y = 0.7 },
        },
        angry = {
            { x = -1.0, y = 0.2 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = -0.3 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.2 },
            { x = 0.75, y = 0.5 }, { x = 0.0, y = 0.7 }, { x = -0.75, y = 0.5 },
        },
    }

    emotionDot = { x = 0.5, y = 0.5 }

    mouthBounds = {
        width = 80,
        height = 80
    }

    mouthShapes = {
        ['A_I'] = { width = 1.2, jawDrop = 0.8 },
        ['OU_W_Q'] = { width = 0.4, jawDrop = 0.2 },
        ['CDEGK_NRS'] = { width = 1.0, jawDrop = 0.3 },
        ['TH_L'] = { width = 0.8, jawDrop = 0.4 },
        ['F_V'] = { width = 1.0, jawDrop = 0.1 },
        ['L_OU'] = { width = 0.5, jawDrop = 0.6 },
        ['O_U_AGH'] = { width = 0.7, jawDrop = 0.7 },
        ['UGH'] = { width = 1.1, jawDrop = 0.7 },
        ['M_B_P'] = { width = 0.9, jawDrop = 0.0 },
        ['MMM'] = { width = 0.9, jawDrop = 0.0 },
        ['CLOSED'] = { width = 1.0, jawDrop = 0.1 },
    }

    phonemeKeys = { 'CLOSED', 'A_I', 'OU_W_Q', 'CDEGK_NRS', 'TH_L', 'F_V', 'L_OU', 'O_U_AGH', 'UGH', 'M_B_P', 'MMM',
        'CLOSED' }
    currentPhoneme = nil
    currentKey = nil
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

function applyPhoneme(shape, phoneme)
    if not phoneme then return shape end
    local width = phoneme.width or 1.0
    local jaw = phoneme.jawDrop or 0.0
    local result = {}

    for i, pt in ipairs(shape) do
        table.insert(result, {
            x = pt.x * mouthBounds.width * width,
            y = pt.y * mouthBounds.height * jaw
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
end

function love.draw()
    if currentKey then
        love.graphics.print(currentKey)
    end
    love.graphics.push()
    love.graphics.translate(400, 300)
    love.graphics.setColor(1, 1, 1)

    local emotionShape = blend5(shapes, emotionDot.x, emotionDot.y)
    local s = applyPhoneme(emotionShape, currentPhoneme)


    local up = { s[1].x, s[1].y, s[2].x, s[2].y, s[2].x, s[2].y, s[3].x, s[3].y, s[3].x, s[3].y, s[4].x, s[4].y, s[4].x,
        s[4].y, s[5].x, s[5].y }
    local down = { s[5].x, s[5].y, s[6].x, s[6].y, s[6].x, s[6].y, s[7].x, s[7].y, s[7].x, s[7].y, s[8].x, s[8].y, s[8]
        .x, s[8].y, s[1].x, s[1].y }
    love.graphics.setLineWidth(1)
    for i = 1, numPoints do
        local a = s[i]
        local b = s[(i % numPoints) + 1]
        love.graphics.line(a.x, a.y, b.x, b.y)
    end

    for _, p in ipairs(s) do
        love.graphics.circle("fill", p.x, p.y, 3)
    end
    love.graphics.setColor(1, 0, 0)
    love.graphics.setLineWidth(5)
    love.graphics.line(love.math.newBezierCurve(up):render())
    love.graphics.line(love.math.newBezierCurve(down):render())
    love.graphics.pop()
    love.graphics.setLineWidth(5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 50, 50, 200, 200)
    love.graphics.circle("fill", 50 + emotionDot.x * 200, 50 + emotionDot.y * 200, 4)
    love.graphics.print("Use arrow keys to move the emotion dot", 50, 270)
    love.graphics.print("Press 1-9 to select phoneme", 50, 290)
end
