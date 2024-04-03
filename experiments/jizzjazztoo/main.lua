package.path = package.path .. ";../../?.lua"

sone = require 'sone'
require 'ui'

local inspect      = require 'vendor.inspect'
local drumPatterns = require 'drum-patterns'
local _thread
local channel      = {};
channel.audio2main = love.thread.getChannel("audio2main")
channel.main2audio = love.thread.getChannel("main2audio")

require 'fileBrowser'


getMessageFromAudioThread = function()
    local v = channel.audio2main:pop();
    local error = _thread:getError()
    assert(not error, error)
    return v
end

sendMessageToAudioThread  = function(msg)
    channel.main2audio:push(msg)
end

local sys                 = love.system.getOS()
if sys == 'iOS' or sys == 'Android' then
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
else
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
end


function saveJizzJazzFile(song)
    local str               = os.date("%Y%m%d%H%M")
    local path              = str .. '.jizzjazz2.txt'
    local indexToSamplePath = {}

    local drumInstruments   = {}
    local melodyInstruments = {}

    for k, v in pairs(drumkit) do
        if k == 'order' then
            -- print(inspect(v))
        else
            -- print(k, v.v)
        end
    end

    for i = 1, #samples do
        print(inspect(samples[i]))
    end

    for i = 1, #instruments do
        print(instruments[i])
    end

    --print(drumkit.order)

    -- for i = 1, #song.voices do
    --     if song.voices[i] then
    --         indexToSamplePath[i] = {
    -- index = song.voices[i].voiceIndex,
    --path = samples[song.voices[i].voiceIndex].p,
    --         }
    --     end
    -- end

    local data = {
        --index = indexToSamplePath,
        --voices = song.voices,
        --pages = optimizeAllPages(song.pages),
        --tuning = song.tuning,
        --swing = song.swing,
        --bpm = song.bpm
    }

    love.filesystem.write(path, inspect(data, { indent = "" }))
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

function prepareSingleSample(root, pathArray, filePath)
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
    end
end

local function prepareDrumkit(drumkitFiles)
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
                result[k] = {
                    name = name,
                    source = love.audio.newSource(soundData),
                    soundData = soundData,
                    cycle = false,
                    path = fullPath,
                    pathParts = { root = root, pathArray = pathArray, filePath = filePath }
                }
            end
        end
    end
    --print(drumkitFiles)
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

local function updateDrumKitData()
    sendMessageToAudioThread({
        type = 'drumkitData',
        data = {
            drumgrid = drumgrid,
            drumkit = drumkit,
            beatInMeasure = grid.columns / 4
        }
    })
end

local function hex2rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255
end

function TableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

