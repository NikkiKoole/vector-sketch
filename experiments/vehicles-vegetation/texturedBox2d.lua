local parse    = require 'lib.parse-file'
local node     = require 'lib.node'
local inspect  = require 'vendor.inspect'
local mesh     = require 'lib.mesh'
local bbox     = require 'lib.bbox'

local polyline = require 'lib.polyline'
local unloop   = require 'lib.unpack-points'
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
            pivotX = bodyParts[i].transforms.l[6],
            pivotY = bodyParts[i].transforms.l[7]
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
    --local curveR = love.math.newBezierCurve({w, 0, w+offsetW, h/2, w, h})
    --local dr = curveR:getDerivative()



    --local curve = love.math.newBezierCurve({mx, my,  mx+50, my + 100, mx, my + 5})
    for i = 1, 1 do
        local w, h = image:getDimensions()
        local count = mesh:getVertexCount()

        for j = 1, count, 2 do
            local index  = (j - 1) / (count - 2)
            local xl, yl = curve:evaluate(index)
            --local xr,yr = curveR:evaluate(index)

            local dx, dy = dl:evaluate(index)
            local a      = math.atan2(dy, dx) + math.pi / 2
            local a2     = math.atan2(dy, dx) - math.pi / 2

            local line   = (w * dir) / scaleW --- here we can make the texture wider!!, also flip it
            local x2     = xl + line * math.cos(a)
            local y2     = yl + line * math.sin(a)
            local x3     = xl + line * math.cos(a2)
            local y3     = yl + line * math.sin(a2)

            if false then
                --love.graphics.line(xl,yl, x2, y2)
                --love.graphics.line(xl,yl, x3, y3)
            end

            local x, y, u, v, r, g, b, a = mesh:getVertex(j)
            mesh:setVertex(j, { x2, y2, u, v })
            x, y, u, v, r, g, b, a = mesh:getVertex(j + 1)
            mesh:setVertex(j + 1, { x3, y3, u, v })
        end
    end
    --love.graphics.draw(mesh2, mx, my, 0, flip, .5)
    --love.graphics.draw(mesh2, mx+488, my, 0, flip, .5)
    love.graphics.draw(mesh, 0, 0, 0, 1, 1)
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

function drawSkinOver(box2dGuy, creation)
    love.graphics.setColor(0, 0, 0, 1)
    if creation and creation.torso.metaURL then
        local img = mesh.getImage(creation.torso.metaURL)
        local w, h = img:getDimensions()
        local x, y = box2dGuy.torso:getPosition()
        local r = box2dGuy.torso:getAngle()

        local wscale = creation.torso.w / creation.torso.metaPointsW
        local hscale = creation.torso.h / creation.torso.metaPointsH

        local sx = (creation.torso.metaTexturePointsW / w) * wscale
        local sy = (creation.torso.metaTexturePointsH / h) * hscale


        love.graphics.draw(img, x, y, r, sx * creation.torso.flipx, sy * creation.torso.flipy, w / 2, h / 2)
    end


    if creation and creation.head.metaURL then
        local img = mesh.getImage(creation.head.metaURL)
        local w, h = img:getDimensions()

        local x, y = box2dGuy.head:getWorldPoint(0, 0)
        --print(x, y)
        --local x, y = box2dGuy.head:getPosition(0, -800)

        local r = box2dGuy.head:getAngle()
        --print(inspect(creation.head))
        local wscale = creation.head.w / creation.head.metaPointsW
        local hscale = creation.head.h / creation.head.metaPointsH

        local sx = (creation.head.metaTexturePointsW / w) * wscale
        local sy = (creation.head.metaTexturePointsH / h) * hscale

        if creation.head.metaOffsetX or creation.head.metaOffsetY then
            --     print('o!', creation.head.metaOffsetX, creation.head.metaOffsetY)
            x, y = box2dGuy.head:getWorldPoint(creation.head.metaOffsetX * wscale, creation.head.metaOffsetY * hscale)
        end

        love.graphics.draw(img, x, y, r, sx * creation.head
        .flipx, sy * creation.head.flipy, w / 2, h / 2)
    end




    love.graphics.setColor(0, 0, 0, 1)
    local ax, ay = box2dGuy.luleg:getPosition()
    local bx, by = box2dGuy.llleg:getPosition()
    local cx, cy = box2dGuy.lfoot:getPosition()


    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })
    --love.graphics.line(curve:render())


    texturedCurve(curve, image3, mesh3)

    -----
    local ax, ay = box2dGuy.ruleg:getPosition()
    local bx, by = box2dGuy.rlleg:getPosition()
    local cx, cy = box2dGuy.rfoot:getPosition()


    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })

    texturedCurve(curve, image3, mesh3)
    texturedCurve(curve, image9, mesh9, 1, 9)

    ----
    local ax, ay = box2dGuy.luarm:getPosition()
    local bx, by = box2dGuy.llarm:getPosition()
    local cx, cy = box2dGuy.lhand:getPosition()


    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, bx, by, cx, cy })
    -- love.graphics.line(curve:render())

    texturedCurve(curve, image5, mesh5)
    texturedCurve(curve, image9, mesh9, 1, 5)
    --texturedCurve(curve, image8, mesh8)


    ----
    local ax, ay = box2dGuy.ruarm:getPosition()
    local bx, by = box2dGuy.rlarm:getPosition()
    local cx, cy = box2dGuy.rhand:getPosition()


    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, bx, by, cx, cy })
    --  love.graphics.line(curve:render())

    texturedCurve(curve, image5, mesh5)
    --texturedCurve(curve, image6, mesh6)
end
