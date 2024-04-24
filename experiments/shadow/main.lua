-- Function to apply a blur filter to an ImageData
function applyBlur(imageData, radius)
    local blurredImageData = imageData:clone()

    for x = 0, blurredImageData:getWidth() - 1 do
        for y = 0, blurredImageData:getHeight() - 1 do
            local totalR, totalG, totalB, totalA = 0, 0, 0, 0
            local count = 0

            -- Apply the blur filter within the specified radius
            for dx = -radius, radius do
                for dy = -radius, radius do
                    local nx, ny = x + dx, y + dy
                    if nx >= 0 and nx < blurredImageData:getWidth() and ny >= 0 and ny < blurredImageData:getHeight() then
                        local r, g, b, a = imageData:getPixel(nx, ny)
                        totalR = totalR + r
                        totalG = totalG + g
                        totalB = totalB + b
                        totalA = totalA + a
                        count = count + 1
                    end
                end
            end

            -- Average the colors within the radius
            totalR = totalR / count
            totalG = totalG / count
            totalB = totalB / count
            totalA = totalA / count

            -- Set the pixel color in the blurred image
            blurredImageData:setPixel(x, y, totalR, totalG, totalB, totalA)
        end
    end

    return blurredImageData
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function getBBoxOfPolygon(poly)
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    for i = 1, #poly, 2 do
        if minX > poly[i] then minX = poly[i] end
        if maxX < poly[i] then maxX = poly[i] end
        if minY > poly[i + 1] then minY = poly[i + 1] end
        if maxY < poly[i + 1] then maxY = poly[i + 1] end
    end

    local width = maxX - minX
    local height = maxY - minY
    return minX, minY, maxX, maxY
end

-- Example usage
rotationAngle = 0

local function rnd(v)
    return love.math.random() * v
end

function love.load()
    elems = {}

    scale = .2
    local w, h = love.graphics.getDimensions()

    local shapes = {
        triangle = { 100, 100, 200, 100, 150, 200 },
    }
    local shadows = {
        triangle = makeSingleShadow(shapes.triangle)
    }
    for i = 1, 100 do
        elems[i] = {
            shape = shapes.triangle,
            shadow = shadows.triangle,
            x = rnd(w) - 500,
            y = rnd(h) - 500,
            r = rnd(1),
            g = rnd(1),
            b = rnd(1),
            angle = rnd(math.pi * 2),
            velocity = rnd(0.2) - 0.1
        }
    end
end

function makeSingleShadow(thing)
    local minX, minY, maxX, maxY = getBBoxOfPolygon(thing)
    local centerX = minX + (maxX - minX) / 2
    local centerY = minY + (maxY - minY) / 2
    local width = maxX - minX
    local height = maxY - minY



    local margin = width / 5
    local canvasWidth, canvasHeight = (width + margin * 2) * scale, (height + margin * 2) * scale
    local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight, { dpiscale = 1 })
    --local canvas = love.graphics.newCanvas(width * scale, height * scale)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1)
    -- Scale and draw the polygon
    love.graphics.push()
    --love.graphics.translate(-minX * scale, -minY * scale)
    love.graphics.translate((-minX + margin) * scale, (-minY + margin) * scale)
    love.graphics.scale(scale)
    love.graphics.polygon("fill", thing)
    love.graphics.pop()
    love.graphics.setCanvas()

    -- Get the ImageData from the canvas
    local imageData = canvas:newImageData()

    -- Apply blur filter to the ImageData
    local blurredImageData = applyBlur(imageData, 2)

    -- Convert blurred ImageData back to Love2D image
    local blurredImage = love.graphics.newImage(blurredImageData)

    return blurredImage
end

function drawPolyAndShadow(it)
    local minX, minY, maxX, maxY = getBBoxOfPolygon(it.shape)
    local centerX = minX + (maxX - minX) / 2
    local centerY = minY + (maxY - minY) / 2



    -- Get the ImageData from the canvas
    -- local imageData = canvas:newImageData()

    -- Apply blur filter to the ImageData
    -- local blurredImageData = applyBlur(imageData, 2)

    -- Convert blurred ImageData back to Love2D image

    local blurredImage = it.shadow

    love.graphics.setColor(0, 0, 0, .5)
    love.graphics.draw(blurredImage, centerX + it.x, centerY + it.y, it.angle, 1 / scale, 1 / scale,
        blurredImage:getWidth() / 2,
        blurredImage:getHeight() / 2)

    -- Display the original polygon
    love.graphics.setColor(it.r, it.g, it.b, 1)
    love.graphics.push()

    love.graphics.translate(centerX + it.x, centerY + it.y) -- Translate to the center
    love.graphics.rotate(it.angle)                          -- Apply rotation
    love.graphics.translate(-centerX, -centerY)             -- Translate to the center

    love.graphics.polygon("fill", it.shape)
    love.graphics.pop()
end

function love.draw()
    love.graphics.clear(1, 1, 1)
    -- Create a polygon
    for i = 1, #elems do
        drawPolyAndShadow(elems[i])
        elems[i].angle = elems[i].angle + elems[i].velocity
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)

    -- rotationAngle = rotationAngle + 0.001
end
