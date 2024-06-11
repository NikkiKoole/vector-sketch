function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        print(a)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

print('before wait for event')
waitForEvent()
print('after wait for event')


package.path = package.path .. ";../../?.lua"

sone = require 'sone'
require 'ui'
require 'wordsmith'

local text         = require 'lib.text'
local inspect      = require 'vendor.inspect'
local drumPatterns = require 'drum-patterns'
local audiohelper  = require 'lib.jizzjazz-audiohelper'
audiohelper.startAudioThread()
require 'fileBrowser'

--luamidi = require "luamidi"

local function clear()
    for x = 1, #audiohelper.drumgrid do
        for y = 1, #audiohelper.drumgrid[1] do
            audiohelper.drumgrid[x][y] = { on = false }
        end
    end

    local totalSections = 0
    for i = 1, #drumPatterns do
        totalSections = totalSections + #drumPatterns[i].sections
    end
end

local function fill(pattern, part)
    return audiohelper.drumPatternFill(pattern, part)
end

function pickPatternByIndex(index1, index2)
    -- clear it
    --print('picking pattern by i dex')
    clear()
    local patternIndex = index1 --math.ceil(love.math.random() * #patterns)
    local pattern = drumPatterns[patternIndex]

    local partIndex = index2

    local part = drumPatterns[patternIndex].sections[partIndex]

    return fill(pattern, part)
end

function pickExistingPattern(drumgrid, drumkit)
    -- clear it
    clear()

    local patternIndex = math.ceil(love.math.random() * #drumPatterns)
    local pattern = drumPatterns[patternIndex]

    local partIndex = math.ceil(love.math.random() * #pattern.sections)

    local part = drumPatterns[patternIndex].sections[partIndex]
    drummPatternPickData.pickedCategoryIndex = patternIndex
    drummPatternPickData.pickedItemIndex = partIndex

    return fill(pattern, part)
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

function love.filedropped(file)
    local filename = file:getFilename()

    if text.ends_with(filename, 'jizzjazz2.txt') then
        file:open("r")
        local data = file:read()
        local obj = (loadstring("return " .. data)())
        audiohelper.loadJizzJazzFile(obj, filename)
        -- print(inspect(obj))
        -- file:close()
    end
end

function love.load()
    bigfont = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    smallestfont = love.graphics.newFont('WindsorBT-Roman.otf', 16)
    smallfont = love.graphics.newFont('WindsorBT-Roman.otf', 24)
    musicfont = love.graphics.newFont('NotoMusic-Regular.ttf', 48)

    title = getRandomName()
    showMixer = false

    messageAlpha = 0
    msg = nil
    messageTime = nil

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

    instrumentIndex = 1
    drumIndex       = 0
    drumJob         = nil
    activeDrumPart  = 1

    uiData          = {
        bpm = 90,
        swing = 50,
        instrumentsVolume = 1,
        drumVolume = 1,
        allDrumSemitoneOffset = 0
    }
    audiohelper.sendMessageToAudioThread({
        type = 'metronome-sound',
        data = love.audio.newSource(
            "samples/cr78/Rim Shot.wav", "static")
    })
    audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    -- livelooping
    recording = false
    playing = false

    waitingForTriggerToStartRecording = false

    pressedKeys = {}

    audiohelper.sendMessageToAudioThread({ type = "resetBeatsAndTicks" });

    browser             = fileBrowser("samples", {}, { "wav", "WAV" })
    browserClicked      = false
    fileBrowserForSound = nil

    max_octave          = 8
    octave              = 4

    local samples       = {
        audiohelper.prepareSingleSample({ "oscillators", "fr4 korg" }, 'Fr4 - Korg MS-10 2.wav'),
        audiohelper.prepareSingleSample({ "oscillators", "fr4 moog" }, 'Fr4 - MemoryMoog 4.wav'),
        audiohelper.prepareSingleSample({ "oscillators", "akwf", "ebass" }, 'AKWF_ebass_0009.wav'),
        audiohelper.prepareSingleSample({ "oscillators", "100 Void Vertex SCW" }, 'twinkle.wav'),
        audiohelper.prepareSingleSample({ "legow" }, 'Pinky Flute.wav'),
    }

    audiohelper.initializeInstruments(samples)
    audiohelper.sendMessageToAudioThread({ type = "instruments", data = audiohelper.instruments })
    audiohelper.sendMessageToAudioThread({ type = "instrumentIndex", data = instrumentIndex })

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
        CB = { { 'cr78' }, 'Cowbell' },
        QU = { { 'mp7' }, 'Quijada' }
    }
    local drumkitMP7 = {
        order = { 'AC', 'BD', 'SD', 'LT', 'MT', 'HT', 'CH', 'OH', 'CY', 'RS', 'CPS', 'TB', 'CB', 'QU' },
        AC = { { 'mp7' }, '808 Kick' },
        BD = { { 'mp7' }, 'Kickdrum' },
        SD = { { 'mp7' }, 'Snare1' },
        LT = { { 'mp7' }, 'Bongo3' },
        MT = { { 'mp7' }, 'Bongo2' },
        HT = { { 'mp7' }, 'Bongo1' },
        CH = { { 'mp7' }, 'Maracas' },
        OH = { { 'mp7' }, 'Cymbal1' },
        CY = { { 'mp7' }, 'Cymbal2' },
        RS = { { 'mp7' }, 'Rimshot' },
        CPS = { { 'mp7' }, 'Guira' },
        TB = { { 'mp7' }, 'Tambourine' },
        CB = { { 'mp7' }, 'Clave' },
        QU = { { 'mp7' }, 'Quijada' }
    }

    audiohelper.setDrumKitFiles(drumkitCR78)

    grid = {
        startX = 150,
        startY = 120,
        cellW = 20,
        cellH = 32,
        --columns = 16,
        --labels = audiohelper.drumkit.order
    }
    audiohelper.setColumns(16)
    audiohelper.setLabels(audiohelper.drumkit.order)


    audiohelper.initializeMixer()
    audiohelper.initializeDrumgrid()
    audiohelper.updateMixerData()

    drumPatternName = ''
    drummPatternPickData = {
        scrollLeft = 0,
        scrollRight = 0,
        pickedCategoryIndex = 1,
        pickedItemIndex = 1
    }
    audiohelper.updateDrumKitData()

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
        ['lydian'] = { 0, 2, 4, 6, 7, 9, 11 },
        ['mixolydian'] = { 0, 2, 4, 5, 7, 9, 10 },

        ['locrian'] = { 0, 1, 3, 5, 6, 8, 10 },
        ['phrygian'] = { 0, 1, 3, 5, 7, 8, 10 },
        ['aeolian'] = { 0, 2, 3, 5, 7, 8, 10 },
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
    return nextScaleKey
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

function handleMIDIInput()
    if luamidi and luamidi.getinportcount() > 0 then
        local msg, semitone, velocity, d = nil
        msg, semitone, velocity, d = luamidi.getMessage(0)
        --https://en.wikipedia.org/wiki/List_of_chords
        --local integers = {0, 4,7,11}


        --local integers = {0, 4, 7, 11}
        --local integers = {0, 3, 7, 9}
        if msg ~= nil then
            -- look for an NoteON command

            if msg == 144 then
                if (waitingForTriggerToStartRecording) then
                    waitingForTriggerToStartRecording = false
                    audiohelper.sendMessageToAudioThread({ type = "mode", data = 'record' });
                    audiohelper.sendMessageToAudioThread({ type = "paused", data = false });
                    playing = false
                    recording = true
                end

                --local semitone = b
                audiohelper.sendMessageToAudioThread({
                    type = "semitonePressed",
                    data = {
                        velocity = velocity,
                        semitone = semitone + audiohelper.instruments[instrumentIndex].tuning,
                    }
                });
            elseif msg == 128 then
                --local semitone = b
                audiohelper.sendMessageToAudioThread({
                    type = "semitoneReleased",
                    data = {
                        semitone = semitone + audiohelper.instruments[instrumentIndex].tuning,
                        instrumentIndex = instrumentIndex
                    }
                });
            end
        end
    end
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
        local tuningOffset = audiohelper.instruments[instrumentIndex].tuning
        local formerOctave = octave
        local formerInstrumentIndex = instrumentIndex
        local formerScale = scale

        if pressedKeys[k] then
            -- we need to know wha the settings were when we started pressing.
            -- because we need to release THAT button, not the one that would be triggered now.
            tuningOffset = pressedKeys[k].tuning
            formerOctave = pressedKeys[k].octave
            formerScale = pressedKeys[k].scale
            formerInstrumentIndex = pressedKeys[k].instrumentIndex
            pressedKeys[k] = nil
        end
        audiohelper.sendMessageToAudioThread({
            type = "semitoneReleased",
            data = {
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], formerScale), formerOctave) + tuningOffset,
                instrumentIndex = formerInstrumentIndex
            }
        });
    end
