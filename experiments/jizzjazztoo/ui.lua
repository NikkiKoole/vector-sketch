mouseState = {
    hoveredSomething = false,
    down = false,
    lastDown = false,
    click = false,
    offset = { x = 0, y = 0 },
    clickedSomething = false,
}
function distance(x, y, x1, y1)
    local dx = x - x1
    local dy = y - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist
end

function pointInRect(x, y, rx, ry, rw, rh)
    if x < rx or y < ry then return false end
    if x > rx + rw or y > ry + rh then return false end
    return true
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
    mouseState.clickedSomething = false
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
    -- print(mouseState.lastDown, mouseState.down)
    mouseState.lastDown = mouseState.down
    -- print(mouseState.released)
end

function getUIRect(x, y, w, h)
    local result = false

    local mx, my = love.mouse.getPosition()
    --print(x, y, w, h)
    if pointInRect(mx, my, x, y, w, h) then
        mouseState.hoveredSomething = true
    end
    --if (mouseState.released and mouseState.clickedSomething == false)
    if mouseState.clickedSomething == false and mouseState.click then
        if pointInRect(mx, my, x, y, w, h) then
            result = true
            mouseState.clickedSomething = true
        end
    end

    return result
end

function v_slider(id, x, y, height, v, min, max, special)
    local thumb_size = 16
    local easy_effect = true
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle('fill', x + 8, y, 3, height)
    love.graphics.setColor(0, 0, 0)
    local yOffset = mapInto(v, min, max, 0, height - thumb_size)
    love.graphics.rectangle('fill', x, yOffset + y, thumb_size, thumb_size)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(4)

    if not special then
        love.graphics.rectangle("line", x, yOffset + y, thumb_size, thumb_size)
    end
    if special and special == 'bottom' then
        love.graphics.arc("fill", x + thumb_size / 2, yOffset + y, thumb_size / 2, 0, math.pi)
    end
    if special and special == 'top' then
        love.graphics.arc("fill", x + thumb_size / 2, yOffset + y + thumb_size, thumb_size / 2, math.pi, math.pi * 2)
    end
    local result = nil
    local mx, my = love.mouse.getPosition()
    local hover = false
    if pointInRect(mx, my, x, (yOffset + y), thumb_size, thumb_size) then
        hover = true
    end
    local hoverTrack = false
    if pointInRect(mx, my, x, y, thumb_size, height) then
        hoverTrack = true
    end

    if hover then
        mouseState.hoveredSomething = true
        -- love.mouse.setCursor(cursors.hand)
        if mouseState.click then
            lastDraggedElement = { id = id }
            mouseState.hoveredSomething = true
            mouseState.offset = { x = x - mx, y = (yOffset + y) - my }
        end
    end

    if love.mouse.isDown(1) then
        if hoverTrack or (lastDraggedElement and lastDraggedElement.id == id) then
            mouseState.hoveredSomething = true
            -- love.mouse.setCursor(cursors.hand)

            local mx, my = love.mouse.getPosition()
            result = mapInto(my + mouseState.offset.y, y, y + height - thumb_size, min, max)
            if result < min then
                result = min
            else
                result = math.max(result, min)
                result = math.min(result, max)
            end
        end
    end
    love.graphics.setLineWidth(1)
    return {
        value = result
    }
end

function labelbutton(str, x, y, w, h, border)
    local mx, my = love.mouse:getPosition()
    local clicked = false
    local alpha = 0.1

    if (pointInRect(mx, my, x, y, w, h - 1)) then
        alpha = 0.5
        mouseState.hoveredSomething = true
        if (mouseState.released and mouseState.clickedSomething == false) then
            clicked = true
            mouseState.clickedSomething = true
        end
    end
    --print(str, alpha)

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, .8)
    if border then
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.setLineWidth(1)
    end
    local col = palette.fg2
    love.graphics.setColor(col[1], col[2], col[3], 0.8)
    love.graphics.print(str, x, y)
    --shadedText(str, x + margin, y)
    return {
        clicked = clicked
    }
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
    --love.graphics.line(x + ax, y + ay, x + bx, y + by)
    love.graphics.setColor(1, 1, 1, 1)

    a = mapInto(v, min, max, 0 + math.pi / 2, math.pi * 2 + math.pi / 2)
    ax, ay = angleAtDistance(x, y, a, cellHeight / 2)
    bx, by = angleAtDistance(x, y, a, cellHeight / 4)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.arc("fill", x, y, 16, math.pi / 2, a, 32)
    love.graphics.setColor(1, 1, 1, 1)
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
