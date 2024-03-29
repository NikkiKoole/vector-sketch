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

local uiData            = nil


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
            -- print('stoping')
        end
    end
    --print(envelopeValue)
    return envelopeValue
end

local function updateADSREnvelopesForPlayingSounds(dt)
    local now = love.timer.getTime()
    for i = 1, #playingSounds do
        local it = playingSounds[i]
        local value = generateADSR(it, now)
        value = value * (uiData and uiData.instrumentsVolume or 1)
        it.source:setVolume(value)
    end
end

local function generateSineLFO(time, lfoFrequency)
    return math.sin(2 * math.pi * lfoFrequency * time)
end
local function generateNoiseLFO(time, lfoFrequency)
    return love.math.noise(2 * math.pi * lfoFrequency * time)
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

local function updatePlayingSoundsWithLFO()
    for i = 1, #playingSounds do
        local useLFO = true
        if useLFO then
            local it            = playingSounds[i]
            local timeThis      = love.timer.getTime() - it.timeNoteOn
            local lfoValue      = generateSineLFO(timeThis, .15) -- PARAMTERIZE THIS
            local lfoValue      = generateNoiseLFO(timeThis, .5) -- PARAMTERIZE THIS
            -- print(lfoValue)
            local tuning        = instruments[it.instrumentIndex].tuning
            local range         = getPitchVariationRange(it.semitone, 1 / 12, tuning) -- PARAMTERIZE THIS
            local lfoAmplitude  = range
            local lfoPitchDelta = (lfoValue * lfoAmplitude)

            it.source:setPitch(it.pitch + lfoPitchDelta)
        end
    end
end

