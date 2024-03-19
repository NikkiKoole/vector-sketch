require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')

local min, max            = ...
local paused              = true
local now                 = love.timer.getTime()
local time                = 0
local lastTick            = 0
local lastBeat            = -1
local beat                = 0
local tick                = 0
local beatInMeasure       = 4
local countInMeasures     = 0
local bpm                 = 100

local metronome_click     = love.audio.newSource("samples/cr78/Clave.wav", "static")

local channel             = {};
channel.audio2main        = love.thread.getChannel("audio2main"); -- from thread
channel.main2audio        = love.thread.getChannel("main2audio"); --from main

local missedTicks         = {}
local playingSounds       = {}
local recordedData        = {}

local playing             = false
local recording           = false

-- adsr stuff
local defaultAttackTime   = 0.2
local defaultDecayTime    = 0.1
local defaultSustainLevel = 0.7
local defaultReleaseTime  = .03


local function generateADSR(it, now)
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

local function generateSineLFO(time, lfoFrequency)
    return math.sin(2 * math.pi * lfoFrequency * time)
end

local function getPitch(semitone)
    local sampledAtSemitone = 60 + 0 --sampleTuning[sampleIndex]
    local usingSemitone = (semitone - sampledAtSemitone)
    local result = 2 ^ (usingSemitone / 12)

    return result
end

local function getPitchVariationRange(semitone, offsetInSemitones)
    local oneUp = getPitch(semitone + 1)
    local oneDown = getPitch(semitone - 1)
    local range = (oneUp - oneDown) * offsetInSemitones
    return range
end

local function updatePlayingSoundsWithLFO()
    for i = 1, #playingSounds do
        local it = playingSounds[i]
        local time = love.timer.getTime() - it.timeNoteOn
        local lfoValue = generateSineLFO(time, .15)               -- PARAMTERIZE THIS
        local range = getPitchVariationRange(it.semitone, 1 / 12) -- PARAMTERIZE THIS
        local lfoAmplitude = range
        local lfoPitchDelta = (lfoValue * lfoAmplitude)
        it.source:setPitch(it.pitch + lfoPitchDelta)
    end
end


local function cleanPlayingSounds()
    local now = love.timer.getTime()
    for i = #playingSounds, 1, -1 do
        local it = playingSounds[i]
        if (it.timeNoteOff and it.timeNoteOff < now) then
            if not it.source:isPlaying() then
                it.source:release()
                table.remove(playingSounds, i)
                channel.audio2main:push({ type = 'numPlayingSounds', data = { numbers = #playingSounds } })
            end
        end
    end
end


local function semitoneTriggered(number, sample)
    local source = sample.source:clone()
    local pitch = getPitch(number)
    local range = getPitchVariationRange(number, 0) -- PARAMTERIZE THIS
    local pitchOffset = love.math.random() * range - range / 2
    source:setPitch(pitch + pitchOffset)
    source:setVolume(0)
    source:play()

    table.insert(playingSounds, {
        pitch = pitch + pitchOffset,
        source = source,
        semitone = number,
        sampleIndex = sampleIndex,
        timeNoteOn = love.timer.getTime()
    })
    channel.audio2main:push({ type = 'numPlayingSounds', data = { numbers = #playingSounds } })
end

local function semitoneReleased(semitone)
    if recording then
        -- print('should record release @', sampleIndex, math.floor(lastBeat), math.floor(lastTick))
        for i = 1, #recordedData do
            if recordedData[i].semitone == semitone and recordedData[i].duration == 0 then
                local deltaBeats = (math.floor(lastBeat) - recordedData[i].beat)
                local deltaTicks = (math.floor(lastTick) - recordedData[i].tick) -- this could end up negtive I think, what does that mean ?
                local totalDeltaTicks = (deltaBeats * 96) + deltaTicks

                recordedData[i].duration = totalDeltaTicks

                recordedData[i].beatOff = math.floor(lastBeat)
                recordedData[i].tickOff = math.floor(lastTick)
            end
        end
        --print(#recordedData)
    end
    for i = 1, #playingSounds do
        if (playingSounds[i].semitone == semitone and not playingSounds[i].timeNoteOff) then
            playingSounds[i].timeNoteOff = love.timer.getTime()
        end
    end
end

function handlePlayingRecordedData()
    if true then
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
                semitoneTriggered(recordedData[i].semitone, recordedData[i].sample)
            end
        end
    end
end

local function resetBeatsAndTicks()
    lastTick = 0
    lastBeat = beatInMeasure * -1 * countInMeasures
    beat     = beatInMeasure * -1 * countInMeasures
    tick     = 0
end

local function playMetronomeSound()
    local snd = metronome_click:clone()
    if (math.floor(beat) % beatInMeasure == 1) then
        snd:setVolume(1)
    else
        snd:setVolume(.5)
    end
    snd:play()
end


while (true) do
    local n = love.timer.getTime()
    local delta = n - now
    now = n
    if not paused then
        beat = beat + (delta * (bpm / 60))
        tick = ((beat % 1) * (96))

        if math.floor(tick) - math.floor(lastTick) > 1 then
            for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
                table.insert(missedTicks, i)
            end
        end


        if (math.floor(beat) ~= math.floor(lastBeat)) then
            if recording == true then
                playMetronomeSound()
            end
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end

        if playing then
            handlePlayingRecordedData()
        end
        -- handle the missed ticks here baby
        --
        missedTicks = {}
        lastBeat = beat
        lastTick = tick
    end

    updateADSREnvelopesForPlayingSounds(delta)
    updatePlayingSoundsWithLFO()

    local sleepForMultiplier = math.ceil(bpm / 50)
    local sleepFor = 1.0 / (96 * sleepForMultiplier)
    love.timer.sleep(sleepFor)

    -- using this i can sleep for a good amount (no missed ticks)
    -- but also will sleep less if the bpm goes up,
    -- testing it i see missed ticks only >400 bpm.  RAVE ON!!

    cleanPlayingSounds()

    local v = channel.main2audio:pop();
    if v then
        if v.type == 'resetBeatsAndTicks' then
            resetBeatsAndTicks()
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end
        if v.type == 'paused' then
            paused = v.data
            now    = love.timer.getTime()
        end
        if v.type == 'semitoneReleased' then
            local semitone = v.data.semitone
            semitoneReleased(semitone)
        end
        if v.type == 'semitonePressed' then
            local semitone = v.data.semitone
            local channelIndex = v.data.channelIndex
            local sampleIndex = v.data.sampleIndex
            local takeIndex = v.data.takeIndex
            local sample = v.data.sample
            semitoneTriggered(semitone, sample)
            if recording == true then
                table.insert(recordedData, {
                    takeIndex = takeIndex or 0,
                    channelIndex = channelIndex,
                    sampleIndex = sampleIndex,
                    sample = sample,
                    beat = math.floor(lastBeat),
                    tick = math.floor(lastTick),
                    semitone = semitone,
                    duration = 0,
                })
            end
        end
        if v.type == 'mode' then
            if v.data == 'play' then
                playing = true
                recording = false
            end
            if v.data == 'record' then
                playing = false
                recording = true
            end
        end
        --if v.type == 'key' then
        --print(v.data)
        --end
    end
end
