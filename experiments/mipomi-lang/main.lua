local MouthClass = require 'mouth.mouth'
local mouth = MouthClass.new()
local inspect = require 'inspect'

pitchCurves = {
    ['neutral'] = { 0.0, 1.0, 0.3, 0.98, 0.6, 1.02, 1.0, 1.0 },
    ['emphasis'] = { 0.0, 1.1, 0.3, 1.3, 0.6, 1.0, 1.0, 1.0 },
    ['rise'] = { 0.0, 1.0, 0.5, 1.05, 0.8, 1.1, 1.0, 1.25 },
    ['rise-emphasis'] = { 0.0, 1.1, 0.3, 1.25, 0.6, 1.1, 1.0, 1.4 },
    ['fall'] = { 0.0, 1.0, 0.4, 1.0, 0.7, 0.95, 1.0, 0.85 },
    ['fall-emphasis'] = { 0.0, 1.1, 0.3, 1.2, 0.6, 1.0, 1.0, 0.8 }
}

local noteFreqRatios = {
    ["c"]  = 1.000,
    ["c#"] = 1.059,
    ["db"] = 1.059,
    ["d"]  = 1.122,
    ["d#"] = 1.189,
    ["eb"] = 1.189,
    ["e"]  = 1.260,
    ["f"]  = 1.335,
    ["f#"] = 1.414,
    ["gb"] = 1.414,
    ["g"]  = 1.498,
    ["g#"] = 1.587,
    ["ab"] = 1.587,
    ["a"]  = 1.682,
    ["a#"] = 1.782,
    ["bb"] = 1.782,
    ["b"]  = 1.888
}

local personalities = {
    robotic = {
        vibrato = { type = 1, freq = 0, depth = 0 },
        legato = { type = 2, amount = 0.1 },
        volume = 0.9,
        vdelta = 0,
        rndp = 0.0,
        rndv = 0.0,
        swing = { 1.0, 1.0 },
        pause = { syllable = 0.05, word = 0.2, comma = 0.1 },
    },
    slowlearner = {
        vibrato = { type = 1, freq = 2, depth = 0.4 },
        legato = { type = 1, amount = 0.2 },
        volume = 1.0,
        vdelta = 0.2,
        rndp = 0.2,
        rndv = 0.05,
        swing = { 1.3, 1.3 },
        pause = { syllable = 0.3, word = 0.8, comma = 0.4 },
        stress = { 1, 2 }
    },
    poopy = {
        vibrato = { type = 2, freq = 6, depth = 0.8, seed = 99 },
        legato = { type = 2, amount = 3 },
        volume = 0.7,
        vdelta = -0.2,
        rndp = 1.5,
        rndv = 0.2,
        swing = { 1.2, 1.3 },
        stress = { 2, 2 }, -- back-heavy emphasis (poopy logic)
        pause = { syllable = 0.15, word = 0.45, comma = 0.25 },
    },
    sleepy = {
        vibrato = { type = 1, freq = 1.5, depth = 0.2 },
        legato = { type = 1, amount = 2 },
        volume = 0.8,
        vdelta = -0.3,
        rndp = 0.1,
        rndv = 0.05,
        swing = { 0.9, 1.1 },
        stress = { 1, 4 }, -- subtle, infrequent emphasis
        pause = { syllable = 0.4, word = 1.2, comma = 0.6 },
    },
    party = {
        vibrato = { type = 2, freq = 8, depth = 0.6, seed = 7 },
        legato = { type = 1, amount = 0.3 },
        volume = 1,
        vdelta = 0.2,
        rndp = 2.0,
        rndv = 0.2,
        swing = { 0.6, 1.4 },
        stress = { 1, 2 }, -- high energy, lots of emphasis
        pause = { syllable = 0.1, word = 0.35, comma = 0.2 },
    },
    simple = {
        swing = { .3, 1.7 },
        stress = { 1, 3 }
    },
    deadpan = {
        vibrato = { type = 1, freq = 0.5, depth = 0 },
        legato = { type = 1, amount = 0.1 },
        volume = 1.0,
        vdelta = 0,
        rndp = 0,
        rndv = 0,
        swing = { 1.0, 1.0 },
        stress = { 2, 99 },
        pause = { syllable = 0.2, word = 0.5, comma = 0.4 },
    }
}

function noteToRatio(noteStr)
    if not noteStr then return 1.0 end
    local note, octave = noteStr:match("([a-gA-G][#b]?)(%d)")
    if not note or not octave then return 1.0 end
    note = note:lower()
    octave = tonumber(octave)
    local base = noteFreqRatios[note]
    return base and (base * (2 ^ (octave - 4))) or 1.0
end

local function semitonesToRatio(semi)
    return 2 ^ (semi / 12)
end
local function log2(x)
    return math.log(x) / math.log(2)
end
local function ratioToSemitones(ratio)
    return log2(ratio) * 12
end


