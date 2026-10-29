-- voice-lab.lua — a test bench for Mipo voices on dreamengine's synth
-- (docs/PUPPETMAKER-SOUND.md P8), apart from the Mipos' real sounds: the settings
-- panel's 'voice lab' fold (src/voice-lab-params.lua). One take, knobs that mix:
--   speed  semitones: the playback rate, the chipmunk: pitch and length change together
--          (what every Mipo sound does now, through LÖVE)
--   shift  semitones: the pitch moves, the length stays (sample_shift; the formants move along)
--   size   semitones: the throat, + bigger: the formants move, pitch and length stay (sample_formant)
-- Play 'now' (the plain take through LÖVE at speed: today's sound), 'synth' (the take with
-- shift and size baked in, played at speed) or 'sing' (INSTR_SING: the take sung at speed's
-- note, held for the take's own length, size as its throat, inflection = how much of the
-- take's own melody it keeps).
-- Uses sample slot 7 and instrument slots 45 (sample) and 46 (sing).
local lib = {}

local state = require('src.state')

local SAMPLE_SLOT = 7
local PLAYER, SINGER = 45, 46
local RATE = 44100 -- the synth's rate; puppetmaker takes are 48 kHz, so everything is resampled

lib.sets = { 'puppetmaker', 'nikki', 'theo', 'herman', 'fx' }

state.voiceLab = state.voiceLab or { set = 'puppetmaker', index = 1, speed = 0, shift = 0, size = 0, inflection = 0.5 }
local L = state.voiceLab

local function synth()
    local ok, s = pcall(require, 'src.synth')
    if ok and s.start() then return s, state.synth.C end
    return nil
end

local function takes(set)
    local list = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems('assets/voices/' .. set)) do
        local key = file:match('^(.+)%.ogg$')
        if key then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

function lib.takeName()
    local list = takes(L.set)
    if #list == 0 then return nil end
    L.index = (L.index - 1) % #list + 1
    return list[L.index]
end

function lib.path()
    local name = lib.takeName()
    return name and ('assets/voices/' .. L.set .. '/' .. name .. '.ogg')
end

function lib.step(delta)
    L.index = L.index + delta
    lib.takeName()
end

-- The take as mono floats at the synth's rate (linear resampling).
local function pcm(path)
    local data = love.sound.newSoundData(path)
    local rate, channels, count = data:getSampleRate(), data:getChannelCount(), data:getSampleCount()
    local n = math.floor(count * RATE / rate)
    local ffi = require('ffi')
    local out = ffi.new('float[?]', n)
    for i = 0, n - 1 do
        local pos = i * rate / RATE
        local i0 = math.floor(pos)
        local i1 = math.min(i0 + 1, count - 1)
        local f = pos - i0
        local a, b = 0, 0
        for c = 1, channels do
            a = a + data:getSample(i0, c)
            b = b + data:getSample(i1, c)
        end
        out[i] = (a + (b - a) * f) / channels
    end
    return out, n, count / rate
end

-- Load the take into the sample slot (again only when something changed) and bind
-- both instruments to it. For 'synth' with shift and size baked in; for 'sing' plain
-- (it does pitch and size itself: baked in too, size counted twice).
local function prepare(C, plain)
    local path = lib.path()
    if not path then return false end
    local shift, size = plain and 0 or L.shift, plain and 0 or L.size
    local key = path .. '|' .. shift .. '|' .. size
    if L.loaded == key then return true end
    local data, n, seconds = pcm(path)
    C.sample_load(SAMPLE_SLOT, data, n)
    if shift ~= 0 then C.sample_shift(SAMPLE_SLOT, shift) end
    if size ~= 0 then C.sample_formant(SAMPLE_SLOT, -size) end -- sample_formant: + = smaller
    local s = require('src.synth')
    -- instrument() first: it clears the sample binding
    C.instrument(PLAYER, s.INSTR.SAMPLE, 1, 0, 7, 40)
    C.instrument_sample(PLAYER, SAMPLE_SLOT, 60)
    C.instrument(SINGER, s.INSTR.SING, 4, 10, 7, 90)
    C.instrument_sample(SINGER, SAMPLE_SLOT, 60)
    L.loaded, L.seconds = key, seconds
    return true
end

-- 'now': the plain take through LÖVE at speed, the way Mipos sound today.
function lib.playNow()
    local path = lib.path()
    if not path then return end
    local source = love.audio.newSource(path, 'static')
    source:setPitch(2 ^ (L.speed / 12))
    source:setVolume(0.8)
    source:play()
end

-- The lab's own level, set on every play: the music panel's volume scales every synth
-- patch, and with the music turned down to listen the lab went silent. Measured
-- (spec/voice-lab_spec.lua): at level 1 the sample player is ~15 dB under the take;
-- level 4 at note volume 7 lands at -1.9 dB, where 'now' plays (LÖVE volume 0.8), so
-- at all zeros 'now' and 'synth' match in pitch, length and loudness. (Quieter, it
-- sounded lower.)
lib.level = 4
local VOL = 7

-- 'synth': the take with shift and size baked in, played at speed (the rate).
function lib.playSynth()
    local s, C = synth()
    if not s or not prepare(C) then return end
    C.instrument_level(PLAYER, lib.level)
    local rate = 2 ^ (L.speed / 12)
    C.hit(60 + L.speed, PLAYER, VOL, math.floor(L.seconds / rate * 1000) + 60)
end

-- 'sing': INSTR_SING at speed's note, the take's own length, size as its throat.
function lib.playSing()
    local s, C = synth()
    if not s or not prepare(C, true) then return end
    C.instrument_level(SINGER, lib.level)
    C.instrument_timbre(SINGER, 0.5 - L.size / 24) -- 0.5 = as recorded, lower = a bigger throat
    C.instrument_harmonics(SINGER, L.inflection)
    C.instrument_morph(SINGER, 0.5) -- its own speed
    -- held for the take's own length: once through. SING sounds only while held (+ a short
    -- release; measured: released at once it's ~0.1 s, the word cut off), and once it gets to
    -- the take's last vowel it sustains it by repeating it (the looping you can hear).
    C.hit(60 + L.speed, SINGER, VOL, math.floor(L.seconds * 1000))
end

function lib.status()
    local name = lib.takeName()
    if not name then return 'no takes in ' .. L.set end
    local s = state.synth
    local synthState = (s and s.started) and '' or ' (synth off)'
    return L.set .. '/' .. name .. (L.seconds and string.format('  %.2fs', L.seconds) or '') .. synthState
end

return lib