end

--local chordIndex = 1

function updateMessage()
    if msg and messageTime then
        local now = love.timer.getTime()
        if now - messageTime < 1 then
            messageAlpha = 1.0 - (now - messageTime)
        else
            msg = nil
        end
    end
    --messageAlpha
end

function message(str)
    messageAlpha = 1
    messageTime = love.timer.getTime()
    msg = str
end

function love.keypressed(k)
    if k == '-' then
        local name, gridlength = pickExistingPattern(drumgrid, drumkit)
        drumPatternName = name

        audiohelper.setColumns(gridlength)
        audiohelper.updateDrumKitData()
    end

    if (usingMap[k] ~= nil) then
        if (waitingForTriggerToStartRecording) then
            waitingForTriggerToStartRecording = false
            audiohelper.sendMessageToAudioThread({ type = "mode", data = 'record' });
            audiohelper.sendMessageToAudioThread({ type = "paused", data = false });
            playing = false
            recording = true
        end

        audiohelper.sendMessageToAudioThread({
            type = "semitonePressed",
            data = {
                velocity = 128,
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], scale)) +
                    audiohelper.instruments[instrumentIndex].tuning,
            }
        });

        pressedKeys[k] = {
            tuning = audiohelper.instruments[instrumentIndex].tuning,
            octave = octave,
            scale = scale,
            instrumentIndex =
                instrumentIndex
        }
    end

    if k == 'z' then
        octave = math.max(octave - 1, 0)
        message('octave: ' .. octave)
    elseif k == 'x' then
        octave = math.min(octave + 1, max_octave)
        message('octave: ' .. octave)
    end

    if k == 'c' then
        if love.keyboard.isDown('lshift') then
            local newTuning = audiohelper.tuneRTInstrumentBySemitone(instrumentIndex, 1)
            message('rt tuning: ' .. newTuning)
        else
            local newTuning = audiohelper.tuneInstrumentBySemitone(instrumentIndex, 1)
            message('tuning: ' .. newTuning)
        end
    end

    if k == 'v' then
        if love.keyboard.isDown('lshift') then
            local newTuning = audiohelper.tuneRTInstrumentBySemitone(instrumentIndex, -1)
            message('rt tuning: ' .. newTuning)
        else
            local newTuning = audiohelper.tuneInstrumentBySemitone(instrumentIndex, -1)
            message('tuning: ' .. newTuning)
        end
    end

    if k == 'b' then
        local s = toggleScale()
        message('scale: ' .. s)
    end

    if k == 'escape' then
        if fileBrowserForSound then
            fileBrowserForSound = nil
        elseif showDrumPatternPicker then
            showDrumPatternPicker = nil
        else
            audiohelper.sendMessageToAudioThread({ type = "paused", data = true });
            love.event.quit()
        end
    end

    if k == 'space' then
        if recording then
            love.keypressed('return')
        else
            playing = not playing

            if not playing then
                for i = 1, #audiohelper.instruments do
                    audiohelper.sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = i })
                end
                audiohelper.sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
                audiohelper.sendMessageToAudioThread({ type = "paused", data = true });
            end
            if playing then
                audiohelper.sendMessageToAudioThread({ type = "mode", data = 'play' });
                audiohelper.sendMessageToAudioThread({ type = "paused", data = false });
                recording = false
            end
        end
    end
    if k == 'f5' then
        audiohelper.saveJizzJazzFile()
    end
    if k == 'return' then
        recording = not recording
        if not recording then
            audiohelper.sendMessageToAudioThread({ type = "paused", data = true });
            audiohelper.sendMessageToAudioThread({ type = "finalizeRecordedDataOnIndex", data = instrumentIndex })
            audiohelper.sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = instrumentIndex })
            audiohelper.sendMessageToAudioThread({ type = "mode", data = 'play' });
        end
        if recording then
            audiohelper.sendMessageToAudioThread({ type = "stopPlayingSoundsOnIndex", data = instrumentIndex })
            audiohelper.sendMessageToAudioThread({ type = "mode", data = 'record' });
            audiohelper.sendMessageToAudioThread({ type = "paused", data = false });
            playing = false
        end
        audiohelper.sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
    end
