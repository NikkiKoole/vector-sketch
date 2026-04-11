--[[
TODO Recreating meshes every frame in drawSquishableHairOver and
createTexturedTriangleStrip (within drawTexturedWorld) is definitely
inefficient. We should absolutely cache these.
]] --

local lib = {}
local registry = require 'src.registry'
local state = require 'src.state'
local mathutils = require 'src.math-utils'
local polyline = require 'src.polyline'
local shapes = require 'src.shapes'
local subtypes = require 'src.subtypes'
local NT = require('src.node-types')
local SIDES = require('src.sides')
local cam = require('src.camera').getInstance()

local function safeLoadImage(path)
    local info = love.filesystem.getInfo(path)
    if not info then return nil end
    return love.graphics.newImage(path)
end

local tex1 = safeLoadImage('textures/pat/type0.png')
if not tex1 then
    -- Fallback: 1x1 white pixel so textured rendering doesn't crash on nil
    local pd = love.image.newImageData(1, 1)
    pd:setPixel(0, 0, 1, 1, 1, 1)
    tex1 = love.graphics.newImage(pd)
end
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')

local line = safeLoadImage('textures/shapes6.png')
local maskTex = safeLoadImage('textures/shapes6-mask.png')
local imageCache = {}
local shrinkFactor = 1

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end
lib.getShrinkFactor = function()
    return shrinkFactor
end

local function getLoveImage(path, settings)
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            --print("Warning: File not found - " .. path)
            return nil, nil, nil
        end
        local img = love.graphics.newImage(path)
        if (settings) then
            if settings.wrapX and settings.wrapY then
                img:setWrap(settings.wrapX, settings.wrapY)
            end
        end
        if img then
            local imgw, imgh = img:getDimensions()
            imageCache[path] = { img = img, imgw = imgw, imgh = imgh }
        end
    end

    if imageCache[path] then
        --  logger:trace()
        return imageCache[path].img, imageCache[path].imgw, imageCache[path].imgh
    else
        return nil, nil, nil
    end
end

local settings = { wrapX = 'mirroredrepeat', wrapY = 'mirroredrepeat' }
getLoveImage('textures/pat/type0.png', settings)
getLoveImage('textures/pat/type1.png', settings)
getLoveImage('textures/pat/type2.png', settings)
getLoveImage('textures/pat/type3.png', settings)
getLoveImage('textures/pat/type4.png', settings)
getLoveImage('textures/pat/type5.png', settings)
getLoveImage('textures/pat/type6.png', settings)
getLoveImage('textures/pat/type7.png', settings)
getLoveImage('textures/pat/type8.png', settings)



local base = {
    '020202', '4f3166', '69445D', '613D41', 'efebd8',
    '6f323a', '872f44', '8d184c', 'be193b', 'd2453a',
    'd6642f', 'd98524', 'dca941', 'e6c800', 'f8df00',
    'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf',
    '9c9d9f', '938541', '808b1c', '8A934E', '86a542',
    '57843d', '45783c', '2a5b3e', '1b4141', '1e294b',
    '0d5f7f', '065966', '1b9079', '3ca37d', '49abac',
    '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3',
    '045b9f', '9377b2', '686094', '5f4769', '815562',
    '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34',
    'CB433A', 'a95c42', 'c37c61', 'd19150', 'de9832',
    'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c',
    '75899c', 'aabdce', '807b7b', '857b7e', '8d7e8a',
    'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267',
    'f0644d', 'ff7376', 'd76656', 'b16890', '020202',
    '333233', '814800', 'efebd8', '1a5f8f', '66a5bc',
    '87727b', 'a23d7e', 'fa8a00', 'fef1d0', 'ffa8a2',
    '6e614c', '418090', 'b5d9a4', 'c0b99e', '4D391F',
    '4B6868', '9F7344', '9D7630', 'D3C281', '8F4839',
    'EEC488', 'C77D52', 'C2997A', '9C5F43', '9C8D81',
    '965D64', '798091', '4C5575', '6E4431', '626964',
}
lib.palette = base

-- Weak-keyed side tables so meshes GC cleanly.
local _vertsBufByMesh = setmetatable({}, { __mode = "k" })
local function _ensureVertsBuf(mesh)
    local buf = _vertsBufByMesh[mesh]
    if buf then return buf end
    local count = mesh:getVertexCount()
    buf = {}
    -- Precreate the vertex tables so we only mutate numbers each frame.
    for i = 1, count do buf[i] = { 0, 0, 0, 0 } end
    _vertsBufByMesh[mesh] = buf
    return buf
end

-- todo segments need to be parameterized
local function createTexturedTriangleStrip(image, optionalWidthMultiplier)
    -- this assumes an strip that is oriented vertically
    local w, h = image:getDimensions()
    w = w * (optionalWidthMultiplier or 1)

    local vertices = {}
    local segments = 32
    local segMinus1 = segments - 1
    local hPart = h / (segMinus1)
    local hv = 1 / (segMinus1)
    local runningHV = 0
    local runningHP = 0
    local index = 0

    for _ = 1, segments do
        vertices[index + 1] = { -w * .5, runningHP, 0, runningHV }
        vertices[index + 2] = { w * .5, runningHP, 1, runningHV }
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)

    return mesh
end

local function resolveIndex(index, length)
    return (index < 0) and ((length + index) % length) or (index % length)
end

local function getIndices(length, startIdx, endIdx, allowFullLoop)
    local start = resolveIndex(startIdx, length)
    local ending = resolveIndex(endIdx, length)
    local result = {}

    local i = start
    repeat
        table.insert(result, i)
        i = (i + 1) % length
    until i == ending and (not allowFullLoop or i == start)

    if i == ending then
        table.insert(result, i)
    end

    return result
end

local _stripCache = setmetatable({}, { __mode = "k" }) -- image -> table
local function getStrip(image, wmul)
    wmul = wmul or 1
    local byW = _stripCache[image]
    if not byW then
        byW = {}; _stripCache[image] = byW
    end
    local m = byW[wmul]
    if not m then
        m = createTexturedTriangleStrip(image, wmul)
        byW[wmul] = m
    end
    return m
end

-- Fan mesh pool: image -> { [vertexCount] = { mesh=..., vertsBuf=... } }
local _fanPool = setmetatable({}, { __mode = "k" })

local function _getFanMesh(image, vertexCount)
    local byV = _fanPool[image]
    if not byV then
        byV = {}; _fanPool[image] = byV
    end
    local rec = byV[vertexCount]
    if not rec then
        local verts = {}
        for i = 1, vertexCount do verts[i] = { 0, 0, 0, 0 } end -- prealloc vertex tables
        local mesh = love.graphics.newMesh(verts, "fan")
        mesh:setTexture(image)
        rec = { mesh = mesh, verts = verts }
        byV[vertexCount] = rec
    end
    return rec.mesh, rec.verts
end

local sqrt = math.sqrt
local function growLine(p1, p2, length)
    local dx, dy = p1[1] - p2[1], p1[2] - p2[2]
    local inv = 1.0 / (sqrt(dx * dx + dy * dy) + 1e-12)
    return p1[1] + length * dx * inv, p1[2] + length * dy * inv
end



--todo the things that have a hex, should have the rgba values directly so we dont have to calculate them every frame.
-- fix this with something like function setBgColor(item, val)
--    item.bgHex = val
--    item.bgR, item.bgG, item.bgB, item.bgA = ToColor(val)-
--end

local function setBgColor(item, val)
    item.bgHex = val
    item.cached.bgR, item.cached.bgG, item.cached.bgB, item.cached.bgA = lib.hexToColor(val)
    item.cached.bgRGB = { item.cached.bgR, item.cached.bgG, item.cached.bgB }
end

local function setFgColor(item, val)
    item.fgHex = val
    item.cached.fgR, item.cached.fgG, item.cached.fgB, item.cached.fgA = lib.hexToColor(val)
    item.cached.fgRGB = { item.cached.fgR, item.cached.fgG, item.cached.fgB }
end

local function setPColor(item, val)
    item.pHex = val
    item.cached.pR, item.cached.pG, item.cached.pB, item.cached.pA = lib.hexToColor(val)
    item.cached.pRGB = { item.cached.pR, item.cached.pG, item.cached.pB }
end

function lib.makeCached(item)
    -- print(item.bgHex, item.fgHex, item.pHex)
    if not item.cached then item.cached = {} end
    setBgColor(item, item.bgHex)
    setFgColor(item, item.fgHex)
    setPColor(item, item.pHex)
end

