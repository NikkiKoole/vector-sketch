-- synth.lua
-- dreamengine's synth (native/desound, built with native/desound/build.sh) through LuaJIT FFI.
-- The main thread calls the sound API; native/desound/synth-thread.lua renders into a QueueableSource.
-- Without the library every call is a no-op and synth.start() returns false,
-- so callers keep their sample-based fallback.
-- In the browser (no FFI) src/synth-web.lua stands in for the library and the page plays it.

local IS_WEB = love ~= nil and love.system ~= nil and love.system.getOS() == 'Web'
local ffi = not IS_WEB and require('ffi') or nil
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
    GUITAR = 26, PIANO = 27, BOWED = 28, BRASS = 29, SAMPLE = 30, MODAL = 31, METAL = 34, WAVESCAN = 36,
    SCRAPE = 39, -- scraped/rattled percussion from separate teeth: harmonics body, timbre rate, morph rattle
    SING = 38, -- one recorded syllable sung at any note by the same speaker (timbre = size, morph = speed)
}

-- Named patches in instrument slots 5..47 (pool = true: no slot of its own, see lib.poolSlots): wave,
-- attack/decay ms, sustain 0..7, release ms, macros,
-- reverb send 0..1, level 0..1 (balances engines: some run much hotter), optional engine modes and filter,
-- glide ms (held notes slide to a new pitch over this long), tape { wow, flutter, saturation, warble } 0..1
-- (a cassette on just this slot; warble = a worn tape that sags now and then), autopan, phaser.
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
    -- a tiny wooden click (a hard mallet on a wooden bar, ~35 ms) for snapping, src/snap-sound.lua
    click  = { slot = 12, wave = 'MALLET', adsr = { 0, 40, 0, 20 },
               harmonics = 0.05, timbre = 0.9, morph = 0, reverb = 0.1, level = 0.5 },
    -- background music (src/music.lua). The Rhodes is the epiano cart's 'suitcase' preset: mellow
    -- (harmonics 0.15 = the Rhodes detent), stereo vibrato (autopan) and a slow phaser swirl.
    rhodes = { slot = 13, wave = 'EPIANO', adsr = { 1, 0, 7, 450 },
               harmonics = 0.15, timbre = 0.2, morph = 0.12, reverb = 0.3, level = 0.35,
               autopan = { rate = 4, depth = 0.5 }, phaser = { rate = 0.8, depth = 0.65, feedback = 0.5, mix = 0.5 },
               tape = { wow = 0.25, flutter = 0.1, saturation = 0, warble = 0 } },
    musicBass = { slot = 14, wave = 'BOWED', adsr = { 4, 0, 7, 475 },
                  harmonics = 0.3, timbre = 0.3, morph = 0.45, reverb = 0.15, level = 0.45,
                  modes = { [0] = 1, [1] = 0.85, [2] = 1 }, filter = { mode = 1, cutoff = 1200, resonance = 3 } },
    -- the citypop style, after dreamengine's citypop2.c: a clean single-coil guitar cutting muted
    -- 16ths (high-passed, no chorus: that needs an FX bus) and a soft saw string section, slow in.
    -- Slots 18 and 21 were the celesta (disliked) and the wavescan kalimba (unused): the engine has
    -- 48 slots (SOUND_INSTR_SLOTS) and every one is taken.
    cityGuitar = { pool = true, wave = 'GUITAR', adsr = { 1, 0, 7, 90 },
                   harmonics = 0.45, timbre = 0.78, morph = 0.5, reverb = 0.15, level = 1.8,
                   filter = { mode = 2, cutoff = 220, resonance = 0 } },
    strings = { pool = true, wave = 'SAW', adsr = { 260, 0, 6, 260 }, reverb = 0.45, level = 0.22,
                filter = { mode = 1, cutoff = 2600, resonance = 0 }, lfo = { { 0, 5.0, 0.04 } } },
    -- other melody voices: the Rhodes a little brighter for a tune on top, and a kalimba: a
    -- mallet halfway between wood and bell
    rhodesLead = { slot = 19, wave = 'EPIANO', adsr = { 1, 0, 7, 450 },
                   harmonics = 0.15, timbre = 0.35, morph = 0.15, reverb = 0.3, level = 0.8,
                   autopan = { rate = 4, depth = 0.4 } },
    kalimba = { slot = 20, wave = 'MALLET', adsr = { 0, 600, 0, 300 },
                harmonics = 0.45, timbre = 0.35, morph = 0.2, reverb = 0.3, level = 1.0 },
    -- the music's rhythm section (bossa): a soft kick (a drumhead struck in the centre), the
    -- cross-stick rim click (a hard wooden tick) and a shaker (short high-passed noise)
    kick   = { slot = 15, wave = 'MEMBRANE', adsr = { 0, 220, 0, 80 },
               harmonics = 0.25, timbre = 0.1, morph = 0, reverb = 0.05, level = 0.6 },
    rim    = { slot = 16, wave = 'MALLET', adsr = { 0, 50, 0, 30 },
               harmonics = 0.0, timbre = 0.95, morph = 0, reverb = 0.15, level = 0.35 },
    shaker = { slot = 17, wave = 'NOISE', adsr = { 3, 45, 0, 25 }, reverb = 0.1, level = 0.12,
               filter = { mode = 2, cutoff = 6500, resonance = 1 } },
    -- the guaraldi style (src/music.lua): a felt grand (piano.c's 'grand' preset, a little softer
    -- hammer, lowpassed warm) and dreamengine cocktail.c's brushes kit: a brushed ride ping, a
    -- closed hat on 2 and 4, the circular brush sweep. The kick is the bossa one, feathered.
    -- Levels balanced on rendered stems (claudetools/render-music.lua SOLO=...) against the Rhodes.
    piano = { slot = 22, wave = 'PIANO', adsr = { 1, 0, 7, 1200 },
              harmonics = 0.08, timbre = 0.4, morph = 0.55, reverb = 0.3, level = 1.6,
              filter = { mode = 1, cutoff = 3400, resonance = 1 },
              tape = { wow = 0.15, flutter = 0.03, saturation = 0, warble = 0 } },
    pianoLead = { slot = 26, wave = 'PIANO', adsr = { 1, 0, 7, 1200 },   -- the same piano, for the tune
                  harmonics = 0.08, timbre = 0.45, morph = 0.55, reverb = 0.3, level = 2.8,
                  filter = { mode = 1, cutoff = 4200, resonance = 1 },
                  tape = { wow = 0.15, flutter = 0.03, saturation = 0, warble = 0 } },
    -- the island style: a soft wooden marimba for the plinky riff (a mallet on a wooden bar,
    -- softer than the box 'wood' and ringing longer)
    marimba = { slot = 27, wave = 'MALLET', adsr = { 0, 500, 0, 250 },
                harmonics = 0.08, timbre = 0.35, morph = 0.35, reverb = 0.3, level = 1.0 },
    -- the dumont style: a soft synth stab (a lowpassed saw), a funk bass
    -- (a triangle, lowpassed with a bit of bite), a steel pan for the tune (a mallet toward the bell,
    -- ringing), and a drum machine clap (high-passed noise, a big room).
    -- No tape/autopan/phaser here: each of those takes one of the engine's 7 aux FX buses
    -- (SOUND_FX_BUSES), and five are taken (rhodes, rhodesLead, piano, pianoLead, guitar).
    stab = { pool = true, wave = 'SAW', adsr = { 3, 180, 2, 160 }, reverb = 0.35, level = 0.38,
             filter = { mode = 1, cutoff = 1500, resonance = 2 } },
    dubBass = { slot = 29, wave = 'TRI', adsr = { 3, 0, 7, 90 }, reverb = 0.05, level = 0.5,
                filter = { mode = 1, cutoff = 1100, resonance = 3 } },
    steelpan = { pool = true, wave = 'MALLET', adsr = { 0, 700, 0, 350 },
                 harmonics = 0.7, timbre = 0.5, morph = 0.4, reverb = 0.35, level = 0.9 },
    clap = { pool = true, wave = 'NOISE', adsr = { 0, 70, 0, 60 }, reverb = 0.6, level = 0.35,
             filter = { mode = 2, cutoff = 1400, resonance = 2 } },
    -- the herbs style (boom-bap): a hard kick (a looser, longer drumhead than the soft kick), a
    -- snare's noise (its body is that kick tuned up) and vinyl crackle (tiny high-passed ticks)
    bapKick = { slot = 31, wave = 'MEMBRANE', adsr = { 0, 300, 0, 100 },
                harmonics = 0.1, timbre = 0.05, morph = 0, reverb = 0.05, level = 1.8 },
    snare = { slot = 33, wave = 'NOISE', adsr = { 0, 130, 0, 90 }, reverb = 0.25, level = 0.6,
              filter = { mode = 2, cutoff = 1200, resonance = 1 } },
    crackle = { slot = 34, wave = 'NOISE', adsr = { 0, 4, 0, 4 }, reverb = 0, level = 0.3,
                filter = { mode = 2, cutoff = 3500, resonance = 1 } },
    -- the lofi style, after dreamengine's lofi city (its jazzhop casting): a darker Rhodes with
    -- the suitcase tremolo, a slow pan and a few cents of tape wow, all as LFOs (an LFO takes no FX
    -- bus), vibes for the tune, a round sine bass, a softer kick and a vinyl hiss bed. music.lua rides
    -- the lowpass on the keys, vibes and bass (lib.slotFilter): the intro opens up, the break dips.
    -- lfo = { { dest, rate Hz, depth } } per LFO: dest 0 pitch (semitones), 2 volume, 7 pan.
    lofiKeys = { slot = 35, wave = 'EPIANO', adsr = { 2, 0, 7, 320 },
                 harmonics = 0.10, timbre = 0.36, morph = 0.18, reverb = 0.3, level = 0.54,
                 filter = { mode = 1, cutoff = 3400, resonance = 0 },
                 lfo = { { 2, 4.5, 0.06 }, { 7, 4.5, 0.12 }, { 0, 0.5, 0.035 } } },
    vibes = { slot = 36, wave = 'MALLET', adsr = { 1, 0, 7, 1100 },
              harmonics = 0.25, timbre = 0.5, morph = 0.9, reverb = 0.3, level = 0.5,
              filter = { mode = 1, cutoff = 3200, resonance = 0 } },
    roundBass = { slot = 37, wave = 'SINE', adsr = { 4, 0, 6, 150 }, reverb = 0.05, level = 0.36,
                  filter = { mode = 1, cutoff = 600, resonance = 0 } },
    lofiKick = { slot = 38, wave = 'MEMBRANE', adsr = { 0, 180, 0, 80 },
                 harmonics = 0.05, timbre = 0.0, morph = 0, reverb = 0.05, level = 1.6 },
    hiss = { slot = 39, wave = 'NOISE', adsr = { 300, 0, 7, 300 }, reverb = 0, level = 0.02,
             filter = { mode = 1, cutoff = 5000, resonance = 0 } },
    -- the puppetmaker style, Puppetmaker 2's band (docs/PUPPETMAKER-SOUND.md 1a) on the synth: the
    -- CR-78's tambourine (a short highpassed jingle) and guiro (a bandpassed scrape, chopped by a fast
    -- volume LFO), two triangles (a bell-hard mallet very high, choked and ringing) and the quijada
    -- (a jawbone rattle: noise through a fast LFO, decaying). The hand drums are the conga patch.
    -- The guiro and quijada are dreamengine's INSTR_SCRAPE (asked for in dreamengine-studio#45, from
    -- measurements of the recordings): each tooth its own noise burst ringing a body. The CR-78 guiro
    -- scrapes ~75 teeth/s for ~270 ms around 6 kHz; the quijada rattles ~23/s and dies away, ~2.5 kHz.
    -- Play them at note 60 (the note moves the body) and the hit length is the scrape's length.
    tamb = { slot = 44, wave = 'NOISE', adsr = { 0, 220, 0, 60 }, reverb = 0.1, level = 0.027,
             filter = { mode = 2, cutoff = 6500, resonance = 1 } },
    guiro = { slot = 40, wave = 'SCRAPE', adsr = { 0, 0, 7, 30 }, harmonics = 0.0, timbre = 0.87, morph = 0.0,
              reverb = 0.02, level = 0.7 },  -- nearly dry: a room tail fills the gaps between the teeth
    triangle = { slot = 41, wave = 'MALLET', adsr = { 0, 90, 0, 40 },
                 harmonics = 1.0, timbre = 0.9, morph = 0.5, reverb = 0.25, level = 0.5 },
    triangleRing = { slot = 42, wave = 'MALLET', adsr = { 0, 1800, 0, 600 },
                     harmonics = 1.0, timbre = 0.9, morph = 0.9, reverb = 0.3, level = 0.5 },
    quijada = { slot = 43, wave = 'SCRAPE', adsr = { 0, 0, 7, 30 }, harmonics = 0.5, timbre = 0.35, morph = 1.0,
                reverb = 0.05, level = 0.7 },
    -- the sesame style: a clavinet (dreamengine's clavinet.c recipe: the e-piano engine's clav voicing,
    -- short and percussive, without its bus wah) and a horn section (the lip-reed BRASS engine,
    -- between trumpet and flugelhorn, round rather than blatty) for short shouts
    clav = { pool = true, wave = 'EPIANO', adsr = { 2, 140, 2, 120 },
             harmonics = 0.85, timbre = 0.75, morph = 0.55, reverb = 0.2, level = 1.1 },
    horn = { pool = true, wave = 'BRASS', adsr = { 8, 0, 6, 120 },
             harmonics = 0.3, timbre = 0.4, morph = 0.25, reverb = 0.3, level = 0.4,
             filter = { mode = 1, cutoff = 3600, resonance = 1 } },
    -- citypop's glossy synth lead: a square with a slow vibrato and a little glide
    citySynth = { pool = true, wave = 'SQUARE', adsr = { 6, 160, 6, 180 }, reverb = 0.3, level = 0.35, glide = 18,
                  filter = { mode = 1, cutoff = 3400, resonance = 0 }, lfo = { { 0, 5.2, 0.08 } } },
    -- the strum style's clean electric guitar, on the neck pickup: the guitar engine warm (timbre low;
    -- the pedalboard's 0.85 is a bright jangly pick, harpsichord-like here), less banjo in the body, a
    -- thick fundamental and a soft pick (modes: string weight, click), rolled off at 2.4 kHz, a little
    -- tube drive, a slow tremolo (a volume LFO), plenty of reverb, and its own tape (wow, flutter,
    -- saturation, warble) and flanger (rate, depth, feedback, mix) pedals, which the music turns while
    -- a song plays (synth.slotTape, synth.slotFlanger). A fixed slot: its pedals take an FX bus.
    guitar = { slot = 47, wave = 'GUITAR', adsr = { 2, 0, 7, 1600 }, harmonics = 0.4, timbre = 0.3, morph = 0.12,
               modes = { [0] = 0.7, [1] = 0.15 }, filter = { mode = 1, cutoff = 2400, resonance = 1 },
               reverb = 0.45, level = 0.45, drive = 0.22, driveMode = 0,
               tape = { wow = 0.25, flutter = 0.08, saturation = 0.25, warble = 0.1 },
               flanger = { 0.25, 0.5, 0.5, 0.35 },
               lfo = { { 2, 4.2, 0.18 } } },
    ride  = { slot = 23, wave = 'SQUARE', adsr = { 1, 260, 0, 160 }, reverb = 0.2, level = 0.7,
              filter = { mode = 2, cutoff = 5400, resonance = 3 } },
    hat   = { slot = 24, wave = 'NOISE', adsr = { 0, 30, 0, 14 }, reverb = 0.1, level = 0.06,
              filter = { mode = 2, cutoff = 8200, resonance = 3 } },
    brush = { slot = 25, wave = 'NOISE', adsr = { 60, 300, 2, 200 }, reverb = 0.15, level = 0.2,
              filter = { mode = 2, cutoff = 4800, resonance = 1 } },
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
void instrument_autopan(int slot, float rate, float depth, int shape);
void instrument_phaser(int slot, float rate, float depth, float feedback, float mix, int stages);
void instrument_lfo(int slot, int which, int dest, float rate_hz, float depth);
void instrument_chorus(int slot, float rate, float depth, float mix);
void instrument_flanger(int slot, float rate, float depth, float feedback, float mix);
void instrument_drive(int slot, float x);
void instrument_drive_mode(int slot, int mode);
double audio_time(void);
void schedule_at(double t, int midi, int instr, int vol, int dur_ms);
int  note_on(int midi, int instr, int vol);
void note_off(int handle);
void note_pitch(int handle, float midi);
void note_vol(int handle, float vol);
void note_pos(int handle, float x, float y);
void note_timbre(int handle, float x);
void note_harmonics(int handle, float x);
void instrument_sample(int slot, int sample_slot, int root_midi);
void instrument_sample_region(int slot, float start, float end);
void instrument_sample_mode(int slot, int mode);
void sample_load(int slot, const float *data, int n);
void sample_shift(int slot, float semitones);
void sample_formant(int slot, float semitones);
]]
-- At load, so a hot reload can add functions. Redeclaring an identical function is allowed.
if ffi then pcall(ffi.cdef, CDEF) end

