require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')


-- Linn often used a timing resolution of 96 parts per quarter note (PPQN),
-- meaning that each quarter note is subdivided into 96 equal parts.
-- This high resolution allows for very precise timing and sequencing of musical events,
local PPQN              = 96

local min, max          = ...
local paused            = true
local now               = love.timer.getTime()
local time              = 0
local lastTick          = 0
local lastBeat          = -1
local beat              = 0
local tick              = 0
local beatInMeasure     = 4
local countInMeasures   = 0
--local bpm             = 90
--local swing           = 50
local metronome_click   = love.audio.newSource("samples/cr78/Rim Shot.wav", "static")

local channel           = {};
channel.audio2main      = love.thread.getChannel("audio2main"); -- from thread
channel.main2audio      = love.thread.getChannel("main2audio"); --from main

local missedTicks       = {}
local playingSounds     = {} -- playingSounds are just for the melodic sounds.

local playingDrumSounds = {}

local drumkit           = {}
local drumgrid          = {}

local samples           = {}
local futureDrumNotes   = {}

local playing           = false
local recording         = false

--local sampleTuning        = {}
local instruments       = {}
local instrumentIndex   = 1

local recordedData      = {}
local recordedClips     = {}

local uiData            = nil
local mixerData         = nil

local function generateADSR(it, now)
    local adsr = instruments[it.instrumentIndex].adsr
    local attackTime = adsr.attack
    local decayTime = adsr.decay
    local sustainLevel = adsr.sustain
    local releaseTime = adsr.release
    local startTime = it.timeNoteOn

    local endTime

    if it.source:isLooping() then
        endTime = it.timeNoteOff
    else
        local duration = it.source:getDuration('seconds')
        endTime = it.timeNoteOff or startTime + duration
    end

    local envelopeValue = 1
    if now <= startTime + attackTime then
        envelopeValue = (now - startTime) / attackTime
    elseif now <= startTime + attackTime + decayTime then
        envelopeValue = 1 - (1 - sustainLevel) * ((now - startTime - attackTime) / decayTime)
    elseif endTime == nil or now <= (endTime - releaseTime) then
        envelopeValue = sustainLevel
    else
        local releaseDuration = now - endTime
        envelopeValue = sustainLevel * math.exp(-releaseDuration / releaseTime)
        if it.source:isLooping() and envelopeValue < 0.001 then
            it.source:stop()
        end
    end

    return envelopeValue
end



local function generateSquareLFO(time, lfoFrequency)
    local phase = time * lfoFrequency
    return (math.floor(phase) % 2 == 0) and 1 or -1
end

local function generateTriangleLFO(time, lfoFrequency)
    local phase = time * lfoFrequency
    return 2 * math.abs((phase - 0.25 * math.floor(4 * phase + 0.5)) - 0.5) - 1
end

local function generateRoundedTriangleLFO(time, lfoFrequency)
    local phase = time * lfoFrequency
    return 2 * (0.5 - math.abs(phase - math.floor(phase + 0.5))) - 1
end
--generatePulseLFO: Produces a pulse wave LFO with a specified duty cycle (percentage of time spent at the maximum amplitude).
local function generatePulseLFO(time, lfoFrequency, dutyCycle)
    local phase = time * lfoFrequency
    return (phase % 1 < dutyCycle) and 1 or -1
end

local function generateSineLFO(time, lfoFrequency)
    return math.sin(2 * math.pi * lfoFrequency * time)
end
local function generateNoiseLFO(time, lfoFrequency)
    return love.math.noise(2 * math.pi * lfoFrequency * time)
end
local function generateSawtoothLFO(time, lfoFrequency)
    local phase = time * lfoFrequency
    return 2 * (phase % 1) - 1
end
local function generateReverseSawtoothLFO(time, lfoFrequency)
    local phase = time * lfoFrequency
    return 1 - 2 * (phase % 1)
end
local function generateExponentialDecayLFO(time, lfoFrequency, decayRate)
    local phase = time * lfoFrequency
    return math.exp(-decayRate * phase) * 2 - 1
end

local function getUntunedPitch(semitone)
    local sampledAtSemitone = 60
    local usingSemitone = (semitone - sampledAtSemitone)
    local result = 2 ^ (usingSemitone / 12)
    return result
end

