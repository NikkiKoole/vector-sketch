local _thread
local channel             = {};
channel.audio2main        = love.thread.getChannel("audio2main")
channel.main2audio        = love.thread.getChannel("main2audio")

getMessageFromAudioThread = function()
    local v = channel.audio2main:pop();
    local error = _thread:getError()
    assert(not error, error)
    return v
end

sendMessageToAudioThread  = function(msg)
    channel.main2audio:push(msg)
end

local os                  = love.system.getOS()
if os == 'iOS' or os == 'Android' then
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
else
    -- local code = getFileContents('lib/audio.lua')
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
end



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


function love.load()
    myBeat = 0
    myBeatInMeasure = 4

    bigfont = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    smallfont = love.graphics.newFont('WindsorBT-Roman.otf', 24)
    musicfont = love.graphics.newFont('NotoMusic-Regular.ttf', 48)


    missedTicks = {}
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

    channelIndex = 1
    recordedData = {}

    -- adsr stuff
    defaultAttackTime = 0.1
    defaultDecayTime = 0.1
    defaultSustainLevel = 0.7
    defaultReleaseTime = .03

    -- measure/beat

    sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
    --resetBeatsAndTicks()

    -- metronome sounds


    -- octave stuff
    max_octave = 8
    octave = 4

    -- sample stuff
    local sampleFiles = {
        'lulla/kiksynth', 'lulla/milkjar', 'lulla/pizzi', 'lulla/C4-pitchpedal',
        'lulla/soft sk', 'lulla/rainbows', 'lulla/receiver', 'lulla/C3', 'lulla/lobassy',
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
    local range = getPitchVariationRange(number, 0) -- this decides how 'off' notes can be
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
        table.insert(recordedData, {
            takeIndex = takeIndex or 0,
            channelIndex = channelIndex,
            sampleIndex = sampleIndex,
            beat = math.floor(lastBeat),
            tick = math.floor(lastTick),
            semitone = number,
            duration = 0,
        })
        --print('should record press @', sampleIndex, math.floor(lastBeat), math.floor(lastTick))
    end

    semitoneTriggered(number)
end

function semitoneReleased(number)
    -- this probably needs to end up checking if current instrument is the same..
    if recording then
        -- print('should record release @', sampleIndex, math.floor(lastBeat), math.floor(lastTick))
        for i = 1, #recordedData do
            if recordedData[i].semitone == number and recordedData[i].duration == 0 then
                local deltaBeats = (math.floor(lastBeat) - recordedData[i].beat)
                local deltaTicks = (math.floor(lastTick) - recordedData[i].tick) -- this could end up negtive I think, what does that mean ?
                local totalDeltaTicks = (deltaBeats * 96) + deltaTicks

                recordedData[i].duration = totalDeltaTicks

                recordedData[i].beatOff = math.floor(lastBeat)
                recordedData[i].tickOff = math.floor(lastTick)
            end
        end
    end
    for i = 1, #playingSounds do
        if (playingSounds[i].semitone == number and not playingSounds[i].timeNoteOff) then
            playingSounds[i].timeNoteOff = love.timer.getTime()
        end
    end
end

function handlePlayingRecordedData()
    if false then
        local beat = math.floor(lastBeat)
        local tick = math.floor(lastTick)

        --missedTicks
        for j = 1, #missedTicks do
            local t = missedTicks[j]
            local b = beat
            if (t > tick) then
                --print('oh dear, missed tick over the beat boundary', t, tick)
                b = beat - 1
            end
            for i = 1, #recordedData do
                if recordedData[i].beatOff == b and recordedData[i].tickOff == t then
                    print('triggered a missed release')
                    semitoneReleased(recordedData[i].semitone)
                end
                if recordedData[i].beat == b and recordedData[i].tick == t then
                    print('triggered a missed tick')
                    semitoneTriggered(recordedData[i].semitone)
                end
            end
        end
        missedTicks = {}

        for i = 1, #recordedData do
            if recordedData[i].beatOff == beat and recordedData[i].tickOff == tick then
                semitoneReleased(recordedData[i].semitone)
            end
            if recordedData[i].beat == beat and recordedData[i].tick == tick then
                semitoneTriggered(recordedData[i].semitone)
            end
        end
    end
end

local function cleanPlayingSounds()
    local now = love.timer.getTime()
    for i = #playingSounds, 1, -1 do
        local it = playingSounds[i]
        if (it.timeNoteOff and it.timeNoteOff < now and not it.source:isPlaying()) then
            it.source:release()
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
        --sendMessageToAudioThread({ type = "SemitonePressed", data = getSemitone(fitKeyOffsetInScale(usingMap[k], scale)) });
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

    --  sendMessageToAudioThread({ type = "key", data = k });

    if k == 'escape' then love.event.quit() end

    if k == 'space' then
        playing = not playing

        if not playing then
            sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
            sendMessageToAudioThread({ type = "paused", data = true });
            --resetBeatsAndTicks()
        end
        if playing then
            sendMessageToAudioThread({ type = "paused", data = false });
            recording = false
        end
    end

    if k == 'return' then
        sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
        --resetBeatsAndTicks()
        recording = not recording
        if not recording then
            sendMessageToAudioThread({ type = "paused", data = true });
        end
        if recording then
            sendMessageToAudioThread({ type = "paused", data = false });
            recordedData = {}
            playing = false
        end
    end
end

function love.update(dt)
    local msg = getMessageFromAudioThread()
    if msg then
        if msg.type == 'beatUpdate' then
            myBeat = msg.data.beat
            myBeatInMeasure = msg.data.beatInMeasure
        end
        --print(msg.type)
    end
    if recording or playing then
        --   updateBeatsAndTicks(dt)
    end
    if playing then
        handlePlayingRecordedData()
    end
    cleanPlayingSounds()
    updateADSREnvelopesForPlayingSounds(dt)
    updatePlayingSoundsWithLFO()
end

function drawDrumMachineGrid()
    local columns = 32
    local rows = 6
    local w, h = love.graphics.getDimensions()

    local font = smallfont
    love.graphics.setFont(font)
    local cellW = font:getWidth('X')
    local cellH = 32
    local labels = { 'kick', 'snare ', 'hat', 'ohat', 'tom', 'cym', 'clap', 'perc', 'rim', 'guiro', 'clav', 'shake' }
    --local label = labels[math.ceil(love.math.random() * #labels)]
    local fw = font:getWidth('WWWW')
    local startY = 100

    -- first draw the grid
    for y = 0, #labels - 1 do
        love.graphics.setColor(1, 1, 1, .3)
        for i = 0, columns - 1 do
            love.graphics.rectangle('line', fw + i * cellW, startY + y * cellH, cellW, cellH)
        end
    end

    -- then the labels (also filled in letters)
    for y = 0, #labels - 1 do
        love.graphics.setColor(1, 1, 1, .5)
        for i = 0, columns - 1 do
            --love.graphics.rectangle('line', fw + i * cellW, startY + y * cellH, cellW, cellH)
            if (love.math.random() < 0.2) then
                -- local char = 'k'
                local chars = { '.', 'k', 'X', 'O', 'b', 'I', ',', '>', '#', '%', '^' }
                local char = chars[math.ceil(love.math.random() * #chars)]
                local offX = (cellW - font:getWidth(char)) / 2
                local offY = (cellH - font:getHeight()) / 2
                love.graphics.print(char, offX + fw + i * cellW, offY + startY + y * cellH)
            end
        end
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(' ' .. labels[y + 1], 0, startY + y * cellH)
    end

    --local cellW = w/columns
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    -- drawDrumMachineGrid()
    if (recording or playing) then
        local font = bigfont
        love.graphics.setFont(font)

        local str = string.format("%02d", math.floor(myBeat / myBeatInMeasure)) ..
            '|' .. string.format("%01d", math.floor(myBeat % myBeatInMeasure))

        love.graphics.print(str, font:getHeight(), 0)
        if (math.floor(myBeat / myBeatInMeasure) < 0) then
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


    local font = smallfont
    love.graphics.setFont(font)

    local instrument = samples[sampleIndex].name .. ' ' .. octave
    local w, h = love.graphics:getDimensions()
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print(instrument, w - font:getWidth(instrument), 0)



    local stats = love.graphics.getStats()
    local memavg = collectgarbage("count") / 1000
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = tostring(love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    local debugstring = mem .. '  ' .. vmem .. '  ' .. draws .. ' ' .. fps
    love.graphics.print(debugstring, 0, h - font:getHeight())

    -- love.graphics.print('𝄞𝄵𝆑𝄆 𝄞𝄰 𝅗𝅥𝅘𝅥𝅮𝅘𝅥𝅮𝅘𝅥 𝄇𝄞𝅘𝅥𝅯 𝄃 𝄞♯ 𝅘𝅥𝄾 𝄀 ♭𝅗𝅥♫ 𝆑𝆏 𝄂')
end
