local inspect          = require 'vendor.inspect'
local mesh             = require 'lib.mesh'
local polyline         = require 'lib.polyline'
local numbers          = require 'lib.numbers'
local border           = require 'lib.border-mesh'
local cam              = require('lib.cameraBase').getInstance()
local canvas           = require 'lib.canvas'
local text             = require 'lib.text'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local mathutils        = require 'src.math-utils'

local lib              = {}



-- todo this is annoying, every lib that uses textured Box now neds these images...
textures = {
    love.graphics.newImage('assets/img/bodytextures/texture-type0.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type2t.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type1.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type3.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type4.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type5.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type6.png'),
    love.graphics.newImage('assets/img/bodytextures/texture-type7.png'),
    love.graphics.newImage('assets/img/tiles/tiles2.png'),
    love.graphics.newImage('assets/img/tiles/tiles.png'),
}


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

local function texturedCurve(curve, image, mesh, dir, scaleW)
    if not dir then dir = 1 end
    if not scaleW then scaleW = 1 end
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

local function drawTorsoOver(box2dTorso)
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

local function drawPlantOver(data, i)
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

function lib.getValues(img, name, box2dGuy, creation)
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
    return x, y, r, sx, sy
end

local function renderMetaObject(img, name, box2dGuy, creation)
    local w, h            = img:getDimensions()
    local x, y, r, sx, sy = lib.getValues(img, name, box2dGuy, creation)
    love.graphics.draw(img, x, y, r, sx * creation[name].flipx, sy * creation[name].flipy, w / 2, h / 2)

    return x, y, r, sx, sy
end

-- note : DONT USE THE sx/sy multiplier to support all types of sizes,
-- just use it for flipping with -1+1 and optionally addsome kind of divider if , for example, all ear images are drawn x2 too big
local function renderAtachedObject(img, name, nameP, extraR, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local x, y = box2dGuy[name]:getWorldPoint(0, 0)
    local r = box2dGuy[name]:getAngle() + extraR
    local wscale = creation[nameP].h / w -- flipped because this is about foot and hands
    local hscale = creation[nameP].w / h
    local ox = creation[nameP].metaPivotX - creation[nameP].metaTexturePoints[1][1]
    local oy = creation[nameP].metaPivotY - creation[nameP].metaTexturePoints[1][2]
    local dpi = 1 --love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox * dpi / shrink, oy * dpi / shrink)
end

local function renderNonAttachedObject(img, name, r, x, y, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local wscale = creation[name].w / h
    local hscale = creation[name].h / w
    local ox = creation[name].metaPivotX - creation[name].metaTexturePoints[1][1]
    local oy = creation[name].metaPivotY - creation[name].metaTexturePoints[1][2]
    local dpi = 1 --love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, ox * dpi / shrink, oy * dpi / shrink)
end

local function renderNonAttachedObject2(img, name, r, x, y, sxMultiplier, syMultiplier, box2dGuy, creation)
    local img = img
    local w, h = img:getDimensions()
    local wscale = creation[name].h / h
    local hscale = creation[name].w / w
    local ox = creation[name].metaPivotX - creation[name].metaTexturePoints[1][1]
    local oy = creation[name].metaPivotY - creation[name].metaTexturePoints[1][2]
    local dpi = 1 -- love.graphics.getDPIScale()
    local shrink = canvas:getShrinkFactor()

    love.graphics.draw(img, x, y, r, wscale * sxMultiplier, hscale * syMultiplier, w / 2, h / 2)
end

local function growLine(p1, p2, length)
    local angle = math.atan2(p1[2] - p2[2], p1[1] - p2[1])
    local new_x = p1[1] + length * math.cos(angle)
    local new_y = p1[2] + length * math.sin(angle)
    return new_x, new_y
end

local function renderCurvedObjectGrow(p1, p2, p3, growLength, canvas, mesh, box2dGuy, dir, wmultiplier)
    local ax, ay = box2dGuy[p1]:getPosition()
    local bx, by = box2dGuy[p2]:getPosition()
    local cx, cy = box2dGuy[p3]:getPosition()

    ax, ay = growLine({ ax, ay }, { bx, by }, growLength)
    cx, cy = growLine({ cx, cy }, { bx, by }, growLength)

    local curve = love.math.newBezierCurve({ ax, ay, bx, by, bx, by, cx, cy })

    if (dir ~= nil or wmultiplier ~= nil) then
        texturedCurve(curve, canvas, mesh, dir, wmultiplier)
    else
        texturedCurve(curve, canvas, mesh)
    end
end

local function renderCurvedObject(p1, p2, p3, canvas, mesh, box2dGuy, dir, wmultiplier)
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

local function renderCurvedObjectFromSimplePoints(p1, p2, p3, canvas, mesh, box2dGuy, dir, wmultiplier)
    local curve = love.math.newBezierCurve({ p1[1], p1[2], p2[1], p2[2], p2[1], p2[2], p3[1], p3[2] })
    if (dir ~= nil or wmultiplier ~= nil) then
        texturedCurve(curve, canvas, mesh, dir, wmultiplier)
    else
        texturedCurve(curve, canvas, mesh, -1, 1 / 3)
    end

    return curve
end

