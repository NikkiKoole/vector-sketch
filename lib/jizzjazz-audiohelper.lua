local inspect      = require 'vendor.inspect'

local _thread
local channel      = {};
channel.audio2main = love.thread.getChannel("audio2main")
channel.main2audio = love.thread.getChannel("main2audio")


local lib = {}

function lib.startAudioThread()
    local sys = love.system.getOS()
    function getFileContents(path)
        print(path, '../..' .. path)
        local f = io.open(path, "rb") or io.open('../../' .. path, "rb")
        local content
        if f then
            --assert(f)
            content = f:read("*all")
            f:close()
        end

        return content
    end

    if sys == 'iOS' or sys == 'Android' then
        _thread = love.thread.newThread('jizzjazz-audiothread.lua')
        _thread:start()
    else
        -- _thread = love.thread.newThread('jizzjazz-audiothread.lua')
        -- _thread:start()

        local code = getFileContents('lib/jizzjazz-audiothread.lua')
        _thread = love.thread.newThread(code or 'jizzjazz-audiothread.lua')
        _thread:start()
    end
end

lib.percentageThingies = {} -- 5
for i = 1, 5 do
    lib.percentageThingies[i] = {}
end

lib.recordedClips = {}
for i = 1, 5 do
    lib.recordedClips[i] = {
        clips = {}
    }
end

lib.myTick                = 0
lib.myBeat                = 0
lib.myBeatInMeasure       = 0
lib.myNumPlayingSounds    = 0

local defaultAttackTime   = 0.2
local defaultDecayTime    = 0.01
local defaultSustainLevel = 0.7
local defaultReleaseTime  = 0.03

lib.instruments           = {}
lib.mixData               = {}
lib.drumgrid              = {}

lib.columns               = nil
lib.labels                = nil

function lib.setColumns(v) lib.columns = v end

function lib.setLabels(v) lib.labels = v end

function lib.initializeMixer()
    for i = 1, #lib.drumkit.order do
        lib.mixData[i] = { volume = 1 }
    end
end

function lib.initializeDrumgrid(optionalColumns)
    for x = 1, optionalColumns or lib.columns do
        lib.drumgrid[x] = {}
        for y = 1, #lib.drumkit.order do
            lib.drumgrid[x][y] = { on = false }
        end
    end
end

function lib.setDrumKitFiles(files)
    --    print('set drumkit files')
    --    lib.drumkitFiles = files
    lib.drumkit = lib.prepareDrumkit(files)
end

function lib.initializeInstruments(samples)
    for i = 1, 5 do
        lib.instruments[i] = {
            --sampleIndex = 1,
            sample = samples[i],
            tuning = 0,
            realtimeTuning = 0,
            adsr = {
                attack = defaultAttackTime,
                decay = defaultDecayTime,
                sustain = defaultSustainLevel,
                release = defaultReleaseTime
            },
        }
    end
end

function lib.getMessageFromAudioThread()
    local v = channel.audio2main:pop();
    local error = _thread:getError()
    assert(not error, error)
    return v
end

function lib.sendMessageToAudioThread(msg)
    channel.main2audio:push(msg)
end

function lib.pumpAudioThread()
    repeat
        local msg = lib.getMessageFromAudioThread()
        if msg then
            if msg.type == 'looperPercentage' then
                local intrIndex = msg.data.instrumentIndex
                local clipIndex = msg.data.clipIndex
                local percentage = msg.data.percentage
                lib.percentageThingies[intrIndex] = { clipIndex = clipIndex, percentage = percentage }
            end
            if msg.type == 'tickUpdate' then
                lib.myTick = msg.data.tick
            end
            if msg.type == 'beatUpdate' then
                lib.myBeat = msg.data.beat
                lib.myBeatInMeasure = msg.data.beatInMeasure
            end
            if msg.type == 'numPlayingSounds' then
                lib.myNumPlayingSounds = msg.data.numbers
            end
            if msg.type == 'clips' then
                lib.recordedClips = msg.data
            end
            if msg.type == 'recordedClip' then
                -- after you've recorded a clip it makes sense to select it.
                local index = msg.data.instrumentIndex
                local clip = msg.data.clip
                for k = 1, #lib.recordedClips[index].clips do
                    lib.recordedClips[index].clips[k].meta.isSelected = false
                end
                clip.meta.isSelected = true
                table.insert(lib.recordedClips[index].clips, clip)

                lib.sendMessageToAudioThread({ type = "clips", data = lib.recordedClips })
            end
        end
    until not msg
