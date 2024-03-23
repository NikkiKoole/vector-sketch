mouseState = {
    hoveredSomething = false,
    down = false,
    lastDown = false,
    click = false,
    offset = { x = 0, y = 0 }
}
function distance(x, y, x1, y1)
    local dx = x - x1
    local dy = y - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist
end

function pointInCircle(x, y, cx, cy, radius)
    if distance(x, y, cx, cy) < radius then
        return true
    else
        return false
    end
end

function angle(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.atan2(dx, dy)
end

function angleAtDistance(x, y, angle, distance)
    local px = math.cos(angle) * distance
    local py = math.sin(angle) * distance
    return px, py
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function mapInto(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function handleMouseClickStart()
    mouseState.hoveredSomething = false
    mouseState.down = love.mouse.isDown(1)
    mouseState.click = false
    mouseState.released = false
    if mouseState.down ~= mouseState.lastDown then
        if mouseState.down then
            mouseState.click = true
        else
            mouseState.released = true
        end
    end
    mouseState.lastDown = mouseState.down
end

function draw_knob(id, x, y, v, min, max)
    love.graphics.setLineWidth(4)
    local cellHeight = 32
    local result = nil
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(.1, .1, .1)
    love.graphics.circle("fill", x, y, cellHeight / 2, 100) -- Draw white circle with 100 segments.

    love.graphics.setColor(1, 1, 1)
    local mx, my = love.mouse.getPosition()

    a = -math.pi / 2
    ax, ay = angleAtDistance(x, y, -a, cellHeight / 2)
    bx, by = angleAtDistance(x, y, -a, cellHeight / 4)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.line(x + ax, y + ay, x + bx, y + by)
    love.graphics.setColor(1, 1, 1, 1)

    a = mapInto(v, min, max, 0 + math.pi / 2, math.pi * 2 + math.pi / 2)
    ax, ay = angleAtDistance(x, y, a, cellHeight / 2)
    bx, by = angleAtDistance(x, y, a, cellHeight / 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(x + ax, y + ay, x + bx, y + by)
    love.graphics.setColor(r, g, b, a)
    if mouseState.click then
        local mx, my = love.mouse.getPosition()
        -- click to start dragging
        if pointInCircle(mx, my, x, y, cellHeight / 2) then
            lastDraggedElement = { id = id, lastAngle = angle(mx, my, x, y), rolling = 0 }
        end
    end

    if love.mouse.isDown(1) then
        if lastDraggedElement and lastDraggedElement.id == id then
            local mx, my = love.mouse.getPosition()
            local a = angle(mx, my, x, y)

            result = mapInto(a, math.pi, -math.pi, min, max)
            --print('result within', result)
            local diff = (lastDraggedElement.lastAngle - a)

            if math.abs(diff) > math.pi or diff == 0 then
                if v > result then
                    result = max
                    -- print('result macing', result)
                elseif v < result then
                    -- print('result minnin', result)
                    result = min
                end
            else
                lastDraggedElement.lastAngle = a;
            end

            -- so it doesnt send similar data twice!
            if a ~= lastDraggedElement.rolling then
                lastDraggedElement.rolling = a
            else
                --result = nil
            end

            love.graphics.line(mx, my, x, y)
        end
    end
    --print(result)
    --print('sending', result)
    love.graphics.setLineWidth(1)
    return {

        value = result
    }
end
