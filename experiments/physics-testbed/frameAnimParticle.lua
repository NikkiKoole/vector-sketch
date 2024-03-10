package.path        = package.path .. ";../../?.lua"
local inspect       = require 'vendor.inspect'
local lib           = {}

local frameRowCache = {}
local animations    = {}

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end
local function lerp(a, b, t)
    return a + (b - a) * clamp(t, 0, 1)
end
-- scale, rotation
lib.startAnimParticle   = function(anim, fps, frameData, posData, colorData, alphaData, scaleData, rotationData)
    if not frameRowCache[anim] then
        print('animation ', anim, 'doesnt exist')
    else
        if #frameRowCache[anim] <= frameData.loopBack then
            print('loopback index >= framecount for ', frameData.loopBack, #frameRowCache[anim], anim)
        end
    end
    table.insert(animations, {
        duration = 0,
        name = anim,
        fps = fps,
        loopBack = frameData.loopBack,
        endFrame = frameData.endFrame,
        startFrame = frameData.startFrame,
        framePointer = frameData.startFrame,
        startPos = posData[1],
        endPos = posData[2],
        posDuration = posData[3],
        startColor = colorData[1],
        endColor = colorData[2],
        colorDuration = colorData[3],
        startAlpha = alphaData[1],
        endAlpha = alphaData[2],
        alphaDuration = alphaData[3],
        startScale = scaleData[1],
        endScale = scaleData[2],
        scaleDuration = scaleData[3],
        startRotation = rotationData[1],
        endRotation = rotationData[2],
        rotationDuration = rotationData[3],
    })
end

lib.prepareAnimParticle = function(name, image, cellWidth, cellHeight)
    local imgW, imgH = image:getDimensions()
    if imgW % cellWidth ~= 0 then
        print('this image isnt exactly the right size')
    end
    frameRowCache[name] = { img = image }
    local countX = imgW / cellWidth
    local countY = (imgH / cellHeight) - 1
    for j = 0, countY do
        for i = 0, countX do
            frameRowCache[name][(j * countX) + i] = love.graphics.newQuad(i * cellWidth, j * cellHeight, cellWidth,
                cellHeight, imgW,
                imgH)
        end
    end
end

lib.updateAnimParticles = function(dt)
    for i = 1, #animations do
        animations[i].duration = animations[i].duration + dt
        local frame = animations[i].duration / (1.0 / animations[i].fps)
        local curFame = frame + animations[i].startFrame
        local amountFramesInAnimation = animations[i].endFrame == -1 and #frameRowCache[animations[i].name] or
            animations[i].endFrame
        local loopBackIndex = animations[i].loopBack

        if (math.floor(curFame) > loopBackIndex) then
            animations[i].framePointer = loopBackIndex +
                math.floor(curFame) % (amountFramesInAnimation - loopBackIndex)
        else
            animations[i].framePointer = math.floor(curFame) % amountFramesInAnimation
        end
    end

    for i = #animations, 1, -1 do
        if animations[i].duration > animations[i].posDuration and
            animations[i].duration > animations[i].colorDuration and
            animations[i].duration > animations[i].scaleDuration and
            animations[i].duration > animations[i].rotationDuration and
            animations[i].duration > animations[i].alphaDuration

        then
            table.remove(animations, i)
        end
    end
end

lib.drawAnimParticles   = function()
    for i = 1, #animations do
        local a = animations[i]
        local quad = frameRowCache[a.name][a.framePointer]
        local img = frameRowCache[a.name].img

        local x = lerp(a.startPos.x, a.endPos.x, a.duration / a.posDuration)
        local y = lerp(a.startPos.y, a.endPos.y, a.duration / a.posDuration)

        local r = lerp(a.startColor[1], a.endColor[1], a.duration / a.colorDuration)
        local g = lerp(a.startColor[2], a.endColor[2], a.duration / a.colorDuration)
        local b = lerp(a.startColor[3], a.endColor[3], a.duration / a.colorDuration)

        local alpha = lerp(a.startAlpha, a.endAlpha, a.duration / a.alphaDuration)
        local scale = lerp(a.startScale, a.endScale, a.duration / a.scaleDuration)
        local rotation = lerp(a.startRotation, a.endRotation, a.duration / a.rotationDuration)

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.draw(img, quad, x, y, rotation, scale, scale)
    end
end

return lib
