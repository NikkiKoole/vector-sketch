-- things todo, there should mybe be an extra y offset that makes certain mouths hapes move more down (or up)
-- look at teeth.

local inspect = require 'inspect'
local mathutils = require 'math-utils'
local shapes = {}
local draggingShape, draggingIndex = nil, nil
local offsetX, offsetY = 0, 0
currentShape = nil
targetShape = nil
tweenTime = 0
tweenDuration = 0.3

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

function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

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

local function lerp(a, b, t)
    return a + (b - a) * t
end

function createTexturedTriangleStrip(image)
    local w, h = image:getDimensions()
    local vertices = {}
    local segments = 20
    local hPart = h / (segments - 1)
    local hv = 1 / (segments - 1)
    local runningHV, runningHP = 0, 0

    for i = 1, segments do
        table.insert(vertices, { w / 2, runningHP, 0, runningHV })
        table.insert(vertices, { -w / 2, runningHP, 1, runningHV })
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)
    return mesh
end

function texturedCurve(curve, image, mesh, dir, scaleW, offset)
    dir = dir or 1
    scaleW = scaleW or 1
    offset = offset or 0
    local dl = curve:getDerivative()
    local w = image:getWidth()
    local count = mesh:getVertexCount()

    for j = 1, count, 2 do
        local t = (j - 1) / (count - 2)
        local xl, yl = curve:evaluate(t)
        local dx, dy = dl:evaluate(t)
        local angle = math.atan2(dy, dx)
        local a = angle + math.pi / 2
        local a2 = angle - math.pi / 2
        local line = w * dir * scaleW

        local x2 = xl + line * math.cos(a)
        local y2 = yl + line * math.sin(a) + offset
        local x3 = xl + line * math.cos(a2)
        local y3 = yl + line * math.sin(a2) + offset

        local _, _, u1, v1 = mesh:getVertex(j)
        local _, _, u2, v2 = mesh:getVertex(j + 1)
        mesh:setVertex(j, { x2, y2, u1, v1 })
        mesh:setVertex(j + 1, { x3, y3, u2, v2 })
    end
end

function normalizeShapesByUpperLip(shapes)
    local function getLipCenters(points)
        local upX, upY, downX, downY = 0, 0, 0, 0
        local half = #points / 2

        for i = 1, half, 2 do
            upX = upX + points[i]
            upY = upY + points[i + 1]
        end
        for i = half + 1, #points, 2 do
            downX = downX + points[i]
            downY = downY + points[i + 1]
        end

        local count = half / 2
        return upX / count, upY / count, downX / count, downY / count
    end

    local normalized = {}

    for j, shape in ipairs(shapes) do
        local upX, upY, downX, downY = getLipCenters(shape.points)

        -- Define anchor as upper lip center (we freeze this) and shift all points relative to it
        local anchorX = upX
        local anchorY = upY

        local newShape = { points = {} }
        for i = 1, #shape.points, 2 do
            local x = shape.points[i] - anchorX
            local y = shape.points[i + 1] - anchorY

            table.insert(newShape.points, x)
            table.insert(newShape.points, y)
        end
        if shape.data then
            newShape.data = shallowCopy(shape.data)
        end
        table.insert(normalized, newShape)
    end

    return normalized
end

function normalizeShapesToCenter(shapes)
    local function getBBox(points)
        local minX, minY = points[1], points[2]
        local maxX, maxY = points[1], points[2]
        for i = 3, #points, 2 do
            local x, y = points[i], points[i + 1]
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
        end
        return minX, minY, maxX, maxY
    end

    -- Step 1: find largest bbox
    local maxW, maxH = 0, 0
    --local refCx, refCy = 0, 0

    for _, shape in ipairs(shapes) do
        local minX, minY, maxX, maxY = getBBox(shape.points)
        local w, h = maxX - minX, maxY - minY
        if w * h > maxW * maxH then
            maxW, maxH = w, h
            --refCx = (minX + maxX) / 2
            --refCy = (minY + maxY) / 2
        end
    end

    -- Step 2: create normalized copies
    local normalized = {}

    for _, shape in ipairs(shapes) do
        local minX, minY, maxX, maxY = getBBox(shape.points)
        local cx = (minX + maxX) / 2
        local cy = (minY + maxY) / 2
        --local w = maxX - minX
        --local h = maxY - minY


        local newShape = { points = {} }

        for i = 1, #shape.points, 2 do
            local x = (shape.points[i] - cx)     --+ refCx
            local y = (shape.points[i + 1] - cy) --+ refCy
            table.insert(newShape.points, x)
            table.insert(newShape.points, y)
        end

        table.insert(normalized, newShape)
    end
    print('largets bbox found', maxW, maxH)
    return normalized
