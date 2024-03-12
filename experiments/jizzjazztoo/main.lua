-- aybe have a play with this:
-- https://github.com/zorggn/love-asl/blob/master/asl-thread.lua
--love.audio.newAdvancedSource = require 'asl'

function love.load()
    max_octave   = 8
    octave       = 4

    samples      = {
        love.audio.newSource("VibraphoneMid-MT70.wav", "static"),
        --  love.audio.newSource("Synth SoftTooter.wav", "static"),
        --  love.audio.newSource("Synth Microdot1.wav", "static"),
        --  love.audio.newSource("synth03.wav", "static"),
        --  love.audio.newSource("piano-clickO1.wav", "static"),
        --  love.audio.newSource("sf1-015.wav", "static"),
        --  love.audio.newSource("bass07.wav", "static"),
        --  love.audio.newSource("Upright Bass F#2.wav", "static"),

        --  love.audio.newSource("bass04.wav", "static"),
    }
    sampleIndex  = 1
    sample       = samples[sampleIndex]
    sampleTuning = {
        0, -1, -1, 0, 0, 0, 0, 0
    }


    scales = {
        ['chromatic'] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },

        ['major'] = { 0, 2, 4, 5, 7, 9, 11 },                 -- ionian major
        ['lydian'] = { 0, 2, 4, 6, 7, 9, 11 },                -- lydian major
        ['mixolydian'] = { 0, 2, 4, 5, 7, 9, 10 },            -- mixolydian major

        ['minor'] = { 0, 2, 3, 5, 7, 8, 10 },                 -- dorian minor
        ['locrian'] = { 0, 1, 3, 5, 6, 8, 10 },               -- locrian minor
        ['phrygian'] = { 0, 1, 3, 5, 7, 8, 10 },              -- phrygian minor
        ['aeolian'] = { 0, 2, 3, 5, 7, 8, 10 },               -- aeolian minor

        ['pentatonic_major'] = { 0, 2, 4, 7, 9 },             -- Major Pentatonic
        ['pentatonic_minor'] = { 0, 3, 5, 7, 10 },            -- Minor Pentatonic

        ['blues_major'] = { 0, 3, 4, 5, 6, 7, 10 },           -- Major Blues
        ['blues_minor'] = { 0, 3, 5, 6, 7, 10 },              -- Minor Blues

        ['jazz_minor'] = { 0, 2, 3, 5, 7, 9, 11 },            -- Jazz Minor
        ['harmonic_minor'] = { 0, 2, 3, 5, 7, 8, 11 },        -- Harmonic Minor
        ['melodic_minor'] = { 0, 2, 3, 5, 7, 9, 11 },         -- Melodic Minor

        ['enigmatic'] = { 0, 1, 4, 6, 8, 10, 11 },            -- Enigmatic scale
        ['double_harmonic_major'] = { 0, 1, 4, 5, 7, 8, 11 }, -- Double Harmonic Major scale
        ['hungarian_minor'] = { 0, 2, 3, 6, 7, 8, 11 },       -- Hungarian Minor scale
        ['arabian'] = { 0, 2, 4, 5, 6, 8, 10 },               -- Arabian scale
        ['altered'] = { 0, 1, 3, 4, 6, 8, 10 },               -- Altered scale
        ['prometheus'] = { 0, 2, 4, 6, 9, 10 },               -- Prometheus scale
        ['kumoi'] = { 0, 2, 3, 7, 9 },                        -- Kumoi scale
        ['gypsy'] = { 0, 2, 4, 7, 8, 10 },                    -- Gypsy scale
        ['lydian_augmented'] = { 0, 2, 4, 6, 8, 9, 11 },      -- Lydian Augmented scale
    }
    scale  = scales.hungarian_minor
end

function love.update()

end

function love.draw()

end

function getPitchVariationRange(semitone, offsetInSemitones)
    local oneUp = getPitch(semitone + 1)
    local oneDown = getPitch(semitone - 1)
    local range = (oneUp - oneDown) * offsetInSemitones -- Calculate the range directly
    return range
end