end

function lib.prepareDrumkit(drumkitFiles)
    local result = {}
    for k, v in pairs(drumkitFiles) do
        if k ~= 'order' then
            -- print(k)
            local root = 'samples'
            local fullPath = root
            local pathArray = v[1]
            local name = v[2]:gsub(".wav", ""):gsub(".WAV", "")
            for i = 1, #pathArray do
                fullPath = fullPath .. '/' .. pathArray[i]
            end
            local filePath = name .. '.wav'
            fullPath = fullPath .. '/' .. filePath
            local info = love.filesystem.getInfo(fullPath)
            if info then
                local soundData = love.sound.newSoundData(fullPath)
                --print(k)
                result[k] = {
                    name = name,
                    source = love.audio.newSource(soundData),
                    soundData = soundData,
                    cycle = false,
                    path = fullPath,
                    pathParts = { root = root, pathArray = pathArray, filePath = filePath }
                }
            else
                print('issuse with drumkit sample', fullPath)
            end
        end
    end

    if drumkitFiles.order then
        for i = 1, #drumkitFiles.order do
            if drumkitFiles[drumkitFiles.order[i]] then

            else
                print('order issue:', drumkitFiles.order[i])
            end
        end
        result.order = drumkitFiles.order
    else
        print('drumkitfile need an order to display')
    end
    return result
end

function lib.prepareSingleSample(pathArray, filePath)
    local root = 'samples'
    local fullPath = root
    local isCycle = false
    for i = 1, #pathArray do
        fullPath = fullPath .. '/' .. pathArray[i]
        if pathArray[i] == 'oscillators' then
            isCycle = true
        end
    end
    -- print('isCycle', isCycle)
    fullPath = fullPath .. '/' .. filePath
    local name = filePath:gsub(".wav", ""):gsub(".WAV", "")
    local info = love.filesystem.getInfo(fullPath)
    if info then
        local soundData = love.sound.newSoundData(fullPath)
        local result = {
            name = name,
            source = love.audio.newSource(soundData),
            soundData = soundData,
            cycle = isCycle,
            path = fullPath,
            pathParts = { root = root, pathArray = pathArray, filePath = filePath }
        }
        return result
    else
        print('issue preparing sample: ', fullPath)
    end
end

function lib.tuneRTInstrumentBySemitone(index, semitone)
    lib.instruments[index].realtimeTuning = lib.instruments[index].realtimeTuning + semitone
    lib.sendMessageToAudioThread({ type = "instruments", data = lib.instruments })
    return lib.instruments[index].realtimeTuning
end

function lib.tuneInstrumentBySemitone(index, semitone)
    lib.instruments[index].tuning = lib.instruments[index].tuning + semitone
    lib.sendMessageToAudioThread({ type = "instruments", data = lib.instruments })
    return lib.instruments[index].tuning
end

function lib.setADSRAtIndex(term, index, value)
    lib.instruments[index].adsr[term] = value
    lib.sendMessageToAudioThread({ type = "instruments", data = lib.instruments });
end

