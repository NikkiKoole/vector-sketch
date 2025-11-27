--[[
TODO Recreating meshes every frame in drawSquishableHairOver and createTexturedTriangleStrip (within drawTexturedWorld) is definitely inefficient. We should absolutely cache these.
]] --

local lib = {}
local state = require 'src.state'
local mathutils = require 'src.math-utils'
local polyline = require 'src.polyline'
local shapes = require 'src.shapes'

local tex1 = love.graphics.newImage('textures/pat/type2t.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')

local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
local imageCache = {}
local shrinkFactor = 1

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end
lib.getShrinkFactor = function()
    return shrinkFactor
end

function getLoveImage(path, settings)
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

local function growLineOLD(p1, p2, length)
    local angle = math.atan2(p1[2] - p2[2], p1[1] - p2[1])
    local new_x = p1[1] + length * math.cos(angle)
    local new_y = p1[2] + length * math.sin(angle)
    return new_x, new_y
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

function setBgColor(item, val)
    item.bgHex = val
    item.cached.bgR, item.cached.bgG, item.cached.bgB, item.cached.bgA = lib.hexToColor(val)
    item.cached.bgRGB = { item.cached.bgR, item.cached.bgG, item.cached.bgB }
end

function setFgColor(item, val)
    item.fgHex = val
    item.cached.fgR, item.cached.fgG, item.cached.fgB, item.cached.fgA = lib.hexToColor(val)
    item.cached.fgRGB = { item.cached.fgR, item.cached.fgG, item.cached.fgB }
end

function setPColor(item, val)
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

local function buildKey(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                        texOffX, texOffY,
                        lineColor, lineAlpha,
                        flipx, flipy, patches)
    local function toStr(v)
        if type(v) == "number" then
            return string.format("%.3f", v)
        elseif type(v) == "table" then
            return table.concat(v, ",")
        elseif type(v) == "boolean" then
            return v and "1" or "0"
        elseif type(v) == "userdata" and v.typeOf and v:typeOf("Image") then
            return tostring(v):match("Image: (.+)") or "image"
        else
            return tostring(v)
        end
    end

    local keyParts = {
        toStr(lineart),
        toStr(mask),
        toStr(color1), alpha1,
        toStr(texture2), toStr(color2), alpha2,
        texRot, texScaleX, texScaleY,
        texOffX, texOffY,
        toStr(lineColor), lineAlpha,
        flipx, flipy
    }

    if patches then
        for _, p in ipairs(patches) do
            table.insert(keyParts, toStr(p.img))
            table.insert(keyParts, p.tx or 0)
            table.insert(keyParts, p.ty or 0)
            table.insert(keyParts, p.r or 0)
            table.insert(keyParts, p.sx or 1)
            table.insert(keyParts, p.sy or 1)
            table.insert(keyParts, p.tint or "ffffff")
        end
    end

    return table.concat(keyParts, "|")
end

local testCache = {}
-- todo /5 and *5 is dumb!
lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patches)
    local key = buildKey(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
        texOffX, texOffY,
        lineColor, lineAlpha,
        flipx, flipy, patches)

    if testCache[key] == true then
        --    logger:info('double?', key)
    end
    testCache[key] = true
    --  logger:info(key)

    if true then
        local lineartColor = lineColor or { 0, 0, 0, 1 }
        local lw, lh = lineart:getDimensions()
        --  local dpiScale = 1 --love.graphics.getDPIScale()
        local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })

        love.graphics.setCanvas({ canvas, stencil = false }) --<<<

        --

        -- the reason for outline ghost stuff is this color
        -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<

        if (true) then
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
        end

        if true then
            if patches then
                for i = 1, #patches do
                    local patch = patches[i]
                    if patch and patch.img then
                        love.graphics.setColorMask(true, true, true, false)
                        print('hextocolor patches')
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
end

function makePatch(name, ud)
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
            if true then
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
                    local maskImage = getLoveImage('textures/' .. main.fgURL)
                    local patternImage = getLoveImage('textures/pat/' .. main.pURL)

                    if outlineImage or line then
                        local imgData = lib.makeTexturedCanvas(
                            outlineImage or line, -- line art
                            maskImage or maskTex, -- mask
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
                            { patch1, patch2, patch3 } -- renderPatch (set to truthy to enable extra patch rendering)
                        )
                        image = love.graphics.newImage(imgData)
                        ud.extra.ompImage = image
                    end
                    fixtures[i]:setUserData(ud)

                    ud.extra.dirty = false
                end
            end
            ud = nil
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




