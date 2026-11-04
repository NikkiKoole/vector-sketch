-- drum-audition: the drum jam's "best of" kit audition (docs/DRUM-JAM.md J4): one WAV per drum role, the
-- same short pattern on A = the jam's old voice, B = the 808, C = the 909 (those that have the role).
-- usage, from the playtime folder: mkdir -p /tmp/aud && luajit claudetools/drum-audition.lua /tmp/aud
package.path = './?.lua;' .. package.path
love = { math = { random = math.random } } -- luacheck: ignore
local ffi = require 'ffi'
ffi.cdef [[ int de_lua_init(void); void de_lua_render(float *out, int frames); ]]
local C = ffi.load('native/desound/libdesound.dylib')
C.de_lua_init()
package.loaded['src.state'] = { synth = { started = true, C = C }, music = {}, musicSettings = {} }
local synth = require('src.synth')
local machines = require('src.drum-machines')
local VOICES = { -- music-jam's lib.VOICES (not required: it pulls in the whole music stack)
    BD = { 'bapKick', 36, 5, 160 }, SD = { 'snare', 60, 4, 120 }, CPS = { 'clap', 60, 4, 100 },
    CH = { 'hat', 60, 3, 28 }, OH = { 'hat', 60, 3, 140 }, CY = { 'ride', 81, 4, 600 },
    RS = { 'rim', 79, 4, 40 }, CB = { 'wood', 76, 3, 120 }, TB = { 'tamb', 84, 2, 60 },
    LT = { 'tom', 45, 4, 220 }, MT = { 'tom', 50, 4, 200 }, HT = { 'tom', 55, 4, 180 },
}
local out = arg[1]
local BEAT = 60 / 110
local S16 = BEAT / 4
-- role -> its pattern: { step (16ths), accent } over 2 bars
local function steps(list) local p = {} for _, s in ipairs(list) do p[#p + 1] = { s, 0 } end return p end
local PATTERNS = {
    BD = steps({ 0, 8, 16, 22, 24 }), SD = steps({ 4, 12, 20, 28, 30 }), CPS = steps({ 4, 12, 20, 28 }),
    CH = steps({ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30 }), OH = steps({ 2, 6, 10, 14, 18, 22 }),
    CY = steps({ 0, 16 }), RS = steps({ 3, 6, 10, 14, 19, 22, 26 }), CB = steps({ 0, 3, 6, 8, 11, 14, 16, 19, 22, 24 }),
    TB = steps({ 2, 6, 10, 14, 18, 22, 26, 30 }), TOMS = { { 24, 'HT' }, { 26, 'HT' }, { 27, 'MT' }, { 28, 'MT' }, { 30, 'LT' }, { 31, 'LT' } },
}
local NAMES = { BD = 'kick', SD = 'snare', CPS = 'clap', CH = 'closed-hat', OH = 'open-hat', CY = 'crash',
                RS = 'rim', CB = 'cowbell', TB = 'tambourine', TOMS = 'toms' }
local function notesFor(source, role)
    if source == 'old' then local v = VOICES[role] return v and { { v[1], v[2], v[3], v[4], 0 } } end
    return machines.notes(source, role, 0, 0)
end
local RATE, N = 44100, 512
local buf = ffi.new('float[?]', N * 2)
local clock = 0
local function render(seconds, into)
    for _ = 1, math.floor(seconds * RATE / N) do
        C.de_lua_render(buf, N)
        for i = 0, N * 2 - 1 do into[#into + 1] = buf[i] end
        clock = clock + N / RATE
    end
end
local function wav(path, samples)
    local peak = 1e-6
    for _, x in ipairs(samples) do peak = math.max(peak, math.abs(x)) end
    local gain = 0.8 / peak
    local function u32(n) return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256) end
    local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
    local data = {}
    for i, x in ipairs(samples) do
        local s = math.floor(math.max(-1, math.min(1, x * gain)) * 32767)
        if s < 0 then s = s + 65536 end
        data[i] = u16(s)
    end
    local d = table.concat(data)
    local f = io.open(path, 'wb')
    f:write('RIFF' .. u32(36 + #d) .. 'WAVEfmt ' .. u32(16) .. u16(1) .. u16(2) .. u32(RATE) .. u32(RATE * 4) .. u16(4) .. u16(16) .. 'data' .. u32(#d) .. d)
    f:close()
end
local junk = {}
render(0.3, junk)
local order = { 'BD', 'SD', 'CPS', 'CH', 'OH', 'CY', 'RS', 'TOMS', 'CB', 'TB' }
for _, role in ipairs(order) do
    local samples, heard = {}, {}
    for _, source in ipairs({ 'old', 'tr808', 'tr909' }) do
        local t0, any = clock + 0.1, false
        for _, st in ipairs(PATTERNS[role]) do
            local r = role == 'TOMS' and st[2] or role
            for _, n in ipairs(notesFor(source, r) or {}) do
                synth.scheduleAt(n[1], t0 + st[1] * S16 + n[5] / 1000, n[2], n[3], n[4])
                any = true
            end
        end
        if any then heard[#heard + 1] = source end
        render(32 * S16 + 1.2, samples)
    end
    wav(out .. '/' .. NAMES[role] .. '.wav', samples)
    print(NAMES[role] .. ': ' .. table.concat(heard, ', '))
end