function love.load()
    uiData = {
        bpm = 90,
        swing = 50,
        instrumentsVolume = 1,
        drumVolume = 1,
        allDrumSemitoneOffset = 0
    }

    palette = {
        ['red'] = '#cc241d',
        ['green'] = '#98971a',
        ['yellow'] = '#d79921',
        ['yellow2'] = '#fabd2f',
        ['blue'] = '#458588',
        ['orange'] = '#d65d0e',
        ['gray'] = '#a89984',
        ['fg4'] = '#a89984',
        ['fg2'] = '#d5c4a1',
        ['bg2'] = '#504945',
        ['bg0'] = '#282828'
    }
    for k, v in pairs(palette) do
        palette[k] = { hex2rgb(v) }
    end

    lookinIntoIntrumentAtIndex = 0
    singleInstrumentJob = nil

    sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    myTick = 0
    myBeat = 0
    myBeatInMeasure = 4
    myNumPlayingSounds = 0

    bigfont = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    smallestfont = love.graphics.newFont('WindsorBT-Roman.otf', 16)
    smallfont = love.graphics.newFont('WindsorBT-Roman.otf', 24)
    musicfont = love.graphics.newFont('NotoMusic-Regular.ttf', 48)

    missedTicks = {}
    playingSounds = {}

    -- livelooping
    recording = false
    playing = false

    activeDrumPatternIndex = 1
    --queuedDrumPatternIndex = 0 --  todo

    pressedKeys = {}
    -- measure/beat

    sendMessageToAudioThread({ type = "resetBeatsAndTicks" });

    browser = fileBrowser("samples", {}, { "wav", "WAV" })
    browserClicked = false
    fileBrowserForSound = nil


    max_octave                = 8
    octave                    = 4

    local defaultAttackTime   = 0.2
    local defaultDecayTime    = 0.01
    local defaultSustainLevel = 0.7
    local defaultReleaseTime  = 0.03

    instrumentIndex           = 1
    instruments               = {}

    local sample              = prepareSingleSample('samples', { "oscillators", "fr4 arp" }, 'Fr4 - ARP 2600 14.wav')

    --prepareSingleSample('samples', {}, 'Triangles 101.wav')
    --prepeareSingleSample('samples', { 'legow' }, 'Little Blip.wav')
    for i = 1, 1 do
        instruments[i] = {
            --sampleIndex = 1,
            sample = sample,
            tuning = 0,
            adsr = {
                attack = defaultAttackTime,
                decay = defaultDecayTime,
                sustain = defaultSustainLevel,
                release = defaultReleaseTime
            },
        }
    end

    -- here we will keep the recorded Data for all instruments, and every instrument can have multiple recorded things, lets call them clip
    recordedClips = {}
    for i = 1, 5 do
        recordedClips[i] = {
            clips = {}
        }
    end

    sendMessageToAudioThread({ type = "instruments", data = instruments })
    sendMessageToAudioThread({ type = "instrumentIndex", data = instrumentIndex })

    local drumkitCR78 = {
        order = { 'AC', 'BD', 'SD', 'LT', 'MT', 'HT', 'CH', 'OH', 'CY', 'RS', 'CPS', 'TB', 'CB' },
        AC = { { 'cr78' }, 'Kick Accent' },
        BD = { { 'cr78' }, 'Kick' },
        SD = { { 'cr78' }, 'Snare' },
        LT = { { 'cr78' }, 'Conga Low' },
        MT = { { 'cr78' }, 'Bongo Low' },
        HT = { { 'cr78' }, 'Bongo High' },
        CH = { { 'cr78' }, 'HiHat' },
        OH = { { 'cr78' }, 'Tamb 2' },
        CY = { { 'cr78' }, 'Cymbal' },
        RS = { { 'cr78' }, 'Rim Shot' },
        TB = { { 'cr78' }, 'Guiro 1' },
        CPS = { {}, 'per01' },
        CB = { { 'cr78' }, 'Cowbell' }
    }

    drumkitFiles = drumkitCR78
    drumkit = prepareDrumkit(drumkitFiles)

    grid = {
        startX = 120,
        startY = 120,
        cellW = 20,
        cellH = 32,
        columns = 16,
        labels = drumkitFiles.order
    }

    drumgrid = {}
    for x = 1, grid.columns do
        drumgrid[x] = {}
        for y = 1, #drumkitFiles.order do
            drumgrid[x][y] = { on = false }
        end
    end
    drumPatternName = ''
    drummPatternPickData = {
        scrollLeft = 0,
        scrollRight = 0,
        pickedCategoryIndex = 1,
        pickedItemIndex = 1
    }
    updateDrumKitData()


    -- scales
    scales = {
        ['chromatic'] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        ['pentatonic_major'] = { 0, 2, 4, 7, 9 },
        ['pentatonic_minor'] = { 0, 3, 5, 7, 10 },
        ['blues_major'] = { 0, 3, 4, 5, 6, 7, 10 },
        ['blues_minor'] = { 0, 3, 5, 6, 7, 10 },
        ['jazz_minor'] = { 0, 2, 3, 5, 7, 9, 11 },
        ['harmonic_minor'] = { 0, 2, 3, 5, 7, 8, 11 },
        ['melodic_minor'] = { 0, 2, 3, 5, 7, 9, 11 },
        ['major'] = { 0, 2, 4, 5, 7, 9, 11 },
        ['minor'] = { 0, 2, 3, 5, 7, 8, 10 },
        -- ['lydian'] = { 0, 2, 4, 6, 7, 9, 11 },
        -- ['mixolydian'] = { 0, 2, 4, 5, 7, 9, 10 },
        --
        -- ['locrian'] = { 0, 1, 3, 5, 6, 8, 10 },
        -- ['phrygian'] = { 0, 1, 3, 5, 7, 8, 10 },
        -- ['aeolian'] = { 0, 2, 3, 5, 7, 8, 10 },
        -- ['enigmatic'] = { 0, 1, 4, 6, 8, 10, 11 },
        -- ['double_harmonic_major'] = { 0, 1, 4, 5, 7, 8, 11 },
        -- ['hungarian_minor'] = { 0, 2, 3, 6, 7, 8, 11 },
        -- ['arabian'] = { 0, 2, 4, 5, 6, 8, 10 },
        -- ['altered'] = { 0, 1, 3, 4, 6, 8, 10 },
        -- ['prometheus'] = { 0, 2, 4, 6, 9, 10 },
        -- ['kumoi'] = { 0, 2, 3, 7, 9 },
        -- ['gypsy'] = { 0, 2, 4, 7, 8, 10 },
        -- ['lydian_augmented'] = { 0, 2, 4, 6, 8, 9, 11 },
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

function mapOffsetToNeareastScaleOffset(o, scale)
    local fullScale = {}
    local counter = 1
    for m = -2, 2 do
        for i = 1, #scale do
            fullScale[counter] = (m * 12) + scale[i]
            counter = counter + 1
        end
    end

    local bestOne = math.huge
    for i = 1, #fullScale do
        if (math.abs(fullScale[i] - o) < math.abs(bestOne - o)) then
            bestOne = fullScale[i]
        end
    end
    return bestOne
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

local function getSemitone(offset, optionalOctave)
    if optionalOctave ~= nil then
        return (optionalOctave * 12) + offset
    else
        return (octave * 12) + offset
    end
end

function love.keyreleased(k)
    if (usingMap[k] ~= nil) then
        local tuningOffset = instruments[instrumentIndex].tuning
        local formerOctave = octave
        if pressedKeys[k] then
            -- we need to know wha the settings were when we started pressing.
            -- because we need to release THAT button, not the one that would be triggered now.
            tuningOffset = pressedKeys[k].tuning
            formerOctave = pressedKeys[k].octave
            formerScale = pressedKeys[k].scale
            pressedKeys[k] = nil
        end
        sendMessageToAudioThread({
            type = "semitoneReleased",
            data = {
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], formerScale), formerOctave) + tuningOffset,

            }
        });
    end
end

--local chordIndex = 1