function love.load()
    -- syllableKeys = { 'ba', 'bi', 'bo', 'ma', 'mi', 'mo', 'pa', 'pi', 'po', 'fa', 'fi', 'fo', 'ka', 'ki', 'ko', 'wa', 'wi',
    --     'wo' }
    syllableKeys = { 'ma', 'mi', 'mo', 'ba', 'bi', 'bo', 'pa', 'pi', 'po', 'fa', 'fi', 'fo', 'ka', 'ki', 'ko',
        'la', 'li', 'lo', 'ta', 'ti', 'to', 'ja', 'ji', 'jo', 'na', 'ni', 'no', 'da', 'di', 'do', 'sa', 'si', 'so', 'ha',
        'hi', 'ho', 'wa', 'wi', 'wo', }
    syllableKeys = { 'ma', 'mi', 'mo', 'ba', 'bi', 'bo', 'pa', 'pi', 'po', 'fa', 'fi', 'fo', 'ka', 'ki', 'ko',
        'la', 'li', 'lo', 'ta', 'ti', 'to', 'ja', 'ji', 'jo', 'na', 'ni', 'da', 'di', 'do', 'sa', 'si', 'so', 'ha',
        'hi', 'ho', 'wa', 'wi', 'wo', }

    syllableSources = {}

    pause = false
    -- the 4 variable below should live on a 'speaker'
    -- that way i can have multipe people conversing.
    -- we do this laters
    -- activeSources = {}
    -- sayQueue = {}
    -- pauseTimer = 0
    -- lastPitch = nil -- used by slide


    for _, key in ipairs(syllableKeys) do
        syllableSources[key] = love.audio.newSource("samples-nikki/" .. key .. ".ogg", "static")
    end

    sfxSources = {}
    sfxSources['huh'] = love.audio.newSource("samples-fx/" .. 'huh' .. ".wav", "static")
    sfxSources['humup1'] = love.audio.newSource("samples-fx/" .. 'humup1' .. ".wav", "static")
    sfxSources['humdown1'] = love.audio.newSource("samples-fx/" .. 'humdown1' .. ".wav", "static")
    sfxSources['humdown2'] = love.audio.newSource("samples-fx/" .. 'humdown2' .. ".wav", "static")
    sfxSources['humdown3'] = love.audio.newSource("samples-fx/" .. 'humdown3' .. ".wav", "static")
    sfxSources['humdown4'] = love.audio.newSource("samples-fx/" .. 'humdown4' .. ".wav", "static")
    --sfxSources['humup2'] = love.audio.newSource("samples-fx/" .. 'humup2' .. ".wav", "static")
    --sfxSources['humup3'] = love.audio.newSource("samples-fx/" .. 'humup3' .. ".wav", "static")

    sfxMouthShapes = {
        huh = { consonant = "h", vowel = "o" },
        humup1 = { consonant = "m", vowel = "i" },
        humdown1 = { consonant = "m", vowel = "mmm" },
        humdown2 = { consonant = "m", vowel = "frown" },
        humdown3 = { consonant = "m", vowel = "t" },
        humdown4 = { consonant = "m", vowel = "t" },
    }


    love.graphics.setFont(love.graphics.newFont('font.ttf', 64))

    -- eyeOpen = true
    -- blinkTimer = 2 + math.random() * 2 -- time until next blink
    -- blinkDuration = 0.1                -- duration eyes stay closed
    -- blinkCooldown = 0                  -- when blinking is happening

    speakers2 = {
        {
            name = "bob",
            mouth = MouthClass.new(),
            activeSources = {},
            sayQueue = {},
            lastPitch = nil,
            pauseTimer = 0,
            --personality = personalities.robotic,
            pos = { x = 200, y = 300 },                 -- for rendering
            scale = { x = 1.5, y = 1.5 },               -- for rendering
            color = { 255 / 255, 172 / 255, 28 / 255 }, -- for rendering
            eyeSpace = 10,
            eyeOpen = true,
            blinkTimer = 2.0,
            blinkCooldown = 0,
            blinkDuration = 0.1,
            root = 'c5',
            mouthIdle = 'mmm',
            -- optionally: currentPhrase, speaking, etc.
        }
    }
    speakers = {
        {
            name = "bob",
            mouth = MouthClass.new(),
            activeSources = {},
            sayQueue = {},
            lastPitch = nil,
            pauseTimer = 0,
            personality = personalities.sleepy,
            pos = { x = 200, y = 300 },                 -- for rendering
            scale = { x = 1.5, y = 1.5 },               -- for rendering
            color = { 255 / 255, 172 / 255, 28 / 255 }, -- for rendering
            eyeSpace = 10,
            eyeOpen = true,
            blinkTimer = 2.0,
            blinkCooldown = 0,
            blinkDuration = 0.1,
            root = 'c5',
            mouthIdle = 'mmm',
            -- optionally: currentPhrase, speaking, etc.
        }, {
        name = "bob",
        mouth = MouthClass.new(),
        activeSources = {},
        sayQueue = {},
        lastPitch = nil,
        pauseTimer = 0,
        personality = personalities.party,
        pos = { x = 850, y = 500 },                 -- for rendering
        scale = { x = -1.2, y = 1.2 },              -- for rendering
        color = { 124 / 255, 200 / 255, 28 / 255 }, -- for rendering
        eyeSpace = 0,
        eyeOpen = true,
        blinkTimer = 2.0,
        blinkCooldown = 0,
        blinkDuration = 0.1,
        root = 'e4',
        mouthIdle = 'mmm',
        -- optionally: currentPhrase, speaking, etc.
    }
    }
end

function drawPitchCurve(instance, originX, originY, size)
    local curve = instance.pitchCurve
    local points = {}
    for x = 0, size do
        local _, y = curve:evaluate(x / size)
        table.insert(points, originX + x)
        table.insert(points, originY + (size / 2) - (y * size))
    end
    love.graphics.setColor(1, 1, 1, .1)
    love.graphics.rectangle('fill', originX, originY - size, size, size)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(points)

    local t = instance.source:tell() / instance.source:getDuration()
    local _, y = curve:evaluate(t)
    love.graphics.circle('fill', originX + t * size, originY - size / 2, 5)
