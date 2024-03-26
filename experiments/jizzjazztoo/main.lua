package.path       = package.path .. ";../../?.lua"
local inspect      = require 'vendor.inspect'
local drumPatterns = require 'drum-patterns'
require 'ui'

local _thread
local channel      = {};
channel.audio2main = love.thread.getChannel("audio2main")
channel.main2audio = love.thread.getChannel("main2audio")


getMessageFromAudioThread = function()
    local v = channel.audio2main:pop();
    local error = _thread:getError()
    assert(not error, error)
    return v
end

sendMessageToAudioThread  = function(msg)
    channel.main2audio:push(msg)
end

local os                  = love.system.getOS()
if os == 'iOS' or os == 'Android' then
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
else
    _thread = love.thread.newThread('audio-thread-newer.lua')
    _thread:start()
end

local function prepareSamples(names)
    local result = {}
    for i = 1, #names do
        local name = names[i]
        local path = 'samples/' .. name .. ".wav"
        local info = love.filesystem.getInfo(path)
        if info then
            result[i] = { name = name, source = love.audio.newSource(path, 'static') }
        else
            print('file not found!', path)
        end
    end
    return result
end

local function prepareDrumkit(drumkitFiles)
    local result = {}
    for k, v in pairs(drumkitFiles) do
        if k ~= 'order' then
            local path = 'samples/' .. v .. ".wav"
            local info = love.filesystem.getInfo(path)
            if info then
                result[k] = { type = k, name = v, source = love.audio.newSource(path, 'static') }
            else
                print('drumkit fail: ', k, v)
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