function love.keypressed(k)
    if k == '-' then
        local name, gridlength = drumPatterns.pickExistingPattern(drumgrid, drumkit)
        drumPatternName = name
        grid.columns = gridlength
        updateDrumKitData()
    end

    if (usingMap[k] ~= nil) then
        sendMessageToAudioThread({
            type = "semitonePressed",
            data = {
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], scale)) + instruments[instrumentIndex].tuning,
            }
        });
        pressedKeys[k] = { tuning = instruments[instrumentIndex].tuning, octave = octave, scale = scale }
    end

    if k == 'z' then
        octave = math.max(octave - 1, 0)
        print("Octave:", octave)
    elseif k == 'x' then
        octave = math.min(octave + 1, max_octave)
        print("Octave:", octave)
    end

    if k == 'c' then
        instruments[instrumentIndex].tuning = instruments[instrumentIndex].tuning + 1
        sendMessageToAudioThread({ type = "instruments", data = instruments })
    end
    if k == 'v' then
        instruments[instrumentIndex].tuning = instruments[instrumentIndex].tuning - 1
        sendMessageToAudioThread({ type = "instruments", data = instruments })
    end
    if k == 'b' then
        toggleScale()
    end

    if k == 'escape' then
        if fileBrowserForSound then
            fileBrowserForSound = nil
        elseif showDrumPatternPicker then
            showDrumPatternPicker = nil
        else
            sendMessageToAudioThread({ type = "paused", data = true });
            love.event.quit()
        end
    end

    if k == 'space' then
        playing = not playing

        if not playing then
            sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
            sendMessageToAudioThread({ type = "paused", data = true });
        end
        if playing then
            sendMessageToAudioThread({ type = "mode", data = 'play' });
            sendMessageToAudioThread({ type = "paused", data = false });
            recording = false
        end
    end
    if k == 'f5' then
        saveJizzJazzFile()
    end
    if k == 'return' then
        recording = not recording
        if not recording then
            sendMessageToAudioThread({ type = "paused", data = true });
            sendMessageToAudioThread({ type = "finalizeRecordedDataOnIndex", data = instrumentIndex })
            sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = instrumentIndex })
        end
        if recording then
            sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = instrumentIndex })
            sendMessageToAudioThread({ type = "mode", data = 'record' });
            sendMessageToAudioThread({ type = "paused", data = false });
            playing = false
        end
        sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
    end
end

function love.update(dt)
    repeat
        local msg = getMessageFromAudioThread()
        if msg then
            if msg.type == 'tickUpdate' then
                myTick = msg.data.tick
            end
            if msg.type == 'beatUpdate' then
                myBeat = msg.data.beat
                myBeatInMeasure = msg.data.beatInMeasure
            end
            if msg.type == 'numPlayingSounds' then
                myNumPlayingSounds = msg.data.numbers
            end
            if msg.type == 'recordedClip' then
                local index = msg.data.instrumentIndex
                local clip = msg.data.clip
                table.insert(recordedClips[index].clips, clip)
            end
        end
    until not msg
end

function drawDrumMachineGrid(startX, startY, cellW, cellH, columns, rows)
    love.graphics.setLineWidth(4)
    for y = 0, rows do
        love.graphics.setColor(.15, .15, .15, 1)
        for i = 0, columns - 1 do
            love.graphics.rectangle('line', startX + i * cellW, startY + y * cellH, cellW, cellH)
        end
    end
    love.graphics.setColor(.3, .3, .3, 1)
    love.graphics.line(startX + 4 * cellW, startY, startX + 4 * cellW, startY + cellH * (rows + 1))
    love.graphics.line(startX + 8 * cellW, startY, startX + 8 * cellW, startY + cellH * (rows + 1))
    love.graphics.line(startX + 12 * cellW, startY, startX + 12 * cellW, startY + cellH * (rows + 1))

    love.graphics.setLineWidth(1)
end

function drawDrumMachineLabelSingleRow(startX, startY, cellH, labels, rowIndex)
    local y = rowIndex
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(' ' .. labels[y], 0, startY)
end

function drawDrumOnNotesSingleRow(startX, startY, cellW, cellH, columns, rowIndex)
    love.graphics.setColor(1, 1, 1, 0.8)
    local xOff = (cellW - smallfont:getWidth('x')) / 2
    local y = rowIndex
    for x = 0, columns - 1 do
        if drumgrid[x + 1][y + 1].on == true then
            if drumgrid[x + 1][y + 1].flam == true then
                love.graphics.print('f', xOff + startX + x * cellW, startY)
            else
                love.graphics.print('x', xOff + startX + x * cellW, startY)
            end
        end
    end
end

function drawDrumOnNotes(startX, startY, cellW, cellH, columns, rows)
    love.graphics.setColor(1, 1, 1, 0.8)
    local xOff = (cellW - smallfont:getWidth('x')) / 2
    for y = 0, rows do
        for x = 0, columns - 1 do
            if drumgrid[x + 1][y + 1].on == true then
                if drumgrid[x + 1][y + 1].flam == true then
                    love.graphics.print('f', xOff + startX + x * cellW, startY + y * cellH)
                else
                    love.graphics.print('x', xOff + startX + x * cellW, startY + y * cellH)
                end
            end
        end
    end
end

function drawDrumMachineLabels(startX, startY, cellH, labels)
    local col = palette.fg2
    love.graphics.setColor(col[1], col[2], col[3], 0.3)

    for y = 0, #labels - 1 do
        if labelbutton(' ' .. labels[y + 1], 0, startY + y * cellH, 100, grid.cellH).clicked then
            lookinIntoIntrumentAtIndex = y + 1
        end
    end
