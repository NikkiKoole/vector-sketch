local lib = {}

local mathutils = require 'src.math-utils'

--local img = love.graphics.newImage('textures/leg1.png')
--local imgw, imgh = img:getDimensions()
local imageCache = {}
function getLoveImage2(path)
    if not imageCache[path] then
        -- Load the image and store it in the cache
        local img = love.graphics.newImage(path)
        if (img) then
            local imgw, imgh = img:getDimensions()
            imageCache[path] = { img = img, imgw = imgw, imgh = imgh }
        end
    end
    return imageCache[path].img, imageCache[path].imgw, imageCache[path].imgh
end

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

function hexToColor2(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then hex = hex .. "FF" end -- Append alpha if missing
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local a = tonumber(hex:sub(7, 8), 16) / 255
    return r, g, b, a
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

function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local ud = body:getUserData()
        if (ud and ud.thing) then
            local thing = ud.thing
            local vertices = thing.vertices
            if thing.textures and thing.textures.bgEnabled then
                local url = thing.textures.bgURL
                local img, imgw, imgh = getLoveImage('textures/' .. url)

                if (img) then
                    if vertices then
                        local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                        local sx = ww / imgw
                        local sy = hh / imgh
                        local r, g, b, a = hexToColor(thing.textures.bgHex)
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
end

return lib
