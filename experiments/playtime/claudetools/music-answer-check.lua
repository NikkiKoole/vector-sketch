-- The answer's notes (bookAnswer, the idea 'answer') that are in neither the key nor the chord under
-- them: a wrong note, as the slide out of the key that Nikki heard in guaraldi (2026-11-02). A note
-- outside the key but in its chord (a II7's raised third, a borrowed bVII's) is fine and not counted.
-- usage: luajit claudetools/music-answer-check.lua <style> [songs] [seconds]
--        prints, per song (seeds 1..songs, default 6, each in its own process), wrong/all answer notes;
--        the answer forced always, the other ideas at never (IDEAS= adds or overrides, as render-music.lua)
package.path = './?.lua;' .. package.path
local style, songs, seconds = arg[1], tonumber(arg[2]) or 6, tonumber(arg[3]) or 100
if arg[4] ~= 'one' then -- each song in a process of its own: the music module keeps state between songs
    local out = {}
    for seed = 1, songs do
        local p = io.popen(('luajit %s %s %d %d one'):format(arg[0], style, seed, seconds))
        out[#out + 1] = p:read('*l') or '?'
        p:close()
    end
    print(style .. ' answer notes wrong/all per song: ' .. table.concat(out, ' '))
    return
end
local seed = songs
love = { math = { random = math.random } } -- luacheck: ignore
local ffi = require 'ffi'
ffi.cdef [[ int de_lua_init(void); void de_lua_render(float *out, int frames); ]]
local C = ffi.load('native/desound/libdesound.dylib')
C.de_lua_init()
package.loaded['src.state'] = { synth = { started = true, C = C } }
local synth = require('src.synth')
local music = require('src.music')
local theory = require('src.music-theory')
local M = package.loaded['src.state'].music
do
    math.randomseed(seed)
    music.style, music.rhythmSection = style, 'on'
    local ideas = { answer = 'always' }
    for name, mode in (os.getenv('IDEAS') or ''):gmatch('(%w+):(%w+)') do ideas[name] = mode end
    music.ideas = ideas
    local clock, total, wrong, first = 0, 0, 0, nil
    synth.audioTime = function() return clock end
    music.trace = function(part, t, midi)
        local song = M.song
        first = first or song
        if part ~= 'answer' or song ~= first then return end
        total = total + 1
        local step = math.max(0, math.floor((t - M.barAt) / (song.beat / 4) + 0.5))
        local chord = theory.chordAtStep(song, song.bar, step)
        if not theory.inKey(song, midi) and not theory.isChordTone(song, midi, chord) then wrong = wrong + 1 end
    end
    for block = 1, math.floor(seconds * 44100 / 512) do
        clock = block * 512 / 44100
        music.update(synth, clock)
    end
    print(wrong .. '/' .. total)
end
