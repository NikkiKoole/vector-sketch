--flowerColors = pastelColors
local numbers       = require 'lib.numbers'

local cam           = require('lib.cameraBase').getInstance()
local texturedBox2d = require 'lib.texturedBox2d'


local brownColor          = { hex2rgb('5b3e05', 1) }
local sunColor1b          = { hex2rgb('ffc800', .8) }
local sunColor1c          = { hex2rgb('ffc800', .05) }

local darkGrassColor      = { hex2rgb('2a5b3e') }
local darkGrassColorTrans = { hex2rgb('2a5b3e', 0.5) }
local lightGrassColor     = { hex2rgb('86a542') }


local pastelColors = {
    { hex2rgb('FFB3BA') },
    { hex2rgb('FFDFBA') },
    { hex2rgb('FFFFBA') },
    { hex2rgb('BAFFC9') },
    { hex2rgb('BAE1FF') },
    { hex2rgb('FFCCE5') },
    { hex2rgb('D4A5A5') },
    { hex2rgb('F0D9FF') },
    { hex2rgb('C4FCEF') },
    { hex2rgb('FFEBB7') },
}

local flowerColors = {
    { hex2rgb('FEDF00') },
    { hex2rgb('FFD700') },
    { hex2rgb('F9A602') },
    { hex2rgb('FFC40C') },

}



local function lerpColor(color1, color2, t)
    local r = numbers.mapInto(t, 0, 1, color1[1], color2[1])
    local g = numbers.mapInto(t, 0, 1, color1[2], color2[2])
    local b = numbers.mapInto(t, 0, 1, color1[3], color2[3])
    return { r, g, b }
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


