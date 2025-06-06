-- =================================================================
-- Emotion Sandbox: Step 1 - A Simple Smile
--
-- Controls:
-- [Q/A]: Increase/Decrease HAPPINESS
-- =================================================================

-- function love.load()
--     -- Our emotional "brain", starting with just one slider.
--     emotionState = {
--         happiness = 0.0,
--         sadness = 0.0 -- NEW
--     }


--     love.graphics.setFont(love.graphics.newFont('VoltaT-Regu.ttf', 20))
-- end

-- function love.keypressed(key)
--     if key == 'space' then
--         for k, _ in pairs(emotionState) do emotionState[k] = 0.0 end
--     end
--     if key == 'escape' then
--         love.event.quit()
--     end
-- end

-- function love.update(dt)
--     -- Control the happiness slider
--     local changeSpeed = 1.0 * dt
--     if love.keyboard.isDown('q') then
--         emotionState.happiness = math.min(1.0, emotionState.happiness + changeSpeed)
--     end
--     if love.keyboard.isDown('a') then
--         emotionState.happiness = math.max(0.0, emotionState.happiness - changeSpeed)
--     end
--     -- NEW: Sadness controls
--     if love.keyboard.isDown('w') then
--         emotionState.sadness = math.min(1.0, emotionState.sadness + changeSpeed)
--     end
--     if love.keyboard.isDown('s') then
--         emotionState.sadness = math.max(0.0, emotionState.sadness - changeSpeed)
--     end
-- end

-- function love.draw()
--     love.graphics.clear(0.2, 0.2, 0.25)

--     -- Draw the character in the center of the screen
--     drawCharacter(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)

--     -- Draw the UI
--     drawUI()
-- end

-- -- =================================================================
-- -- Drawing Functions
-- -- =================================================================

-- function drawCharacter(x, y)
--     love.graphics.push()
--     love.graphics.translate(x, y)

--     -- A simple head shape
--     love.graphics.setColor(0.9, 0.8, 0.7)
--     love.graphics.ellipse("fill", 0, -20, 150, 160)

--     -- Pass the emotional state to the mouth renderer
--     renderMouth(emotionState)

--     love.graphics.pop()
-- end

-- function renderMouth(emotions)
--     -- 1. DEFINE THE MOUTH'S IDLE (NEUTRAL) STATE
--     local idleWidth            = 80
--     local idleCornerHeight     = 0
--     local idleMouthOpening     = 5

--     -- 2. DEFINE THE MAXIMUM INFLUENCE OF EACH EMOTION
--     local maxHappyWidth        = 40
--     local maxHappyCornerHeight = 30
--     local maxSadCornerHeight   = -25 -- NEW: Sadness pulls corners DOWN (negative value)

--     -- 3. CALCULATE THE FINAL, BLENDED VALUES
--     local happiness            = emotions.happiness
--     local sadness              = emotions.sadness -- NEW

--     -- Width is only affected by happiness for now
--     local finalWidth           = idleWidth + (maxHappyWidth * happiness)

--     -- NEW: The core of the blending logic.
--     -- The final corner height is the sum of all emotional influences.
--     local happyInfluence       = maxHappyCornerHeight * happiness
--     local sadInfluence         = maxSadCornerHeight * sadness
--     local finalCornerHeight    = idleCornerHeight + happyInfluence + sadInfluence

--     -- 4. DEFINE THE MOUTH'S GEOMETRY (This part is unchanged)
--     local mouthX               = 0
--     local mouthY               = 20

--     local cornerLeft           = { x = mouthX - finalWidth / 2, y = mouthY - finalCornerHeight }
--     local cornerRight          = { x = mouthX + finalWidth / 2, y = mouthY - finalCornerHeight }

--     local upperLipY            = mouthY - idleMouthOpening
--     local lowerLipY            = mouthY + idleMouthOpening

--     -- 5. DRAW THE MOUTH (This part is unchanged)
--     --love.graphics.setColor(0.1, 0, 0)
--     --love.graphics.line(cornerLeft.x, cornerLeft.y, cornerRight.x, cornerRight.y)
--     --love.graphics.ellipse("fill", mouthX, mouthY, finalWidth / 2, idleMouthOpening)

--     love.graphics.setColor(1, 0.6, 0.6)
--     love.graphics.setLineWidth(15)

