local parse    = require 'lib.parse-file'
local node     = require 'lib.node'
local inspect  = require 'vendor.inspect'
local mesh     = require 'lib.mesh'
local polyline = require 'lib.polyline'
local numbers  = require 'lib.numbers'
local border   = require 'lib.border-mesh'
local cam      = require('lib.cameraBase').getInstance()
local canvas   = require 'lib.canvas'

local function stripPath(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url
        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
    end

    if root.children then
        for i = 1, #root.children do
            stripPath(root.children[i], path)
        end
    end

    return root
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

local function getLengthOfPath(path)
    local result = 0
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i + 1]
        result = result + getDistance(a[1], a[2], b[1], b[2])
    end
    return result
end

local function loadGroupFromFile(url, groupName)
    local imgs = {}
    local parts = {}
    local whole = parse.parseFile(url)
    local group = node.findNodeByName(whole, groupName) or {}

    for i = 1, #group.children do
        local p = group.children[i]
        stripPath(p, '/experiments/puppet%-maker/')
        for j = 1, #p.children do
            if p.children[j].texture then
                imgs[i] = p.children[j].texture.url
                parts[i] = group.children[i]
            end
        end
    end
    return imgs, parts
end

local function zeroTransform(arr)
    for i = 1, #arr do
        if arr[i].transforms then
            arr[i].transforms.l[1] = 0
            arr[i].transforms.l[2] = 0
        end
    end
end

function loadVectorSketch(path, groupName)
    local _, bodyParts = loadGroupFromFile(path, groupName)
    zeroTransform(bodyParts)

    local result = {}
    for i = 1, #bodyParts do
        local me = {
            pivotX = bodyParts[i].transforms.l[6] - bodyParts[i].transforms.l[1],
            pivotY = bodyParts[i].transforms.l[7] - bodyParts[i].transforms.l[2]
        }
        for j = 1, #bodyParts[i].children do
            local child = bodyParts[i].children[j]
            if child.texture and child.texture.url then
                local img = mesh.getImage(child.texture.url)
                me.url = child.texture.url
                me.texturePoints = child.points
            end
            if child.type == 'meta' then
                --print(inspect(child.points))
                me.points = child.points
            end
        end
        table.insert(result, me)
    end

    return result
end

---comment
---@param image love.Image
---@return love.Mesh
function createTexturedTriangleStrip(image, optionalWidthMultiplier)
    -- this assumes an strip that is oriented vertically
    local w, h = image:getDimensions()
    w = w * (optionalWidthMultiplier or 1)

    local vertices = {}
    local segments = 11
    local hPart = h / (segments - 1)
    local hv = 1 / (segments - 1)
    local runningHV = 0
    local runningHP = 0
    local index = 0

    for i = 1, segments do
        vertices[index + 1] = { -w / 2, runningHP, 0, runningHV }
        vertices[index + 2] = { w / 2, runningHP, 1, runningHV }
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)
    return mesh
end

function texturedCurve(curve, image, mesh, dir, scaleW)
    if not dir then dir = 1 end
    if not scaleW then scaleW = 1 / 2.5 end
    local dl = curve:getDerivative()

    for i = 1, 1 do
        local w, h = image:getDimensions()
        local count = mesh:getVertexCount()

        for j = 1, count, 2 do
            local index                  = (j - 1) / (count - 2)
            local xl, yl                 = curve:evaluate(index)
            local dx, dy                 = dl:evaluate(index)
            local a                      = math.atan2(dy, dx) + math.pi / 2
            local a2                     = math.atan2(dy, dx) - math.pi / 2
            local line                   = (w * dir) * scaleW --- here we can make the texture wider!!, also flip it
            local x2                     = xl + line * math.cos(a)
            local y2                     = yl + line * math.sin(a)
            local x3                     = xl + line * math.cos(a2)
            local y3                     = yl + line * math.sin(a2)

            local x, y, u, v, r, g, b, a = mesh:getVertex(j)
            mesh:setVertex(j, { x2, y2, u, v })
            x, y, u, v, r, g, b, a = mesh:getVertex(j + 1)
            mesh:setVertex(j + 1, { x3, y3, u, v })
        end
    end
end

