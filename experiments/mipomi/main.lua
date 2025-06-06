local inspect = require 'inspect'

-- things todo later:
-- add extra markers like (breathout) (sign) (tsk) (ooof) (ough) etc.
-- Allow speaker-specific variation (some Mipos always end high, some stutter, some have deep voices).
-- Try combining pitch with timing (e.g. slower syllable = sadder).
-- make the code testable, for that we need to unroll the bezier to pure code.
-- Or define speaker personalities that bias pitch/timing differently?
-- another thing i want is emotion that sort of decide on the gap length
-- another though would be volume markers!

-- ma     = normal
-- MA     = emphasized
-- ma!    = louder (1.25)
-- ma!!   = very loud (1.5)
-- ma<    = soft (0.75)
-- ma<<   = whisper (0.5)
-- Marker	Effect
-- !	Loud
-- !!	Very Loudx
-- <	Soft
-- <<	Whisper
-- ~	Legato glide
-- '	Clipped / Glottal / Cutoff
-- -	(Stutter / pre-played repeat?)
-- ?	Question rise
-- MA	Emphasis
-- Ma/mA	Tone direction



-- Pattern	Suggested Meaning	Pitch Curve	Volume	Emotion
-- ma	Normal	neutral	1.0	Calm / default
-- MA	Strong Emphasis	emphasis-first	1.25	Assertive / loud
-- Ma	Light / Upward	rise	1.0	Curious / upbeat
-- mA	Heavy / Downward	fall	1.1	Serious / tired
-- 🛠️ Implicit Traits You Could Formalize as “Speaker Style”
-- These traits are already present in the code or comments but could become speaker profile fields:

-- Trait	Description	Controlled By
-- basePitch	Default frequency base	root=G3, etc.
-- jitterAmount	How much randomness in pitch	rnd=2, etc.
-- glideType	natural vs targeted glide	not formalized yet
-- vibrato	Whether LFO is used	currently hardcoded off
-- timingGap	Word and syllable spacing	saySyllableGap, sayWordGap
-- fadeType	Normal vs chaotic or exponential	chaoticFade, etc.
-- volumeBias	Consistently louder/softer speakers	not yet configured

-- speakers = {
--     default = {
--         basePitch = noteToRatio("C4"),
--         jitter = 0,
--         glide = "natural",
--         syllableGap = 0.1,
--         wordGap = 0.3,
--         vibrato = false,
--         volumeBias = 1.0
--     },
--     quirky = {
--         basePitch = noteToRatio("D4"),
--         jitter = 2,
--         glide = "targeted",
--         vibrato = true,
--         volumeBias = 1.2
--     },
--     mellow = {
--         basePitch = noteToRatio("A3"),
--         glide = "natural",
--         syllableGap = 0.15,
--         volumeBias = 0.8
--     }
-- }

-- order of video
-- make samples mi po
-- play on keypress.
-- make function say('mi-po')
-- make syllabels be played after each other
-- do say('mi-po mi-po') (add pauses)
-- say('mi-po?') (curves)
-- say mipo??     more extreme
-- say mi-po_    opposite
-- say(?mi-po-po-po) -- global rise
-- say(_mi-po-po) -- global fall
-- add pauses with , also always put extra space aroudn to make typing less error prone
-- start with notes like [c4] == default, [c3] octave down, [c5] octave up
-- also use relative notes and '[c3]mi [-1]mi [-2]mi' will start at c3 then go to b3 then a3