local function cleanPlayingSounds()
    local now = love.timer.getTime()
    for i = #playingSounds, 1, -1 do
        local it = playingSounds[i]
        if (it.timeNoteOff and it.timeNoteOff < now) then
            if not it.source:isPlaying() then
                --  print('removing')
                it.source:release()
                table.remove(playingSounds, i)
                channel.audio2main:push({ type = 'numPlayingSounds', data = { numbers = #playingSounds } })
            end
        end
    end
end

local function semitoneTriggered(number, instrumentIndex)
    local sampleIndex = instruments[instrumentIndex].sampleIndex
    local source = samples[sampleIndex].source:clone()
    local tuning = 0                                        --instruments[instrumentIndex].tuning
    local pitch = getPitch(number, tuning)
    local range = getPitchVariationRange(number, 0, tuning) -- PARAMTERIZE THIS
    local pitchOffset = love.math.random() * range - range / 2
    if samples[sampleIndex].cycle then
        --print('triggered a looping sound')
        source:setLooping(true)
    end

    --print('play!')
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
            -- print('found already!', foundInstrumentSoundAlready)
            foundInstrumentSoundAlready.pitch = pitch + pitchOffset
            --foundInstrumentSoundAlready.source = source
            foundInstrumentSoundAlready.semitone = number
            foundInstrumentSoundAlready.instrumentIndex = instrumentIndex
            foundInstrumentSoundAlready.timeNoteOn = love.timer.getTime()
        end
    end
    if not foundInstrumentSoundAlready or monophonic == false then
        -- print('not found already!', foundInstrumentSoundAlready)
        source:setPitch(pitch + pitchOffset)
        source:setVolume(0)
        source:play()
        table.insert(playingSounds, {
            pitch = pitch + pitchOffset,
            source = source,
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
                    -- print('got here!', i, math.floor(lastBeat), math.floor(lastTick))
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
            volume = volume * (uiData and uiData.drumVolume or 1)
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
                    local source = drumkit[key].source:clone()
                    local cellVolume = cell.volume or 1
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



                    if drumgrid[column + 1][i].flam == true then
                        local flamRepeat = 1

                        for j = 1, flamRepeat do
                            local futureTick = tick + (12 / flamRepeat)
                            local futureBeat = beat

                            if futureTick >= PPQN then
                                futureTick = futureTick - PPQN
                                futureBeat = futureBeat + 1
                            end
                            local gateCloseBeat, gateCloseTick = getGateOffBeatAndTick(source, pitch,
                                bpm, futureBeat, futureTick, gate)
                            -- print(gateCloseTick, gateCloseBeat)
                            local future = {
                                tick = futureTick,
                                beat = futureBeat,
                                source = drumkit[key].source:clone(),
                                pitch = pitch,
                                volume = volume,
                                gateCloseBeat = gateCloseBeat,
                                gateCloseTick = gateCloseTick
                            }
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

                            local futureTick = tick + (delay)
                            local futureBeat = beat
                            if futureTick >= PPQN then
                                futureTick = futureTick % PPQN
                                futureBeat = futureBeat + math.ceil(futureTick / PPQN)
                            end
                            local gateCloseBeat, gateCloseTick = getGateOffBeatAndTick(source, pitch,
                                bpm, futureBeat, futureTick, gate)

                            local future = {
                                tick = futureTick,
                                beat = futureBeat,
                                source = drumkit[key].source:clone(),
                                volume = volume / k,
                                pitch = pitch,
                                gateCloseBeat = gateCloseBeat,
                                gateCloseTick = gateCloseTick
                            }
                            --     print(futureTick, futureBeat, volume)
                            table.insert(futureDrumNotes, future)

                            volume = volume / 2
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
            local t = missedTicks[j]
            local b = beat
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

function doReplayRecorded(beat, tick)
    for i = 1, #recordedData do
        if recordedData[i].beatOff == beat and recordedData[i].tickOff == tick then
            semitoneReleased(recordedData[i].semitone, recordedData[i].instrumentIndex)
        end
        if recordedData[i].beat == beat and recordedData[i].tick == tick then
            semitoneTriggered(recordedData[i].semitone, recordedData[i].instrumentIndex)
        end
    end
end

function handlePlayingRecordedData()
    if true then
        local loopRounder = 1
        if #recordedData > 0 then
            --print(#recordedData, recordedData[#recordedData].beatOff, recordedData[#recordedData].tickOff)
            local lastRecordedBeat = recordedData[#recordedData].beatOff + 1
            if lastRecordedBeat then
                loopRounder = (math.ceil(lastRecordedBeat / beatInMeasure) * beatInMeasure)
            end
        end
        local beat = (math.floor(lastBeat) % loopRounder)
        local tick = math.floor(lastTick)

        --missedTicks
        for j = 1, #missedTicks do
            local t = missedTicks[j]
            local b = beat
            if (t > tick) then
                --print('oh dear, missed tick over the beat boundary', t, tick)
                b = beat - 1
            end
            doReplayRecorded(b, t)
        end
        missedTicks = {}

        doReplayRecorded(beat, tick)
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

        if math.floor(tick) - math.floor(lastTick) > 1 then
            for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
                table.insert(missedTicks, i)
                print('insert missing tick')
            end
        end

        if (math.floor(beat) ~= math.floor(lastBeat)) then
            if recording == true then
                playMetronomeSound()
            end
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end
        if (math.floor(tick) ~= math.floor(lastTick)) then
            channel.audio2main:push({ type = 'tickUpdate', data = { tick = math.floor(tick) } })
            if playing then
                handlePlayingRecordedData()
                handlePlayingDrumGrid()
            end
            if recording then
                handlePlayingDrumGrid()
            end
        end


        -- handle the missed ticks here baby
        --
        missedTicks = {}
        lastBeat = beat
        lastTick = tick
    end

    updateADSREnvelopesForPlayingSounds(delta)
    updatePlayingSoundsWithLFO()

    local sleepForMultiplier = math.ceil(bpm / 25)
    local sleepFor = 1.0 / (PPQN * sleepForMultiplier)
    love.timer.sleep(sleepFor)

    -- using this i can sleep for a good amount (no missed ticks)
    -- but also will sleep less if the bpm goes up,
    -- testing it i see missed ticks only >400 bpm.  RAVE ON!!

    cleanPlayingSounds()

    local v = channel.main2audio:pop();
    if v then
        if v.type == 'samples' then
            samples = v.data
        end

        if v.type == 'stopPlayingSoundsOnIndex' then
            -- first patch up the recordeddata
            for i = 1, #recordedData do
                local it = recordedData[i]

                --print(recordedData[i].beatOff, recordedData[i].tickOff)
                if it.instrumentIndex ~= v.data then
                    print('SUHIAUSDH???')
                end
                if it.beatOff == nil and it.tickOff == nil then
                    print('theres an issue with this probably')
                    semitoneReleased(it.semitone, it.instrumentIndex)
                    --recordedData[i].beatOff = math.floor(lastBeat)
                    --recordedData[i].tickOff = math.floor(lastTick)
                end
            end
            local index = v.data
            for i = 1, #playingSounds do
                local it = playingSounds[i]
                --print(it.instrumentIndex, index)
                if it.instrumentIndex == index then
                    it.source:stop()
                end
            end
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
            semitoneReleased(semitone, instrumentIndex)
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