function drawTorsoOver(box2dTorso)
    local img = mesh.getImage(box2dTorso.textureData.url)
    local w, h = img:getDimensions()
    local x, y = box2dTorso.body:getPosition()
    local r = box2dTorso.body:getAngle()

    local tp = box2dTorso.textureData.texturePoints
    local pointsW = tp[2][1] - tp[1][1]
    local pointsH = tp[3][2] - tp[1][2]

    local sx = (pointsW / w) * box2dTorso.scaleData.wscale
    local sy = (pointsH / h) * box2dTorso.scaleData.hscale

    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(img, x, y, r, sx, sy, w / 2, h / 2)
end

function drawSpriet(x, y, index, r, sy)
    local img = spriet[index]
    local w, h = img:getDimensions()
    love.graphics.draw(img, x, y, r, 1, sy, w, h)
end

function drawPlantOver(data, i)
    local imgs = plantImages
    local index = (i % #imgs) + 1
    --  print(index)
    local img = imgs[index]
    if data then
        love.graphics.setColor(10 / 255, 122 / 255, 42 / 255, 1)
        local w, h = img:getDimensions()
        local x, y = data[1]:getPosition()
        local r    = data[1]:getAngle()
        love.graphics.draw(img, x, y, r, 1, 1, w, h)
    end
end

-- torso/head
function renderMetaObject(img, name, box2dGuy, creation)
    local img    = img
    local w, h   = img:getDimensions()

    local x, y   = box2dGuy[name]:getPosition()
    local r      = box2dGuy[name]:getAngle()

    local wscale = creation[name].w / creation[name].metaPointsW
    local hscale = creation[name].h / creation[name].metaPointsH

    local sx     = (creation[name].metaTexturePointsW / w) * wscale
    local sy     = (creation[name].metaTexturePointsH / h) * hscale

    if name == 'head' and (creation.head.metaOffsetX or creation.head.metaOffsetY) then
        x, y = box2dGuy.head:getWorldPoint(creation.head.metaOffsetX * wscale,
                creation.head.metaOffsetY * hscale)
    end

    love.graphics.draw(img, x, y, r, sx * creation[name].flipx, sy * creation[name].flipy, w / 2, h / 2)

    return x, y, r, sx, sy
end

-- note : DONT USE THE sx/sy multiplier to support all types of sizes,
-- just use it for flipping with -1+1 and optionally addsome kind of divider if , for example, all ear images are drawn x2 too big
function renderAtachedObject(img, name, nameP, extraR, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local x, y = box2dGuy[name]:getWorldPoint(0, 0)
    local r = box2dGuy[name]:getAngle() + extraR
    local wscale = creation[nameP].h / w -- flipped because this is about foot and hands
    local hscale = creation[nameP].w / h
    local ox = creation[nameP].metaPivotX - creation[nameP].metaTexturePoints[1][1]
    local oy = creation[nameP].metaPivotY - creation[nameP].metaTexturePoints[1][2]
    local dpi = love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox * dpi / shrink, oy * dpi / shrink)
end

function renderNonAttachedObject(img, name, r, x, y, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local wscale = creation[name].w / h
    local hscale = creation[name].h / w
    local ox = creation[name].metaPivotX - creation[name].metaTexturePoints[1][1]
    local oy = creation[name].metaPivotY - creation[name].metaTexturePoints[1][2]
    local dpi = love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox * dpi / shrink, oy * dpi / shrink)
end

function renderNonAttachedObject2(img, name, r, x, y, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local wscale = creation[name].h / h
    local hscale = creation[name].w / w
    local ox = creation[name].metaPivotX - creation[name].metaTexturePoints[1][1]
    local oy = creation[name].metaPivotY - creation[name].metaTexturePoints[1][2]
    local dpi = love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, w / 2, h / 2)
end

function renderCurvedObject(p1, p2, p3, canvas, mesh, box2dGuy, dir, wmultiplier)
    local ax, ay = box2dGuy[p1]:getPosition()
    local bx, by = box2dGuy[p2]:getPosition()
    local cx, cy = box2dGuy[p3]:getPosition()
    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })

    if (dir ~= nil or wmultiplier ~= nil) then
        texturedCurve(curve, canvas, mesh, dir, wmultiplier)
    else
        texturedCurve(curve, canvas, mesh)
    end
end

function renderCurvedObjectFromSimplePoints(p1, p2, p3, canvas, mesh, box2dGuy, dir, wmultiplier)
    local curve = love.math.newBezierCurve({ p1[1], p1[2], p2[1], p2[2], p2[1], p2[2], p3[1], p3[2] })
    if (dir ~= nil or wmultiplier ~= nil) then
        texturedCurve(curve, canvas, mesh, dir, wmultiplier)
    else
        texturedCurve(curve, canvas, mesh, -1, 1 / 3)
    end

    return curve