end

function getMaxBoundingBoxDimensions(shapes)
    if #shapes == 0 then return 0, 0, 0, 0 end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, shape in ipairs(shapes) do
        local pts = shape.points
        for i = 1, #pts, 2 do
            local x, y = pts[i], pts[i + 1]
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
        end
    end

    return maxX - minX, maxY - minY
end

function love.load()
    love.window.setMode(1600, 1024)
    aardman = love.graphics.newImage('aardman.jpg')
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    lips = {
        love.graphics.newImage('line1.png'),
        love.graphics.newImage('line2.png'),
        love.graphics.newImage('upperlip2.png'),
        love.graphics.newImage('upperlip3.png'),
        love.graphics.newImage('upperlipx.png')
    }
    font = love.graphics.getFont()
    bigfont = love.graphics.newFont('VoltaT-Regu.ttf', 24)

    lipindex, lipoffset = 1, 0
    lip = lips[lipindex]

    shapes = {
        [1] = {
            data = { upperteeth = true },
            points = { 46, 111, 70, 68, 153, 111, 224, 68, 254, 110, 223, 172, 156, 205, 70, 153 }
        },
        [2] = {

            points = { 615, 657, 631, 651, 739, 649, 852, 645, 862, 665, 841, 670, 739, 670, 628, 674 }
        },
        [3] = {

            points = { 758, 300, 790, 277, 848, 316, 899, 268, 932, 296, 926, 333, 847, 355, 762, 338 }
        },
        [4] = {

            points = { 529, 484, 545, 476, 601, 530, 666, 478, 688, 490, 669, 522, 605, 531, 533, 520 }
        },
        [5] = {

            points = { 508, 313, 570, 256, 610, 249, 669, 262, 715, 315, 697, 365, 615, 329, 541, 370 }
        },
        [6] = {

            points = { 540, 98, 561, 59, 601, 47, 643, 65, 661, 93, 639, 126, 597, 139, 564, 130 }
        },
        [7] = {

            points = { 355, 122, 363, 98, 388, 85, 411, 96, 421, 122, 411, 146, 388, 160, 366, 145 }
        },
        [8] = {

            points = { 762, 104, 772, 68, 835, 76, 914, 72, 930, 101, 915, 138, 827, 144, 770, 140 }
        },
        [9] = {

            points = { 770, 506, 794, 486, 853, 491, 906, 486, 927, 512, 908, 521, 846, 515, 792, 521 }
        },
        [10] = {
            data = { upperteeth = true },

            points = { 265, 315, 285, 285, 348, 271, 420, 289, 429, 320, 413, 368, 341, 367, 281, 345 }
        },
        [11] = {
            data = { upperteeth = true },
            points = { 323, 583, 334, 546, 385, 519, 435, 543, 443, 580, 424, 608, 384, 638, 337, 614 }
        },
        [12] =
        {
            data = { upperteeth = true },
            points = { 80, 444, 101, 408, 165, 391, 231, 404, 248, 450, 231, 478, 163, 500, 84, 478 }
        },
        [13] =
        {
            data = { upperteeth = true },
            points = { 86, 643, 113, 611, 177, 647, 239, 616, 265, 659, 231, 701, 162, 702, 96, 692 }
        },
        [14] = {

            points = { 1036, 556, 1056, 534, 1129, 496, 1226, 538, 1218, 566, 1204, 573, 1128, 518, 1051, 576 }
        }
    }
    --normalizedshapes = normalizeShapesByUpperLip(shapes)
    normalizedshapes = normalizeShapesByUpperLip(shapes)
    maxw, maxh = getMaxBoundingBoxDimensions(normalizedshapes)
    teeth = love.graphics.newImage('teeth5.png')
    tw, th = teeth:getDimensions()
    teethScale = maxw / tw


    renderShapeIndex = 1
    currentShape = { points = {} }
    for _, v in ipairs(normalizedshapes[renderShapeIndex].points) do
        table.insert(currentShape.points, v)
    end
    if (normalizedshapes[renderShapeIndex].data) then
        currentShape.data = shallowCopy(normalizedshapes[renderShapeIndex].data)
    end