--- new lipsync fun:
-- 1. Data representation of the mouth shapes from your image.
-- (This table remains the same, it's our library of shapes)
local mouthShapesOLD = {
    ['A_I'] = { width = 1.2, height = 0.8, teethVisible = true, tongueVisible = true },
    ['OU_W_Q'] = { width = 0.4, height = 0.4, teethVisible = false, tongueVisible = false },
    ['CDEGK_NRS'] = { width = 1.0, height = 0.4, teethVisible = true, tongueVisible = false },
    ['TH_L'] = { width = 0.8, height = 0.5, teethVisible = true, tongueVisible = true },
    ['F_V'] = { width = 1.0, height = 0.3, teethVisible = true, tongueVisible = false },
    ['L_OU'] = { width = 0.5, height = 0.6, teethVisible = true, tongueVisible = true },
    ['O_U_AGH'] = { width = 0.7, height = 0.7, teethVisible = false, tongueVisible = false },
    ['UGH'] = { width = 1.1, height = 0.7, teethVisible = false, tongueVisible = false },
    ['M_B_P'] = { width = 0.9, height = 0.15, teethVisible = false, tongueVisible = false },
    ['MMM'] = { width = 0.9, height = 0.1, teethVisible = false, tongueVisible = false },
    ['CLOSED'] = { width = 1.0, height = 0.05, teethVisible = false, tongueVisible = false },
}

-- NEW DATA STRUCTURE with Jaw and TeethMode
local mouthShapes = {
    ['A_I'] = { width = 1.2, jawDrop = 0.8, teethMode = "apart" },
    ['OU_W_Q'] = { width = 0.4, jawDrop = 0.2, teethMode = "none" },
    ['CDEGK_NRS'] = { width = 1.0, jawDrop = 0.3, teethMode = "apart" },
    ['TH_L'] = { width = 0.8, jawDrop = 0.4, teethMode = "upper", tongueVisible = true },
    ['F_V'] = { width = 1.0, jawDrop = 0.1, teethMode = "upper" },
    ['L_OU'] = { width = 0.5, jawDrop = 0.6, teethMode = "apart", tongueVisible = true },
    ['O_U_AGH'] = { width = 0.7, jawDrop = 0.7, teethMode = "none" },
    ['UGH'] = { width = 1.1, jawDrop = 0.7, teethMode = "none" },
    ['M_B_P'] = { width = 0.9, jawDrop = 0.0, teethMode = "none" },
    ['MMM'] = { width = 0.9, jawDrop = 0.0, teethMode = "none" },
    ['CLOSED'] = { width = 1.0, jawDrop = 0.0, teethMode = "none" },
}
-- 2. REFINED reverse map for YOUR specific phonemes.
local phonemeToShape = {
    -- Consonants from your list
    m = 'M_B_P',
    b = 'M_B_P',
    p = 'M_B_P',
    f = 'F_V',
    k = 'CDEGK_NRS',

    -- Vowels from your list
    a = 'A_I',
    i = 'CDEGK_NRS', -- The wide, teeth-showing shape fits the 'ee' sound well.
    o = 'OU_W_Q',
}

-- 3. A helper to parse syllables into consonant and vowel.
-- (This remains the same and works perfectly for your C+V syllables)
local function parseSyllable(syllableName)
    if #syllableName < 2 then return nil, syllableName:sub(1, 1) end
    return syllableName:sub(1, 1), syllableName:sub(2, 2)
end

-- 4. Global variable to hold the current state for the rendering function.
local currentMouthState = { shape = mouthShapes['CLOSED'] }
local CONSONANT_DURATION = 0.3 -- 30% of the syllable time is for the consonant

-- =================================================================
-- EMOTION-AWARE LIP-SYNC CODE
-- =================================================================

-- This data from our previous attempt is still perfect.
local emotionStyles = {
    neutral   = { scale = 1.0, cornerYOffset = 0.0, lipCurveFactor = 1.0 },
    happy     = { scale = 1.1, cornerYOffset = -0.3, lipCurveFactor = 1.2 }, -- Corners go UP
    sad       = { scale = 0.9, cornerYOffset = 0.25, lipCurveFactor = 1.2 }, -- Corners go DOWN
    angry     = { scale = 1.3, cornerYOffset = -0.5, lipCurveFactor = 0.8 }, -- Tense, flatter curve
    surprised = { scale = 1.4, cornerYOffset = 0.0, lipCurveFactor = 1.5 },  -- Very round
}

local currentEmotion = "neutral"

-- Global variable to hold the character's current emotion
local currentEmotion = "neutral"


-- end lipsync fun



function love.load()
    keys = { 'ma', 'mi', 'mo', 'ba', 'bi', 'bo', 'fa', 'fi', 'fo', 'pa', 'pi', 'po', 'ka', 'ki', 'ko' }
    syllables = {}
    for _, key in ipairs(keys) do
        syllables[key] = love.audio.newSource("syllables/" .. key .. ".ogg", "static")
    end
    activeSources, sayQueue = {}, {}
    sayTimer = 0
    saySyllableGap, sayWordGap = 0.1, 0.3
    lastPitch = nil
    -- legatoStrength = .5
    legatoFadeRate = .3
end

function renderMouthOLD(state)
    local x, y = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    local baseWidth, baseHeight = 100, 80 -- The base size of the mouth in pixels

    local shape = state.shape

    -- Calculate the final dimensions
    local mouthWidth = baseWidth * shape.width
    local mouthHeight = baseHeight * shape.height

    -- 1. Draw the outer lips (a pink ellipse)
    love.graphics.setColor(220 / 255, 100 / 255, 100 / 255)
    love.graphics.ellipse("fill", x, y, mouthWidth / 2 + 5, mouthHeight / 2 + 10)

    -- 2. Draw the inner mouth opening (a black ellipse)
    love.graphics.setColor(0, 0, 0)
    love.graphics.ellipse("fill", x, y, mouthWidth / 2, mouthHeight / 2)

    -- 3. Conditionally draw teeth
    if shape.teethVisible then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x - mouthWidth / 2.2, y - mouthHeight / 2.5, mouthWidth * 0.9, 10)
        love.graphics.rectangle("fill", x - mouthWidth / 2.2, y + mouthHeight / 2.5 - 10, mouthWidth * 0.9, 10)
    end

    -- 4. Conditionally draw the tongue
    if shape.tongueVisible then
        love.graphics.setColor(240 / 255, 150 / 255, 150 / 255)
        love.graphics.ellipse("fill", x, y + mouthHeight * 0.1, 30, 20)
    end

    love.graphics.setColor(1, 1, 1) -- Reset color
end

