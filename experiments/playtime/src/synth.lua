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
    PLUCK = 16, MALLET = 17, FM = 18, EPIANO = 20, MEMBRANE = 22, PIPE = 25,
    GUITAR = 26, PIANO = 27, BOWED = 28, MODAL = 31, METAL = 34,
}

-- Named patches in instrument slots 5..47: wave, attack/decay ms, sustain 0..7, release ms, macros,
-- reverb send 0..1, level 0..1 (balances engines: some run much hotter), optional engine modes and filter,
-- glide ms (held notes slide to a new pitch over this long), tape { wow, flutter, saturation, warble } 0..1
-- (a cassette on just this slot; warble = a worn tape that sags now and then).
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
    -- drum skins (the membrane engine) for boxes: harmonics = head (tuned -> inharmonic),
    -- timbre = strike (center thump -> edge slap), morph = the tabla's downward pitch bend
    conga  = { slot = 9, wave = 'MEMBRANE', adsr = { 0, 500, 0, 250 },
               harmonics = 0.15, timbre = 0.3, morph = 0, reverb = 0.3 },
    djembe = { slot = 10, wave = 'MEMBRANE', adsr = { 0, 500, 0, 250 },
               harmonics = 0.75, timbre = 0.6, morph = 0, reverb = 0.3 },
    tabla  = { slot = 11, wave = 'MEMBRANE', adsr = { 0, 500, 0, 250 },
               harmonics = 0, timbre = 0.5, morph = 0.4, reverb = 0.3 },
    -- slide whistle: the blown pipe (in tune at morph 0.7), held and glided (src/slide-sound.lua).
    -- Breathy (timbre = breath air) and on a wobbly cassette, so it sounds less like a pure synth.
    whistle = { slot = 8, wave = 'PIPE', adsr = { 30, 0, 7, 120 },
                harmonics = 0.3, timbre = 0.65, morph = 0.7, reverb = 0.25, level = 0.25, glide = 40,
                tape = { wow = 0.5, flutter = 0.3, saturation = 0.3, warble = 0.3 } },
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
void instrument_glide(int slot, int ms);
void instrument_tape(int slot, float wow, float flutter, float saturation);
void instrument_tape_warble(int slot, float amount);
int  note_on(int midi, int instr, int vol);
void note_off(int handle);
void note_pitch(int handle, float midi);
void note_vol(int handle, float vol);
void note_pos(int handle, float x, float y);
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
        S.C.instrument_glide(patch.slot, patch.glide or 0)
        if patch.tape then
            S.C.instrument_tape(patch.slot, patch.tape.wow, patch.tape.flutter, patch.tape.saturation)
            S.C.instrument_tape_warble(patch.slot, patch.tape.warble or 0)
        end
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

-- Held notes. noteOn returns a handle (nil when the synth isn't running); vol 0..7, fractions OK.
-- A handle whose voice was stolen just stops responding, so a stale one is harmless.
function lib.noteOn(patchName, midi, vol, x, y)
    if not S.started then return nil end
    local patch = lib.patches[patchName]
    if not patch then return nil end
    local handle = S.C.note_on(midi, patch.slot, math.max(0, math.min(7, math.floor(vol + 0.5))))
    if x then S.C.note_pos(handle, x, y) end
    return handle
end

-- Changes a held note live; pass nil to leave a value as it is. The engine slews each change.
function lib.noteSet(handle, midi, vol, x, y)
    if not (S.started and handle) then return end
    if midi then S.C.note_pitch(handle, midi) end
    if vol then S.C.note_vol(handle, math.max(0, math.min(7, vol))) end
    if x then S.C.note_pos(handle, x, y) end
end

function lib.noteOff(handle)
    if S.started and handle then S.C.note_off(handle) end
end

-- A hot reload (lurker) of this file re-applies the patches, so saving a tweak is audible right away.
if S.started then definePatches() end

return lib