--     local upperCurve = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y, mouthX, upperLipY, cornerRight.x,
--         cornerRight.y)
--     love.graphics.line(upperCurve:render())
--     --love.graphics.line(cornerLeft.x, cornerLeft.y, mouthX, upperLipY, cornerRight.x, cornerRight.y)
--     local lowerCurve = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y, mouthX, lowerLipY, cornerRight.x,
--         cornerRight.y)
--     love.graphics.line(lowerCurve:render())
--     --love.graphics.line(cornerLeft.x, cornerLeft.y, mouthX, lowerLipY, cornerRight.x, cornerRight.y)
--     love.graphics.setLineWidth(1)
-- end

-- function drawUI()
--     love.graphics.setColor(1, 1, 1)

--     -- A helper function to draw a slider bar
--     local function drawSlider(name, value, y, keyUp, keyDown)
--         local x, barWidth, barHeight = 20, 200, 20
--         local label = string.format("[%s/%s] %s: %.2f", keyUp, keyDown, name, value)
--         love.graphics.print(label, x, y)
--         love.graphics.rectangle("line", x, y + 25, barWidth, barHeight)
--         love.graphics.setColor(0.4, 0.8, 1)
--         love.graphics.rectangle("fill", x, y + 25, barWidth * value, barHeight)
--         love.graphics.setColor(1, 1, 1)
--     end

--     drawSlider("Happiness", emotionState.happiness, 20, "Q", "A")
--     drawSlider("Sadness", emotionState.sadness, 80, "W", "S") -- NEW
-- end

local inspect = require 'inspect'
function love.load()
    -- 1. THE EMOTIONAL BRAIN: Our four sliders from 0.0 to 1.0
    emotionState = {
        happiness = 0.0,
        sadness = 0.0,
        anger = 0.0,
        surprise = 0.0,
    }

    -- 2. THE EMOTIONAL INFLUENCE TABLE: How each emotion affects the mouth levers.
    -- This table defines the "maximum influence" each emotion has on a parameter.
    -- To change the character's personality, tweak these values.
    -- emotionalInfluences = {
    --     -- Parameter Name: { happiness, sadness, anger,   surprise }
    --     width        = { 0.3, -0.2, 0.5, -0.4 }, -- Multiplier
    --     jawDrop      = { 0.4, 0.2, 1.0, 1.2 },   -- Multiplier
    --     cornerHeight = { 30, -25, 5, 0 },        -- Pixel offset
    --     upperLipY    = { 0, 5, -40, -20 },       -- Pixel offset (negative is UP)
    --     lowerLipY    = { 0, -10, 30, 20 },       -- Pixel offset (positive is DOWN)
    --     wobble       = { 0, 20, 0, 0 },          -- Pixel offset (only sadness uses this)
    --     curveFactor  = { 0.0, -0.2, -0.3, 0.8 }, -- Multiplier
    --     teethGap     = { 0.2, -0.5, 1.0, 1.5 },  -- Multiplier
    -- }
    -- NEW, PURE-MULTIPLIER INFLUENCE TABLE
    emotionalInfluences = {
        -- Parameter:         { happiness, sadness, anger,   surprise }
        width        = { 0.3, -0.2, 0.5, -0.4 }, -- % change to base width
        jawDrop      = { 0.4, 0.2, 1.0, 1.2 },   -- % of max jaw range
        cornerHeight = { 0.5, -0.4, 0.1, 0.0 },  -- % of vertical range
        upperLipY    = { 0, 0.1, -0.7, -0.3 },   -- % of vertical range (negative is UP)
        lowerLipY    = { 0.0, -0.1, 0.5, 0.3 },  -- % of vertical range (positive is DOWN from jaw)
        wobble       = { 0.0, 0.3, 0.0, 0.0 },   -- % of vertical range
        curveFactor  = { 0.0, -0.2, -0.3, 0.8 },
        teethGap     = { 0.2, -0.5, 1.0, 1.5 },
    }
    love.graphics.setFont(love.graphics.newFont('VoltaT-Regu.ttf', 20))
end

function love.update(dt)
    -- This function handles the keyboard input to control the sliders.
    local changeSpeed = 1.0 * dt -- How fast the sliders move

    -- Happiness
    if love.keyboard.isDown('q') then emotionState.happiness = math.min(1.0, emotionState.happiness + changeSpeed) end
    if love.keyboard.isDown('a') then emotionState.happiness = math.max(0.0, emotionState.happiness - changeSpeed) end
    -- Sadness
    if love.keyboard.isDown('w') then emotionState.sadness = math.min(1.0, emotionState.sadness + changeSpeed) end
    if love.keyboard.isDown('s') then emotionState.sadness = math.max(0.0, emotionState.sadness - changeSpeed) end
    -- Anger
    if love.keyboard.isDown('e') then emotionState.anger = math.min(1.0, emotionState.anger + changeSpeed) end
    if love.keyboard.isDown('d') then emotionState.anger = math.max(0.0, emotionState.anger - changeSpeed) end
    -- Surprise
    if love.keyboard.isDown('r') then emotionState.surprise = math.min(1.0, emotionState.surprise + changeSpeed) end
    if love.keyboard.isDown('f') then emotionState.surprise = math.max(0.0, emotionState.surprise - changeSpeed) end