local function getDimensions(points)
    local tlx, tly = math.huge, math.huge
    local brx, bry = -math.huge, -math.huge
    for i = 1, #points do
        local it = points[i]
        if it[1] < tlx then tlx = it[1] end
        if it[1] > brx then brx = it[1] end
        if it[2] < tly then tly = it[2] end
        if it[2] > bry then bry = it[2] end
    end

    return tlx, tly, brx, bry
end
lib.makeSquishableHairOverMesh = function(img, growFactor, creation)
    local f = creation.torso.metaPoints
    local p = {}
    for i = 1, #f do
        p[i] = {}
        p[i][1] = f[i][1] * 1.3 * growFactor
        p[i][2] = f[i][2] * 1.3 * growFactor
    end

    local points = { { 0, 0 }, p[8], p[1], p[2], p[3], p[4], p[5], p[6], p[7] }
    local uvs = mesh.makeSquishableUVsFromPoints(points)
    local _mesh = love.graphics.newMesh(uvs, 'fan')
    local img = img
    _mesh:setTexture(img)


    local tlx, tly, brx, bry = getDimensions(points)
    local w = brx - tlx
    local h = bry - tly
    local canvas = love.graphics.newCanvas(w * 1, h * 1)
    print(w, h)
    local mx, my = tlx + w / 2, tly + h / 2
    love.graphics.setCanvas(canvas)
    love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.draw(_mesh, -tlx, -tly, 0, 10, 10)
    love.graphics.rectangle('fill', 0, 0, 1000, 1000)
    love.graphics.setCanvas()

    return _mesh, canvas
end

lib.makeCanvasFromMesh = function(mesh)
    local width, height = getDimensions()
    local result = love.graphics.newCanvas(width, height, { dpiscale = 1 })
end

local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, creation)
    -- first get the polygon from the meta object that describes the shape in 8 points
    -- optionally grow that polygon outwards from the middle
    local f = creation.torso.metaPoints
    local p = {}
    for i = 1, #f do
        p[i] = {}
        p[i][1] = f[i][1] * 1.3 * growFactor
        p[i][2] = f[i][2] * 1.3 * growFactor
    end

    local points = { { 0, 0 }, p[8], p[1], p[2], p[3], p[4], p[5], p[6], p[7] }
    local uvs = mesh.makeSquishableUVsFromPoints(points)
    local _mesh = love.graphics.newMesh(uvs, 'fan')
    local img = img
    _mesh:setTexture(img)

    love.graphics.draw(_mesh, x, y, r, sx, sy)
end

local function renderHair(box2dGuy, guy, faceData, creation, multipliers, x, y, r, sx, sy)
    local canvasCache = guy.canvasCache
    local dpi = 1 --love.graphics.getDPIScale()
    local shrink = canvas.getShrinkFactor()
    if true then
        if true or box2dGuy.hairNeedsRedo then
            local img = canvasCache.hairCanvas
            local w, h = img:getDimensions()
            local f = faceData.metaPoints
            -- todo parameter hair (beard, only top hair, sidehair)
            --local hairLine = { f[6], f[7], f[8], f[1], f[2], f[3], f[4] }
            local hairLine = { f[7], f[8], f[1], f[2], f[3] }
            -- local hairLine = { f[8], f[1], f[2] }
            -- print(inspect(hairLine))
            --local hairLine = { f[3], f[4], f[5], f[6], f[7] }
            local points = hairLine
            local hairTension = .02
            local spacing = 10 * multipliers.hair.sMultiplier
            local coords

            coords = mathutils.unloosenVanillaline(points, hairTension, spacing)

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

