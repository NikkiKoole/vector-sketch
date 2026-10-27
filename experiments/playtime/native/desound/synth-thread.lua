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

while not quit:pop() do
    while source:getFreeBufferCount() > 0 do
        local soundData = buffers[nextBuffer]
        nextBuffer = nextBuffer % BUFFERS + 1
        C.de_lua_render_s16(ffi.cast('int16_t *', soundData:getFFIPointer()), FRAMES)
        source:queue(soundData)
    end
    if not source:isPlaying() then source:play() end
    love.timer.sleep(0.002)
end
source:stop()