local function drawLineImage(img, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    local scale = distance / img:getWidth()
    love.graphics.draw(img, x1, y1, angle, scale, 1, 0, img:getHeight() / 2)
end





local function drawRepeatedPatternUsingStencilFunction(stencilFunc, img, color, alpha, repeatScale)
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    love.graphics.stencil(stencilFunc, "replace", 1)
    love.graphics.setStencilTest("greater", 0)


    local pw, ph = img:getDimensions()
    local screenW = cambrx - camtlx
    local screenH = cambry - camtly
    -- first render....
    local repeats = (screenW / pw) * repeatScale
    local tileOffsetX = (camtlx / screenW) * repeats
    local tileOffsetY = (camtly / screenH) * repeats
    local mesh = love.graphics.newMesh({
        { camtlx, camtly, 0 + tileOffsetX,       0 + tileOffsetY,      1, 1, 1 },
        { cambrx, camtly, repeats + tileOffsetX, 0 + tileOffsetY,      1, 1, 1 },
        { cambrx, cambry, repeats + tileOffsetX, repeats + tileOffsetY },
        { camtlx, cambry, 0 + tileOffsetX,       repeats + tileOffsetY }
    })
    mesh:setTexture(img)

    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.draw(mesh, 0, 0)
    love.graphics.setStencilTest()
end


local function subdivide2D(x1, y1, x2, y2, stepsize)
    local result = {}

    -- Calculate the distance between the two points
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Calculate the angle of the line segment
    local angle = math.atan2(dy, dx)

    -- Calculate the number of steps needed
    local numSteps = distance / stepsize

    -- Calculate the step increments for x and y
    local stepX = dx / numSteps
    local stepY = dy / numSteps

    -- Iterate through the line segment and add the subdivided points to the result
    for i = 0, numSteps do
        local x = x1 + stepX * i
        local y = y1 + stepY * i
        table.insert(result, { x, y })
    end

    return result
end

function textureTheSchansjes()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    love.graphics.setColor(brownColor)

    for i = 1, #schansjes do
        local points = schansjes[i]
        --  print(inspect(points))
        local lx = points[1]
        local ly = points[2]
        local rx = points[#points - 1]
        local ry = points[#points]
        -- print(l, r)
        if (lx > camtlx and lx < cambrx) or (rx > camtlx and rx < cambrx) then
            --print('should render schansje #', i)
            --print(inspect(points))
            local startPoints = subdivide2D(points[1], points[2], points[3], points[4], 80)


            for j = 1, #startPoints do
                drawLineImage(stokdik, startPoints[j][1], startPoints[j][2] - 100, startPoints[j][1],
                    startPoints[j][2] + 200)
            end
            local startPoints = subdivide2D(points[3], points[4], points[5], points[6], 80)


            for j = 1, #startPoints do
                drawLineImage(stokdik, startPoints[j][1], startPoints[j][2] - 100, startPoints[j][1],
                    startPoints[j][2] + 200)
            end
        end
    end
end

function textureTheBike(bike, bikeData)
    local img          = tireImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)


    local img          = tireOverImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.setColor(.2, .1, .1, 0.5)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)




    love.graphics.setColor(0, 0, 0)
    local img          = wheelImages[frontWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.frontWheel.body:getPosition()
    local a            = bike.frontWheel.body:getAngle()
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)

    ----


    local img          = tireImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)


    local img          = tireOverImage
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)
    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.setColor(.2, .1, .1, 0.5)
    love.graphics.draw(img, x, y, a, sx, sy, dimsH / 2, dimsW / 2)

    love.graphics.setColor(0, 0, 0)
    local img          = wheelImages[backWheelImgIndex]
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, bikeData.radius * 2, bikeData.radius * 2)

    local x, y         = bike.backWheel.body:getPosition()
    local a            = bike.backWheel.body:getAngle()
    love.graphics.draw(img, x, y, a + math.pi, sx, sy, dimsH / 2, dimsW / 2)


    local x1, y1 = bike.backWheel.body:getPosition()




    local shapePoints = { bike.frame.shape:getPoints() }
    --   print(inspect(shapePoints))
    local middlex     = numbers.lerp(shapePoints[1], shapePoints[9], 0.5)
    local topy        = shapePoints[2] - (bikeData.radius * 0.2)
    local bottomy     = shapePoints[4]
    local x2, y2      = bike.frame.body:getWorldPoint(middlex, topy)
    drawLineImage(stok1R, x1, y1, x2, y2)
    local x3, y3 = bike.frame.body:getWorldPoint(middlex, bottomy)
    drawLineImage(stok1R, x1, y1, x3, y3)



    local xvw, yvw           = bike.backWheel.body:getPosition()
    local gx, gy             = bike.frame.body:getLocalPoint(xvw, yvw)
    --bikeData.radius
    -- local x4, y4   = bike.frame.body:getWorldPoint(shapePoints[1],
    --  shapePoints[2])
    local steerSteepOffset   = (bikeData.radius * 0.2)
    local endFrameAboveWheel = gy - (bikeData.radius * 1.2)
    local x4, y4             = bike.frame.body:getWorldPoint(shapePoints[1] - steerSteepOffset, endFrameAboveWheel)
    drawLineImage(stok1R, x2, y2, x4, y4)
    drawLineImage(stok1R, x3, y3, x4, y4)

    -- achter wile vork
    local img          = achtervork
    local dimsW, dimsH = img:getDimensions()


    local shapeTL = { shapePoints[1], shapePoints[2] }
    local shapeBL = { shapePoints[3], shapePoints[4] }
    local shapeBR = { shapePoints[5], shapePoints[6] }
    local sx, sy  = createFittingScale(img, shapeTL[1] - shapeBR[1], shapeBL[2] - shapeTL[2])
    local x, y    = bike.backWheel.body:getPosition() --bike.frame.body:getWorldPoint(shapeTL[1], shapeTL[2])
    local a       = bike.frame.body:getAngle()

    --   love.graphics.draw(img, x, y, a, sx, sy, 40, 200)

    if false then
        local img          = voorvork
        local dimsW, dimsH = img:getDimensions()
        local shapePoints  = { bike.frame.shape:getPoints() }
        print(inspect(shapePoints))
        local shapeTR = { shapePoints[9], shapePoints[10] }
        local shapeBR = { shapePoints[7], shapePoints[8] }
        local shapeBL = { shapePoints[5], shapePoints[6] }
        local sx, sy  = createFittingScale(img, shapeTR[1] - shapeBL[1], (shapeBR[2] - shapeTR[2]) * 1.5)
        local x, y    = bike.frontWheel.body:getPosition() --bike.frame.body:getWorldPoint(shapeTL[1], shapeTL[2])
        local a       = bike.frame.body:getAngle()
        love.graphics.draw(img, x, y, a, sx * -1, sy, img:getWidth(), img:getHeight() / 2)
    end
end

