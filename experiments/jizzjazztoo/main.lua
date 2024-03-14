local function prepareSamples(names)
    local result = {}
    for i = 1, #names do
        local name = names[i]
        result[i] = { name = name, source = love.audio.newSource(name .. ".wav", 'static') }
    end
    return result
end

function love.load()
    -- adsr stuff
    playingSounds = {}

    -- measure/beat
    barsInMeasure = 4
    bpm = 190
    lastTick = 0
    lastBeat = 0
    beat = 0
    tick = 0

    -- metronome sounds
    metronome_click = love.audio.newSource("Clave.wav", "static")

    -- octave stuff
    max_octave = 8
    octave = 4

    -- sample stuff
    local sampleFiles = {
        "0x722380", "0x14146A0", "0xC3B760",
        "ANCR I Mallet 7", "VibraphoneMid-MT70",
        "Synth SineFiltered1", "Bass BoringSimple",
        "Synth SoftTooter", "junopiano",
        "synth03", "4", "chord-organ-decentc2",
        "A_040__E2_3", "sf1-015"
    }
    samples = prepareSamples(sampleFiles)

    sampleIndex = 1
    sample = samples[sampleIndex]
    -- print(sample.name)
    -- tuning
    sampleTuning = {}
    for i = 1, #samples do
        sampleTuning[i] = 0
    end

    -- scales
    scales = {
        ['chromatic'] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        ['major'] = { 0, 2, 4, 5, 7, 9, 11 },
        ['lydian'] = { 0, 2, 4, 6, 7, 9, 11 },
        ['mixolydian'] = { 0, 2, 4, 5, 7, 9, 10 },
        ['minor'] = { 0, 2, 3, 5, 7, 8, 10 },
        ['locrian'] = { 0, 1, 3, 5, 6, 8, 10 },
        ['phrygian'] = { 0, 1, 3, 5, 7, 8, 10 },
        ['aeolian'] = { 0, 2, 3, 5, 7, 8, 10 },
        ['pentatonic_major'] = { 0, 2, 4, 7, 9 },
        ['pentatonic_minor'] = { 0, 3, 5, 7, 10 },
        ['blues_major'] = { 0, 3, 4, 5, 6, 7, 10 },
        ['blues_minor'] = { 0, 3, 5, 6, 7, 10 },
        ['jazz_minor'] = { 0, 2, 3, 5, 7, 9, 11 },
        ['harmonic_minor'] = { 0, 2, 3, 5, 7, 8, 11 },
        ['melodic_minor'] = { 0, 2, 3, 5, 7, 9, 11 },
        ['enigmatic'] = { 0, 1, 4, 6, 8, 10, 11 },
        ['double_harmonic_major'] = { 0, 1, 4, 5, 7, 8, 11 },
        ['hungarian_minor'] = { 0, 2, 3, 6, 7, 8, 11 },
        ['arabian'] = { 0, 2, 4, 5, 6, 8, 10 },
        ['altered'] = { 0, 1, 3, 4, 6, 8, 10 },
        ['prometheus'] = { 0, 2, 4, 6, 9, 10 },
        ['kumoi'] = { 0, 2, 3, 7, 9 },
        ['gypsy'] = { 0, 2, 4, 7, 8, 10 },
        ['lydian_augmented'] = { 0, 2, 4, 6, 8, 9, 11 },
    }
    scale = scales.chromatic

    -- keymapping (black and white or just white)
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
    usingMap = mapToOffsetBlackAndWhite
end

function toggleScale()
    local currentScaleIndex = 1
    local scaleKeys = {}

    -- Extract scale keys into a separate table
    for key, _ in pairs(scales) do
        table.insert(scaleKeys, key)
    end

    -- Function to get the next scale key
    local function getNextScaleKey()
        for i = 1, #scaleKeys do
            if scale == scales[scaleKeys[i]] then
                currentScaleIndex = i
            end
        end

        currentScaleIndex = currentScaleIndex + 1
        if currentScaleIndex > #scaleKeys then
            currentScaleIndex = 1
        end
        return scaleKeys[currentScaleIndex]
    end

    local nextScaleKey = getNextScaleKey()
    scale = scales[nextScaleKey]
    print("Scale:", nextScaleKey)
end

function getPitchVariationRange(semitone, offsetInSemitones)
    local oneUp = getPitch(semitone + 1)
    local oneDown = getPitch(semitone - 1)
    local range = (oneUp - oneDown) * offsetInSemitones
    return range
end

function semitoneTriggered(number)
    local source = sample.source:clone()
    local pitch = getPitch(number)
    -- print(pitch)
    local range = getPitchVariationRange(number, 1 / 7)
    local pitchOffset = love.math.random() * range - range / 2
    source:setPitch(pitch + pitchOffset)
    source:play()

    table.insert(playingSounds, {
        pitch = pitch + pitchOffset,
        source = source,
        semitone = number,
        sampleIndex = sampleIndex,
        timeNoteOn = love.timer.getTime()
    })
