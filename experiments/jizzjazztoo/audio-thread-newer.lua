require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')

local min, max     = ...
local paused       = false
local now          = love.timer.getTime()
local time         = 0
local lastTick     = 0
local lastBeat     = -1
local beat         = 0
local bpm          = 100
local channel      = {};
channel.audio2main = love.thread.getChannel("audio2main"); -- from thread
channel.main2audio = love.thread.getChannel("main2audio"); --from main

while (true) do
    if not paused then
        local n = love.timer.getTime()
        local delta = n - now
        now = n
        beat = beat + (delta * (bpm / 60))
        local tick = ((beat % 1) * (96))

        if math.floor(tick) - math.floor(lastTick) > 1 then
            for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
                print('missed tick', i)
                --table.insert(missedTicks, i)
            end
        end

        lastBeat = beat
        lastTick = tick
    end

    -- using this i can sleep for a good amount (no missed ticks)
    -- but also will sleep less if the bpm goes up,
    -- testing it i see missed ticks only >400 bpm.  RAVE ON!!
    local sleepForMultiplier = math.ceil(bpm / 50)
    local sleepFor = 1.0 / (96 * sleepForMultiplier)
    love.timer.sleep(sleepFor)

    local v = channel.main2audio:pop();
    if v then

    end
end