-- Lives on `state` so a lurker hot-swap of this file doesn't load the library or start the thread twice.
state.synth = state.synth or { started = false, failed = nil, C = nil, thread = nil, quit = nil }
local S = state.synth

local function definePatch(slot, patch)
    local a, d, s, r = unpack(patch.adsr)
    S.C.instrument(slot, lib.INSTR[patch.wave], a, d, s, r)
    S.C.instrument_harmonics(slot, patch.harmonics or 0)
    S.C.instrument_timbre(slot, patch.timbre or 0)
    S.C.instrument_morph(slot, patch.morph or 0)
    S.C.instrument_level(slot, lib.volume * (patch.level or 1))
    S.C.instrument_reverb(slot, patch.reverb or 0)
    if patch.pool then -- a pool slot may still hold the last patch's modes and LFOs
        for idx = 0, 2 do S.C.instrument_mode(slot, idx, patch.modes and patch.modes[idx] or 0) end
        for i = 0, 2 do S.C.instrument_lfo(slot, i, 0, 0, 0) end
    else
        for idx, value in pairs(patch.modes or {}) do S.C.instrument_mode(slot, idx, value) end
    end
    local filter = patch.filter or { mode = 0, cutoff = 0, resonance = 0 }
    S.C.instrument_filter(slot, filter.mode, filter.cutoff, filter.resonance)
    S.C.instrument_glide(slot, patch.glide or 0)
    for i, lfo in ipairs(patch.lfo or {}) do S.C.instrument_lfo(slot, i - 1, lfo[1], lfo[2], lfo[3]) end
    if patch.pool then return end -- inserts take an FX bus for good: never on a pool slot
    if patch.tape then
        S.C.instrument_tape(slot, patch.tape.wow, patch.tape.flutter, patch.tape.saturation)
        S.C.instrument_tape_warble(slot, patch.tape.warble or 0)
    end
    if patch.autopan then S.C.instrument_autopan(slot, patch.autopan.rate, patch.autopan.depth, 0) end
    if patch.drive then
        S.C.instrument_drive_mode(slot, patch.driveMode or 0)
        S.C.instrument_drive(slot, patch.drive)
    end
    if patch.chorus then S.C.instrument_chorus(slot, patch.chorus[1], patch.chorus[2], patch.chorus[3]) end
    if patch.flanger then
        local f = patch.flanger
        S.C.instrument_flanger(slot, f[1], f[2], f[3], f[4])
    end
    if patch.phaser then
        local ph = patch.phaser
        S.C.instrument_phaser(slot, ph.rate, ph.depth, ph.feedback, ph.mix, 6)
    end