local function drawSinglePaardenBloem(x, y, randomNumber, randomNumber2)
    local stengelScaleY = 1.2 - randomNumber * 3
    local h = stengelImage:getHeight() * stengelScaleY
    local x1 = math.sin(love.timer.getTime() * .4) * (h / 7)
    local x2 = 0
    local c = love.math.newBezierCurve({ 0, 0, x1, 0 - h / 2, x2, 0 - h + math.abs(x1) })
    local m = texturedBox2d.createTexturedTriangleStrip(stengelImage)
    local eindX, eindY = c:evaluate(1)
    texturedCurve(c, stengelImage, m, 1, .5)
    love.graphics.setColor(darkGrassColor)

    love.graphics.draw(m, x, y, 0, 1, stengelScaleY, 0, 0)




    --if dayTime == 10 then
    local colorIndex = math.floor(numbers.mapInto(randomNumber2, .2, .8, 1, #flowerColors))
    local daycolors = flowerColors[colorIndex]
    --love.graphics.setColor(colors)
    --else
    local colorIndex = math.floor(numbers.mapInto(randomNumber2, .2, .8, 1, #pastelColors))
    local nightcolors = pastelColors[colorIndex]
    --l--ove.graphics.setColor(colors)
    --end
    local mixedColor = lerpColor(daycolors, nightcolors, dayTimeTransition.t)
    love.graphics.setColor(mixedColor)
    love.graphics.draw(bloemHoofdImage, x + eindX, y + eindY * stengelScaleY, math.sin(love.timer.getTime()),
        1, 1,
        bloemHoofdImage:getWidth() / 2, bloemHoofdImage:getHeight() / 2)

    love.graphics.setColor(darkGrassColor)
    love.graphics.draw(bloemBladImage, x, y, -math.pi / 2 + 0.5, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
    love.graphics.draw(bloemBladImage, x, y, math.pi / 2, 1, 1, bloemBladImage:getWidth() / 2,
        bloemBladImage:getHeight())
end

function drawPaardenBloemen()
    local startX = ground.points[1]
    local startY = ground.points[2]
    local eindX = ground.points[#ground.points - 1]
    local eindY = ground.points[#ground.points]


    for i = 1, #ground.points, 2 do
        local x = ground.points[i]
        local y = ground.points[i + 1]

        local hh = love.math.noise((x) / 1000, .1, .1)
        local hh2 = love.math.noise((x) / 100, .6, .1)

        if (x % 8 == 0) then
            if (hh < .4) then
                love.graphics.setColor(1, 0, 0)
            elseif (hh > .4 and hh < .5) then
                love.graphics.setColor(1, 1, 0)
            else
                drawSinglePaardenBloem(x, y, hh - 0.5, hh2)
            end
        end
    end
end

function drawGrassLeaves(secondParam, yOffset, xOffset, hMultiplier, batch)
    -- the individual grass leaves...
    local startX = ground.points[1]
    local startY = ground.points[2]
    local eindX = ground.points[#ground.points - 1]
    local eindY = ground.points[#ground.points]

    --for i = startX, eindX, 50 do
    --    love.graphics.line(i, startY, i, startY - 100)
    --end


    --  if true then
    -- atlasArray = love.graphics.newArrayImage({ 'floweratlas.png' })

    local count = #quads
    local rand = love.math.random
    local w, h = love.graphics.getDimensions()

    --  for i = 1, testsize do
    --      local a = rand() * math.pi / 4 - (math.pi / 8)
    --      local index = math.ceil(rand() * count)
    --      local ori = origins[index]
    --      batch2:addLayer(1, quads[index], rand() * w, h, a, 1, 1, ori[1], ori[2])
    --  end
    --end


    local ccc = 0
    for i = 1, #ground.points, 2 do
        if i > 1 and i < #ground.points - 1 then
            local x = ground.points[i]
            local y = ground.points[i + 1]
            local x2 = ground.points[i + 2]
            local y2 = ground.points[i + 3]

            for j = 0, stepSize - 1, 75 do
                local yy = lerpYAtX(x + j, stepSize)
                local hh = love.math.noise((x + j) / 1000, secondParam, j * 2) * 200 * hMultiplier
                local indx2 = math.ceil(love.math.noise((x + j) / .1, yOffset * 0.01, hMultiplier) * count)

                local ori = origins[indx2]
                local angle = math.sin(hh) / 10
                angle = angle + math.sin(love.timer.getTime()) / 10

                batch:addLayer(1, quads[indx2], x + j + xOffset, yy + yOffset, angle, 2, 2 * hh / 200, ori[1], ori[2])
                ccc = ccc + 1
            end
        end
    end
    -- print(ccc)
end

local function drawSunRays(x, y, radius)
    love.graphics.setColor(sunColor1b)
    love.graphics.setBlendMode('alpha')
    local sy = radius / 70
    --print(sy)
    for i = 1, 20 do
        local index = 1 --math.ceil(love.math.random() * #quads)
        love.graphics.draw(atlasImg, quads[index], x, y, (love.timer.getTime() / 20) + i * (math.pi * 2) / 20, sy, sy,
            origins[index][1],
            origins[index][2])
    end
end

local function rndOffset(offset)
    return math.random() * offset * 2 - offset
end

local function drawSunFace(x, y, radius)
    love.graphics.setColor(1, 1, 1)


    love.graphics.setBlendMode("add")

    local spotSize = radius * 2.7
    local sx, sy   = createFittingScale(sunSpot, spotSize, spotSize)
    love.graphics.setColor(1, 1, 1, 0.025)

    local offset = radius / 5
    love.graphics.draw(sunSpot, x, y + offset, love.timer.getTime(), sx, sy, sunSpot:getWidth() / 2,
        sunSpot:getHeight() / 2)
    love.graphics.setBlendMode("subtract")
    love.graphics.draw(sunSpot, x, y + offset, love.timer.getTime() * 3.3, sx, sy, sunSpot:getWidth() / 2,
        sunSpot:getHeight() / 2)
    love.graphics.setBlendMode("add")
    love.graphics.draw(sunSpot, x, y + offset, love.timer.getTime() / 1.3, sx, sy, sunSpot:getWidth() / 2,
        sunSpot:getHeight() / 2)
    love.graphics.draw(sunSpot, x, y + offset, love.math.random(), sx, sy, sunSpot:getWidth() / 2, sunSpot:getHeight() /
        2)
    local sx, sy = createFittingScale(sunSpot2, spotSize, spotSize)
    local offset = radius / 5
    love.graphics.draw(sunSpot2, x, y + offset, love.timer.getTime(), sx, sy, sunSpot2:getWidth() / 2,
        sunSpot2:getHeight() / 2)

    love.graphics.setBlendMode("subtract")

    love.graphics.setColor(1, 1, 1, 0.03)
    local eyeSize = radius / 2
    local sx, sy  = createFittingScale(sunEye, eyeSize, eyeSize)



    love.graphics.draw(sunEye, rndOffset(5) + x - radius / 2 - eyeSize / 2, rndOffset(5) + y - radius / 2, 0, sx, sy)
    love.graphics.draw(sunEye, rndOffset(5) + x + radius / 2 - eyeSize / 2, rndOffset(5) + y - radius / 2, 0, sx, sy)


    local sx, sy = createFittingScale(sunNose, eyeSize, eyeSize)
    love.graphics.draw(sunNose, rndOffset(5) + x - eyeSize / 2, y + rndOffset(5), 0, sx, sy)

    local sx, sy = createFittingScale(sunTeeth, radius, radius / 3)
    love.graphics.draw(sunTeeth, rndOffset(5) + x - radius / 2, rndOffset(5) + y + radius / 2, 0, sx, sy)

    love.graphics.setBlendMode("alpha")
end


local function drawSun(sunX, sunY)
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)

    local w, h           = love.graphics.getDimensions()
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local img            = sunImage
    local dimsW, dimsH   = img:getDimensions()
    local sunRadius      = math.max(w, h) / 11
    local sx, sy         = createFittingScale(img, sunRadius, sunRadius)
    local x, y           = sunRadius / 2, sunRadius / 2



    local sunScale = 3 * ((math.sin(love.timer.getTime()) + 1) / 2) / 100
    local sunAngle = (((math.sin(love.timer.getTime()) + 1) / 2) / 10) * (math.pi * 2)


    drawSunRays(sunX, sunY, sunRadius * .8)

    love.graphics.setColor(sunColor1b)


    love.graphics.draw(img, sunX, sunY, love.timer.getTime() / 5, 2 * sx + sunScale, 2 * sy + sunScale, dimsH / 2,
        dimsW / 2)
    love.graphics.setColor(sunColor1c)
    love.graphics.setBlendMode("alpha")
    love.graphics.draw(img, sunX, sunY, -love.timer.getTime() / 5, 2 * sx + sunScale, 2 * sy + sunScale, dimsH / 2,
        dimsW / 2)

    drawSunFace(sunX, sunY - sunRadius / 8, sunRadius * .8)
    sunMoonPositions.x = sunX
    sunMoonPositions.y = sunY
    sunMoonPositions.radius = sunRadius * .8
end

local function drawMoon(x, y)
    local w, h         = love.graphics.getDimensions()
    local img          = moonImage
    local moonRadius   = math.max(w, h) / 11
    local dimsW, dimsH = img:getDimensions()
    local sx, sy       = createFittingScale(img, moonRadius, moonRadius)

    love.graphics.setColor(181 / 255, 226 / 255, 196 / 255, 0.25)
    love.graphics.draw(img, x, y, 0, sx, sx, dimsH / 2, dimsW / 2)
    love.graphics.draw(img, x, y, 0, sx, sx, dimsH / 2, dimsW / 2)


    local radius  = moonRadius
    local eyeSize = radius / 7
    local sx, sy  = createFittingScale(sunEye, eyeSize, eyeSize)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.draw(sunEye, rndOffset(2) + x - radius / 1.2 - eyeSize / 2, rndOffset(2) + y + radius / 2, 0, sx, sy)
    love.graphics.draw(sunEye, rndOffset(2) + x - radius / 1 - eyeSize / 2, rndOffset(2) + y + radius / 2, 0, sx, sy)

    local sx, sy = createFittingScale(sunNose, eyeSize, eyeSize)
    love.graphics.draw(sunNose, rndOffset(2) + x - radius / 1.1 - eyeSize / 2, rndOffset(2) + y + radius / 1.5, 0, sx, sy)


    local sx, sy = createFittingScale(sunTeeth, radius / 4, radius / 5)
    love.graphics.draw(sunTeeth, rndOffset(2) + x - radius / 1.1 - eyeSize / 2, rndOffset(2) + y + radius / 1, 0, sx,
        sy)

    love.graphics.setBlendMode("alpha")

    sunMoonPositions.x = x
    sunMoonPositions.y = y
    sunMoonPositions.radius = moonRadius
end


function drawCelestialBodies()
    local w, h = love.graphics.getDimensions()
    local sunX = w / 12 * 10 --numbers.mapInto(camtlx, 800000, -100000, 0, w)
    local sunY = h / 12      --numbers.mapInto(camtly, 800000, -100000, 0, h)
    --  print(dayTimeTransition.t)

    centerX = w / 2
    centerY = h / 2

    if dayTimeTransition.t >= 0 and dayTimeTransition.t < .5 then
        local angle = dayTimeTransition.t * math.pi
        local rotatedX = math.cos(angle) * (sunX - centerX) - math.sin(angle) * (sunY - centerY) + centerX
        local rotatedY = math.sin(angle) * (sunX - centerX) + math.cos(angle) * (sunY - centerY) + centerY
        drawSun(rotatedX, rotatedY)
    else
        local angle = math.pi + dayTimeTransition.t * -math.pi
        local rotatedX = math.cos(angle) * (sunX - centerX) - math.sin(angle) * (sunY - centerY) + centerX
        local rotatedY = math.sin(angle) * (sunX - centerX) + math.cos(angle) * (sunY - centerY) + centerY
        drawMoon(rotatedX, rotatedY)
    end
end

function drawHillGround()
    local w, h = love.graphics.getDimensions()
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    --grassPattern

    for i = 1, #ground.points - 2, 2 do
        -- the 'road' part

        love.graphics.setColor(lightGrassColor)
        -- love.graphics.setColor({ .5, .5, .5, .5 })
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] - 100,
            ground.points[i + 2], ground.points[i + 3] - 100,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 0], ground.points[i + 1] + 200)

        -- the side part
        love.graphics.polygon("fill",
            ground.points[i + 0], ground.points[i + 1] + 200,
            ground.points[i + 2], ground.points[i + 3] + 200,
            ground.points[i + 2], cambry,
            ground.points[i + 0], cambry)
    end


    local doTextureStuff = true
    if (doTextureStuff) then
        local sideHillFunc = function()
            for i = 1, #ground.points - 2, 2 do
                love.graphics.setColor(1, 1, 1)


                love.graphics.polygon("fill",
                    ground.points[i + 0], ground.points[i + 1] + 200,
                    ground.points[i + 2], ground.points[i + 3] + 200,
                    ground.points[i + 2], cambry,
                    ground.points[i + 0], cambry)
            end
        end
        local topHillFunc = function()
            for i = 1, #ground.points - 2, 2 do
                love.graphics.setColor(1, 1, 1)

                love.graphics.polygon("fill",
                    ground.points[i + 0], ground.points[i + 1] - 100,
                    ground.points[i + 2], ground.points[i + 3] - 100,
                    ground.points[i + 2], ground.points[i + 3] + 200,
                    ground.points[i + 0], ground.points[i + 1] + 200)
            end
        end

        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 1, 0.5 / 2)
        drawRepeatedPatternUsingStencilFunction(sideHillFunc, grassPattern1, darkGrassColorTrans, 1, 0.7 / 2)
        drawRepeatedPatternUsingStencilFunction(topHillFunc, grassPattern2, darkGrassColor, 1, 1 / 2)
    end
end