end

local texture = love.graphics.newImage("type7.png")
local texture2 = love.graphics.newImage("type8.png")

function love.draw()
    if true then
        for i = 1, #speakers do
            local speaker = speakers[i]
            for _, instance in ipairs(speaker.activeSources) do
                local name = instance.emphasized and instance.name:upper() or instance.name
                local post = (instance.rise and '?') or (instance.fall and '_') or ''
                love.graphics.print(name .. post, 500, 100)
                drawPitchCurve(instance, 500, 300, 200)
                -- drawing pitch drift in a bar
                love.graphics.rectangle('fill', 500 - 20, 200, 10, -(instance.pitchDrift or 0) * 100)
            end
        end
    end
    for i = 1, #speakers do
        local speaker = speakers[i]
        love.graphics.push()
        love.graphics.translate(speaker.pos.x, speaker.pos.y)
        love.graphics.scale(speaker.scale.x, speaker.scale.y) -- Scale everything by 1.5x

        -- 1. Define the stencil shape (the head)
        love.graphics.stencil(function()
            love.graphics.ellipse("fill", 0, 0, 100, 100)
        end, "replace", 1)
        -- 2. Enable stencil test so only head shape gets drawn to
        love.graphics.setColor(1, 1, 0)
        love.graphics.setColor(speaker.color)
        -- love.graphics.setColor(217 / 255, 184 / 255, 64 / 255)
        love.graphics.ellipse('fill', 0, 0, 100, 100)
        love.graphics.setColor(0, 0, 0)

        love.graphics.setStencilTest("equal", 1)
        -- 3. Draw the texture (will be masked to head shape)
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.draw(texture, -100, -100, 0, 2, 2) -- Adjust as needed


        love.graphics.setColor(0, 0, 0, 0.8)
        if speaker.eyeOpen then
            love.graphics.circle('fill', 0 - speaker.eyeSpace, -40, 10)
            love.graphics.circle('fill', 40 + speaker.eyeSpace, -40, 10)
        else
            love.graphics.ellipse('fill', 0 - speaker.eyeSpace, -40, 10, 2)
            love.graphics.ellipse('fill', 40 + speaker.eyeSpace, -40, 10, 2)
        end
        -- 4. Disable stencil test
        love.graphics.setStencilTest()
        love.graphics.setColor(1, 1, 1)
        speaker.mouth:draw(1, .8)
        love.graphics.pop()
    end
end

function getPitchCurveName(syllable)
    if syllable.rise and syllable.emphasized then return 'rise-emphasis' end
    if syllable.rise then return 'rise' end
    if syllable.fall and syllable.emphasized then return 'fall-emphasis' end
    if syllable.fall then return 'fall' end
    if syllable.emphasized then return 'emphasis' end
    return 'neutral'
end

local function parseSyllable(syllableName)
    if #syllableName < 2 then return nil, syllableName:sub(1, 1) end
    return syllableName:sub(1, 1), syllableName:sub(2, 2)
end

function playSFX(sfx)
    local key = sfx.name
    local pitchCurveName = getPitchCurveName(sfx)
    local consonant, vowel = sfxMouthShapes[key].consonant, sfxMouthShapes[key].vowel
    print(consonant, vowel)
    local instance = {
        consonant = consonant,
        vowel = vowel,
        rootRatio = sfx.rootRatio,
        isSFX = true,
        name = key,
        pitchDrift = 0,
        pitchCurveName = pitchCurveName,
        pitchCurve = love.math.newBezierCurve(pitchCurves[pitchCurveName]),
        source = sfxSources[key]:clone(),
        volume = 1,
    }
    --table.insert(activeSources, instance)
    updatePitch(instance, 0)
    updateVolume(instance, 0)
    instance.source:play()
    return instance
end

function playSyllable(syllable)
    local key = syllable.name
    if not syllableSources[key] then return end

    local pitchCurveName = getPitchCurveName(syllable)

    local consonant, vowel = parseSyllable(key)

    local instance = {
        name = key,
        emphasized = syllable.emphasized,
        rise = syllable.rise,
        fall = syllable.fall,
        rootRatio = syllable.rootRatio,
        pitchDrift = syllable.pitchDrift,
        jitterSemitone = syllable.jitterSemitone,
        source = syllableSources[key]:clone(),
        pitchCurveName = pitchCurveName,
        pitchCurve = love.math.newBezierCurve(pitchCurves[pitchCurveName]),
        previousPitch = not syllable.firstInWord and lastPitch,
        legato = syllable.legato,
        vibrato = syllable.vibrato,
        volume = syllable.volume,
        isStutter = syllable.isStutter,
        stutterCutoff = syllable.stutterCutoff,
        consonant = consonant,
        vowel = vowel
    }
    -- print(inspect(instance.rootRatio))
    updatePitch(instance, 0)
    updateVolume(instance, 0)
    -- table.insert(activeSources, instance)
    instance.source:play()
    return instance
end

function lfo(t, speed, depth)
    return math.sin(t * speed * 2 * math.pi) * depth
end

function noisyLFO(t, freq, depth, seed)
    -- cheap random wobble based on time and seed
    return (love.math.noise((t * freq) or 0, seed) - 0.5) * 2 * depth
end