end

local function definePatches()
    S.C.reverb(lib.reverbSize, lib.reverbDamping)
    for _, patch in pairs(lib.patches) do
        if patch.slot then definePatch(patch.slot, patch) end
    end
    S.pool = {} -- the pool slots load their patches on first use
end

-- The engine has 48 instrument slots (SOUND_INSTR_SLOTS) and every one was taken. Patches that only
-- one music style plays are `pool = true`: they share these slots, and a pool slot takes a patch the
-- first time a note needs it, from a slot whose notes have all ended (one style plays at a time, so
-- that's the last style's). S.pool[slot] = { name, ends = audio time its last note is done }.
lib.poolSlots = { 8, 18, 21, 28, 30, 32, 45, 46 } -- 8 was the slide whistle's (gone 2026-10-30)

local function slotOf(name, patch, t, durMs)
    if patch.slot then return patch.slot end
    S.pool = S.pool or {}
    local ends = t + (durMs + patch.adsr[4]) / 1000
    local pick, oldest
    for _, slot in ipairs(lib.poolSlots) do
        local resident = S.pool[slot]
        if resident and resident.name == name then
            resident.ends = math.max(resident.ends, ends)
            return slot
        end
        if not resident then pick = pick or slot
        elseif not oldest or resident.ends < S.pool[oldest].ends then oldest = slot end
    end
    -- a free slot, else the one that went quiet longest ago (cut short only if every one still sounds)
    pick = pick or oldest
    definePatch(pick, patch)
    S.pool[pick] = { name = name, ends = ends }
    return pick