local function getUntunedPitchVariationRange(semitone, offsetInSemitones)
    local oneUp = getUntunedPitch(semitone + 1)
    local oneDown = getUntunedPitch(semitone - 1)
    local range = (oneUp - oneDown) * offsetInSemitones
    return range
end

local function getPitch(semitone, tuning)
    local sampledAtSemitone = 60 + tuning
    local usingSemitone = (semitone - sampledAtSemitone)
    local result = 2 ^ (usingSemitone / 12)

    return result
end

local function getPitchVariationRange(semitone, offsetInSemitones, tuning)
    local oneUp = getPitch(semitone + 1, tuning)
    local oneDown = getPitch(semitone - 1, tuning)
    local range = (oneUp - oneDown) * offsetInSemitones
    return range
end

local function updateADSREnvelopesForPlayingSounds(dt)
    local now = love.timer.getTime()
    for i = 1, #playingSounds do
        local it = playingSounds[i]
        local value = generateADSR(it, now)
        value = value * (uiData and uiData.instrumentsVolume or 1)
        it.volume = value
        --  print(value)
        --it.source:setVolume(value)
    end
end

local function updatePlayingSoundsWithLFO()
    for i = 1, #playingSounds do
        local useLFO = true

        -- hoeveel sec oduurt 1/16 th ?

        if useLFO then
            local it            = playingSounds[i]
            local timeThis      = love.timer.getTime() - it.timeNoteOn -- PARAMTERIZE THIS (usefull when doing sine)
            --local lfoValue      = generateSawtoothLFO(timeThis, .25)   -- PARAMTERIZE THIS
            local lfoValue      = generateNoiseLFO(timeThis, .25)      -- PARAMTERIZE THIS
            --local lfoValue      = generateExponentialDecayLFO(timeThis, .5, 10)
            local tuning        = instruments[it.instrumentIndex].realtimeTuning
            local range         = getPitchVariationRange(it.semitone, 1 / 12, tuning) -- PARAMTERIZE THIS
            local lfoAmplitude  = range
            local lfoPitchDelta = (lfoValue * lfoAmplitude)



            it.source:setPitch(it.pitch + lfoPitchDelta)


            local volume = it.volume
            local useVolumeLFO = false
            if useVolumeLFO then
                local freqLfo = (generateExponentialDecayLFO(timeThis, 1, 1) + 1) / 2

                local lfVolume = (generateSineLFO(timeThis, 1 / freqLfo) + 1) / 2

                -- local lfoVolumeValue = ((generateExponentialDecayLFO(timeThis, 1 / freqLfo, 1) + 1) / 2)
                -- print(lfoVolumeValue)
                --if it.volume > 0.5 then
                volume = it.volume * lfVolume
                --if volume < 0.02 then volume = 0 end
                --  print(i, volume)
            end
            it.source:setVolume(volume)

            -- print('*****')
            -- print(it.pitch + lfoPitchDelta)
            -- print(it.volume * lfoVolumeValue)
            --end
        end
    end
end