local function drawSquishableHairOverOLD(img, x, y, r, sx, sy, growFactor, vertices)
    local p = {}
    for i = 1, #vertices do
        p[i] = vertices[i] * growFactor
    end
    -- local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
    local uvs = makeSquishableUVsFromPoints(p)


    -- todo maybe parametrize this point so you can make the midle of the fan not be the exact middle of the polygon.
    local cx, cy, _, _ = mathutils.getCenterOfPoints(vertices)
    table.insert(uvs, 1, { cx, cy, .5, .5 }) -- I will just alwasy put a center vertex as the first one

    local _mesh = love.graphics.newMesh(uvs) --or love.graphics.newMesh(uvs, 'fan')
    local img = img
    _mesh:setTexture(img)

    -- i believe sx and sy will just always be 1
    love.graphics.draw(_mesh, x, y, r, sx, sy)
end

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


-- Optionally pass dl (precomputed derivative curve) if you have it.
function meshGetVertex(mesh, j)
    local x, y, u, v = mesh:getVertex(j)
    return x, y, u, v
end

-- todo segments need to be parameterized
function createTexturedTriangleStrip(image, optionalWidthMultiplier)
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

    for i = 1, segments do
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

-- https://love2d.org/forums/viewtopic.php?t=83410
function texturedCurveOLD2(curve, image, mesh, dir, scaleW, dl)
    dir         = dir or 1
    scaleW      = scaleW or 1

    dl          = dl or curve:getDerivative()

    -- Only need width here
    local w     = image:getWidth()
    local line  = (w * dir) * scaleW

    local count = mesh:getVertexCount()
    local tmp   = { 0, 0, 0, 0 } -- reusable vertex table: {x, y, u, v}

    for j = 1, count, 2 do
        -- Map vertex pair index to [0,1] parameter
        local t                        = (j - 1) / (count - 2)

        -- Point on curve + derivative
        local x, y                     = curve:evaluate(t)
        local dx, dy                   = dl:evaluate(t)

        -- Normalize derivative and build its left normal (-dy, dx)
        local invlen                   = 1.0 / math.sqrt(dx * dx + dy * dy + 1e-12) -- avoid div-by-zero
        dx, dy                         = dx * invlen, dy * invlen
        local nx, ny                   = -dy, dx

        -- Offset to both sides
        local x2                       = x + line * nx
        local y2                       = y + line * ny
        local x3                       = x - line * nx
        local y3                       = y - line * ny

        -- Keep existing UVs

        local _, _, u1, v1             = mesh:getVertex(j)
        tmp[1], tmp[2], tmp[3], tmp[4] = x2, y2, u1, v1
        mesh:setVertex(j, tmp)

        local _, _, u2, v2 = mesh:getVertex(j + 1)
        tmp[1], tmp[2], tmp[3], tmp[4] = x3, y3, u2, v2
        mesh:setVertex(j + 1, tmp)
    end
end

-- Batched, no mesh:getVertex, 1x mesh:setVertices per call
function texturedCurve(curve, image, mesh, dir, scaleW, dl)
    dir             = dir or 1
    scaleW          = scaleW or 1
    dl              = dl or curve:getDerivative()

    -- Only need the texture width to set half-width of the ribbon
    local w         = image:getWidth()
    local line      = (w * dir) * scaleW

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
        local xL                   = x + line * nx
        local yL                   = y + line * ny
        local xR                   = x - line * nx
        local yR                   = y - line * ny

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

-- this function is a bunch slower then the new one.
function texturedCurveOLD(curve, image, mesh, dir, scaleW)
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

