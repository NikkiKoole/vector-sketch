-- music-trace: every call the music makes to the synth, written out as text, for refactors of the music
-- code that mustn't change what plays. The real src/music.lua + src/synth.lua on render-music.lua's offline
-- clock (no sound is made, so it's quick); each scenario in a process of its own (the music modules keep
-- state between songs). Same seed, same settings: the same calls, so before/after is a plain diff.
--   luajit claudetools/music-trace.lua take <dir>         every scenario's calls into <dir>/<scenario>.txt
--   luajit claudetools/music-trace.lua diff <dirA> <dirB>  identical, or the first difference per scenario
--   luajit claudetools/music-trace.lua list               the scenarios
-- Run from experiments/playtime. Needs native/desound/libdesound.dylib (docs/SOUND-SYNTH.md): synth.lua
-- defines its patches through it. The scenarios cover the jam (every genre, the play level rising and
-- falling, the panel's picks); add more for other styles in SCENARIOS.
package.path = './?.lua;' .. package.path

-- A scenario: style, seed, seconds; bumps = { {from s, to s, every s, amount} } raise the play level;
-- jam = the jam's panel picks; impacts = { {at s, strength} } world impacts; moments = { {at s, name} }.
local RISE_FALL = { { 10, 40, 1.5, 1 }, { 70, 90, 0.7, 1 } } -- calm, busy, calm, very busy, calm
local SCENARIOS = {}
local function add(name, s) s.name = name SCENARIOS[#SCENARIOS + 1] = s end
for _, seed in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 25 }) do -- every genre (25 = Brushes; each
    -- trace's first song line says which)
    add('jam-seed' .. seed, { style = 'jam', seed = seed, seconds = 150, bumps = RISE_FALL,
                              impacts = { { 33, 0.7 }, { 61, 0.95 }, { 95, 0.95 } },
                              moments = { { 47, 'door' }, { 120, 'snap' } } })
end
add('jam-all-layers', { style = 'jam', seed = 4, seconds = 100, jam = { layers = 'all' } })
add('jam-picks', { style = 'jam', seed = 5, seconds = 100, bumps = RISE_FALL,
                   jam = { walk = 'round the fourths', pace = '2', chords = 'funk stabs', figure = 'riff: pocket' } })
add('jam-spot-feature', { style = 'jam', seed = 6, seconds = 120, bumps = RISE_FALL, jam = { spot = 'bass feature' } })
add('jam-spot-trading', { style = 'jam', seed = 7, seconds = 120, bumps = RISE_FALL, jam = { spot = 'trading' } })
add('jam-spot-break', { style = 'jam', seed = 8, seconds = 120, bumps = RISE_FALL, jam = { spot = 'drum break' } })
add('jam-moves-always', { style = 'jam', seed = 9, seconds = 100, bumps = RISE_FALL,
                          jam = { gap = 'always', lean = 'always', variations = 'always' } })
add('jam-moves-never', { style = 'jam', seed = 10, seconds = 100, bumps = RISE_FALL,
                         jam = { gap = 'never', lean = 'never', variations = 'never', spot = 'never' } })
add('jam-funk-guitar', { style = 'jam', seed = 10, seconds = 100, bumps = RISE_FALL, jam = { chords = 'funk guitar' } })
-- the jam answering the world's moments (world = state.musicSettings.world: the stingers' and impacts' rows)
local MOMENTS = { { 15, 'door' }, { 24, 'snap' }, { 31, 'jump' }, { 38, 'grab' }, { 52, 'room' }, { 66, 'throw' },
                  { 75, 'daze' }, { 83, 'door' }, { 91, 'wake' } }
add('jam-stingers-small', { style = 'jam', seed = 3, seconds = 100, bumps = RISE_FALL, moments = MOMENTS,
                            world = { stingerSize = 'small', stingerMoments = 'all' } })
add('jam-stingers-big', { style = 'jam', seed = 9, seconds = 100, bumps = RISE_FALL, moments = MOMENTS,
                          impacts = { { 20, 0.95 }, { 45, 0.7 }, { 70, 0.95 } },
                          world = { stingerSize = 'big', stingerMoments = 'rare', impact = 'crash' } })
-- long and busy, for the rare paths (the tom roll: Funk and Breaks, a third of their unwritten fills)
local BUSY = { { 5, 400, 0.6, 1 } }
add('jam-funk-long', { style = 'jam', seed = 11, seconds = 400, bumps = BUSY })
add('jam-breaks-long', { style = 'jam', seed = 1, seconds = 400, bumps = BUSY, jam = { variations = 'never' } })

local mode = arg[1]

local function fmt(v, depth)
    local t = type(v)
    if t == 'number' then
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', v) end
        return string.format('%.6f', v)
    elseif t == 'string' then return string.format('%q', v)
    elseif t == 'table' then
        if (depth or 0) > 3 then return '{...}' end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. fmt(v[k], (depth or 0) + 1) end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif t == 'nil' or t == 'boolean' then return tostring(v)
    else return t end -- a function or cdata: only that it was one
end

-- one scenario, in this process: the calls go to stdout
local function runOne(s)
    math.randomseed(s.seed)
    love = { math = { random = math.random } } -- luacheck: ignore
    local ffi = require 'ffi'
    ffi.cdef [[ int de_lua_init(void); void de_lua_render(float *out, int frames); ]]
    local C = ffi.load('native/desound/libdesound.dylib')
    C.de_lua_init()
    package.loaded['src.state'] = { synth = { started = true, C = C } }
    local synth = require('src.synth')
    local music = require('src.music')
    music.style, music.rhythmSection = s.style, 'auto'
    local st = package.loaded['src.state']
    if s.jam then st.musicSettings.jam = s.jam end
    if s.world then st.musicSettings.world = s.world end
    local clock = 0
    synth.audioTime = function() return clock end
    local out, n = {}, 0
    local function log(line)
        n = n + 1
        out[n] = line
        if n >= 4096 then io.write(table.concat(out, '\n'), '\n') out, n = {}, 0 end
    end
    for name, f in pairs(synth) do -- every function the music can call on the synth table
        if type(f) == 'function' and name ~= 'audioTime' then
            synth[name] = function(...)
                local args = { ... }
                local parts = {}
                for i = 1, select('#', ...) do parts[i] = fmt(args[i]) end
                log(('%.4f %s(%s)'):format(clock, name, table.concat(parts, ',')))
                return f(...)
            end
        end
    end
    local RATE, N = 44100, 512
    local blocks = math.floor(s.seconds * RATE / N)
    local nextBump = {}
    local impacts, moments = s.impacts or {}, s.moments or {}
    -- what else the music hands out: the world's moments (chord, phrase, drop), the chords impacts play
    -- along in (M.booked), and at the end the sounds the panel lists (M.styleSounds)
    local events = require('src.music-events')
    local moment = events.moment
    events.moment = function(what, at, data)
        log(('%.4f moment(%s,%s,%s)'):format(clock, fmt(what), fmt(at), fmt(data)))
        return moment(what, at, data)
    end
    local lastBooked
    local group
    for b = 1, blocks do
        local now = b * N / RATE
        clock = now
        for k, bump in ipairs(s.bumps or {}) do
            if now >= bump[1] and now < bump[2] and now >= (nextBump[k] or 0) then
                music.bump(bump[4])
                nextBump[k] = now + bump[3]
            end
        end
        for _, e in ipairs(impacts) do
            if not e.done and now >= e[1] then e.done = true music.event('impact', { strength = e[2] }) end
        end
        for _, e in ipairs(moments) do
            if not e.done and now >= e[1] then e.done = true music.event(e[2], {}) end
        end
        music.update(synth, now)
        local booked = st.music.booked and st.music.booked[#st.music.booked]
        if booked and booked ~= lastBooked then
            lastBooked = booked
            log(('%.4f remember(%s)'):format(clock, fmt(booked)))
        end
        local song = st.music.song
        if song and song.jam and song.jam.group ~= group then
            group = song.jam.group
            log(('%.4f -- song: %s, group %s, family %s'):format(now, song.style, group, tostring(song.jam.family)))
        end
    end
    log('styleSounds ' .. fmt(st.music.styleSounds))
    io.write(table.concat(out, '\n'), '\n')
end

local function shell(cmd) local p = io.popen(cmd) local r = p:read('*a') p:close() return r end

if mode == 'one' then
    for _, s in ipairs(SCENARIOS) do if s.name == arg[2] then runOne(s) os.exit(0) end end
    io.stderr:write('no scenario ' .. tostring(arg[2]) .. '\n') os.exit(1)
elseif mode == 'list' then
    for _, s in ipairs(SCENARIOS) do print(s.name) end
elseif mode == 'take' and arg[2] then
    os.execute('mkdir -p ' .. arg[2])
    for _, s in ipairs(SCENARIOS) do
        local file = arg[2] .. '/' .. s.name .. '.txt'
        local ok = os.execute(('luajit %s one %s > %s 2> %s.err'):format(arg[0], s.name, file, file))
        local lines = shell('wc -l < ' .. file):gsub('%s', '')
        local head = shell('grep -m1 -- "-- song" ' .. file):gsub('^%S+ %-%- ', ''):gsub('\n', '')
        local failed = not (ok == 0 or ok == true) and '  FAILED, see .err' or ''
        print(('%-20s %8s calls  %s%s'):format(s.name, lines, head, failed))
    end
elseif mode == 'diff' and arg[2] and arg[3] then
    local same = true
    for _, s in ipairs(SCENARIOS) do
        local a, b = arg[2] .. '/' .. s.name .. '.txt', arg[3] .. '/' .. s.name .. '.txt'
        if shell(('cmp -s %s %s && echo same'):format(a, b)):match('same') then
            print(('%-20s identical'):format(s.name))
        else
            same = false
            print(('%-20s DIFFERENT, first lines:'):format(s.name))
            io.write(shell(('diff %s %s | head -6'):format(a, b)))
        end
    end
    print(same and 'all identical' or 'some differ')
    os.exit(same and 0 or 1)
else
    print('usage: luajit claudetools/music-trace.lua take <dir> | diff <dirA> <dirB> | list')
end