function love.load()
    uiData = {
        bpm = 90,
        swing = 50,
        instrumentsVolume = 1,
        drumVolume = 1,
    }
    lookinIntoIntrumentAtIndex = 0
    singleInstrumentJob = nil

    sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    myTick = 0
    myBeat = 0
    myBeatInMeasure = 4
    myNumPlayingSounds = 0

    bigfont = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    smallfont = love.graphics.newFont('WindsorBT-Roman.otf', 24)
    musicfont = love.graphics.newFont('NotoMusic-Regular.ttf', 48)

    missedTicks = {}
    playingSounds = {}

    -- livelooping
    recording = false
    playing = false

    -- ok the data structure for recording things:
    -- we have a limited amount of channels in a song (say 1-9)
    -- you can view a channel as an instrument: an instrument is a sample + adsr envelope

    -- when we are recording we are doing that for 1 channel.
    -- also recoring a loop means we can maybe record multiple takes.
    -- yeah a take should be a thing
    -- that implies you want to either start with  nothing and play as long as you want
    -- OR do a predefined set of measures a couple of times/takes until its good enough
    -- OR you could also do a predefined set of measures and when you are done you layer on top.

    channelIndex = 1
    recordedData = {}


    -- measure/beat

    sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
    --resetBeatsAndTicks()

    -- metronome sounds


    -- octave stuff
    max_octave = 8
    octave = 4

    -- sample stuff
    local sampleFiles = {
        'lulla/tubo', 'lulla/kiksynth', 'lulla/milkjar', 'lulla/pizzi', 'lulla/C4-pitchpedal',
        'lulla/soft sk', 'lulla/rainbows', 'lulla/receiver', 'lulla/C3', 'lulla/lobassy',
        "ac/0x722380", "ac/0x14146A0", "ac/0xC3B760",
        "ANCR I Mallet 7", "legow/SYNTH-CleanHigh", "legow/Synth-PinkyFlute kopie",
        "legow/Synth-Bellancholia",
        "legow/VibraphoneMid-MT70",
        "legow/Synth SineFiltered1", "legow/Bass BoringSimple",
        "legow/Synth SoftTooter", "junopiano",
        "synth03", "4", "decent/chord-organ-decentc2",
        "rhodes", "sf1-015", 'wavparty/melodic-tunedC06',
        'wavparty/bass-tunedC05', 'wavparty/bass-tunedC06', 'wavparty/synth22', 'wavparty/synth36', 'mello/C3-3',
        'ratchet/downstroke (10)', 'ratchet/downstroke (11)', 'ratchet/downstroke (12)',
        'mt70/top1', 'mt70/top2', 'mt70/top3', 'mt70/Bdrum1'
    }
    samples = prepareSamples(sampleFiles)

    sampleIndex = 1
    sample = samples[sampleIndex]

    -- tuning
    sampleTuning = {}
    for i = 1, #samples do
        sampleTuning[i] = 0
    end
    sendMessageToAudioThread({ type = "tuningUpdated", data = sampleTuning })
    sendMessageToAudioThread({ type = 'samples', data = samples })
    sendMessageToAudioThread({ type = 'sampleIndex', data = sampleIndex })

    local drumkitCR78 = {
        order = { 'AC', 'BD', 'SD', 'LT', 'MT', 'HT', 'CH', 'OH', 'CY', 'RS', 'CPS', 'TB', 'CB' },
        AC = 'cr78/Kick Accent',
        BD = 'cr78/Kick',
        SD = 'cr78/Snare',
        LT = 'cr78/Conga Low',
        MT = 'cr78/Bongo Low',
        HT = 'cr78/Bongo High',
        CH = 'cr78/HiHat',
        OH = 'cr78/Tamb 2',
        CY = 'cr78/Cymbal',
        RS = 'cr78/Rim Shot',
        TB = 'cr78/Guiro 1',
        CPS = 'cr78/Guiro 1',
        CB = 'cr78/Cowbell'
    }

    local drumkitJazzkit = {
        order = { 'AC', 'BD', 'SD', 'LT', 'MT', 'HT', 'CH', 'OH', 'CY', 'RS', 'CPS', 'TB', 'CB' },
        AC = 'Minipops/bd2',
        BD = 'Minipops/bd1',
        SD = 'Minipops/sd1',
        LT = 'cr78/Conga Low',
        MT = 'Minipops/bd3',
        HT = 'cr78/Bongo High',
        CH = 'jazzkit/JK_HH_01',
        OH = 'Minipops/hihat2',
        CY = 'cr78/Cymbal',
        RS = 'cr78/Rim Shot',
        CPS = 'cr78/Guiro 1',
        TB = 'jazzkit/JK_BRSH_01',
        CB = 'Minipops/wood1',
    }
    local drumkitMinipop = {
        order = { 'AC', 'BD', 'SD', 'LT', 'MT', 'HT', 'CH', 'OH', 'CY', 'RS', 'CPS', 'TB', 'CB' },
        AC = 'Minipops/bd2',
        BD = 'Minipops/bd1',
        SD = 'Minipops/sd1',
        LT = 'cr78/Conga Low',
        MT = 'Minipops/bd3',
        HT = 'cr78/Bongo High',
        CH = 'Minipops/hihat1',
        OH = 'Minipops/hihat2',
        CY = 'cr78/Cymbal',
        RS = 'cr78/Rim Shot',
        CPS = 'cr78/Guiro 1',
        TB = 'Minipops/Tambourine',
        CB = 'Minipops/wood1',
    }

    drumkitFiles = drumkitJazzkit
    drumkit = prepareDrumkit(drumkitFiles)

    grid = {
        startX = 120, -- smallfont:getWidth('WWWW')
        startY = 100,
        cellW = 20,   --smallfont:getWidth('X')
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

local function getSemitone(offset)
    return (octave * 12) + offset
end
function love.keyreleased(k)
    if (usingMap[k] ~= nil) then
        sendMessageToAudioThread({
            type = "semitoneReleased",
            data = {
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], scale)),
                takeIndex = 0,
                channelIndex = 1,
                sampleIndex = sampleIndex
            }
        });
    end
end