local function doubleControlPointsOld(points, duplications)
    local result = {}

    -- Sanity check: must be even number of values
    if #points % 2 ~= 0 then
        error("Input array must have even number of elements (x, y pairs)")
    end

    local numPoints = #points / 2

    for i = 1, numPoints do
        local x = points[(i - 1) * 2 + 1]
        local y = points[(i - 1) * 2 + 2]

        table.insert(result, x)
        table.insert(result, y)

        -- Double the point if it's a *middle* point (not first or last)
        if i > 1 and i < numPoints then
            for j = 1, duplications do
                table.insert(result, x)
                table.insert(result, y)
            end
        end
    end

    return result
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
            -- todo instead of having to check all the fixtures every frame we should mark a thing that has these type of specialfixtures.
            local fixtures = body:getFixtures()
            for i = 1, #fixtures do
                local ud = fixtures[i]:getUserData()
                if type(ud) ~= 'table' then -- vanwege softbodies bullshit
                    ud = nil
                end
                if ud and ud.subtype == 'trace-vertices' then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                    table.insert(drawables, {
                        type = 'trace-vertices',
                        z = composedZ,
                        extra = ud.extra,
                        thing = body:getUserData().thing
                    })
                end

                if ud and ud.subtype == 'tile-repeat' then
                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                    table.insert(drawables, {
                        type = 'tile-repeat',
                        z = composedZ,
                        extra = ud.extra,
                        thing = body:getUserData().thing
                    })
                end

                if (ud and ud.extra and ud.extra.type == 'texfixture') or (ud and ud.subtype == 'texfixture') then
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
                if ud and ud.subtype == 'meshusert' then
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
                if ud and ud.subtype == 'uvusert' then
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
                if ud and (ud.label == "connected-texture" or ud.subtype == 'connected-texture') and ud.extra.nodes then
                    -- logger:inspect(ud)
                    --logger:info('got some new kind of combined drawing todo!')
                    local points = {}
                    for j = 1, #ud.extra.nodes do
                        local it = ud.extra.nodes[j]
                        if it.type == 'anchor' then
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
                        if it.type == 'joint' then
                            local j = registry.getJointByID(it.id)
                            if j and not j:isDestroyed() then
                                local x1, y1, _, _ = j:getAnchors()
                                table.insert(points, x1)
                                table.insert(points, y1)
                            end
                        end
                    end

                    if #points == 4 then
                        -- here we will just introduce a little midle thingie
                        -- -- becaue i cannot draw a curve of 2 points
                        function addMidpoint(points)
                            if #points ~= 4 then
                                error("Expected array of exactly 2 points (4 numbers)")
                            end

                            local x1, y1, x2, y2 = points[1], points[2], points[3], points[4]
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
    -- todo this list needs to be kept around and sorted in place, resetting and doing all the work every frame is heavy!
    -- optimally i dont want to sort at all every frame, maybe i can add a flag to indicate that the list is sorted and only sort when necessary (when adding/removing)

    local function sorter(a, b) return a.z < b.z end

    local function sortDrawables()
        --print(#drawables)
        table.sort(drawables, sorter)
    end
    sortDrawables()



    -- todo: these3 function look very much alike, we wnat to combine them all in otne,
    -- another issue here is that i dont really understand how to set the ox and oy correctly, (for the combined Image)
    -- and there is an issue with the center of the 'fan' mesh, it shouldnt always be 0,0 you can see this when you position the texfxture with the
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
        local img, imgw, imgh = getLoveImage('textures/' .. url)
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

    local function drawCombinedImageVanilla(ompImage, extra, texfixture, thing)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }
        local img = ompImage
        local imgw, imgh = ompImage:getDimensions()

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
        local body = drawables[i].body
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture

        if drawables[i].type == 'texfixture' then
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
                        drawImageLayerSquishRGBA(extra.main.bgURL, cached.bgR, cached.bgG, cached.bgB, cached.bgA, extra,
                            texfixture)
                        --  drawImageLayerSquish(extra.main.bgURL, extra.main.bgHex, extra, texfixture)
                        --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                    end
                    if extra.main and extra.main.fgURL then
                        --drawImageLayerSquish(extra.main.fgURL, extra.main.fgHex, extra, texfixture)
                        drawImageLayerSquishRGBA(extra.main.fgURL, cached.fgR, cached.fgG, cached.fgB, cached.fgA, extra,
                            texfixture)
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

        if drawables[i].type == 'meshusert' then
            -- now we need to find a mapping file..

            local mappert
            for k, v in pairs(registry.sfixtures) do
                if not v:isDestroyed() then
                    local ud = v:getUserData()

                    if (#ud.label > 0 and drawables[i].label == ud.label and ud.subtype == 'resource') then
                        mappert = v
                    end
                end
            end

            local data = mappert and mappert:getUserData().extra
            if data then
                local bodyUD = mappert:getBody():getUserData()
                local thing2 = bodyUD.thing
                local verts = thing2.vertices


                -- somehow we need to center the vertices.
                local vx, vy = mathutils.getCenterOfPoints(verts)
                verts = mathutils.makePolygonRelativeToCenter(verts, vx, vy)

                -- maybe here we deal with translate and scale ? (rotation?)
                local x = drawables[i].extra.meshX or 0
                local y = drawables[i].extra.meshY or 0
                --print(x, y)
                verts = mathutils.transformPolygonPoints(verts, x, y)
                local sx = drawables[i].extra.scaleX or 1
                local sy = drawables[i].extra.scaleY or 1
                verts = mathutils.scalePolygonPoints(verts, sx, sy)


                --    local rotation = drawables[i].rotation or 0


                local body = drawables[i].body
                --logger:info(x, y)
                --logger:inspect(verts)


                local vertexFormat = {
                    { "VertexPosition", "float", 2 },
                    --    { "VertexTexCoord", "float", 2 },
                    { "VertexColor",    "byte",  4 },
                }
                meshVertices = {}

                local tris = shapes.makeTrianglesFromPolygon(verts)

                for j = 1, #tris do
                    local tri = tris[j]
                    for k = 0, 2 do
                        local x = tri[k * 2 + 1]
                        local y = tri[k * 2 + 2]
                        table.insert(meshVertices, {
                            x, y,
                            -- u, v,
                            255, 255, 255, .100
                        })
                    end
                end

                local mesh = love.graphics.newMesh(vertexFormat, meshVertices, 'triangles')
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

        if drawables[i].type == 'uvusert' then
            -- now we need to find a mapping file..

            local mappert
            for k, v in pairs(registry.sfixtures) do
                local ud = v:getUserData()
                if (drawables[i].label == ud.label and ud.subtype == 'resource') then
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

                for i = 1, #b.thing.vertices, 2 do
                    verts[i] = b.thing.vertices[i] - centerX
                    verts[i + 1] = b.thing.vertices[i + 1] - centerY
                end


                local p = {}
                for i = 1, #verts, 2 do
                    table.insert(p, { verts[i], verts[i + 1] })
                end


                local vertexFormat = {
                    { "VertexPosition", "float", 2 },
                    { "VertexTexCoord", "float", 2 },
                    { "VertexColor",    "byte",  4 },
                }
                meshVertices = {}
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
                        --print('why i?,', u, v)
                        --if u == nil then u = 0 end

                        if u == nil or v == nil then
                            print('asdasd')
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
            --     if (findLabel == ud.label and ud.subtype == 'resource') then
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

        if drawables[i].type == 'connected-texture' then
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

        if drawables[i].type == 'tile-repeat' then
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
                    local bb = mathutils.getBoundingRect(vertices)
                    -- bb.width and bb.height
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

        if drawables[i].type == 'trace-vertices' then
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
                local img = getLoveImage('textures/' .. (drawables[i].extra.main.bgURL))
                if not img then
                    img = getLoveImage('textures/' .. 'hair7.png')
                end

                local w, h = img:getDimensions()

                local hairTension = drawables[i].extra.tension or .02 -- love.math.random() --.02
                local spacing = drawables[i].extra.spacing or 5
                -- 5                                                    --* multipliers.hair.sMultiplier
                local coords = mathutils.unloosenVanillaline(points, hairTension, spacing)
                -- logger:info('check these below')
                -- logger:inspect(points)
                -- logger:inspect(coords)
                local length = mathutils.getLengthOfPath(points)

                --local factor = (length / h)
                --local hairWidthMultiplier = 1 --* multipliers.hair.wMultiplier
                local width = drawables[i].extra.width or 100 -- 100 --(w * factor) / 2
                --2                         -- 100             (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
                local verts, indices, draw_mode = polyline.render('miter', coords, width)

                local cx, cy = mathutils.getCenterOfPoints(drawables[i].thing.vertices)
                for i = 1, #verts do
                    verts[i][1] = verts[i][1] - cx
                    verts[i][2] = verts[i][2] - cy
                end

                local vertsWithUVs = {}

                for i = 1, #verts do
                    local u = (i % 2 == 1) and 0 or 1
                    local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                    vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
                end

                local vertices = vertsWithUVs


                local m = love.graphics.newMesh(vertices, "strip")
                m:setTexture(img)
                local body = drawables[i].thing.body
                --local cx, cy, ww, hh = mathutils.getCenterOfPoints(drawables[i].thing.vertices)
                love.graphics.draw(m, body:getX(), body:getY(), body:getAngle())
            end
            --logger:inspect(points)
            --logger:inspect()
        end
    end

    --  end)
    --love.graphics.setShader()
    --love.graphics.setDepthMode()
end

function resolveIndex(index, length)
    return (index < 0) and ((length + index) % length) or (index % length)
end

function getIndices(length, startIdx, endIdx, allowFullLoop)
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

return lib
