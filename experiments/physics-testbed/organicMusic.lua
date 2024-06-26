local audiohelper = require 'lib.jizzjazz-audiohelper'

local inspect = require 'vendor.inspect'
local lib = {}


-- all these things are actions that can happen, i need to figure out an audible result for them

-- gets on bike
-- gets off bike
-- unlink
-- link
-- increases speed on bike
-- decrease speed on bike
-- is being dragged while on bike
-- is ebing dragged while not on bike
-- is sliding over groudn,not on bike
-- is rolling down the mountain without much speed
-- is standing on bike
-- make looping
-- doing wheelie
-- doing jump
-- change from day to night
-- change from night to day

audiohelper.startAudioThread()

uiData = {
    bpm = 90,
    swing = 50,
    instrumentsVolume = 1,
    drumVolume = 1,
    allDrumSemitoneOffset = 0
}
local myBeat = 0
local queuedActions = {}
local timer = 0
local finishAction = nil
function lib.update()
    repeat
        local msg = audiohelper.getMessageFromAudioThread()
        if msg then
            if msg.type == 'beatUpdate' then
                --print(msg.data.beat)
                myBeat = msg.data.beat
                handleQueuedActions()
            end
        end
    until not msg

    if finishAction then
        timer = timer - 1
        if timer <= 0 then
            finishAction()
            finishAction = nil
            timer = 0
        end
    end
end

function lib.swapDrumPattern()
    -- this should leave all the drum instruments alone
end

function lib.toggleInstrumentAtIndex(toggle, index)
    if toggle then
        print('korg')
        local inst1 = audiohelper.prepareSingleSample({ "oscillators", "fr4 korg" }, 'Fr4 - Korg MS-10 2.wav')
        audiohelper.changeSingleInstrumentsAtIndex(inst1, index)
    else
        print('rainbows')
        local inst2 = audiohelper.prepareSingleSample({ "lulla" }, 'rainbows.wav')
        audiohelper.changeSingleInstrumentsAtIndex(inst2, index)
    end
end

function handleQueuedActions()
    -- print(#queuedActions)
    for i = #queuedActions, 1, -1 do
        local it = queuedActions[i]
        --print(it.startBeat, it.endBeat, myBeat)
        if it.startBeat <= myBeat and it.started == false then
            queuedActions[i].started = true
            --print('started')
            audiohelper.mixDataInstruments[it.instrumentIndex].volume = 1
            audiohelper.recordedClips[it.instrumentIndex].clips[it.clipIndex].meta.isSelected = true
            audiohelper.updateClips()
            audiohelper.updateMixerData()
        end
        if it.endBeat <= myBeat and it.started == true then
            timer = 1

            finishAction = function()
                audiohelper.recordedClips[it.instrumentIndex].clips[it.clipIndex].meta.isSelected = false
                -- print('ended')
                audiohelper.mixDataInstruments[it.instrumentIndex].volume = 0

                audiohelper.updateClips()
                audiohelper.updateMixerData()
                audiohelper.stopSoundsAtInstrumentIndex(it.instrumentIndex)
            end
            table.remove(queuedActions, i)
            --
        end
    end
end

function lib.queueClip(instrumentIndex, clipIndex)
    -- on 2 and 8
    -- find out how long this clip takes
    audiohelper.setADSRAtIndex('release', instrumentIndex, love.math.random() * 0.3)
    -- print(inspect(audiohelper.recordedClips[instrumentIndex].clips[clipIndex].meta))

    local duration = audiohelper.recordedClips[instrumentIndex].clips[clipIndex].meta.loopRounder
    local startBeat = math.ceil(myBeat) + (myBeat % duration) + 1
    local endBeat = startBeat + duration + 1
    --print(myBeat, startBeat)
    table.insert(queuedActions,
        {
            action = 'play-clip',
            clipIndex = clipIndex,
            instrumentIndex = instrumentIndex,
            startBeat = startBeat,
            endBeat = endBeat,
            started = false
        })
    audiohelper.mixDataInstruments[instrumentIndex].volume = 0
    audiohelper.recordedClips[instrumentIndex].clips[clipIndex].meta.isSelected = true
    --  audiohelper.recordedClips[4].clips[8].meta.isSelected = true
    audiohelper.updateClips()
end

function lib.toggleTurbo(value)
    audiohelper.recordedClips[5].clips[1].meta.isSelected = value
    audiohelper.mixDataInstruments[5].volume = value and 1 or 0
    if value then
        lib.queueClip(5, 1)
    end
end

function lib.setFreaky(value)
    if not value then
        -- uiData.instrumentsVolume = 1
        uiData.allDrumSemitoneOffset = 0
        -- print(value)
    else
        local offset = (love.math.noise(love.timer.getTime() * 100)) * 2 - 1
        uiData.allDrumSemitoneOffset = value + offset
        -- uiData.instrumentsVolume = .5
        --  print(value + offset)
    end
    audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
end

function lib.setAllInstrumentsVolume(volume)
    uiData.instrumentsVolume = volume
    audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
end

function lib.setTempo(bpm)
    uiData.bpm = bpm
    audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
end

function lib.fadeOutVolume(index)
    audiohelper.setADSRAtIndex('release', 1, .1)
end

function lib.fadeInVolume(index, volume)
    audiohelper.setADSRAtIndex('release', 1, .1)
    --audiohelper.mixDataInstruments[index].volume = volume
    -- audiohelper.updateMixerData()
end

function lib.fadeOutAndFadeInVolume(turnOffIndex, turnOnIndex)
    audiohelper.mixDataInstruments[turnOffIndex].volume = 0
    audiohelper.mixDataInstruments[turnOnIndex].volume = 1
    audiohelper.updateMixerData()
    -- print(turnOffIndex, turnOnIndex)
end

function lib.loadJizzJazzSong(path)
    local contents = love.filesystem.read(path)
    local obj = (loadstring("return " .. contents)())

    audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    audiohelper.loadJizzJazzFile(obj, path)


    -- audiohelper.initializeMixer()
    -- audiohelper.initializeDrumgrid()
    -- audiohelper.updateMixerData()
    audiohelper.sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
    audiohelper.sendMessageToAudioThread({ type = "paused", data = false });
    audiohelper.sendMessageToAudioThread({ type = "mode", data = 'play' });
    for i = 1, 5 do
        audiohelper.mixDataInstruments[i].volume = 0
    end
    audiohelper.mixDataInstruments[1].volume = 1
    audiohelper.mixDataInstruments[4].volume = 1
    --audiohelper.mixDataInstruments[5].volume = 1
    audiohelper.updateMixerData()
    --audiohelper.initializeDrumgrid()
    --print(path)
end

return lib