end

function drawDrumMachinePlayHead(startX, startY, cellW, cellH, columns, rows)
    -- i think we are assuming there are 16 columns
    --if columns ~= 16 then print('something is wrong about amount of columns') end
    --if myBeatInMeasure ~= 4 then print('kinda has to have 4 beats in a measure i think') end

    local highlightedColumn = ((myBeat % myBeatInMeasure) * 4) + math.floor((myTick / 96) * 4)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.rectangle('line', startX + highlightedColumn * cellW, startY, cellW, cellH * (rows + 1))
    love.graphics.setLineWidth(1)
end

local function getCellUnderPosition(x, y)
    if x > grid.startX and x < grid.startX + (grid.cellW * grid.columns) then
        if y > grid.startY and y < grid.startY + (grid.cellH * (#grid.labels)) then
            return math.ceil((x - grid.startX) / grid.cellW), math.ceil((y - grid.startY) / grid.cellH)
        end
    end
    return -1, -1
end

local function getInstrumentIndexUnderPosition(x, y)
    if x >= 0 and x <= grid.startX then
        if y >= grid.startY and y < grid.startY + (grid.cellH * (#grid.labels)) then
            return math.ceil((y - grid.startY) / grid.cellH)
        end
    end
    return -1
end


function drawDrumMachine()
    love.graphics.setFont(smallfont)
    drawDrumMachineGrid(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, #grid.labels - 1)
    drawDrumMachineLabels(grid.startX, grid.startY, grid.cellH, grid.labels)
    drawDrumOnNotes(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, #grid.labels - 1)

    if playing or recording then
        drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, #grid.labels - 1)
    end
end

function drawMoreInfoForInstrument()
    local startX = grid.startX
    local startY = grid.startY
    local cellW = grid.cellW
    local cellH = grid.cellH

    if lookinIntoIntrumentAtIndex > 0 then
        drawDrumMachineGrid(startX, startY, cellW, cellH, grid.columns, 0)
        drawDrumOnNotesSingleRow(startX, startY, cellW, cellH, grid.columns,
            lookinIntoIntrumentAtIndex - 1)

        if labelbutton(' ' .. grid.labels[lookinIntoIntrumentAtIndex], 0, startY, 100, cellH).clicked then
            lookinIntoIntrumentAtIndex = 0
        end

        if labelbutton(' volume', 0, startY + cellH * 1, 100, cellH, singleInstrumentJob == 'volume').clicked then
            singleInstrumentJob = 'volume'
        end

        if labelbutton(' pitch', 0, startY + cellH * 2, 100, cellH, singleInstrumentJob == 'pitch').clicked then
            singleInstrumentJob = 'pitch'
        end

        if labelbutton(' pan', 0, startY + cellH * 3, 100, cellH, singleInstrumentJob == 'pan').clicked then
            singleInstrumentJob = 'pan'
        end


        if labelbutton(' gate', 0, startY + cellH * 4, 100, cellH, singleInstrumentJob == 'gate').clicked then
            singleInstrumentJob = 'gate'
        end
        if labelbutton(' echo', 0, startY + cellH * 5, 100, cellH, singleInstrumentJob == 'echo').clicked then
            singleInstrumentJob = 'echo'
        end
        if labelbutton(' randP', 0, startY + cellH * 6, 100, cellH, singleInstrumentJob == 'randP').clicked then
            singleInstrumentJob = 'randP'
        end
        if labelbutton(' trig', 0, startY + cellH * 7, 100, cellH, singleInstrumentJob == 'trig').clicked then
            singleInstrumentJob = 'trig'
        end
        if labelbutton(' wav', 0, startY + cellH * 8, 100, cellH, singleInstrumentJob == 'wav').clicked then
            fileBrowserForSound = { type = 'drum', index = lookinIntoIntrumentAtIndex }
            browser = fileBrowser("samples", {}, { "wav", "WAV" })
        end
        if singleInstrumentJob then
            if labelbutton(' reset', 0, startY + cellH * 9, 100, cellH).clicked then
                for i = 1, #drumgrid do
                    local cell = drumgrid[i][lookinIntoIntrumentAtIndex]
                    if (cell and cell.on) then
                        if singleInstrumentJob == 'volume' then
                            cell.volume = 1
                        end
                        if singleInstrumentJob == 'gate' then
                            cell.gate = 1
                        end
                        if singleInstrumentJob == 'pitch' then
                            cell.semitoneOffset = 0
                        end
                        if singleInstrumentJob == 'pan' then
                            cell.pan = 0
                        end
                    end
                end
                updateDrumKitData()
            end
        end

        for i = 1, #drumgrid do
            local cell = drumgrid[i][lookinIntoIntrumentAtIndex]
            if (cell and cell.on) then
                if singleInstrumentJob == 'randP' then
                    love.graphics.setLineWidth(4)
                    local circX = startX + (i - 1) * cellW + cellW / 2
                    local circY = startY + cellH * 1.5
                    love.graphics.circle('line', circX, circY, cellW / 2)
                    if cell.useRndP then
                        love.graphics.circle('fill', circX, circY, cellW / 3)
                    end

                    local r = getUIRect(circX - cellW / 2, circY - cellW / 2, cellW, cellW)
                    if r then
                        cell.useRndP = not cell.useRndP
                        updateDrumKitData()
                    end

                    local v = v_slider(singleInstrumentJob .. '1:' .. i, startX + cellW * (i - 1),
                        startY + cellH * 2, 100,
                        cell.rndPOctMin or 0, -2, 0, 'top')
                    if v.value then
                        cell.rndPOctMin = v.value
                        updateDrumKitData()
                    end
                    local v = v_slider(singleInstrumentJob .. '2:' .. i, startX + cellW * (i - 1),
                        startY + cellH * 2 + 100, 100,
                        cell.rndPOctMax or 0, 0, 2, 'bottom')
                    if v.value then
                        cell.rndPOctMax = v.value
                        updateDrumKitData()
                    end

                    love.graphics.setLineWidth(4)
                    local circX = startX + (i - 1) * cellW + cellW / 2
                    local circY = startY + 280
                    love.graphics.circle('line', circX, circY, cellW / 2)
                    if cell.useRndPPentatonic then
                        love.graphics.circle('fill', circX, circY, cellW / 3)
                    end

                    local r = getUIRect(circX - cellW / 2, circY - cellW / 2, cellW, cellW)
                    if r then
                        cell.useRndPPentatonic = not cell.useRndPPentatonic
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'trig' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, startX + cellW * (i - 1), startY + cellH, 200,
                        cell.trig or 1, 0, 1)
                    if v.value then
                        cell.trig = v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'gate' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, startX + cellW * (i - 1), startY + cellH, 200,
                        cell.gate or 1, 0, 1)
                    if v.value then
                        cell.gate = v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'pan' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        cell.pan or 0, -1, 1)
                    if v.value then
                        cell.pan = v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'volume' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        1.0 - (cell.volume or 1), 0, 1)
                    if v.value then
                        cell.volume = 1.0 - v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'pitch' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        (cell.semitoneOffset or 0) * -1, -24, 24)
                    if v.value then
                        local v = math.floor(v.value + 0.5) * -1
                        if love.keyboard.isDown('lshift') then
                            v = mapOffsetToNeareastScaleOffset(v, scales['pentatonic_minor'])
                        end
                        cell.semitoneOffset = v
                        updateDrumKitData()
                    end
                end
            end
        end


        if singleInstrumentJob == 'echo' then
            local xOff = (cellW - smallfont:getWidth('x')) / 2
            drawDrumMachineGrid(startX, startY + cellH, cellW, cellH, #drumgrid, 0)
            for i = 1, #drumgrid do
                local cell = drumgrid[i][lookinIntoIntrumentAtIndex]

                if (cell and cell.on) then
                    if cell.echo then
                        love.graphics.print(cell.echo .. "", xOff + startX + (i - 1) * cellW,
                            startY + cellH)
                    end
                    local r = getUIRect(startX + (i - 1) * cellW, startY + cellH,
                        cellW,
                        cellH)
                    if r then
                        if cell.echo == nil or cell.echo == 0 then
                            cell.echo = 1
                        elseif cell.echo >= 4 then
                            cell.echo = 0
                        else
                            cell.echo = cell.echo + 1
                        end
                        updateDrumKitData()
                    end
                end
            end
        end
    else
        print('shouldnt come here')
    end
end

function drawMouseOverMoreInfo()
    local x, y = love.mouse.getPosition()
    if x > 0 and x < 100 and y >= grid.startY and y <= grid.startY + grid.cellH then
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle('fill', 0, grid.startY, 100, grid.cellH)
    end
end

function drawMouseOverGrid()
    local x, y = love.mouse.getPosition()
    local cx, cy = getCellUnderPosition(x, y)
    if cx >= 0 and cy >= 0 then
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle('fill', grid.startX + (cx - 1) * grid.cellW, grid.startY + (cy - 1) * grid.cellH,
            grid.cellW, grid.cellH)
    end
end

function love.wheelmoved(a, b)
    if showDrumPatternPicker then
        handleDrumPickerWheelMoved(drummPatternPickData, a, b)
    end
    if fileBrowserForSound then
        handleFileBrowserWheelMoved(browser, a, b)
    end
end

function love.mousepressed(x, y, button)
    if fileBrowserForSound then
        local bclicked, path = handleBrowserClick(browser, x, y, smallfont)
        --print(path)
        if bclicked then
            mouseState.clickedSomething = true
            browserClicked = true
            --print('mouseState.clickedSomething', mouseState.clickedSomething)
            if bclicked == 'directory' then
                --print(browser.root, inspect(browser.subdirs))
                browser = fileBrowser(browser.root, browser.subdirs,
                    browser.allowedExtensions)
            else
                local sample = prepareSingleSample(browser.root, browser.subdirs, path)
                if sample then
                    if fileBrowserForSound.type == 'instrument' then
                        instruments[instrumentIndex].sample = sample
                        sendMessageToAudioThread({ type = "instruments", data = instruments })
                    end
                    if fileBrowserForSound.type == 'drum' then
                        local key = drumkit.order[lookinIntoIntrumentAtIndex]
                        drumkit[key] = sample
                        updateDrumKitData()
                    end
                end
                --print(browser.root, inspect(browser.subdirs), path)
            end
        end
    end
    if browserClicked then return end
    -- handleBrowserClick(browser, x, y)

    if lookinIntoIntrumentAtIndex <= 0 then
        local cx, cy = getCellUnderPosition(x, y)
        if cx >= 0 and cy >= 0 then
            -- print(cx, cy)
            local flam = false
            if love.keyboard.isDown('.') then
                flam = true
            end
            drumgrid[cx][cy] = { on = not drumgrid[cx][cy].on, flam = flam }
            updateDrumKitData()
        end
    else
        if lookinIntoIntrumentAtIndex > 0 then
            local cx, cy = getCellUnderPosition(x, y)

            if cx >= 0 and cy == 1 then
                local flam = false
                if love.keyboard.isDown('.') then
                    flam = true
                end
                drumgrid[cx][lookinIntoIntrumentAtIndex] = {
                    on = not drumgrid[cx][lookinIntoIntrumentAtIndex].on,
                    flam =
                        flam
                }
                updateDrumKitData()
            end
        end
    end
    --print(lookinIntoIntrumentAtIndex)
end

function love.mousereleased()
    lastDraggedElement = nil
end

function drawDrumParts(x, y)
    -- here we have 6 buttons to arm and play various drumparts that are in 1 song (verse choris, fill etc)
    local font = smallfont
    love.graphics.setFont(font)
    local labels = { '1', '2', '3', '4', '5', '6' }
    local w = font:getWidth('X') + 4
    local xOff = (w - smallfont:getWidth('x')) / 2
    local h = font:getHeight()
    local col = palette.fg2
    love.graphics.setColor(col[1], col[2], col[3], 0.25)
    love.graphics.setLineWidth(4)
    for i = 1, 3 do
        love.graphics.rectangle('line', x + w * (i - 1), y, w, h)
        love.graphics.print(labels[i], xOff + x + w * (i - 1), y)
    end
    for i = 4, 6 do
        love.graphics.rectangle('line', x + w * (i - 4), y + h, w, h)
        love.graphics.print(labels[i], xOff + x + w * (i - 4), y + h)
    end
end

function handleDrumPickerWheelMoved(pickData, a, b)
    local mx, my = love.mouse:getPosition()
    local columnWidth = 200
    if mx > 32 and mx < columnWidth + 32 then
        pickData.scrollLeft = pickData.scrollLeft + b
    end
    if mx > columnWidth + 32 and mx < (columnWidth * 2) + 32 then
        pickData.scrollRight = pickData.scrollRight + b
    end
end

function drawDrumPatternPicker(pickData)
    local leftColumn = {}
    local yOffset = 100
    local font = smallfont
    local fontH = font:getHeight()
    local w, h = love.graphics.getDimensions()
    local panelHeight = h - 200
    local columnWidth = 200
    local panelWidth = columnWidth * 2

    love.graphics.setColor(palette.bg0)
    love.graphics.rectangle('fill', 32, 100, panelWidth, panelHeight)
    local index = pickData.pickedCategoryIndex --pickedDrumCategory
    local index2 = pickData.pickedItemIndex

    pickData.scrollLeft = math.min(0, pickData.scrollLeft)
    local inList = #drumPatterns.patterns
    if panelHeight / fontH < inList then
        if (pickData.scrollLeft - panelHeight / fontH < inList * -1) then
            pickData.scrollLeft = (inList - panelHeight / fontH) * -1
        end
    end

    --print(pickData.scrollRight)

    local inList = #drumPatterns.patterns[index].sections
    pickData.scrollRight = math.min(0, pickData.scrollRight)
    if panelHeight / fontH < inList then
        if (pickData.scrollRight - panelHeight / fontH < (#drumPatterns.patterns[index].sections) * -1) then
            pickData.scrollRight = (#drumPatterns.patterns[index].sections - panelHeight / fontH) * -1
        end
    else
        pickData.scrollRight = 0
    end
    for i = 1, #drumPatterns.patterns do
        love.graphics.setColor(palette.fg2)

        local str = drumPatterns.patterns[i].name
        local buttonW = columnWidth
        if i == index then
            love.graphics.setColor(palette.orange)
            love.graphics.rectangle('fill', 32, (pickData.scrollLeft * fontH) + yOffset + (i - 1) * fontH, buttonW, fontH)
            love.graphics.setColor(1, 1, 1, 1)
        end

        if labelbutton(str, 32, (pickData.scrollLeft * fontH) + yOffset + (i - 1) * fontH, buttonW, fontH, true).clicked then
            pickData.pickedCategoryIndex = i
        end
    end

    for i = 1, #drumPatterns.patterns[index].sections do
        local it = drumPatterns.patterns[index].sections[i]
        love.graphics.setColor(1, 1, 1, 1)

        local str = it.name
        local buttonW = columnWidth

        if i == index2 then
            love.graphics.setColor(palette.orange)
            love.graphics.rectangle('fill', 32 + columnWidth, (pickData.scrollRight * fontH) + yOffset + (i - 1) * fontH,
                buttonW,
                fontH)
            love.graphics.setColor(1, 1, 1, 1)
        end
        if labelbutton(str, 32 + columnWidth, (pickData.scrollRight * fontH) + yOffset + (i - 1) * fontH, buttonW, fontH, true).clicked then
            drumPatternName = drumPatterns.pickPatternByIndex(index, i)
            pickData.pickedItemIndex = i
        end
    end
end

function drawMeasureCounter(x, y)
    if (recording or playing) then
        local font = bigfont
        love.graphics.setFont(font)

        local str = string.format("%02d", math.floor(myBeat / myBeatInMeasure)) ..
            '|' .. string.format("%01d", math.floor(myBeat % myBeatInMeasure))
        local xOff = font:getWidth(str) / 2
        love.graphics.print(str, x - xOff + font:getHeight(), y + 0)
        if (math.floor(myBeat / myBeatInMeasure) < 0) then
            love.graphics.setColor(1, 1, 0)
        else
            if recording then
                love.graphics.setColor(1, 0, 0, 0.8)
            else
                love.graphics.setColor(0, 1, 0, 0.8)
            end
        end
        love.graphics.circle('fill', x - xOff + font:getHeight() / 2, y + font:getHeight() / 2, font:getHeight() / 3)
    end
end

function drawADSRForActiveInstrument(x, y)
    local rainbow = { palette.red, palette.orange, palette.yellow, palette.green, palette.blue }

    local color = rainbow[instrumentIndex]
    love.graphics.setColor(color[1], color[2], color[3], 0.3)
    love.graphics.rectangle('line', x - 50, y, 300 + 100, 70)
    love.graphics.setColor(1, 1, 1)
    local adsr = instruments[instrumentIndex].adsr

    local bx, by = x, y + 20
    local v = drawLabelledKnob('attack', bx, by, adsr.attack, 0, 1)
    if v.value then
        drawLabel(string.format("%.2f", v.value), bx, by, 1)
        instruments[instrumentIndex].adsr.attack = v.value
        sendMessageToAudioThread({ type = "instruments", data = instruments });
    end
    local bx, by = x + 100, y + 20
    local v = drawLabelledKnob('decay', bx, by, adsr.decay, 0, 1)
    if v.value then
        drawLabel(string.format("%.2f", v.value), bx, by, 1)
        instruments[instrumentIndex].adsr.decay = v.value
        sendMessageToAudioThread({ type = "instruments", data = instruments });
    end
    local bx, by = x + 200, y + 20
    local v = drawLabelledKnob('sustain', bx, by, adsr.sustain, 0, 1)
    if v.value then
        drawLabel(string.format("%.1f", v.value), bx, by, 1)
        instruments[instrumentIndex].adsr.sustain = v.value
        sendMessageToAudioThread({ type = "instruments", data = instruments });
    end

    local bx, by = x + 300, y + 20
    local v = drawLabelledKnob('release', bx, by, adsr.release, 0, 1)

    if v.value then
        drawLabel(string.format("%.1f", v.value), bx, by, 1)
        instruments[instrumentIndex].adsr.release = v.value
        sendMessageToAudioThread({ type = "instruments", data = instruments });
    end
end

function drawInstrumentBanks(x, y)
    local font = smallfont
    love.graphics.setFont(font)
    local rowHeight = smallfont:getHeight() * 2.5
    local rowWidth = 300
    local gray = palette.gray
    local rainbow = { palette.red, palette.orange, palette.yellow, palette.green, palette.blue }
    local margin = 4

    for i = 1, #instruments do
        local font = smallfont
        love.graphics.setFont(font)
        love.graphics.setLineWidth(4)
        love.graphics.setColor(gray[1], gray[2], gray[3], 0.3)
        local color = rainbow[i]
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        if instrumentIndex == i then
            love.graphics.setColor(color[1], color[2], color[3], 0.8)
        end

        love.graphics.rectangle('fill', x, y + (i - 1) * (rowHeight + margin), rowWidth, rowHeight)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setColor(0, 0, 0)
        if instrumentIndex == i then
            love.graphics.setColor(1, 1, 1)
        end
        -- print(instruments[i].sample.name)
        local name = instruments[i].sample.name --samples[instruments[i].sampleIndex].name
        love.graphics.print(' ' .. name, x, y + (i - 1) * (rowHeight + margin))


        if browserClicked == false then
            local r = getUIRect(x, y + (i - 1) * (rowHeight + margin), rowWidth, rowHeight)

            if r then
                print('click instr')
                instrumentIndex = i
                sendMessageToAudioThread({ type = "instrumentIndex", data = instrumentIndex })
            end
        end
        if instrumentIndex == i then
            local buttonw = font:getWidth('wav')
            local buttonh = rowHeight / 2
            local buttony = y + (i - 1) * (rowHeight + margin) + buttonh
            if labelbutton('wav', x, buttony, buttonw, buttonh, false).clicked == true then
                --print('gonna do the wav')


                print(inspect(instruments[instrumentIndex].sample.pathParts))
                local pathParts = instruments[instrumentIndex].sample.pathParts
                browser = fileBrowser(browser.root, pathParts.pathArray,
                    browser.allowedExtensions)
                fileBrowserForSound = { type = 'instrument', index = instrumentIndex }
            end
        end
        if #recordedClips[i].clips > 0 and instrumentIndex == i then
            local buttonw = font:getWidth('edit clips')
            local buttonh = rowHeight / 2
            local buttony = y + (i - 1) * (rowHeight + margin) + buttonh
            if labelbutton('edit clips', x + rowWidth - buttonw, buttony, buttonw, buttonh, false).clicked == true then
                print('gonna do the clip')
            end
        end

        --- the clips
        local startX = x + rowWidth
        local startY = y + (i - 1) * (rowHeight + margin)
        local clipSize = (rowHeight / 2) - 1
        local maxColumns = 5
        --print(i, #recordedClips[i].clips)

        for j = 1, #recordedClips[i].clips do
            local columnIndex = (j - 1) % maxColumns
            local rowIndex = math.floor((j - 1) / maxColumns)
            local x = startX + (columnIndex * (clipSize + 2))
            local y = startY + (rowIndex * (clipSize + 2))

            if instrumentIndex == i then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.rectangle('fill', x, y, clipSize, clipSize)
                love.graphics.setColor(color[1], color[2], color[3], 0.8)
                love.graphics.rectangle('fill', x, y, clipSize, clipSize)
            else
                love.graphics.setColor(.1, .1, .1, 0.8)
                love.graphics.rectangle('fill', x, y, clipSize, clipSize)
                love.graphics.setColor(color[1], color[2], color[3], 0.3)
                love.graphics.rectangle('fill', x, y, clipSize, clipSize)
            end
            local font = smallestfont
            love.graphics.setFont(smallestfont)
            local loopRounder = (recordedClips[i].clips[j].meta.loopRounder)
            local str = #recordedClips[i].clips[j] .. '\n' .. loopRounder

            local xOff = (clipSize - font:getWidth(str .. '')) / 2
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.print(str .. '', x + xOff, y)
        end
    end
end

function love.draw()
    love.graphics.clear(0, 0, 0)
    local w, h = love.graphics.getDimensions()
    handleMouseClickStart()




    love.graphics.setColor(1, 1, 1)
    --drawDrumParts(4, 4)

    --    print(inspect(browser))



    if lookinIntoIntrumentAtIndex <= 0 then
        if (not showDrumPatternPicker) then
            drawDrumMachine()
            drawMouseOverGrid()
        end
    end

    if lookinIntoIntrumentAtIndex > 0 then
        drawMoreInfoForInstrument()
        drawMouseOverMoreInfo()
        if playing then
            drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, 0)
        end
    end

    love.graphics.setColor(1, 1, 1)
    drawMeasureCounter(w / 2, 20)

    drawInstrumentBanks((w / 2) + 32, 120)

    drawADSRForActiveInstrument((w / 2) + 32 + 50, 120 + 380)

    love.graphics.setColor(1, 1, 1)


    if fileBrowserForSound then
        if fileBrowserForSound.type == 'instrument' then
            if labelbutton('ok', (w / 2) + 64, 90, 100, 30, false).clicked == true then
                fileBrowserForSound = nil
            end

            renderBrowser(browser, (w / 2) + 64, 120, (w / 2) - 128, h - 240, smallfont)
        end
    end
    if fileBrowserForSound then
        if fileBrowserForSound.type == 'drum' then
            --fileBrowserForSound = { type = 'drum', index = lookinIntoIntrumentAtIndex }
            if labelbutton('ok', 64, 90, 100, 30, false).clicked == true then
                print('jojo')
                fileBrowserForSound = nil
            end

            renderBrowser(browser, 64, 120, (w / 2) - 128, h - 240, smallfont)
        end
    end
    local font = smallfont
    love.graphics.setFont(font)

    local stats = love.graphics.getStats()
    local memavg = collectgarbage("count") / 1000
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = string.format("%03i", love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    local countNotes = string.format("%02i", myNumPlayingSounds)
    local debugstring = mem ..
        '  ' .. vmem .. '  ' .. draws .. ' ' .. fps .. ' ' .. countNotes .. ' ' .. love.audio.getActiveSourceCount()
    love.graphics.setColor(1, 1, 1, .5)
    love.graphics.print(debugstring, 0, h - font:getHeight())


    --print()
    --drawLabelledKnob(drumPatternName, bx, by, adsr.release, 0, 1)

    if labelbutton(drumPatternName, 0, 32 + font:getHeight(), font:getWidth(drumPatternName),
            font:getHeight()).clicked then
        showDrumPatternPicker = not showDrumPatternPicker
    end
    if (showDrumPatternPicker) then
        drawDrumPatternPicker(drummPatternPickData)
    end
    --love.graphics.print(drumPatternName, 0, 32 + font:getHeight())


    local bx, by = grid.startX + grid.cellW * (grid.columns + 2), grid.startY + grid.cellH * 1
    local v = drawLabelledKnob('bpm', bx, by, uiData.bpm, 10, 200)
    if v.value then
        drawLabel(string.format("%.0i", v.value), bx, by, 1)
        uiData.bpm = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (grid.columns + 2), grid.startY + grid.cellH * 3
    local v = drawLabelledKnob('swing', bx, by, uiData.swing, 50, 80)
    if v.value then
        drawLabel(string.format("%.0i", v.value), bx, by, 1)
        uiData.swing = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (grid.columns + 2), grid.startY + grid.cellH * 5
    local v = drawLabelledKnob('drums', bx, by, uiData.drumVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), bx, by, 1)
        uiData.drumVolume = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (grid.columns + 2), grid.startY + grid.cellH * 7
    local v = drawLabelledKnob('instr', bx, by, uiData.instrumentsVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), bx, by, 1)
        uiData.instrumentsVolume = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (grid.columns + 2), grid.startY + grid.cellH * 9
    local v = drawLabelledKnob('semi', bx, by, uiData.allDrumSemitoneOffset, -72, 48)
    if v.value then
        drawLabel(string.format("%02.1i", v.value), bx, by, 1)
        uiData.allDrumSemitoneOffset = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    browserClicked = false
end

function drawLabelledKnob(label, x, y, value, min, max)
    drawLabel(label, x, y + 32)
    local v = draw_knob(label, x, y, value, min, max)
    return v
end

function drawLabel(str, x, y, alpha)
    local col = palette.fg2
    love.graphics.setColor(col[1], col[2], col[3], alpha or .2)
    local font = smallfont
    love.graphics.setFont(font)
    local strW = font:getWidth(str)
    local strH = font:getHeight()
    love.graphics.print(str, x - strW / 2, y - strH / 2)
end

--