end

function love.keypressed(key)
    if key == 'space' then
        lipindex = lipindex % #lips + 1
        lip = lips[lipindex]
    elseif key == 'r' then
        renderShapeIndex = renderShapeIndex + 1
        if renderShapeIndex > #normalizedshapes then renderShapeIndex = 1 end
        -- Copy target
        targetShape = normalizedshapes[renderShapeIndex]
        tweenTime = 0
    elseif key == 'e' then
        renderShapeIndex = renderShapeIndex - 1
        if renderShapeIndex < 1 then renderShapeIndex = #normalizedshapes end

        -- Copy target
        targetShape = normalizedshapes[renderShapeIndex]
        tweenTime = 0
    elseif key == 'escape' then
        love.event.quit()
    end
end

function love.update()
    if love.keyboard.isDown('left') then lipoffset = lipoffset - 1 end
    if love.keyboard.isDown('right') then lipoffset = lipoffset + 1 end

    if targetShape and tweenTime < tweenDuration then
        tweenTime = tweenTime + love.timer.getDelta()
        local t = math.min(tweenTime / tweenDuration, 1)

        for i = 1, #currentShape.points do
            local a = currentShape.points[i]
            local b = targetShape.points[i]
            currentShape.points[i] = lerp(a, b, t)
        end
        -- if t >= .5 then
        if (targetShape.data and t > .1) then
            currentShape.data = shallowCopy(targetShape.data)
        elseif not (targetShape.data) then
            currentShape.data = nil
        end
        --  end
        -- Done tweening
        if t >= 1 then
            targetShape = nil
        end
    end
end

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

function drawShape(shape, scaleX, scaleY)
    local s = shape.points
    local scaleX = scaleX or 1
    local scaleY = scaleY or 1
    --normalizedshapes[1].points
    -- local up = { s[1], s[2], s[3], s[4], s[3], s[4], s[5], s[6], s[5], s[6], s[7], s[8], s[7], s[8], s[9], s[10] }
    -- local down = { s[9], s[10], s[11], s[12], s[11], s[12], s[13], s[14], s[13], s[14], s[15], s[16], s[15], s[16], s
    --     [1], s[2] }

    local up = {
        s[1] * scaleX, s[2] * scaleY, s[3] * scaleX, s[4] * scaleY,
        s[3] * scaleX, s[4] * scaleY, s[5] * scaleX, s[6] * scaleY,
        s[5] * scaleX, s[6] * scaleY, s[7] * scaleX, s[8] * scaleY,
        s[7] * scaleX, s[8] * scaleY, s[9] * scaleX, s[10] * scaleY
    }
    local down = {
        s[9] * scaleX, s[10] * scaleY, s[11] * scaleX, s[12] * scaleY,
        s[11] * scaleX, s[12] * scaleY, s[13] * scaleX, s[14] * scaleY,
        s[13] * scaleX, s[14] * scaleY, s[15] * scaleX, s[16] * scaleY,
        s[15] * scaleX, s[16] * scaleY, s[1] * scaleX, s[2] * scaleY
    }


    local upCurve = love.math.newBezierCurve(up)
    local downCurve = love.math.newBezierCurve(down)

    local upPoints = upCurve:render(1)
    local downPoints = downCurve:render(1)
    for i = 1, #downPoints, 2 do
        table.insert(upPoints, downPoints[i])
        table.insert(upPoints, downPoints[i + 1])
    end
    local vertices = removeConsecutiveDuplicates(upPoints)
    local tris = makeTrianglesFromPolygon(vertices)

    local stencilFunction = function()
        for i = 1, #tris do
            love.graphics.polygon("fill", tris[i])
        end
    end

    love.graphics.stencil(stencilFunction, "replace", 1)
    love.graphics.setStencilTest("equal", 1)
    love.graphics.setColor(0, 0, 0, 1)
    for i = 1, #tris do
        love.graphics.polygon("fill", tris[i])
    end

    love.graphics.setColor(1, 1, 1)

    love.graphics.setStencilTest()
    if shape.data and shape.data.upperteeth then
        local umx, umy = getMidpoint(up)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(teeth, umx, umy, 0, teethScale / 2, teethScale / 2, tw / 2)
    end
    -- love.graphics.setColor(1, 0, 0)
    -- love.graphics.setLineWidth(5)
    -- love.graphics.line(upCurve:render())
    --  love.graphics.line(downCurve:render())

    love.graphics.setColor(1, 0, 0, 1)
    local m1 = createTexturedTriangleStrip(lip)
    texturedCurve(upCurve, lip, m1, -1, 0.3, lipoffset)
    love.graphics.draw(m1)

    local m2 = createTexturedTriangleStrip(lip)
    texturedCurve(downCurve, lip, m2, -1, 0.3, -lipoffset)
    love.graphics.draw(m2)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        for i, shape in ipairs(shapes) do
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
        table.insert(shapes, createShape(x, y, 30, 8))
    end