function love.keypressed(k)
    if k == '-' then
        drumPatternName, gl = drumPatterns.pickExistingPattern(drumgrid, drumkit)
        grid.columns = gl
        updateDrumKitData()
    end
    if (usingMap[k] ~= nil) then
        sendMessageToAudioThread({
            type = "semitonePressed",
            data = {
                sample = sample,
                semitone = getSemitone(fitKeyOffsetInScale(usingMap[k], scale)),
                takeIndex = 0,
                channelIndex = 1,
                sampleIndex = sampleIndex
            }
        });
    end

    if k == 'z' then
        octave = math.max(octave - 1, 0)
        print("Octave:", octave)
    elseif k == 'x' then
        octave = math.min(octave + 1, max_octave)
        print("Octave:", octave)
    end
    if k == 'tab' then
        sampleIndex = (sampleIndex % #samples) + 1
        sample = samples[sampleIndex]
        print('Sample:', sampleIndex, sample.name)
        sendMessageToAudioThread({ type = 'sampleIndex', data = sampleIndex })
    end

    if k == 'c' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] + 1
        sendMessageToAudioThread({
            type = "tuningUpdated", data = sampleTuning })
        print('Tuning:', sample.name, sampleTuning[sampleIndex])
    end
    if k == 'v' then
        sampleTuning[sampleIndex] = sampleTuning[sampleIndex] - 1
        sendMessageToAudioThread({
            type = "tuningUpdated", data = sampleTuning })
        print('Tuning:', sample.name, sampleTuning[sampleIndex])
    end
    if k == 'b' then
        toggleScale()
    end

    --  sendMessageToAudioThread({ type = "key", data = k });

    if k == 'escape' then
        sendMessageToAudioThread({ type = "paused", data = true });
        love.event.quit()
    end

    if k == 'space' then
        playing = not playing

        if not playing then
            sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
            sendMessageToAudioThread({ type = "paused", data = true });
            --resetBeatsAndTicks()
        end
        if playing then
            sendMessageToAudioThread({ type = "mode", data = 'play' });
            sendMessageToAudioThread({ type = "paused", data = false });
            recording = false
        end
    end

    if k == 'return' then
        sendMessageToAudioThread({ type = "resetBeatsAndTicks" });
        --resetBeatsAndTicks()
        recording = not recording
        if not recording then
            sendMessageToAudioThread({ type = "paused", data = true });
        end
        if recording then
            sendMessageToAudioThread({ type = "mode", data = 'record' });
            sendMessageToAudioThread({ type = "paused", data = false });
            recordedData = {}
            playing = false
        end
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
        end
    until not msg

    if playing then
        --   handlePlayingRecordedData()
    end
    --cleanPlayingSounds()
end

function drawDrumMachineGrid(startX, startY, cellW, cellH, columns, rows)
    love.graphics.setLineWidth(4)
    for y = 0, rows do
        love.graphics.setColor(1, 1, 1, .1)
        for i = 0, columns - 1 do
            love.graphics.rectangle('line', startX + i * cellW, startY + y * cellH, cellW, cellH)
        end
    end
    love.graphics.setColor(1, 1, 1, .3)
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
    love.graphics.setColor(1, 1, 1, 0.8)
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

    if playing then
        drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, #grid.labels - 1)
    end
end

