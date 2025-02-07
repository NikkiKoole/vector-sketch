local lib = {}

local mathutils = require 'src.math-utils'

--local img = love.graphics.newImage('textures/leg1.png')
local tex1 = love.graphics.newImage('textures/pat/type3_.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
--local imgw, imgh = img:getDimensions()
local imageCache = {}

function getLoveImage(path)
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            print("Warning: File not found - " .. path)
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

function hexToColor(hex)
    if type(hex) ~= "string" then
        print("Warning: hexToColor expected a string but got " .. type(hex))
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
        print("Warning: invalid hex string length (" .. #hex .. ") for value: " .. hex)
        return 1, 1, 1, 1
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8), 16)

    -- If any conversion failed, return white.
    if not (r and g and b and a) then
        print("Warning: invalid hex color value: " .. hex)
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

local shrinkFactor = 2

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
    return image
end

function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()
    local drawables = {}

    for _, body in ipairs(bodies) do
        local ud = body:getUserData()
        if (ud and ud.thing) then
            local composedZ = ((ud.thing.zGroupOffset or 0) * 1000) + ud.thing.zOffset
            table.insert(drawables, { z = ud.thing.zOffset, b = body })
        end
    end
    --print(#drawables)
    table.sort(drawables, function(a, b)
        return a.z < b.z
    end)

    --for _, body in ipairs(bodies) do
    for i = 1, #drawables do
        local body = drawables[i].b
        local ud = body:getUserData()
        if (ud and ud.thing) then
            local thing = ud.thing
            local vertices = thing.vertices


            if (image) then
                local img = image
                local imgw, imgh = image:getDimensions()
                if vertices then
                    local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                    local sx = ww / imgw
                    local sy = hh / imgh
                    local r, g, b, a = hexToColor(thing.textures.bgHex)
                    love.graphics.setColor(r, g, b, a)
                    --love.graphics.draw(img, body:getX(), body:getY())
                    love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
                        sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
                else
                    print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                end
            end


            if thing.textures and thing.textures.bgEnabled then
                local url = thing.textures.bgURL
                local img, imgw, imgh = getLoveImage('textures/' .. url)
                --imgw = img:getWidth()
                --imgh = img:getHeight()

                if (img) then
                    if vertices then
                        local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                        local sx = ww / imgw
                        local sy = hh / imgh
                        local r, g, b, a = hexToColor(thing.textures.bgHex)
                        love.graphics.setColor(r, g, b, a)
                        --love.graphics.draw(img, body:getX(), body:getY())
                        love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
                            sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
                    else
                        print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                    end
                end
            end

            if thing.textures and thing.textures.fgEnabled then
                local url = thing.textures.fgURL
                local img, imgw, imgh = getLoveImage('textures/' .. url)

                if (img) then
                    if vertices then
                        local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                        local sx = ww / imgw
                        local sy = hh / imgh
                        local r, g, b, a = hexToColor(thing.textures.fgHex)
                        love.graphics.setColor(r, g, b, a)
                        love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1 * thing.mirrorX,
                            sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
                    else
                        print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                    end
                end
            end
        end
    end
    --love.graphics.setDepthMode()
end

return lib
