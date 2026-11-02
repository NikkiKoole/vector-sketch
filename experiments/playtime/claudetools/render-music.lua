-- Renders the real src/music.lua + src/synth.lua offline to a WAV.
-- usage: luajit render.lua <out.wav> <seconds> <style: set|bossa|guaraldi|ballad> <rhythm: auto|on|off>
--        [busyFrom seconds] [seed]
-- env: MELODY=<patch> swaps the tune's voice, VOICES=bass:tb303,lead:flute any part's, SOLO=<patch,patch> a stem,
--      TUNE=classic builds the tune the old way (the default is guide, src/music-guide.lua),
--      CUES=20:citypop,45:satie:bar,70:keep:cellar cues a style (or only layers, with 'keep') at a second,
--      EFFECTS=0..2 the effects slider (every pedal's amount; 1 = as designed),
--      SPICE=0..2 the style's ideas (walks, answers; 0 plain, 1 as designed), IDEAS=walks:never,answer:always
local P = arg[0]:match('^(.*)claudetools/') or './' -- the project folder, from where this script is
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
if os.getenv('TUNE') then music.tune = os.getenv('TUNE') end
if os.getenv('MELODY') then music.melody, music.melodyPatch = true, os.getenv('MELODY') end
-- VOICES=bass:tb303,lead:flute plays parts on other instruments, as the panel's part rows do
if os.getenv('VOICES') then
    local voices = {}
    for part, patch in os.getenv('VOICES'):gmatch('(%w+):(%w+)') do voices[part] = patch end
    music.voices = voices
end
-- SOLO=piano,ride renders only those patches (a stem); the rms printed is over the windows where it sounds
if os.getenv('SOLO') then
    local keep, scheduleAt = {}, synth.scheduleAt
    for name in os.getenv('SOLO'):gmatch('[^,]+') do keep[name] = true end
    synth.scheduleAt = function(patch, ...) if keep[patch] then return scheduleAt(patch, ...) end end
end

if os.getenv('EFFECTS') then synth.setEffectAmount(tonumber(os.getenv('EFFECTS'))) end -- the effects slider
if os.getenv('SPICE') then music.spice = tonumber(os.getenv('SPICE')) end -- the ideas, src/music.lua
if os.getenv('IDEAS') then
    local ideas = {}
    for name, mode in os.getenv('IDEAS'):gmatch('(%w+):(%w+)') do ideas[name] = mode end
    music.ideas = ideas
end

-- NOTES=<file.lua> writes the first song's notes as a score (src/music-scores/'s format), for
-- claudetools/score-analysis.py: every tonal part, each note on its bar's 16th (swing undone);
-- lead = l, keys = k, bass = b, the others (chord, guitar, horns, strings, riff) by name
-- NOTES_ONLY=1: only the notes, no sound (fast; the wav is left out)
local notesOut, recorded = os.getenv('NOTES'), { bars = {} }
local notesOnly = notesOut and os.getenv('NOTES_ONLY')
local clock = 0
if notesOnly then synth.audioTime = function() return clock end end -- no audio: the music runs on the loop's time
if notesOut then
    local M = package.loaded['src.state'].music
    local CODE = { lead = 'l', keys = 'k', bass = 'b' }
    music.trace = function(part, t, midi, vol, durMs)
        local song = M.song
        if not song or not require('src.music-parts').TONAL[part] then return end
        recorded.song = recorded.song or song
        if song ~= recorded.song or not M.barAt then return end -- the first song only
        local sixteenth = song.beat / 4
        local step = math.floor((t - M.barAt) / sixteenth + 0.5)
        local notes = recorded.bars[song.bar] or {}
        recorded.bars[song.bar] = notes
        notes[#notes + 1] = { step, midi, math.max(1, math.floor(durMs / 1000 / sixteenth + 0.5)), CODE[part] or part,
                              vol * 16 }
    end
end

local cues = {}
for at, name, opt in (os.getenv('CUES') or ''):gmatch('(%d+):([%w]+):?([%w]*)') do
    cues[#cues + 1] = { at = tonumber(at), name = name, opt = opt }
end

local RATE, N = 44100, 512
local buf = ffi.new('float[?]', N * 2)
local samples = {}
local blocks = math.floor(seconds * RATE / N)
for b = 1, blocks do
    local now = b * N / RATE
    if busyFrom and now > busyFrom and now < busyFrom + 6 and b % 20 == 0 then music.bump(1) end
    for _, cue in ipairs(cues) do
        if not cue.done and now >= cue.at then
            cue.done = true
            if cue.name == 'keep' then music.layers(cue.opt)
            else
                local layers = cue.opt ~= 'bar' and cue.opt ~= '' and cue.opt or nil
                music.cue(cue.name, { at = cue.opt == 'bar' and 'bar' or 'phrase', layers = layers })
            end
            print(('%5.1fs cue %s %s'):format(now, cue.name, cue.opt))
        end
    end
    clock = now
    music.update(synth, now)
    if not notesOnly then
        C.de_lua_render(buf, N)
        for i = 0, N * 2 - 1 do samples[#samples + 1] = buf[i] end
    end
end

if not notesOnly then
local peak = 0
for _, x in ipairs(samples) do if math.abs(x) > peak then peak = math.abs(x) end end
local sum, count = 0, 0
for w = 1, #samples - 2205, 2205 do -- 25 ms stereo windows, counted only while something sounds
    local e = 0
    for i = w, w + 2204 do e = e + samples[i] * samples[i] end
    e = e / 2205
    if e > 1e-6 then sum, count = sum + e, count + 1 end
end
local rmsDb = count > 0 and 10 * math.log10(sum / count) or -120
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
print(('%s  peak %.3f  rms %.1f dB (sounding)  %s'):format(out, peak, rmsDb, M.song and (M.song.style .. ' key ' .. M.song.key) or ''))
end

if notesOut and recorded.song then
    local song = recorded.song
    local lines = { '-- luacheck: no max line length',
        ('-- %s-seed%d: recorded by claudetools/render-music.lua (NOTES=), the first song of style %s, %d bars'):format(
            song.style, seed, song.style, song.bars),
        ('return { key = %d, meter = %d, velocity = 64, bars = {'):format(song.key % 12,
            math.floor(song.barLength / song.beat + 0.5)) }
    local bars = {}
    for b in pairs(recorded.bars) do bars[#bars + 1] = b end
    table.sort(bars)
    for _, b in ipairs(bars) do
        local cells = {}
        for _, n in ipairs(recorded.bars[b]) do
            if n[1] >= 0 then cells[#cells + 1] = ("{%d,%d,%d,'%s',%d}"):format(n[1], n[2], n[3], n[4], n[5]) end
        end
        lines[#lines + 1] = ('    [%d] = { %s },'):format(b, table.concat(cells, ', '))
    end
    lines[#lines + 1] = '} }'
    local f = assert(io.open(notesOut, 'w'))
    f:write(table.concat(lines, '\n'), '\n')
    f:close()
    print(('%s  %d bars recorded'):format(notesOut, #bars))
end
