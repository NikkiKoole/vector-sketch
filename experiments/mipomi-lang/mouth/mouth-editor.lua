local lib = {}
local inspect = require 'inspect'
local aardman = love.graphics.newImage('assets/aardman.jpg')
--local shapes = require('mouth-shapes')
local mouthRenderer = require 'mouth'

local draggingShape, draggingIndex = nil, nil
local offsetX, offsetY = 0, 0

function getBoundingBoxCenter(points)
    if #points < 2 then return 0, 0 end
    local minX, minY = points[1], points[2]
    local maxX, maxY = points[1], points[2]
    for i = 3, #points, 2 do
        local x, y = points[i], points[i + 1]
        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
    end
    return (minX + maxX) / 2, (minY + maxY) / 2
end

local function getMidpoint(points)
    -- local mid = #points / 4 -- halfway into the top lip (2 control points)
    local sumX, sumY = 0, 0
    local count = 0
    for i = 1, #points, 2 do
        sumX = sumX + points[i]
        sumY = sumY + points[i + 1]
        count = count + 1
    end
    return sumX / count, sumY / count
end

function lib.drawEditableOverlay()
    for i, shape in ipairs(mouthRenderer.shapes.raw) do
        local s = shape.points

        for j = 1, #s, 2 do
            local x1, y1 = s[j], s[j + 1]
            local next = ((j + 2) > #s) and 1 or j + 2
            local x2, y2 = s[next], s[next + 1]
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.line(x1, y1, x2, y2)
        end

        for j = 1, #s, 2 do
            love.graphics.setColor(1, 0.5, 0.2)
            love.graphics.circle("fill", s[j], s[j + 1], 6)
            love.graphics.setColor(1, 1, 1)
            --love.graphics.print(math.ceil(j / 2), s[j] + 8, s[j + 1] - 8)
        end

        local up = { s[1], s[2], s[3], s[4], s[3], s[4], s[5], s[6], s[5], s[6], s[7], s[8], s[7], s[8], s[9], s[10] }
        local down = { s[9], s[10], s[11], s[12], s[11], s[12], s[13], s[14], s[13], s[14], s[15], s[16], s[15], s[16], s
            [1], s[2] }
        local upCurve = love.math.newBezierCurve(up)
        local downCurve = love.math.newBezierCurve(down)
        love.graphics.setColor(1, 0, 0)
        love.graphics.setLineWidth(5)
        ---  love.graphics.line(upCurve:render())
        --  love.graphics.line(downCurve:render())

        if shape.data and shape.data.upperteeth then
            love.graphics.setColor(1, 1, 1)
            local umx, umy = getMidpoint(up)
            --        love.graphics.rectangle('fill', umx - 25, umy, 50, 10)
        end
        local cx, cy = getBoundingBoxCenter(s)
        love.graphics.setColor(1, 1, 0)
        --love.graphics.print(i, cx, cy)
    end
end

function lib.drawTexturedMouthsOverlay()
    for i, shape in ipairs(shapes.raw) do
        mouthRenderer.drawShape(shape, 1, 1)
    end
end

function lib.draw()
    love.graphics.setColor(1, 1, 1)
    -- love.graphics.draw(aardman, 0, 0, 0, 2, 2)
    --lib.drawTexturedMouthsOverlay()
    lib.drawEditableOverlay()
end

function createShape(x, y, radius, count)
    local shape = { points = {} }
    for i = 1, count do
        local angle = (i - 1) / count * 2 * math.pi + math.pi
        local px = x + radius * math.cos(angle)
        local py = y + radius * math.sin(angle)
        table.insert(shape.points, px)
        table.insert(shape.points, py)
    end
    return shape
end

function lib.mousepressed(x, y, button)
    -- start dragging
    if button == 1 then
        for i, shape in ipairs(mouthRenderer.shapes.raw) do
            for j = 1, #shape.points, 2 do
                local px, py = shape.points[j], shape.points[j + 1]
                local dx, dy = x - px, y - py
                if dx * dx + dy * dy <= 64 then
                    draggingShape = shape
                    draggingIndex = j
                    offsetX = dx
                    offsetY = dy
                    print(i)
                    return
                end
            end
        end
    elseif button == 2 then
        table.insert(mouthRenderer.shapes, createShape(x, y, 30, 8))
    end
end

function lib.mousereleased(x, y, button)
    -- stop dragging
    if button == 1 then
        if draggingShape then
            for i = 1, #draggingShape.points do
                draggingShape.points[i] = math.floor(draggingShape.points[i] + .5)
            end
            print(inspect(draggingShape))
        end
        draggingShape, draggingIndex = nil, nil
    end
end

function lib.mousemoved(x, y)
    -- move dragged point
    -- print(draggingShape, draggingIndex)
    if draggingShape and draggingIndex then
        draggingShape.points[draggingIndex] = x - offsetX
        draggingShape.points[draggingIndex + 1] = y - offsetY
        --print('hello?')
    end
end

return lib
