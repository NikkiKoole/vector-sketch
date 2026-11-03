-- What plays between two seconds of a render: per bar its section and chords, per note the time,
-- part, note and length. For "there's a weird note at 50 s": the same arguments and settings as the
-- render-music.lua run that made the wav (no sound is made here, the music runs on the loop's clock).
-- usage: luajit claudetools/music-when.lua <style> <seed> <from s> <to s>
-- env:   IDEAS=approach:lots,answer:never (as render-music.lua), BAND=on|auto|off (default on),
--        BUSY=<seconds> render-music's busyFrom (the play level bumped there; e.g. 20 as the style
--        report runs), JAM='figure=riff: pocket;walk=1 4 5 1' the drum jam's picks, PARTS=keys,lead,answer,bass (the parts shown; default those and the rest tonal)
package.path = './?.lua;' .. package.path
local style, seed, from, to = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4])
math.randomseed(seed)
love = { math = { random = math.random } } -- luacheck: ignore
local ffi = require 'ffi'
ffi.cdef [[ int de_lua_init(void); void de_lua_render(float *out, int frames); ]]
local C = ffi.load('native/desound/libdesound.dylib')
C.de_lua_init()
package.loaded['src.state'] = { synth = { started = true, C = C } }
local synth = require('src.synth')
local music = require('src.music')
local theory = require('src.music-theory')
music.style, music.rhythmSection = style, os.getenv('BAND') or 'on'
if os.getenv('JAM') then -- the drum jam's picks, as render-music.lua: JAM='figure=riff: pocket;pace=4'
    local jam = {}
    for k, v in os.getenv('JAM'):gmatch('([^=;]+)=([^;]+)') do jam[k] = v end
    package.loaded['src.state'].musicSettings.jam = jam
end
local ideas = {}
for name, mode in (os.getenv('IDEAS') or ''):gmatch('(%w+):(%w+)') do ideas[name] = mode end
music.ideas = ideas
local show
if os.getenv('PARTS') then
    show = {}
    for part in os.getenv('PARTS'):gmatch('[^,]+') do show[part] = true end
end
local M = package.loaded['src.state'].music
local NAMES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
local function nm(m) return NAMES[m % 12 + 1] .. (math.floor(m / 12) - 1) end
local clock = 0
synth.audioTime = function() return clock end
local shown = {}
music.trace = function(part, t, midi, _, durMs)
    if t < from or t > to then return end
    local song = M.song
    local b = song.bar
    if not shown[b] and song.barSection then
        shown[b] = true
        local chords = {}
        local jam = song.jam -- the drum jam has no chords, only a root that walks
        if jam then chords[1] = ('root %s'):format(NAMES[(song.key + jam.root) % 12 + 1]) end
        for _, c in ipairs(jam and {} or theory.barChords(song, b)) do
            chords[#chords + 1] = ('%s%s@%d'):format(NAMES[(song.key + c.degree) % 12 + 1], c.quality, c.s)
        end
        print(('-- bar %d (%s %d) at %.2fs: %s'):format(b, song.barSection[b].kind, song.barIndex[b], M.barAt or 0,
            table.concat(chords, ' ')))
    end
    if show and not show[part] or not show and not require('src.music-parts').TONAL[part] then return end
    print(('   %.2f %-7s %-4s %dms'):format(t, part, nm(midi), math.floor(durMs)))
end
local busyFrom = tonumber(os.getenv('BUSY') or '')
local RATE, N = 44100, 512
for block = 1, math.floor((to + 4) * RATE / N) do
    clock = block * N / RATE
    if busyFrom and clock > busyFrom and clock < busyFrom + 6 and block % 20 == 0 then music.bump(1) end
    music.update(synth, clock)
end
