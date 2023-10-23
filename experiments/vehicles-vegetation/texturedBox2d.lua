local parse    = require 'lib.parse-file'
local node     = require 'lib.node'
local inspect  = require 'vendor.inspect'
local mesh     = require 'lib.mesh'
local bbox     = require 'lib.bbox'
local polyline = require 'lib.polyline'
local unloop   = require 'lib.unpack-points'
local numbers  = require 'lib.numbers'
local border   = require 'lib.border-mesh'
local text     = require 'lib.text'

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
    local bodyImgUrls, bodyParts = loadGroupFromFile(path, groupName)
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

function createTexturedTriangleStrip(image)
    -- this assumes an strip that is oriented vertically

    local w, h = image:getDimensions()
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
        -- print(i, runningHV, runningHP)
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end
    --print(h)
    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)

    return mesh
end

function texturedCurve(curve, image, mesh, dir, scaleW)
    if not dir then dir = 1 end
    if not scaleW then scaleW = 2.5 end
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

            local line                   = (w * dir) / scaleW --- here we can make the texture wider!!, also flip it
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
    local img    = img -- love.graphics.newImage(torsoCanvas)
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
    local img = img -- mesh.getImage(creation.ear.metaURL)
    local w, h = img:getDimensions()
    local x, y = box2dGuy[name]:getWorldPoint(0, 0)
    local r = box2dGuy[name]:getAngle() + extraR
    local wscale = creation[nameP].h / w
    local hscale = creation[nameP].w / h
    local ox = creation[nameP].metaPivotX - creation[nameP].metaTexturePoints[1][1]
    local oy = creation[nameP].metaPivotY - creation[nameP].metaTexturePoints[1][2]

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox, oy)
end

function renderNonAttachedObject(img, name, r, x, y, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img -- mesh.getImage(creation.eye.metaURL)
    local w, h = img:getDimensions()
    local wscale = creation[name].h / w --* 2 --creation.lfoot.metaPointsW
    local hscale = creation[name].w / h --* 2 --creation.lfoot.metaPointsH
    local ox = creation[name].metaPivotX - creation[name].metaTexturePoints[1][1]
    local oy = creation[name].metaPivotY - creation[name].metaTexturePoints[1][2]

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox, oy)
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
    --local ax, ay = box2dGuy[p1]:getPosition()
    --local bx, by = box2dGuy[p2]:getPosition()
    --local cx, cy = box2dGuy[p3]:getPosition()
    local curve = love.math.newBezierCurve({ p1[1], p1[2], p2[1], p2[2], p2[1], p2[2], p3[1], p3[2] })
    if (dir ~= nil or wmultiplier ~= nil) then
        texturedCurve(curve, canvas, mesh, dir, wmultiplier)
    else
        texturedCurve(curve, canvas, mesh, -1, 3)
    end
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

    local first = { { 0, 0 }, p[8], p[1], p[2], p[3], p[4], p[5], p[6], p[7] }
    local v = mesh.makeSquishableUVsFromPoints(first)
    local msh = love.graphics.newMesh(v, 'fan')
    local img = mesh.getImage('assets/parts/borsthaar7.png')
    msh:setTexture(img)
    love.graphics.draw(msh, x, y, r, sx, sy)
end

