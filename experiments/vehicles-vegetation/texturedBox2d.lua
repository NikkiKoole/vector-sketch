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
local canvas   = require 'lib.canvas'

palettes       = {}
local base     = {
    '020202', '333233', '814800', 'e6c800', 'efebd8',
    '808b1c', '1a5f8f', '66a5bc', '87727b', 'a23d7e',
    'f0644d', 'fa8a00', 'f8df00', 'ff7376', 'fef1d0',
    'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
    '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
    'CB433A', '8F4839', '8A934E', '69445D', 'EEC488',
    'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
    '798091', '4C5575', '6E4431', '626964', '613D41',
}

local base     = {
    '020202',
    '4f3166', '6f323a', '872f44', 'efebd8', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
    'dca941', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
    '938541', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
    '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
    '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'a95c42', 'c37c61',
    'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
    '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'd76656', 'b16890'

}

local base     = {
    '020202',
    '4f3166', '69445D', '613D41', 'efebd8', '6f323a', '872f44', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
    'dca941', 'e6c800', 'f8df00', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
    '938541', '808b1c', '8A934E', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
    '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
    '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'CB433A', 'a95c42',
    'c37c61', 'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
    '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'f0644d', 'ff7376', 'd76656', 'b16890',
    '020202', '333233', '814800', 'efebd8',
    '1a5f8f', '66a5bc', '87727b', 'a23d7e',
    'fa8a00', 'fef1d0',
    'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
    '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
    '8F4839', 'EEC488',
    'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
    '798091', '4C5575', '6E4431', '626964',

}

textures       = {
    love.graphics.newImage('assets/bodytextures/texture-type0.png'),
    love.graphics.newImage('assets/bodytextures/texture-type2t.png'),
    love.graphics.newImage('assets/bodytextures/texture-type1.png'),
    love.graphics.newImage('assets/bodytextures/texture-type3.png'),
    love.graphics.newImage('assets/bodytextures/texture-type4.png'),
    love.graphics.newImage('assets/bodytextures/texture-type5.png'),
    love.graphics.newImage('assets/bodytextures/texture-type6.png'),
    love.graphics.newImage('assets/bodytextures/texture-type7.png'),

}

function hex2rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255
end

for i = 1, #base do
    local r, g, b = hex2rgb(base[i])
    table.insert(palettes, { r, g, b })
end
local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end

function helperTexturedCanvas(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, optionalSettings,
                              renderPatch)
    local img = mesh.getImage(url, optionalSettings)
    local maskUrl = getPNGMaskUrl(url)
    local mask = mesh.getImage(maskUrl)
    -- print(url)
    -- print(love.graphics.getDPIScale())
    local cnv = canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy,
            renderPatch)

    return cnv
end

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
        -- print(bodyParts[i].transforms.l[1], bodyParts[i].transforms.l[6])
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

--[[
  local texturedcanvas = helperTexturedCanvas(
           url,
           textures[values[partName].bgTex],
           palettes[values[partName].bgPal],
           values[partName].bgAlpha,
           textures[values[partName].fgTex],
           palettes[values[partName].fgPal],
           values[partName].fgAlpha,
           values[partName].texRot,
           texscales[values[partName].texScale],
           palettes[values[partName].linePal],
           values[partName].lineAlpha,
           flipX, flipY,
           optionalImageSettings,
           renderPatch
       )
]]
--


