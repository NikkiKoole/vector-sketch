local inspect      = require 'vendor.inspect'
local sone         = require 'vendor.sone'
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
lib.mixDataDrums          = {}
lib.mixDataInstruments    = {}
lib.drumgrid              = {}

lib.columns               = nil
lib.labels                = nil

lib.eq                    = { bass = 0, mid = 0, treble = 0 }

function lib.setEQ(eq)
    lib.eq = eq

    for k, v in pairs(lib.drumkit) do
        local thing = v -- lib.drumkit[i]
        if thing.path then
            local soundData = love.sound.newSoundData(thing.path)
            sone.filter(soundData, {
                type = "lowshelf",
                frequency = 150,      -- target lows
                gain = eq.bass * 100, -- boost
            })

            sone.filter(soundData, {
                type = "peakeq",
                frequency = 1200,
                gain = eq.mid * 100,
                Q = 1.0, -- control width
            })

            sone.filter(soundData, {
                type = "highshelf",
                frequency = 6000,
                gain = eq.treble * 100,
            })

            lib.drumkit[k].source = love.audio.newSource(soundData)
        else
            --print(k, 'no')
        end
        --§ print('before', thing.source)
        -- sone.filter(thing.soundData, {
        --     type = "lowpass",
        --     frequency = 150,
        -- })
        -- sone.filter(thing.soundData, {
        --     type = "peakeq",
        --     frequency = 1000,
        --     gain = 100,
        -- })
        --   thing.source = love.audio.newSource(thing.soundData)
        --  print('after', thing.source)
        --source = love.audio.newSource(soundData),
        --soundDataOriginal
    end
    lib.updateDrumKitData()
    --  print(inspect(lib.drumkit))
end

function lib.setColumns(v) lib.columns = v end

function lib.setLabels(v) lib.labels = v end

function lib.updateClips()
    lib.sendMessageToAudioThread({ type = "clips", data = lib.recordedClips })
end

function lib.stopSoundsAtInstrumentIndex(index)
    lib.sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = index })
end

function lib.initializeMixer()
    for i = 1, #lib.drumkit.order do
        lib.mixDataDrums[i] = { volume = 1 }
    end
    for i = 1, 5 do
        lib.mixDataInstruments[i] = { volume = 1 }
    end
end

function lib.cloneDrumgrid(grid)
    local copy = {}
    for x = 1, #grid do
        copy[x] = {}
        for y = 1, #grid[x] do
            copy[x][y] = {}
            for k, v in pairs(grid[x][y]) do
                copy[x][y][k] = v
            end
        end
    end
    return copy
end

function lib.initializeDrumgrid(optionalColumns)
    local k = 1
    lib.drumgrid[k] = {}
    for x = 1, optionalColumns or lib.columns do
        lib.drumgrid[k][x] = {}
        for y = 1, #lib.drumkit.order do
            lib.drumgrid[k][x][y] = { on = false }
        end
    end
end

function lib.drumPatternFill(pattern, part)
    print(inspect(pattern), inspect(part))
    local hasEveryThingNeeded = true
    for k, v in pairs(part.grid) do
        if not lib.drumkit[k] then
            print("failed looking for", k, "in drumkt")
            hasEveryThingNeeded = false
        end
    end

    if (hasEveryThingNeeded) then
        local gridLength = 0

        for k, v in pairs(part.grid) do
            gridLength = string.len(v)
        end
        lib.initializeDrumgrid(gridLength)
        --print(inspect(part.grid))

        for k, v in pairs(part.grid) do
            -- find the correct row in the grid.
            local index = -1
            for i = 1, #lib.drumkit.order do
                if lib.drumkit.order[i] == k then
                    index = i
                end
            end

            if string.len(v) ~= #lib.drumgrid[1] then
                print("failed: issue with length of drumgrid", string.len(v), #lib.drumgrid, pattern.name)
            end
            gridLength = string.len(v)
            if index == -1 then
                print("failed: I could find the correct key but something wrong with order: ", k)
            end

            for i = 1, string.len(v) do
                local c = v:sub(i, i)
                if (c == "x") then
                    lib.drumgrid[1][i][index] = { on = true }
                elseif (c == "f") then
                    lib.drumgrid[1][i][index] = { on = true, flam = true }
                else
                    lib.drumgrid[1][i][index] = { on = false }
                end
            end
        end

        return pattern.name .. " : " .. part.name, gridLength
    end
end

function lib.setDrumKitFiles(files)
    --    print('set drumkit files')
    --    lib.drumkitFiles = files
    lib.drumkit = lib.prepareDrumkit(files)
end

function lib.changeSingleInstrumentsAtIndex(sample, index)
    -- im assuming we alkready have an instrument here and wetype want to keep adsr as is
    print(index)
    lib.instruments[index].sample = sample
    lib.sendMessageToAudioThread({ type = "instruments", data = lib.instruments })
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


                -- -- -- Filter out all sounds above 150Hz.
                -- sone.filter(soundData, {
                --     type = "lowpass",
                --     frequency = 150,
                -- })

                -- sone.filter(soundData, {
                --     type = "lowshelf",
                --     frequency = 150,
                --     gain = 160,
                -- })
                -- -- Boost sound at 1000Hz
                -- sone.filter(soundData, {
                --     type = "peakeq",
                --     frequency = 1000,
                --     gain = 100,
                -- })
                --sone.filter(soundData, { type = 'highpass', frequency = 100 })
                --print(k)
                result[k] = {
                    name = name,
                    source = love.audio.newSource(soundData),
                    -- soundDataOriginal = soundData,
                    -- soundData = soundData,
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

function lib.saveJizzJazzFile(allDrumParts)
    local str  = os.date("%Y%m%d%H%M")
    local path = str .. '.jizzjazz2.txt'
    print('tod save all the various drumparts if available ', #allDrumParts)
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
    local drumColumns = #lib.drumgrid[1]
    local drumRows = #simplifiedDrumkit.order
    simplifiedDrumGrid.columns = lib.columns

    local k = 1
    simplifiedDrumGrid[k] = {}
    for x = 1, drumColumns do
        simplifiedDrumGrid[k][x] = {}
        for y = 1, drumRows do
            simplifiedDrumGrid[k][x][y] = 0
            local d = lib.drumgrid[k][x][y]
            if (d.on == true) then
                local n = shallowcopy(d)
                n.on = nil
                simplifiedDrumGrid[k][x][y] = n
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
        drums = lib.mixDataDrums,
        instruments = lib.mixDataInstruments
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

    if (type(data.simplifiedDrumGrid[1][1])) == 'number' then
        print('patching for multiple drumparts')
        local temp = { [1] = data.simplifiedDrumGrid }
        data.simplifiedDrumGrid = temp
    else
        print("this didnt need patching")
    end
    local g = data.simplifiedDrumGrid



    lib.initializeDrumgrid(lib.columns)
    local k = 1
    print(#g)
    for x = 1, #g[k] do
        for y = 1, #g[k][x] do
            local dcell = g[k][x][y]

            lib.drumgrid[k][x][y] = { on = false }
            if dcell ~= 0 then
                lib.drumgrid[k][x][y] = shallowcopy(dcell)
                lib.drumgrid[k][x][y].on = true
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