function drawSkinOver(box2dGuy, creation)
    love.graphics.setColor(1, 1, 1, 1)

    if creation then
        if creation.torso.metaURL then
            local x, y, r, sx, sy = renderMetaObject(torsoCanvas, 'torso', box2dGuy, creation)
            love.graphics.setColor(.4, 0, 0, .8)
            drawSquishableHairOver(x, y, r, sx, sy, creation)
            love.graphics.setColor(1, 1, 1, 1)
        end

        if box2dGuy.neck and box2dGuy.neck1 then
            love.graphics.setColor(1, 1, 1, 1)
            renderCurvedObject('neck', 'neck1', 'head', neckCanvas, neckmesh, box2dGuy)
            love.graphics.draw(neckmesh, 0, 0, 0, 1, 1)
        end

        if not creation.isPotatoHead then
            if creation.ear.metaURL then
                renderAtachedObject(earCanvas, 'lear', 'ear', -math.pi / 2, -1 * 2, -1 * 2, box2dGuy, creation)
                renderAtachedObject(earCanvas, 'rear', 'ear', math.pi / 2, 1 * 2, -1 * 2, box2dGuy, creation)
            end
        end

        love.graphics.setColor(0, 0, 0, 1)

        if not creation.isPotatoHead then
            if creation.head.metaURL then
                love.graphics.setColor(1, 1, 1, 1)
                local x, y, r, sx, sy = renderMetaObject(headCanvas, 'head', box2dGuy, creation)

                if true then
                    --  love.graphics.setColor(1, 0, 1, 1)
                    local f = creation.head.metaPoints

                    local leftEyeX = numbers.lerp(f[3][1], f[7][1], 0.2)
                    local rightEyeX = numbers.lerp(f[3][1], f[7][1], 0.8)
                    local eyelx, eyely = box2dGuy.head:getWorldPoint(
                            (leftEyeX + creation.head.metaOffsetX) * sx,
                            (f[3][2] + creation.head.metaOffsetY) * sy)

                    local eyerx, eyery = box2dGuy.head:getWorldPoint(
                            (rightEyeX + creation.head.metaOffsetX) * sx,
                            (f[3][2] + creation.head.metaOffsetY) * sy)

                    renderNonAttachedObject(eyeCanvas,
                        'eye', r, eyelx, eyely, -0.5, 0.5,
                        box2dGuy, creation)
                    renderNonAttachedObject(eyeCanvas,
                        'eye', r, eyerx, eyery, 0.5, 0.5,
                        box2dGuy, creation)

                    renderNonAttachedObject(pupilCanvas,
                        'pupil', r, eyelx, eyely, -0.5 / 2, 0.5 / 2,
                        box2dGuy, creation)
                    renderNonAttachedObject(pupilCanvas,
                        'pupil', r, eyerx, eyery, 0.5 / 2, 0.5 / 2,
                        box2dGuy, creation)


                    local noseX = numbers.lerp(f[3][1], f[7][1], 0.5)
                    local noseY = f[3][2] -- numbers.lerp(f[1][2], f[8][2], 0.25)

                    local nx, ny = box2dGuy.head:getWorldPoint(
                            (noseX + creation.head.metaOffsetX) * sx,
                            (noseY + creation.head.metaOffsetY) * sy)

                    local mouthX = numbers.lerp(f[3][1], f[7][1], 0.5)
                    local mouthY = numbers.lerp(f[1][1], f[8][1], 0.85) --f[3][2] -- numbers.lerp(f[1][2], f[8][2], 0.25)
                    local mx, my = box2dGuy.head:getWorldPoint(
                            (mouthX + creation.head.metaOffsetX) * sx,
                            (mouthY + creation.head.metaOffsetY) * sy)

                    local scaleX = 200 / teethCanvas:getWidth()
                    renderNonAttachedObject(teethCanvas,
                        'teeth', r, mx, my, scaleX, -1 * scaleX,
                        box2dGuy, creation)

                    local mouthmesh = createTexturedTriangleStrip(upperlipCanvas)
                    renderCurvedObjectFromSimplePoints({ -100, 0 }, { 0, -20 }, { 100, 0 }, upperlipCanvas,
                        mouthmesh, box2dGuy)
                    love.graphics.draw(mouthmesh, mx, my, r - math.pi, 1, 1)

                    mouthmesh = createTexturedTriangleStrip(lowerlipCanvas)

                    renderCurvedObjectFromSimplePoints({ -100, 0 }, { 0, 20 }, { 100, 0 }, upperlipCanvas,
                        mouthmesh, box2dGuy)
                    love.graphics.draw(mouthmesh, mx, my, r - math.pi, 1, 1)


                    renderNonAttachedObject(noseCanvas,
                        'nose', r, nx, ny, 0.5, -0.5,
                        box2dGuy, creation)
                end

                --            love.graphics.setColor(1, 0, 0, 1)
                love.graphics.setColor(0, 0, 0, 1)
                -- hair1x
                if true then
                    if true or box2dGuy.hairNeedsRedo then
                        --local img = mesh.getImage('assets/parts/hair1x.png')
                        local img = mesh.getImage('assets/parts/haarnew2.png')
                        local w, h = img:getDimensions()
                        local f = creation.head.metaPoints
                        -- note: make this a parameter
                        local hairLine = { f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[1] }

                        local hairLine = { f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[1] }
                        local hairLine = { f[3], f[4], f[5], f[6], f[7] }

                        local points = hairLine
                        local hairTension = .02
                        local spacing = 10
                        local coords

                        coords = border.unloosenVanillaline(points, hairTension, spacing)
                        local length = getLengthOfPath(hairLine)
                        local factor = (length / h)
                        --print(length)
                        local hairWidthMultiplier = .5
                        local width = (w * factor) * hairWidthMultiplier --30 --160 * 10
                        -- print(inspect(coords), inspect(points))
                        local verts, indices, draw_mode = polyline.render('miter', coords, width)

                        local vertsWithUVs = {}

                        for i = 1, #verts do
                            local u = (i % 2 == 1) and 0 or 1
                            local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                            vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
                        end
                        local vertices = vertsWithUVs
                        local m = love.graphics.newMesh(vertices, "strip")
                        --print(inspect(vertices))
                        m:setTexture(img)
                        love.graphics.draw(m, x, y, r, sx * creation.head.flipx, sy)
                    end
                end
            end
        end

        love.graphics.setColor(0, 0, 0, 1)

        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObject('luleg', 'llleg', 'lfoot', legCanvas, legmesh, box2dGuy)
        love.graphics.draw(legmesh, 0, 0, 0, 1, 1)
        renderCurvedObject('ruleg', 'rlleg', 'rfoot', legCanvas, legmesh, box2dGuy)
        love.graphics.draw(legmesh, 0, 0, 0, 1, 1)

        renderCurvedObject('luarm', 'llarm', 'lhand', armCanvas, armmesh, box2dGuy)
        love.graphics.draw(armmesh, 0, 0, 0, 1, 1)
        love.graphics.setColor(.4, 0, 0, .8)
        renderCurvedObject('luarm', 'llarm', 'lhand', image11, mesh11, box2dGuy, 1, 2)
        love.graphics.draw(mesh11, 0, 0, 0, 1, 1)
        love.graphics.setColor(1, 1, 1, 1)

        renderCurvedObject('ruarm', 'rlarm', 'rhand', armCanvas, armmesh, box2dGuy)
        love.graphics.draw(armmesh, 0, 0, 0, 1, 1)
        love.graphics.setColor(.4, 0, 0, .8)
        renderCurvedObject('ruarm', 'rlarm', 'rhand', image11, mesh11, box2dGuy, 1, 2)
        love.graphics.draw(mesh11, 0, 0, 0, 1, 1)
        love.graphics.setColor(1, 1, 1, 1)

        if creation.lhand.metaURL then
            renderAtachedObject(handCanvas, 'lhand', 'lhand', -math.pi / 2, 1, 1, box2dGuy, creation)
        end
        if creation.rhand.metaURL then
            renderAtachedObject(handCanvas, 'rhand', 'rhand', -math.pi / 2, 1, -1, box2dGuy, creation)
        end
        love.graphics.setColor(0, 0, 0, 1)

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