function updateVolume(instance, t)
    local baseVolume = instance.emphasized and 1.3 or 1
    local volume = instance.volume
    if instance.isStutter then
        --print(inspect(instance))
        local cutoff = instance.stutterCutoff or 0.3 -- e.g., 0.9 = long, 0.1 = fast
        local fade = 1.0 - math.min(1.0, t / cutoff)
        volume = math.max(0, fade)
        -- print(volume)
        if volume < 0.01 then
            instance.source:stop()
        end
    end
    --print(volume)
    instance.source:setVolume(baseVolume * instance.volume)
    --instance.source:setVolume(0)
    --instance.source:setVolume(instance.volume)
end

function updatePitch(instance, t)
    local _, envelope = instance.pitchCurve:evaluate(t)
    local driftSemitones = instance.pitchDrift or 0
    local baseRatio = instance.rootRatio or 1.0
    local jitterSemitones = instance.jitterSemitone or 0

    -- Compute pitch before modulation (base * envelope * drift)
    local pitchFromEnvelope = baseRatio * envelope
    local driftRatio = semitonesToRatio(driftSemitones + jitterSemitones)
    local targetPitch = pitchFromEnvelope * driftRatio

    -- Convert to perceptual semitone space for modulation
    local pitchInSemitones = ratioToSemitones(targetPitch)


    local vibratoSemitones = 0

    if instance.vibrato then
        local time = instance.source:tell()
        local freq = instance.vibrato.freq   -- Hz
        local depth = instance.vibrato.depth -- semitones
        print(freq, depth)
        if instance.vibrato.type == 1 then
            vibratoSemitones = vibratoSemitones + lfo(time, freq, depth)
        elseif instance.vibrato.type == 2 then
            local seed = instance.vibrato.seed
            vibratoSemitones = vibratoSemitones + noisyLFO(time, freq, depth, seed)
        end
    end

    local legatoSemitones = 0
    if instance.legato and instance.previousPitch then
        local prevSemitones = ratioToSemitones(instance.previousPitch)
        if instance.legato.type == 1 then
            local legatoFade = instance.legato.amount
            local fadeTime = math.max(legatoFade, 0.00001) -- not allowed to divide by zero below
            local fadeAmount = math.min(1.0, t / fadeTime)
            legatoSemitones = (1.0 - fadeAmount) * (prevSemitones - pitchInSemitones)
        elseif instance.legato.type == 2 then
            local glideStrength = instance.legato.amount or 3.0 -- higher = slower fade, try 2–5
            local delta = prevSemitones - pitchInSemitones
            local fade = math.exp(-t * glideStrength)
            legatoSemitones = delta * fade
        end
    end

    local finalSemitones = pitchInSemitones + vibratoSemitones + legatoSemitones
    local finalPitch = semitonesToRatio(finalSemitones)

    instance.source:setPitch(finalPitch)

    lastPitch = finalPitch
end

function updateSpeaker(speaker, dt)
    for i = #speaker.activeSources, 1, -1 do
        local src = speaker.activeSources[i]
        if not src.source:isPlaying() then
            table.remove(speaker.activeSources, i)
        else
            local t = src.source:tell() / src.source:getDuration()

            local CONSONANT_DURATION = 0.3
            -- if src.isSFX then
            -- else
            if t < CONSONANT_DURATION and src.consonant then
                local myT = t / CONSONANT_DURATION

                if myT < .5 and speaker.mouth.lastDirect then
                    speaker.mouth:tweenFromTo(speaker.mouth.lastDirect, src.consonant, myT * 2)
                else
                    if speaker.mouth.lastDirect ~= src.consonant then
                        --mouth.lastDirect = src.consonant
                        speaker.mouth:setDirectTo(src.consonant)
                    end
                end
            else
                local myT = (t - CONSONANT_DURATION) / (1.0 - CONSONANT_DURATION)
                if myT < .5 and speaker.mouth.lastDirect then
                    speaker.mouth:tweenFromTo(speaker.mouth.lastDirect, src.vowel, myT * 2)
                else
                    if speaker.mouth.lastDirect ~= src.vowel then
                        -- mouth.lastDirect = src.vowel
                        speaker.mouth:setDirectTo(src.vowel)
                    end
                end
            end
            -- end
            if not src.isSFX then
                updatePitch(src, t)
                updateVolume(src, t)
            end
        end
    end

    if speaker.pauseTimer > 0 then
        speaker.pauseTimer = speaker.pauseTimer - dt
    elseif #speaker.sayQueue > 0 and #speaker.activeSources == 0 then
        local entry = table.remove(speaker.sayQueue, 1)
        if entry.pause then
            speaker.pauseTimer = entry.delay
        else
            --print(inspect(entry))
            if entry.sfx then
                table.insert(speaker.activeSources, playSFX(entry))
                -- print('sfx spotted', inspect(entry))
            else
                table.insert(speaker.activeSources, playSyllable(entry))
            end
        end
    end
    --print(speaker, speaker.blinkCooldown)
    if speaker.blinkCooldown > 0 then
        speaker.blinkCooldown = speaker.blinkCooldown - dt
        if speaker.blinkCooldown <= 0 then
            speaker.eyeOpen = true
            speaker.blinkTimer = 2 + math.random() * 2
        end
    else
        speaker.blinkTimer = speaker.blinkTimer - dt
        if speaker.blinkTimer <= 0 then
            speaker.eyeOpen = false
            speaker.blinkCooldown = speaker.blinkDuration
        end
    end

    if #speaker.activeSources == 0 then
        speaker.mouth:updateFallback(dt, speaker.mouthIdle or 'closed', 0.1)
    else
        speaker.mouth.mouthCloseTimer = nil
        speaker.mouth.mouthCloseTimer = nil
    end