function renderMouth2(state)
    local x, y = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    local baseWidth, baseHeight = 100, 80

    -- Get the base phonetic shape and the current emotional style
    local phoneticShape = state.shape
    local emoStyle = emotionStyles[currentEmotion] or emotionStyles.neutral

    -- 1. APPLY EMOTIONAL MODIFIERS
    local scale = emoStyle.scale
    local mouthWidth = baseWidth * phoneticShape.width * scale
    local mouthHeight = baseHeight * phoneticShape.height * scale

    -- Prevent mouth from fully closing to maintain a visible line
    if mouthHeight < 2 then mouthHeight = 2 end

    -- 2. CALCULATE KEY ANCHOR POINTS FOR THE MOUTH

    -- The corners of the mouth are our primary anchors.
    local cornerLeft = { x = x - mouthWidth / 2, y = y }
    local cornerRight = { x = x + mouthWidth / 2, y = y }

    -- Apply the emotional offset to the corners to make them smile or frown.
    local cornerYOffset = mouthWidth * emoStyle.cornerYOffset
    cornerLeft.y = y + cornerYOffset
    cornerRight.y = y + cornerYOffset

    -- The top and bottom center points of the inner mouth (the black part).
    local topCenter = { x = x, y = y - mouthHeight / 2 }
    local bottomCenter = { x = x, y = y + mouthHeight / 2 }

    -- 3. CALCULATE THE CONTROL POINTS FOR THE BÉZIER CURVES

    -- The control points determine the curvature of the lips.
    -- We'll base them on the center points and the emotional `lipCurveFactor`.
    local upperControlPoint = {
        x = x,
        y = topCenter.y - (mouthHeight * emoStyle.lipCurveFactor * 0.5)
    }
    local lowerControlPoint = {
        x = x,
        y = bottomCenter.y + (mouthHeight * emoStyle.lipCurveFactor * 0.5)
    }

    -- 4. DRAW THE MOUTH

    -- First, create a polygon for the inner mouth shape to fill it with black.
    -- We can approximate the curves with a series of vertices.
    local vertices = {}
    local steps = 20 -- More steps = smoother curve
    -- Generate vertices for the upper lip curve
    --
    local upperlip = {}
    for i = 0, steps do
        local t = i / steps
        local px, py = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y, upperControlPoint.x, upperControlPoint.y,
            cornerRight.x, cornerRight.y):evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)

        table.insert(upperlip, px)
        table.insert(upperlip, py)
    end
    -- Generate vertices for the lower lip curve (in reverse to close the polygon)
    local lowerlip = {}
    for i = steps, 0, -1 do
        local t = i / steps
        local px, py = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y, lowerControlPoint.x, lowerControlPoint.y,
            cornerRight.x, cornerRight.y):evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)

        table.insert(lowerlip, px)
        table.insert(lowerlip, py)
    end

    love.graphics.setColor(0.2, 0.1, 0.1)
    love.graphics.polygon("fill", vertices)

    -- Now, draw the colored lips themselves as thick lines on top.
    love.graphics.setColor(220 / 255, 100 / 255, 100 / 255)
    love.graphics.setLineWidth(15 * scale)

    -- Draw the upper and lower lip curves
    local upper = love.math.newBezierCurve(upperlip)
    love.graphics.line(upper:render())

    local lower = love.math.newBezierCurve(lowerlip)
    love.graphics.line(lower:render())


    love.graphics.setLineWidth(1) -- Reset line width

    -- 5. DRAW TEETH AND TONGUE (conditionally, on top of the black)

    if phoneticShape.teethVisible then
        love.graphics.setColor(1, 1, 1)
        -- We can place the teeth more intelligently now, relative to the center
        local teethHeight = 12 * scale
        love.graphics.rectangle("fill", x - mouthWidth / 2.2, y - teethHeight / 2, mouthWidth * 0.9, teethHeight)
    end

    if phoneticShape.tongueVisible then
        love.graphics.setColor(240 / 255, 150 / 255, 150 / 255)
        love.graphics.ellipse("fill", x, y + mouthHeight * 0.2, 30 * scale, 20 * scale)
    end

    love.graphics.setColor(1, 1, 1) -- Reset color
end

function renderMouth1(state)
    local x, y = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    local baseWidth, baseHeight = 100, 80

    -- Get the base phonetic shape and the current emotional style
    local phoneticShape = state.shape
    local emoStyle = emotionStyles[currentEmotion] or emotionStyles.neutral

    -- 1. APPLY EMOTIONAL MODIFIERS (No changes here)
    local scale = emoStyle.scale
    local mouthWidth = baseWidth * phoneticShape.width * scale
    local mouthHeight = baseHeight * phoneticShape.height * scale
    if mouthHeight < 2 then mouthHeight = 2 end

    -- 2. CALCULATE KEY ANCHOR POINTS FOR THE MOUTH (No changes here)
    local cornerLeft = { x = x - mouthWidth / 2, y = y }
    local cornerRight = { x = x + mouthWidth / 2, y = y }
    local cornerYOffset = mouthWidth * emoStyle.cornerYOffset
    cornerLeft.y = y + cornerYOffset
    cornerRight.y = y + cornerYOffset
    local topCenter = { x = x, y = y - mouthHeight / 2 }
    local bottomCenter = { x = x, y = y + mouthHeight / 2 }

    -- 3. CALCULATE THE CONTROL POINTS FOR THE BÉZIER CURVES (No changes here)
    local upperControlPoint = { x = x, y = topCenter.y - (mouthHeight * emoStyle.lipCurveFactor * 0.5) }
    local lowerControlPoint = { x = x, y = bottomCenter.y + (mouthHeight * emoStyle.lipCurveFactor * 0.5) }

    -- 4. GENERATE THE MOUTH POLYGON (No changes here)
    local vertices = {}
    local steps = 20
    local upperlip_points = {}
    local lowerlip_points = {}

    local upper_curve = love.math.newBezierCurve(
        cornerLeft.x, cornerLeft.y,
        upperControlPoint.x, upperControlPoint.y,
        cornerRight.x, cornerRight.y)
    local lower_curve = love.math.newBezierCurve(
        cornerLeft.x, cornerLeft.y,
        lowerControlPoint.x, lowerControlPoint.y,
        cornerRight.x, cornerRight.y)

    for i = 0, steps do
        local t = i / steps
        local px, py = upper_curve:evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)
        table.insert(upperlip_points, px)
        table.insert(upperlip_points, py)
    end
    for i = steps, 0, -1 do
        local t = i / steps
        local px, py = lower_curve:evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)
        table.insert(lowerlip_points, px)
        table.insert(lowerlip_points, py)
    end

    local upperCurve = love.math.newBezierCurve(upperlip_points)
    local lowerCurve = love.math.newBezierCurve(lowerlip_points)
    local _, ucY = upperCurve:evaluate(0.5)
    local _, lcY = lowerCurve:evaluate(0.5)

    -- 5. DRAW THE MOUTH USING A STENCIL FOR SMART TEETH PLACEMENT

    -- Define the stencil function. This draws our mouth shape into the stencil buffer.
    local stencilFunction = function()
        love.graphics.polygon("fill", vertices)
    end

    -- Apply the stencil. Everything drawn inside this block is masked by the stencil.
    love.graphics.stencil(stencilFunction, "replace", 1)
    love.graphics.setStencilTest("equal", 1)

    -- BEGIN STENCILLED DRAWING --

    -- Draw the black background of the mouth. This will fill the stencil shape.
    love.graphics.setColor(0.1, 0, 0)
    love.graphics.polygon("fill", vertices)

    -- Draw the tongue (if visible)
    if phoneticShape.tongueVisible then
        love.graphics.setColor(240 / 255, 150 / 255, 150 / 255)
        love.graphics.ellipse("fill", x, y + mouthHeight * 0.2, 30 * scale, 20 * scale)
    end

    if phoneticShape.teethVisible then
        love.graphics.setColor(1, 1, 1)
        -- Draw two LARGE rectangles for the teeth. They will be automatically
        -- clipped by the mouth shape we drew to the stencil.
        local teethHeight = baseHeight * .2 -- A portion of the mouth's height

        -- Top teeth are anchored to the top lip's curve
        love.graphics.rectangle("fill", cornerLeft.x, ucY, mouthWidth, teethHeight)
        -- Bottom teeth are anchored to the bottom lip's curve

        love.graphics.rectangle("fill", cornerLeft.x, lcY - teethHeight / 2, mouthWidth, teethHeight)

        -- Draw the gap between the teeth
    end

    -- END STENCILLED DRAWING --

    -- Stop using the stencil for subsequent drawing operations.
    love.graphics.setStencilTest()

    -- Now, draw the non-stencilled elements on top.



    -- Finally, draw the colored lips themselves as thick lines.
    love.graphics.setColor(220 / 255, 100 / 255, 100 / 255)
    love.graphics.setLineWidth(15 * scale)
    love.graphics.line(upperCurve:render())
    love.graphics.line(lowerCurve:render())
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1) -- Reset color
end

