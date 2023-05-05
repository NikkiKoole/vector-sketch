local function makeDynamicCanvas(imageData, mymesh)
    local w, h = imageData:getDimensions()
    local w2 = w / 2
    local h2 = h / 2

    local result = {}
    result.color = { 1, 1, 1 }
    result.name = 'generated'
    result.points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } }
    result.texture = {
        filter = "linear",
        canvas = mymesh,
        wrap = "repeat",
    }

    return result
end

local function createRectangle(x, y, w, h, r, g, b)
    local w2 = w / 2
    local h2 = h / 2

    local result = {}
    result.folder = true
    result.transforms = {
        l = { x, y, 0, 1, 1, 0, 0 }
    }
    result.children = { {

        name = 'rectangle',
        points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } },
        color = { r or 1, g or 0.91, b or 0.15, 1 }
    } }
    return result
end

local numbers = require 'lib.numbers'
local cam = require 'lib.camera'
local bbox = require 'lib.bbox'

function drawBBoxDebug()
    if true then
        love.graphics.push() -- stores the default coordinate system
        local w, h = love.graphics.getDimensions()
        love.graphics.translate(w / 2, h / 2)
        love.graphics.scale(.25) -- zoom the camera
        if love.mouse.isDown(1) then
            local mx, my = love.mouse:getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            for j = 1, #root.children do
                local guy = root.children[j]

                for i = 1, #guy.children do
                    local item = guy.children[i]
                    local b = bbox.getBBoxRecursive(item)


                    if b then
                        local mx1, my1 = item.transforms._g:inverseTransformPoint(wx, wy)
                        local tlx2, tly2 = item.transforms._g:inverseTransformPoint(b[1], b[2])
                        local brx2, bry2 = item.transforms._g:inverseTransformPoint(b[3], b[4])

                        love.graphics.print(item.name, mx1, my1)
                        love.graphics.circle('line', mx1, my1, 10)

                        love.graphics.print(item.name, tlx2, tly2)
                        love.graphics.rectangle('line', tlx2, tly2, brx2 - tlx2, bry2 - tly2)

                        if item.children then
                            if (item.children[1].name == 'generated') then
                                -- todo this part is still not correct?
                                local tlx, tly, brx, bry = bbox.getPointsBBox(item.children[1].points)

                                love.graphics.setColor(1, 0, 0, 0.5)
                                love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
                                love.graphics.setColor(0, 0, 0)
                                -- how to map that location ino the texture dimensions ?
                                local imgW, imgH = item.children[1].texture.imageData:getDimensions()
                                local xx = numbers.mapInto(mx1, tlx, brx, 0, imgW)
                                local yy = numbers.mapInto(my1, tly, bry, 0, imgH)
                                if (xx >= 0 and xx < imgW and yy >= 0 and yy < imgH) then
                                    local r, g, b, a = item.children[1].texture.imageData:getPixel(xx, yy)
                                    if (a > 0) then
                                        love.graphics.setColor(1, 0, 1, 1)
                                        love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
                                        love.graphics.setColor(0, 0, 0)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        love.graphics.pop() -- stores the default coordinate system
    end
end



local function drawCirclesAroundCenterCircle(cx, cy, label, buttonRadius, r, smallButtonRadius)
    love.graphics.circle("line", cx, cy, buttonRadius)
    love.graphics.print(label, cx, cy)
 
    local other = { "hair", "headshape", "eyes", "ears", "nose", "mouth", "chin" }
    local angleStep = (180 / (#other - 1))
    local angle = -90
    for i = 1, #other do
       local px = cx + r * math.cos(angle * math.pi / 180)
       local py = cy + r * math.sin(angle * math.pi / 180)
       angle = angle + angleStep
       love.graphics.circle("line", px, py, smallButtonRadius)
    end
 end
 
 --local res = { clicked = false }
 
 local function bigButtonWithSmallAroundIt(x, y, textureOrColors)
    prof.push("big-bitton-small-around")
    local biggestRadius = 70
    local bigRadius = 40
    local radius = 20
    local diam = radius * 2
    local rad = -math.pi / 2
    local number = 4
    local step = (math.pi / 1.5) / (number - 1)
 
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("line", x, y, bigRadius)
 
    local first, second, third, fourth, fifth = nil, nil, nil, nil, nil
 
    if (type(textureOrColors[1]) == "table") then
       love.graphics.setColor(textureOrColors[1])
    else
       local img = mesh.getImage(textureOrColors[1])
       local scale, xOffset, yOffset = getScaleAndOffsetsForImage(img, diam * 2, diam * 2)
 
       love.graphics.draw(img, x + xOffset, y + yOffset, 0, scale, scale)
    end
    first = ui.getUICircle(x, y, bigRadius)
 
    for i = 2, #textureOrColors do
       local new_x = x + math.cos(rad) * biggestRadius
       local new_y = y + math.sin(rad) * biggestRadius
       love.graphics.setColor(0, 0, 0)
       love.graphics.circle("line", new_x, new_y, radius)
 
       if (type(textureOrColors[i]) == "table") then
          love.graphics.setColor(textureOrColors[i])
          love.graphics.circle("fill", new_x, new_y, radius - 2)
       else
          scale, xOffset, yOffset = getScaleAndOffsetsForImage(blup2, 40, 40)
          prof.push("render-masked-texture")
          canvas.renderMaskedTexture(blup2, textureOrColors[i], new_x + xOffset, new_y + yOffset, scale, scale)
          prof.pop("render-masked-texture")
       end
 
       local b = ui.getUICircle(new_x, new_y, 30)
       if (i == 2) then
          second = b
       end
       if (i == 3) then
          third = b
       end
       if (i == 4) then
          fourth = b
       end
       if (i == 5) then
          fifth = b
       end
       rad = rad + step
    end
    prof.pop("big-bitton-small-around")
    return first, second, third, fourth, fifth
 end
 
 local function buttonHelper(button, bodyPart, param, maxAmount, func, firstParam)
    if button then
       values[bodyPart][param] = values[bodyPart][param] + 1
       if values[bodyPart][param] > maxAmount then
          values[bodyPart][param] = 1
       end
       func(firstParam, values)
    end
 end
 
 local function bigButtonHelper(x, y, param, imgArray, changeFunc, redoFunc, firstParam)
    shapeButton, BGButton, FGTexButton, FGButton, LinePalButton =
        bigButtonWithSmallAroundIt(
            x,
            y,
            {
                imgArray[values[param].shape],
                palettes[values[param].bgPal],
                textures[values[param].fgTex],
                palettes[values[param].fgPal],
                palettes[values[param].linePal]
            }
        )
 
    -- todo maybe parametrize palettes and textures?
    buttonHelper(shapeButton, param, "shape", #imgArray, changeFunc, firstParam)
    buttonHelper(BGButton, param, "bgPal", #palettes, redoFunc, firstParam)
    buttonHelper(FGTexButton, param, "fgTex", #textures, redoFunc, firstParam)
    buttonHelper(FGButton, param, "fgPal", #palettes, redoFunc, firstParam)
    buttonHelper(LinePalButton, param, "linePal", #palettes, redoFunc, firstParam)
 end
 