end

function love.update(dt)
    if pause then return end

    for i = 1, #speakers do
        updateSpeaker(speakers[i], dt)
    end
end

function say(input)
    lastPitch = nil -- just to be sure
    sayQueue = parseInput(input)
end

-- Splits word into syllables, ignoring dashes inside brackets (e.g. [-2])
function splitSyllables(word)
    local syllables = {}
    local i = 1
    local len = #word
    local start = 1
    local inBrackets = false

    while i <= len do
        local c = word:sub(i, i)
        if c == '[' then
            inBrackets = true
        elseif c == ']' then
            inBrackets = false
        elseif c == '-' and not inBrackets then
            table.insert(syllables, word:sub(start, i - 1))
            start = i + 1
        end
        i = i + 1
    end

    if start <= len then
        table.insert(syllables, word:sub(start))
    end

    return syllables
end

local stutterChanceSets = {
    {
        p = 0.6,
        b = 0.5,
        f = 0.4,
        k = 0.3,
        m = 0.05 -- very low likelihood for nasals
    }
}
function shouldStutter(syllable, stutter)
    local firstChar = syllable:sub(1, 1):lower()
    local chance = stutterChanceSets[stutter.chanceIndex][firstChar]
    if not chance then
        return false -- default to no stutter if consonant is not in list
    end
    return love.math.random() < chance
end

