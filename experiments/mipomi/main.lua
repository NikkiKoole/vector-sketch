local inspect = require 'inspect'

-- things todo later:
-- add extra markers like (breathout) (sign) (tsk) (ooof) (ough) etc.
-- Allow speaker-specific variation (some Mipos always end high, some stutter, some have deep voices).
-- Try combining pitch with timing (e.g. slower syllable = sadder).
-- lets just get rid of the dash between syllables
-- make the code testable, for that we need to unroll the bezier to pure code.
-- Allow default curves by word function (e.g., questions = rising).
-- Or define speaker personalities that bias pitch/timing differently?
-- 3. 🫨 Stutter (Pre-decided syllable repetition)
--Yes, this is more complex — but you’re right to think "decide before queueing".
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

function love.draw()
    love.graphics.print('Press 1–7 for syllables, 8–0 for phrases\nActive: ' .. #activeSources)
end

function love.keypressed(key)
    local keymap = {
        ['q2'] = function() say('{root=g3} _MI-mi-MI, ?MI-mi-MI ,') end,
        ['q'] = function() say('[c3]mi [-1]mi [-2]mi') end,
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
            say('{root=c4} ?mi-mi-mi?')
        end,
        ['escape'] = function() love.event.quit() end,
    }
    if keymap[key] then keymap[key]() end
end

function love.update(dt)
    for i = #activeSources, 1, -1 do
        local src = activeSources[i]
        if not src.source:isPlaying() then
            lastPitch = src.source:getPitch()
            table.remove(activeSources, i)
        else
            local tNorm = src.source:tell() / src.source:getDuration()
            updatePitch(src, tNorm)
            updateVolume(src, tNorm)
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
        stutterCutoff = syllableData.stutterCutoff or 1
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