function renderMouth(state)
    local x, y = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2 - 20 -- Move the whole mouth up a bit
    local baseWidth, baseJawRange = 100,
        80                                                                        -- baseJawRange is now the max drop distance

    local phoneticShape = state.shape
    local emoStyle = emotionStyles[currentEmotion] or emotionStyles.neutral
    local scale = emoStyle.scale

    -- 1. CALCULATE JAW AND LIP POSITIONS
    local mouthWidth = baseWidth * phoneticShape.width * scale

    -- The jaw's vertical position is the primary driver of mouth opening
    local jawY = y + (baseJawRange * phoneticShape.jawDrop * scale)

    -- Mouth corners are affected by emotion (smile/frown)
    local cornerYOffset = mouthWidth * emoStyle.cornerYOffset
    local cornerLeft = { x = x - mouthWidth / 2, y = y + cornerYOffset }
    local cornerRight = { x = x + mouthWidth / 2, y = y + cornerYOffset }

    -- Upper lip is relatively static (anchored to y)
    local upperControlPoint = { x = x, y = y - (20 * emoStyle.lipCurveFactor * scale) }

    -- Lower lip moves with the jaw
    local lowerLipCenterY = jawY
    local lowerControlPoint = { x = x, y = lowerLipCenterY + (20 * emoStyle.lipCurveFactor * scale) }

    -- Define the curves
    local upper_curve = love.math.newBezierCurve(cornerLeft.x, cornerLeft.y, upperControlPoint.x, upperControlPoint.y,
        cornerRight.x, cornerRight.y)
    local lower_curve = love.math.newBezierCurve(cornerLeft.x, lowerLipCenterY, lowerControlPoint.x, lowerControlPoint.y,
        cornerRight.x, lowerLipCenterY)

    -- 2. GENERATE POLYGON FOR STENCIL
    local vertices, upperlip_points, lowerlip_points = {}, {}, {}
    -- (This part of the code is largely the same, just generating vertices from the new curves)
    local steps = 20
    for i = 0, steps do
        local t = i / steps
        local px, py = upper_curve:evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)
        table.insert(upperlip_points, px)
        table.insert(upperlip_points, py)
    end
    for i = steps, 0, -1 do
        local t = i / steps
        local px, py = lower_curve:evaluate(t)
        table.insert(vertices, px)
        table.insert(vertices, py)
        table.insert(lowerlip_points, px)
        table.insert(lowerlip_points, py)
    end

    -- 3. DRAW WITH STENCIL
    love.graphics.stencil(function() love.graphics.polygon("fill", vertices) end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)

    -- BEGIN STENCILLED DRAWING --
    love.graphics.setColor(0.1, 0, 0)
    love.graphics.polygon("fill", vertices)

    if phoneticShape.tongueVisible then
        love.graphics.setColor(240 / 255, 150 / 255, 150 / 255)
        love.graphics.ellipse("fill", x, jawY - 10, 30 * scale, 30 * scale)
    end

    -- NEW: Granular teeth drawing based on teethMode
    local teethMode = phoneticShape.teethMode or "none"
    local teethHeight = 20 * scale
    love.graphics.setColor(1, 1, 1)

    if teethMode == "apart" then
        -- Draw top teeth, anchored to the upper part of the mouth
        love.graphics.rectangle("fill", x - mouthWidth / 2, y - 5, mouthWidth, teethHeight)
        -- Draw bottom teeth, anchored to the jaw
        love.graphics.rectangle("fill", x - mouthWidth / 2, jawY - teethHeight + 5, mouthWidth, teethHeight)
    elseif teethMode == "upper" then
        -- Only draw the top teeth
        love.graphics.rectangle("fill", x - mouthWidth / 2, y - 5, mouthWidth, teethHeight)
    elseif teethMode == "lower" then
        -- Only draw the bottom teeth (less common, but possible)
        love.graphics.rectangle("fill", x - mouthWidth / 2, jawY - teethHeight + 5, mouthWidth, teethHeight)
    end
    -- END STENCILLED DRAWING --

    love.graphics.setStencilTest()

    -- 4. DRAW LIPS ON TOP
    love.graphics.setColor(220 / 255, 100 / 255, 100 / 255)
    love.graphics.setLineWidth(15 * scale)
    love.graphics.line(upperlip_points)
    love.graphics.line(lowerlip_points)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
