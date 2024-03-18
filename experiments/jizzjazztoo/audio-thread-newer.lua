require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')

local min, max        = ...
local paused          = true
local now             = love.timer.getTime()
local time            = 0
local lastTick        = 0
local lastBeat        = -1
local beat            = 0
local tick            = 0
local beatInMeasure   = 4
local countInMeasures = 0
local bpm             = 90

local metronome_click = love.audio.newSource("samples/cr78/Clave.wav", "static")

local channel         = {};
channel.audio2main    = love.thread.getChannel("audio2main"); -- from thread
channel.main2audio    = love.thread.getChannel("main2audio"); --from main



local function resetBeatsAndTicks()
    lastTick = 0
    lastBeat = beatInMeasure * -1 * countInMeasures
    beat = beatInMeasure * -1 * countInMeasures
    tick = 0
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

local missedTicks = {}

while (true) do
    if not paused then
        local n = love.timer.getTime()
        local delta = n - now
        now = n
        beat = beat + (delta * (bpm / 60))
        tick = ((beat % 1) * (96))

        if math.floor(tick) - math.floor(lastTick) > 1 then
            for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
                print('missed tick', i)
                table.insert(missedTicks, i)
            end
        end

        if (math.floor(beat) ~= math.floor(lastBeat)) then
            playMetronomeSound()
            -- print(math.floor(beat), beatInMeasure)
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end

        lastBeat = beat
        lastTick = tick
    end

    local sleepForMultiplier = math.ceil(bpm / 50) + 1
    local sleepFor = 1.0 / (96 * sleepForMultiplier)
    love.timer.sleep(sleepFor)
    -- using this i can sleep for a good amount (no missed ticks)
    -- but also will sleep less if the bpm goes up,
    -- testing it i see missed ticks only >400 bpm.  RAVE ON!!


    local v = channel.main2audio:pop();
    if v then
        if v.type == 'resetBeatsAndTicks' then
            resetBeatsAndTicks()
            channel.audio2main:push({ type = 'beatUpdate', data = { beat = math.floor(beat), beatInMeasure = beatInMeasure } })
        end
        if v.type == 'paused' then
            paused = v.data
        end
        --if v.type == 'key' then
        --print(v.data)
        --end
    end
end