function addStutterings(queue, syllable, stutterCount, stutter)
    for j = 1, stutterCount do
        local stutterJitter = 0
        local stutterPitch = syllable.rootRatio
        local stutterCutoff = 0.5

        if stutter.melodicIndex == 1 then
            stutterJitter = (love.math.random() * 2 - 1) * 4 -- random between -0.2 and +0.2 semitones
            stutterPitch = syllable.rootRatio * (2 ^ (stutterJitter / 12))
            stutterCutoff = 0.6
        end
        -- todo d more..
        -- very musical jitters below -- d not ooptimize this away
        --local stutterMelody = { 0, -2, -3, 4, -8 }
        --local melodyOffset = stutterMelody[(j - 1) % #stutterMelody + 1]
        --local stutterPitch = finalPitchTargetRatio * (2 ^ (melodyOffset / 12))
        -- local stutterPitch = syllable.rootRatio * (2 ^ (((j - 1) * 1) / 12)) -- ascending
        --local stutterPitch = finalPitchTargetRatio * (2 ^ (((1 - j) * 1) / 12))   -- descending

        -- print('stutterpitch', stutterPitch)
        table.insert(queue, {
            volume = 1,
            pitchDrift = 0, --stutterJitter,
            name = syllable.name,
            emphasized = syllable.emphasized,
            pitchCurveName = currentPitchCurveName or (syllable.emphasized and 'emphasis-first') or
                'neutral',
            riseOffset = riseOffsetVal,
            rootRatio = stutterPitch,
            --defaultPitch = stutterPitch,
            isStutter = true,
            stutterCutoff = stutterCutoff -- + love.math.random() * .25
        })
    end
end

function parseConfigBlock(block)
    local config = {}
    for k, v in block:gmatch("([%w_]+)=([^%s}]+)") do
        if k == "personality" then
            local preset = personalities[v]
            if preset then
                for presetKey, presetVal in pairs(preset) do
                    config[presetKey] = presetVal
                end
                --print(inspect(config))
            else
                print("Unknown personality: " .. v)
            end
        elseif k == "vibrato" then
            local parts = {}
            for p in v:gmatch("[^:]+") do table.insert(parts, p) end
            local type = tonumber(parts[1]) or 1
            print(inspect(parts))
            config.vibrato = {
                type = type,
                freq = tonumber(parts[2]) or 5,
                depth = tonumber(parts[3]) or .5,
                seed = tonumber(parts[4]) or 100,
            }
        elseif k == "stutter" then
            if v == '0' then
                config.stutter = { disabled = true }
            elseif v == '1' then
                config.stutter = {
                    min = min,
                    max = max,
                    chanceIndex = 1,
                    melodicIndex = 1,
                    disabled = false,
                }
            else
                local parts = {}
                for p in v:gmatch("[^:]+") do table.insert(parts, p) end
                local min = tonumber(parts[1]) or 2
                local max = tonumber(parts[2]) or 4
                local melodicIndex = tonumber(parts[3]) or 1
                local changeIndex = tonumber(parts[4]) or 1

                config.stutter = {
                    min = min,
                    max = max,
                    chanceIndex = changeIndex,
                    melodicIndex = melodicIndex,
                    disabled = false
                }
            end
        elseif k == "pause" then
            local parts = {}
            for p in v:gmatch("[^:]+") do table.insert(parts, p) end

            config.pause = {
                syllable = tonumber(parts[1]) or 0.1,
                word = tonumber(parts[2]) or 0.5,
                comma = tonumber(parts[3]) or 0.2
            }
        elseif k == "swing" then
            local parts = {}
            for p in v:gmatch("[^:]+") do table.insert(parts, p) end

            config.swing = {
                tonumber(parts[1]) or 1,
                tonumber(parts[2]) or 1,
            }
            --print(config.swing[1], config.swing[2])
        elseif k == "stress" then
            local parts = {}
            for p in v:gmatch("[^:]+") do table.insert(parts, p) end

            config.stress = {
                tonumber(parts[1]),
                tonumber(parts[2]),
            }
            --print('setting stres', config.stress[1], config.stress[2])
        elseif k == 'legato' then
            local parts = {}
            for p in v:gmatch("[^:]+") do table.insert(parts, p) end
            local type = tonumber(parts[1]) or 1
            if type ~= nil and (type < 1 or type > 2) then
                print('legato can only be of type 1 and 2')
            end
            config.legato = {
                type = type,
                amount = tonumber(parts[2]) or (type == 1 and 0.5 or 3)
            }
        else
            config[k] = v
        end
    end
    return config
end

function parseInput(input)
    local queue = {}

    local rootRatio = 1.0
    local pitchJitter = 0.0
    local legato = nil
    local vibrato = nil
    local baseVolume = 1
    local volumeDelta = 0
    local volumeJitter = 0
    local intonationStep = 1
    local pause = { syllable = 0.1, word = 0.5, comma = 0.2 }
    local syllableTimingJitter = 0
    local wordTimingJitter = 0
    local swing = { 1, 1 }
    local stress = { 0, 0 }
    local stutter = { disabled = true, min = 0, max = 0, changeIndex = 1, melodicIndex = 1 }

    local configBlock = input:match("^%b{}")


    if configBlock then
        local config = parseConfigBlock(configBlock)
        rootRatio = noteToRatio(config.root) or 1.0
        pitchJitter = tonumber(config.rndp) or 0
        legato = config.legato
        vibrato = config.vibrato
        baseVolume = config.volume or 1
        volumeJitter = tonumber(config.rndv) or 0
        volumeDelta = tonumber(config.vdelta) or 0
        intonationStep = tonumber(config.intonation) or 1
        pause = config.pause and config.pause or pause
        syllableTimingJitter = tonumber(config.rndst) or 0
        wordTimingJitter = tonumber(config.rndwt) or 0
        swing = config.swing and config.swing or swing
        input = input:gsub("^%b{}%s*", "")
        stress = config.stress and config.stress
        stutter = config.stutter and config.stutter
    end


    input = input:gsub(",", " , ")
    for word in input:gmatch("%S+") do
        if word == ',' then
            table.insert(queue, { pause = true, delay = pause.comma })
        else
            local wordRising = false
            local wordFalling = false

            local sfx = nil
            print(word)
            if word:match("^%b()$") then
                local raw = word:sub(2, -2)
                local note = raw:match("%[(.-)%]")
                local name = raw:gsub("%[.-%]", "")
                table.insert(queue, {
                    sfx = true,
                    name = name,
                    rootRatio = noteToRatio(note)
                })

                goto continue
            end


            do
                local prefix = word:sub(1, 1)
                if prefix == '?' then
                    wordRising = true
                    word = word:sub(2)
                elseif prefix == '_' then
                    wordFalling = true
                    word = word:sub(2)
                end

                local syllables = {}

                for _, syllable in ipairs(splitSyllables(word)) do
                    local raw = syllable
                    local rise = false
                    local fall = false
                    local glideFromPrevious = false

                    -- syllable starts with ~
                    if raw:sub(1, 1) == '~' then
                        glideFromPrevious = true
                        raw = raw:sub(2)
                    end


                    if raw:sub(-1) == '?' then
                        rise = true
                        raw = raw:sub(1, -2)
                    elseif raw:sub(-1) == '_' then
                        fall = true
                        raw = raw:sub(1, -2)
                    end

                    local inlinePitchStr = raw:match("%[([^%]]+)%]")
                    local absolutePitchRatio = nil
                    local relativeOffsetSemitones = nil
                    if inlinePitchStr then
                        raw = raw:gsub("%[[^%]]+%]", "", 1) -- strip pitch annotation
                        local numVal = tonumber(inlinePitchStr)
                        if numVal then
                            relativeOffsetSemitones = numVal
                        else
                            absolutePitchRatio = noteToRatio(inlinePitchStr)
                        end
                    end

                    local volStr = raw:match("^<([^>]+)>")
                    local volumeOverride = nil

                    if volStr then
                        raw = raw:gsub("^<[^>]+>", "", 1) -- remove the volume marker
                        local v = tonumber(volStr)
                        if v then volumeOverride = v end
                    end

                    local emphasized = raw == raw:upper()


                    local name = raw:lower()


                    table.insert(syllables, {
                        name = name,
                        emphasized = emphasized,
                        rise = rise,
                        fall = fall,
                        relativeOffsetSemitones = relativeOffsetSemitones,
                        absolutePitchRatio = absolutePitchRatio,
                        legato = legato or glideFromPrevious and { type = 1, amount = 0.5 },
                        vibrato = vibrato,
                        volumeOverride = volumeOverride
                    })
                end
                for i, syllable in ipairs(syllables) do
                    local isStressed = stress and (stress[2] ~= 0) and (i % stress[2] == stress[1])
                    if isStressed then
                        syllable.emphasized = true
                    end

                    local pitchDrift = 0
                    if wordRising then
                        pitchDrift = (intonationStep * (i - 1))
                    elseif wordFalling then
                        pitchDrift = (intonationStep * (1 - i))
                    end

                    syllable.jitterSemitone = ((love.math.random() * 2 - 1) * pitchJitter)

                    if syllable.absolutePitchRatio then
                        syllable.rootRatio = syllable.absolutePitchRatio
                        syllable.pitchDrift = 0
                    elseif syllable.relativeOffsetSemitones then
                        syllable.rootRatio = rootRatio * (2 ^ (syllable.relativeOffsetSemitones / 12))
                        syllable.pitchDrift = 0
                    else
                        syllable.rootRatio = rootRatio
                        syllable.pitchDrift = pitchDrift
                    end


                    local syllableVolumeDelta = 0
                    if volumeDelta ~= 0 then
                        local t = (i - 1) / math.max(1, #syllables) -- value from 0 to 1
                        syllableVolumeDelta = t * volumeDelta
                    end


                    local jitter = (love.math.random() * 2 - 1) * volumeJitter
                    local finalVolume = baseVolume * (1 + jitter)
                    syllable.volume = finalVolume + syllableVolumeDelta
                    if syllable.volumeOverride ~= nil then
                        syllable.volume = syllable.volumeOverride
                    end
                    syllable.firstInWord = (i == 1)


                    if stutter then
                        if not stutter.disabled then
                            local shouldMaybeStutter = shouldStutter(syllable.name, stutter)
                            if true and shouldMaybeStutter then
                                if (i == 1) and #syllables > 1 then
                                    local min = (stutter.min or 2)
                                    local max = min + ((stutter.max or 2) - min)
                                    local stutterCount = min + love.math.random() * (max - min)
                                    addStutterings(queue, syllable, stutterCount, stutter)
                                end
                            end
                        end
                    end

                    table.insert(queue, syllable)

                    -- here we do the pauses inbetween syllables and words, also swung and timingjitter

                    local swingMultiplier = (swing[(i - 1) % 2 + 1])
                    local divideBy = (swing[1] == 1 and swing[2] == 1) and 1 or syllable.rootRatio

                    local sylM = syllableTimingJitter > 0 and (love.math.random() * syllableTimingJitter) or 1
                    local wordM = wordTimingJitter > 0 and (love.math.random() * wordTimingJitter) or 1

                    local sylpause = ((pause.syllable * swingMultiplier) / divideBy) * sylM
                    local wordpause = ((pause.word) / divideBy) * wordM


                    table.insert(queue,
                        {
                            pause = true,
                            delay = (i < #syllables) and sylpause or wordpause
                        }
                    )
                end
            end
            ::continue::
        end
    end
    return queue
end

function randomSayableString(root)
    local endings = { '', '', '', '?' }
    local output = { '{personality=party root=' .. (root or 'g4') .. ' } ' }

    for _ = 1, 4 do
        local syllCount = love.math.random(1, 4)
        local word = {}
        for i = 1, syllCount do
            local s = syllableKeys[love.math.random(#syllableKeys)]

            if i == 1 and syllCount == 2 and love.math.random() < 0.5 then
                s = s:upper()
                -- s = 'MI'
            end
            table.insert(word, s)
        end
        table.insert(output, table.concat(word, '-') .. endings[love.math.random(#endings)])

        if love.math.random() < .5 then
            table.insert(output, ',')
        end
        if love.math.random() < .5 then
            table.insert(output, ' (humup1) ')
        end
    end
    local result = table.concat(output, ' ')
    --print(result)
    return result
end

function speakerSay(speaker, input)
    speaker.sayQueue = parseInput(input)
    speaker.lastPitch = nil
end

function love.keypressed(key)
    if key == 'y' then
        say('{root=c3  } [c4]mi-[d4]mi-[e5]MI?-MI?-MI?-mi-mi-mi-mi-mi po-po-po-po-po-po-po')
    end
    if key == 'n' then
        say('{root=c3  } [c4]mi-[d4]mi-[e5]mi-mi-mi-mi-mi-mi-mi-mi')
        -- like and subscribe!
        -- say('{root=c5 swing={.2, 1.8}} ?NI-ko? KO-la? FA-da?')
    end
    if key == 'x' then
        say('{root=c5 swing=.2:1.8 stress=1:1 } mi-mi-mi-mi-mi-mi-mi-mi-mi-mi')
        --say('{root=c5 swing=.2:1.8 } mi-mi-mi-mi-mi')
        -- say('{root=c5 swing=.2:1.8 } ?wa-hi-pi? lo-pi-pi')
        -- like and subscribe!
        -- say('{root=c3 swing={.2, 1.8}} ?LI-ka? ?SO-bi-SI-~ba?')
    end
    if key == 'p' then
        say('mi ([a3]humup1) di-di ([c4]humup1) ([c6]huh) ([d6]huh) ([e6]huh)')
    end
    if key == 'l' then
        say('{root=c4, swing=.3,:1.7} li ki ?so-bi-si-bi')
    end
    if key == 'm' then
        say('{root=c6, swing=.3:1.7, stress=1:3 } mi-mi-mi-mi-mi-mi')
    end
    if key == 'j' then
        say(' ')

        say('MI?')

        say('po!')

        say('fo-fi? _lo-lo·ma')

        say('mi? to-ko pi-pi?')

        say('so, wa-ha')

        say('{swing=.3:1.7} lo-fi? ta-la-mi!')

        -- say('{root=c3} mi')
        -- say('{root=c6} mi-~[-12]<.1>mi-~mi-~[-8]<.4>mo?-~MO')

        --say('{swing=.3:1.7 root=c6} mi-MI-mi-MI-mi')
        --say('{swing=.3:1.7 root=c6} mi-mi-mi-mi-mi')l
        say('{swing=.3:1.7 root=c2} [c3]ka-ki')
        --say('{swing=.3:1.7 root=d5} mi-mi-MI-mi-mi')
        --say('{root=c6} fi-~[-8]<.3>mi-~fo-~[-8]<.4>mo?-~MO')
        --say('{root=c5} mi-~[c4]<.5>mi-~[d3]mi-~[c6]<.4>mo?-~MO')
        --say('{swing=.1:1.9 rndp=5} mi-mi-mi-mi-mi-mi-mi-mi')
        --say('{rndp=15} mi-mi-mi-mi-mi-mi-mi-mi')
    end


    -- say('mi ka-ka po-lo do-di')




    if key == 'space' then
        speakerSay(speakers[2], '{root=c3  rndp=3 legato=1}  BA')
        -- speakerSay(speakers[1], '{root=c5  } ([e3]huh) ([e2]huh) , ([e2]humup1)')
        --  speakerSay(speakers[1], '{root=c5 vibrato=1:5:3 } mi-po-la')

        -- speakerSay(speakers[1], '{root=c5  legato=2:0.5} [c4]mi-~[c6]po-~[c7]po-~[c8]pi-~[c7]po-~[c4]la')
        --speakerSay(speakers[1], '{root=c5  legato=2:0.5} [c4]la-[c6]la-[c7]la-[c8]la-[c7]la-[c4]la')



        --speakerSay(speakers[1], '{root=c5} mi-ka-ka-po-lo-do-di')
        --speakerSay(speakers[1], '{root=c5} ?mi-ka-ka-po-lo-do-di')
        --speakerSay(speakers[1], '{root=c5} mi-po-mi-po-mi-po-mi')
        --speakerSay(speakers[1], randomSayableString(speakers[1].root))
        --speakerSay(speakers[2], randomSayableString(speakers[2].root))
        --speakerSay(speakers[3], randomSayableString(speakers[3].root))
        --
        -- for i = 1, #speakers do
        --     speakerSay(speakers[i], randomSayableString(speakers[i].root))
        -- end


        -- for i = 1, #speakers do
        --     local delay = love.math.random() * 2.5 -- random delay between 0 and 1.5 seconds
        --     local input = randomSayableString(speakers[i].root)
        --     local parsed = parseInput(input)

        --     -- Insert a pause entry at the start
        --     table.insert(parsed, 1, { pause = true, delay = delay })

        --     speakers[i].sayQueue = parsed
        --     speakers[i].lastPitch = nil
        -- end


        --say(randomSayableString())
    end
    if key == 'q' then
        speakerSay(speakers[1], '{root=c5 stutter=1}  fo-fi po-pi')
        --speakerSay(speakers[1], '{root=c5  } la-la-la-la-la-la')
        --   speakerSay(speakers[1],
        --       '[c5]mi [c5]mi [g5]mi [g5]mi [a5]mi [a5]mi [g5]mi , [f5]mi [f5]mi [e5]mi [e5]mi [d5]mi [d5]mi [c5]mi')
        --speakerSay(speakers[1],
        --    '[c5]mi-[c5]mi-[g5]mi-[g5]mi-[a5]mi-[a5]mi-[g5]mi  [f5]mi-[f5]mi-[e5]mi-[e5]mi-[d5]mi-[d5]mi-[c5]mi')

        --speakerSay(speakers[1], '{root=c5} MI-mi-mi')
        --speakerSay(speakers[1], '{root=c5} ?mi-po-mi-po-mi-po-mi')
        --  speakerSay(speakers[1], randomSayableString(speakers[1].root))
        --speakerSay(speakers[2], randomSayableString(speakers[2].root))
        --speakerSay(speakers[3], randomSayableString(speakers[3].root))
        --say(randomSayableString())
    end
    if key == 'w' then
        speakerSay(speakers[1],
            '{root=c5 swing=0.3:1.7 }  la-la-la-la-la-la')

        --speakerSay(speakers[1], '{root=c5  swing=0.3:1.7 } la-la-la-la-la-la')

        --speakerSay(speakers[1], '{root=c5 swing=0.1:1.9 } mi-po-la-mi-po-la-mi-po-la-mi-po-la')
        --speakerSay(speakers[1], '{root=c5  legato=2:0.5} [c4]mi-~[c6]po-~[c7]po-~[c8]pi-~[c7]po-~[c4]la')
        -- speakerSay(speakers[1], '{root=c5} _mi-po-mi-po-mi-po-mi')
        --speakerSay(speakers[1], '{root=c5} mi da-jo')
    end

    if key == 'e' then
        speakerSay(speakers[1],
            '{root=c5  stress=1:2}  la-la-la-la-la-la')

        --speakerSay(speakers[1], '{root=c5  swing=0.3:1.7 stress=1:2 } la-la-la-la-la-la')
        -- speakerSay(speakers[1], '{root=c5  legato=2:0.5} [c4]la-[c6]la-[c7]la-[c8]la-[c7]la-[c4]la')
        --speakerSay(speakers[1], '{root=c5 rndp=15} mi-po-mi-po-mi-po-mi')
        --speakerSay(speakers[1], '{root=c5} mi ja')
    end
    if key == 'r' then
        speakerSay(speakers[1],
            '{root=c5  swing=0.3:1.7 stress=1:2}  la-la-la-la-la-la')
    end
    if key == 'p' then
        pause = not pause
    end

    if key == 'escape' then love.event.quit() end
end
