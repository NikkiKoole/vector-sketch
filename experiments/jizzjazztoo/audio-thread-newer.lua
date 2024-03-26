require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')


-- Linn often used a timing resolution of 96 parts per quarter note (PPQN),
-- meaning that each quarter note is subdivided into 96 equal parts.
-- This high resolution allows for very precise timing and sequencing of musical events,
local PPQN = 96



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
local playingSounds     = {} -- lpayingSounds are just for the melodic sounds.
local recordedData      = {}
local playingDrumSounds = {}

local drumkit           = {}
local drumgrid          = {}
local sampleTuning      = {}
local sampleIndex       = 1
local samples           = {}
local futureDrumNotes   = {} -- this is now just used for FLAMS, but i can see echo notes working similarly



local playing             = false
local recording           = false

-- adsr stuff
local defaultAttackTime   = 0.2
local defaultDecayTime    = 0.01
local defaultSustainLevel = 0.7
local defaultReleaseTime  = 0.03
local uiData              = nil

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
        value = value * (uiData and uiData.instrumentsVolume or 1)
        it.source:setVolume(value)
    end
end

local function generateSineLFO(time, lfoFrequency)
    return math.sin(2 * math.pi * lfoFrequency * time)
end

local function getUntunedPitch(semitone)
    local sampledAtSemitone = 60 --+ sampleTuning[sampleIndex]
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

local function getPitch(semitone)
    --print(sampleTuning, sampleIndex)
    local sampledAtSemitone = 60 + sampleTuning[sampleIndex]
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


local function semitoneTriggered(number)
    local source = samples[sampleIndex].source:clone() --sample.source:clone()
    local pitch = getPitch(number)
    local range = getPitchVariationRange(number, 0)    -- PARAMTERIZE THIS
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
                local totalDeltaTicks = (deltaBeats * PPQN) + deltaTicks

                recordedData[i].duration = totalDeltaTicks
                recordedData[i].beatOff = math.floor(lastBeat)
                recordedData[i].tickOff = math.floor(lastTick)
            end
        end
    end
    for i = 1, #playingSounds do
        if (playingSounds[i].semitone == semitone and not playingSounds[i].timeNoteOff) then
            playingSounds[i].timeNoteOff = love.timer.getTime()
        end
    end
end
function getGateOffBeatAndTick(snd, pitch, bpm, beat, tick, gateValue)
    local secondsToFinishAtThisPitch = (snd:getDuration() / pitch) * gateValue
    local bb = secondsToFinishAtThisPitch * (bpm / 60)
    local futureTick = math.ceil(tick + (bb * PPQN))
    local futureBeat = beat

    if futureTick >= PPQN then
        futureTick = futureTick - PPQN
        futureBeat = futureBeat + 1
    end
    return futureBeat, futureTick
end

function handlePlayingDrumGrid()
    if uiData then
        local beat = math.floor(lastBeat)
        local tick = math.floor(lastTick)

        if false then
            for j = 1, #missedTicks do
                local t = missedTicks[j]
                if (t % 24 == 0) then
                    --print('16th hit', tick)
                    local source = drumkit.AC.source:clone()
                    source:play()
                    print('played missed tick drum')
                end
            end
        end


        -- gate closing for  the already playing drums
        for i = #playingDrumSounds, 1, -1 do
            local pd = playingDrumSounds[i]
            if pd.gateCloseBeat == beat and pd.gateCloseTick == tick then
                pd.source:setVolume(0)
                -- print('closing gate', pd.source:tell())
            end
            if not pd.source:isPlaying() then
                pd.source:release()
                table.remove(playingDrumSounds, i)
            end
        end

        -- triggering future drum notes (flam/echo) when their time is there.
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

        -- why % 24 ??
        -- because the PPQN = 96 so PartsPer16th note is 24!
        -- drumgrid is subdivided in 16ths

        -- -- how to apply swing?
        -- 50% is no swing
        -- 100% is way too much swing, now it will fall
        -- the number we write is the percentage the first (in other words 16th before this gets.)

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
                    if cell.on then
                        local key = drumkit.order[i]
                        local source = drumkit[key].source:clone()
                        local cellVolume = cell.volume or 1
                        local gate = cell.gate or 1
                        local allDrumsVolume = (uiData and uiData.drumVolume or 1)
                        local volume = cellVolume * allDrumsVolume
                        source:setVolume(volume)

                        local afterOffset = getUntunedPitch(60 + (cell and cell.semitoneOffset or 0))
                        local pitch = afterOffset

                        -- local pitch = getUntunedPitch(60)
                        -- local range = getUntunedPitchVariationRange(60, 3)
                        -- local pitchOffset = 0 --love.math.random() * range - range / 2


                        if source:getChannelCount() == 1 then
                            source:setPosition(cell.pan or 0, 0, 0)
                        else
                            print(key .. ' isnt MONO, so it cant be panned')
                        end


                        -- local ratio =  line.sfx:tell("samples") / line.sfx:getDuration('samples')
                        -- local general_ratio = (line.sfx:tell('samples')/ 48000)


                        local gateCloseBeat, gateCloseTick = getGateOffBeatAndTick(source, pitch,
                            uiData.bpm, beat, tick, gate)
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

                        --beat = beat + (delta * (bpm / 60))
                        --tick = ((beat % 1) * (PPQN))

                        -- howmany ticks is that ?
                        --

                        source:setPitch(pitch)
                        source:play()

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
                                    uiData.bpm, futureBeat, futureTick, gate)
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
                                    uiData.bpm, futureBeat, futureTick, gate)
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
                semitoneTriggered(recordedData[i].semitone)
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
        if (math.floor(tick) ~= math.floor(lastTick)) then
            channel.audio2main:push({ type = 'tickUpdate', data = { tick = math.floor(tick) } })
            if playing then
                handlePlayingRecordedData()
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

    local sleepForMultiplier = math.ceil(bpm / 50)
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
            --  print(bpm)
        end


        if v.type == 'tuningUpdated' then
            sampleTuning = v.data
        end
        if v.type == 'sampleIndex' then
            sampleIndex = v.data
        end
        if v.type == 'drumkitData' then
            drumkit = v.data.drumkit
            drumgrid = v.data.drumgrid
            beatInMeasure = v.data.beatInMeasure -- math.ceil(#v.data.drumgrid / 4)
            --print('beatInMeasure', math.ceil(#v.data.drumgrid / 4))
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
            semitoneReleased(semitone)
        end
        if v.type == 'semitonePressed' then
            local semitone = v.data.semitone
            local channelIndex = v.data.channelIndex
            local sampleIndex = v.data.sampleIndex
            local takeIndex = v.data.takeIndex
            --local sample = v.data.sample
            semitoneTriggered(semitone)
            if recording == true then
                table.insert(recordedData, {
                    takeIndex = takeIndex or 0,
                    channelIndex = channelIndex,
                    sampleIndex = sampleIndex,
                    --sample = sample,
                    beat = math.floor(lastBeat),
                    tick = math.floor(lastTick),
                    semitone = semitone,
                    duration = 0,
                })
            end
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
        --if v.type == 'key' then
        --print(v.data)
        --end
    end
end
