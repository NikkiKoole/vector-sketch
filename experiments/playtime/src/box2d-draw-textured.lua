local lib = {}
local state = require 'src.state'
local mathutils = require 'src.math-utils'


local img = love.graphics.newImage('textures/leg1.png')
local tex1 = love.graphics.newImage('textures/pat/type2t.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
--local imgw, imgh = img:getDimensions()


local imageCache = {}

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
        return imageCache[path].img, imageCache[path].imgw, imageCache[path].imgh
    else
        return nil, nil, nil
    end
end

local settings = {wrapX='mirroredrepeat', wrapY='mirroredrepeat'}
getLoveImage('textures/pat/type0.png', settings)
getLoveImage('textures/pat/type1.png', settings)
getLoveImage('textures/pat/type2.png', settings)
getLoveImage('textures/pat/type3.png', settings)
getLoveImage('textures/pat/type4.png', settings)
getLoveImage('textures/pat/type5.png', settings)
getLoveImage('textures/pat/type6.png', settings)
getLoveImage('textures/pat/type7.png', settings)
getLoveImage('textures/pat/type8.png', settings)

local shrinkFactor = 1

--local image = nil

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end
lib.getShrinkFactor = function()
    return shrinkFactor
end

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





function lib.hexToColor(hex)
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



lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX,texScaleY,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patch1, patch2)
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


        if (patch1 and patch1.img) then
            love.graphics.setColorMask(true, true, true, false)
            local r, g, b, a = lib.hexToColor(patch1.tint)
            love.graphics.setColor(r, g, b, a)
            local image = patch1.img
            local imgw, imgh = image:getDimensions()
            local xOffset = (patch1.tx or 0) * (imgw) * shrinkFactor
            local yOffset = (patch1.ty or 0) * (imgh) * shrinkFactor
            love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, (patch1.r or 0) * ((math.pi * 2) / 16),
                (patch1.sx or 1) * shrinkFactor,
                (patch1.sy or 1) * shrinkFactor,
                imgw / 2, imgh / 2)
            love.graphics.setColorMask(true, true, true, true)
        end

        if (patch2 and patch2.img) then
            love.graphics.setColorMask(true, true, true, false)
            local r, g, b, a = lib.hexToColor(patch2.tint)
            love.graphics.setColor(r, g, b, a)
            local image = patch2.img
            local imgw, imgh = image:getDimensions()
            local xOffset = (patch2.tx or 0) * (imgw) * shrinkFactor
            local yOffset = (patch2.ty or 0) * (imgh) * shrinkFactor
            love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, (patch2.r or 0) * ((math.pi * 2) / 16),
                (patch2.sx or 1) * shrinkFactor,
                (patch2.sy or 1) * shrinkFactor,
                imgw / 2, imgh / 2)
            love.graphics.setColorMask(true, true, true, true)
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
        --  print(flipx, flipy, lw, lh, sx, sy, ox, oy)
        --love.graphics.setColor(0, 0, 0)
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
        -- love.graphics.rectangle('fill', 0, 0, 1000, 1000)
        --print(0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
        love.graphics.setCanvas()       --- <<<<<
        local imageData = otherCanvas:newImageData()
        love.graphics.setColor(0, 0, 0) --- huh?!
        --local imageData = canvas:newImageData()



        canvas:release()
        otherCanvas:release()
        -- print(imageData)
        return imageData
    end
    -- return lineart:getData()
    -- return nil -- love.image.newImageData(mask)
end



function lib.makeCombinedImages()
    local bodies = state.physicsWorld:getBodies()
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for i = 1, #fixtures do
            local ud = fixtures[i]:getUserData()
            if ud and ud.extra and ud.extra.OMP and ud.extra.dirty then
                 logger:info(inspect(ud.extra))
                ud.extra.dirty = false





                function makePatch(name)
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
                            outlineImage,                      -- line art
                            maskImage,                   -- mask
                                { mr, mg, mb },            -- color1
                                ma * 5,                    -- alpha1
                                patternImage or  tex1,                      -- texture2 (fill texture)
                                { pr, pg, pb },            -- color2
                                pa * 5,                    -- alpha2
                                ud.extra[name].pr or 0, -- texRot
                                ud.extra[name].psx or 1,    -- texScale
                                ud.extra[name].psy or 1,    -- texScale
                                ud.extra[name].ptx or 0,
                                ud.extra[name].pty or 0,
                                { olr, olg, olb },      -- lineColor
                                ola * 5,                -- lineAlpha
                                ud.extra[name].fx or 1, -- flipx (normal)
                                ud.extra[name].fy or 1 -- flipy (normal)
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
                end

                local patch1 = makePatch('patch1')
                local patch2 = makePatch('patch2')



                local outlineImage = getLoveImage('textures/' .. ud.extra.main.bgURL)
                local olr, olg, olb, ola = lib.hexToColor(ud.extra.main.bgHex)
                local maskImage = getLoveImage('textures/' .. ud.extra.main.fgURL)
                local mr, mg, mb, ma = lib.hexToColor(ud.extra.main.fgHex)
                local patternImage = getLoveImage('textures/pat/' .. ud.extra.main.pURL)
                local pr, pg, pb, pa = lib.hexToColor(ud.extra.main.pHex)

                if outlineImage or line then
                local imgData = lib.makeTexturedCanvas(
                   outlineImage or  line,                      -- line art
                   maskImage or maskTex,                   -- mask

                    { mr, mg, mb },            -- color1
                    ma * 5,                    -- alpha1
                   patternImage or  tex1,                      -- texture2 (fill texture)
                    { pr, pg, pb },            -- color2
                    pa * 5,                    -- alpha2
                    ud.extra.main.pr or 0, -- texRot
                    ud.extra.main.psx or 1,    -- texScale
                    ud.extra.main.psy or 1,    -- texScale
                    ud.extra.main.ptx or 0,
                    ud.extra.main.pty or 0,
                    { olr, olg, olb },      -- lineColor
                    ola * 5,                -- lineAlpha
                    ud.extra.main.fx or 1, -- flipx (normal)
                    ud.extra.main.fy or 1, -- flipy (normal)
                    patch1 , patch2                 -- renderPatch (set to truthy to enable extra patch rendering)
                )
                image = love.graphics.newImage(imgData)
                ud.extra.ompImage = image
                end
                fixtures[i]:setUserData(ud)
            end
        end
    end
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

local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, vertices)
     local p = {}
     for i = 1, #vertices do
         p[i] = vertices[i] * growFactor
     end
    -- local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
    local uvs = makeSquishableUVsFromPoints(p)


    -- todo maybe parametrize this point so you can make the midle of the fan not be the exact middle of the polygon.
    local cx, cy, _, _ = mathutils.getCenterOfPoints(vertices)
    table.insert(uvs,1,{cx,cy, .5,.5}) -- I will just alwasy put a center vertex as the first one

    local _mesh =  love.graphics.newMesh(uvs) --or love.graphics.newMesh(uvs, 'fan')
    local img = img
    _mesh:setTexture(img)

    love.graphics.draw(_mesh, x, y, r, 1, 1)
