local function prepareSamples(names)
    local result = {}
    for i = 1, #names do
        local name = names[i]
        local path = 'samples/' .. name .. ".wav"
        local info = love.filesystem.getInfo(path)
        if info then
            result[i] = { name = name, source = love.audio.newSource(path, 'static') }
        else
            print('file not found!', path)
        end
    end
    return result
end

local function resetBeatsAndTicks()
    lastTick = 0
    lastBeat = beatInMeasure * -1 * countInMeasures
    beat = beatInMeasure * -1 * countInMeasures
    tick = 0
end




function love.load()
    local bigfont = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    local smallfont = love.graphics.newFont('WindsorBT-Roman.otf', 24)
    local musicfont = love.graphics.newFont('NotoMusic-Regular.ttf', 48)
    font = musicfont
    love.graphics.setFont(font)


    playingSounds = {}
    
    -- livelooping
    recording = false
    playing = false

    -- ok the data structure for recording things:
    -- we have a limited amount of channels in a song (say 1-9)
    -- you can view a channel as an instrument: an instrument is a sample + adsr envelope
    
    -- when we are recording we are doing that for 1 channel. 
    -- also recoring a loop means we can maybe record multiple takes.
    -- yeah a take should be a thing 
    -- that implies you want to either start with  nothing and play as long as you want
    -- OR do a predefined set of measures a couple of times/takes until its good enough   
    -- OR you could also do a predefined set of measures and when you are done you layer on top.

    channel = 1
    

    -- adsr stuff
    defaultAttackTime = 0.1
    defaultDecayTime = 0.1
    defaultSustainLevel = 0.7
    defaultReleaseTime = .03

    -- measure/beat
    beatInMeasure = 4
    countInMeasures = 0
    bpm = 90

    resetBeatsAndTicks()

    -- metronome sounds
    metronome_click = love.audio.newSource("samples/cr78/Clave.wav", "static")

    -- octave stuff
    max_octave = 8
    octave = 4

    -- sample stuff
    local sampleFiles = {
        'lulla/kiksynth', 'lulla/milkjar', 'lulla/pizzi',
        'lulla/soft sk', 'lulla/rainbows', 'lulla/receiver',
        "ac/0x722380", "ac/0x14146A0", "ac/0xC3B760",
        "ANCR I Mallet 7", "legow/VibraphoneMid-MT70",
        "legow/Synth SineFiltered1", "legow/Bass BoringSimple",
        "legow/Synth SoftTooter", "junopiano",
        "synth03", "4", "decent/chord-organ-decentc2",
        "rhodes", "sf1-015", 'wavparty/melodic-tunedC06',
        'wavparty/bass-tunedC05', 'wavparty/bass-tunedC06', 'wavparty/synth22', 'wavparty/synth36', 'mello/C3-3',
        'ratchet/downstroke (10)', 'ratchet/downstroke (11)', 'ratchet/downstroke (12)',
        'mt70/top1', 'mt70/top2', 'mt70/top3', 'mt70/Bdrum1'
    }
    samples = prepareSamples(sampleFiles)

    sampleIndex = 1
    sample = samples[sampleIndex]

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
    local range = getPitchVariationRange(number, 1 / 7)  -- this decides how 'off' notes can be
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
    if recording then
        print('should record press @', sampleIndex, math.floor(lastBeat), math.floor(lastTick))
    end

    semitoneTriggered(number)
end

function semitoneReleased(number)
    -- this probably needs to end up checking if current instrument is the same..
    if recording then 
        print('should record release @', sampleIndex, math.floor(lastBeat), math.floor(lastTick))
    end
    for i = 1, #playingSounds do
        if (playingSounds[i].semitone == number and not playingSounds[i].timeNoteOff) then
            playingSounds[i].timeNoteOff = love.timer.getTime()
        end
    end
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
    local attackTime = defaultAttackTime
    local decayTime = defaultDecayTime
    local sustainLevel = defaultSustainLevel
    local releaseTime = defaultReleaseTime
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
        local lfoPitchDelta = (lfoValue * lfoAmplitude)
        it.source:setPitch(it.pitch + lfoPitchDelta)
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

    if k == 'space' then
        playing = not playing
        if not playing then
            resetBeatsAndTicks()
        end
        if playing then
            recording = false
        end
    end

    if k == 'return' then
        recording = not recording
        if not recording then
            resetBeatsAndTicks()
        end
        if recording then
            playing = false
        end
    end
end

function playMetronomeSound()
    local snd = metronome_click:clone()
    if (math.floor(beat) % beatInMeasure == 1) then
        snd:setVolume(1)
    else
        snd:setVolume(.5)
    end
    snd:play()
end

function love.update(dt)
    if recording or playing then
        updateBeatsAndTicks(dt)
    end
    cleanPlayingSounds()
    updateADSREnvelopesForPlayingSounds(dt)
    updatePlayingSoundsWithLFO()
end

function updateBeatsAndTicks(dt)
    beat = beat + (dt * (bpm / 60))
    local tick = ((beat % 1) * (96))

    if (math.floor(beat) ~= math.floor(lastBeat)) then
        playMetronomeSound()
    end

    lastBeat = beat
    lastTick = tick
end

function love.draw()
    if (recording or playing) then
        love.graphics.setColor(1, 1, 1)
        local str = string.format("%02d", math.floor(lastBeat / beatInMeasure)) ..
            '|' .. string.format("%01d", math.floor(lastBeat % beatInMeasure))

        love.graphics.print(str, font:getHeight(), 0)
        if (math.floor(lastBeat / beatInMeasure) < 0) then
            love.graphics.setColor(1, 1, 0)
        else
            if recording then
                love.graphics.setColor(1, 0, 0)
            else
                love.graphics.setColor(0, 1, 0)
            end
        end
        love.graphics.circle('fill', font:getHeight() / 2, font:getHeight() / 2, font:getHeight() / 3)
    end
    love.graphics.print('𝄞𝄵𝆑𝄆 𝄞𝄰 𝅗𝅥𝅘𝅥𝅮𝅘𝅥𝅮𝅘𝅥 𝄇𝄞𝅘𝅥𝅯 𝄃 𝄞♯ 𝅘𝅥𝄾 𝄀 ♭𝅗𝅥♫ 𝆑𝆏 𝄂') 
end