end

function drawSquishableHairOver(x, y, r, sx, sy, creation)
    -- first get the polygon from the meta object that describes the shape in 8 points
    -- optionally grow that polygon outwards from the middle
    local f = creation.torso.metaPoints
    local p = {}
    for i = 1, #f do
        p[i] = {}
        p[i][1] = f[i][1] * 1.3
        p[i][2] = f[i][2] * 1.3
    end

    local points = { { 0, 0 }, p[8], p[1], p[2], p[3], p[4], p[5], p[6], p[7] }
    local uvs = mesh.makeSquishableUVsFromPoints(points)
    local _mesh = love.graphics.newMesh(uvs, 'fan')
    local img = mesh.getImage('assets/parts/borsthaar7.png')
    _mesh:setTexture(img)

    love.graphics.draw(_mesh, x, y, r, sx, sy)
end

function drawNumbersOver(box2dGuy)
    local parts = {
        'torso', 'head', 'neck', 'neck1',
        'lear', 'rear', 'luleg', 'ruleg',
        'llleg', 'rlleg', 'lfoot', 'rfoot',
    }

    for i = 1, #parts do
        local p = parts[i]
        if box2dGuy[p] then
            local x, y = box2dGuy[p]:getPosition()
            local a = box2dGuy[p]:getAngle()
            love.graphics.print(string.format("%.2f ", a), x, y)
        end
    end
end