local function cleanPlayingSounds()
    local now = love.timer.getTime()
    --if (#missedTicks > 0) then
    --print('missed a tick shoul clean it too', #missedTicks)
    --end
    for i = #playingSounds, 1, -1 do
        local it = playingSounds[i]
        if not it.timeNoteOff then
            -- print('ok wy ?')
        end
        if (it.timeNoteOff and it.timeNoteOff < it.timeNoteOn) then
            -- print('this is weird', it.timeNoteOn)
        end
        if (it.timeNoteOff and it.timeNoteOff < now) then
            if not it.source:isPlaying() then
                it.source:release()
                table.remove(playingSounds, i)
                channel.audio2main:push({ type = 'numPlayingSounds', data = { numbers = #playingSounds } })
            end
        end
    end
end

local function semitoneTriggered(number, instrumentIndex)
    local sample = instruments[instrumentIndex].sample
    -- local sampleIndex = instruments[instrumentIndex].sampleIndex
    -- local source = samples[sampleIndex].source:clone()
    local source = sample.source:clone()
    local tuning = instruments[instrumentIndex].realtimeTuning
    local pitch = getPitch(number, tuning)
    local range = getPitchVariationRange(number, 0, tuning) -- PARAMTERIZE THIS
    local pitchOffset = love.math.random() * range - range / 2
    --if samples[sampleIndex].cycle then
    if sample.cycle then
        source:setLooping(true)
    end


    local monophonic = false
    if monophonic == true then
        local foundInstrumentSoundAlready = nil
        for i = 1, #playingSounds do
            if (playingSounds[i].instrumentIndex == instrumentIndex) then
                foundInstrumentSoundAlready = playingSounds[i]
            end
        end
        if foundInstrumentSoundAlready then
            --foundInstrumentSoundAlready.source:stop()
            foundInstrumentSoundAlready.source:setPitch(pitch + pitchOffset)

            foundInstrumentSoundAlready.pitch = pitch + pitchOffset
            --foundInstrumentSoundAlready.source = source
            foundInstrumentSoundAlready.semitone = number
            foundInstrumentSoundAlready.instrumentIndex = instrumentIndex
            foundInstrumentSoundAlready.timeNoteOn = love.timer.getTime()
        end
    end
    if not foundInstrumentSoundAlready or monophonic == false then
        source:setPitch(pitch + pitchOffset)
        source:setVolume(0)
        source:play()
        table.insert(playingSounds, {
            pitch = pitch + pitchOffset,
            source = source,
            volume = 0,
            semitone = number,
            instrumentIndex = instrumentIndex,
            timeNoteOn = love.timer.getTime()
        })
    end
    channel.audio2main:push({ type = 'numPlayingSounds', data = { numbers = #playingSounds } })
end

local function semitoneReleased(semitone, instrumentIndex)
    if recording then
        for i = 1, #recordedData do
            if recordedData[i].instrumentIndex == instrumentIndex then
                if recordedData[i].semitone == semitone and recordedData[i].duration == 0 then
                    local deltaBeats = (math.floor(lastBeat) - recordedData[i].beat)
                    local deltaTicks = (math.floor(lastTick) - recordedData[i].tick) -- this could end up negtive I think, what does that mean ?
                    local totalDeltaTicks = (deltaBeats * PPQN) + deltaTicks

                    recordedData[i].duration = totalDeltaTicks
                    recordedData[i].beatOff = math.floor(lastBeat)
                    recordedData[i].tickOff = math.floor(lastTick)
                end
            end
        end
    end

    -- use this here..instrumentIndex
    for i = 1, #playingSounds do
        if (playingSounds[i].instrumentIndex == instrumentIndex) then
            if (playingSounds[i].semitone == semitone and not playingSounds[i].timeNoteOff) then
                playingSounds[i].timeNoteOff = love.timer.getTime()
            end
        end
    end
end

function getGateOffBeatAndTick(snd, pitch, bpm, beat, tick, gateValue)
    local secondsToFinishAtThisPitch = (snd:getDuration() / pitch) * gateValue
    local bb = secondsToFinishAtThisPitch * (bpm / 60)
    local futureTick = math.ceil(tick + (bb * PPQN))
    local futureBeat = beat

    if (futureBeat == beat and futureTick == tick) then
        futureTick = tick + 2
    end

    if futureTick >= PPQN then
        futureTick = futureTick - PPQN
        futureBeat = futureBeat + 1
    end

    return futureBeat, futureTick
end

function doTheGateClosing(beat, tick)
    for i = #playingDrumSounds, 1, -1 do
        local pd = playingDrumSounds[i]


        if pd.gateCloseBeat == beat and pd.gateCloseTick == tick then
            if pd.source:tell() == 0 then
                --print(pd.source)
                --print(beat, pd.beatOn, pd.gateCloseBeat, ':', tick, pd.tickOn, pd.gateCloseTick)
            end
            pd.source:setVolume(0)
            --end

            --print('closing gate', pd.source:tell(), pd.source:getDuration())
        end

        if not pd.source:isPlaying() then
            pd.source:release()
            table.remove(playingDrumSounds, i)
        else

        end
    end
end

function doHandleFutureDrumNotes(beat, tick)
    for i = #futureDrumNotes, 1, -1 do
        local f = futureDrumNotes[i]
        if (f.beat == beat and f.tick == tick) then
            local volume = f.volume or 1
            volume = volume * (uiData and uiData.drumVolume or 1) * (mixerData and mixerData[i].volume or 1)
            if f.volume then
                f.source:setVolume(volume)
            end
            if f.pitch then
                f.source:setPitch(f.pitch)
            end
            f.source:play()

            table.insert(playingDrumSounds, {
                source = f.source,
                pitch = f.pitch,
                timeOn = love.timer.getTime(),
                beatOn = f.beat,
                tickOn = f.tick,
                -- drumIndex = ?,
                gateCloseBeat = f.gateCloseBeat,
                gateCloseTick = f.gateCloseTick,
                volume = volume
            })


            table.remove(futureDrumNotes, i)
        end
    end
end

function createFutureDrumNote(beat, tick, delay, source, pitch, volume, gate, bpm)
    local futureTick = tick + delay
    local futureBeat = beat
    if futureTick >= PPQN then
        futureTick = futureTick - PPQN
        futureBeat = futureBeat + 1
    end
    local gateCloseBeat, gateCloseTick = getGateOffBeatAndTick(source, pitch,
        bpm, futureBeat, futureTick, gate)
    local future = {
        tick = futureTick,
        beat = futureBeat,
        source = source,
        pitch = pitch,
        volume = volume,
        gateCloseBeat = gateCloseBeat,
        gateCloseTick = gateCloseTick
    }
    return future
end

function doHandleDrumNotes(beat, tick, bpm)
    -- why % 24 ??
    -- because the PPQN = 96 so PartsPer16th note is 24!
    -- drumgrid is subdivided in 16ths
    -- -- how to apply swing?
    -- 50% is no swing
    -- 100% is way too much swing, now it will fall
    -- the number we write is the percentage the first (in other words 16th before this gets.)
    --
    local swing = uiData and uiData.swing or 50
    local delaySwungNote = math.ceil(((swing / 100) * 48) - 24)

    local isSwung = (tick % 48 == delaySwungNote)
    local shouldDelayEvenNotes = swing ~= 50
    local isEvenNoteUndelayed = tick % 48 == 0

    if ((tick % 24 == 0 and isSwung == false) or isSwung) then
        if (shouldDelayEvenNotes and isEvenNoteUndelayed) then
            -- here we do nothing, because even noted should be delayed and whe get here, the undelayed even note
        else
            -- print(math.floor(tick))
            local column = ((beat % beatInMeasure) * 4) + (tick / 24)
            if isSwung then
                column = ((beat % beatInMeasure) * 4) + ((tick - delaySwungNote) / 24)
            end

            for i = 1, #drumkit.order do
                local cell = drumgrid[column + 1][i]
                local dontTrigger = false
                if cell.on and cell.trig ~= nil then
                    if love.math.random() > cell.trig then
                        dontTrigger = true
                    end
                end
                if cell.on and not dontTrigger then
                    local key = drumkit.order[i]
                    --print(drumkit, drumkit[key], key)
                    if (drumkit[key] == nil) then
                        print(key)
                    end
                    local source = drumkit[key].source:clone()
                    local cellVolume = (cell.volume or 1) * (mixerData and mixerData[i].volume or 1)
                    local gate = cell.gate or 1
                    local allDrumsVolume = (uiData and uiData.drumVolume or 1)
                    local volume = cellVolume * allDrumsVolume
                    local semitoneOffset = math.ceil((uiData and uiData.allDrumSemitoneOffset or 0))

                    if cell.useRndP then
                        local pentaMinor = { 0, 3, 5, 7, 10 }

                        local scaleToPickFrom = {}
                        for si = cell.rndPOctMin or 0, cell.rndPOctMax or 0 do
                            if (cell.useRndPPentatonic) then
                                for j = 1, #pentaMinor do
                                    local o = pentaMinor[j] + (12 * si)
                                    table.insert(scaleToPickFrom, o)
                                end
                            else
                                for j = 0, 11 do
                                    local o = j + (12 * si)
                                    table.insert(scaleToPickFrom, o)
                                end
                            end
                        end
                        local picked = scaleToPickFrom[math.ceil(math.random() * #scaleToPickFrom)]
                        semitoneOffset = semitoneOffset + picked
                        -- print(#scaleToPickFrom)
                    end

                    local afterOffset = getUntunedPitch(60 + semitoneOffset + (cell and cell.semitoneOffset or 0))
                    local pitch = afterOffset

                    local gateCloseBeat, gateCloseTick = getGateOffBeatAndTick(source, pitch,
                        bpm, beat, tick, gate)

                    if source:getChannelCount() == 1 then
                        source:setPosition(cell.pan or 0, 0, 0)
                    else
                        print(key .. ' isnt MONO, so it cant be panned')
                    end

                    source:setVolume(volume)
                    source:setPitch(pitch)

                    if cell.delay and cell.delay > 0 then
                        --print('DO NOT PLAY DIRECTLY BUT DELAY ')
                        --print(cell.delay * PPQN)
                        local future = createFutureDrumNote(beat, tick, math.ceil(cell.delay * 24),
                            source, pitch,
                            volume, gate, bpm)
                        table.insert(futureDrumNotes, future)
                    else
                        source:play()
                        table.insert(playingDrumSounds, {
                            source = source,
                            pitch = pitch,
                            timeOn = love.timer.getTime(),
                            beatOn = beat,
                            tickOn = tick,
                            drumIndex = i,
                            gateCloseBeat = gateCloseBeat,
                            gateCloseTick = gateCloseTick,
                            volume = volume
                        })
                    end


                    if drumgrid[column + 1][i].flam == true then
                        local flamRepeat = 1
                        for j = 1, flamRepeat do
                            local future = createFutureDrumNote(beat, tick, (12 / flamRepeat),
                                drumkit[key].source:clone(), pitch,
                                volume, gate, bpm)


                            table.insert(futureDrumNotes, future)
                        end
                    end
                    --local echo = true
                    if cell.echo and cell.echo > 0 then
                        local volume = 0.75
                        local echoRepeats = cell.echo
                        local startDelay = 33

                        for k = 1, echoRepeats do
                            local delay = startDelay * k
                            local future = createFutureDrumNote(beat, tick, startDelay * k,
                                drumkit[key].source:clone(), pitch,
                                volume / k, gate, bpm)

                            table.insert(futureDrumNotes, future)
                        end
                    end
                end
            end
        end
    end
end

function handlePlayingDrumGrid()
    if uiData then
        local beat = math.floor(lastBeat)
        local tick = math.floor(lastTick)
        --  print(#missedTicks)

        for j = 1, #missedTicks do
            local t = missedTicks[j].tick
            local b = missedTicks[j].beat
            doTheGateClosing(b, t)
            doHandleFutureDrumNotes(b, t)
            doHandleDrumNotes(b, t, uiData.bpm)
        end

        -- gate closing for  the already playing drums
        doTheGateClosing(beat, tick)

        -- triggering future drum notes (flam/echo) when their time is there.
        doHandleFutureDrumNotes(beat, tick)

        doHandleDrumNotes(beat, tick, uiData.bpm)
    else
        --print('no ui data?')
    end
end

function doReplayRecorded(clip, beat, tick)
    --print(beat, tick)
    for i = 1, #clip do
        -- print(clip[i].beat, clip[i].tick, clip[i].beatOff, clip[i].tickOff)
        if clip[i].beatOff == beat and clip[i].tickOff == tick then
            -- print('released', beat, tick)
            semitoneReleased(clip[i].semitone, clip[i].instrumentIndex)
        end
        if clip[i].beat == beat and clip[i].tick == tick then
            --print('triggered', beat, tick)
            semitoneTriggered(clip[i].semitone, clip[i].instrumentIndex)
        end
    end
end

function handlePlayingRecordedData()
    if true then
        for i = 1, #recordedClips do
            for j = 1, #(recordedClips[i].clips) do
                local it = recordedClips[i].clips[j]



                if it.meta.isSelected then
                    --print('it is selected')
                    local loopRounder = it.meta and it.meta.loopRounder or 1
                    local beat = (math.floor(lastBeat) % loopRounder)
                    local tick = math.floor(lastTick)

                    local percentageDonePlaying = ((beat * PPQN) + tick) / (loopRounder * PPQN)
                    channel.audio2main:push({ type = 'looperPercentage', data = { percentage = percentageDonePlaying, instrumentIndex = i, clipIndex = j } })

                    for j = 1, #missedTicks do
                        local t = missedTicks[j].tick
                        local b = math.floor(missedTicks[j].beat % loopRounder)

                        doReplayRecorded(it, b, t)
                    end


                    doReplayRecorded(it, beat, tick)
                end
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
    local bpm = (uiData and uiData.bpm) or 90
    local n = love.timer.getTime()
    local delta = n - now
    now = n
    if not paused then
        beat = beat + (delta * (bpm / 60))
        tick = ((beat % 1) * (PPQN))
        --print(beat, tick)
        -- print((lastBeat - beat) * (PPQN), tick, lastTick)






        if (math.floor(beat) ~= math.floor(lastBeat)) then
            if recording == true then
                playMetronomeSound()
            end
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end
        if (math.floor(tick) ~= math.floor(lastTick)) then
            local diff = math.abs((lastBeat - beat) * (PPQN))
            if diff > 1 then
                if tick > lastTick then
                    for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
                        table.insert(missedTicks, { tick = i, beat = math.floor(beat) })
                    end
                else
                    for i = math.floor(lastTick) + 1, 95 do
                        table.insert(missedTicks, { tick = i, beat = math.floor(lastBeat) })
                    end
                    for i = 0, math.floor(tick) - 1 do
                        table.insert(missedTicks, { tick = i, beat = math.floor(beat) })
                    end
                end
            end

            channel.audio2main:push({ type = 'tickUpdate', data = { tick = math.floor(tick) } })
            if playing then
                handlePlayingRecordedData()
                handlePlayingDrumGrid()
            end
            if recording then
                handlePlayingRecordedData()
                handlePlayingDrumGrid()
            end
        end


        -- handle the missed ticks here baby
        --

        lastBeat = beat
        lastTick = tick
    end

    updateADSREnvelopesForPlayingSounds(delta)
    updatePlayingSoundsWithLFO()

    local sleepForMultiplier = math.ceil(bpm / 25)
    local sleepFor = 1.0 / (PPQN * sleepForMultiplier)
    --print(sleepFor)
    love.timer.sleep(sleepFor)

    -- using this i can sleep for a good amount (no missed ticks)
    -- but also will sleep less if the bpm goes up,
    -- testing it i see missed ticks only >400 bpm.  RAVE ON!!

    cleanPlayingSounds()
    missedTicks = {}
    local v = channel.main2audio:pop();
    if v then
        if v.type == 'clips' then
            recordedClips = v.data
        end
        if v.type == 'samples' then
            samples = v.data
        end
        if v.type == 'finalizeRecordedDataOnIndex' then
            for i = 1, #recordedData do
                local it = recordedData[i]

                if it.instrumentIndex ~= v.data then
                    print('SUHIAUSDH???')
                end
                if it.beatOff == nil and it.tickOff == nil then
                    semitoneReleased(it.semitone, it.instrumentIndex)
                end
            end
            if #recordedData > 0 then
                local lastRecordedBeat = recordedData[#recordedData].beatOff + 1
                local loopRounder = 1
                if lastRecordedBeat then
                    loopRounder = (math.ceil(lastRecordedBeat / beatInMeasure) * beatInMeasure)
                end
                recordedData.meta = {
                    loopRounder = loopRounder
                }
            end
            if #recordedData > 0 then
                channel.audio2main:push({ type = 'recordedClip', data = { instrumentIndex = instrumentIndex, clip = recordedData } })
            end
        end
        if v.type == 'stopPlayingSoundsOnIndex' then
            -- first patch up the recordeddata

            local index = v.data
            for i = 1, #playingSounds do
                local it = playingSounds[i]

                if it.instrumentIndex == index then
                    it.source:stop()
                end
            end
        end
        if v.type == 'mixerData' then
            mixerData = v.data
        end
        if v.type == 'drumkitData' then
            drumkit = v.data.drumkit
            drumgrid = v.data.drumgrid
            beatInMeasure = v.data.beatInMeasure
        end

        if v.type == 'resetBeatsAndTicks' then
            resetBeatsAndTicks()
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
            channel.audio2main:push({ type = 'tickUpdate', data = { tick = math.floor(tick) } })
        end

        if v.type == 'paused' then
            paused = v.data
            now    = love.timer.getTime()
        end

        if v.type == 'semitoneReleased' then
            local semitone = v.data.semitone
            semitoneReleased(semitone, v.data.instrumentIndex)
        end

        if v.type == 'semitonePressed' then
            local semitone = v.data.semitone
            semitoneTriggered(semitone, instrumentIndex)
            if recording == true then
                table.insert(recordedData, {
                    instrumentIndex = instrumentIndex,
                    beat = math.floor(lastBeat),
                    tick = math.floor(lastTick),
                    semitone = semitone,
                    duration = 0,
                })
            end
        end

        if v.type == 'instruments' then
            instruments = v.data
        end

        if v.type == 'instrumentIndex' then
            instrumentIndex = v.data
        end

        if v.type == 'updateKnobs' then
            uiData = v.data
        end

        if v.type == 'mode' then
            if v.data == 'play' then
                playing = true
                recording = false
            end
            if v.data == 'record' then
                recordedData = {}
                playing = false
                recording = true
            end
        end
    end
end