function lib.hexToColor(hex)
    --logger:trace()
    if type(hex) ~= "string" then
        -- print("Warning: hexToColor expected a string but got " .. type(hex))
        return 1, 1, 1, 1
    end

    -- Remove any leading hash symbol.
    hex = hex:gsub("#", "")

    -- Expand shorthand forms:
    if #hex == 3 then
        -- Example: "f00" becomes "ff0000"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
        -- Append full opacity.
        hex = hex .. "FF"
    elseif #hex == 4 then
        -- Example: "f00a" becomes "ff0000aa"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2) .. hex:sub(4, 4):rep(2)
    elseif #hex == 6 then
        -- Append alpha if missing.
        hex = hex .. "FF"
    elseif #hex ~= 8 then
        -- print("Warning: invalid hex string length (" .. #hex .. ") for value: " .. hex)
        return 1, 1, 1, 1
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8), 16)

    -- If any conversion failed, return white.
    if not (r and g and b and a) then
        -- print("Warning: invalid hex color value: " .. hex)
        return 1, 1, 1, 1
    end

    return r / 255, g / 255, b / 255, a / 255
end

-- only thing thats no longer possible == using an alpha for the background color
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec4 backgroundColor;
    uniform mat2 uvTransform;
    uniform vec2 uvTranslation;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        vec2 transformedUV = uv * uvTransform;
        transformedUV.x += uvTranslation.x;
        transformedUV.y += uvTranslation.y;
        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, transformedUV).a * color.a);
        return vec4(patternMix, Texel(mask, uv).r * backgroundColor.a  );
	}
]])



local function getDrawParams(flipx, flipy, imgw, imgh)
    local sx = flipx
    local sy = flipy

    local ox = flipx == -1 and imgw or 0
    local oy = flipy == -1 and imgh or 0

    return sx, sy, ox, oy
end