end

function semitonePressed(number)
    semitoneTriggered(number)
end

local function cleanPlayingSounds()
    local now = love.timer.getTime()
    for i = #playingSounds, 1, -1 do
        local it = playingSounds[i]
        if (it.timeNoteOff and it.timeNoteOff < now and not it.source:isPlaying()) then
            table.remove(playingSounds, i)
        end
    end
end

function generateADSR(it, now)
    local attackTime = 0.1
    local decayTime = 0.1
    local sustainLevel = 0.7
    local releaseTime = .3
    local startTime = it.timeNoteOn
    local duration = it.source:getDuration('seconds')
    local endTime = it.timeNoteOff or startTime + duration
    local envelopeValue = 1

    if now <= startTime + attackTime then
        envelopeValue = (now - startTime) / attackTime
    elseif now <= startTime + attackTime + decayTime then
        envelopeValue = 1 - (1 - sustainLevel) * ((now - startTime - attackTime) / decayTime)
    elseif now <= endTime - releaseTime then
        envelopeValue = sustainLevel
    else
        local releaseDuration = now - endTime
        envelopeValue = sustainLevel * math.exp(-releaseDuration / releaseTime)
    end

    return envelopeValue
end

local function updateADSREnvelopesForPlayingSounds(dt)
    local now = love.timer.getTime()
    for i = 1, #playingSounds do
        local it = playingSounds[i]
        local value = generateADSR(it, now)
        it.source:setVolume(value)
    end
end

function generateSineLFO(time, lfoFrequency)
    return math.sin(2 * math.pi * lfoFrequency * time)
end

local function updatePlayingSoundsWithLFO()
    for i = 1, #playingSounds do
        local it = playingSounds[i]
        local time = love.timer.getTime() - it.timeNoteOn
        local lfoValue = generateSineLFO(time, .15)
        local range = getPitchVariationRange(it.semitone, 1 / 12)
        local lfoAmplitude = range
        local lfoPicthDiff = (lfoValue * lfoAmplitude)
        it.source:setPitch(it.pitch + lfoPicthDiff)
    end
end

function semitoneReleased(number)
    for i = 1, #playingSounds do
        if (playingSounds[i].semitone == number and not playingSounds[i].timeNoteOff) then
            playingSounds[i].timeNoteOff = love.timer.getTime()
        end
    end
end

function getSemitone(offset)
    return (octave * 12) + offset
end

function getPitch(semitone)
    local sampledAtSemitone = 60 + sampleTuning[sampleIndex]
    local usingSemitone = (semitone - sampledAtSemitone)
    local result = 2 ^ (usingSemitone / 12)

    return result
end

function fitKeyOffsetInScale(offset, scale)
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

function love.keyreleased(k)
    if (usingMap[k] ~= nil) then
        semitoneReleased(getSemitone(fitKeyOffsetInScale(usingMap[k], scale)))
    end
end

function love.keypressed(k)
    if (usingMap[k] ~= nil) then
        semitonePressed(getSemitone(fitKeyOffsetInScale(usingMap[k], scale)))
    end

    if k == 'z' then
        octave = math.max(octave - 1, 0)
        print("Octave:", octave)
    elseif k == 'x' then
        octave = math.min(octave + 1, max_octave)
        print("Octave:", octave)
    end
    if k == 'tab' then
        sampleIndex = (sampleIndex % #samples) + 1
        sample = samples[sampleIndex]
        print('Sample:', sampleIndex, sample.name)
    end

    if k == 'c' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] - 1
        print('Tuning:', sample.name, sampleTuning[sampleIndex])
    end
    if k == 'v' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] + 1
        print('Tuning:', sample.name, sampleTuning[sampleIndex])
    end
    if k == 'b' then
        toggleScale()
    end

    if k == 'escape' then love.event.quit() end
end

function playMetronomeSound()
    local snd = metronome_click:clone()
    if (math.floor(beat) % barsInMeasure == 1) then
        snd:setVolume(1)
    else
        snd:setVolume(.5)
    end
    snd:play()
end

function love.update(dt)
    updateBeatsAndTicks(dt)
    cleanPlayingSounds()
    updateADSREnvelopesForPlayingSounds(dt)
    updatePlayingSoundsWithLFO()
end

function updateBeatsAndTicks(dt)
    beat = beat + (dt * (bpm / 60))
    local tick = ((beat % 1) * (96))

    if (math.floor(beat) ~= math.floor(lastBeat)) then
        --  playMetronomeSound()
    end

    lastBeat = beat
    lastTick = tick
end

function love.draw()
    --  love.graphics.print(#playingSounds, 0, 0)
end