function renderHair(box2dGuy, faceData, creation, multipliers, x, y, r, sx, sy)
    local dpi = love.graphics.getDPIScale()
    local shrink = canvas.getShrinkFactor()
    if true then
        if true or box2dGuy.hairNeedsRedo then
            local img = hairCanvas
            local w, h = img:getDimensions()
            local f = faceData.metaPoints
            -- todo parameter hair (beard, only top hair, sidehair)
            --local hairLine = { f[6], f[7], f[8], f[1], f[2], f[3], f[4] }
            local hairLine = { f[7], f[8], f[1], f[2], f[3] }
            --local hairLine = { f[3], f[4], f[5], f[6], f[7] }
            local points = hairLine
            local hairTension = .02
            local spacing = 10 * multipliers.hair.sMultiplier
            local coords

            coords = border.unloosenVanillaline(points, hairTension, spacing)
            local length = getLengthOfPath(hairLine)
            local factor = (length / h)
            local hairWidthMultiplier = 1 * multipliers.hair.wMultiplier
            local width = (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
            local verts, indices, draw_mode = polyline.render('miter', coords, width)

            local vertsWithUVs = {}

            for i = 1, #verts do
                local u = (i % 2 == 1) and 0 or 1
                local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
            end

            local vertices = vertsWithUVs
            local m = love.graphics.newMesh(vertices, "strip")
            m:setTexture(img)
            love.graphics.draw(m, x, y, r - math.pi, sx * creation.head.flipx * (dpi / shrink), sy * (dpi / shrink))
        end
    end
end

function drawMouth(facePart, faceData, creation, box2dGuy, sx, sy, r)
    local f = faceData.metaPoints
    local mouthX = numbers.lerp(f[3][1], f[7][1], 0.5)
    local mouthY = numbers.lerp(f[1][2], f[5][2], 0.85)

    local mx, my = facePart:getWorldPoint(
            (mouthX + faceData.metaOffsetX) * sx,
            (mouthY + faceData.metaOffsetY) * sy)
    local tx, ty = facePart:getWorldPoint(
            (mouthX + faceData.metaOffsetX) * sx,
            (mouthY + faceData.metaOffsetY - 20) * sy)
    local mouthWidth = (f[3][1] - f[7][1]) / 2
    local scaleX = mouthWidth / teethCanvas:getWidth()
    local upperlipmesh = createTexturedTriangleStrip(upperlipCanvas)

    local upperCurve = renderCurvedObjectFromSimplePoints({ -mouthWidth / 2, 0 },
            { 0, -20 },
            { mouthWidth / 2, 0 },
            upperlipCanvas,
            upperlipmesh, box2dGuy)

    local lowerlipmesh = createTexturedTriangleStrip(lowerlipCanvas)

    local lowerCurve = renderCurvedObjectFromSimplePoints({ -mouthWidth / 2, 0 },
            { 0, 20 },
            { mouthWidth / 2, 0 },
            upperlipCanvas,
            lowerlipmesh, box2dGuy)

    local holePolygon = {}

    for i = 0, 6 do
        local x, y = upperCurve:evaluate(i / 6)
        table.insert(holePolygon, { x, y })
    end
    for i = 0, 6 do
        local x, y = lowerCurve:evaluate(1 - (i / 6))
        table.insert(holePolygon, { x, y })
    end
    local mesh = love.graphics.newMesh(holePolygon, "fan")

    local myStencilFunction = function()
        love.graphics.draw(mesh, mx, my, r - math.pi, 1, 1)
    end
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(mesh, mx, my, r - math.pi, 1, 1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.stencil(myStencilFunction, "replace", 1)

    love.graphics.setStencilTest("greater", 0)
    renderNonAttachedObject(teethCanvas,
        'teeth', r, tx, ty, scaleX * 2, -1 * scaleX * 2,
        box2dGuy, creation)

    love.graphics.setStencilTest()

    love.graphics.draw(upperlipmesh, mx, my, r - math.pi, 1, 1)
    love.graphics.draw(lowerlipmesh, mx, my, r - math.pi, 1, 1)
end

local function getAngleAndDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local angle = math.atan2(dy, dx)
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return angle, distance
end

local function setAngleAndDistance(sx, sy, angle, distance, scaleX, scaleY)
    local newx = sx + (distance * scaleX) * math.cos(angle)
    local newy = sy + (distance * scaleY) * math.sin(angle)
    return newx, newy
end

function drawSkinOver(box2dGuy, creation, multipliers, positioners)
    love.graphics.setColor(1, 1, 1, 1)
    local dpi = love.graphics.getDPIScale()
    local shrink = canvas.getShrinkFactor()

    if creation.torso.metaURL and not creation.isPotatoHead then
        local x, y, r, sx, sy = renderMetaObject(torsoCanvas, 'torso', box2dGuy, creation)
        love.graphics.setColor(.4, 0, 0, 1)
        drawSquishableHairOver(x, y, r, sx * dpi / shrink, sy * dpi / shrink, creation)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if neckCanvas and box2dGuy.neck and box2dGuy.neck1 then
        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObject('neck', 'neck1', 'head', neckCanvas, neckmesh, box2dGuy, 1,
            multipliers.neck.wMultiplier / (4 * dpi / shrink))
        love.graphics.draw(neckmesh, 0, 0, 0, 1, 1)
    end

    if earCanvas then
        if creation.lear.metaURL then
            renderAtachedObject(earCanvas, 'lear', 'lear', -math.pi / 2, -1 * 2, 2, box2dGuy, creation)
            renderAtachedObject(earCanvas, 'rear', 'rear', math.pi / 2, 1 * 2, 2, box2dGuy, creation)
        end
    end

    love.graphics.setColor(0, 0, 0, 1)

    local facePart = creation.isPotatoHead and box2dGuy.torso or box2dGuy.head
    local faceCanvas = creation.isPotatoHead and torsoCanvas or headCanvas
    local face = creation.isPotatoHead and 'torso' or 'head'
    local faceData = creation.isPotatoHead and creation.torso or creation.head


    local faceMultiplier = multipliers.face.mMultiplier

    love.graphics.setColor(1, 1, 1, 1)
    local x, y, r, sx, sy = renderMetaObject(faceCanvas, face, box2dGuy, creation)

    if creation.isPotatoHead then
        love.graphics.setColor(.4, 0, 0, 1)
        drawSquishableHairOver(x, y, r, sx * dpi / shrink, sy * dpi / shrink, creation)
        love.graphics.setColor(1, 1, 1, 1)
    end
    r = r + math.pi

    local mx, my = love.mouse.getPosition()
    local f = faceData.metaPoints
    local leftEyeX = numbers.lerp(f[7][1], f[3][1], 0.5 - positioners.eye.x)
    local rightEyeX = numbers.lerp(f[7][1], f[3][1], 0.5 + positioners.eye.x)

    if true then -- eyes!!!
        local eyeMultiplierFix = 0.5
        local pupilMultiplierFix = 0.5

        local eyeY = numbers.lerp(f[1][2], f[5][2], positioners.eye.y)

        local eyelx, eyely = facePart:getWorldPoint(
                (leftEyeX + faceData.metaOffsetX) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY) * sy * dpi / shrink)

        local eyerx, eyery = facePart:getWorldPoint(
                (rightEyeX + faceData.metaOffsetX) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY) * sy * dpi / shrink)

        local cx, cy = cam:getScreenCoordinates(eyelx, eyely)
        local angle, dist = getAngleAndDistance(cx, cy, mx, my)
        local px1, py1 = setAngleAndDistance(0, 0, angle - r, math.min(dist, 10), 1, 1)
        local pupillx, pupilly = facePart:getWorldPoint(
                (leftEyeX + faceData.metaOffsetX + px1) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY + py1) * sy * dpi / shrink)

        local cx, cy = cam:getScreenCoordinates(eyerx, eyery)
        local angle, dist = getAngleAndDistance(cx, cy, mx, my)
        local px2, py2 = setAngleAndDistance(0, 0, angle - r, math.min(dist, 10), 1, 1)
        local pupilrx, pupilry = facePart:getWorldPoint(
                (rightEyeX + faceData.metaOffsetX + px2) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY + py2) * sy * dpi / shrink)

        if eyeCanvas then
            local eyeW = eyeMultiplierFix * multipliers.eye.wMultiplier * faceMultiplier
            local eyeH = eyeMultiplierFix * multipliers.eye.hMultiplier * faceMultiplier
            renderNonAttachedObject(eyeCanvas,
                'eye', r - positioners.eye.r, eyelx, eyely, -eyeW, eyeH, box2dGuy, creation)

            renderNonAttachedObject(eyeCanvas,
                'eye', r + positioners.eye.r, eyerx, eyery, eyeW, eyeH, box2dGuy, creation)
        end

        if pupilCanvas then
            local pupilW = multipliers.pupil.wMultiplier
            local pupilH = multipliers.pupil.hMultiplier
            renderNonAttachedObject2(pupilCanvas,
                'pupil', r, pupillx, pupilly, pupilW, pupilH, box2dGuy, creation)
            renderNonAttachedObject2(pupilCanvas,
                'pupil', r, pupilrx, pupilry, pupilW, pupilH, box2dGuy, creation)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    renderHair(box2dGuy, faceData, creation, multipliers, x, y, r, sx, sy)

    if browCanvas then
        local browY = numbers.lerp(f[5][2], f[1][2], positioners.brow.y)

        local browlx, browly = facePart:getWorldPoint(
                (leftEyeX + faceData.metaOffsetX) * sx * dpi / shrink,
                (browY + faceData.metaOffsetY) * sy * dpi / shrink)

        local browrx, browry = facePart:getWorldPoint(
                (rightEyeX + faceData.metaOffsetX) * sx * dpi / shrink,
                (browY + faceData.metaOffsetY) * sy * dpi / shrink)

        love.graphics.setColor(1, 1, 1, 1)

        local faceWidth = ((f[3][1] - f[7][1]) / 2) * multipliers.brow.wMultiplier
        local bends = { { 0, 0, 0 }, { 1, 0, -1 }, { -1, 0, 1 }, { 1, 0, 1 }, { -1, 0, -1 }, { 1, 0, 0 },
            { -1, 0, 0 }, { 0, -1, 1 }, { 0, 1, 1 }, { -1, 1, 1 }, }
        local bend = bends[math.ceil(positioners.brow.bend)]
        local bendMultiplier = 1 * faceWidth / 5

        local browmesh = createTexturedTriangleStrip(browCanvas)
        renderCurvedObjectFromSimplePoints(
            { -faceWidth / 2, bend[1] * bendMultiplier },
            { 0, bend[2] * bendMultiplier },
            { faceWidth / 2, bend[3] * bendMultiplier },
            browCanvas, browmesh, box2dGuy, 1, multipliers.brow.hMultiplier * shrink / dpi)
        love.graphics.draw(browmesh, browlx, browly, r, 1, 1)

        local browmesh = createTexturedTriangleStrip(browCanvas)
        renderCurvedObjectFromSimplePoints(
            { -faceWidth / 2, bend[1] * bendMultiplier },
            { 0, bend[2] * bendMultiplier },
            { faceWidth / 2, bend[3] * bendMultiplier },
            browCanvas, browmesh, box2dGuy, 1, multipliers.brow.hMultiplier * shrink / dpi)
        love.graphics.draw(browmesh, browrx, browry, r, -1, 1)
    end

    --     drawMouth(facePart, faceData, creation, box2dGuy, sx, sy, r)

    if noseCanvas then
        local noseX = numbers.lerp(f[7][1], f[3][1], 0.5)
        local noseY = numbers.lerp(f[1][2], f[5][2], positioners.nose.y)
        local nx, ny = facePart:getWorldPoint(
                (noseX + faceData.metaOffsetX) * sx * dpi / shrink,
                (noseY + faceData.metaOffsetY) * sy * dpi / shrink)

        renderNonAttachedObject(noseCanvas,
            'nose', r, nx, ny, 0.5 * multipliers.nose.wMultiplier * faceMultiplier,
            -0.5 * multipliers.nose.hMultiplier * faceMultiplier,
            box2dGuy, creation)
    end

    if legCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObject('luleg', 'llleg', 'lfoot', legCanvas, legmesh, box2dGuy, 1,
            shrink * multipliers.leg.wMultiplier / (4 * dpi))
        love.graphics.draw(legmesh, 0, 0, 0, 1, 1)
        renderCurvedObject('ruleg', 'rlleg', 'rfoot', legCanvas, legmesh, box2dGuy, 1,
            shrink * multipliers.leg.wMultiplier / (4 * dpi))
        love.graphics.draw(legmesh, 0, 0, 0, 1, 1)
    end

    if leghairCanvas then
        renderCurvedObject('luleg', 'llleg', 'lfoot', leghairCanvas, leghairMesh, box2dGuy, -1,
            (multipliers.leg.wMultiplier * multipliers.leghair.wMultiplier) / (4 * dpi))
        love.graphics.draw(leghairMesh, 0, 0, 0, 1, 1)

        renderCurvedObject('ruleg', 'rlleg', 'rfoot', leghairCanvas, leghairMesh, box2dGuy, 1,
            (multipliers.leg.wMultiplier * multipliers.leghair.wMultiplier) / (4 * dpi))
        love.graphics.draw(leghairMesh, 0, 0, 0, 1, 1)
    end

    if armCanvas then
        renderCurvedObject('luarm', 'llarm', 'lhand', armCanvas, armmesh, box2dGuy, 1,
            shrink * multipliers.arm.wMultiplier / (4 * dpi))
        love.graphics.draw(armmesh, 0, 0, 0, 1, 1)
        renderCurvedObject('ruarm', 'rlarm', 'rhand', armCanvas, armmesh, box2dGuy, 1,
            shrink * multipliers.arm.wMultiplier / (4 * dpi))
        love.graphics.draw(armmesh, 0, 0, 0, 1, 1)
    end

    if armhairCanvas then
        renderCurvedObject('luarm', 'llarm', 'lhand', armhairCanvas, armhairMesh, box2dGuy, -1,
            (multipliers.arm.wMultiplier * multipliers.armhair.wMultiplier) / (4 * dpi))
        love.graphics.draw(armhairMesh, 0, 0, 0, 1, 1)

        renderCurvedObject('ruarm', 'rlarm', 'rhand', armhairCanvas, armhairMesh, box2dGuy, 1,
            (multipliers.arm.wMultiplier * multipliers.armhair.wMultiplier) / (4 * dpi))
        love.graphics.draw(armhairMesh, 0, 0, 0, 1, 1)
    end

    if handCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        if creation.lhand.metaURL then
            renderAtachedObject(handCanvas, 'lhand', 'lhand', -math.pi / 2, 1, 1, box2dGuy, creation)
        end
        if creation.rhand.metaURL then
            renderAtachedObject(handCanvas, 'rhand', 'rhand', -math.pi / 2, 1, -1, box2dGuy, creation)
        end
        love.graphics.setColor(0, 0, 0, 1)
    end

    if footCanvas then
        -- left foot
        if creation.lfoot.metaURL then
            love.graphics.setColor(1, 1, 1, 1)
            renderAtachedObject(footCanvas, 'lfoot', 'lfoot', -math.pi / 2, 1.1, 1.1, box2dGuy, creation)
        end
        -- right foot
        if creation.rfoot.metaURL then
            renderAtachedObject(footCanvas, 'rfoot', 'rfoot', math.pi / 2, -1.1, 1.1, box2dGuy, creation)
        end
    end
end