end

function love.keypressed(key)
    if key == 'space' then
        for k, _ in pairs(emotionState) do emotionState[k] = 0.0 end
    end
    if key == 'escape' then
        love.event.quit()
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(0.2, 0.2, 0.25)

    local baseRig = {
        width = 80,
        verticalRange = 60, -- Max distance lips/corners can move
        jawRange = 80,      -- Max distance jaw can drop
    }
    drawCharacter(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, baseRig)

    local baseRig = {
        width = 40,
        verticalRange = 30, -- Max distance lips/corners can move
        jawRange = 40,      -- Max distance jaw can drop
    }
    --drawCharacter(w - 200, 100, baseRig)
    drawUI()
end

-- =================================================================
-- CHARACTER DRAWING FUNCTIONS
-- =================================================================

function drawCharacter(x, y, baseRig)
    love.graphics.push()
    love.graphics.translate(x, y)

    -- A simple head shape
    love.graphics.setColor(0.9, 0.8, 0.7)
    love.graphics.ellipse("fill", 0, -baseRig.width / 3, baseRig.width * 1.5, baseRig.width * 1.5)


    renderMouth(emotionState, baseRig)

    love.graphics.pop()
end

function renderMouth(emotions, baseRig)
    -- 1. DEFINE IDLE (BASE) STATE
    -- 1. DEFINE THE CHARACTER RIG (Base pixel dimensions)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle('fill', -baseRig.width / 2, -baseRig.verticalRange / 2, baseRig.width, baseRig.verticalRange)

    local base = {

        cornerHeight = 0,
        upperLipY = 0,
        lowerLipY = 0,
        wobble = 0,
        curveFactor = 0.5,
        teethGap = 0.2
    }

    -- 2. CALCULATE FINAL BLENDED VALUES by applying influences
    local blendedRatios = {}
    for param, influenceList in pairs(emotionalInfluences) do
        local totalInfluence = (influenceList[1] * emotions.happiness) +
            (influenceList[2] * emotions.sadness) +
            (influenceList[3] * emotions.anger) +
            (influenceList[4] * emotions.surprise)


        blendedRatios[param] = totalInfluence
    end

    -- print(inspect(blendedRatios))


    local final = {}
    -- Multiplicative values start with the base and are scaled by the influence.
    final.width = baseRig.width * (1 + blendedRatios.width)
    final.jawDrop = baseRig.jawRange * blendedRatios.jawDrop
    -- NOTE: curveFactor and teethGap are also multiplicative
    final.curveFactor = base.curveFactor * (1 + blendedRatios.curveFactor)
    final.teethGap = base.teethGap * (1 + blendedRatios.teethGap)

    -- Additive/Offset values are calculated by scaling a range by the influence.
    final.cornerHeight = base.cornerHeight + (baseRig.verticalRange * blendedRatios.cornerHeight)
    final.upperLipY = base.upperLipY + (baseRig.verticalRange * blendedRatios.upperLipY)
    final.lowerLipY = base.lowerLipY + (baseRig.verticalRange * blendedRatios.lowerLipY)


    final.wobble = base.wobble + (baseRig.verticalRange * blendedRatios.wobble) -- Don't forget wobble!

    print(inspect(final))



    -- 3. DEFINE ANCHOR & CONTROL POINTS from the final blended values
    local mouthWidth, jawY, cornerY         = final.width, final.jawDrop, final.cornerHeight
    local upperLipY, lowerLipY, curveFactor = final.upperLipY, final.lowerLipY, final.curveFactor

    local cornerLeft                        = { x = -mouthWidth / 2, y = -cornerY } -- Invert Y for intuitive control
    local cornerRight                       = { x = mouthWidth / 2, y = -cornerY }
    --print(mouthWidth)
    local upperCenter                       = { x = 0, y = upperLipY - (10 * curveFactor) }
    local lowerJawPos                       = jawY
    local lowerCenter                       = { x = 0, y = lowerJawPos + lowerLipY + (10 * curveFactor) }

    -- 4. DEFINE THE BÉZIER CURVES
    local upperLipCurve1                    = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y,
        (cornerLeft.x + upperCenter.x) / 2, (cornerLeft.y + upperCenter.y) / 2, upperCenter.x, upperCenter.y)
    local upperLipCurve2                    = love.math.newBezierCurve(upperCenter.x, upperCenter.y,
        (upperCenter.x + cornerRight.x) / 2, (upperCenter.y + cornerRight.y) / 2, cornerRight.x, cornerRight.y)

    local lowerLipCurve1, lowerLipCurve2
    -- if emotions.sadness > 0.1 then -- Activate the "sad wobble"
    --     local wobbleY = lowerJawPos + final.wobble
    --     local midLeft = { x = -mouthWidth / 4, y = wobbleY }
    --     local midRight = { x = mouthWidth / 4, y = wobbleY }
    --     lowerLipCurve1 = love.math.newBezierCurve(cornerLeft.x, lowerJawPos, midLeft.x, midLeft.y, lowerCenter.x,
    --         lowerCenter.y)
    --     lowerLipCurve2 = love.math.newBezierCurve(lowerCenter.x, lowerCenter.y, midRight.x, midRight.y, cornerRight.x,
    --         lowerJawPos)
    -- else -- Use a simple curve
    lowerLipCurve1                          = love.math.newBezierCurve(cornerLeft.x, lowerJawPos,
        (cornerLeft.x + lowerCenter.x) / 2,
        (lowerCenter.y + lowerJawPos) / 2, lowerCenter.x, lowerCenter.y)
    lowerLipCurve2                          = love.math.newBezierCurve(lowerCenter.x, lowerCenter.y,
        (lowerCenter.x + cornerRight.x) / 2,
        (lowerCenter.y + lowerJawPos) / 2, cornerRight.x, lowerJawPos)
    --end

    -- 5. DRAW THE MOUTH using stencils for a clean look
    local vertices                          = {}
    local upperVerts                        = { upperLipCurve1:render(10), upperLipCurve2:render(10) }
    for i = 1, #upperVerts do vertices[#vertices + 1] = upperVerts[i] end
    local lowerVerts = { lowerLipCurve1:render(10), lowerLipCurve2:render(10) }
    for i = #lowerVerts, 1, -2 do
        vertices[#vertices + 1] = lowerVerts[i - 1]; vertices[#vertices + 1] = lowerVerts[i]
    end

    --love.graphics.stencil(function() love.graphics.polygon("fill", vertices) end, "replace", 1)
    -- love.graphics.setStencilTest("equal", 1)

    --love.graphics.setColor(0.1, 0, 0)
    --love.graphics.polygon("fill", vertices)

    -- if emotions.anger > 0.8 then
    --     love.graphics.setColor(1, 0.5, 0.5)
    --     love.graphics.rectangle('fill', -mouthWidth / 2, upperLipY, mouthWidth, 15) -- Gums
    -- end

    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.rectangle('fill', -mouthWidth / 2, -5, mouthWidth, jawY + 10) -- Single block for teeth
    -- love.graphics.setColor(0, 0, 0, 0.5)
    -- love.graphics.setLineWidth(math.max(1, final.teethGap))
    -- love.graphics.line(-mouthWidth / 2, jawY / 2, mouthWidth / 2, jawY / 2) -- Gap between teeth

    -- love.graphics.setStencilTest()

    love.graphics.setColor(1, 0.6, 0.6)
    love.graphics.setLineWidth(baseRig.width / 6)
    love.graphics.line(upperLipCurve1:render())
    love.graphics.line(upperLipCurve2:render())
    love.graphics.line(lowerLipCurve1:render())
    love.graphics.line(lowerLipCurve2:render())
    love.graphics.setLineWidth(1)
end

-- =================================================================
-- UI DRAWING FUNCTION
-- =================================================================
function drawUI()
    love.graphics.push()
    love.graphics.translate(20, 20)
    love.graphics.setColor(1, 1, 1)

    local function drawSlider(name, value, y, keyUp, keyDown)
        love.graphics.rectangle("line", 150, y, 200, 20)
        love.graphics.setColor(0.4, 0.8, 1)
        love.graphics.rectangle("fill", 150, y, 200 * value, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("[%s/%s] %s", keyUp, keyDown, name), 0, y, 200, "left")
        love.graphics.printf(string.format("%.2f", value), 150, y + 2, 200, "center")
    end

    drawSlider("Happiness", emotionState.happiness, 0, "Q", "A")
    drawSlider("Sadness", emotionState.sadness, 30, "W", "S")
    drawSlider("Anger", emotionState.anger, 60, "E", "D")
    drawSlider("Surprise", emotionState.surprise, 90, "R", "F")

    love.graphics.printf("[SPACE] Reset Emotions", 0, 130, 400, "left")
    love.graphics.pop()
end
