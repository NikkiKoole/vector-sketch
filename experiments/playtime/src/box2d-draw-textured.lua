local lib = {}

local mathutils = require 'src.math-utils'

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


--local img = love.graphics.newImage('textures/leg1.png')
local tex1 = love.graphics.newImage('textures/pat/type2t.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
--local imgw, imgh = img:getDimensions()
local imageCache = {}

function getLoveImage(path)
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            --print("Warning: File not found - " .. path)
            return nil, nil, nil
        end
        local img = love.graphics.newImage(path)
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

local shrinkFactor = 1

local image = nil

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end
lib.getShrinkFactor = function()
    return shrinkFactor
end

local function getDrawParams(flipx, flipy, imgw, imgh)
    local sx = flipx
    local sy = flipy

    local ox = flipx == -1 and imgw or 0
    local oy = flipy == -1 and imgh or 0

    return sx, sy, ox, oy
end

lib.makeTexturedCanvas = function(lineart, mask, texture1, color1, alpha1, texture2, color2, alpha2, texRot, texScale,
                                  lineColor, lineAlpha,
                                  flipx, flipy, renderPatch)
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


            transform:rotate((texRot * math.pi) / 8)
            transform:scale(texScale, texScale)

            local m1, m2, _, _, m5, m6 = transform:getMatrix()
            local dx = 0 --love.math.random() * .001
            local dy = love.math.random() * .01
            maskShader:send('fill', texture2)
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


        -- I want to know If we do this or not..
        if (false and renderPatch) then
            love.graphics.setColorMask(true, true, true, false)
            for i = 1, #renderPatch do
                local p = renderPatch[i]

                -- love.graphics.setColor(1, 1, 1, 1)
                -- local image = love.graphics.newImage(p.imageData)
                -- local imgw, imgh = image:getDimensions();
                -- local xOffset = p.tx * (imgw / 6) * shrinkFactor
                -- local yOffset = p.ty * (imgh / 6) * shrinkFactor
                -- love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, p.r * ((math.pi * 2) / 16),
                --     p.sx * shrinkFactor,
                --     p.sy * shrinkFactor,
                --     imgw / 2, imgh / 2)
                --print(lw, lh)
                if true then
                    local img = love.graphics.newImage('textures/eye4.png')
                    --local img = love.graphics.newImage('assets/test1.png')
                    --love.graphics.setBlendMode('subtract')

                    for i = 1, 13 do
                        love.graphics.setColor(love.math.random(), love.math.random(), love.math.random(), 0.4)
                        local s = 3 + love.math.random() * 3
                        love.graphics.draw(img, lw * love.math.random(), lh * love.math.random(),
                            love.math.random() * math.pi * 2,
                            1 / s, 1 / s)
                    end

                    --love.graphics.setBlendMode("alpha")
                end
            end
            love.graphics.setColorMask(true, true, true, true)
        end


        love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha / 5)
        local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
        --  print(flipx, flipy, lw, lh, sx, sy, ox, oy)
        love.graphics.setColor(0, 0, 0)
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
        return imageData
    end
    -- return lineart:getData()
    -- return nil -- love.image.newImageData(mask)
end