end


function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()
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
            if (ud and ud.extra and ud.extra.type == 'texfixture') then
                local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                --print(inspect(ud.extra))
                table.insert(drawables,
                    {
                        z = composedZ,
                        texfixture = fixtures[i],
                        extra = ud.extra,
                        body = body,
                        thing = body:getUserData().thing
                    })
            end
        end
    end
    --print(#drawables)
    table.sort(drawables, function(a, b)
        return a.z < b.z
    end)




    -- todo: these3 function look very much alike, we wnat to combine them all in otne,
    -- another issue here is that i dont really understand how to set the ox and oy correctly, (for the combined Image)
    -- and there is an issue with the center of the 'fan' mesh, it shouldnt always be 0,0 you can see this when you position the texfxture with the
    -- onscreen 'd' button quite a distnace out of the actual physics body center.
    --
    local function drawImageLayerSquish(url, hex, extra, texfixture )
       -- print('jo!')
        local img, imgw, imgh = getLoveImage('textures/' .. url)
        local vertices =  extra.vertices or { texfixture:getShape():getPoints() }

        if (vertices and img) then
           local body = texfixture:getBody()
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = ww / imgw
            local sy = hh / imgh
            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            local r, g, b, a = lib.hexToColor(hex)
            love.graphics.setColor(r, g, b, a)
          --  drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
             drawSquishableHairOver(img, body:getX() , body:getY() , body:getAngle(), sx, sy, 1, vertices)
        end
    end
    local function drawImageLayerVanilla(url, hex, extra, texfixture )
        local img, imgw, imgh = getLoveImage('textures/' .. url)
        local vertices =  extra.vertices or { texfixture:getShape():getPoints() }

        if (vertices and img) then
             local body = texfixture:getBody()
           -- local body = texfixture:getBody()
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = ww / imgw
            local sy = hh / imgh
            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            local r, g, b, a = lib.hexToColor(hex)
            love.graphics.setColor(r, g, b, a)

            love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                body:getAngle(), sx * 1, sy * 1,
                (imgw) / 2, (imgh) / 2)
            --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
        end
    end
    local function drawCombinedImageVanilla(ompImage, extra, texfixture, thing)
         local vertices = extra.vertices or { texfixture:getShape():getPoints() }
         local img = ompImage
         local imgw, imgh = ompImage:getDimensions()

         if vertices and img then
             local body = texfixture:getBody()
             local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
             local sx = ww / imgw
             local sy = hh / imgh
             local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
             --local r, g, b, a = hexToColor(thing.textures.bgHex)

             -- this routine is alos good, but it doenst take in affect the squishyness. you cannot deform the rectangle
             -- love.graphics.setColor(1, 1, 1, 1)
             -- love.graphics.draw(img, body:getX() + rx, body:getY() + ry, body:getAngle(),
             --     sx * 1 * thing.mirrorX,
             --     sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)



             -- this routine works as is, you just need to center more often, the 0,0 at the beginning is not always corretc though..
                local r, g, b, a = lib.hexToColor(extra.main.tint or 'ffffffff')
             love.graphics.setColor(r,g,b,a)
              --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
                drawSquishableHairOver(img, body:getX() , body:getY() , body:getAngle(), sx, sy, 1, vertices)
         end
    end


    --for _, body in ipairs(bodies) do
    for i = 1, #drawables do
        local body = drawables[i].body
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture

        if texfixture then
            local extra = drawables[i].extra
            if not extra.OMP then -- this is the BG and FG routine
                if extra.main and extra.main.bgURL then
                drawImageLayerSquish(extra.main.bgURL, extra.main.bgHex, extra,  texfixture )
                --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                end
                if extra.main and extra.main.fgURL then
                drawImageLayerSquish(extra.main.fgURL, extra.main.fgHex, extra,  texfixture )
                --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                end
            end

            if extra.OMP then
                if (texfixture and extra.ompImage) then
                    drawCombinedImageVanilla(extra.ompImage, extra, texfixture, thing)
                end
                --end
            end
        end
    end
    --love.graphics.setDepthMode()
end

return lib