function semitonePressed(number)
    --print('pressed', number, getPitch(number))
    local source = sample:clone()
    local pitch = getPitch(number)


    local range = getPitchVariationRange(number, 1 / 32)
    local pitchOffset = love.math.random() * range - range / 2

    source:setPitch(pitch + pitchOffset)
    source:play()
end

function semitoneReleased(number)
    -- print('released', number)
end

function getSemitone(offset)
    return (octave * 12) + offset
end

function getPitch(semitone)
    local sampledAtSemitone = 60 + sampleTuning[sampleIndex]
    return 2 ^ ((semitone - sampledAtSemitone) / 12)
end

function fitKeyOffsetInScale(offset, scale)
    -- this will get a keyboard offset integer (0...17 for all the 'white and black keys')
    -- and return an offset that fits within the active scale.
    local result
    if (offset <= #scale - 1) then
        result = scale[offset + 1]
    else
        local extraChords = math.floor(offset / #scale)
        local newOffset = (offset % #scale)
        result = (extraChords * 12) + scale[newOffset + 1]
    end

    return result
end

function love.keypressed(k)
    local mapToOffsetBlackAndWhite = {
        ['a'] = 0,
        ['w'] = 1,
        ['s'] = 2,
        ['e'] = 3,
        ['d'] = 4,
        ['f'] = 5,
        ['t'] = 6,
        ['g'] = 7,
        ['y'] = 8,
        ['h'] = 9,
        ['u'] = 10,
        ['j'] = 11,
        ['k'] = 12,
        ['o'] = 13,
        ['l'] = 14,
        ['p'] = 15,
        [';'] = 16,
        ["'"] = 17,
        [']'] = 18,
        ["\\"] = 19,
    }

    local mapToOffsetJustWhites = {
        ['a'] = 0,
        ['s'] = 1,
        ['d'] = 2,
        ['f'] = 3,
        ['g'] = 4,
        ['h'] = 5,
        ['j'] = 6,
        ['k'] = 7,
        ['l'] = 8,
        [';'] = 9,
        ["'"] = 10,
        ['\\'] = 11,
    }

    --local chordMappings = {
    --    ['major'] = { 0, 4, 7 }, -- Major chord
    --    ['minor'] = { 0, 3, 7 }, -- Minor chord
    --['d'] = {0, 7},        -- 5th chord
    -- Define more chord mappings as needed
    -- }
    if (mapToOffsetBlackAndWhite[k] ~= nil) then
        local oneKeyChord = false
        --local doMajorTriad
        if not oneKeyChord then
            semitonePressed(getSemitone(fitKeyOffsetInScale(mapToOffsetBlackAndWhite[k], scale)))
        else
            if false then
                local triads = {
                    { 1, 3, 5 },
                    { 2, 4, 6 },
                    { 3, 5, 7 },
                    { 1, 3, 5, 7 },
                }
                local triad = triads[4]
                for i = 1, #triad do
                    local offset0 = scale[triad[i]]
                    semitonePressed(getSemitone(fitKeyOffsetInScale(mapToOffsetBlackAndWhite[k], scale)) + offset0)
                end
            end
            local offsets = { { 0, 4, 7 }, { 0, 4, 7, 11 }, { 0, 4, 8, 10 }, }
            local offset = offsets[3]


            for i = 1, #offset do
                local offset0 = offset[i]
                semitonePressed(getSemitone(fitKeyOffsetInScale(mapToOffsetBlackAndWhite[k], scale)) + offset0)
            end
        end
    end


    if k == 'z' then
        octave = math.max(octave - 1, 0)
    elseif k == 'x' then
        octave = math.min(octave + 1, max_octave)
    end
    if k == 'tab' then
        sampleIndex = (sampleIndex % #samples) + 1
        sample      = samples[sampleIndex]
        print(sampleIndex)
    end

    if k == 'c' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] - 1
        print('tuning of #', sampleIndex, sampleTuning[sampleIndex])
    end
    if k == 'v' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] + 1
        print('tuning of #', sampleIndex, sampleTuning[sampleIndex])
    end

    if k == 'escape' then love.event.quit() end
end
