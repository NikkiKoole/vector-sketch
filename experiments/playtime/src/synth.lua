-- synth.lua
-- dreamengine's synth (native/desound, built with native/desound/build.sh) through LuaJIT FFI.
-- The main thread calls the sound API; native/desound/synth-thread.lua renders into a QueueableSource.
-- Without the library every call is a no-op and synth.start() returns false,
-- so callers keep their sample-based fallback.

local ffi = require('ffi')
local state = require('src.state')

local lib = {}

lib.libPath = 'native/desound/libdesound.dylib' -- relative to love.filesystem.getSource()
lib.volume = 1.0
lib.reverbSize = 0.55    -- 0 small room .. 1 endless hall
lib.reverbDamping = 0.5  -- 0 bright .. 1 dark tail

-- instrument ids from dreamengine runtime/studio.h (#defines don't come through FFI)
lib.INSTR = {
    SQUARE = 0, SAW = 1, TRI = 2, NOISE = 3, SINE = 4,
    PLUCK = 16, MALLET = 17, FM = 18, EPIANO = 20, MEMBRANE = 22,
    GUITAR = 26, PIANO = 27, BOWED = 28, MODAL = 31, METAL = 34,
}

-- Named patches in instrument slots 5..47: wave, attack/decay ms, sustain 0..7, release ms, macros,
-- reverb send 0..1, level 0..1 (balances engines: some run much hotter), optional engine modes and filter.
lib.patches = {
    tom  = { slot = 5, wave = 'MEMBRANE', adsr = { 0, 400, 0, 200 },
             harmonics = 0.3, timbre = 0.35, morph = 0, reverb = 0.3 },
    wood = { slot = 6, wave = 'MALLET', adsr = { 0, 300, 0, 150 },
             harmonics = 0.05, timbre = 0.6, morph = 0.15, reverb = 0.35 },
    -- dreamengine's upright bass (tools/carts/upright.c): the bowed-string model plucked (pizzicato)
    -- in a double-bass-sized body, through a warm lowpass. modes: [MODE_BOW_PIZZ, _BODY, _SIZE]
    bass = { slot = 7, wave = 'BOWED', adsr = { 4, 0, 7, 475 },
             harmonics = 0.3, timbre = 0.3, morph = 0.45, reverb = 0.2, level = 0.8,
             modes = { [0] = 1, [1] = 0.85, [2] = 1 }, filter = { mode = 1, cutoff = 1490, resonance = 3 } },
}

local CDEF = [[
int  de_lua_init(void);
void de_lua_tick(float dt);
void instrument(int slot, int wave, int attack_ms, int decay_ms, int sustain, int release_ms);
void instrument_harmonics(int slot, float x);
void instrument_timbre(int slot, float x);
void instrument_morph(int slot, float x);
void instrument_level(int slot, float gain);
void hit(int midi, int instr, int vol, int dur_ms);
void hit_at(int midi, int instr, int vol, int dur_ms, float x, float y);
void listener(float x, float y);
void spatial_model(float ref_dist, float max_dist, float rolloff);
void spatial_speed(float c);
void reverb(float size, float damping);
void instrument_reverb(int slot, float send);
void instrument_mode(int slot, int idx, float value);
void instrument_filter(int slot, int mode, int cutoff_hz, int resonance);
]]
-- At load, so a hot reload can add functions. Redeclaring an identical function is allowed.
pcall(ffi.cdef, CDEF)

-- Lives on `state` so a lurker hot-swap of this file doesn't load the library or start the thread twice.
state.synth = state.synth or { started = false, failed = nil, C = nil, thread = nil, quit = nil }
local S = state.synth

local function definePatches()
    S.C.reverb(lib.reverbSize, lib.reverbDamping)
    for _, patch in pairs(lib.patches) do
        local a, d, s, r = unpack(patch.adsr)
        S.C.instrument(patch.slot, lib.INSTR[patch.wave], a, d, s, r)
        S.C.instrument_harmonics(patch.slot, patch.harmonics or 0)
        S.C.instrument_timbre(patch.slot, patch.timbre or 0)
        S.C.instrument_morph(patch.slot, patch.morph or 0)
        S.C.instrument_level(patch.slot, lib.volume * (patch.level or 1))
        S.C.instrument_reverb(patch.slot, patch.reverb or 0)
        for idx, value in pairs(patch.modes or {}) do S.C.instrument_mode(patch.slot, idx, value) end
        local filter = patch.filter or { mode = 0, cutoff = 0, resonance = 0 }
        S.C.instrument_filter(patch.slot, filter.mode, filter.cutoff, filter.resonance)
    end
end

-- Loads the library and starts the render thread once; returns whether the synth is usable.
function lib.start()
    if S.started then return true end
    if S.failed then return false end
    if not (love and love.thread and love.audio) then
        S.failed = 'no love.thread/love.audio'
        return false
    end
    local path = love.filesystem.getSource() .. '/' .. lib.libPath
    if not love.filesystem.getInfo(lib.libPath) then
        S.failed = 'missing ' .. lib.libPath .. ' (run native/desound/build.sh)'
        print('[synth] ' .. S.failed)
        return false
    end
    local ok, C = pcall(ffi.load, path)
    if not ok then
        S.failed = tostring(C)
        print('[synth] ' .. S.failed)
        return false
    end
    S.C = C
    C.de_lua_init()
    C.spatial_speed(0) -- impact speeds are thousands of units/s; no Doppler
    definePatches()
    S.quit = love.thread.getChannel('synth-quit')
    S.quit:clear()
    S.thread = love.thread.newThread('native/desound/synth-thread.lua')
    S.thread:start(path)
    S.started = true
    return true
end

function lib.isRunning()
    return S.started
end

function lib.stop()
    if not S.started then return end
    S.quit:push(true)
    S.thread:wait()
    S.started = false
end

-- Main thread, every frame: advances the engine clock, keeps the listener on the camera
-- and reports render-thread errors.
function lib.update(dt, camera)
    if not S.started then return end
    S.C.de_lua_tick(dt)
    if camera then
        local cx, cy = camera:getTranslation()
        local halfWidth = camera:getContainerDimensions() / camera:getScale() / 2
        S.C.listener(cx, cy)
        S.C.spatial_model(halfWidth, halfWidth * 4, 1)
    end
    local err = S.thread:getError()
    if err then
        print('[synth] render thread died: ' .. err)
        S.started = false
        S.failed = err
    end
end

-- One-shot note on a named patch. vol 0..7. With x, y it is placed in the world
-- (panned and quieter away from the listener).
function lib.hit(patchName, midi, vol, durMs, x, y)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not patch then return end
    vol = math.max(0, math.min(7, math.floor(vol + 0.5)))
    if x then
        S.C.hit_at(midi, patch.slot, vol, durMs, x, y)
    else
        S.C.hit(midi, patch.slot, vol, durMs)
    end
end

-- A hot reload (lurker) of this file re-applies the patches, so saving a tweak is audible right away.
if S.started then definePatches() end

return lib
