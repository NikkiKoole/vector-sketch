local Mouth = {}
Mouth.__index = Mouth
package.path = package.path .. ";mouth/?.lua;mouth/?/init.lua"

--local shapes = require 'mouth-shapes'
local assetPrefix = 'mouth/' or ''

local mathutils = require 'math-utils'

local raw = {
    [1] = {
        name = 'A_I',
        data = { upperteeth = true },
        points = { 46, 111, 70, 68, 153, 111, 224, 68, 254, 110, 223, 172, 156, 205, 70, 153 }
    },
    [2] = {
        name = 'closed',
        points = { 615, 657, 631, 651, 739, 649, 852, 645, 862, 665, 841, 670, 739, 670, 628, 674 }
    },
    [3] = {
        name = 'open_tween_happy',
        points = { 758, 300, 790, 277, 848, 316, 899, 268, 932, 296, 926, 333, 847, 355, 762, 338 }
    },
    [4] = {
        name = 'M_B_P',
        points = { 529, 484, 545, 476, 601, 530, 666, 478, 688, 490, 669, 522, 605, 531, 533, 520 }
    },
    [5] = {
        name = 'ugh',
        points = { 508, 313, 570, 256, 610, 249, 669, 262, 715, 315, 697, 365, 615, 329, 541, 370 }
    },
    [6] = {
        name = 'O_U_agh',
        points = { 540, 98, 561, 59, 601, 47, 643, 65, 661, 93, 639, 126, 597, 139, 564, 130 }
    },
    [7] = {
        name = 'O_U_W_Q',
        points = { 355, 122, 363, 98, 388, 85, 411, 96, 421, 122, 411, 146, 388, 160, 366, 145 }
    },
    [8] = {
        name = 'open_tween',
        points = { 762, 104, 772, 68, 835, 76, 914, 72, 930, 101, 915, 138, 827, 144, 770, 140 }
    },
    [9] = {
        name = 'mmm',
        points = { 770, 506, 794, 486, 853, 491, 906, 486, 927, 512, 908, 521, 846, 515, 792, 521 }
    },
    [10] = {
        name = 'C_D_E_G_K_N_R_S',
        data = { upperteeth = true },
        points = { 265, 315, 285, 285, 348, 271, 420, 289, 429, 320, 413, 368, 341, 367, 281, 345 }
    },
    [11] = {
        name = 'L_OU',
        data = { upperteeth = true },
        points = { 323, 583, 334, 546, 385, 519, 435, 543, 443, 580, 424, 608, 384, 638, 337, 614 }
    },
    [12] =
    {
        name = 'TH_L',
        data = { upperteeth = true },
        points = { 80, 444, 101, 408, 165, 391, 231, 404, 248, 450, 231, 478, 163, 500, 84, 478 }
    },
    [13] =
    {
        name = 'F_V',
        data = { upperteeth = true },
        points = { 86, 643, 113, 611, 177, 647, 239, 616, 265, 659, 231, 701, 162, 702, 96, 692 }
    },
    [14] = {
        name = 'frown',
        points = { 1036, 556, 1056, 534, 1129, 496, 1226, 538, 1218, 566, 1204, 573, 1128, 518, 1051, 576 }
    },
    [15] = {
        name = "smile",
        points = { 1038, 546, 1051, 536, 1124, 652, 1208, 532, 1221, 547, 1208, 568, 1124, 663, 1053, 570 }
    }
}

local phonemeKeys = {
    a = 'A_I',
    i = 'A_I',
    o = 'O_U_W_Q',
    m = 'M_B_P',
    b = 'M_B_P',
    p = 'M_B_P',
    f = 'F_V',
    k = 'C_D_E_G_K_N_R_S',
    l = 'L_OU',
    t = 'TH_L',
    j = 'open_tween',
    n = 'C_D_E_G_K_N_R_S',
    d = 'C_D_E_G_K_N_R_S',
    s = 'C_D_E_G_K_N_R_S',
    h = 'O_U_agh',
    w = 'O_U_W_Q',
    closed = 'frown',
    smile2 = 'open_tween_happy',
    smile = 'smile',
    mmm = 'mmm',
    frown = 'frown'
}

local phonemeIndex = {}
for k, v in pairs(phonemeKeys) do
    for i = 1, #raw do
        --print(raw[i].name)
        if raw[i].name == v then
            phonemeIndex[k] = i
        end
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
        newShape.name = shape.name
        table.insert(normalized, newShape)
    end

    return normalized
end

function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
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

local shapes = { raw = raw, normalized = normalizeShapesByUpperLip(raw), phonemeIndex = phonemeIndex }
--return
Mouth.shapes = shapes