local function drawMouth(facePart, faceData, creation, guy, box2dGuy, sx, sy, multipliers, positioners, r)
    local canvasCache = guy.canvasCache
    local hMult = multipliers.mouth.hMultiplier
    local wMult = multipliers.mouth.wMultiplier
    local f = faceData.metaPoints
    local dpi = 1 --love.graphics.getDPIScale()
    local shrink = canvas.getShrinkFactor()
    local mouthX = numbers.lerp(f[3][1], f[7][1], 0.5)
    local mouthY = numbers.lerp(f[1][2], f[5][2], (1 - positioners.mouth.y))
    local mx, my = facePart:getWorldPoint(
        (mouthX + faceData.metaOffsetX) * sx * dpi / shrink,
        (mouthY + faceData.metaOffsetY) * sy * dpi / shrink)
    local tx, ty = facePart:getWorldPoint(
        (mouthX + faceData.metaOffsetX) * sx * dpi / shrink,
        (mouthY + faceData.metaOffsetY - 20) * sy * dpi / shrink)

    local mouthWidth = (wMult * (f[3][1] - f[7][1]) / 2)
    local scaleX = (mouthWidth / wMult) / canvasCache.teethCanvas:getWidth()
    local upperlipmesh = lib.createTexturedTriangleStrip(canvasCache.upperlipCanvas)

    mouthWidth = mouthWidth * (guy.tweenVars.mouthWide) --- do the mouth anim wideness here
    local mouthOpen = 20 * (guy.tweenVars.mouthOpen)
    --print(mouthOpen, guy.tweenVars.mouthOpen)

    local upperCurve = renderCurvedObjectFromSimplePoints({ -mouthWidth / 2, 0 },
        { 0, -mouthOpen },
        { mouthWidth / 2, 0 },
        canvasCache.upperlipCanvas,
        upperlipmesh, box2dGuy, -1 * hMult, .5 * scaleX)
    local lowerlipmesh = lib.createTexturedTriangleStrip(canvasCache.lowerlipCanvas)
    local lowerCurve = renderCurvedObjectFromSimplePoints({ -mouthWidth / 2, 0 },
        { 0, mouthOpen },
        { mouthWidth / 2, 0 },
        canvasCache.upperlipCanvas,
        lowerlipmesh, box2dGuy, -1 * hMult, .5 * scaleX)

    local holePolygon = {}
    for i = 0, 6 do
        local x, y = upperCurve:evaluate(i / 6)
        table.insert(holePolygon, { x, y })
    end
    for i = 0, 6 do
        local x, y = lowerCurve:evaluate(1 - (i / 6))
        table.insert(holePolygon, { x, y })
    end

    local holeMesh = love.graphics.newMesh(holePolygon, "fan")
    local myStencilFunction = function()
        love.graphics.draw(holeMesh, mx, my, r - math.pi, 1, 1)
    end

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(holeMesh, mx, my, r - math.pi, 1, 1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.stencil(myStencilFunction, "replace", 1)

    love.graphics.setStencilTest("greater", 0)


    --if positioners.teeth.z == 0 then
    if not box2dGuyCreation.isNullObject('teeth', guy.dna.values) then
        if canvasCache.teethCanvas then
            renderNonAttachedObject(canvasCache.teethCanvas,
                'teeth', r, tx, ty, 10, -10 * multipliers.teeth.hMultiplier,
                box2dGuy, creation)
        end
    end
    --end

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
local function setAngleAndDistanceX2(sx, sy, angle, distanceX, distanceY, scaleX, scaleY)
    local newx = sx + (distanceX * scaleX) * math.cos(angle)
    local newy = sy + (distanceY * scaleY) * math.sin(angle)
    return newx, newy
end



local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end

local function helperTexturedCanvas(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, optionalSettings,
                                    renderPatch)
    --print(url)
    local img = mesh.getImage(url, optionalSettings)
    local maskUrl = getPNGMaskUrl(url)
    local mask = mesh.getImage(maskUrl)
    -- print(url)
    -- print(love.graphics.getDPIScale())
    local cnv = canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy,
        renderPatch)

    return cnv
end