-- todo /5 and *5 is dumb!
lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patches)
    --  logger:info(key)

    local lineartColor = lineColor or { 0, 0, 0, 1 }
    local lw, lh = lineart:getDimensions()
        --  local dpiScale = 1 --love.graphics.getDPIScale()
        local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })

        love.graphics.setCanvas({ canvas, stencil = false }) --<<<

        --

        -- the reason for outline ghost stuff is this color
        -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<

        love.graphics.setShader(maskShader)
        local transform = love.math.newTransform()

        transform:rotate(texRot)
        transform:scale(texScaleX, texScaleY)

        local m1, m2, _, _, m5, m6 = transform:getMatrix()
        local dx = texOffX --love.math.random() * .001
        local dy = texOffY
        if texture2 then
            maskShader:send('fill', texture2)
        end

        maskShader:send('backgroundColor', { color1[1], color1[2], color1[3], alpha1 / 5 })
        maskShader:send('uvTransform', { { m1, m2 }, { m5, m6 } })
        maskShader:send('uvTranslation', { dx, dy })

        if mask then
            local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
            love.graphics.setColor(color2[1], color2[2], color2[3], alpha2 / 5)
            love.graphics.draw(mask, 0, 0, 0, sx, sy, ox, oy)
        end
        love.graphics.setShader()

        if patches then
            for i = 1, #patches do
                local patch = patches[i]
                if patch and patch.img then
                    love.graphics.setColorMask(true, true, true, false)
                    local r, g, b, a = lib.hexToColor(patch.tint)
                    love.graphics.setColor(r, g, b, a)
                    local image = patch.img
                    local imgw, imgh = image:getDimensions()
                    local xOffset = (patch.tx or 0) * (imgw) * shrinkFactor
                    local yOffset = (patch.ty or 0) * (imgh) * shrinkFactor
                    love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset,
                        (patch.r or 0) * ((math.pi * 2) / 16),
                        (patch.sx or 1) * shrinkFactor,
                        (patch.sy or 1) * shrinkFactor,
                        imgw / 2, imgh / 2)
                    love.graphics.setColorMask(true, true, true, true)
                end
            end
        end



        -- I want to know If we do this or not..
        -- if (true and renderPatch) then
        --     love.graphics.setColorMask(true, true, true, false)
        --     -- for i = 1, #renderPatch do
        --     --     local p = renderPatch[i]

        --     --     love.graphics.setColor(1, 1, 1, 1)
        --     --     local image = love.graphics.newImage(p.)
        --     --     local imgw, imgh = image:getDimensions();
        --     --     local xOffset = p.tx * (imgw / 6) * shrinkFactor
        --     --     local yOffset = p.ty * (imgh / 6) * shrinkFactor
        --     --     love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, p.r * ((math.pi * 2) / 16),
        --     --         p.sx * shrinkFactor,
        --     --         p.sy * shrinkFactor,
        --     --         imgw / 2, imgh / 2)
        --     --     --print(lw, lh)
        --     --     if true then
        --     --         local img = love.graphics.newImage('textures/eye4.png')
        --     --         --local img = love.graphics.newImage('assets/test1.png')
        --     --         --love.graphics.setBlendMode('subtract')

        --     --         for i = 1, 13 do
        --     --             love.graphics.setColor(love.math.random(), love.math.random(), love.math.random(), 0.4)
        --     --             local s = 3 + love.math.random() * 3
        --     --             love.graphics.draw(img, lw * love.math.random(), lh * love.math.random(),
        --     --                 love.math.random() * math.pi * 2,
        --     --                 1 / s, 1 / s)
        --     --         end

        --     --         --love.graphics.setBlendMode("alpha")
        --     --     end
        --     -- end
        --     love.graphics.setColorMask(true, true, true, true)
        -- end


        love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha / 5)
        local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
        love.graphics.draw(lineart, 0, 0, 0, sx, sy, ox, oy)

        love.graphics.setColor(0, 0, 0) --- huh?!
        love.graphics.setCanvas()       --- <<<<<

        local otherCanvas = love.graphics.newCanvas(lw / shrinkFactor, lh / shrinkFactor,
            { dpiscale = 1 })
        love.graphics.setCanvas({ otherCanvas, stencil = false })                 --<<<
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
        love.graphics.setColor(1, 1, 1)
        --- huh?!
        love.graphics.draw(canvas, 0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
        love.graphics.setCanvas()       --- <<<<<
        local imageData = otherCanvas:newImageData()
        love.graphics.setColor(0, 0, 0) --- huh?!

        canvas:release()
        otherCanvas:release()
        return imageData
end

local function makePatch(name, ud)
    local result = nil
    if ud.extra[name] and ud.extra[name].bgURL then
        local outlineImage = getLoveImage('textures/' .. ud.extra[name].bgURL)
        local olr, olg, olb, ola = lib.hexToColor(ud.extra[name].bgHex)
        local maskImage = getLoveImage('textures/' .. ud.extra[name].fgURL)
        local mr, mg, mb, ma = lib.hexToColor(ud.extra[name].fgHex)
        local patternImage = getLoveImage('textures/pat/' .. ud.extra[name].pURL)
        local pr, pg, pb, pa = lib.hexToColor(ud.extra[name].pHex)
        if outlineImage then
            local imgData = lib.makeTexturedCanvas(
                outlineImage,            -- line art
                maskImage,               -- mask
                { mr, mg, mb },          -- color1
                ma * 5,                  -- alpha1
                patternImage or tex1,    -- texture2 (fill texture)
                { pr, pg, pb },          -- color2
                pa * 5,                  -- alpha2
                ud.extra[name].pr or 0,  -- texRot
                ud.extra[name].psx or 1, -- texScale
                ud.extra[name].psy or 1, -- texScale
                ud.extra[name].ptx or 0,
                ud.extra[name].pty or 0,
                { olr, olg, olb },      -- lineColor
                ola * 5,                -- lineAlpha
                ud.extra[name].fx or 1, -- flipx (normal)
                ud.extra[name].fy or 1  -- flipy (normal)
            )
            result = {
                img = love.graphics.newImage(imgData),
                --img = getLoveImage('textures/' .. ud.extra.patch1URL),
                tint = ud.extra[name].tint or 'ffffff',
                tx = ud.extra[name].tx,
                ty = ud.extra[name].ty,
                sx = ud.extra[name].sx,
                sy = ud.extra[name].sy,
                r = ud.extra[name].r
            }
        end
        return result
    end
    return result
end

function lib.makeCombinedImages()
    local bodies = state.physicsWorld:getBodies()

    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for i = 1, #fixtures do
            local ud = fixtures[i]:getUserData()
            if ud and type(ud) == 'table' and ud.extra and ud.extra.OMP and ud.extra.dirty then
                local patch1 = makePatch('patch1', ud)
                local patch2 = makePatch('patch2', ud)
                local patch3 = makePatch('patch3', ud)
                local main = ud.extra.main

                if not main.cached then
                    lib.makeCached(main)
                end
                local cached = main.cached

                local outlineImage = getLoveImage('textures/' .. main.bgURL)
                local hasFgURL = main.fgURL and main.fgURL ~= ''
                local maskImage = hasFgURL and getLoveImage('textures/' .. main.fgURL) or nil
                local patternImage = getLoveImage('textures/pat/' .. main.pURL)

                if outlineImage or line then
                    local imgData = lib.makeTexturedCanvas(
                        outlineImage or line, -- line art
                        maskImage or (hasFgURL and maskTex) or nil, -- mask (nil for outline-only textures)
                        cached.fgRGB,         -- color1
                        cached.fgA * 5,       -- alpha1
                        patternImage or tex1, -- texture2 (fill texture)
                        cached.pRGB,          -- color2
                        cached.pA * 5,        -- alpha2
                        main.pr or 0,         -- texRot
                        main.psx or 1,        -- texScale
                        main.psy or 1,        -- texScale
                        main.ptx or 0,
                        main.pty or 0,
                        cached.bgRGB,              -- lineColor
                        cached.bgA * 5,            -- lineAlpha
                        main.fx or 1,              -- flipx (normal)
                        main.fy or 1,              -- flipy (normal)
                        { patch1 or false, patch2 or false, patch3 or false } -- renderPatch (avoid sparse table)
                    )
                    local image = love.graphics.newImage(imgData)
                    ud.extra.ompImage = image
                end
                fixtures[i]:setUserData(ud)

                ud.extra.dirty = false
            end
        end
        --for i = 1, #fixtures do fixtures[i] = nil end
    end
    --for i = 1, #bodies do bodies[i] = nil end
end

local function makeSquishableUVsFromPoints(v)
    local verts = {}
    if #v == 8 then -- has 4 (4*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], 1, 0 }
        verts[3] = { v[5], v[6], 1, 1 }
        verts[4] = { v[7], v[8], 0, 1 }
        verts[5] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    if #v == 16 then -- has 8 (8*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], .5, 0 }
        verts[3] = { v[5], v[6], 1, 0 }
        verts[4] = { v[7], v[8], 1, .5 }
        verts[5] = { v[9], v[10], 1, 1 }
        verts[6] = { v[11], v[12], .5, 1 }
        verts[7] = { v[13], v[14], 0, 1 }
        verts[8] = { v[15], v[16], 0, .5 }
        verts[9] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    return verts
end


-- local function renderHair(box2dGuy, guy, faceData, creation, multipliers, x, y, r, sx, sy)
--     local canvasCache = guy.canvasCache
--     local dpi = 1 --love.graphics.getDPIScale()
--     local shrink = lib.getShrinkFactor()
--     if true then
--         if true or box2dGuy.hairNeedsRedo then
--             local img = canvasCache.hairCanvas
--             local w, h = img:getDimensions()
--             local f = faceData.metaPoints
--             -- todo parameter hair (beard, only top hair, sidehair)
--             --local hairLine = { f[6], f[7], f[8], f[1], f[2], f[3], f[4] }
--             local hairLine = { f[7], f[8], f[1], f[2], f[3] }
--             -- local hairLine = { f[8], f[1], f[2] }
--             -- print(inspect(hairLine))
--             --local hairLine = { f[3], f[4], f[5], f[6], f[7] }
--             local points = hairLine
--             local hairTension = .02
--             local spacing = 10 * multipliers.hair.sMultiplier
--             local coords

--             coords = border.unloosenVanillaline(points, hairTension, spacing)

--             local length = getLengthOfPath(hairLine)
--             local factor = (length / h)
--             local hairWidthMultiplier = 1 * multipliers.hair.wMultiplier
--             local width = (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
--             local verts, indices, draw_mode = polyline.render('none', coords, width)

--             local vertsWithUVs = {}

--             for i = 1, #verts do
--                 local u = (i % 2 == 1) and 0 or 1
--                 local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
--                 vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
--             end

--             local vertices = vertsWithUVs
--             local m = love.graphics.newMesh(vertices, "strip")
--             m:setTexture(img)
--             love.graphics.draw(m, x, y, r - math.pi, sx * creation.head.flipx * (dpi / shrink), sy * (dpi / shrink))
--         end
--     end
-- end




local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, vertices)
    -- grow once into a flat array (reuse a local)
    local nnums = #vertices         -- flat x,y,... array
    local n = math.floor(nnums / 2) -- number of polygon points
    local grown = {}                -- short-lived; ok (main cost was newMesh)
    for i = 1, nnums do grown[i] = vertices[i] * growFactor end

    -- ring UVs from your existing helper (allocates, but cheap vs newMesh)
    local ring = makeSquishableUVsFromPoints(grown) -- size n+1 (closed)
    local cx, cy = mathutils.getCenterOfPoints(vertices)

    -- center + ring => total vertex count
    local vcount = (n + 1) + 1 -- closed ring + center
    local mesh, buf = _getFanMesh(img, vcount)

    -- write center
    local v = buf[1]; v[1], v[2], v[3], v[4] = cx, cy, 0.5, 0.5
    -- write ring
    for i = 1, #ring do
        local s = ring[i]
        local d = buf[i + 1]
        d[1], d[2], d[3], d[4] = s[1], s[2], s[3], s[4]
    end

    mesh:setVertices(buf) -- 1 call instead of creating a mesh
    love.graphics.draw(mesh, x, y, r, sx, sy)
end


-- Batched, no mesh:getVertex, 1x mesh:setVertices per call
local function texturedCurve(curve, image, mesh, dir, scaleW, dl)
    dir             = dir or 1
    scaleW          = scaleW or 1
    dl              = dl or curve:getDerivative()

    -- Only need the texture width to set half-width of the ribbon
    local w         = image:getWidth()
    local halfWidth = (w * dir) * scaleW

    -- Prealloc / reuse vertex tables for this mesh
    local verts     = _ensureVertsBuf(mesh)

    local count     = mesh:getVertexCount() -- always even
    local segments  = count / 2             -- number of (left,right) pairs
    local segMinus1 = segments - 1

    -- Safety against degenerate curves
    local eps       = 1e-12

    -- Walk pairs j,j+1 while also knowing pair index p
    local p         = 0
    for j = 1, count, 2 do
        -- Param along the curve in [0,1]
        local t                    = p / segMinus1

        -- Evaluate position and derivative
        local x, y                 = curve:evaluate(t)
        local dx, dy               = dl:evaluate(t)

        -- Normalized derivative and its left normal
        local invlen               = 1.0 / math.sqrt(dx * dx + dy * dy + eps)
        dx, dy                     = dx * invlen, dy * invlen
        local nx, ny               = -dy, dx

        -- Offset to both sides
        local xL                   = x + halfWidth * nx
        local yL                   = y + halfWidth * ny
        local xR                   = x - halfWidth * nx
        local yR                   = y - halfWidth * ny

        -- Compute UVs analytically (no getVertex):
        -- left u=0, right u=1; v increases 0..1 per pair
        local v                    = (segMinus1 > 0) and (p / segMinus1) or 0

        -- Mutate the precreated vertex tables
        local vL                   = verts[j]
        vL[1], vL[2], vL[3], vL[4] = xL, yL, 0, v

        local vR                   = verts[j + 1]
        vR[1], vR[2], vR[3], vR[4] = xR, yR, 1, v

        p                          = p + 1
    end

    -- One C call instead of N*2
    mesh:setVertices(verts)
end


-- -- cache squish fan meshes per fixture (extra) + url (+ vertex layout)
-- local _fanMeshCache = setmetatable({}, { __mode = "k" })

-- local function _verticesSig(v)
--     -- cheap change detector: (#, sum, sumsq)
--     local n, s, s2 = #v, 0.0, 0.0
--     for i = 1, n do
--         local x = v[i]; s = s + x; s2 = s2 + x * x
--     end
--     return n, s, s2
-- end

-- local function _makeSquishMesh(img, vertices, growFactor)
--     -- scale once
--     local n = #vertices
--     local p = {}
--     for i = 1, n do p[i] = vertices[i] * growFactor end

--     -- reuse your helper to make perimeter UVs
--     local uvs = makeSquishableUVsFromPoints(p)

--     -- prepend center vertex (cx,cy,0.5,0.5) without table.insert
--     local cx, cy = mathutils.getCenterOfPoints(vertices)
--     for i = #uvs + 1, 2, -1 do uvs[i] = uvs[i - 1] end
--     uvs[1] = { cx, cy, 0.5, 0.5 }

--     local m = love.graphics.newMesh(uvs) -- default mode is 'fan' here
--     m:setTexture(img)
--     return m
-- end


local function doubleControlPoints(points, duplications)
    local len = #points
    if len % 2 ~= 0 then
        error("Input array must have even number of elements (x, y pairs)")
    end

    local n = len / 2                     -- number of (x,y) points
    local mids = (n > 2) and (n - 2) or 0 -- middle points count
    local outLen = len + 2 * duplications * mids

    local result = {}
    result[outLen] = false -- pre-allocate array size (fills with nils)

    local ri = 1           -- write index into result
    local last = len - 1   -- last x index (so y is last+1)
    local d = duplications -- localize for tight loop

    for i = 1, len, 2 do
        local x = points[i]
        local y = points[i + 1]

        -- always copy the original point once
        result[ri] = x
        result[ri + 1] = y
        ri = ri + 2

        -- duplicate if it's a middle point (not first or last)
        if i > 2 and i < last then
            for _ = 1, d do
                result[ri] = x
                result[ri + 1] = y
                ri = ri + 2
            end
        end
    end

    return result
end


local function transformUV(x, y, cx, cy, opts)
    -- Translate point to origin (centroid or top-left)
    local dx = x - cx + opts.offsetX
    local dy = y - cy + opts.offsetY

    -- Rotate
    local cosA = math.cos(opts.rotate or 0)
    local sinA = math.sin(opts.rotate or 0)
    local rx = dx * cosA - dy * sinA
    local ry = dx * sinA + dy * cosA

    -- Scale to UV space
    local tileW = opts.tileWidth or 64
    local tileH = opts.tileHeight or 64
    local u = rx / tileW
    local v = ry / tileH

    return u * (opts.scaleX or 1), v * (opts.scaleY or 1)
end

-- Build a closed polygon from mouth curvePoints (16 floats: 8 control points).
-- Returns a cleaned flat vertex array suitable for triangulation, or nil.
local function buildMouthPolygon(curvePoints)
    local pts = curvePoints
    if not pts or #pts ~= 16 then return nil end

    local upData = {
        pts[1], pts[2], pts[3], pts[4],
        pts[3], pts[4], pts[5], pts[6],
        pts[5], pts[6], pts[7], pts[8],
        pts[7], pts[8], pts[9], pts[10],
    }
    local downData = {
        pts[9], pts[10], pts[11], pts[12],
        pts[11], pts[12], pts[13], pts[14],
        pts[13], pts[14], pts[15], pts[16],
        pts[15], pts[16], pts[1], pts[2],
    }

    local upCurve = love.math.newBezierCurve(upData)
    local downCurve = love.math.newBezierCurve(downData)
    local upPts = upCurve:render(1)
    local downPts = downCurve:render(1)

    local poly = {}
    for pi = 1, #upPts do poly[#poly + 1] = upPts[pi] end
    for pi = 1, #downPts do poly[#poly + 1] = downPts[pi] end

    -- Remove consecutive duplicates
    local cleaned = {}
    local prevX, prevY
    for pi = 1, #poly - 1, 2 do
        local px, py = poly[pi], poly[pi + 1]
        if not prevX or math.abs(px - prevX) > 0.1 or math.abs(py - prevY) > 0.1 then
            cleaned[#cleaned + 1] = px
            cleaned[#cleaned + 1] = py
            prevX, prevY = px, py
        end
    end

    if #cleaned >= 6 then return cleaned end
    return nil
end

function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()


    local function createDrawables()
        local drawables = {}
        for _, body in ipairs(bodies) do
            -- local ud = body:getUserData()
            -- if (ud and ud.thing) then
            --     local composedZ = ((ud.thing.zGroupOffset or 0) * 1000) + ud.thing.zOffset
            --     table.insert(drawables, { z = composedZ, body = body, thing = ud.thing })
            -- end
            -- todo instead of having to check all the fixtures every frame
            -- we should mark a thing that has these type of specialfixtures.
            local fixtures = body:getFixtures()
            for i = 1, #fixtures do
                local ud = fixtures[i]:getUserData()
                if type(ud) ~= 'table' then -- vanwege softbodies bullshit
                    ud = nil
                end
                if ud and subtypes.is(ud, subtypes.TRACE_VERTICES) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                    table.insert(drawables, {
                        type = 'trace-vertices',
                        z = composedZ,
                        extra = ud.extra,
                        thing = body:getUserData().thing
                    })
                end

                if ud and subtypes.is(ud, subtypes.TILE_REPEAT) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                    table.insert(drawables, {
                        type = 'tile-repeat',
                        z = composedZ,
                        extra = ud.extra,
                        thing = body:getUserData().thing
                    })
                end

                if ud and subtypes.is(ud, subtypes.TEXFIXTURE) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                    table.insert(drawables,
                        {
                            type = 'texfixture',
                            z = composedZ,
                            texfixture = fixtures[i],
                            extra = ud.extra,
                            body = body,
                            thing = body:getUserData().thing
                        })
                end
                if ud and subtypes.is(ud, subtypes.MESHUSERT) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                    table.insert(drawables,
                        {
                            type = 'meshusert',
                            z = composedZ,
                            texfixture = fixtures[i],
                            label = ud.label,
                            extra = ud.extra,
                            body = body,
                            thing = body:getUserData().thing
                        })
                end
                if ud and subtypes.is(ud, subtypes.UVUSERT) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                    table.insert(drawables,
                        {
                            type = 'uvusert',
                            z = composedZ,
                            texfixture = fixtures[i],
                            label = ud.label,
                            extra = ud.extra,
                            body = body,
                            thing = body:getUserData().thing
                        })
                end
                if ud and subtypes.is(ud, subtypes.DECAL) then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                    if ud.extra.browCurve then
                        table.insert(drawables, {
                            type = 'brow',
                            z = composedZ,
                            extra = ud.extra,
                            body = body,
                        })
                    elseif ud.extra.mouthCurve then
                        if ud.extra.mouthCurve == 'teeth' then
                            -- Teeth: positioned image, optionally clipped to mouth polygon
                            table.insert(drawables, {
                                type = 'mouth-teeth',
                                z = composedZ,
                                extra = ud.extra,
                                body = body,
                            })
                        else
                            -- Mouth bezier curve decal (upper or lower lip)
                            local pts = ud.extra.curvePoints
                            if pts and #pts == 16 then
                                local s = pts
                                local curveData
                                if ud.extra.mouthCurve == 'upper' then
                                    curveData = {
                                        s[1], s[2], s[3], s[4],
                                        s[3], s[4], s[5], s[6],
                                        s[5], s[6], s[7], s[8],
                                        s[7], s[8], s[9], s[10],
                                    }
                                else
                                    -- Reverse lower lip curve to go left-to-right
                                    -- (matching upper lip direction) so texture orientation is consistent
                                    curveData = {
                                        s[1], s[2], s[15], s[16],
                                        s[15], s[16], s[13], s[14],
                                        s[13], s[14], s[11], s[12],
                                        s[11], s[12], s[9], s[10],
                                    }
                                end
                                table.insert(drawables, {
                                    type = 'mouth-' .. ud.extra.mouthCurve,
                                    z = composedZ,
                                    extra = ud.extra,
                                    body = body,
                                    curveData = curveData,
                                })
                            end
                        end
                    else
                        table.insert(drawables, {
                            type = 'decal',
                            z = composedZ,
                            extra = ud.extra,
                            body = body,
                        })
                    end
                end

                if ud and subtypes.is(ud, subtypes.CONNECTED_TEXTURE) and ud.extra.nodes then
                    -- logger:inspect(ud)
                    --logger:info('got some new kind of combined drawing todo!')
                    local points = {}
                    for j = 1, #ud.extra.nodes do
                        local it = ud.extra.nodes[j]
                        if it.type == NT.ANCHOR then
                            local f = registry.getSFixtureByID(it.id)
                            if f then
                                local b = f:getBody()
                                local centerX, centerY = mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape()
                                    :getPoints()) })
                                table.insert(points, centerX)
                                table.insert(points, centerY)
                            else
                                print('issue with finding achor, id:', it.id)
                            end
                        end
                        if it.type == NT.JOINT then
                            local jnt = registry.getJointByID(it.id)
                            if jnt and not jnt:isDestroyed() then
                                local x1, y1, _, _ = jnt:getAnchors()
                                table.insert(points, x1)
                                table.insert(points, y1)
                            end
                        end
                    end

                    if #points == 4 then
                        -- here we will just introduce a little midle thingie
                        -- -- becaue i cannot draw a curve of 2 points
                        local function addMidpoint(pts)
                            if #pts ~= 4 then
                                error("Expected array of exactly 2 points (4 numbers)")
                            end

                            local x1, y1, x2, y2 = pts[1], pts[2], pts[3], pts[4]
                            local midX = (x1 + x2) / 2
                            local midY = (y1 + y2) / 2

                            return { x1, y1, midX, midY, x2, y2 }
                        end

                        points = addMidpoint(points)
                    end

                    if #points >= 6 then
                        -- todo here we might want to grow the curve... so it will stick a little bit from the sides


                        -- todo parameterize this
                        local growLength = ud.extra.growExtra or 20
                        points[1], points[2] = growLine({ points[1], points[2] }, { points[3], points[4] }, growLength)
                        points[5], points[6] = growLine({ points[5], points[6] }, { points[3], points[4] }, growLength)


                        points = doubleControlPoints(points, 2)


                        local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                        --print(inspect(ud.extra))
                        table.insert(drawables,
                            {
                                z = composedZ,
                                type = 'connected-texture',
                                curve = love.math.newBezierCurve(points),
                                --texfixture = fixtures[i],
                                extra = ud.extra,
                                --body = body,
                                -- thing = body:getUserData().thing
                            })
                    end
                end
            end
        end
        return drawables
    end

    local drawables = createDrawables()
    -- todo this list needs to be kept around and sorted in place,
    -- resetting and doing all the work every frame is heavy!
    -- optimally i dont want to sort at all every frame, maybe i can
    -- add a flag to indicate that the list is sorted and only sort
    -- when necessary (when adding/removing)

    local function sorter(a, b) return a.z < b.z end

    local function sortDrawables()
        --print(#drawables)
        table.sort(drawables, sorter)
    end
    sortDrawables()



    -- todo: these3 function look very much alike, we wnat to combine them all in otne,
    -- another issue here is that i dont really understand how to set the ox and oy correctly, (for the combined Image)
    -- and there is an issue with the center of the 'fan' mesh, it
    -- shouldnt always be 0,0 you can see this when you position the
    -- texfxture with the
    -- onscreen 'd' button quite a distnace out of the actual physics body center.
    --
    -- local function drawImageLayerSquish(url, hex, extra, texfixture)
    --     -- print('jo!')
    --     local img, imgw, imgh = getLoveImage('textures/' .. url)
    --     local vertices = extra.vertices or { texfixture:getShape():getPoints() }

    --     if (vertices and img) then
    --         local body = texfixture:getBody()
    --         local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
    --         local sx = 1 --ww / imgw
    --         local sy = 1 --hh / imgh
    --         local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
    --         local r, g, b, a = lib.hexToColor(hex)
    --         love.graphics.setColor(r, g, b, a)
    --         --  drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
    --         drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices)
    --     end
    -- end
    local function drawImageLayerSquishRGBA(url, r, g, b, a, extra, texfixture)
        -- print('jo!')
        local img = getLoveImage('textures/' .. url)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }

        if (vertices and img) then
            local body = texfixture:getBody()
            --local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = 1 --ww / imgw
            local sy = 1 --hh / imgh
            --local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            -- local r, g, b, a = lib.hexToColor(hex)
            --logger:info(r, g, b, a)
            love.graphics.setColor(r, g, b, a)
            --  drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
            drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices)
        end
    end




    -- local function drawImageLayerVanilla(url, hex, extra, texfixture)
    --     local img, imgw, imgh = getLoveImage('textures/' .. url)
    --     local vertices = extra.vertices or { texfixture:getShape():getPoints() }

    --     if (vertices and img) then
    --         local body = texfixture:getBody()
    --         -- local body = texfixture:getBody()
    --         local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
    --         local sx = ww / imgw
    --         local sy = hh / imgh
    --         local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
    --         local r, g, b, a = lib.hexToColor(hex)
    --         love.graphics.setColor(r, g, b, a)

    --         love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
    --             body:getAngle(), sx * 1, sy * 1,
    --             (imgw) / 2, (imgh) / 2)



    --         --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
    --     end
    -- end

    local function drawCombinedImageVanilla(ompImage, extra, texfixture, _thing)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }
        local img = ompImage
        if vertices and img then
            local body = texfixture:getBody()
            -- local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = 1 --ww / imgw
            local sy = 1 --hh / imgh


            love.graphics.setColor(1, 1, 1, 1)

            if (extra.main.tint) then
                --                print('optimize this away, tint')
                local r, g, b, a = lib.hexToColor(extra.main.tint)
                love.graphics.setColor(r, g, b, a)
            end

            --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
            drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices)
        end
    end


    for i = 1, #drawables do
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture

        if drawables[i].type == subtypes.TEXFIXTURE then
            --if texfixture then
            local extra = drawables[i].extra
            --print(extra.dirty)
            if not extra.OMP then -- this is the BG and FG routine
                local main = extra.main
                -- local cached = main.cached
                --print(inspect(main))
                if main then
                    if not main.cached then
                        lib.makeCached(main)
                        print('Cached not found')
                        local cached = main.cached
                        print(cached.bgR, cached.bgG, cached.bgB, cached.bgA)
                    end
                    local cached = main.cached

                    if main and main.bgURL then
                        --logger:inspect(extra.main.cached)
                        love.graphics.setColor(1, 0, 0)
                        drawImageLayerSquishRGBA(extra.main.bgURL,
                            cached.bgR, cached.bgG, cached.bgB, cached.bgA,
                            extra, texfixture)
                        --  drawImageLayerSquish(extra.main.bgURL, extra.main.bgHex, extra, texfixture)
                        --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                    end
                    if extra.main and extra.main.fgURL then
                        --drawImageLayerSquish(extra.main.fgURL, extra.main.fgHex, extra, texfixture)
                        drawImageLayerSquishRGBA(extra.main.fgURL,
                            cached.fgR, cached.fgG, cached.fgB, cached.fgA,
                            extra, texfixture)
                        --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                    end
                end
            end

            if extra.OMP then
                if (texfixture and extra.ompImage) then
                    drawCombinedImageVanilla(extra.ompImage, extra, texfixture, thing)
                end
                --end
            end
        end

        local function currentAnchorLocal(infl)
            if infl.nodeType == NT.ANCHOR then
                local f = registry.getSFixtureByID(infl.nodeId)
                if not f then return infl.offx, infl.offy end
                local bp = f:getBody()

                local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
                local cx, cy = mathutils.getCenterOfPoints(pts)
                return bp:getLocalPoint(cx, cy)
            end

            if infl.nodeType == NT.JOINT then
                local joint = registry.getJointByID(infl.nodeId)
                if not joint then return infl.offx, infl.offy end

                local x1, y1, x2, y2 = joint:getAnchors()
                local bodyA, bodyB = joint:getBodies()

                if infl.side == SIDES.A then
                    return bodyA:getLocalPoint(x1, y1)
                else
                    return bodyB:getLocalPoint(x2, y2)
                end
            end

            return infl.offx, infl.offy
        end

        -- this is all wrong, the code works but this shouldbnt  be a responnsible in the drawloop, do this outside!
        -- really we want to do this on load or something.
        -- local function fillBodiesInInfluences(influences, numVerts)
        --     for vi = 1, numVerts do
        --         local inflList = influences[vi]
        --         for k = 1, #inflList do
        --             local infl   = inflList[k]
        --             --remove this to a preprocess step
        --             if not infl.body then
        --                 --print("infl.body is nil")
        --                 --print(inspect(infl))
        --                 if infl.nodeType == "anchor" then
        --                     local b = registry.getSFixtureByID(infl.nodeId):getBody()
        --                     infl.body = b
        --                 end
        --                 if infl.nodeType == "joint" then
        --                     local a,b = registry.getJointByID(infl.nodeId):getBodies()
        --                     if infl.side == "A" then
        --                         infl.body = a
        --                     else
        --                         infl.body = b
        --                     end
        --                 end
        --                 print("infl.body is now", infl.body)
        --             end
        --         end
        --     end
        --     return influences
        -- end

        local function deformWorldVerts(influences, numVerts, rootBody)
            local out = {}

            for vi = 1, numVerts do
                local inflList = influences[vi]
                local wxSum, wySum, wSum = 0, 0, 0
                --logger:inspect(inflList)   -- somehow this can end up being nil
                for k = 1, #inflList do
                    local infl = inflList[k]



                    local body   = infl.body

                    local ax, ay = currentAnchorLocal(infl)
                    local lx     = ax + infl.dx
                    local ly     = ay + infl.dy
                    local wx, wy = body:getWorldPoint(lx, ly)

                    local w      = infl.w
                    wxSum        = wxSum + wx * w
                    wySum        = wySum + wy * w
                    wSum         = wSum + w
                end

                if wSum > 0 then
                    wxSum = wxSum / wSum; wySum = wySum / wSum
                end

                -- convert blended world -> root local
                local rx, ry = rootBody:getLocalPoint(wxSum, wySum)
                out[(vi - 1) * 2 + 1] = rx -- wxSum
                out[(vi - 1) * 2 + 2] = ry --wySum
            end

            return out
        end

        if drawables[i].type == subtypes.MESHUSERT then
            -- now we need to find a mapping file..

            local mappert
            for _, v in pairs(registry.sfixtures) do
                if not v:isDestroyed() then
                    local ud = v:getUserData()

                    if (#ud.label > 0 and drawables[i].label == ud.label and subtypes.is(ud, subtypes.RESOURCE)) then
                        mappert = v
                    end
                end
            end

            local data = mappert and mappert:getUserData().extra
            if data then
                local bodyUD = mappert:getBody():getUserData()
                local verts = bodyUD.thing.vertices


                -- somehow we need to center the vertices.
                local cx, cy = mathutils.getCenterOfPoints(verts)
                verts = mathutils.makePolygonRelativeToCenter(verts, cx, cy)

                -- maybe here we deal with translate and scale ? (rotation?)
                local x = drawables[i].extra.meshX or 0
                local y = drawables[i].extra.meshY or 0
                --print(x, y)
                verts = mathutils.transformPolygonPoints(verts, x, y)
                local sx = drawables[i].extra.scaleX or 1
                local sy = drawables[i].extra.scaleY or 1
                verts = mathutils.scalePolygonPoints(verts, sx, sy)


                if drawables[i].extra.influences and #drawables[i].extra.influences > 0 then
                    -- logger:inspect(drawables[i].extra.influences)
                    -- we need to fill in the bodies for each influence, but ratehr not everyframe!
                    --drawables[i].extra.influences = fillBodiesInInfluences(drawables[i].extra.influences, #verts/2)
                    local newVerts = deformWorldVerts(drawables[i].extra.influences, #verts / 2, drawables[i].body)
                    -- local worldBindVerts = vertsToWorld(drawables[i].body, verts)
                    -- logger:inspect(worldBindVerts)
                    --logger:inspect(newVerts)
                    verts = newVerts
                end



                --    local rotation = drawables[i].rotation or 0


                --logger:info(x, y)
                --logger:inspect(verts)


                local vertexFormat = {
                    { "VertexPosition", "float", 2 },
                    --    { "VertexTexCoord", "float", 2 },
                    { "VertexColor",    "byte",  4 },
                }
                local meshVertices = {}
                --logger:inspect(verts)
                local tris = shapes.makeTrianglesFromPolygon(verts)

                for j = 1, #tris do
                    local tri = tris[j]
                    for k = 0, 2 do
                        local vx = tri[k * 2 + 1]
                        local vy = tri[k * 2 + 2]
                        table.insert(meshVertices, {
                            vx, vy,
                            -- u, v,
                            255, 255, 255, .100
                        })
                    end
                end
                if data and data.uvs then
                     meshVertices = {}
                      vertexFormat = {
                         { "VertexPosition", "float", 2 },
                             { "VertexTexCoord", "float", 2 },
                         { "VertexColor",    "byte",  4 },
                     }
                    --print('got some uvs ready too!')
                    for j = 1, #tris do
                        local tri = tris[j]
                        for k = 0, 2 do
                            local vx = tri[k * 2 + 1]
                            local vy = tri[k * 2 + 2]
                            local u, v --= 1, 1
                            --print(vx, inspect(verts))
                            for l = 1, #verts do
                                --  print()
                                if math.abs(vx - verts[l]) < 0.001 then
                                    u = data.uvs[l]
                                end

                                if math.abs(vy - verts[l]) < 0.001 then
                                    v = data.uvs[l]
                                end
                            end

                            table.insert(meshVertices, {
                                vx, vy,
                                u, v,
                                255, 255, 255
                            })
                        end
                    end

                end
                local mesh = love.graphics.newMesh(vertexFormat, meshVertices, 'triangles')
                 if data and data.uvs then
                mesh:setTexture(state.backdrops[data.selectedBGIndex].image)
                 end
                local bx, by = drawables[i].body:getPosition()
                local ba = drawables[i].body:getAngle()
                love.graphics.draw(mesh, bx, by, ba)

                -- love.graphics.push()
                -- love.graphics.translate(body:getX(), body:getY())
                -- love.graphics.rotate(body:getAngle())
                --love.graphics.polygon("line", verts)
                -- love.graphics.pop()
            end
        end

        if drawables[i].type == subtypes.UVUSERT then
            -- now we need to find a mapping file..

            local mappert
            for _, v in pairs(registry.sfixtures) do
                local ud = v:getUserData()
                if (drawables[i].label == ud.label and subtypes.is(ud, subtypes.RESOURCE)) then
                    mappert = v
                end
            end
            local data = mappert and mappert:getUserData().extra
            if data and data.uvs then
                --print(inspect(data))
                --print('getting close')


                local bx, by = drawables[i].body:getPosition()
                local ba = drawables[i].body:getAngle()
                local b = drawables[i].body:getUserData()
                --print(inspect(b.thing.vertices))

                local centerX, centerY = mathutils.getCenterOfPoints(b.thing.vertices)
                local verts = {}

                for vi = 1, #b.thing.vertices, 2 do
                    verts[vi] = b.thing.vertices[vi] - centerX
                    verts[vi + 1] = b.thing.vertices[vi + 1] - centerY
                end


                local p = {}
                for vi = 1, #verts, 2 do
                    table.insert(p, { verts[vi], verts[vi + 1] })
                end


                local vertexFormat = {
                    { "VertexPosition", "float", 2 },
                    { "VertexTexCoord", "float", 2 },
                    { "VertexColor",    "byte",  4 },
                }
                local meshVertices = {}
                -- for i = 1, #verts, 2 do
                --     table.insert(meshVertices, {
                --         verts[i], verts[i + 1],
                --         data.uvs[i], data.uvs[i + 1],
                --         255, 255, 255
                --     })
                -- end
                local tris = shapes.makeTrianglesFromPolygon(verts)


                for j = 1, #tris do
                    local tri = tris[j]
                    for k = 0, 2 do
                        local x = tri[k * 2 + 1]
                        local y = tri[k * 2 + 2]
                        local u, v --= 1, 1
                        --print(x, inspect(verts))
                        for l = 1, #verts do
                            --  print()
                            if math.abs(x - verts[l]) < 0.001 then
                                u = data.uvs[l]
                            end

                            if math.abs(y - verts[l]) < 0.001 then
                                v = data.uvs[l]
                            end
                        end

                        table.insert(meshVertices, {
                            x, y,
                            u, v,
                            255, 255, 255
                        })
                    end
                end


                --print(inspect(tris))
                -- print(#tris)


                local mesh = love.graphics.newMesh(vertexFormat, meshVertices, 'triangles')
                mesh:setTexture(state.backdrops[data.selectedBGIndex].image)

                --local mesh = love.graphics.newMesh(p)
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(mesh, bx, by, ba)
                love.graphics.setColor(1, 1, 1)
            end
            --print(inspect(mappert:getUserData().extra))


            -- local findLabel = drawables[i].label
            -- for k, v in pairs(registry.sfixtures) do
            --     local ud = v:getUserData()
            --     if (findLabel == ud.label and subtypes.is(ud, subtypes.RESOURCE)) then
            --         --   print('fount the uvmappert for me.', findLabel)
            --         -- this needs to have th euvdata and point me to the right bg image
            --         --
            --         --
            --         local bx, by = drawables[i].body:getPosition()
            --         local ba = drawables[i].body:getAngle()
            --         local b = drawables[i].body:getUserData()
            --         --print(inspect(b.thing.vertices))

            --         local centerX, centerY = mathutils.getCenterOfPoints(b.thing.vertices)
            --         local verts = {}
            --         for i = 1, #b.thing.vertices, 2 do
            --             verts[i] = b.thing.vertices[i] - centerX
            --             verts[i + 1] = b.thing.vertices[i + 1] - centerY
            --         end


            --         local p = {}
            --         for i = 1, #verts, 2 do
            --             table.insert(p, { verts[i], verts[i + 1] })
            --         end
            --         local mesh = love.graphics.newMesh(p)
            --         print('aybe start using the real uvs now?')
            --         love.graphics.setColor(1, .5, .5)
            --         love.graphics.draw(mesh, bx, by, ba)
            --         love.graphics.setColor(1, 1, 1)
            --         --print(inspect(b))
            --         --print(inspect(ud))
            --         --local b = v:getBody()
            --         --local bud = b:getUserData()
            --         --print(inspect(bud))
            --     end

            --     -- local mesh = love.graphics.newMesh()
            --     -- love.graphics.draw(mesh)
            -- end
            --            print('uv rendering galore!')
        end

        if drawables[i].type == subtypes.CONNECTED_TEXTURE then
            local curve = drawables[i].curve
            local derivate = curve:getDerivative()
            local extra = drawables[i].extra
            if not extra.OMP then -- this is the BG and FG routine
                local main = extra.main
                -- local cached = main.cached
                if not main.cached then
                    lib.makeCached(main)
                    --print('Cached not found')
                end
                local cached = main.cached


                if extra.main and extra.main.bgURL then
                    local img = getLoveImage('textures/' .. extra.main.bgURL)
                    if img then
                        --local mesh = createTexturedTriangleStrip(img)
                        local mesh = getStrip(img, extra.main.wmul or 1)
                        texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1, derivate)
                        --local olr, olg, olb, ola = lib.hexToColor(extra.main.bgHex)
                        love.graphics.setColor(cached.bgR, cached.bgG, cached.bgB, cached.bgA)
                        love.graphics.draw(mesh)
                    end
                end
                if extra.main and extra.main.fgURL then
                    local img = getLoveImage('textures/' .. extra.main.fgURL)
                    if img then
                        --print(extra.main.wmul)
                        --local mesh = createTexturedTriangleStrip(img)
                        local mesh = getStrip(img, extra.main.wmul or 1)
                        texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1, derivate)
                        --local olr, olg, olb, ola = lib.hexToColor(extra.main.fgHex)
                        -- love.graphics.setColor(olr, olg, olb, ola)
                        love.graphics.setColor(cached.fgR, cached.fgG, cached.fgB, cached.fgA)
                        love.graphics.draw(mesh)
                    end
                end
            end
            if extra.OMP then
                local img = extra.ompImage
                if img then
                    --local mesh = createTexturedTriangleStrip(img)
                    local mesh = getStrip(img, extra.main.wmul or 1)
                    texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1, derivate)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(mesh)
                end
            end
        end

        if drawables[i].type == subtypes.TILE_REPEAT then
            local vertices = drawables[i].thing.vertices
            -- todo CACHE THIS!!
            local tris = drawables[i].thing._tris or shapes.makeTrianglesFromPolygon(vertices)
            drawables[i].thing._tris = tris

            local img = getLoveImage('textures/' .. drawables[i].extra.main.bgURL)
            if img then
                if not drawables[i].extra._mesh then
                    img:setWrap("repeat", "repeat")
                    local texW, texH = img:getWidth(), img:getHeight()
                    local centroidX, centroidY = mathutils.computeCentroid(vertices)
                    local meshVertices = {}

                    local twm = drawables[i].extra.tileWidthM
                    local thm = drawables[i].extra.tileHeightM
                    local tr = drawables[i].extra.tileRotation
                    --print(twm, thm, tr)
                    local uvParams = {
                        tileWidth = texW * twm,  --bb.width,    -- world units per tile horizontally
                        tileHeight = texH * thm, --bb.height,  -- world units per tile vertically
                        rotate = tr,             -- radians
                        offsetX = 0,             -- offset in world units
                        offsetY = 0,
                        scaleX = 1,              -- scale texture space (can be 1 / repeatX)
                        scaleY = 1,
                        anchor = "center",       -- or "top-left"
                        keepAspect = false       -- optional flag to preserve aspect ratio
                    }

                    for j = 1, #tris do
                        local tri = tris[j]
                        for k = 0, 2 do
                            local x = tri[k * 2 + 1]
                            local y = tri[k * 2 + 2]
                            local u, v = transformUV(x, y, centroidX, centroidY, uvParams)
                            table.insert(meshVertices, {
                                x - centroidX, y - centroidY,
                                u, v,
                                255, 255, 255, 255
                            })
                        end
                    end

                    local vertexFormat = {
                        { "VertexPosition", "float", 2 },
                        { "VertexTexCoord", "float", 2 },
                        { "VertexColor",    "byte",  4 },
                    }

                    local mesh = love.graphics.newMesh(vertexFormat, meshVertices, "triangles")
                    mesh:setTexture(img)
                    drawables[i].extra._mesh = mesh
                end


                local r, g, b, a = lib.hexToColor(drawables[i].extra.main.tint or 'ffffffff')
                love.graphics.setColor(r, g, b, a)

                local body = drawables[i].thing.body
                love.graphics.draw(drawables[i].extra._mesh, body:getX(), body:getY(), body:getAngle())
            end
        end

        if drawables[i].type == subtypes.TRACE_VERTICES then
            local length = (#drawables[i].thing.vertices) / 2
            local startIndex = drawables[i].extra.startIndex
            local endIndex = drawables[i].extra.endIndex
            local indices = getIndices(length, startIndex, endIndex)
            local points = {}
            local pointsflat = {}
            -- logger:info(length)
            -- logger:inspect(indices)
            for j = 1, #indices do
                --local index = indices[j]
                local x = drawables[i].thing.vertices[indices[j] * 2 + 1]
                local y = drawables[i].thing.vertices[indices[j] * 2 + 2]
                table.insert(points, { x, y })
                table.insert(pointsflat, x)
                table.insert(pointsflat, y)
            end


            if #points >= 2 then
                --love.graphics.line(pointsflat)
                --if drawables[i].extra.main.bgURL
                local extra = drawables[i].extra
                local useOMP = extra.OMP and extra.ompImage
                local img
                if useOMP then
                    img = extra.ompImage
                else
                    img = getLoveImage('textures/' .. (extra.main.bgURL))
                    if not img then
                        img = getLoveImage('textures/' .. 'hair7.png')
                    end
                end

                local hairTension = extra.tension or .02 -- love.math.random() --.02
                local spacing = extra.spacing or 5
                -- 5                                                    --* multipliers.hair.sMultiplier
                local coords = mathutils.unloosenVanillaline(points, hairTension, spacing)
                --local factor = (length / h)
                --local hairWidthMultiplier = 1 --* multipliers.hair.wMultiplier
                local width = extra.width or 100 -- 100 --(w * factor) / 2
                --2                         -- 100             (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
                local verts = polyline.render('miter', coords, width)

                local cx, cy = mathutils.getCenterOfPoints(drawables[i].thing.vertices)
                for vi = 1, #verts do
                    verts[vi][1] = verts[vi][1] - cx
                    verts[vi][2] = verts[vi][2] - cy
                end

                local vertsWithUVs = {}

                for vi = 1, #verts do
                    local u = (vi % 2 == 1) and 0 or 1
                    local v = math.floor(((vi - 1) / 2)) / (#verts / 2 - 1)
                    vertsWithUVs[vi] = { verts[vi][1], verts[vi][2], u, v }
                end

                local vertices = vertsWithUVs


                local m = love.graphics.newMesh(vertices, "strip")
                m:setTexture(img)
                local body = drawables[i].thing.body
                if useOMP then
                    love.graphics.setColor(1, 1, 1, 1)
                else
                    local main = extra.main
                    if main then
                        if not main.cached then lib.makeCached(main) end
                        local c = main.cached
                        love.graphics.setColor(c.bgR, c.bgG, c.bgB, c.bgA)
                    end
                end
                love.graphics.draw(m, body:getX(), body:getY(), body:getAngle())
                love.graphics.setColor(1, 1, 1, 1)
            end
            --logger:inspect(points)
            --logger:inspect()
        end

        if drawables[i].type == 'decal' then
            local extra = drawables[i].extra
            local body = drawables[i].body
            if body and not body:isDestroyed() then
                local ox, oy = extra.ox or 0, extra.oy or 0
                if extra.lookAtMouse and extra.eyeW then
                    local mx, my = love.mouse.getPosition()
                    local wmx, wmy = cam:getWorldCoordinates(mx, my)
                    local ecx, ecy = body:getWorldPoint(ox, oy)
                    local dx, dy = wmx - ecx, wmy - ecy
                    local angle = math.atan2(dy, dx)
                    local localAngle = angle - body:getAngle()
                    local dw = extra.w or 0
                    local dh = extra.h or 0
                    local maxX = math.max(0, (extra.eyeW - dw) / 2)
                    local maxY = math.max(0, (extra.eyeH - dh) / 2)
                    ox = ox + math.cos(localAngle) * maxX
                    oy = oy + math.sin(localAngle) * maxY
                end
                local wx, wy = body:getWorldPoint(ox, oy)
                local angle = body:getAngle() + (extra.rot or 0)
                local dw = extra.w or 50
                local dh = extra.h or 50
                local mirrorX = extra.mirror and -1 or 1

                if extra.OMP and extra.ompImage then
                    -- Pre-composited OMP image (has proper alpha)
                    local img = extra.ompImage
                    local imgw, imgh = img:getDimensions()
                    local sx = dw / imgw * mirrorX
                    local sy = dh / imgh
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
                elseif extra.bgURL and extra.bgURL ~= '' then
                    -- Simple single-color tinted image (no mask)
                    local img, imgw, imgh = getLoveImage('textures/' .. extra.bgURL)
                    if img then
                        local sx = dw / imgw * mirrorX
                        local sy = dh / imgh
                        local r, g, b, a = lib.hexToColor(extra.bgHex or 'ffffffff')
                        love.graphics.setColor(r, g, b, a)
                        love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
                    end
                end
            end
        end

        -- Brow: bezier curve with bend pattern
        if drawables[i].type == 'brow' then
            local extra = drawables[i].extra
            local body = drawables[i].body
            if body and not body:isDestroyed() and extra.bgURL then
                local browBends = {
                    { 0, 0, 0 },       -- 1: flat
                    { 1, 0, -1 },      -- 2: angry
                    { -1, 0, 1 },      -- 3: sad
                    { 1, 0, 1 },       -- 4: raised both ends
                    { -1, 0, -1 },     -- 5: lowered both ends
                    { 1, 0, 0 },       -- 6: raise left
                    { -1, 0, 0 },      -- 7: lower left
                    { 0, -1, 1 },      -- 8: center down, right up
                    { 0, 1, 1 },       -- 9: center up, right up
                    { -1, 1, 1 },      -- 10: asymmetric
                }

                local angle = body:getAngle()
                local bx, by = body:getPosition()

                love.graphics.push()
                love.graphics.translate(bx, by)
                love.graphics.rotate(angle)

                local browImg = getLoveImage('textures/' .. extra.bgURL)
                if browImg then
                    local w = extra.w or 20
                    local h = extra.h or 10
                    local bendIdx = extra.browBend or 1
                    local bend = browBends[bendIdx] or browBends[1]
                    local bendMul = w / 5

                    -- Build curve at origin, same for both sides
                    local ox = extra.ox or 0
                    local oy = extra.oy or 0

                    local p1x = -w / 2
                    local p1y = bend[1] * bendMul
                    local p2x = 0
                    local p2y = bend[2] * bendMul
                    local p3x = w / 2
                    local p3y = bend[3] * bendMul

                    -- Double control points to create a proper bezier
                    local curveData = {
                        p1x, p1y,
                        (p1x + p2x) / 2, (p1y + p2y) / 2,
                        (p2x + p3x) / 2, (p2y + p3y) / 2,
                        p3x, p3y,
                    }

                    local curve = love.math.newBezierCurve(curveData)
                    local lipScale = h / (browImg:getHeight() * 2)
                    local mesh = getStrip(browImg, lipScale)
                    local r, g, b, a = lib.hexToColor(extra.bgHex or '000000ff')
                    love.graphics.setColor(r, g, b, a)
                    texturedCurve(curve, browImg, mesh, -1, lipScale)
                    -- Mirror right brow via sx=-1, matching puppet-maker2 approach
                    local mirrorSx = extra.browMirror and -1 or 1
                    love.graphics.draw(mesh, ox, oy, 0, mirrorSx, 1)
                end

                love.graphics.pop()
            end
        end

        -- Mouth lower lip: stencil-fill interior + draw lower lip curve
        if drawables[i].type == 'mouth-lower' then
            local extra = drawables[i].extra
            local body = drawables[i].body
            local curveData = drawables[i].curveData
            if body and not body:isDestroyed() and curveData then
                local angle = body:getAngle()
                local bx, by = body:getPosition()

                love.graphics.push()
                love.graphics.translate(bx, by)
                love.graphics.rotate(angle)

                local cleaned = buildMouthPolygon(extra.curvePoints)
                local downCurve = love.math.newBezierCurve(curveData)

                if cleaned then
                    local tris = shapes.makeTrianglesFromPolygon(cleaned)
                    if tris and #tris > 0 then
                        -- Stencil fill with backdrop color
                        love.graphics.stencil(function()
                            for ti = 1, #tris do
                                love.graphics.polygon("fill", tris[ti])
                            end
                        end, "replace", 1)
                        love.graphics.setStencilTest("equal", 1)

                        local br, bg, bb, ba = lib.hexToColor(extra.backdropHex or '00000033')
                        love.graphics.setColor(br, bg, bb, ba)
                        -- Fill bounding rect
                        local minX, minY, maxX, maxY = cleaned[1], cleaned[2], cleaned[1], cleaned[2]
                        for pi = 3, #cleaned, 2 do
                            if cleaned[pi] < minX then minX = cleaned[pi] end
                            if cleaned[pi + 1] < minY then minY = cleaned[pi + 1] end
                            if cleaned[pi] > maxX then maxX = cleaned[pi] end
                            if cleaned[pi + 1] > maxY then maxY = cleaned[pi + 1] end
                        end
                        love.graphics.rectangle("fill", minX - 2, minY - 2, maxX - minX + 4, maxY - minY + 4)
                        love.graphics.setStencilTest()
                    end
                end

                -- Draw lower lip curve (outside stencil block so it renders even for closed mouths)
                local lipImg = extra.ompImage
                if not lipImg and extra.main and extra.main.bgURL then
                    lipImg = getLoveImage('textures/' .. extra.main.bgURL)
                end
                if lipImg then
                    local mesh = getStrip(lipImg, extra.lipScale or 0.25)
                    love.graphics.setColor(1, 1, 1, 1)
                    texturedCurve(downCurve, lipImg, mesh, -1, extra.lipScale or 0.25)
                    love.graphics.draw(mesh)
                end

                love.graphics.pop()
            end
        end

        -- Mouth upper lip: draw upper lip curve on top
        if drawables[i].type == 'mouth-upper' then
            local extra = drawables[i].extra
            local body = drawables[i].body
            local curveData = drawables[i].curveData
            if body and not body:isDestroyed() and curveData then
                local angle = body:getAngle()
                local bx, by = body:getPosition()

                love.graphics.push()
                love.graphics.translate(bx, by)
                love.graphics.rotate(angle)

                local upCurve = love.math.newBezierCurve(curveData)
                local lipImg = extra.ompImage
                if not lipImg and extra.main and extra.main.bgURL then
                    lipImg = getLoveImage('textures/' .. extra.main.bgURL)
                end
                if lipImg then
                    local mesh = getStrip(lipImg, extra.lipScale or 0.25)
                    love.graphics.setColor(1, 1, 1, 1)
                    texturedCurve(upCurve, lipImg, mesh, -1, extra.lipScale or 0.25)
                    love.graphics.draw(mesh)
                end

                love.graphics.pop()
            end
        end

        -- Teeth: positioned image, optionally stencil-clipped to mouth interior
        if drawables[i].type == 'mouth-teeth' then
            local extra = drawables[i].extra
            local body = drawables[i].body
            if body and not body:isDestroyed() then
                local angle = body:getAngle()
                local bx, by = body:getPosition()

                love.graphics.push()
                love.graphics.translate(bx, by)
                love.graphics.rotate(angle)

                local img = extra.ompImage
                if not img and extra.main and extra.main.bgURL then
                    img = getLoveImage('textures/' .. extra.main.bgURL)
                end

                if img then
                    local ox = extra.ox or 0
                    local oy = extra.oy or 0
                    local w = extra.w or 20
                    local h = extra.h or 10
                    local imgW, imgH = img:getDimensions()
                    local scaleX = w / imgW
                    local scaleY = h / imgH

                    if not extra.teethStickOut then
                        -- Clip teeth to mouth polygon interior
                        local cleaned = buildMouthPolygon(extra.curvePoints)
                        if cleaned then
                            local tris = shapes.makeTrianglesFromPolygon(cleaned)
                            if tris and #tris > 0 then
                                love.graphics.stencil(function()
                                    for ti = 1, #tris do
                                        love.graphics.polygon("fill", tris[ti])
                                    end
                                end, "replace", 1)
                                love.graphics.setStencilTest("equal", 1)

                                love.graphics.setColor(1, 1, 1, 1)
                                love.graphics.draw(img, ox - w / 2, oy - h / 2, 0, scaleX, scaleY)

                                love.graphics.setStencilTest()
                            end
                        end
                    else
                        -- Stick out: draw freely, no stencil clipping
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(img, ox - w / 2, oy - h / 2, 0, scaleX, scaleY)
                    end
                end

                love.graphics.pop()
            end
        end
    end

    --  end)
    --love.graphics.setShader()
    --love.graphics.setDepthMode()
end

return lib