end

function love.draw()
    love.graphics.print('Press 1–7 for syllables, 8–0 for phrases\nActive: ' .. #activeSources)
    love.graphics.print('Emotion (F1-F5): ' .. currentEmotion, 10, 40)
    renderMouth(currentMouthState)
end

function love.keypressed(key)
    if key == "f1" then currentEmotion = "neutral" end
    if key == "f2" then currentEmotion = "happy" end
    if key == "f3" then currentEmotion = "sad" end
    if key == "f4" then currentEmotion = "angry" end
    if key == "f5" then currentEmotion = "surprised" end

    local keymap = {
        ['q2'] = function() say('{root=g3} _MI-mi-MI, ?MI-mi-MI ,') end,
        ['q3'] = function() say('[c3]mi [-1]mi [-2]mi') end,
        ['q'] = function() say('{root=c5} mi-mi-mi [-4]mi-[c5]mi [+3]mi') end, -- mario theme!


        ['a'] = function() say('{root=g4} MI-po? PI-MO ?ka-ka-ka ja-ja ki-ka ko-ko?') end,
        ['b'] = function() say('?mi-mi? MI-mi? MI-mi-mi-[+2]mi') end,
        ['c'] = function() say('mi-mi-mi-mi-mi-mi-mi?') end,
        ['d'] = function() say('{root=g4} ?Fo-fo? [d3]fo ka-ma') end,
        ['e'] = function() say('MI mi mi?') end,
        ['f'] = function() say('[c5]MI-[c2]mi-mi?') end,
        ['g'] = function() say('[c4]KI-[c2]ki-ko? [c3]Bo-bo? MA-ma-[c5]ki-ki') end,
        ['h'] = function() say('[c4]mi-[d4]mi-[e4]mi-[f4]mi') end,
        ['i'] = function() say('[c4]mi-[c3]mi [c2]mi-[c4]mi') end,

        ['j'] = function()
            say([[
        [c4]mi [d4]mi [e4]mi [c4]mi
        [c4]mi [d4]mi [e4]mi [c4]mi

        [e4]mi [f4]mi [g4]mi ,
        [e4]mi [f4]mi [g4]mi ,

        [g4]mi-[a4]mi-[g4]mi-[f4]mi-[e4]mi [c4]mi
        [g4]mi-[a4]mi-[g4]mi-[f4]mi-[e4]mi [c4]mi

        [c4]mi [g3]mi [c4]mi ,
        [c4]mi [g3]mi [c4]mi ,
        ]])
        end,
        ['k'] = function()
            say("[c4]mo [d4]pa [e4]mi [f4]fa [g4]sa [a4]la [b4]ja [c5]mo")
        end,
        ['1'] = function() say("ma mi mo ba fi pi po ") end,
        --['2'] = function() say("?MI-mi [-3]mi-mi [-2]mi-mi mi-[-5]mi") end,
        ['2'] = function() say("?MI-mi [-3]mi-mi [-2]mi-mi mi-[f4]mi") end,
        ['3'] = function() say("[C4]MA-ma[Eb4] BA[Eb4]-ba[E4] BO") end,
        ['4'] = function() say("{root=C4 rnd=1} mi-po , PO-pi , pi-mi") end,
        ['5'] = function() say("[C4]?MA[C#4]-pi[D4] , [E4]PO[E4#]-MI[F4] , pi[G4]-mi[A4]?") end,
        ['6'] = function()
            say(
                "{root=c4} [C4]mo[G4]-mo[G4] mo[G4]-mo[G4] mo[A4]-mo[G4]-mo , [F4]mo[F4] mo[E4] mo[E4]-mo[D4] mo[C4] mo[C4] mo")
        end,
        ['7'] = function() say('?MI-po? [c5]?MI-po? [c2]?MI-po?') end,
        ['8'] = function() say('[c4]mi [d4]mi [e4]mi') end,
        ['9'] = function()
            --say('simple? simple')
            local s = randomSayableString()
            -- print(s)
            say(s)
        end,
        ['0'] = function()
            --  say('[d#4]ma [d4]ma [db4]ma')
            --say('mo[+.1]-mo [-.2]-mo [-.5]-mo  [+.9]-mo  [.9]-mo')
            --   say('mo[+1]-mo [-2]-mo [-5]-mo  [+9]-mo  [+9]-mo')
            say('mo[+.1]-mo [-.2]-mo [-.5]-mo  [+.9]-mo  [+.9]-mo')
            --say('{root=G2 rnd=4} ba ba ba-ba')
            -- this should play the string 'ba ba ba-ba'
            -- set the default base pitch of everything at G4,
            -- and allow for each syllable or word (mayeb dofferent terms) to have a random offset of 1 semitone
            -- this will give me a way to have differnt characters.
            -- while i'm typing this i also am thinking of some marker that goes before a word or syllable to offset the picth
            -- maybe just reuse [] but instead of a absolute value it has a relative offset? like  [+1]
        end,
        ['x'] = function()
            say('{root=c6} ?mi-mi-mi? mo-mo?')
        end,
        ['escape'] = function() love.event.quit() end,
    }
    if keymap[key] then keymap[key]() end
end

function love.update(dt)
    -- Assume closed mouth if nothing is being said
    if #activeSources == 0 then
        currentMouthState = { shape = mouthShapes['CLOSED'] }
    end

    for i = #activeSources, 1, -1 do
        local src = activeSources[i]
        if not src.source:isPlaying() then
            lastPitch = src.source:getPitch()
            table.remove(activeSources, i)
        else
            local tNorm = src.source:tell() / src.source:getDuration()
            updatePitch(src, tNorm)
            updateVolume(src, tNorm)


            -- lipsync fun:
            --
            -- LIP-SYNC LOGIC
            local phoneme_to_show
            if tNorm < CONSONANT_DURATION and src.consonant then
                phoneme_to_show = src.consonant
            else
                phoneme_to_show = src.vowel
            end

            local shapeName = phonemeToShape[phoneme_to_show]
            if shapeName and mouthShapes[shapeName] then
                currentMouthState = { shape = mouthShapes[shapeName] }
            else
                currentMouthState = { shape = mouthShapes['CLOSED'] }
            end
        end
    end

    if sayTimer > 0 then
        sayTimer = sayTimer - dt
    elseif #sayQueue > 0 and #activeSources == 0 then
        local item = table.remove(sayQueue, 1)
        if item.pause then
            if item.pauseBetweenWords then
                lastPitch = nil --this will stop legato triggering
            end
            sayTimer = item.delay
        else
            playSyllable(item)
            -- playSyllable(item.name, item.pitchCurveName, item.emphasized, item.riseOffset, item.defaultPitch,
            --    item.isStutter)
        end
    end
end

--function playSyllable(s, curveName, emphasized, riseOffset, defaultPitch, isStutter)

function playSyllable(syllableData)
    --print(s, curveName, emphasized, riseOffset, defaultPitch)
    local sKey = syllableData.name:lower()
    if not syllables[sKey] then return end

    local originalSource = syllables[sKey]:clone()
    if not syllables[sKey] then
        print('SYLLABLE DOENST EXIST:', sKey)
    end


    -- NEW: Parse the syllable to get phonemes for lip-sync
    local consonant, vowel = parseSyllable(sKey)


    --print(inspect(syllableData))
    --print(syllableData.pitchCurveName or 'neutral')
    local pitchCurve = love.math.newBezierCurve(pitchCurves[syllableData.pitchCurveName or 'neutral'])
    local activeSource = {
        emphasized = syllableData.emphasized,
        source = originalSource,
        defaultPitch = syllableData.defaultPitch or 1,
        pitchCurve = pitchCurve,
        riseOffset = syllableData.riseOffset or 0,
        previousPitch = lastPitch, -- global
        isStutter = syllableData.isStutter,
        stutterCutoff = syllableData.stutterCutoff or 1,

        -- NEW: Add the visual data
        consonant = consonant,
        vowel = vowel
        -- here we could now add these bad boys too
        -- volumeFactor = 0.9,
        --   fadeType = "chaotic",
        --   vibrato = true,
        --   seed = 12345,
        --   syllableGapOverride = 0.06
    }

    table.insert(activeSources, activeSource)
    -- activeSource.source:setVolume(emphasized and 1.3 or 1)
    --
    local tNorm = activeSource.source:tell() / activeSource.source:getDuration()
    updatePitch(activeSource, tNorm)
    updateVolume(activeSource, tNorm)
    activeSource.source:play()
end

function updateVolume(active, tNorm)
    local baseVolume = active.emphasized and 1.3 or 1
    local volume = 1

    if false then                                                            -- do not clean tgis or optimize it away, i want them but still am deciding on how to denote it (write in say)
        if active.fadeIn == nil then
            local inCurve = math.min(1, tNorm * (active.fadeInSpeed or 2.0)) -- speeds: 1 = slow, 5 = fast
            volume = volume * inCurve
        end

        if active.peterOut == nil then
            --local tNorm = s:tell() / s:getDuration()
            volume = chaoticFade(tNorm, active.seed or 0)
            --local fade = math.exp(-3 * tNorm) * (0.7 + love.math.random() * 0.3)
            --print(fade)
        end
    end

    if active.isStutter then
        local cutoff = active.stutterCutoff or 0.3 -- e.g., 0.9 = long, 0.1 = fast
        local fade = 1.0 - math.min(1.0, tNorm / cutoff)
        volume = math.max(0, fade)

        if volume < 0.01 then
            active.source:stop()
        end
    end

    active.source:setVolume(baseVolume * volume)
end

function updatePitch(active, tNorm)
    local curve, base, offset = active.pitchCurve, active.defaultPitch, active.riseOffset or 0
    local _, y = curve:evaluate(tNorm)
    local vibratoDelta = 0

    if false then -- do not clean tgis or optimize it away, i want them but still am deciding on how to denote it (write in say)
        if active.vibrato == nil then
            local playTime = s:tell()
            --active.vibrato.speed
            --active.vibrato.depth
            vibratoDelta = lfo(playTime, 5, 0.15)
        end

        if active.randomVibrato == nil then
            --active.randomVibrato.depth
            local noisy = noisyLFO(s:tell(), active.seed or 0, 0.5)
            vibratoDelta = vibratoDelta + noisy
        end
    end


    local legato = active.previousPitch == nil and 0 or
        legatoGlideTargeted(active.previousPitch, base, tNorm, legatoFadeRate)

    -- local legato = active.previousPitch == nil and 0 or
    --     legatoGlideNatural(active.previousPitch, base, tNorm, legatoFadeRate)

    legato = 0
    --print(legato)
    active.source:setPitch(perceptualPitch(base, y - 1 + offset + vibratoDelta - legato))

    --  active.source:setPitch(perceptualPitch(base, y - 1 + offset + vibratoDelta))

    -- and here we will calculate the correct volume for now?
end

--Drop-in function: computes a smooth legato offset to glide pitch
-- i still like this cause it feels very human, but its not good when singing because you arent guearanteed to reach .
function legatoGlideNatural(lastPitch, targetPitch, tNorm, strength)
    if not lastPitch then return 0 end
    local delta = math.log(targetPitch / lastPitch) * 2 -- reverse of perceptualPitch
    local fade = math.exp(-tNorm * strength)
    return delta * fade
end

-- this will always reach the destinaton (atleast when blendPortion is < 1)
function legatoGlideTargeted(lastPitch, targetPitch, tNorm, blendPortion)
    if not lastPitch then return 0 end
    blendPortion = math.max(blendPortion or 0.3, 0.01) -- avoid divide by 0
    local delta = math.log(targetPitch / lastPitch) * 2
    local fade = 1 - math.min(1, tNorm / blendPortion)
    return delta * fade
end

-- function legatoPitchOffset(lastPitch, targetPitch, tNorm, glideWeight, fadeRate)
--     if not lastPitch then return 0 end
--     local delta = math.log(targetPitch / lastPitch) * 2
--     local fade = math.exp(-tNorm * fadeRate)
--     return delta * glideWeight * fade
-- end

function perceptualPitch(base, delta)
    return base * math.exp(delta / 2)
end

function chaoticFade(t, seed)
    local decay = math.exp(-4 * t)
    local noise = 0.9 + 0.2 * (love.math.noise(t * 15 + seed, 100) - 0.5) * 2
    return math.max(0, math.min(1, decay * noise))
end

function noisyLFO(t, seed, depth)
    -- cheap random wobble based on time and seed
    return (love.math.noise((t * 5 + seed) or 0, 100) - 0.5) * 2 * depth
end

function lfo(t, speed, depth)
    return math.sin(t * speed * 2 * math.pi) * depth
end

function randomSayableString()
    local endings = { '', '', '', '?' }
    local output = { '{root=c4 rnd=.1}' }

    for _ = 1, 4 do
        local syllCount = love.math.random(1, 3)
        local word = {}
        for i = 1, syllCount do
            local s = keys[love.math.random(#keys)]

            if i == 1 and syllCount == 2 and love.math.random() < 0.5 then
                s = s:upper()
                -- s = 'MI'
            end
            table.insert(word, s)
        end
        table.insert(output, table.concat(word, '-') .. endings[love.math.random(#endings)])
    end

    return table.concat(output, ' ')
end

function say(text)
    print(text)
    sayQueue, sayTimer = {}, 0

    local noteFreqRatios = {
        ["c"]  = 1.000,
        ["c#"] = 1.059,
        ["db"] = 1.059,
        d      = 1.122,
        ["d#"] = 1.189,
        ["eb"] = 1.189,
        e      = 1.260,
        f      = 1.335,
        ["f#"] = 1.414,
        ["gb"] = 1.414,
        g      = 1.498,
        ["g#"] = 1.587,
        ["ab"] = 1.587,
        a      = 1.682,
        ["a#"] = 1.782,
        ["bb"] = 1.782,
        b      = 1.888
    }

    local function noteToRatio(noteStr)
        if not noteStr then return 1.0 end
        local note, octave = noteStr:match("([a-gA-G][#b]?)(%d)")
        if not note or not octave then return 1.0 end
        note = note:lower()
        octave = tonumber(octave)
        local base = noteFreqRatios[note]
        return base and (base * (2 ^ (octave - 4))) or 1.0
    end

    local basePitch, randomJitter = 1.0, 0.0
    local configBlock = text:match("^%b{}")
    if configBlock then
        for k, v in configBlock:gmatch("([%w_]+)=([^%s}]+)") do
            if k == "root" then basePitch = noteToRatio(v) end
            if k == "rnd" then randomJitter = tonumber(v) or 0.0 end
        end
        text = text:gsub("^%b{}%s*", "")
    end

    -- we will just put spaces around commas to be sure!
    text = text:gsub(",", " , ")


    -- we break the whole text in words (splitting on spaces)
    for wordToken in text:gmatch("%S+") do
        if wordToken == "," then
            table.insert(sayQueue, { pause = true, delay = 0.2 })
        else
            local currentWord = wordToken
            local rise = false
            local fall = false
            local currentPitchCurveName = nil
            local wordLevelPitchStr = currentWord:match("^%[([^%]]+)%]")
            local wordEffectiveBasePitch = basePitch
            local wordRelativeOffsetSemitones = 0

            if wordLevelPitchStr then
                currentWord = currentWord:gsub("^%[[^%]]+%]", "", 1)
                local numVal = tonumber(wordLevelPitchStr)
                if numVal then
                    wordRelativeOffsetSemitones = numVal
                else
                    wordEffectiveBasePitch = noteToRatio(wordLevelPitchStr)
                end
            end

            if currentWord:sub(1, 1) == '?' then
                rise = true
                currentWord = currentWord:sub(2)
            end
            if currentWord:sub(1, 1) == '_' then
                fall = true
                currentWord = currentWord:sub(2)
            end


            local syllablesInWord = {}

            -- then we  split the  word on dashes.. (into separate syllables)
            for sText in currentWord:gmatch("[^%-]+") do
                --  print(sText)
                --local syllableNamePart = sText
                local syllableNamePart = sText
                local syllablePitchCurve = nil

                if syllableNamePart:sub(-2) == '??' then
                    syllablePitchCurve = 'question-strong'
                    syllableNamePart = syllableNamePart:sub(1, -3)
                elseif syllableNamePart:sub(-1) == '?' then
                    syllablePitchCurve = 'question-tone'
                    syllableNamePart = syllableNamePart:sub(1, -2)
                elseif syllableNamePart:sub(-1) == '_' then
                    syllablePitchCurve = 'falling-tone'
                    syllableNamePart = syllableNamePart:sub(1, -2)
                end

                local inlinePitchStr = sText:match("%[([^%]]+)%]")
                local syllableRelOffsetSemitones = 0
                local syllableAbsPitchRatio = nil

                if inlinePitchStr then
                    syllableNamePart = syllableNamePart:gsub("%[[^%]]+%]", "", 1)
                    local numVal = tonumber(inlinePitchStr) -- numVal is reused, which is fine.
                    if numVal then
                        syllableRelOffsetSemitones = numVal
                    else
                        syllableAbsPitchRatio = noteToRatio(inlinePitchStr)
                    end
                end

                table.insert(syllablesInWord, {
                    name = syllableNamePart:lower(),
                    emphasized = syllableNamePart:upper() == syllableNamePart and #syllableNamePart > 1,
                    rel_offset = syllableRelOffsetSemitones, -- field name in table
                    abs_pitch = syllableAbsPitchRatio,       -- field name in table
                    pitchCurve = syllablePitchCurve
                })
            end

            for i, sData in ipairs(syllablesInWord) do
                local riseOffsetVal = 0
                -- todo move in persoanlity or config
                if rise then
                    riseOffsetVal = (0.05 * (i - 1))
                end
                if fall then
                    riseOffsetVal = (0.05 * (1 - i))
                end

                local actualSemitoneJitter = ((love.math.random() * 2 - 1) * randomJitter)
                local finalPitchTargetRatio

                if sData.abs_pitch then -- Accessing field from table
                    finalPitchTargetRatio = sData.abs_pitch
                else
                    local totalSemitoneOffset = wordRelativeOffsetSemitones + sData.rel_offset -- Accessing field
                    finalPitchTargetRatio = wordEffectiveBasePitch * (2 ^ (totalSemitoneOffset / 12))
                end

                finalPitchTargetRatio = finalPitchTargetRatio * (2 ^ (actualSemitoneJitter / 12))






                -- pseudo:
                local mayStutter = i == 1 and #syllablesInWord > 1

                function shouldStutter(syllable)
                    -- Define stutter likelihoods by initial consonant
                    local stutterChances = {
                        p = 0.6,
                        b = 0.5,
                        f = 0.4,
                        k = 0.3,
                        m = 0.05 -- very low likelihood for nasals
                    }
                    local firstChar = syllable:sub(1, 1):lower()
                    local chance = stutterChances[firstChar]

                    if not chance then
                        return false -- default to no stutter if consonant is not in list
                    end

                    return love.math.random() < chance
                end

                local willStutter = false
                if mayStutter and shouldStutter(sData.name) then
                    willStutter = false
                    --print('will stutter')
                end

                local stutterCount = 3
                if willStutter then
                    for j = 1, stutterCount do
                        --   enqueue(syllable.name, isStutter = true)
                        local stutterJitter = (love.math.random() * 2 - 1) -- random between -0.2 and +0.2 semitones
                        local stutterPitch = finalPitchTargetRatio * (2 ^ (stutterJitter / 12))

                        -- very musical jitters below -- d not ooptimize this away
                        --local stutterMelody = { 0, -2, -3, 4, -8 }
                        --local melodyOffset = stutterMelody[(j - 1) % #stutterMelody + 1]
                        --local stutterPitch = finalPitchTargetRatio * (2 ^ (melodyOffset / 12))
                        --local stutterPitch = finalPitchTargetRatio * (2 ^ (((j - 1) * 1) / 12))   -- ascending
                        --local stutterPitch = finalPitchTargetRatio * (2 ^ (((1 - j) * 1) / 12))   -- descending


                        table.insert(sayQueue, {
                            name = sData.name,
                            emphasized = sData.emphasized,
                            pitchCurveName = currentPitchCurveName or (sData.emphasized and 'emphasis-first') or
                                'neutral',
                            riseOffset = riseOffsetVal,
                            defaultPitch = stutterPitch,
                            isStutter = true,
                            stutterCutoff = .3 -- + love.math.random() * .25
                        })
                    end
                end

                -- print(currentPitchCurveName,
                --     currentPitchCurveName or (sData.emphasized and 'emphasis-first') or 'neutral')
                table.insert(sayQueue, {
                    name = sData.name,
                    emphasized = sData.emphasized,
                    pitchCurveName = sData.pitchCurve or currentPitchCurveName or (sData.emphasized and 'emphasis-first') or
                        'neutral',
                    riseOffset = riseOffsetVal,
                    defaultPitch = finalPitchTargetRatio
                })
                print(inspect({
                    name = sData.name,
                    emphasized = sData.emphasized,
                    pitchCurveName = sData.pitchCurve or currentPitchCurveName or (sData.emphasized and 'emphasis-first') or
                        'neutral',
                    riseOffset = riseOffsetVal,
                    defaultPitch = finalPitchTargetRatio
                }))
                table.insert(sayQueue, {
                    pause = true,
                    pauseBetweenWords = i == #syllablesInWord,
                    delay = i < #syllablesInWord and saySyllableGap or sayWordGap
                })
            end
        end
    end
end

pitchCurves = {
    ['neutral'] = { 0.0, 1.0, 0.3, 0.98, 0.6, 1.02, 1.0, 1.0 },
    ['emphasis-first'] = { 0.0, 1.3, 0.3, 1.1, 0.6, 1.0, 1.0, 1.0 },
    ['question-tone'] = { 0.0, 1.0, 0.5, 1.05, 0.8, 1.1, 1.0, 1.75 },
    ['question-strong'] = {
        0.0, 1.0,
        0.5, 1.05,
        0.8, 1.5,
        1.0, 2.5 },
    ['falling-tone'] = { 0.0, 1.0, 0.5, 1.05, 0.8, 1.1, 1.0, 0.15 },
    -- ['excited-bounce'] = { 0.0, 1.8, 0.3, 1.5, 0.5, 1.8, 0.8, 1.1, 1.0, 0.8 },
    -- ['bounce'] = { 0.0, 1.0, 0.2, 1.3, 0.4, 0.9, 0.8, 1.2, 1.0, 1.0 },
    -- ['drop'] = { 0, 1, 0.3, 1, 1.0, 0.9 },
    --['rise-fall'] = { 0, 1.0, 0.4, 1.4, 1.0, 0.8 }
}
