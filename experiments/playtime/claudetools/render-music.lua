-- Renders the real src/music.lua + src/synth.lua offline to a WAV.
-- usage: luajit render.lua <out.wav> <seconds> <style> <rhythm: auto|on|off> [busyFrom seconds] [seed]
local P = '/Users/nikkikoole/Projects/love/vector-sketch/experiments/playtime/'
package.path = P .. '?.lua;' .. package.path
local out, seconds, style, rhythm = arg[1], tonumber(arg[2]) or 30, arg[3] or 'bossa', arg[4] or 'auto'
local busyFrom, seed = tonumber(arg[5]), tonumber(arg[6]) or 3
math.randomseed(seed)
love = { math = { random = math.random } } -- luacheck: ignore

local ffi = require 'ffi'
ffi.cdef [[ int de_lua_init(void); void de_lua_render(float *out, int frames); ]]
local C = ffi.load(P .. 'native/desound/libdesound.dylib')
C.de_lua_init()
-- stand-in for src/state with the synth already "started", so synth.lua defines its patches on load
package.loaded['src.state'] = { synth = { started = true, C = C } }
local synth = require('src.synth')
local music = require('src.music')
music.style, music.rhythmSection = style, rhythm
if os.getenv('MELODY') then music.melody, music.melodyPatch = true, os.getenv('MELODY') end

local RATE, N = 44100, 512
local buf = ffi.new('float[?]', N * 2)
local samples = {}
local blocks = math.floor(seconds * RATE / N)
for b = 1, blocks do
    local now = b * N / RATE
    if busyFrom and now > busyFrom and now < busyFrom + 6 and b % 20 == 0 then music.bump(1) end
    music.update(synth, now)
    C.de_lua_render(buf, N)
    for i = 0, N * 2 - 1 do samples[#samples + 1] = buf[i] end
end

local peak = 0
for _, x in ipairs(samples) do if math.abs(x) > peak then peak = math.abs(x) end end
local gain = 0.8 / math.max(peak, 1e-6)
local function u32(n) return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256) end
local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local data = {}
for i, x in ipairs(samples) do
    local s = math.floor(math.max(-1, math.min(1, x * gain)) * 32767)
    if s < 0 then s = s + 65536 end
    data[i] = u16(s)
end
local d = table.concat(data)
local f = io.open(out, 'wb')
f:write('RIFF' .. u32(36 + #d) .. 'WAVEfmt ' .. u32(16) .. u16(1) .. u16(2) .. u32(RATE) .. u32(RATE * 4) .. u16(4) .. u16(16) .. 'data' .. u32(#d) .. d)
f:close()
local M = package.loaded['src.state'].music
print(('%s  peak %.3f  key %s  lydian %s  band at end: %s'):format(out, peak, tostring(M.key), tostring(M.lydian), tostring(M.withBand)))