end

-- Loads the library and starts the render thread once; returns whether the synth is usable.
-- The CDEF functions a library doesn't have. One built before synth.lua declared a new function
-- would otherwise fail inside definePatches (dlsym: symbol not found) on the first sound.
function lib.missingFunctions(C)
    local missing = {}
    for name in CDEF:gmatch('([%w_]+)%(') do
        if not pcall(function() return C[name] end) then missing[#missing + 1] = name end
    end
    return missing
end

-- webtest/build-web.sh puts this in the .love only when it built desound.wasm for the page.
lib.webSynthMarker = 'native/desound/web-synth'

function lib.start()
    if S.started then return true end
    if S.failed then return false end
    if IS_WEB then
        if not love.filesystem.getInfo(lib.webSynthMarker) then
            S.failed = 'this web build has no desound.wasm (needs emcc and dreamengine at build time)'
            print('[synth] ' .. S.failed)
            return false
        end
        S.C = require('src.synth-web') -- here, not on top: only the web build has it
        S.C.spatial_speed(0)
        definePatches()
        S.started = true
        return true
    end
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
    local missing = lib.missingFunctions(C)
    if #missing > 0 then
        S.failed = lib.libPath .. ' is older than src/synth.lua, it lacks ' .. table.concat(missing, ', ')
            .. ' (rerun native/desound/build.sh)'
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

function lib.stop()
    if not (S.started and S.thread) then return end
    S.quit:push(true)
    S.thread:wait()
    S.started = false
end

-- Dropouts: the render thread came round too late, the queue ran dry and the sound broke
-- up (a pop). The thread reports each one ('synth-dropouts'); here each gets what the game
-- was doing then: window in front or not, this frame's time and the worst of the last
-- second, and (at most every 5 s) the busiest processes on the machine. Newest last on
-- state.synth.dropouts, one console line each; synth.audioReport() sums them up.
lib.dropoutsKept = 50

-- 'love', 'Google Chrome', 'node drag-check.js': an app's name, else the program's, with
-- the script it runs when it runs one
local function processName(args)
    local app = args:match('([^/]+)%.app/')
    if app then return app end
    local program = (args:match('^(%S+)') or args):match('[^/]+$')
    local script = args:match('([^/%s]+%.js)%f[%s%z]') or args:match('([^/%s]+%.py)%f[%s%z]')
        or args:match('([^/%s]+%.lua)%f[%s%z]')
    return script and (program .. ' ' .. script) or program
end
lib.processName = processName

local function busyProcesses()
    if not io.popen then return nil end
    -- LC_ALL=C: with a Dutch locale ps writes 94,8
    local ok, pipe = pcall(io.popen, 'LC_ALL=C ps -Ao pcpu=,args= -r 2>/dev/null | head -4')
    if not (ok and pipe) then return nil end
    local list = {}
    for line in pipe:lines() do
        local cpu, args = line:match('^%s*([%d%.]+)%s+(.+)$')
        if cpu then
            list[#list + 1] = string.format('%s %d%%', processName(args), math.floor(tonumber(cpu) + 0.5))
        end
    end
    pipe:close()
    return table.concat(list, ', ')
end

local function noteFrame(dt)
    S.frames = S.frames or {}
    S.frameIndex = (S.frameIndex or 0) % 60 + 1
    S.frames[S.frameIndex] = dt
end

local function worstFrameMs()
    local worst = 0
    for _, dt in ipairs(S.frames or {}) do worst = math.max(worst, dt) end
    return worst * 1000
end

local function collectDropouts(dt)
    local channel = love.thread.getChannel('synth-dropouts')
    local event = channel:pop()
    while event do
        local now = love.timer.getTime()
        local busy
        if not S.lastBusyAt or now - S.lastBusyAt > 5 then
            busy = busyProcesses()
            S.lastBusyAt = now
        end
        local focused = love.window and love.window.hasFocus and love.window.hasFocus()
        local dropout = {
            at = event.at, gapMs = event.gapMs, stopped = event.stopped, focused = focused,
            frameMs = dt * 1000, worstFrameMs = worstFrameMs(), busy = busy,
        }
        S.dropouts = S.dropouts or {}
        table.insert(S.dropouts, dropout)
        if #S.dropouts > lib.dropoutsKept then table.remove(S.dropouts, 1) end
        S.dropoutCount = (S.dropoutCount or 0) + 1
        print(string.format('[synth] dropout: render thread away %d ms%s; window %s, frame %d ms (worst %d)%s',
            dropout.gapMs, dropout.stopped and ', sound stopped' or '',
            focused and 'in front' or 'in the background', dropout.frameMs, dropout.worstFrameMs,
            busy and ('; busy: ' .. busy) or ''))
        event = channel:pop()
    end
end

-- What the dropouts look like: counts, the queue's margin, the last few with their context.
-- From the bridge: require('src.synth').audioReport(); from the shell: ./playtime.sh audio
function lib.audioReport()
    if not S.started then return 'synth not running' .. (S.failed and (': ' .. S.failed) or '') end
    if not S.thread then return 'no render thread (web: the page has its own worklet)' end
    local stats = love.thread.getChannel('synth-stats'):peek() or {}
    local now = love.timer.getTime()
    local dropouts = S.dropouts or {}
    local lastMinute, background = 0, 0
    for _, d in ipairs(dropouts) do
        if now - d.at < 60 then lastMinute = lastMinute + 1 end
        if not d.focused then background = background + 1 end
    end
    local lines = {
        string.format('dropouts: %d since the synth started, %d in the last minute; '
            .. '%d of the last %d with the window in the background',
            S.dropoutCount or 0, lastMinute, background, #dropouts),
        string.format('render thread, last second: longest gap %d ms (the queue holds %d ms; longer runs it dry)',
            stats.maxGapMs or 0, stats.queueMs or 0),
    }
    for i = math.max(1, #dropouts - 9), #dropouts do
        local d = dropouts[i]
        lines[#lines + 1] = string.format('  %ds ago: away %d ms%s, %s, frame %d ms (worst %d)%s',
            now - d.at, d.gapMs, d.stopped and ' (stopped)' or '', d.focused and 'in front' or 'background',
            d.frameMs, d.worstFrameMs, d.busy and (', busy: ' .. d.busy) or '')
    end
    return table.concat(lines, '\n')
end

-- Main thread, every frame: advances the engine clock, keeps the listener on the camera
-- and reports render-thread errors and dropouts.
function lib.update(dt, camera)
    if not S.started then return end
    if S.thread then
        noteFrame(dt)
        collectDropouts(dt)
    end
    S.C.de_lua_tick(dt)
    if camera then
        local cx, cy = camera:getTranslation()
        local halfWidth = camera:getContainerDimensions() / camera:getScale() / 2
        S.C.listener(cx, cy)
        S.C.spatial_model(halfWidth, halfWidth * 4, 1)
    end
    local err = S.thread and S.thread:getError()
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
    local slot = slotOf(patchName, patch, lib.audioTime() or 0, durMs)
    if x then
        S.C.hit_at(midi, slot, vol, durMs, x, y)
    else
        S.C.hit(midi, slot, vol, durMs)
    end
end

-- The engine's clock: seconds of sound actually played. Book notes against it with scheduleAt.
function lib.audioTime()
    return S.started and S.C.audio_time() or nil
end

-- A note at audio time t exactly (sample-accurate; book it at least a buffer ahead). Not placed in the world.
function lib.scheduleAt(patchName, t, midi, vol, durMs)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not patch then return end
    vol = math.max(0, math.min(7, math.floor(vol + 0.5)))
    S.C.schedule_at(t, midi, slotOf(patchName, patch, t, durMs), vol, math.max(1, math.floor(durMs)))
end

-- Ride a patch's lowpass live (the music's tone automation); the patch keeps its filter mode.
-- Turn a patch's flanger pedal now: rate 0.05..5 Hz, depth 0..1, feedback -0.95..0.95 (high = the jet,
-- below 0 = through-zero), mix 0..1 (0 = off). Fixed-slot patches only.
function lib.slotFlanger(patchName, rate, depth, feedback, mix)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not (patch and patch.slot) then return end
    S.C.instrument_flanger(patch.slot, rate, depth, feedback, mix)
end

-- Turn a patch's tape pedal now: wow, flutter, saturation, warble, each 0..1. Fixed-slot patches only.
function lib.slotTape(patchName, wow, flutter, saturation, warble)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not (patch and patch.slot) then return end
    S.C.instrument_tape(patch.slot, wow, flutter, saturation)
    S.C.instrument_tape_warble(patch.slot, warble)
end

function lib.slotFilter(patchName, cutoff)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not (patch and patch.filter) then return end
    local slot = patch.slot
    if not slot then -- a pool patch: only while it holds a slot
        for poolSlot, resident in pairs(S.pool or {}) do if resident.name == patchName then slot = poolSlot end end
        if not slot then return end
    end
    S.C.instrument_filter(slot, patch.filter.mode, math.floor(cutoff), patch.filter.resonance)
end

-- Held notes. noteOn returns a handle (nil when the synth isn't running); vol 0..7, fractions OK.
-- A handle whose voice was stolen just stops responding, so a stale one is harmless.
function lib.noteOn(patchName, midi, vol, x, y)
    if not S.started then return nil end
    local patch = lib.patches[patchName]
    if not patch then return nil end
    local handle = S.C.note_on(midi, slotOf(patchName, patch, lib.audioTime() or 0, 60000),
                               math.max(0, math.min(7, math.floor(vol + 0.5))))
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

-- Overall level (settings panel, music section): scales every patch's level.
function lib.setVolume(v)
    lib.volume = v
    S.volume = v
    if not S.started then return end
    for _, patch in pairs(lib.patches) do
        if patch.slot then S.C.instrument_level(patch.slot, v * (patch.level or 1)) end
    end
    for slot, resident in pairs(S.pool or {}) do
        S.C.instrument_level(slot, v * (lib.patches[resident.name].level or 1))
    end
end

-- A hot reload (lurker) of this file re-applies the patches, so saving a tweak is audible right away.
-- The volume set in settings lives on state, so it survives that.
lib.volume = S.volume or lib.volume
if S.started then definePatches() end

return lib
