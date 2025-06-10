local lib = {}
local shapes = require 'mouth-shapes'
local mathutils = require 'math-utils'
local currentShape = nil
local targetShape = nil
local tweenTime = 0
local tweenDuration = 0.3
local renderShapeIndex = 0

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

local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

local lips = {
    love.graphics.newImage('assets/line1.png'),
    love.graphics.newImage('assets/line2.png'),
    love.graphics.newImage('assets/upperlip2.png'),
    love.graphics.newImage('assets/upperlip3.png'),
    love.graphics.newImage('assets/upperlipx.png'),
    love.graphics.newImage('assets/lowerlip4.png')
}

local teeth = love.graphics.newImage('assets/teeth5.png')
local tw, th = teeth:getDimensions()
local lipindex, lipoffset = 1, 0
local lip = lips[lipindex]

local maxw, maxh = getMaxBoundingBoxDimensions(shapes.normalized)
local teethScale = maxw / tw

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

local function makeTrianglesFromPolygon(polygon)
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

function lib.drawCurrentShape(scaleX, scaleY)
    lib.drawShape(currentShape, scaleX, scaleY)
end

function lib.drawShape(shape, scaleX, scaleY)
    -- local shape = normalizedshapes[index]
    local s = shape.points
    local scaleX = scaleX or 1
    local scaleY = scaleY or 1
    --normalizedshapes[1].points
    -- local up = { s[1], s[2], s[3], s[4], s[3], s[4], s[5], s[6], s[5], s[6], s[7], s[8], s[7], s[8], s[9], s[10] }
    -- local down = { s[9], s[10], s[11], s[12], s[11], s[12], s[13], s[14], s[13], s[14], s[15], s[16], s[15], s[16], s
    --     [1], s[2] }

    --  print(s, s[1])
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

function lib.init()
    renderShapeIndex = 1
    currentShape = { points = {} }
    for _, v in ipairs(shapes.normalized[renderShapeIndex].points) do
        table.insert(currentShape.points, v)
    end
    if (shapes.normalized[renderShapeIndex].data) then
        currentShape.data = shallowCopy(shapes.normalized[renderShapeIndex].data)
    end
end

function lib.nextLips()
    lipindex = lipindex % #lips + 1
    lip = lips[lipindex]
end

function lib.nextShape()
    renderShapeIndex = renderShapeIndex + 1
    if renderShapeIndex > #shapes.normalized then renderShapeIndex = 1 end
    -- Copy target
    targetShape = shapes.normalized[renderShapeIndex]
    tweenTime = 0
end

function lib.previousShape()
    renderShapeIndex = renderShapeIndex - 1
    if renderShapeIndex < 1 then renderShapeIndex = #shapes.normalized end

    -- Copy target
    targetShape = shapes.normalized[renderShapeIndex]
    tweenTime = 0
end

local function lerp(a, b, t)
    return a + (b - a) * t
end
function lib.update()
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

return lib