end

function love.update(dt)
    updateMessage()
    audiohelper.pumpAudioThread()
    handleMIDIInput()
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
    for j = 0, columns, 4 do
        love.graphics.line(startX + j * cellW, startY, startX + j * cellW, startY + cellH * (rows + 1))
        -- love.graphics.line(startX + 4 * cellW, startY, startX + 4 * cellW, startY + cellH * (rows + 1))
        -- love.graphics.line(startX + 8 * cellW, startY, startX + 8 * cellW, startY + cellH * (rows + 1))
        -- love.graphics.line(startX + 12 * cellW, startY, startX + 12 * cellW, startY + cellH * (rows + 1))
    end
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
    local k = 1
    for x = 0, columns - 1 do
        if audiohelper.drumgrid[k][x + 1][y + 1].on == true then
            if audiohelper.drumgrid[k][x + 1][y + 1].flam == true then
                love.graphics.print('f', xOff + startX + x * cellW, startY)
            else
                love.graphics.print('x', xOff + startX + x * cellW, startY)
            end
        end
    end
end

function drawDrumOnNotes(startX, startY, cellW, cellH, columns, rows)
    love.graphics.setColor(1, 1, 1, 0.8)
    local k = 1
    local xOff = (cellW - smallfont:getWidth('x')) / 2
    for y = 0, rows do
        for x = 0, columns - 1 do
            if audiohelper.drumgrid[k][x + 1][y + 1].on == true then
                if audiohelper.drumgrid[k][x + 1][y + 1].flam == true then
                    love.graphics.print('f', xOff + startX + x * cellW, startY + y * cellH)
                else
                    love.graphics.print('x', xOff + startX + x * cellW, startY + y * cellH)
                end
            end
        end
    end
end

