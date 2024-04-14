local audiohelper = require 'lib.jizzjazz-audiohelper'

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


audiohelper.startAudioThread()

uiData = {
    bpm = 90,
    swing = 50,
    instrumentsVolume = 1,
    drumVolume = 1,
    allDrumSemitoneOffset = 0
}
function lib.setFreaky(value)
    if not value then
        uiData.allDrumSemitoneOffset = 0
    else
        local offset = (love.math.noise(love.timer.getTime() * 100)) * 2 - 1
        uiData.allDrumSemitoneOffset = value + offset
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
    --audiohelper.initializeDrumgrid()
    --print(path)
end

return lib