function lib.makePatternTexture()
    if not image then
        -- You can adjust the parameters as desired.
        local imgData = lib.makeTexturedCanvas(
            line,        -- line art
            maskTex,     -- mask
            tex1,        -- texture1 (unused in this version)
            { 1, 0, 1 }, -- color1
            5,           -- alpha1
            tex1,        -- texture2 (fill texture)
            { 0, 0, 1 }, -- color2
            5,           -- alpha2
            0,           -- texRot
            .2,          -- texScale
            { 0, 0, 0 }, -- lineColor
            1,           -- lineAlpha
            1,           -- flipx (normal)
            1,           -- flipy (normal)
            { 'jo!' }    -- renderPatch (set to truthy to enable extra patch rendering)
        )
        image = love.graphics.newImage(imgData)
    end
    return image
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
                table.insert(drawables, { z = composedZ, texfixture = fixtures[i], extra = ud.extra })
            end
        end
    end
    --print(#drawables)
    table.sort(drawables, function(a, b)
        return a.z < b.z
    end)

    --for _, body in ipairs(bodies) do
    for i = 1, #drawables do
        local body = drawables[i].body
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture

        -- if thing and body then
        --     local vertices = thing.vertices
        --     if (image) then
        --         local img = image
        --         local imgw, imgh = image:getDimensions()
        --         if vertices then
        --             local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
        --             local sx = ww / imgw
        --             local sy = hh / imgh
        --             local r, g, b, a = lib.hexToColor(thing.textures.bgHex)
        --             love.graphics.setColor(r, g, b, a)
        --             --love.graphics.draw(img, body:getX(), body:getY())
        --             love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
        --                 sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
        --         else
        --             print('NO VERTICES FOUND, kinda hard ', inspect(thing))
        --         end
        --     end

        --     if thing.textures and thing.textures.bgEnabled then
        --         local url = thing.textures.bgURL
        --         local img, imgw, imgh = getLoveImage('textures/' .. url)
        --         --imgw = img:getWidth()
        --         --imgh = img:getHeight()

        --         if (img) then
        --             if vertices then
        --                 local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
        --                 local sx = ww / imgw
        --                 local sy = hh / imgh
        --                 local r, g, b, a = lib.hexToColor(thing.textures.bgHex)
        --                 love.graphics.setColor(r, g, b, a)
        --                 --love.graphics.draw(img, body:getX(), body:getY())
        --                 love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
        --                     sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
        --             else
        --                 print('NO VERTICES FOUND, kinda hard ', inspect(thing))
        --             end
        --         end
        --     end

        --     if thing.textures and thing.textures.fgEnabled then
        --         local url = thing.textures.fgURL
        --         local img, imgw, imgh = getLoveImage('textures/' .. url)

        --         if (img) then
        --             if vertices then
        --                 local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
        --                 local sx = ww / imgw
        --                 local sy = hh / imgh
        --                 local r, g, b, a = lib.hexToColor(thing.textures.fgHex)
        --                 love.graphics.setColor(r, g, b, a)
        --                 love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
        --                     sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
        --             else
        --                 print('NO VERTICES FOUND, kinda hard ', inspect(thing))
        --             end
        --         end
        --     end
        -- end

        if texfixture then
            local extra = drawables[i].extra
            local url = extra.bgURL
            local img, imgw, imgh = getLoveImage('textures/' .. url)
            local body = texfixture:getBody()

            local vertices = { texfixture:getShape():getPoints() }

            if (img) then
                -- -- the Mesh DrawMode "fan" works well for 4-vertex Meshes.
                -- mesh = love.graphics.newMesh(vert2, "fan")
                -- mesh:setTexture(img)

                if vertices then
                    local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                    local sx = ww / imgw
                    local sy = hh / imgh
                    local r, g, b, a = lib.hexToColor(extra.bgHex)
                    local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())

                    love.graphics.setColor(r, g, b, a)
                    love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                        body:getAngle(), sx * 1, sy * 1,
                        (imgw) / 2, (imgh) / 2)

                    -- love.graphics.draw(mesh, body:getX() + rx, body:getY() + ry, body:getAngle(), sx * 1, sy * 1,
                    --     (imgw) / 2, (imgh) / 2)
                else
                    print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                end
            end

            local url = extra.fgURL
            local img, imgw, imgh = getLoveImage('textures/' .. url)
            local body = texfixture:getBody()

            local vertices = { texfixture:getShape():getPoints() }

            if (img) then
                -- -- the Mesh DrawMode "fan" works well for 4-vertex Meshes.
                -- mesh = love.graphics.newMesh(vert2, "fan")
                -- mesh:setTexture(img)

                if vertices then
                    local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                    local sx = ww / imgw
                    local sy = hh / imgh
                    local r, g, b, a = lib.hexToColor(extra.fgHex)
                    local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())

                    love.graphics.setColor(r, g, b, a)
                    love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                        body:getAngle(), sx * 1, sy * 1,
                        (imgw) / 2, (imgh) / 2)

                    -- love.graphics.draw(mesh, body:getX() + rx, body:getY() + ry, body:getAngle(), sx * 1, sy * 1,
                    --     (imgw) / 2, (imgh) / 2)
                else
                    print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                end
            end
        end
    end
    --love.graphics.setDepthMode()
end

return lib