function drawMixerStuff(startX, startY, cellH, labels)
    for i = 1, #audiohelper.mixDataDrums do
        local it = audiohelper.mixDataDrums[i]
        local v = draw_knob(labels[i], startX - 120, cellH / 2 + startY + (i - 1) * cellH, it.volume, 0, 1, 24)
        if v.value then
            audiohelper.mixDataDrums[i].volume = v.value
            audiohelper.updateMixerData()
        end
    end
    local w, h = love.graphics.getDimensions()
    for i = 1, 5 do
        local it = audiohelper.mixDataInstruments[i]
        local v = draw_knob('instr' .. i, w / 2 + 16, cellH / 2 + startY + (i - 1) * 75, it.volume, 0, 1, 24)
        if v.value then
            audiohelper.mixDataInstruments[i].volume = v.value
            audiohelper.updateMixerData()
        end
    end
end

function drawDrumMachineLabels(startX, startY, cellH, labels)
    local col = palette.fg2
    love.graphics.setColor(col[1], col[2], col[3], 0.3)

    for y = 0, #labels - 1 do
        if labelbutton(' ' .. labels[y + 1], startX - 100, startY + y * cellH, 100, grid.cellH).clicked then
            drumIndex = y + 1
            print(drumIndex)
        end
    end
end

function drawDrumMachinePlayHead(startX, startY, cellW, cellH, columns, rows)
    -- i think we are assuming there are 16 columns
    --if columns ~= 16 then print('something is wrong about amount of columns') end
    --if myBeatInMeasure ~= 4 then print('kinda has to have 4 beats in a measure i think') end
    local myBeat = audiohelper.myBeat
    local myBeatInMeasure = audiohelper.myBeatInMeasure
    local highlightedColumn = ((myBeat % myBeatInMeasure) * 4) + math.floor((audiohelper.myTick / 96) * 4)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.rectangle('line', startX + highlightedColumn * cellW, startY, cellW, cellH * (rows + 1))
    love.graphics.setLineWidth(1)
end

