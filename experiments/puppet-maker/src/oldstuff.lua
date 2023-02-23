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