local lips = {
    love.graphics.newImage(assetPrefix .. 'assets/line1.png'),
    love.graphics.newImage(assetPrefix .. 'assets/line2.png'),
    love.graphics.newImage(assetPrefix .. 'assets/upperlip2.png'),
    love.graphics.newImage(assetPrefix .. 'assets/upperlip3.png'),
    love.graphics.newImage(assetPrefix .. 'assets/upperlipx.png'),
    love.graphics.newImage(assetPrefix .. 'assets/lowerlip4.png')
}
local backdrop = love.graphics.newImage(assetPrefix .. 'assets/type4.png')
backdrop:setWrap('repeat', 'repeat')
local teeth = love.graphics.newImage(assetPrefix .. 'assets/teeth4.png')
local tw, th = teeth:getDimensions()

local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

-- Utility
function deepCopyShape(shape)
    local copy = {}
    for k, v in pairs(shape) do
        if type(v) == "table" then
            local sub = {}
            for i, p in ipairs(v) do sub[i] = p end
            copy[k] = sub
        else
            copy[k] = v
        end
    end
    return copy
end

local function shallowCopy(t)
    local new = {}
    for k, v in pairs(t) do new[k] = v end
    return new
end


local function lerp(a, b, t)
    return a + (b - a) * t
end


-- Class constructor
function Mouth.new()
    local self = setmetatable({}, Mouth)
    self.tweenTime = 0
    self.tweenDuration = 0.3
    self.renderShapeIndex = 1
    self.currentShape = { points = {} }
    self.targetShape = nil
    self.lipindex = 1
    self.lipoffset = 0
    self.lip = lips[self.lipindex]
    self.lastPhoneme = nil
    self.startShape = nil
    local shape = shapes.normalized[self.renderShapeIndex]
    for _, v in ipairs(shape.points) do
        table.insert(self.currentShape.points, v)
    end
    if shape.data then
        self.currentShape.data = shallowCopy(shape.data)
    end


    local maxw, maxh = getMaxBoundingBoxDimensions(shapes.normalized)
    self.teethScale = (maxw / tw) * (1 + love.math.random())
    -- print(self.teethScale)
    return self
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

function Mouth:drawCurrentShape(scaleX, scaleY)
    self:drawShape(self.drawCurrentShape, scaleX, scaleY)
end

function Mouth:drawShape(shape, scaleX, scaleY)
    local s = shape.points
    local scaleX = scaleX or 1
    local scaleY = scaleY or 1

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
    if true then
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

        local vertexFormat = {
            { "VertexPosition", "float", 2 },
            { "VertexTexCoord", "float", 2 },
        }
        local meshVertices = {}
        local texw, texh = backdrop:getDimensions()

        for i = 1, #tris do
            for j = 1, 6, 2 do
                local x = tris[i][j]
                local y = tris[i][j + 1]
                local tx = (x + texw / 2) / texw -- simple UV mapping
                local ty = (y + texh / 2) / texh
                --print(tx, ty)
                table.insert(meshVertices, { x, y, tx, ty })
            end
        end
        local mesh = love.graphics.newMesh(vertexFormat, meshVertices, "triangles")
        love.graphics.setColor(1, 1, 1, .4)
        love.graphics.draw(mesh)
        love.graphics.setColor(0.1, 0, 0, .7)
        mesh:setTexture(backdrop)

        love.graphics.draw(mesh)


        -- for i = 1, #tris do
        --     love.graphics.polygon("fill", tris[i])
        -- end

        love.graphics.setColor(1, 1, 1)
        if shape.data and false and shape.data.upperteeth then
            local umx, umy = getMidpoint(up)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(teeth, umx, umy, 0, self.teethScale / 2, self.teethScale / 2, tw / 2)
        end
        love.graphics.setStencilTest()

        if false then
            love.graphics.setColor(1, 0, 0)
            love.graphics.setLineWidth(15)
            love.graphics.line(upCurve:render())
            love.graphics.line(downCurve:render())
            love.graphics.setLineWidth(1)
        end
        if true then
            love.graphics.setColor(1, 1, 1, 1)
            --love.graphics.setColor(0, 0, 0, 1)
            local m1 = createTexturedTriangleStrip(self.lip)
            local texthick = scaleX / 4
            texturedCurve(upCurve, self.lip, m1, -1, texthick, self.lipoffset)
            love.graphics.draw(m1)

            local m2 = createTexturedTriangleStrip(self.lip)
            texturedCurve(downCurve, self.lip, m2, -1, texthick, -self.lipoffset)
            love.graphics.draw(m2)
        end
    end
    if false then
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
    end
    love.graphics.setColor(1, 1, 1)
end

function Mouth:setToPhoneme(phoneme)
    local index = shapes.phonemeIndex[phoneme]
    if index then
        self.renderShapeIndex = index
        self.targetShape = shapes.normalized[self.renderShapeIndex]
        self.tweenTime = 0
    end
end

-- function Mouth:close(duration)
--     --print('mouth close')
--     local index = phonemeIndex.closed -- self.closedShapeIndex
--     if not index then return end
--     if self.renderShapeIndex ~= index then
--         self.renderShapeIndex = index
--         self.targetShape = shapes.normalized[index]
--         self.tweenDuration = duration or 0.2
--         self.tweenTime = 0

