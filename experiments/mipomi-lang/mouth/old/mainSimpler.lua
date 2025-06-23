function love.load()
    numPoints = 8

    -- Emotion base shapes (each is 8 points)
    shapes = {
        neutral = {
            { x = -1.0, y = 0.0 }, { x = -0.5, y = -0.25 }, { x = 0.0, y = -0.5 }, { x = 0.5, y = -0.25 }, { x = 1.0, y = 0.0 },
            { x = 0.5,  y = 0.25 }, { x = 0.0, y = 0.5 }, { x = -0.5, y = 0.25 },
        },
        sad = {
            { x = -1.0, y = 0.5 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = 0.1 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.5 },
            { x = 0.75, y = 0.5 }, { x = 0.0, y = 0.3 }, { x = -0.75, y = 0.5 },
        },
        happy = {
            { x = -1.0, y = -0.5 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = -0.2 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = -0.5 },
            { x = 0.75, y = 0.6 }, { x = 0.0, y = 0.8 }, { x = -0.75, y = 0.6 },
        },
        surprised = {
            { x = -1.0, y = 0.0 }, { x = -0.5, y = -0.3 }, { x = 0.0, y = -0.3 }, { x = 0.5, y = -0.3 }, { x = 1.0, y = 0.0 },
            { x = 0.5,  y = 0.7 }, { x = 0.0, y = 0.8 }, { x = -0.5, y = 0.7 },
        },
        angry = {
            { x = -1.0, y = 0.0 }, { x = -0.5, y = -0.2 }, { x = 0.0, y = -0.6 }, { x = 0.5, y = -0.2 }, { x = 1.0, y = 0.0 },
            { x = 0.75, y = 0.25 }, { x = 0.0, y = 0.5 }, { x = -0.75, y = 0.25 },
        },
    }


    --[[
    good looking other shapes
    surprised2 = {
        { x = -1.0, y = 0.0 }, { x = -0.5, y = -0.1 }, { x = 0.0, y = -0.3 }, { x = 0.5, y = -0.1 }, { x = 1.0, y = 0.0 },
        { x = 0.5,  y = 0.7 }, { x = 0.0, y = 0.8 }, { x = -0.5, y = 0.7 },
    },
    ]] --



    -- Simple phoneme modifiers (scale only)
    phonemeShapes = {
        ['A_I'] = { width = 1.2, height = 0.8 },
        ['OU_W_Q'] = { width = 0.4, height = 0.4 },
        --   ['CDEGK_NRS'] = { width = 1.0, height = 0.4 },
        ['TH_L'] = { width = 0.8, height = 0.5 },
        ['F_V'] = { width = 1.0, height = 0.3 },
        ['L_OU'] = { width = 0.5, height = 0.6 },
        ['O_U_AGH'] = { width = 0.7, height = 0.7 },
        --  ['UGH'] = { width = 1.1, height = 0.7 },
        ['M_B_P'] = { width = 0.9, height = 0.15 },
        ['MMM'] = { width = 0.9, height = 0.1 },
        ['CLOSED'] = { width = 1.0, height = 0.05 },
    }

    --phonemeKeys = { 'CLOSED', 'A_I', 'OU_W_Q', 'CDEGK_NRS', 'TH_L', 'F_V', 'L_OU', 'O_U_AGH', 'UGH', 'M_B_P', 'MMM' }
    phonemeKeys = { 'CLOSED', 'A_I', 'OU_W_Q', 'TH_L', 'F_V', 'L_OU', 'O_U_AGH', 'M_B_P', 'MMM' }
    -- Start neutral
    currentEmotion = "neutral"
    currentPhonemeKey = "CLOSED"
end

function getEmotionShape()
    return shapes[currentEmotion] or shapes.neutral
end

function getPhonemeMod()
    return phonemeShapes[currentPhonemeKey] or { width = 1.0, height = 1.0 }
end

function getMouthShape()
    local shape = getEmotionShape()
    local mod = getPhonemeMod()

    local scaled = {}
    for _, pt in ipairs(shape) do
        table.insert(scaled, {
            x = pt.x * 80 * mod.width,
            y = pt.y * 80 * mod.height,
        })
    end
    return scaled
end

function love.update(dt)
    -- Keys 1–9 = phonemes
    for i = 1, #phonemeKeys do
        if love.keyboard.isDown(tostring(i)) then
            currentPhonemeKey = phonemeKeys[i]
        end
    end

    -- Emotions with keys (n = neutral, h = happy, s = sad, a = angry, u = surprised)
    if love.keyboard.isDown("n") then currentEmotion = "neutral" end
    if love.keyboard.isDown("h") then currentEmotion = "happy" end
    if love.keyboard.isDown("s") then currentEmotion = "sad" end
    if love.keyboard.isDown("a") then currentEmotion = "angry" end
    if love.keyboard.isDown("u") then currentEmotion = "surprised" end
    if love.keyboard.isDown("escape") then love.event.quit() end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(400, 300)

    -- Draw mouth
    local s = getMouthShape()
    love.graphics.setColor(1, 1, 1)
    for i = 1, numPoints do
        local a = s[i]
        local b = s[(i % numPoints) + 1]
        love.graphics.line(a.x, a.y, b.x, b.y)
    end
    for _, pt in ipairs(s) do
        love.graphics.circle("fill", pt.x, pt.y, 3)
    end

    local up = { s[1].x, s[1].y, s[2].x, s[2].y, s[2].x, s[2].y, s[3].x, s[3].y, s[3].x, s[3].y, s[4].x, s[4].y, s[4].x,
        s[4].y, s[5].x, s[5].y }
    local down = { s[5].x, s[5].y, s[6].x, s[6].y, s[6].x, s[6].y, s[7].x, s[7].y, s[7].x, s[7].y, s[8].x, s[8].y, s[8]
        .x, s[8].y, s[1].x, s[1].y }
    love.graphics.setLineWidth(5)
    love.graphics.line(love.math.newBezierCurve(up):render())
    love.graphics.line(love.math.newBezierCurve(down):render())
    love.graphics.setLineWidth(1)

    love.graphics.pop()

    -- Labels
    love.graphics.print("Emotion: " .. currentEmotion, 50, 50)
    love.graphics.print("Phoneme: " .. currentPhonemeKey, 50, 70)
    love.graphics.print("Press N/H/S/A/U for emotions", 50, 100)
    love.graphics.print("Press 1–9 for phonemes", 50, 120)
end