local function getCellUnderPosition(x, y)
    if x > grid.startX and x < grid.startX + (grid.cellW * audiohelper.columns) then
        if y > grid.startY and y < grid.startY + (grid.cellH * (#audiohelper.labels)) then
            return math.ceil((x - grid.startX) / grid.cellW), math.ceil((y - grid.startY) / grid.cellH)
        end
    end
    return -1, -1
end

local function getInstrumentIndexUnderPosition(x, y)
    if x >= 0 and x <= grid.startX then
        if y >= grid.startY and y < grid.startY + (grid.cellH * (#audiohelper.labels)) then
            return math.ceil((y - grid.startY) / grid.cellH)
        end
    end
    return -1
end


function drawDrumMachine()
    love.graphics.setFont(smallfont)

    drawDrumMachineGrid(grid.startX, grid.startY, grid.cellW, grid.cellH, audiohelper.columns, #audiohelper.labels - 1)
    if showMixer then
        drawMixerStuff(grid.startX + 150 + audiohelper.columns * grid.cellW, grid.startY, grid.cellH, audiohelper.labels)
    end
    drawDrumMachineLabels(grid.startX, grid.startY, grid.cellH, audiohelper.labels)
    drawDrumOnNotes(grid.startX, grid.startY, grid.cellW, grid.cellH, audiohelper.columns, #audiohelper.labels - 1)

    if playing or recording then
        drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, audiohelper.columns,
            #audiohelper.labels - 1)
    end
end

function drawMoreInfoForInstrument()
    local startX = grid.startX
    local startY = grid.startY
    local cellW = grid.cellW
    local cellH = grid.cellH

    local buttonX = startX - 100
    local k = 1
    if drumIndex > 0 then
        drawDrumMachineGrid(startX, startY, cellW, cellH, audiohelper.columns, 0)
        drawDrumOnNotesSingleRow(startX, startY, cellW, cellH, audiohelper.columns, drumIndex - 1)

        if labelbutton(' ' .. audiohelper.labels[drumIndex], buttonX, startY, 100, cellH).clicked then
            drumIndex = 0
        end

        if labelbutton(' volume', buttonX, startY + cellH * 1, 100, cellH, drumJob == 'volume').clicked then
            drumJob = 'volume'
        end

        if labelbutton(' pitch', buttonX, startY + cellH * 2, 100, cellH, drumJob == 'pitch').clicked then
            drumJob = 'pitch'
        end

        if labelbutton(' pan', buttonX, startY + cellH * 3, 100, cellH, drumJob == 'pan').clicked then
            drumJob = 'pan'
        end

        if labelbutton(' gate', buttonX, startY + cellH * 4, 100, cellH, drumJob == 'gate').clicked then
            drumJob = 'gate'
        end
        if labelbutton(' echo', buttonX, startY + cellH * 5, 100, cellH, drumJob == 'echo').clicked then
            drumJob = 'echo'
        end
        if labelbutton(' randP', buttonX, startY + cellH * 6, 100, cellH, drumJob == 'randP').clicked then
            drumJob = 'randP'
        end
        if labelbutton(' trig', buttonX, startY + cellH * 7, 100, cellH, drumJob == 'trig').clicked then
            drumJob = 'trig'
        end
        if labelbutton(' delay', buttonX, startY + cellH * 8, 100, cellH, drumJob == 'delay').clicked then
            drumJob = 'delay'
        end
        if labelbutton(' wav', buttonX, startY + cellH * 9, 100, cellH, drumJob == 'wav').clicked then
            fileBrowserForSound = { type = 'drum', index = drumIndex }
            browser = fileBrowser("samples", {}, { "wav", "WAV" })
        end
        if drumJob then
            if labelbutton(' reset', buttonX, startY + cellH * 10, 100, cellH).clicked then
                
                for i = 1, #audiohelper.drumgrid[k] do
                    local cell = audiohelper.drumgrid[k][i][drumIndex]
                    if (cell and cell.on) then
                        if drumJob == 'volume' then
                            cell.volume = 1
                        end
                        if drumJob == 'gate' then
                            cell.gate = 1
                        end
                        if drumJob == 'pitch' then
                            cell.semitoneOffset = 0
                        end
                        if drumJob == 'pan' then
                            cell.pan = 0
                        end
                    end
                end
                audiohelper.updateDrumKitData()
            end
        end

        for i = 1, #audiohelper.drumgrid[k] do
            local cell = audiohelper.drumgrid[k][i][drumIndex]
            if (cell and cell.on) then
                if drumJob == 'randP' then
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
                        audiohelper.updateDrumKitData()
                    end

                    local v = v_slider(drumJob .. '1:' .. i, startX + cellW * (i - 1),
                        startY + cellH * 2, 100,
                        cell.rndPOctMin or 0, -2, 0, 'top')
                    if v.value then
                        cell.rndPOctMin = v.value
                        audiohelper.updateDrumKitData()
                    end
                    local v = v_slider(drumJob .. '2:' .. i, startX + cellW * (i - 1),
                        startY + cellH * 2 + 100, 100,
                        cell.rndPOctMax or 0, 0, 2, 'bottom')
                    if v.value then
                        cell.rndPOctMax = v.value
                        audiohelper.updateDrumKitData()
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
                        audiohelper.updateDrumKitData()
                    end
                end
                if drumJob == 'trig' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1), startY + cellH, 200,
                        cell.trig or 1, 0, 1)
                    if v.value then
                        cell.trig = v.value
                        audiohelper.updateDrumKitData()
                    end
                end
                if drumJob == 'gate' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1), startY + cellH, 200,
                        cell.gate or 1, 0, 1)
                    if v.value then
                        cell.gate = v.value
                        audiohelper.updateDrumKitData()
                    end
                end
                if drumJob == 'pan' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        cell.pan or 0, -1, 1)
                    if v.value then
                        cell.pan = v.value
                        audiohelper.updateDrumKitData()
                    end
                end
                if drumJob == 'volume' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        1.0 - (cell.volume or 1), 0, 1)
                    if v.value then
                        cell.volume = 1.0 - v.value
                        audiohelper.updateDrumKitData()
                    end
                end

                if drumJob == 'delay' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        cell.delay or 0, 0, 1.0)
                    if v.value then
                        cell.delay = v.value
                        audiohelper.updateDrumKitData()
                    end
                end

                if drumJob == 'pitch' then
                    local v = v_slider(drumJob .. ':' .. i, startX + cellW * (i - 1),
                        startY + cellH, 200,
                        (cell.semitoneOffset or 0) * -1, -24, 24)
                    if v.value then
                        local v = math.floor(v.value + 0.5) * -1
                        if love.keyboard.isDown('lshift') then
                            v = mapOffsetToNeareastScaleOffset(v, scales['pentatonic_minor'])
                        end
                        cell.semitoneOffset = v
                        audiohelper.updateDrumKitData()
                    end
                end
            end
        end

        if drumJob == 'echo' then
            local xOff = (cellW - smallfont:getWidth('x')) / 2
            drawDrumMachineGrid(startX, startY + cellH, cellW, cellH, #audiohelper.drumgrid[k], 0)
            for i = 1, #audiohelper.drumgrid[k] do
                local cell = audiohelper.drumgrid[k][i][drumIndex]

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
                        audiohelper.updateDrumKitData()
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
        handleDrumPickerWheelMoved(drummPatternPickData, 500, a, b)
    end
    if fileBrowserForSound then
        handleFileBrowserWheelMoved(browser, a, b)
    end
end

function love.mousepressed(x, y, button)
    if fileBrowserForSound then
        local bclicked, path = handleBrowserClick(browser, x, y, smallfont)

        if bclicked then
            mouseState.clickedSomething = true
            browserClicked = true

            if bclicked == 'directory' then
                browser = fileBrowser(browser.root, browser.subdirs,
                    browser.allowedExtensions)
            else
                --print(inspect(browser.subdirs), path)
                local sample = audiohelper.prepareSingleSample(browser.subdirs, path)
                if sample then
                    if fileBrowserForSound.type == 'instrument' then
                        audiohelper.instruments[instrumentIndex].sample = sample
                        audiohelper.sendMessageToAudioThread({ type = "instruments", data = audiohelper.instruments })
                    end
                    if fileBrowserForSound.type == 'drum' then
                        local key = audiohelper.drumkit.order[drumIndex]
                        print(key, sample, drumIndex)
                        audiohelper.drumkit[key] = sample
                        audiohelper.updateDrumKitData()
                    end
                end
            end
        end
    end
    if browserClicked then return end

    if drumIndex <= 0 then
        local cx, cy = getCellUnderPosition(x, y)
        if cx >= 0 and cy >= 0 then
            local k = 1
            audiohelper.drumgrid[k][cx][cy] = { on = not audiohelper.drumgrid[k][cx][cy].on, flam = love.keyboard.isDown('.') }
            audiohelper.updateDrumKitData()
        end
    else
        if drumIndex > 0 then
            local k = 1
            local cx, cy = getCellUnderPosition(x, y)

            if cx >= 0 and cy == 1 then
                audiohelper.drumgrid[k][cx][drumIndex] = {
                    on = not audiohelper.drumgrid[k][cx][drumIndex].on,
                    flam = love.keyboard.isDown('.')
                }
                audiohelper.updateDrumKitData()
            end
        end
    end
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
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.setLineWidth(4)



    for i = 1, 3 do
        local myX = xOff + x + w * (i - 1)
        local myY = y
        if (activeDrumPart == i) then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(col[1], col[2], col[3], .3)
        end
        local r = getUIRect(myX, myY, w, h)
        if r then
            activeDrumPart = i
        end
        love.graphics.print(labels[i], myX, myY)
    end
    for i = 4, 6 do
        local myX = xOff + x + w * (i - 4)
        local myY = y + h
        if (activeDrumPart == i) then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(col[1], col[2], col[3], .3)
        end
        local r = getUIRect(myX, myY, w, h)
        if r then
            activeDrumPart = i
        end
        love.graphics.print(labels[i], myX, myY)
    end
end

function handleDrumPickerWheelMoved(pickData, xOffset, a, b)
    local mx, my = love.mouse:getPosition()
    local columnWidth = 200
    if mx > xOffset + 32 and mx < xOffset + columnWidth + 32 then
        pickData.scrollLeft = pickData.scrollLeft + b
    end
    if mx > xOffset + columnWidth + 32 and mx < xOffset + (columnWidth * 2) + 32 then
        pickData.scrollRight = pickData.scrollRight + b
    end
end

function drawDrumPatternPicker(pickData, xOffset)
    local leftColumn = {}
    local yOffset = 100
    local font = smallfont
    local fontH = font:getHeight()
    local w, h = love.graphics.getDimensions()
    local panelHeight = h - 200
    local columnWidth = 200
    local panelWidth = columnWidth * 2

    love.graphics.setColor(palette.bg0)
    love.graphics.rectangle('fill', xOffset + 32, 100, panelWidth, panelHeight)
    local index = pickData.pickedCategoryIndex --pickedDrumCategory
    local index2 = pickData.pickedItemIndex

    pickData.scrollLeft = math.min(0, pickData.scrollLeft)
    local inList = #drumPatterns
    if panelHeight / fontH < inList then
        if (pickData.scrollLeft - panelHeight / fontH < inList * -1) then
            pickData.scrollLeft = (inList - panelHeight / fontH) * -1
        end
    end

    local inList = #drumPatterns[index].sections
    pickData.scrollRight = math.min(0, pickData.scrollRight)
    if panelHeight / fontH < inList then
        if (pickData.scrollRight - panelHeight / fontH < (#drumPatterns[index].sections) * -1) then
            pickData.scrollRight = (#drumPatterns[index].sections - panelHeight / fontH) * -1
        end
    else
        pickData.scrollRight = 0
    end
    for i = 1, #drumPatterns do
        love.graphics.setColor(palette.fg2)

        local str = drumPatterns[i].name
        local buttonW = columnWidth
        local thisY = (pickData.scrollLeft * fontH) + yOffset + (i - 1) * fontH
        if thisY >= yOffset and thisY < yOffset + panelHeight then
            if i == index then
                love.graphics.setColor(palette.orange)
                love.graphics.rectangle('fill', 32 + xOffset, thisY, buttonW, fontH)
                love.graphics.setColor(1, 1, 1, 1)
            end

            if labelbutton(str, 32 + xOffset, thisY, buttonW, fontH).clicked then
                pickData.pickedCategoryIndex = i
            end
        end
    end

    for i = 1, #drumPatterns[index].sections do
        local it = drumPatterns[index].sections[i]
        love.graphics.setColor(1, 1, 1, 1)

        local str = it.name
        local buttonW = columnWidth
        local thisY = (pickData.scrollRight * fontH) + yOffset + (i - 1) * fontH
        if thisY >= yOffset and thisY < yOffset + panelHeight then
            if i == index2 then
                love.graphics.setColor(palette.orange)
                love.graphics.rectangle('fill', xOffset + 32 + columnWidth, thisY,
                    buttonW,
                    fontH)
                love.graphics.setColor(1, 1, 1, 1)
            end
            if smallfont:getWidth(str) > columnWidth then
                love.graphics.setFont(smallestfont)
            end
            if labelbutton(str, xOffset + 32 + columnWidth, thisY, buttonW, fontH).clicked then
                drumPatternName, gridlength = pickPatternByIndex(index, i)
                pickData.pickedItemIndex = i

                audiohelper.setColumns(gridlength)
                audiohelper.updateDrumKitData()
            end
            if smallfont:getWidth(str) > columnWidth then
                love.graphics.setFont(smallfont)
            end
        end
    end
end

function drawMeasureCounter(x, y)
    if (recording or playing) then
        local font = bigfont
        love.graphics.setFont(font)
        local myBeat = audiohelper.myBeat
        local myBeatInMeasure = audiohelper.myBeatInMeasure

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
    local adsr = audiohelper.instruments[instrumentIndex].adsr

    local bx, by = x, y + 20
    local v = drawLabelledKnob('attack', bx, by, adsr.attack, 0, 1)
    if v.value then
        drawLabel(string.format("%.2f", v.value), bx, by, 1)
        audiohelper.setADSRAtIndex('attack', instrumentIndex, v.value)
    end
    local bx, by = x + 100, y + 20
    local v = drawLabelledKnob('decay', bx, by, adsr.decay, 0, 1)
    if v.value then
        drawLabel(string.format("%.2f", v.value), bx, by, 1)
        audiohelper.setADSRAtIndex('decay', instrumentIndex, v.value)
    end
    local bx, by = x + 200, y + 20
    local v = drawLabelledKnob('sustain', bx, by, adsr.sustain, 0, 1)
    if v.value then
        drawLabel(string.format("%.1f", v.value), bx, by, 1)
        audiohelper.setADSRAtIndex('sustain', instrumentIndex, v.value)
    end

    local bx, by = x + 300, y + 20
    local v = drawLabelledKnob('release', bx, by, adsr.release, 0, 1)

    if v.value then
        drawLabel(string.format("%.1f", v.value), bx, by, 1)
        audiohelper.setADSRAtIndex('release', instrumentIndex, v.value)
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

    for i = 1, #audiohelper.instruments do
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
        local name = audiohelper.instruments[i].sample.name --samples[instruments[i].sampleIndex].name
        love.graphics.print(' ' .. name, x, y + (i - 1) * (rowHeight + margin))
        if (not showDrumPatternPicker) then
            -- if not showDrumPatternPicker then
            if browserClicked == false then
                local r = getUIRect(x, y + (i - 1) * (rowHeight + margin), rowWidth, rowHeight)

                if r then
                    instrumentIndex = i
                    audiohelper.sendMessageToAudioThread({ type = "instrumentIndex", data = instrumentIndex })
                end
            end

            if instrumentIndex == i then
                local buttonw = font:getWidth('wav')
                local buttonh = rowHeight / 2
                local buttony = y + (i - 1) * (rowHeight + margin) + buttonh

                if labelbutton('wav', x + rowWidth - buttonw, buttony - buttonh, buttonw, buttonh, false).clicked == true then
                    local pathParts = audiohelper.instruments[instrumentIndex].sample.pathParts
                    browser = fileBrowser(browser.root, pathParts.pathArray,
                        browser.allowedExtensions)
                    fileBrowserForSound = { type = 'instrument', index = instrumentIndex }
                end
            end

            if false then
                if #audiohelper.recordedClips[i].clips > 0 and instrumentIndex == i then
                    local buttonw = font:getWidth('edit clips')
                    local buttonh = rowHeight / 2
                    local buttony = y + (i - 1) * (rowHeight + margin) + buttonh
                    if labelbutton('edit clips', x + rowWidth - buttonw, buttony, buttonw, buttonh, false).clicked == true then
                        print('gonna do the clip')
                    end
                end
            end
        end

        --- the clips
        local startX = x + rowWidth
        local startY = y + (i - 1) * (rowHeight + margin)
        local clipSize = (rowHeight / 2) - 1
        local maxColumns = 5

        for j = 1, #audiohelper.recordedClips[i].clips do
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

            local r = getUIRect(x, y, clipSize, clipSize)
            if r then
                for k = 1, #audiohelper.recordedClips[i].clips do
                    if (k ~= j) then
                        audiohelper.recordedClips[i].clips[k].meta.isSelected = false
                    else
                        audiohelper.recordedClips[i].clips[k].meta.isSelected = not audiohelper.recordedClips[i].clips
                            [k].meta.isSelected
                    end
                end
                audiohelper.sendMessageToAudioThread({ type = 'stopPlayingSoundsOnIndex', data = i })
                audiohelper.sendMessageToAudioThread({ type = "clips", data = audiohelper.recordedClips })
            end

            if (audiohelper.recordedClips[i].clips[j].meta.isQueued) then
                love.graphics.setColor(.5, 1, 1, 0.8)
                love.graphics.rectangle('line', x, y, clipSize, clipSize)
            end
            if (audiohelper.recordedClips[i].clips[j].meta.isSelected) then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.rectangle('line', x, y, clipSize, clipSize)
            end

            local font = smallestfont
            love.graphics.setFont(smallestfont)
            local loopRounder = (audiohelper.recordedClips[i].clips[j].meta.loopRounder)
            local str = #audiohelper.recordedClips[i].clips[j] .. '\n' .. loopRounder

            local xOff = (clipSize - font:getWidth(str .. '')) / 2
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.print(str .. '', x + xOff, y)

            local clip = audiohelper.recordedClips[i].clips[j]

            if clip.meta.isSelected then
                love.graphics.setColor(1, 1, 1, 0.8)
                local doneCircleRadius = clipSize / 3
                local offset = clipSize / 2
                local value = audiohelper.percentageThingies[i].percentage

                if value then
                    love.graphics.arc('fill', x + offset, y + offset, doneCircleRadius, -math.pi / 2,
                        (value * math.pi * 2) - math.pi / 2)
                end
            end
        end
    end
end

function love.draw()
    love.graphics.clear(0, 0, 0)
    local w, h = love.graphics.getDimensions()
    handleMouseClickStart()

    love.graphics.setColor(1, 1, 1)

    drawDrumParts(100, 0)

    if drumIndex <= 0 then
        drawDrumMachine()
        drawMouseOverGrid()
    end

    if drumIndex > 0 then
        drawMoreInfoForInstrument()
        drawMouseOverMoreInfo()
        if playing then
            drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, audiohelper.columns, 0)
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
            if labelbutton('ok', 64, 90, 100, 30, false).clicked == true then
                fileBrowserForSound = nil
            end

            renderBrowser(browser, 64, 120, (w / 2) - 128, h - 240, smallfont)
        end
    end

    love.graphics.setFont(bigfont)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.print('  ' .. title, 100, 10)

    local font = smallfont
    love.graphics.setFont(font)

    local stats = love.graphics.getStats()
    local memavg = collectgarbage("count") / 1000
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = string.format("%03i", love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    local countNotes = string.format("%02i", audiohelper.myNumPlayingSounds)
    local debugstring = mem ..
        '  ' .. vmem .. '  ' .. draws .. ' ' .. fps .. ' ' .. countNotes .. ' ' .. love.audio.getActiveSourceCount()
    love.graphics.setColor(1, 1, 1, .5)
    love.graphics.print(debugstring, 0, h - font:getHeight())

    if msg then
        love.graphics.setColor(1, 1, 1, messageAlpha)
        love.graphics.print(msg, w - font:getWidth(msg), h - font:getHeight())
    end

    if labelbutton('trigger', 0, 0, font:getWidth('trigger'), font:getHeight(), waitingForTriggerToStartRecording).clicked then
        waitingForTriggerToStartRecording = not waitingForTriggerToStartRecording
    end
    if labelbutton('mixer', 0, font:getHeight(), font:getWidth('trigger'), font:getHeight(), showMixer).clicked then
        showMixer = not showMixer
    end
    if labelbutton(drumPatternName, 0, 32 + font:getHeight(), font:getWidth(drumPatternName),
            font:getHeight()).clicked then
        showDrumPatternPicker = not showDrumPatternPicker
    end
    if (showDrumPatternPicker) then
        drawDrumPatternPicker(drummPatternPickData, w / 2)
    end

    local bx, by = grid.startX + grid.cellW * (audiohelper.columns + 5), grid.startY + grid.cellH * 1
    local v = drawLabelledKnob('bpm', bx, by, uiData.bpm, 10, 200)
    if v.value then
        drawLabel(string.format("%.0i", v.value), bx, by, 1)
        uiData.bpm = v.value
        audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (audiohelper.columns + 5), grid.startY + grid.cellH * 3
    local v = drawLabelledKnob('swing', bx, by, uiData.swing, 50, 80)
    if v.value then
        drawLabel(string.format("%.0i", v.value), bx, by, 1)
        uiData.swing = v.value
        audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (audiohelper.columns + 5), grid.startY + grid.cellH * 5
    local v = drawLabelledKnob('drums', bx, by, uiData.drumVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), bx, by, 1)
        uiData.drumVolume = v.value
        audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (audiohelper.columns + 5), grid.startY + grid.cellH * 7
    local v = drawLabelledKnob('instr', bx, by, uiData.instrumentsVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), bx, by, 1)
        uiData.instrumentsVolume = v.value
        audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local bx, by = grid.startX + grid.cellW * (audiohelper.columns + 5), grid.startY + grid.cellH * 9
    local v = drawLabelledKnob('semi', bx, by, uiData.allDrumSemitoneOffset, -72, 48)
    if v.value then
        drawLabel(string.format("%02.1i", v.value), bx, by, 1)
        uiData.allDrumSemitoneOffset = v.value
        audiohelper.sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
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
