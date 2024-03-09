package.path  = package.path .. ";../../?.lua"
local inspect = require 'vendor.inspect'
local lib     = {}


local frameRowCache = {}
local animations    = {}

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end
local function lerp(a, b, t)
    return a + (b - a) * clamp(t, 0, 1)
end
-- scale, rotation
lib.startAnimParticle   = function(anim, fps, loopBack, posData, colorData, alphaData, scaleData)
    if not frameRowCache[anim] then
        print('animation ', anim, 'doesnt exist')
    else
        if #frameRowCache[anim] <= loopBack then
            print('loopback index >= framecount for ', loopBack, #frameRowCache[anim], anim)
        end
    end
    table.insert(animations, {
        duration = 0,
        name = anim,
        fps = fps,
        loopBack = loopBack,
        framePointer = 0,
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
    })
end

lib.prepareAnimParticle = function(name, image, cellWidth, cellHeight)
    local imgW, imgH = image:getDimensions()
    if imgW % cellWidth ~= 0 then
        print('this image isnt exactly the right size')
    end
    frameRowCache[name] = { img = image }
    local count = imgW / cellWidth
    for i = 0, count do
        frameRowCache[name][i] = love.graphics.newQuad(i * cellWidth, 0, cellWidth, cellHeight, imgW, imgH)
    end
    --print('added', count, 'frames to animation: ', name)
end

lib.updateAnimParticles = function(dt)
    for i = 1, #animations do
        animations[i].duration = animations[i].duration + dt
        local frame = animations[i].duration / (1.0 / animations[i].fps)
        local amountFramesInAnimation = #frameRowCache[animations[i].name]
        local loopBackIndex = animations[i].loopBack

        if (math.floor(frame) > loopBackIndex) then
            animations[i].framePointer = loopBackIndex + math.floor(frame) % (amountFramesInAnimation - loopBackIndex)
        else
            animations[i].framePointer = math.floor(frame) % amountFramesInAnimation
        end
    end

    for i = #animations, 1, -1 do
        if animations[i].duration > animations[i].posDuration and
            animations[i].duration > animations[i].colorDuration and
            animations[i].duration > animations[i].scaleDuration and
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
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.draw(img, quad, x, y, 0, scale, scale)
    end
end

return lib