function drawMoreInfoForInstrument()
    if lookinIntoIntrumentAtIndex > 0 then
        drawDrumMachineGrid(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, 0)
        drawDrumOnNotesSingleRow(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns,
            lookinIntoIntrumentAtIndex - 1)

        if labelbutton(' ' .. grid.labels[lookinIntoIntrumentAtIndex], 0, grid.startY, 100, grid.cellH).clicked then
            lookinIntoIntrumentAtIndex = 0
            --singleInstrumentJob = nil
        end

        if labelbutton(' volume', 0, grid.startY + grid.cellH * 1, 100, grid.cellH, singleInstrumentJob == 'volume').clicked then
            singleInstrumentJob = 'volume'
        end

        if labelbutton(' pitch', 0, grid.startY + grid.cellH * 2, 100, grid.cellH, singleInstrumentJob == 'pitch').clicked then
            singleInstrumentJob = 'pitch'
        end

        if labelbutton(' pan', 0, grid.startY + grid.cellH * 3, 100, grid.cellH, singleInstrumentJob == 'pan').clicked then
            singleInstrumentJob = 'pan'
        end
        if labelbutton(' echo', 0, grid.startY + grid.cellH * 4, 100, grid.cellH, singleInstrumentJob == 'echo').clicked then
            singleInstrumentJob = 'echo'
        end

        if labelbutton(' gate', 0, grid.startY + grid.cellH * 5, 100, grid.cellH, singleInstrumentJob == 'gate').clicked then
            singleInstrumentJob = 'gate'
        end
        if singleInstrumentJob then
            if labelbutton(' reset', 0, grid.startY + grid.cellH * 6, 100, grid.cellH).clicked then
                for i = 1, #drumgrid do
                    local cell = drumgrid[i][lookinIntoIntrumentAtIndex]
                    if (cell and cell.on) then
                        if singleInstrumentJob == 'volume' then
                            cell.volume = 1
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

        --  if labelbutton(' micro', 0, grid.startY + grid.cellH * 4, 100, grid.cellH, singleInstrumentJob == 'micro').clicked then
        --      singleInstrumentJob = 'micro'
        --  end


        --    drumgrid[cx][cy]

        for i = 1, #drumgrid do
            local cell = drumgrid[i][lookinIntoIntrumentAtIndex]
            if (cell and cell.on) then
                if singleInstrumentJob == 'gate' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, grid.startX + grid.cellW * (i - 1),
                        grid.startY + grid.cellH, 200,
                        cell.gate or 1, 0, 1)
                    if v.value then
                        cell.gate = v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'pan' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, grid.startX + grid.cellW * (i - 1),
                        grid.startY + grid.cellH, 200,
                        cell.pan or 0, -1, 1)
                    if v.value then
                        cell.pan = v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'volume' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, grid.startX + grid.cellW * (i - 1),
                        grid.startY + grid.cellH, 200,
                        1.0 - (cell.volume or 1), 0, 1)
                    if v.value then
                        cell.volume = 1.0 - v.value
                        updateDrumKitData()
                    end
                end
                if singleInstrumentJob == 'pitch' then
                    local v = v_slider(singleInstrumentJob .. ':' .. i, grid.startX + grid.cellW * (i - 1),
                        grid.startY + grid.cellH, 200,
                        (cell.semitoneOffset or 0) * -1, -24, 24)
                    if v.value then
                        cell.semitoneOffset = math.floor(v.value + 0.5) * -1
                        updateDrumKitData()
                    end
                end
            end
        end
        if singleInstrumentJob == 'echo' then
            local xOff = (grid.cellW - smallfont:getWidth('x')) / 2
            drawDrumMachineGrid(grid.startX, grid.startY + grid.cellH, grid.cellW, grid.cellH, #drumgrid, 0)
            for i = 1, #drumgrid do
                local cell = drumgrid[i][lookinIntoIntrumentAtIndex]

                if (cell and cell.on) then
                    if cell.echo then
                        love.graphics.print(cell.echo .. "", xOff + grid.startX + (i - 1) * grid.cellW,
                            grid.startY + grid.cellH)
                    end
                    local r = getUIRect(grid.startX + (i - 1) * grid.cellW, grid.startY + grid.cellH,
                        grid.cellW,
                        grid.cellH)
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

function love.mousepressed(x, y, button)
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
                -- print(cx, cy)
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

function love.draw()
    handleMouseClickStart()
    love.graphics.setColor(1, 1, 1)

    if lookinIntoIntrumentAtIndex <= 0 then
        drawDrumMachine()
        drawMouseOverGrid()
    end

    if lookinIntoIntrumentAtIndex > 0 then
        drawMoreInfoForInstrument()
        drawMouseOverMoreInfo()
        if playing then
            drawDrumMachinePlayHead(grid.startX, grid.startY, grid.cellW, grid.cellH, grid.columns, 0)
        end
    end

    love.graphics.setColor(1, 1, 1)
    if (recording or playing) then
        local font = bigfont
        love.graphics.setFont(font)

        local str = string.format("%02d", math.floor(myBeat / myBeatInMeasure)) ..
            '|' .. string.format("%01d", math.floor(myBeat % myBeatInMeasure))

        love.graphics.print(str, font:getHeight(), 0)
        if (math.floor(myBeat / myBeatInMeasure) < 0) then
            love.graphics.setColor(1, 1, 0)
        else
            if recording then
                love.graphics.setColor(1, 0, 0)
            else
                love.graphics.setColor(0, 1, 0)
            end
        end
        love.graphics.circle('fill', font:getHeight() / 2, font:getHeight() / 2, font:getHeight() / 3)
    end


    local font = smallfont
    love.graphics.setFont(font)

    local instrument = samples[sampleIndex].name .. ' ' .. octave
    local w, h = love.graphics:getDimensions()
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print(instrument, w - font:getWidth(instrument), 0)

    local stats = love.graphics.getStats()
    local memavg = collectgarbage("count") / 1000
    local mem = string.format("%02.1f", memavg) .. 'Mb(mem)'
    local vmem = string.format("%.0f", (stats.texturememory / 1000000)) .. 'Mb(video)'
    local fps = string.format("%03i", love.timer.getFPS()) .. 'fps'
    local draws = stats.drawcalls .. 'draws'
    local countNotes = string.format("%02i", myNumPlayingSounds)
    local debugstring = mem ..
        '  ' .. vmem .. '  ' .. draws .. ' ' .. fps .. ' ' .. countNotes .. ' ' .. love.audio.getActiveSourceCount()
    love.graphics.print(debugstring, 0, h - font:getHeight())
    love.graphics.print(drumPatternName, w - font:getWidth(drumPatternName), font:getHeight())





    local v = drawLabelledKnob('bpm', 200, 50, uiData.bpm, 10, 200)
    if v.value then
        drawLabel(string.format("%.0i", v.value), 200, 50, 1)
        uiData.bpm = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local v = drawLabelledKnob('swing', 300, 50, uiData.swing, 50, 75)
    if v.value then
        drawLabel(string.format("%.0i", v.value), 300, 50, 1)
        uiData.swing = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local v = drawLabelledKnob('VD.', 400, 50, uiData.drumVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), 400, 50, 1)
        uiData.drumVolume = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end

    local v = drawLabelledKnob('VI.', 600, 50, uiData.instrumentsVolume, 0.01, 1)
    if v.value then
        drawLabel(string.format("%02.1f", v.value), 600, 50, 1)
        uiData.instrumentsVolume = v.value
        sendMessageToAudioThread({ type = "updateKnobs", data = uiData });
    end
    -- love.graphics.print('𝄞𝄵𝆑𝄆 𝄞𝄰 𝅗𝅥𝅘𝅥𝅮𝅘𝅥𝅮𝅘𝅥 𝄇𝄞𝅘𝅥𝅯 𝄃 𝄞♯ 𝅘𝅥𝄾 𝄀 ♭𝅗𝅥♫ 𝆑𝆏 𝄂')
end

function drawLabelledKnob(label, x, y, value, min, max)
    drawLabel(label, x, y + 32)
    local v = draw_knob(label, x, y, value, min, max)
    return v
end

function drawLabel(str, x, y, alpha)
    love.graphics.setColor(1, 1, 1, alpha or .2)
    local font = smallfont
    love.graphics.setFont(font)
    local strW = font:getWidth(str)
    local strH = font:getHeight()
    love.graphics.print(str, x - strW / 2, y - strH / 2)
end

--