end

function love.mousereleased(x, y, button)
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

function love.mousemoved(x, y)
    if draggingShape and draggingIndex then
        draggingShape.points[draggingIndex] = x - offsetX
        draggingShape.points[draggingIndex + 1] = y - offsetY
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(aardman, 0, 0, 0, 2, 2)

    for i, shape in ipairs(shapes) do
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
            love.graphics.print(math.ceil(j / 2), s[j] + 8, s[j + 1] - 8)
        end
        scale = scale or 1
        -- local up = { s[1], s[2], s[3], s[4], s[3], s[4], s[5], s[6], s[5], s[6], s[7], s[8], s[7], s[8], s[9], s[10] }
        -- local down = { s[9], s[10], s[11], s[12], s[11], s[12], s[13], s[14], s[13], s[14], s[15], s[16], s[15], s[16], s
        --     [1], s[2] }

        local up = {
            s[1] * scale, s[2] * scale, s[3] * scale, s[4] * scale,
            s[3] * scale, s[4] * scale, s[5] * scale, s[6] * scale,
            s[5] * scale, s[6] * scale, s[7] * scale, s[8] * scale,
            s[7] * scale, s[8] * scale, s[9] * scale, s[10] * scale
        }
        local down = {
            s[9] * scale, s[10] * scale, s[11] * scale, s[12] * scale,
            s[11] * scale, s[12] * scale, s[13] * scale, s[14] * scale,
            s[13] * scale, s[14] * scale, s[15] * scale, s[16] * scale,
            s[15] * scale, s[16] * scale, s[1] * scale, s[2] * scale
        }


        local umx, umy = getMidpoint(up)

        love.graphics.draw(teeth, umx, umy, 0, teethScale / 2, teethScale / 2, tw / 2)
        local dmx, dmy = getMidpoint(down)
        love.graphics.draw(teeth, dmx, dmy, 0, teethScale / 2, -teethScale / 2, tw / 2)
        local upCurve = love.math.newBezierCurve(up)
        local downCurve = love.math.newBezierCurve(down)

        love.graphics.setColor(1, 0, 0)
        love.graphics.setLineWidth(5)
        love.graphics.line(upCurve:render())
        love.graphics.line(downCurve:render())

        love.graphics.setColor(1, 0, 1, 0.8)
        local m1 = createTexturedTriangleStrip(lip)
        texturedCurve(upCurve, lip, m1, -1, 0.3, lipoffset)
        love.graphics.draw(m1)

        local m2 = createTexturedTriangleStrip(lip)
        texturedCurve(downCurve, lip, m2, -1, 0.3, -lipoffset)
        love.graphics.draw(m2)

        love.graphics.setFont(bigfont)
        local cx, cy = getBoundingBoxCenter(s)
        love.graphics.setColor(1, 1, 0)
        love.graphics.print(i, cx, cy)
        love.graphics.setFont(font)
    end

    love.graphics.push()
    love.graphics.translate(1400, 200)
    love.graphics.ellipse('fill', 25, -50, 150, 200)
    drawShape(currentShape, 1, 1)
    --drawShape(normalizedshapes[renderShapeIndex])

    love.graphics.pop()

    love.graphics.setColor(0, 0, 0)
    love.graphics.print('R/E toggle mouthshapes, space textures, left/right offset')
end