function drawSkinOver(box2dGuy, creation, cam)
    love.graphics.setColor(0, 0, 0, 1)
    if creation and creation.torso.metaURL then
        -- local maskUrl = getPNGMaskUrl(creation.torso.metaURL)
        -- print(maskUrl)
        cam:pop()
        local cnv = helperTexturedCanvas(creation.torso.metaURL, textures[1], palettes[1], 5, textures[2], palettes[34],
                5, 5, 5,
                palettes[55], 5, 1, 1, nil, nil)
        --print(cnv)
        --local url = creation.torso.metaURL

        --local cnv = canvas.makeTexturedCanvas2(mesh.getImage(url))
        cam:push()
        local img    = love.graphics.newImage(cnv)
        --local img    = mesh.getImage(creation.torso.metaURL)
        local w, h   = img:getDimensions()

        local x, y   = box2dGuy.torso:getPosition()
        local r      = box2dGuy.torso:getAngle()

        local wscale = creation.torso.w / creation.torso.metaPointsW
        local hscale = creation.torso.h / creation.torso.metaPointsH

        local sx     = (creation.torso.metaTexturePointsW / w) * wscale
        local sy     = (creation.torso.metaTexturePointsH / h) * hscale

        print(x, y, r, sx * creation.torso.flipx, sy * creation.torso.flipy, w / 2, h / 2)
        --  print(x, y, r, sx * creation.torso.flipx, sy * creation.torso.flipy, w / 2, h / 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, r, sx * creation.torso.flipx, sy * creation.torso.flipy, w / 2, h / 2)
        love.graphics.setColor(0, 0, 0, 1)
        --love.graphics.draw(img, x, y, r, 1, 1, w / 2, h / 2)
    end


    -- left ear
    if creation and creation.ear.metaURL then
        local img = mesh.getImage(creation.ear.metaURL)
        local w, h = img:getDimensions()

        local x, y = box2dGuy.lear:getWorldPoint(0, 0)
        local r = box2dGuy.lear:getAngle() - math.pi / 2

        local wscale = creation.ear.h / w * 2 --creation.lfoot.metaPointsW
        local hscale = creation.ear.w / h * 2 --creation.lfoot.metaPointsH

        local ox = creation.ear.metaPivotX - creation.ear.metaTexturePoints[1][1]
        local oy = creation.ear.metaPivotY - creation.ear.metaTexturePoints[1][2]

        love.graphics.draw(img, x, y, r, -wscale, -hscale, ox, oy)
    end

    if creation and creation.ear.metaURL then
        local img = mesh.getImage(creation.ear.metaURL)
        local w, h = img:getDimensions()

        local x, y = box2dGuy.rear:getWorldPoint(0, 0)
        local r = box2dGuy.rear:getAngle() + math.pi / 2

        local wscale = creation.ear.h / w * 2 --creation.lfoot.metaPointsW
        local hscale = creation.ear.w / h * 2 --creation.lfoot.metaPointsH

        local ox = creation.ear.metaPivotX - creation.ear.metaTexturePoints[1][1]
        local oy = creation.ear.metaPivotY - creation.ear.metaTexturePoints[1][2]

        love.graphics.draw(img, x, y, r, wscale, -hscale, ox, oy)
    end

    -- HHHEEEEAAADDD
    if not creation.isPotatoHead then
        if creation and creation.head.metaURL then
            local img = mesh.getImage(creation.head.metaURL)
            local w, h = img:getDimensions()
            local x, y = box2dGuy.head:getWorldPoint(0, 0)
            local r = box2dGuy.head:getAngle()
            local wscale = creation.head.w / creation.head.metaPointsW
            local hscale = creation.head.h / creation.head.metaPointsH
            local sx = (creation.head.metaTexturePointsW / w) * wscale
            local sy = (creation.head.metaTexturePointsH / h) * hscale

            if creation.head.metaOffsetX or creation.head.metaOffsetY then
                x, y = box2dGuy.head:getWorldPoint(creation.head.metaOffsetX * wscale, creation.head.metaOffsetY * hscale)
            end

            love.graphics.draw(img, x, y, r, sx * creation.head
            .flipx, sy * creation.head.flipy, w / 2, h / 2)


            if true then
                --  love.graphics.setColor(1, 0, 1, 1)
                local f = creation.head.metaPoints

                --for i = 1, #f do


                leftEyeX = numbers.lerp(f[3][1], f[7][1], 0.2)
                rightEyeX = numbers.lerp(f[3][1], f[7][1], 0.8)

                local eyelx, eyely = box2dGuy.head:getWorldPoint(
                        (leftEyeX + creation.head.metaOffsetX) * sx,
                        (f[3][2] + creation.head.metaOffsetY) * sy)

                local eyerx, eyery = box2dGuy.head:getWorldPoint(
                        (rightEyeX + creation.head.metaOffsetX) * sx,
                        (f[3][2] + creation.head.metaOffsetY) * sy)


                local img = mesh.getImage(creation.eye.metaURL)
                local w, h = img:getDimensions()

                local wscale = creation.eye.h / w --* 2 --creation.lfoot.metaPointsW
                local hscale = creation.eye.w / h --* 2 --creation.lfoot.metaPointsH


                local ox = creation.eye.metaPivotX - creation.eye.metaTexturePoints[1][1]
                local oy = creation.eye.metaPivotY - creation.eye.metaTexturePoints[1][2]


                love.graphics.draw(img, eyelx, eyely, r, wscale * 0.5 * -1, hscale * 0.5, ox, oy)
                love.graphics.draw(img, eyerx, eyery, r, wscale * 0.5, hscale * 0.5, ox, oy)
                --end
            end

            --            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.setColor(0, 0, 0, 1)
            -- hair1x
            if false then
                if true or box2dGuy.hairNeedsRedo then
                    local img = mesh.getImage('assets/parts/hair1x.png')
                    local w, h = img:getDimensions()
                    -- editingGuy.hair = updateChild(container, editingGuy.hair, createHairVanillaLine(values, hairLine))
                    --return createFromImage.vanillaline(
                    --    url, textured,
                    --        values.hairWidthMultiplier, values.hairTension, hairLine)
                    -- print(creation.head.flipy)
                    local f = creation.head.metaPoints
                    -- print(inspect(f))
                    local hairLine = { f[3], f[4], f[5], f[6], f[7] }
                    --for i = 1, #hairLine do
                    --  local eyelx, eyely = box2dGuy.head:getWorldPoint(
                    --          (hairLine[i][1] + creation.head.metaOffsetX) * sx,
                    --          (hairLine[i][2] + creation.head.metaOffsetY) * sy)
                    --love.graphics.circle('fill', eyelx, eyely, 5)
                    --print(getLengthOfPath(hairLine))


                    local points = hairLine
                    local hairTension = .02
                    local spacing = 3
                    local coords
                    --print('vanillaline stuff', shape.data)
                    --if shape.data and shape.data.tension then
                    coords = border.unloosenVanillaline(points, hairTension, spacing)
                    --else
                    --   coords = unloop.unpackNodePoints(points, false)
                    --end
                    local width = 160 * 3 -- shape.data and shape.data.width or 60
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
                    love.graphics.draw(m, x, y, r, sx * creation.head
                    .flipx, sy)

                    -- local factor = (length / height)
                    -- currentNode.data = {}
                    -- currentNode.data.width = (width * factor) * hairWidthMultiplier
                    -- currentNode.data.tension = hairTension
                    -- currentNode.data.spacing = 5



                    --love.graphics.draw(img, eyelx, eyely, r, wscale * 0.5 * -1, hscale * 0.5, w / 2, h / 2)
                    -- end
                end
            end
        end

        -- maybe start trying out to draw eyes and nose




        love.graphics.setColor(0, 0, 0, 1)
        if box2dGuy.neck and box2dGuy.neck1 then
            local ax, ay = box2dGuy.neck:getPosition()
            local bx, by = box2dGuy.neck1:getPosition()
            local cx, cy = box2dGuy.head:getPosition()


            local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })
            texturedCurve(curve, image10, mesh10)
        end


        love.graphics.setColor(0, 0, 0, 1)
        local ax, ay = box2dGuy.luleg:getPosition()
        local bx, by = box2dGuy.llleg:getPosition()
        local cx, cy = box2dGuy.lfoot:getPosition()


        local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })
        --love.graphics.line(curve:render())


        texturedCurve(curve, image10, mesh10)

        -----
        local ax, ay = box2dGuy.ruleg:getPosition()
        local bx, by = box2dGuy.rlleg:getPosition()
        local cx, cy = box2dGuy.rfoot:getPosition()


        local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })

        texturedCurve(curve, image1, mesh1)
        --texturedCurve(curve, image9, mesh9, 1, 9)

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

        if creation and creation.lhand.metaURL then
            local img = mesh.getImage(creation.lhand.metaURL)
            local w, h = img:getDimensions()

            local x, y = box2dGuy.lhand:getWorldPoint(0, 0)
            local r = box2dGuy.lhand:getAngle() - math.pi / 2

            local wscale = creation.lhand.h / w --creation.lfoot.metaPointsW
            local hscale = creation.lhand.w / h --creation.lfoot.metaPointsH

            local ox = creation.lhand.metaPivotX - creation.lhand.metaTexturePoints[1][1]
            local oy = creation.lhand.metaPivotY - creation.lhand.metaTexturePoints[1][2]

            love.graphics.setColor(1, 0, 0, 1)
            --love.graphics.print(r, x, y)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(img, x, y, r, wscale, hscale, ox, oy)
        end
        if creation and creation.rhand.metaURL then
            local img = mesh.getImage(creation.rhand.metaURL)
            local w, h = img:getDimensions()

            local x, y = box2dGuy.rhand:getWorldPoint(0, 0)
            local r = box2dGuy.rhand:getAngle() - math.pi / 2

            local wscale = creation.rhand.h / w --creation.lfoot.metaPointsW
            local hscale = creation.rhand.w / h --creation.lfoot.metaPointsH

            local ox = creation.rhand.metaPivotX - creation.rhand.metaTexturePoints[1][1]
            local oy = creation.rhand.metaPivotY - creation.rhand.metaTexturePoints[1][2]

            love.graphics.setColor(1, 0, 0, 1)
            --love.graphics.print(r, x, y)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(img, x, y, r, wscale, -hscale, ox, oy)
        end


        -- left foot
        if creation and creation.lfoot.metaURL then
            local img = mesh.getImage(creation.lfoot.metaURL)
            local w, h = img:getDimensions()

            local x, y = box2dGuy.lfoot:getWorldPoint(0, 0)
            local r = box2dGuy.lfoot:getAngle() - math.pi / 2

            local wscale = creation.lfoot.h / w --creation.lfoot.metaPointsW
            local hscale = creation.lfoot.w / h --creation.lfoot.metaPointsH

            local ox = creation.lfoot.metaPivotX - creation.lfoot.metaTexturePoints[1][1]
            local oy = creation.lfoot.metaPivotY - creation.lfoot.metaTexturePoints[1][2]
            love.graphics.setColor(1, 0, 0, 1)
            -- love.graphics.print(r, x, y)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(img, x, y, r, wscale * 1.1, hscale * 1.1, ox, oy)
        end
        -- right foot
        if creation and creation.rfoot.metaURL then
            local img = mesh.getImage(creation.rfoot.metaURL)
            local w, h = img:getDimensions()

            local x, y = box2dGuy.rfoot:getWorldPoint(0, 0)
            local r = box2dGuy.rfoot:getAngle() + math.pi / 2

            local wscale = creation.rfoot.h / w --creation.lfoot.metaPointsW
            local hscale = creation.rfoot.w / h --creation.lfoot.metaPointsH

            local ox = creation.rfoot.metaPivotX - creation.rfoot.metaTexturePoints[1][1]
            local oy = creation.rfoot.metaPivotY - creation.rfoot.metaTexturePoints[1][2]
            love.graphics.setColor(1, 0, 0, 1)
            --   love.graphics.print(r, x, y)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(img, x, y, r, -wscale * 1.1, hscale * 1.1, ox, oy)
        end
    end
end