local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function lib.saveJizzJazzFile()
    local str               = os.date("%Y%m%d%H%M")
    local path              = str .. '.jizzjazz2.txt'

    local simplifiedDrumkit = {}
    for k, v in pairs(lib.drumkit) do
        if k == 'order' then
            simplifiedDrumkit.order = v
        else
            simplifiedDrumkit[k] = { v.pathParts.pathArray, v.name }
        end
    end

    local simplifiedInstrumentBanks = {}
    for i = 1, #lib.instruments do
        local instr = lib.instruments[i]
        local sample = instr.sample
        local adsr = instr.adsr
        simplifiedInstrumentBanks[i] = {
            sample = { sample.pathParts.pathArray, sample.pathParts.filePath },
            adsr = { a = adsr.attack, d = adsr.decay, s = adsr.sustain, r = adsr.release },
            tuning = instr.tuning,
            realtimeTuning = instr.realtimeTuning
        }
    end

    local simplifiedDrumGrid = {}
    local drumColumns = #lib.drumgrid
    local drumRows = #simplifiedDrumkit.order
    simplifiedDrumGrid.columns = lib.columns
    for x = 1, drumColumns do
        simplifiedDrumGrid[x] = {}
        for y = 1, drumRows do
            simplifiedDrumGrid[x][y] = 0
            local d = lib.drumgrid[x][y]
            if (d.on == true) then
                local n = shallowcopy(d)
                n.on = nil
                simplifiedDrumGrid[x][y] = n
            end
        end
    end

    --print(#recordedClips)

    local simplifiedClips = shallowcopy(lib.recordedClips)


    local data = {
        drumPatternName = drumPatternName,
        drumkit = simplifiedDrumkit,
        instruments = simplifiedInstrumentBanks,
        simplifiedDrumGrid = simplifiedDrumGrid,

        simplifiedClips = simplifiedClips,
        uiData = shallowcopy(uiData)
    }

    love.filesystem.write(path, inspect(data, { indent = " " }))
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

function lib.updateMixerData()
    lib.sendMessageToAudioThread({
        type = 'mixerData',
        data = lib.mixData
    })
end

function lib.updateDrumKitData()
    lib.sendMessageToAudioThread({
        type = 'drumkitData',
        data = {
            drumgrid = lib.drumgrid,
            drumkit = lib.drumkit,
            beatInMeasure = lib.columns / 4
        }
    })
end

function lib.loadJizzJazzFile(data, filename)
    drumPatternName = data.drumPatternName
    -- lib.drumkitFiles = data.drumkit
    lib.drumkit = lib.prepareDrumkit(data.drumkit)
    lib.columns = data.simplifiedDrumGrid.columns or #data.simplifiedDrumGrid -- todo not working yet.
    lib.labels = lib.drumkit.order
    local g = data.simplifiedDrumGrid
    lib.initializeDrumgrid(lib.columns)
    for x = 1, #g do
        for y = 1, #g[x] do
            local dcell = g[x][y]

            lib.drumgrid[x][y] = { on = false }
            if dcell ~= 0 then
                lib.drumgrid[x][y] = shallowcopy(dcell)
                lib.drumgrid[x][y].on = true
            end
        end
    end

    lib.updateDrumKitData()


    for i = 1, #data.instruments do
        local readInstrument = data.instruments[i]
        local newSample = lib.prepareSingleSample(readInstrument.sample[1], readInstrument.sample[2])
        if newSample then
            lib.instruments[i] = {
                --sampleIndex = 1,
                sample = newSample, -- pickedSamples[i],
                tuning = readInstrument.tuning,
                realtimeTuning = readInstrument.realtimeTuning,
                adsr = {
                    attack = readInstrument.adsr.a,
                    decay = readInstrument.adsr.d,
                    sustain = readInstrument.adsr.s,
                    release = readInstrument.adsr.r
                },
            }
        else
            -- print('something was up making sample for this instrument: ', filename)
        end
    end
    lib.sendMessageToAudioThread({ type = "instruments", data = lib.instruments })

    lib.recordedClips = data.simplifiedClips
    lib.sendMessageToAudioThread({ type = "clips", data = lib.recordedClips })

    uiData = data.uiData
    lib.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });

    lib.initializeMixer()
end

return lib