local function createRandomColoredBlackOutlineTexture(url, optionalPart)
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[math.ceil(math.random() * #palettes)]
    local al1 = 5
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[math.ceil(math.random() * #palettes)]
    local al2 = 2

    local lineP = palettes[1]
    local lineA = 5

    local tr = 0
    local ts = 1
    if optionalPart then
        tex1 = textures[optionalPart.bgTex]
        pal1 = palettes[optionalPart.bgPal]
        al1 = optionalPart.bgAlpha
        tex2 = textures[optionalPart.fgTex]
        pal2 = palettes[optionalPart.fgPal]
        al2 = optionalPart.fgAlpha
        lineP = palettes[optionalPart.linePal]
        lineA = optionalPart.lineAlpha
        tr = optionalPart.texRot
        ts = optionalPart.texScale
    end

    local renderPatch = {}

    return love.graphics.newImage(helperTexturedCanvas(url,
        tex1, pal1, al1,
        tex2, pal2, al2,
        tr, ts,
        lineP, lineA,
        1, 1, nil, renderPatch))
end


local texscales = { 0.06, 0.12, 0.24, 0.48, 0.64, 0.96, 1.28, 1.64, 2.56 }
local function partToTexturedCanvas(partName, guy, optionalImageSettings)
    local creation = guy.dna.creation
    local values = guy.dna.values

    local p = findPart(partName)
    local url = p.imgs[values[partName].shape]


    local renderPatch = {}

    if (partName == 'head') then
        if not box2dGuyCreation.isNullObject('skinPatchSnout', values) then
            local p = {}
            p.imageData = partToTexturedCanvas('skinPatchSnout', guy)
            p.sx = values.skinPatchSnoutPV.sx
            p.sy = values.skinPatchSnoutPV.sy
            p.r = values.skinPatchSnoutPV.r
            p.tx = values.skinPatchSnoutPV.tx * creation.head.flipx
            p.ty = values.skinPatchSnoutPV.ty * creation.head.flipy
            table.insert(renderPatch, p)
        end
        if not box2dGuyCreation.isNullObject('skinPatchEye1', values) then
            local p     = {}
            p.imageData = partToTexturedCanvas('skinPatchEye1', guy)
            p.sx        = values.skinPatchEye1PV.sx
            p.sy        = values.skinPatchEye1PV.sy
            p.r         = values.skinPatchEye1PV.r
            p.tx        = values.skinPatchEye1PV.tx * creation.head.flipx
            p.ty        = values.skinPatchEye1PV.ty * creation.head.flipy
            table.insert(renderPatch, p)
        end
        if not box2dGuyCreation.isNullObject('skinPatchEye2', values) then
            local p     = {}
            p.imageData = partToTexturedCanvas('skinPatchEye2', guy)
            p.sx        = values.skinPatchEye2PV.sx
            p.sy        = values.skinPatchEye2PV.sy
            p.r         = values.skinPatchEye2PV.r
            p.tx        = values.skinPatchEye2PV.tx * creation.head.flipx
            p.ty        = values.skinPatchEye2PV.ty * creation.head.flipy
            table.insert(renderPatch, p)
        end
    end

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
        1, 1,
        optionalImageSettings,
        renderPatch
    )
    return texturedcanvas, url
end

lib.partToTexturedCanvasWrap = function(partName, guy, optionalImageSettings)
    local a, b = partToTexturedCanvas(partName, guy, optionalImageSettings)
    return love.graphics.newImage(a)
end


lib.createWhiteColoredBlackOutlineTexture = function(url)
    -- todo make this more optimal and readable, 5 is white in any case
    local tex1 = textures[math.ceil(math.random() * #textures)]
    local pal1 = palettes[5]
    local tex2 = textures[math.ceil(math.random() * #textures)]
    local pal2 = palettes[5]

    return love.graphics.newImage(helperTexturedCanvas(url,
        tex1, pal1, 5,
        tex2, pal2, 2,
        0, 1,
        palettes[1], 5,
        1, 1, nil, nil))
end


lib.createTexturedTriangleStrip = function(image, optionalWidthMultiplier)
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

lib.drawSpriet = function(x, y, index, r, sy)
    local img = spriet[index]
    local w, h = img:getDimensions()
    love.graphics.draw(img, x, y, r, 1, sy, w, h)
end

lib.drawNumbersOver = function(box2dGuy)
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

local function createFittingScale(img, desired_w, desired_h)
    local w, h = img:getDimensions()
    local sx, sy = desired_w / w, desired_h / h
    return sx, sy
end


lib.drawTurboButtons = function(items)
    --print(items, #items)
    for i = 1, #items do
        local body = items[i].body
        local color = { 1, 0, 0 }
        local type = items[i].type
        local x, y = body:getPosition()

        local factor = 1.1
        local shade = 0.2
        if type == 'ruit' then
            --  print('getting here')
            local rndIndex = (items[i].index % 2) + 1
            local w = items[i].w
            local h = items[i].h
            local img = winegums.ruits[1]
            love.graphics.setColor(1, 1, 1)
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle() + love.timer.getTime() * 3, sx, sy, img:getWidth() / 2,
                img:getHeight() / 2)

            if false then
                local img = winegums.ruits[2]
                love.graphics.setColor(1, 0, 0)
                local sx, sy = createFittingScale(img, w * factor, h * factor)
                love.graphics.draw(img, x, y, body:getAngle() + love.timer.getTime() * 3, sx, sy, img:getWidth() / 2,
                    img:getHeight() / 2)
                love.graphics.setColor(0, 1, 0)
                local sx, sy = createFittingScale(img, w * factor, h * factor)
                love.graphics.draw(img, x, y, body:getAngle() + love.timer.getTime() * 2, sx, sy, img:getWidth() / 2,
                    img:getHeight() / 2)
                love.graphics.setColor(0, 0, 1)
                local sx, sy = createFittingScale(img, w * factor, h * factor)
                love.graphics.draw(img, x, y, body:getAngle() + love.timer.getTime() * 4, sx, sy, img:getWidth() / 2,
                    img:getHeight() / 2)
            end
        end
    end
end

lib.drawWineGums = function(items)
    for i = 1, #items do
        local body = items[i].body

        local color = items[i].color
        local type = items[i].type
        local x, y = body:getPosition()

        local factor = 1.1
        local shade = 0.8

        if type == 'circle' then
            local rndIndex = (items[i].index % 2) + 1
            local size = items[i].w
            love.graphics.setColor(color[1], color[2], color[3])
            local img = winegums.circs[rndIndex + 0]
            local sx, sy = createFittingScale(img, size * 2.1, size * 2.1)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)

            --  love.graphics.draw(img, x,y, body:getAngle(), sx, sy, img:getWidth()/2, img:getHeight()/2)
            --  local imgIndex = (items[i].index % #circles) + 1
            local img = winegums.circs[rndIndex + 1]
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            local sx, sy = createFittingScale(img, size * 2, size * 2)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
            -- print(img,  body,color) end
        end
        if type == 'capsule2' then
            local rndIndex = (items[i].index % 2) + 1
            local w = items[i].w
            local h = items[i].h
            local img = winegums.capsules[rndIndex + 0]
            love.graphics.setColor(color[1], color[2], color[3])
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
            local img = winegums.capsules[rndIndex + 1]
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
        end
        if type == 'ruit' then
            local rndIndex = (items[i].index % 2) + 1
            local w = items[i].w
            local h = items[i].h
            local img = winegums.ruits[rndIndex + 0]
            love.graphics.setColor(color[1], color[2], color[3])
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
            local img = winegums.ruits[rndIndex + 1]
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
        end
        if type == 'octagon' then
            local rndIndex = (items[i].index % 2) + 1
            local w = items[i].w
            local h = items[i].h
            local img = winegums.octas[rndIndex + 0]
            love.graphics.setColor(color[1], color[2], color[3])
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
            local img = winegums.octas[rndIndex + 1]
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
        end

        if type == 'rect3' then
            local rndIndex = (items[i].index % 2) + 1
            local w = items[i].w
            local h = items[i].h
            local img = winegums.rekts[rndIndex + 0]
            love.graphics.setColor(color[1], color[2], color[3])
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
            local img = winegums.rekts[rndIndex + 1]
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            local sx, sy = createFittingScale(img, w * factor, h * factor)
            love.graphics.draw(img, x, y, body:getAngle(), sx, sy, img:getWidth() / 2, img:getHeight() / 2)
        end
    end
end

-- this function is here fo when a mipo is on a bike, i can draw that bodypart separately over the bike
lib.renderLeftLegAndHair = function(box2dGuy, guy)
    local values = guy.dna.values
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local positioners = guy.dna.positioners
    local canvasCache = guy.canvasCache

    local facing = guy.facingVars
    love.graphics.setColor(1, 1, 1, 1)
    local dpi = 1
    local shrink = canvas.getShrinkFactor()
    if canvasCache.legCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObjectGrow('luleg', 'llleg', 'lfoot', 25, canvasCache.legCanvas, canvasCache.legmesh, box2dGuy, 1,
            shrink * multipliers.leg.wMultiplier / (4 * dpi))
        love.graphics.draw(canvasCache.legmesh, 0, 0, 0, 1, 1)
    end
    if not box2dGuyCreation.isNullObject('leghair', values) and canvasCache.leghairCanvas then
        renderCurvedObject('luleg', 'llleg', 'lfoot', canvasCache.leghairCanvas, canvasCache.leghairMesh, box2dGuy,
            -1,
            (multipliers.leg.wMultiplier * multipliers.leghair.wMultiplier) / (4 * dpi))
        love.graphics.draw(canvasCache.leghairMesh, 0, 0, 0, 1, 1)
    end
    if canvasCache.footCanvas then
        local yScale = 1.1
        if guy.facingVars.legs == 'right' then
            yScale = -1.1
        end
        if creation.lfoot.metaURL then
            love.graphics.setColor(1, 1, 1, 1)
            renderAtachedObject(canvasCache.footCanvas, 'lfoot', 'lfoot', -math.pi / 2, 1.1, yScale, box2dGuy,
                creation)
        end
    end
end
-- this function is here fo when a mipo is on a bike, i can draw that bodypart separately over the bike
lib.renderLeftArmAndHair = function(box2dGuy, guy)
    local values = guy.dna.values
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local positioners = guy.dna.positioners
    local canvasCache = guy.canvasCache

    local facing = guy.facingVars
    love.graphics.setColor(1, 1, 1, 1)
    local dpi = 1
    local shrink = canvas.getShrinkFactor()

    if canvasCache.armCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObjectGrow('luarm', 'llarm', 'lhand', 25, canvasCache.armCanvas, canvasCache.armmesh, box2dGuy, 1,
            shrink * multipliers.arm.wMultiplier / (4 * dpi))
        love.graphics.draw(canvasCache.armmesh, 0, 0, 0, 1, 1)
    end
    if not box2dGuyCreation.isNullObject('armhair', values) and canvasCache.armhairCanvas then
        renderCurvedObject('luarm', 'llarm', 'lhand', canvasCache.armhairCanvas, canvasCache.armhairMesh, box2dGuy,
            -1,
            (multipliers.arm.wMultiplier * multipliers.armhair.wMultiplier) / (4 * dpi))
        love.graphics.draw(canvasCache.armhairMesh, 0, 0, 0, 1, 1)
    end

    if canvasCache.handCanvas then
        renderAtachedObject(canvasCache.handCanvas, 'lhand', 'lhand', -math.pi / 2, 1, 1, box2dGuy, creation)
    end
end



local weirdCanvas = nil


lib.drawSkinOverMultiple = function(list)
    local dpi = 1
    local shrink = canvas.getShrinkFactor()
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, #list do
        local guy = list[i]
        local values = guy.dna.values
        local creation = guy.dna.creation
        local multipliers = guy.dna.multipliers
        local positioners = guy.dna.positioners
        local canvasCache = guy.canvasCache
        local facing = guy.facingVars
        local box2dGuy = guy.b2d

        if creation.torso.metaURL and not creation.isPotatoHead then
            --  print(i, x, y)
            local x, y, r, sx, sy = renderMetaObject(canvasCache.torsoCanvas, 'torso', box2dGuy, creation)
            --if not box2dGuyCreation.isNullObject('chestHair', values) then
            --    drawSquishableHairOver(canvasCache.chestHairCanvas, x, y, r, sx * dpi / shrink,
            --        sy * dpi / shrink, multipliers.chesthair.mMultiplier, creation)
            -- end
            --love.graphics.setColor(1, 1, 1, 1)
        end
    end
    for i = 1, #list do
        local guy = list[i]
        local values = guy.dna.values
        local creation = guy.dna.creation
        local multipliers = guy.dna.multipliers
        local positioners = guy.dna.positioners
        local canvasCache = guy.canvasCache
        local facing = guy.facingVars
        local box2dGuy = guy.b2d




        if not canvasCache.weirdCanvas then
            -- local x, y, r, sx, sy     = lib.getValues(canvasCache.torsoCanvas, 'torso', guy.b2d, creation)
            canvasCache.chestHairMesh, canvasCache.weirdCanvas = lib.makeSquishableHairOverMesh(
                canvasCache.chestHairCanvas,
                multipliers.chesthair.mMultiplier,
                creation)
        end
        -- print(canvasCache.chestHairMesh)

        local x, y, r, sx, sy = renderMetaObject(canvasCache.torsoCanvas, 'torso', box2dGuy, creation)
        --end
        if creation.torso.metaURL and not creation.isPotatoHead then
            --  print(i, x, y)s
            local x, y, r, sx, sy = lib.getValues(canvasCache.torsoCanvas, 'torso', guy.b2d, creation)
            if not box2dGuyCreation.isNullObject('chestHair', values) then
                -- print(canvasCache.chestHairMesh)
                love.graphics.draw(canvasCache.chestHairCanvas, x, y, r, sx * dpi / shrink, sy * dpi / shrink)
                if (canvasCache.weirdCanvas) then
                    print('getting here')
                    love.graphics.draw(canvasCache.weirdCanvas, x, y, r, 10, 10)
                end
                --local x, y, r, sx, sy = lib.getValues(canvasCache.torsoCanvas, 'torso', guy.b2d, creation)
                --drawSquishableHairOver(canvasCache.chestHairCanvas, x, y, r, sx * dpi / shrink,
                --    sy * dpi / shrink, multipliers.chesthair.mMultiplier, creation)
            end
        end
    end
end

lib.drawSkinOver = function(box2dGuy, guy, skipList)
    --print(skipNeck)
    local values = guy.dna.values
    local creation = guy.dna.creation
    local multipliers = guy.dna.multipliers
    local positioners = guy.dna.positioners
    local canvasCache = guy.canvasCache

    local facing = guy.facingVars
    love.graphics.setColor(1, 1, 1, 1)
    local dpi = 1
    local shrink = canvas.getShrinkFactor()


    local function renderLeftLegAndHair()
        if canvasCache.legCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            renderCurvedObjectGrow('luleg', 'llleg', 'lfoot', 25, canvasCache.legCanvas, canvasCache.legmesh, box2dGuy, 1,
                shrink * multipliers.leg.wMultiplier / (4 * dpi))
            love.graphics.draw(canvasCache.legmesh, 0, 0, 0, 1, 1)
        end
        if not box2dGuyCreation.isNullObject('leghair', values) and canvasCache.leghairCanvas then
            renderCurvedObject('luleg', 'llleg', 'lfoot', canvasCache.leghairCanvas, canvasCache.leghairMesh, box2dGuy,
                -1,
                (multipliers.leg.wMultiplier * multipliers.leghair.wMultiplier) / (4 * dpi))
            love.graphics.draw(canvasCache.leghairMesh, 0, 0, 0, 1, 1)
        end
        if canvasCache.footCanvas then
            local yScale = 1.1
            if guy.facingVars.legs == 'right' then
                yScale = -1.1
            end
            if creation.lfoot.metaURL then
                love.graphics.setColor(1, 1, 1, 1)
                renderAtachedObject(canvasCache.footCanvas, 'lfoot', 'lfoot', -math.pi / 2, 1.1, yScale, box2dGuy,
                    creation)
            end
        end
    end

    local function renderRightLegAndHair()
        if canvasCache.legCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            renderCurvedObjectGrow('ruleg', 'rlleg', 'rfoot', 25, canvasCache.legCanvas, canvasCache.legmesh,
                box2dGuy, 1,
                shrink * multipliers.leg.wMultiplier / (4 * dpi))
            love.graphics.draw(canvasCache.legmesh, 0, 0, 0, 1, 1)
        end
        if not box2dGuyCreation.isNullObject('leghair', values) and canvasCache.leghairCanvas then
            renderCurvedObject('ruleg', 'rlleg', 'rfoot', canvasCache.leghairCanvas, canvasCache.leghairMesh,
                box2dGuy, 1,
                (multipliers.leg.wMultiplier * multipliers.leghair.wMultiplier) / (4 * dpi))
            love.graphics.draw(canvasCache.leghairMesh, 0, 0, 0, 1, 1)
        end
        if canvasCache.footCanvas then
            local yScale = 1.1
            if guy.facingVars.legs == 'left' then
                yScale = -1.1
            end
            renderAtachedObject(canvasCache.footCanvas, 'rfoot', 'rfoot', math.pi / 2, -1.1, yScale, box2dGuy, creation)
        end
    end

    local function renderLeftArmAndHair()
        if canvasCache.armCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            renderCurvedObjectGrow('luarm', 'llarm', 'lhand', 25, canvasCache.armCanvas, canvasCache.armmesh, box2dGuy, 1,
                shrink * multipliers.arm.wMultiplier / (4 * dpi))
            love.graphics.draw(canvasCache.armmesh, 0, 0, 0, 1, 1)
        end
        if not box2dGuyCreation.isNullObject('armhair', values) and canvasCache.armhairCanvas then
            renderCurvedObject('luarm', 'llarm', 'lhand', canvasCache.armhairCanvas, canvasCache.armhairMesh, box2dGuy,
                -1,
                (multipliers.arm.wMultiplier * multipliers.armhair.wMultiplier) / (4 * dpi))
            love.graphics.draw(canvasCache.armhairMesh, 0, 0, 0, 1, 1)
        end

        if canvasCache.handCanvas then
            renderAtachedObject(canvasCache.handCanvas, 'lhand', 'lhand', -math.pi / 2, 1, 1, box2dGuy, creation)
        end
    end

    local function renderRightArmAndHair()
        if canvasCache.armCanvas then
            love.graphics.setColor(1, 1, 1, 1)
            renderCurvedObjectGrow('ruarm', 'rlarm', 'rhand', 25, canvasCache.armCanvas, canvasCache.armmesh, box2dGuy, 1,
                shrink * multipliers.arm.wMultiplier / (4 * dpi))
            love.graphics.draw(canvasCache.armmesh, 0, 0, 0, 1, 1)
        end
        if not box2dGuyCreation.isNullObject('armhair', values) and canvasCache.armhairCanvas then
            renderCurvedObject('ruarm', 'rlarm', 'rhand', canvasCache.armhairCanvas, canvasCache.armhairMesh, box2dGuy, 1,
                (multipliers.arm.wMultiplier * multipliers.armhair.wMultiplier) / (4 * dpi))
            love.graphics.draw(canvasCache.armhairMesh, 0, 0, 0, 1, 1)
        end
        if canvasCache.handCanvas then
            renderAtachedObject(canvasCache.handCanvas, 'rhand', 'rhand', -math.pi / 2, 1, -1, box2dGuy, creation)
        end
    end


    -- when we are facing left i want to draw left leg and left arm before the torso

    if facing.legs == 'right' then
        renderRightArmAndHair()
        renderRightLegAndHair()
    end

    if facing.legs == 'left' then
        renderLeftArmAndHair()
        renderLeftLegAndHair()
    end


    if creation.torso.metaURL and not creation.isPotatoHead then
        local x, y, r, sx, sy = renderMetaObject(canvasCache.torsoCanvas, 'torso', box2dGuy, creation)
        if not box2dGuyCreation.isNullObject('chestHair', values) then
            drawSquishableHairOver(canvasCache.chestHairCanvas, x, y, r, sx * dpi / shrink,
                sy * dpi / shrink, multipliers.chesthair.mMultiplier, creation)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if canvasCache.neckCanvas and box2dGuy.neck and box2dGuy.neck1 then
        love.graphics.setColor(1, 1, 1, 1)
        renderCurvedObjectGrow('neck', 'neck1', 'head', 50, canvasCache.neckCanvas, canvasCache.neckmesh, box2dGuy, 1,
            multipliers.neck.wMultiplier / (4 * dpi / shrink))
        love.graphics.draw(canvasCache.neckmesh, 0, 0, 0, 1, 1)
    end

    if canvasCache.earCanvas then
        if creation.lear.metaURL then
            renderAtachedObject(canvasCache.earCanvas, 'lear', 'lear', -math.pi / 2, -1 * 2, 2, box2dGuy, creation)
            renderAtachedObject(canvasCache.earCanvas, 'rear', 'rear', math.pi / 2, 1 * 2, 2, box2dGuy, creation)
        end
    end

    love.graphics.setColor(0, 0, 0, 1)

    -- all  the FACE INTERNALS
    if true then
        local facePart = creation.isPotatoHead and box2dGuy.torso or box2dGuy.head
        local faceCanvas = creation.isPotatoHead and canvasCache.torsoCanvas or canvasCache.headCanvas
        local face = creation.isPotatoHead and 'torso' or 'head'
        local faceData = creation.isPotatoHead and creation.torso or creation.head
        local faceMultiplier = multipliers.face.mMultiplier

        love.graphics.setColor(1, 1, 1, 1)
        if not faceCanvas then
            print('au')
        end
        local x, y, r, sx, sy = renderMetaObject(faceCanvas, face, box2dGuy, creation)

        if creation.isPotatoHead then
            -- love.graphics.setColor(.4, 0, 0, 1)
            if not box2dGuyCreation.isNullObject('chestHair', values) then
                drawSquishableHairOver(canvasCache.chestHairCanvas, x, y, r, sx * dpi / shrink,
                    sy * dpi / shrink, multipliers.chesthair.mMultiplier, creation)
            end
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
            local destX = cx
            local destY = cy
            if guy.tweenVars.lookAtCounter > 0 then
                destX = guy.tweenVars.lookAtPosX
                destY = guy.tweenVars.lookAtPosY
            end


            local eyeImgWidth = canvasCache.eyeCanvas:getWidth()
            local eyeImgHeight = canvasCache.eyeCanvas:getHeight()
            local eyeW = eyeImgWidth * eyeMultiplierFix * multipliers.eye.wMultiplier * faceMultiplier
            local eyeH = eyeImgHeight * eyeMultiplierFix * multipliers.eye.hMultiplier * faceMultiplier


            local pupilImgWidth = canvasCache.pupilCanvas:getWidth()
            local pupilImgHeight = canvasCache.pupilCanvas:getHeight()
            local pupilW = pupilImgWidth * multipliers.pupil.wMultiplier  --* faceMultiplier
            local pupilH = pupilImgHeight * multipliers.pupil.hMultiplier -- * faceMultiplier
            local pupilMaxOffsetW = math.max(((eyeW / 3)), 0)
            local pupilMaxOffsetH = math.max(((eyeH / 3)), 0)

            local angle, dist = getAngleAndDistance(cx, cy, destX, destY)
            local px1, py1 = setAngleAndDistanceX2(0, 0, angle - r, math.min(dist, pupilMaxOffsetW),
                math.min(dist, pupilMaxOffsetH), 1, 1)
            local pupillx, pupilly = facePart:getWorldPoint(
                (leftEyeX + faceData.metaOffsetX + px1) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY + py1) * sy * dpi / shrink)


            local cx, cy = cam:getScreenCoordinates(eyerx, eyery)

            local destX = cx
            local destY = cy
            if guy.tweenVars.lookAtCounter > 0 then
                destX = guy.tweenVars.lookAtPosX
                destY = guy.tweenVars.lookAtPosY
            end
            local angle, dist = getAngleAndDistance(cx, cy, destX, destY)
            local px2, py2 = setAngleAndDistanceX2(0, 0, angle - r, math.min(dist, pupilMaxOffsetW),
                math.min(dist, pupilMaxOffsetH), 1,
                1)
            local pupilrx, pupilry = facePart:getWorldPoint(
                (rightEyeX + faceData.metaOffsetX + px2) * sx * dpi / shrink,
                (eyeY + faceData.metaOffsetY + py2) * sy * dpi / shrink)

            if canvasCache.eyeCanvas then
                local eyeW = eyeMultiplierFix * multipliers.eye.wMultiplier * faceMultiplier
                local eyeH = eyeMultiplierFix * multipliers.eye.hMultiplier * faceMultiplier * guy.tweenVars.eyesOpen
                renderNonAttachedObject(canvasCache.eyeCanvas,
                    'eye', r - positioners.eye.r, eyelx, eyely, -eyeW, eyeH, box2dGuy, creation)

                renderNonAttachedObject(canvasCache.eyeCanvas,
                    'eye', r + positioners.eye.r, eyerx, eyery, eyeW, eyeH, box2dGuy, creation)
            end

            if canvasCache.pupilCanvas then
                local pupilW = multipliers.pupil.wMultiplier
                local pupilH = multipliers.pupil.hMultiplier
                renderNonAttachedObject2(canvasCache.pupilCanvas,
                    'pupil', r, pupillx, pupilly, pupilW, pupilH, box2dGuy, creation)
                renderNonAttachedObject2(canvasCache.pupilCanvas,
                    'pupil', r, pupilrx, pupilry, pupilW, pupilH, box2dGuy, creation)
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
        if not box2dGuyCreation.isNullObject('hair', values) then
            renderHair(box2dGuy, guy, faceData, creation, multipliers, x, y, r, sx, sy)
        end

        if canvasCache.browCanvas then
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

            local browmesh = lib.createTexturedTriangleStrip(canvasCache.browCanvas)
            renderCurvedObjectFromSimplePoints(
                { -faceWidth / 2, bend[1] * bendMultiplier },
                { 0, bend[2] * bendMultiplier },
                { faceWidth / 2, bend[3] * bendMultiplier },
                canvasCache.browCanvas, browmesh, box2dGuy, 1, multipliers.brow.hMultiplier * shrink / dpi)
            love.graphics.draw(browmesh, browlx, browly, r, 1, 1)

            local browmesh = lib.createTexturedTriangleStrip(canvasCache.browCanvas)
            renderCurvedObjectFromSimplePoints(
                { -faceWidth / 2, bend[1] * bendMultiplier },
                { 0, bend[2] * bendMultiplier },
                { faceWidth / 2, bend[3] * bendMultiplier },
                canvasCache.browCanvas, browmesh, box2dGuy, 1, multipliers.brow.hMultiplier * shrink / dpi)
            love.graphics.draw(browmesh, browrx, browry, r, -1, 1)
        end


        drawMouth(facePart, faceData, creation, guy, box2dGuy, sx,
            sy, multipliers, positioners, r)

        if canvasCache.noseCanvas then
            local noseX = numbers.lerp(f[7][1], f[3][1], 0.5)
            local noseY = numbers.lerp(f[1][2], f[5][2], positioners.nose.y)
            local nx, ny = facePart:getWorldPoint(
                (noseX + faceData.metaOffsetX) * sx * dpi / shrink,
                (noseY + faceData.metaOffsetY) * sy * dpi / shrink)

            renderNonAttachedObject(canvasCache.noseCanvas,
                'nose', r, nx, ny, 0.5 * multipliers.nose.wMultiplier * faceMultiplier,
                -0.5 * multipliers.nose.hMultiplier * faceMultiplier,
                box2dGuy, creation)
        end
    end


    if facing.legs ~= 'right' then
        renderRightLegAndHair()
    end
    if facing.legs ~= 'left' then
        renderLeftLegAndHair()
    end

    if facing.legs ~= 'right' then
        renderRightArmAndHair()
    end
    if facing.legs ~= 'left' then
        renderLeftArmAndHair()
    end
end

return lib