--         -- Snapshot current shape for tweening
--         self.startShape = { points = {}, data = shallowCopy(self.currentShape.data or {}) }
--         for i, v in ipairs(self.currentShape.points) do
--             self.startShape.points[i] = v
--         end
--     end
-- end

function Mouth:setToPose(pose)
    print('todo')
end

function Mouth:nextShape()
    self.renderShapeIndex = self.renderShapeIndex + 1
    if self.renderShapeIndex > #shapes.normalized then self.renderShapeIndex = 1 end
    self.targetShape = shapes.normalized[self.renderShapeIndex]
    self.tweenTime = 0
end

function Mouth:previousShape()
    self.renderShapeIndex = self.renderShapeIndex - 1
    if self.renderShapeIndex < 1 then self.renderShapeIndex = #shapes.normalized end
    self.targetShape = shapes.normalized[self.renderShapeIndex]
    self.tweenTime = 0
end

function Mouth:nextLips()
    self.lipindex = self.lipindex % #lips + 1
    self.lip = lips[self.lipindex]
end

function Mouth:updateFallback(dt, target, duration)
    if self.mouthCloseTimer == nil then
        self.mouthCloseTimer = 0
        self.mouthCloseFrom = self.lastDirect or target
    end

    if self.mouthCloseTimer <= 1 then
        self.mouthCloseTimer = self.mouthCloseTimer + dt / duration
        local t = math.min(self.mouthCloseTimer, 1)
        self:tweenFromTo(self.mouthCloseFrom, target, t)
        self.lastDirect = target
    else
        self:setDirectTo(target)
    end
end

function Mouth:setDirectTo(phoneme)
    -- print('direct', phoneme)
    local index = shapes.phonemeIndex[phoneme]

    self.renderShapeIndex = index
    self.currentShape = deepCopyShape(shapes.normalized[self.renderShapeIndex])
    self.currentShape.points = shallowCopy(shapes.normalized[self.renderShapeIndex].points)
    self.lastDirect = phoneme
end

function Mouth:tweenFromTo(from, to, t)
    -- print(from, to, t)
    local fromindex = shapes.phonemeIndex[from]
    local toindex = shapes.phonemeIndex[to]
    local frompoints = shallowCopy(shapes.normalized[fromindex].points)
    local topoints = shallowCopy(shapes.normalized[toindex].points)

    for i = 1, #self.currentShape.points do
        local a = frompoints[i]
        local b = topoints[i]
        self.currentShape.points[i] = lerp(a, b, t)
    end
end

-- function Mouth:tweenTo(phoneme, t)
--     local index = shapes.phonemeIndex[phoneme]
--     if not index then return end

--     -- Only reset the tween if phoneme has changed

--     if self.lastPhoneme ~= phoneme then
--         --print(self.lastPhoneme, phoneme)
--         self.lastPhoneme = phoneme
--         self.renderShapeIndex = index
--         self.targetShape = shapes.normalized[index]
--         --print('ts', self.targetShape)
--         -- Save current shape as the start of the tween
--         self.startShape = { points = {}, data = shallowCopy(self.currentShape.data or {}) }
--         for i, v in ipairs(self.currentShape.points) do
--             self.startShape.points[i] = v
--         end
--     end
--     -- if self.targetShape == nil then
--     --     print('problesm!')
--     --     self.targetShape = shapes.normalized[index]
--     -- end

--     -- Now interpolate from start to target using external t
--     for i = 1, #self.currentShape.points do
--         local a = self.startShape.points[i]
--         local b = self.targetShape.points[i]
--         self.currentShape.points[i] = lerp(a, b, t)
--     end

--     if self.targetShape.data and t > 0.1 then
--         self.currentShape.data = shallowCopy(self.targetShape.data)
--     elseif not self.targetShape.data then
--         self.currentShape.data = nil
--     end

--     -- Optional: clear at end
--     -- if t >= 1 then
--     --     self.startShape = nil
--     -- end
-- end

function Mouth:update(dt)
    -- print('hello?')
    --if self.targetShape and self.startShape and self.tweenTime ~= nil then
    --    return
    --end

    if self.targetShape and self.tweenTime < self.tweenDuration then
        self.tweenTime = self.tweenTime + dt
        local t = math.min(self.tweenTime / self.tweenDuration, 1)

        for i = 1, #self.currentShape.points do
            local a = self.currentShape.points[i]
            local b = self.targetShape.points[i]
            self.currentShape.points[i] = lerp(a, b, t)
        end

        if (self.targetShape.data and t > .1) then
            self.currentShape.data = shallowCopy(self.targetShape.data)
        elseif not self.targetShape.data then
            self.currentShape.data = nil
        end

        -- if t >= 1 then
        --     self.targetShape = nil
        -- end
    end
end

function Mouth:draw(scaleX, scaleY)
    self:drawShape(self.currentShape, scaleX, scaleY)
end

return Mouth
