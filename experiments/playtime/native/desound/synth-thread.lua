-- synth-thread.lua (outside src/ so lurker never hot-swaps it into the main thread)
-- Render thread for src/synth.lua: pulls samples from the dreamengine synth into a
-- QueueableSource. This is the engine's single consumer; the main thread is its single producer.

local libPath = ...

require('love.audio')
require('love.sound')
require('love.timer')
local ffi = require('ffi')

ffi.cdef [[ void de_lua_render_s16(int16_t *out, int frames); ]]
local C = ffi.load(libPath)

local RATE, FRAMES, BUFFERS = 44100, 512, 3 -- 3 x 512 frames ~ 35 ms of queued audio
local source = love.audio.newQueueableSource(RATE, 16, 2, BUFFERS)
local quit = love.thread.getChannel('synth-quit')

-- One SoundData per queue slot; LÖVE copies on queue(), so they can be reused right away.
local buffers = {}
for i = 1, BUFFERS do buffers[i] = love.sound.newSoundData(FRAMES, RATE, 16, 2) end
local nextBuffer = 1

-- How it keeps up, on the 'synth-stats' channel about once a second (read it with
-- love.thread.getChannel('synth-stats'):peek()): `empty` = passes that found the queue
-- run dry (a gap: a pop), `restarts` = the source had stopped (a drop), `maxGapMs` =
-- the longest time between two passes of this loop (> ~35 ms runs the queue dry).
-- Each dry pass also goes out on 'synth-dropouts' as it happens ({ at, gapMs, stopped }),
-- for src/synth.lua to log with what the game was doing (synth.audioReport()).
-- A stopped source counts as dry: `empty` used to look at free buffers only and missed
-- most drops (13 empty against 74 restarts, 2026-10-30).
local stats = love.thread.getChannel('synth-stats')
local dropouts = love.thread.getChannel('synth-dropouts')
local window = { empty = 0, restarts = 0, maxGapMs = 0, passes = 0 }
local total = { empty = 0, restarts = 0, passes = 0 }
local lastPass, lastReport = love.timer.getTime(), love.timer.getTime()

while not quit:pop() do
    local now = love.timer.getTime()
    local gapMs = (now - lastPass) * 1000
    lastPass = now
    if gapMs > window.maxGapMs then window.maxGapMs = gapMs end
    window.passes = window.passes + 1
    local stopped = not source:isPlaying()
    if window.passes + total.passes > 1 and (stopped or source:getFreeBufferCount() == BUFFERS) then
        window.empty = window.empty + 1
        if dropouts:getCount() < 100 then dropouts:push({ at = now, gapMs = gapMs, stopped = stopped }) end
    end
    while source:getFreeBufferCount() > 0 do
        local soundData = buffers[nextBuffer]
        nextBuffer = nextBuffer % BUFFERS + 1
        C.de_lua_render_s16(ffi.cast('int16_t *', soundData:getFFIPointer()), FRAMES)
        source:queue(soundData)
    end
    if not source:isPlaying() then
        source:play()
        window.restarts = window.restarts + 1
    end
    if now - lastReport >= 1 then
        total.empty, total.restarts = total.empty + window.empty, total.restarts + window.restarts
        total.passes = total.passes + window.passes
        stats:clear()
        stats:push({ empty = window.empty, restarts = window.restarts, maxGapMs = window.maxGapMs,
            passes = window.passes, totalEmpty = total.empty, totalRestarts = total.restarts,
            queueMs = BUFFERS * FRAMES / RATE * 1000 })
        window.empty, window.restarts, window.maxGapMs, window.passes = 0, 0, 0, 0
        lastReport = now
    end
    love.timer.sleep(0.002)
end
source:stop()
