-- synth.lua
-- dreamengine's synth (native/desound, built with native/desound/build.sh) through LuaJIT FFI.
-- The main thread calls the sound API; native/desound/synth-thread.lua renders into a QueueableSource.
-- Without the library every call is a no-op and synth.start() returns false,
-- so callers keep their sample-based fallback.
-- In the browser (no FFI) src/synth-web.lua stands in for the library and the page plays it.

local IS_WEB = love ~= nil and love.system ~= nil and love.system.getOS() == 'Web'
local IS_IOS = love ~= nil and love.system ~= nil and love.system.getOS() == 'iOS'
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
    PLUCK = 16, MALLET = 17, FM = 18, ORGAN = 19, EPIANO = 20, MEMBRANE = 22, REED = 23, PIPE = 25,
    GUITAR = 26, PIANO = 27, BOWED = 28, BRASS = 29, SAMPLE = 30, MODAL = 31, METAL = 34, WAVESCAN = 36,
    SCRAPE = 39, -- scraped/rattled percussion from separate teeth: harmonics body, timbre rate, morph rattle
    SING = 38, -- one recorded syllable sung at any note by the same speaker (timbre = size, morph = speed)
}

-- Named patches in instrument slots 5..47 (pool = true / fx = true: no slot of their own, see
-- lib.poolSlots and lib.fxSlots): wave,
-- attack/decay ms, sustain 0..7, release ms, macros,
-- reverb send 0..1, level 0..1 (balances engines: some run much hotter), optional engine modes and filter,
-- analog 0..2 (dreamengine's instrument_analog: every voice a little different + a slow drift, an old
-- polysynth; on the saw / square synth patches, Nikki 2026-11-05: junoPad, strings, stab, citySynth, hPad),
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
    rhodes = { fx = true, wave = 'EPIANO', adsr = { 1, 0, 7, 450 },
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
    strings = { pool = true, wave = 'SAW', adsr = { 260, 0, 6, 260 }, reverb = 0.45, level = 0.22, analog = 1,
                filter = { mode = 1, cutoff = 2600, resonance = 0 }, lfo = { { 0, 5.0, 0.04 } } },
    -- other melody voices: the Rhodes a little brighter for a tune on top, and a kalimba: a
    -- mallet halfway between wood and bell
    rhodesLead = { fx = true, wave = 'EPIANO', adsr = { 1, 0, 7, 450 },
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
    piano = { fx = true, wave = 'PIANO', adsr = { 1, 0, 7, 1200 },
              harmonics = 0.08, timbre = 0.4, morph = 0.55, reverb = 0.3, level = 1.6,
              filter = { mode = 1, cutoff = 3400, resonance = 1 },
              tape = { wow = 0.15, flutter = 0.03, saturation = 0, warble = 0 } },
    pianoLead = { fx = true, wave = 'PIANO', adsr = { 1, 0, 7, 1200 },   -- the same piano, for the tune
                  harmonics = 0.08, timbre = 0.45, morph = 0.55, reverb = 0.3, level = 2.8,
                  filter = { mode = 1, cutoff = 4200, resonance = 1 },
                  tape = { wow = 0.15, flutter = 0.03, saturation = 0, warble = 0 } },
    -- the dusk style: the felt piano holding, darker and on a more worn cassette (it warbles now and then)
    feltKeys = { fx = true, wave = 'PIANO', adsr = { 1, 0, 7, 1400 },
                 harmonics = 0.08, timbre = 0.35, morph = 0.6, reverb = 0.35, level = 1.4,
                 filter = { mode = 1, cutoff = 2800, resonance = 1 },
                 tape = { wow = 0.3, flutter = 0.06, saturation = 0.15, warble = 0.15 } },
    -- dusk's tune: a tongue drum (a tuned drumhead, harmonics 0, struck between centre and edge: a
    -- pitched plonk)
    tongueDrum = { pool = true, wave = 'MEMBRANE', adsr = { 0, 900, 0, 400 },
                   harmonics = 0, timbre = 0.3, morph = 0.05, reverb = 0.35, level = 1.4 },
    -- the island style: a soft wooden marimba for the plinky riff (a mallet on a wooden bar,
    -- softer than the box 'wood' and ringing longer)
    marimba = { slot = 27, wave = 'MALLET', adsr = { 0, 500, 0, 250 },
                harmonics = 0.08, timbre = 0.35, morph = 0.35, reverb = 0.3, level = 1.0 },
    -- the dumont style: a soft synth stab (a lowpassed saw), a funk bass
    -- (a triangle, lowpassed with a bit of bite), a steel pan for the tune (a mallet toward the bell,
    -- ringing), and a drum machine clap (high-passed noise, a big room).
    -- No tape/autopan/phaser here: each of those takes one of the engine's 7 aux FX buses
    -- (SOUND_FX_BUSES); the patches with pedals share five of them through lib.fxSlots.
    stab = { pool = true, wave = 'SAW', adsr = { 3, 180, 2, 160 }, reverb = 0.35, level = 0.38, analog = 1,
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
                  analog = 1,
                  filter = { mode = 1, cutoff = 3400, resonance = 0 }, lfo = { { 0, 5.2, 0.08 } } },
    -- the strum style's clean electric guitar, on the neck pickup: the guitar engine warm (timbre low;
    -- the pedalboard's 0.85 is a bright jangly pick, harpsichord-like here), less banjo in the body, a
    -- thick fundamental and a soft pick (modes: string weight, click), rolled off at 2.4 kHz, a little
    -- tube drive, a slow tremolo (a volume LFO), plenty of reverb, and its own tape (wow, flutter,
    -- saturation, warble) and flanger (rate, depth, feedback, mix) pedals, which the music turns while
    -- a song plays (synth.slotTape, synth.slotFlanger). It shares the effect slots (fx = true).
    guitar = { fx = true, wave = 'GUITAR', adsr = { 2, 0, 7, 1600 }, harmonics = 0.4, timbre = 0.3, morph = 0.12,
               modes = { [0] = 0.7, [1] = 0.15 }, filter = { mode = 1, cutoff = 2400, resonance = 1 },
               reverb = 0.45, level = 0.45, drive = 0.22, driveMode = 0,
               tape = { wow = 0.25, flutter = 0.08, saturation = 0.25, warble = 0.1 },
               flanger = { 0.25, 0.5, 0.5, 0.35 },
               lfo = { { 2, 4.2, 0.18 } } },
    -- rollo's guitar: the same electric guitar, choked (a short release) and on a worn cassette
    jabGuitar = { fx = true, wave = 'GUITAR', adsr = { 1, 0, 7, 90 }, harmonics = 0.4, timbre = 0.35, morph = 0.12,
                  modes = { [0] = 0.7, [1] = 0.15 }, filter = { mode = 1, cutoff = 2800, resonance = 1 },
                  reverb = 0.3, level = 0.55, drive = 0.15, driveMode = 0,
                  tape = { wow = 0.3, flutter = 0.12, saturation = 0.35, warble = 0.15 } },
    -- rollo's flute: dreamengine's pipe.c 'flute' preset (overblow 0, air .38, embouchure .7), a 4.4 Hz
    -- vibrato as measured on the record, and the same cassette. Keep it at A5 or below (PIPE flips mode
    -- above, dreamengine STATUS #31)
    -- the bowed strings, arco (dreamengine's bowed.c presets: bow position, pressure, speed), each with
    -- its own body (modes: [MODE_BOW_PIZZ] 0 = bowed, [_BODY] 1, [_SIZE] violin .5 / viola .53 / cello .7086)
    -- legatoGlide (ms): in a legato line (a score style's style.legato) the note SLIDES from the one before
    -- instead of starting again (synth.scheduleAt's opts.glide, dreamengine-studio#47). Only the voices that
    -- can slide have it: a piano or a mallet would bend, which they can't.
    violin = { pool = true, wave = 'BOWED', adsr = { 40, 0, 7, 220 }, harmonics = 0.45, timbre = 0.30, morph = 0.70,
               reverb = 0.35, level = 1.0, modes = { [0] = 0, [1] = 1, [2] = 0.5 }, legatoGlide = 70 },
    viola = { pool = true, wave = 'BOWED', adsr = { 40, 0, 7, 240 }, harmonics = 0.50, timbre = 0.38, morph = 0.60,
              reverb = 0.35, level = 1.0, modes = { [0] = 0, [1] = 1, [2] = 0.53 }, legatoGlide = 70 },
    cello = { pool = true, wave = 'BOWED', adsr = { 50, 0, 7, 280 }, harmonics = 0.55, timbre = 0.42, morph = 0.55,
              reverb = 0.3, level = 1.0, modes = { [0] = 0, [1] = 1, [2] = 0.7086 }, legatoGlide = 80 },
    -- a clarinet: dreamengine's reed engine (reed.c's clarinet preset: a cylindrical bore, soft cane, dark)
    clarinet = { pool = true, wave = 'REED', adsr = { 8, 0, 6, 160 }, harmonics = 0, timbre = 0.30, morph = 0.40,
                 reverb = 0.3, level = 0.5, legatoGlide = 80 },
    -- a TB-303 (dreamengine's acid303.h, voiced stock, pre-Devil-Fish): a raw saw through the diode-ladder
    -- lowpass (FILTER_DIODE = 10; CUT .45 -> 390 Hz, RES .7 -> Q 10), every note kicking the filter
    -- envelope (ENV .6 x the sweep 1.66 -> ~3000 Hz over DEC .4 -> 230 ms), soft drive .35, and the slow
    -- analog drift (random-walk LFOs on pitch and cutoff). The SLIDE (a legato line glides in 60 ms, the
    -- stock 303's fixed slide, no new filter sweep) and the ACCENT (downbeatAccent: each bar's first note
    -- louder with a harder filter kick, acid303.h's accent) come from dreamengine-studio#47. MONO like the
    -- real one: a new note cuts the last, and of two notes booked at the same instant (a bass line's
    -- root + fifth) only the first plays (scheduleAt).
    tb303 = { fx = true, wave = 'SAW', adsr = { 2, 60, 6, 25 }, reverb = 0.1, level = 0.5,
              legatoGlide = 60, downbeatAccent = 0.7, mono = true, accentCutoff = 0.7,
              filter = { mode = 10, cutoff = 390, resonance = 10 }, env = { 0, 230, 2990 },
              drive = 0.35, driveMode = 0,
              lfo = { { 0, 0.13, 0.025, shape = 7 }, { 3, 0.19, 20, shape = 7 } } },
    flute = { fx = true, wave = 'PIPE', adsr = { 1, 0, 6, 140 }, harmonics = 0, timbre = 0.38, morph = 0.7,
              reverb = 0.4, level = 0.22, lfo = { { 0, 4.4, 0.08 } }, legatoGlide = 80,
              tape = { wow = 0.3, flutter = 0.12, saturation = 0.3, warble = 0.15 } },
    -- rollo's bass: a picked electric bass (the guitar model down low, dark, stopped after a beat)
    pickBass = { pool = true, wave = 'GUITAR', adsr = { 1, 0, 7, 160 }, harmonics = 0.3, timbre = 0.25, morph = 0.1,
                 filter = { mode = 1, cutoff = 900, resonance = 1 }, reverb = 0.1, level = 2.0 },
    -- jingle's guitar (dreamengine's jingle.c): the clean electric fingerpicked, soft (a gentle pick,
    -- darker), through a chorus with a slow 4.6 Hz pitch warble and a 3.9 Hz sway, on a cassette
    jingleGuitar = { fx = true, wave = 'GUITAR', adsr = { 2, 0, 7, 700 }, harmonics = 0.4, timbre = 0.25, morph = 0.1,
                     modes = { [0] = 0.7, [1] = 0.1 }, filter = { mode = 1, cutoff = 2000, resonance = 1 },
                     reverb = 0.4, level = 0.7, chorus = { 0.8, 0.5, 0.45 },
                     tape = { wow = 0.3, flutter = 0.08, saturation = 0.2, warble = 0.15 },
                     lfo = { { 0, 4.6, 0.08 }, { 2, 3.9, 0.06 } } },
    -- jingle's Juno chords (dreamengine's juno.c): a saw pad, slow in, through a warm resonant lowpass
    -- and the Juno's chorus I (slow and lush; the chorus is what makes it a Juno)
    junoPad = { fx = true, wave = 'SAW', adsr = { 24, 0, 6, 460 }, reverb = 0.35, level = 0.15, analog = 1,
                filter = { mode = 1, cutoff = 1400, resonance = 4 }, chorus = { 0.6, 0.45, 0.5 } },
    -- jingle's bass: a soft round sine, rolled off at 520 Hz
    jingleBass = { pool = true, wave = 'SINE', adsr = { 3, 280, 4, 110 }, reverb = 0.05, level = 0.22,
                   filter = { mode = 1, cutoff = 520, resonance = 0 } },
    -- jingle's tune: a soft singing sine with a 5.1 Hz vibrato
    jingleLead = { pool = true, wave = 'SINE', adsr = { 14, 200, 4, 240 }, reverb = 0.35, level = 0.25,
                   filter = { mode = 1, cutoff = 2300, resonance = 1 }, lfo = { { 0, 5.1, 0.12 } } },
    ride  = { slot = 23, wave = 'SQUARE', adsr = { 1, 260, 0, 160 }, reverb = 0.2, level = 0.7,
              filter = { mode = 2, cutoff = 5400, resonance = 3 } },
    hat   = { slot = 24, wave = 'NOISE', adsr = { 0, 30, 0, 14 }, reverb = 0.1, level = 0.06,
              filter = { mode = 2, cutoff = 8200, resonance = 3 } },
    brush = { slot = 25, wave = 'NOISE', adsr = { 60, 300, 2, 200 }, reverb = 0.15, level = 0.2,
              filter = { mode = 2, cutoff = 4800, resonance = 1 } },
    -- the parlour style (src/music-parlour.lua): dreamengine's humanizing engine, each instrument after its
    -- spike cart (tools/carts/pianohand, cellohand, breathflute, synthhand, drumhand). A ...Plain twin is
    -- the same sound with the engine's defaults back (its own vibrato, no analog cards), for the A/B.
    -- The piano: the release is the felt's (each note's own release_ms; the pedal lane holds the rest)
    hPiano = { pool = true, wave = 'PIANO', adsr = { 1, 0, 7, 900 }, harmonics = 0.08, timbre = 0.44,
               morph = 0.6, reverb = 0.3, level = 1.9, releaseShape = 'damper',
               filter = { mode = 1, cutoff = 3600, resonance = 1 } },
    -- cellohand's cello: bowed.c's preset on a cello-sized body; vibrato 0: each note carries its own
    hCello = { pool = true, wave = 'BOWED', adsr = { 60, 0, 7, 240 }, harmonics = 0.55, timbre = 0.42, morph = 0.55,
               reverb = 0.32, level = 0.6, modes = { [0] = 0, [1] = 0.85, [2] = 0.7086 }, vibrato = 0,
               filter = { mode = 1, cutoff = 4200, resonance = 0 } },
    hCelloPlain = { pool = true, wave = 'BOWED', adsr = { 60, 0, 7, 240 }, harmonics = 0.55, timbre = 0.42,
                    morph = 0.55, reverb = 0.32, level = 0.6, modes = { [0] = 0, [1] = 0.85, [2] = 0.7086 },
                    filter = { mode = 1, cutoff = 4200, resonance = 0 } },
    -- breathflute's flute: the in-tune embouchure (morph 0.70), the engine's vibrato off
    hFlute = { pool = true, wave = 'PIPE', adsr = { 30, 0, 7, 110 }, harmonics = 0, timbre = 0.38, morph = 0.7,
               reverb = 0.38, level = 0.2, vibrato = 0 },
    hFlutePlain = { pool = true, wave = 'PIPE', adsr = { 30, 0, 7, 110 }, harmonics = 0, timbre = 0.38, morph = 0.7,
                    reverb = 0.38, level = 0.2 },
    -- synthhand's pad: saw through the ladder, its own filter at 900 Hz (the lane moves it in octaves),
    -- analog 1 = eight voice cards in rotation and a slow drift
    hPad = { pool = true, wave = 'SAW', adsr = { 380, 0, 6, 700 }, reverb = 0.4, level = 0.13, analog = 1,
             filter = { mode = 1, cutoff = 900, resonance = 3 } },
    hPadPlain = { pool = true, wave = 'SAW', adsr = { 380, 0, 6, 700 }, reverb = 0.4, level = 0.13,
                  filter = { mode = 1, cutoff = 900, resonance = 3 } },
    -- the upright style (src/music-upright.lua): basshand.c's upright, voiced as upright.c / rootwalk.c:
    -- pizzicato on the double-bass body, the FINGER pluck (mode 6), dark (350 Hz), mono like a walking
    -- line (a ghost on the same slot stops the ringing note, as the cart's choked ghost slot does)
    hUpright = { pool = true, wave = 'BOWED', adsr = { 4, 0, 7, 475 }, harmonics = 0.3, timbre = 0.3, morph = 0.45,
                 reverb = 0.22, level = 0.8, mono = true, vibrato = 0,
                 modes = { [0] = 1, [1] = 0.85, [2] = 1, [6] = 1 },
                 filter = { mode = 1, cutoff = 350, resonance = 3 } },
    -- and its THUMP: the finger and the body knocked, a short low membrane under every pluck (a real pizz is
    -- loud, then rings on ~15 dB down)
    hThump = { pool = true, wave = 'MEMBRANE', adsr = { 1, 0, 7, 300 }, harmonics = 0.8, timbre = 0.2, morph = 0.25,
               reverb = 0.3, level = 0.8, filter = { mode = 1, cutoff = 700, resonance = 1 } },
    -- the brew style (src/music-brew.lua), Mystic Brew's keys and guitar: Ronnie Foster's organ, the tonewheel
    -- engine fitted to the organ stem of Mystic Brew's chop (octave bands 125 Hz..8 kHz, centroid 531 Hz): the
    -- thin registration (0.1) through a 1.2 kHz lowpass lands at 526 Hz with the same 250 Hz..1 kHz shape (the
    -- registrations are snapped drawbar recipes: 0.3-0.6 have nothing over 1 kHz, 0.75 a hole at 500 Hz-1 kHz).
    -- Its held chords barely move (measured: pitch ~1.5 cents, level under 1 dB, a faint 6-7 Hz shimmer now and
    -- then): a little scanner chorus (morph) and the real Leslie (instrument_leslie) slow and low, chorale speed,
    -- little doppler, half mixed, for air rather than a sway. On an effect slot: the Leslie is an insert
    brewOrgan = { fx = true, wave = 'ORGAN', adsr = { 12, 0, 7, 220 }, harmonics = 0.1, timbre = 0.6, morph = 0.25,
                  reverb = 0.3, level = 0.3, filter = { mode = 1, cutoff = 1200, resonance = 0 },
                  leslie = { speed = 1, drive = 0.1, balance = 0.5, doppler = 0.2, mix = 0.5 } },
    -- and the pings over Electric Relaxation's intro, break and verses (likely Outside Love's, sped up with its
    -- drums): a pair of bells, ~150 ms rings, inharmonic (the mallet's bell material makes the overtones)
    brewBell = { pool = true, wave = 'MALLET', adsr = { 0, 160, 0, 80 }, harmonics = 0.85, timbre = 0.7, morph = 0.2,
                 reverb = 0.25, level = 0.3 },
    brewGuitar = { pool = true, wave = 'GUITAR', adsr = { 2, 0, 7, 900 }, harmonics = 0.4, timbre = 0.22, morph = 0.1,
                   modes = { [0] = 0.7, [1] = 0.12 }, filter = { mode = 1, cutoff = 1900, resonance = 0 },
                   reverb = 0.3, level = 0.66 },
    -- drumhand's hat: metal plates that RING (so the stroke's damp and the foot's level lane are heard)
    hHat = { pool = true, wave = 'METAL', adsr = { 0, 0, 7, 60 }, harmonics = 0.7, timbre = 0.85, morph = 0.85,
             reverb = 0.12, level = 0.12, modes = { [0] = 0.66, [1] = 0.2 },
             filter = { mode = 1, cutoff = 11000, resonance = 2 } },
}

-- The TR-808 (the drum jam's kit, docs/DRUM-JAM.md J4): dreamengine's runtime/tr808.h tr808_build, slot
-- for slot, at the cart's neutral knobs (the decays tr808_fire sets at knob 0.5: kick 391, open hat 403,
-- cymbal 642). src/drum-machines.lua fires them (a voice = a few hits on these). In slots 48-61, which
-- the engine has since dreamengine 9f2b18dd (128 slots); an older library ignores them (no sound).
-- The congas and claves are left out: the jam has no role for them. env.dest 1 = ENV_PITCH (a drop in
-- semitones), choke = the patch whose ringing note a hit on this one cuts (closed hat -> open hat).
do
    -- one level and reverb send for the whole kit, so its own balance stays the cart's; 0.4 (-8 dB) puts
    -- the jam at the level it had on the old drum patches (rendered Electro and Hip Hop, within 0.1 dB)
    local L, R = 0.4, 0.08
    local function p(slot, wave, adsr, filter, extra)
        local patch = { slot = slot, wave = wave, adsr = adsr, level = L, reverb = R, kit = 'tr808',
                        filter = filter and { mode = filter[1], cutoff = filter[2], resonance = filter[3] } }
        for k, v in pairs(extra or {}) do patch[k] = v end
        return patch
    end
    local P = lib.patches
    P.tr808Kick = p(48, 'SINE', { 0, 391, 0, 60 }, { 1, 250, 3 },
                    { env = { 0, 50, 26, dest = 1 }, drive = 0.28, driveMode = 0 })
    P.tr808SnareBody = p(49, 'SINE', { 0, 100, 0, 30 }, { 1, 1200, 1 }, { env = { 0, 20, 3, dest = 1 } })
    P.tr808Snappy = p(50, 'NOISE', { 0, 130, 0, 40 }, { 1, 7500, 4 })
    P.tr808Tom = p(51, 'SINE', { 0, 260, 0, 50 }, nil, { env = { 0, 80, 6, dest = 1 } })
    P.tr808TomThud = p(52, 'NOISE', { 0, 28, 0, 12 }, { 3, 900, 2 })
    P.tr808Rim = p(53, 'TRI', { 0, 18, 0, 8 }, { 2, 500, 3 })
    P.tr808Clap = p(54, 'NOISE', { 0, 110, 0, 50 }, { 3, 1100, 8 })
    P.tr808Maracas = p(55, 'NOISE', { 0, 24, 0, 10 }, { 3, 8500, 13 })
    P.tr808Cowbell = p(56, 'SQUARE', { 0, 250, 0, 60 }, { 3, 900, 6 })
    P.tr808Cymbal = p(57, 'SQUARE', { 0, 642, 0, 200 }, { 3, 5000, 9 })
    P.tr808CymbalMid = p(58, 'SQUARE', { 3, 420, 0, 120 }, { 3, 6200, 3 })
    P.tr808CymbalHigh = p(59, 'SQUARE', { 2, 150, 0, 50 }, { 3, 7100, 3 })
    P.tr808HatOpen = p(60, 'NOISE', { 0, 403, 0, 90 }, { 3, 6600, 14 })
    P.tr808HatClosed = p(61, 'NOISE', { 0, 42, 0, 16 }, { 3, 8800, 14 }, { choke = 'tr808HatOpen' })
end

-- the drum jam's chord pad (music-jam's 'pad' figure): the Rhodes, held for most of a bar. The shared
-- 'rhodes' (bossa's comping) has a 4 Hz auto-pan, a phaser and tape wow; on a chord held that long they
-- wobbled into a wah-wah "tooter" (Nikki, 2026-11-04). This one is still: a little mellower, rolled off,
-- a slow drift of pan as the only movement (an LFO: no FX bus), its own slot. It fades a bit quicker than
-- the engine's own Rhodes decay (decay 2 s to sustain 1; liked). The flat "toot" that seemed to need the
-- fade was a dropped define, a default square wave (definePatches, below).
lib.patches.jamPad = { slot = 62, wave = 'EPIANO', adsr = { 1, 2000, 1, 600 },
                       harmonics = 0.12, timbre = 0.22, morph = 0.12, reverb = 0.4, level = 0.35,
                       filter = { mode = 1, cutoff = 2400, resonance = 0 }, lfo = { { 7, 0.15, 0.2 } } }

-- The TR-909 (the drum jam's other kit, DRUM-JAM.md J4): dreamengine's runtime/tr909.h tr909_build at the
-- cart's neutral knobs (tune / decay / colour 0.5) and the metal filter's default XY (cut .40, res .33:
-- the lowpasses x0.86, resonance 4), its voices in src/drum-machines.lua. tr909_fire re-sets the kick's,
-- toms', hats' and crash's slot decay per hit; the jam books ahead, so those are the neutral-knob decays
-- here, and each tom has its own slot (the cart shares one). The ride is left out (the jam has no ride
-- role). Slots 63-76. hats + crash: the METAL engine, modes [0] decay, [1] spread.
do
    local L, R = 0.4, 0.08 -- as the 808: one level for the kit, set against the old drums by render
    local function p(slot, wave, adsr, filter, extra)
        local patch = { slot = slot, wave = wave, adsr = adsr, level = L, reverb = R, kit = 'tr909',
                        filter = filter and { mode = filter[1], cutoff = filter[2], resonance = filter[3] } }
        for k, v in pairs(extra or {}) do patch[k] = v end
        return patch
    end
    local P = lib.patches
    P.tr909Kick = p(63, 'SINE', { 0, 174, 0, 50 }, { 1, 380, 2 },
                    { env = { 0, 35, 30, dest = 1 }, drive = 0.22, driveMode = 0 })
    P.tr909KickClick = p(64, 'NOISE', { 0, 9, 0, 4 }, { 2, 2500, 2 })
    P.tr909SnareBody = p(65, 'SINE', { 0, 90, 0, 25 }, { 1, 1400, 1 }, { env = { 0, 15, 4, dest = 1 } })
    P.tr909Snappy = p(66, 'NOISE', { 0, 170, 0, 50 }, { 1, 8500, 4 })
    P.tr909TomLow = p(67, 'SINE', { 0, 251, 0, 45 }, nil, { env = { 0, 60, 7, dest = 1 } })
    P.tr909TomMid = p(68, 'SINE', { 0, 150, 0, 45 }, nil, { env = { 0, 60, 7, dest = 1 } })
    P.tr909TomHigh = p(69, 'SINE', { 0, 177, 0, 45 }, nil, { env = { 0, 60, 7, dest = 1 } })
    P.tr909TomClick = p(70, 'NOISE', { 0, 12, 0, 5 }, { 3, 2000, 3 })
    P.tr909Rim = p(71, 'TRI', { 0, 28, 0, 10 }, { 2, 150, 2 })
    P.tr909Clap = p(72, 'NOISE', { 0, 100, 0, 45 }, { 3, 1200, 5 })
    local hat = { harmonics = 0.7, timbre = 0.85, morph = 0.85 }
    P.tr909HatClosed = p(73, 'METAL', { 0, 98, 0, 16 }, { 1, 12470, 4 },
                         { harmonics = hat.harmonics, timbre = hat.timbre, morph = hat.morph,
                           modes = { [0] = 0.40, [1] = 0.20 }, choke = 'tr909HatOpen' })
    P.tr909HatOpen = p(74, 'METAL', { 0, 232, 0, 110 }, { 1, 12470, 4 },
                       { harmonics = hat.harmonics, timbre = hat.timbre, morph = hat.morph,
                         modes = { [0] = 0.66, [1] = 0.20 } })
    P.tr909Crash = p(75, 'METAL', { 0, 807, 0, 280 }, { 1, 9460, 4 },
                     { harmonics = 0.55, timbre = 0.30, morph = 0.30, modes = { [0] = 0.80, [1] = 0.15 } })
    P.tr909CrashNoise = p(76, 'NOISE', { 0, 807, 0, 320 }, { 1, 8600, 4 })
end

-- The drum jam's funk guitar (music-jam's 'funk guitar' chord figure), after dreamengine's wahhand cart:
-- a guitar as its STRINGS, each a mono slot (a string rings once: strike it again and the old note stops,
-- so a scratch cuts the stab ringing on it). One slot per string, not one per string per filter type: each
-- stroke picks its own filter (NoteOpts.filter, synth.scheduleAt's opts.filter): scratches high-passed,
-- stabs band-passed, a held note low-passed, all around the slot's 1800 Hz; the wah foot rides the cutoff
-- lane. Four strings: the jam voices its chords in four. Slots 77-80. modes: [0] string weight, [1] click.
for i = 1, 4 do
    lib.patches['funkString' .. i] = { slot = 76 + i, wave = 'GUITAR', adsr = { 1, 0, 7, 260 },
        harmonics = 0.35, timbre = 0.70, morph = 0.10, modes = { [0] = 0.40, [1] = 0.45 }, mono = true,
        filter = { mode = 1, cutoff = 1800, resonance = 8 }, reverb = 0.10, level = 0.4 }
end

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
void instrument_env(int slot, int which, int dest, int attack_ms, int decay_ms, float amount);
void lfo_shape(int slot, int which, int shape);
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

-- dreamengine-studio#47 (engine b06a2a93, 2026-11-02): a booked note that SLIDES from the slot's
-- note still sounding (legato, no new attack), leans on an ACCENT, or carries its own macro values;
-- and the group bus, its reverb on the record, and stereo width (bound, not used yet: MUSIC-IDEAS).
-- OPTIONAL, unlike CDEF: a library built before them still starts (CDEF's check would refuse it), and
-- scheduleAt falls back to schedule_at, so the notes just attack again. Kept out of CDEF on purpose:
-- native/ios/device.sh links in every CDEF function with -u, which fails to link against an older
-- dreamengine; and the web build's synth-web.lua has no struct-passing bridge. So iOS and web play
-- without slides for now (S.hasNoteAt is false there). Since 2026-11-03 both get them when the engine has them:
-- device.sh and build-web.sh also take the CDEF_OPTIONAL functions runtime/sound.h defines, and the web
-- passes NoteOpts flat (schedule_note_at_flat, built into a struct by webtest/desound-processor.js).
-- Humanized playing (dreamengine humanized-playing.md §8, 2026-11-04): schedule_note_at returns a booking
-- id, note_event_at acts inside a booked note (a bow change), shape_define's curves ride on booked notes
-- (NoteOpts.shape), lane_at books a slot-wide curve (the sustain pedal, the hand on the filter), and a
-- slot's built-in vibrato, analog warmth and release shape. docs/guides/humanizing-sounds.md there.
local CDEF_OPTIONAL = [[
int  schedule_note_at(double t, int midi, int instr, int vol, int dur_ms, const NoteOpts *opts);
void note_event_at(int booking, double t, int event, float amount);
void shape_define(int id, int n, const float *t_ms, const float *v, int interp);
void lane_at(double t, int slot, int lane, float value, int ramp_ms);
void instrument_vibrato(int slot, float amount);
void instrument_analog(int slot, float amount);
void instrument_release_shape(int slot, int shape);
void instrument_accent(int slot, int route, float amount);
void stereo_width(float amount);
void instrument_stereo_width(int slot, float amount);
void instrument_group(int slot, int lead);
void reverb_bus_into(int tank, int lead);
void instrument_fx_filter(int slot, int mode, float cutoff_hz, float resonance);
void instrument_mono(int slot, int on);
void unschedule(int slot, double t1, double t2);
void instrument_choke(int slot_a, int slot_b);
void instrument_leslie(int slot, int speed, float drive, float balance, float doppler, float mix);
]]
-- The structs on their own: a hot reload redeclaring one errors, which must not stop the functions.
-- NoteOpts copied from dreamengine runtime/studio.h, FIELD ORDER AND ALL: the engine reads the whole of it,
-- so a smaller one here hands it what lies past the end (random detune, cut notes, stray curves, no error).
-- It grew in place (the first six fields first, 24 bytes, then 108, now 112 with filter), so an older
-- engine reading only the start is fine with this one. noteOptsFits() checks it against the library's own size.
-- LuaJIT keeps the first typedef for the whole run: a running game hot-reloading this keeps the old one.
if ffi then
    pcall(ffi.cdef, 'typedef struct { float cents, rate_hz; int delay_ms, fade_ms; float wander; } NoteVib;')
    pcall(ffi.cdef, 'typedef struct { unsigned char id, target; float scale, stretch; } NoteShape;')
    pcall(ffi.cdef, [[typedef struct { int glide_ms; float accent, harmonics, timbre, morph, gain;
                     float cents, cutoff_oct, damp; int release_ms; float region_start, region_end;
                     NoteVib vib; NoteShape shape[3]; int origin_ms; int filter; } NoteOpts;]])
    -- one function at a time: schedule_note_at's return changed (void -> int), and a running game
    -- redeclaring it differently errors, which mustn't keep the others undeclared
    for line in CDEF_OPTIONAL:gmatch('[^\n]+') do pcall(ffi.cdef, line) end
    -- Playtime's own (native/desound/desound.c), not the engine's: for audioReport and the NoteOpts check
    pcall(ffi.cdef, 'int de_lua_pool_overflow(int which);')
    pcall(ffi.cdef, 'int de_note_opts_size(void);')
end

-- Lives on `state` so a lurker hot-swap of this file doesn't load the library or start the thread twice.
state.synth = state.synth or { started = false, failed = nil, C = nil, thread = nil, quit = nil }
local S = state.synth

-- the engine's own mode values per slot (dreamengine sound.h's bank init): 0 and 1 the guitar/piano
-- string weight and click (off), 2..5 the piano's decay, knock, stretch and stiffness (0.5 = as
-- voiced), 6 the organ's leakage. A shared slot goes back to these before its next patch.
local MODE_DEFAULTS = { [0] = 0, 0, 0.5, 0.5, 0.5, 0.5, 0 }

-- The pedals a patch has right now, unscaled: from the patch when it loads, then whatever the music
-- turned (slotTape, slotFlanger). On state, so the settings panel and a hot reload see them.
S.pedals = S.pedals or {}
S.effectAmount = S.effectAmount or 1

local function pedalsFromPatch(patch)
    local p = {}
    local tape = patch.tape
    if tape then p.tape = { tape.wow, tape.flutter, tape.saturation, tape.warble or 0 } end
    if patch.autopan then p.autopan = { patch.autopan.rate, patch.autopan.depth } end
    if patch.drive then p.drive = { patch.driveMode or 0, patch.drive } end
    if patch.chorus then p.chorus = { patch.chorus[1], patch.chorus[2], patch.chorus[3] } end
    if patch.flanger then p.flanger = { patch.flanger[1], patch.flanger[2], patch.flanger[3], patch.flanger[4] } end
    if patch.phaser then
        p.phaser = { patch.phaser.rate, patch.phaser.depth, patch.phaser.feedback, patch.phaser.mix }
    end
    local les = patch.leslie
    if les then p.leslie = { les.speed or 1, les.drive or 0, les.balance or 0.5, les.doppler or 0.5, les.mix or 1 } end
    return p
end

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

-- Send a patch's pedals to its slot, every amount scaled by the effects slider (S.effectAmount:
-- 0 dry, 1 as designed, 2 extreme), kept inside the engine's ranges. Rates and modes don't scale.
-- At 1 these are exactly the patch's own values. `only` sends just that pedal.
local optionalFn -- defined below (CDEF_OPTIONAL's functions); the Leslie pedal looks itself up
local function sendPedals(slot, name, only)
    local p, a = S.pedals[name] or {}, S.effectAmount
    local function want(kind) return p[kind] and (not only or only == kind) end
    if want('tape') then
        local t = p.tape
        S.C.instrument_tape(slot, clamp(t[1] * a, 0, 1), clamp(t[2] * a, 0, 1), clamp(t[3] * a, 0, 1))
        S.C.instrument_tape_warble(slot, clamp(t[4] * a, 0, 1))
    end
    if want('autopan') then S.C.instrument_autopan(slot, p.autopan[1], clamp(p.autopan[2] * a, 0, 1), 0) end
    if want('drive') then
        S.C.instrument_drive_mode(slot, p.drive[1])
        S.C.instrument_drive(slot, clamp(p.drive[2] * a, 0, 1))
    end
    if want('chorus') then
        local c = p.chorus
        S.C.instrument_chorus(slot, c[1], clamp(c[2] * a, 0, 1), clamp(c[3] * a, 0, 1))
    end
    if want('flanger') then
        local f = p.flanger
        S.C.instrument_flanger(slot, f[1], clamp(f[2] * a, 0, 1), clamp(f[3] * a, -0.95, 0.95), clamp(f[4] * a, 0, 1))
    end
    if want('phaser') then
        local ph = p.phaser
        S.C.instrument_phaser(slot, ph[1], clamp(ph[2] * a, 0, 1), clamp(ph[3] * a, 0, 0.95), clamp(ph[4] * a, 0, 1), 6)
    end
    local leslie = want('leslie') and optionalFn('instrument_leslie')
    if leslie then -- the rotary cabinet at the chain's end: speed 0 stop, 1 chorale, 2 tremolo
        local l = p.leslie
        leslie(slot, l[1], clamp(l[2] * a, 0, 1), l[3], clamp(l[4] * a, 0, 1), clamp(l[5] * a, 0, 1))
    end
end

-- one of CDEF_OPTIONAL's functions in the loaded library, or nil (a library built before it). On the
-- web every call is written down for the page (src/synth-web.lua); the page skips one the wasm lacks
function optionalFn(name) -- (the local declared above sendPedals)
    if not ffi then return IS_WEB and S.C and S.C[name] or nil end
    local ok, f = pcall(function() return S.C[name] end)
    return ok and f or nil
end

-- the oscillator, its envelope and tone, level, reverb send; the modes (a shared slot gets all of
-- them and its LFOs off: it may still hold the last patch's), filter, glide
local function defineVoice(slot, patch)
    local a, d, s, r = unpack(patch.adsr)
    S.C.instrument(slot, lib.INSTR[patch.wave], a, d, s, r)
    S.C.instrument_harmonics(slot, patch.harmonics or 0)
    S.C.instrument_timbre(slot, patch.timbre or 0)
    S.C.instrument_morph(slot, patch.morph or 0)
    S.C.instrument_level(slot, lib.volume * (patch.level or 1))
    S.C.instrument_reverb(slot, patch.reverb or 0)
    if patch.pool or patch.fx then
        for idx = 0, 6 do S.C.instrument_mode(slot, idx, patch.modes and patch.modes[idx] or MODE_DEFAULTS[idx]) end
        for i = 0, 2 do S.C.instrument_lfo(slot, i, 0, 0, 0) end
    else
        for idx, value in pairs(patch.modes or {}) do S.C.instrument_mode(slot, idx, value) end
    end
    local filter = patch.filter or { mode = 0, cutoff = 0, resonance = 0 }
    S.C.instrument_filter(slot, filter.mode, filter.cutoff, filter.resonance)
    S.C.instrument_glide(slot, patch.glide or 0)
end

-- How it's played, set on every define so a shared slot's next patch is back at the engine's
-- defaults (each only with a library that has it):
-- mono = true: one voice, a new note cuts the one sounding (dreamengine's instrument_mono, cb82042a);
-- accentCutoff (octaves): an accented note opens the filter that much further (ACC_CUTOFF = 5);
-- vibrato = the built-in vibrato of PIPE/REED/BOWED/BRASS (1 as played, 0 off: a booked note's own
-- .vib instead), analog = 0..2 every voice a little different + a slow drift (an old polysynth),
-- releaseShape = 'linear' / 'exp' / 'damper' (a piano's felt)
local function definePlaying(slot, patch)
    local mono = optionalFn('instrument_mono')
    if mono then mono(slot, patch.mono and 1 or 0) end
    local accentRoute = optionalFn('instrument_accent')
    if accentRoute then accentRoute(slot, 5, patch.accentCutoff or 0) end
    local vibrato = optionalFn('instrument_vibrato')
    if vibrato then vibrato(slot, patch.vibrato or 1) end
    local analog = optionalFn('instrument_analog')
    if analog then analog(slot, patch.analog or 0) end
    local releaseShape = optionalFn('instrument_release_shape')
    if releaseShape then releaseShape(slot, lib.RELEASE[patch.releaseShape] or patch.releaseShape or 0) end
end

-- a shared slot's lanes (lane_at: the pedal, the filter hand...) back at rest for the next patch: the
-- last one may have left the damper down or the filter closed
local function restLanes(slot, patch)
    local lane = (patch.pool or patch.fx) and optionalFn('lane_at')
    if lane and S.C.audio_time then
        local now = S.C.audio_time()
        lane(now, slot, 0, 0, 0); lane(now, slot, 1, 0, 0); lane(now, slot, 2, 0, 0); lane(now, slot, 3, 1, 0)
    end
end

-- The LFOs, and env = { attack ms, decay ms, amount, dest = 0 }: an envelope kicked by every note,
-- on the filter (dest 0, ENV_CUTOFF, amount in Hz) or the pitch (dest 1, ENV_PITCH, semitones: a
-- drum's drop); a shared slot gets it switched off when its patch has none
local function defineModulation(slot, patch)
    for i, lfo in ipairs(patch.lfo or {}) do
        S.C.instrument_lfo(slot, i - 1, lfo[1], lfo[2], lfo[3])
        if lfo.shape or patch.pool or patch.fx then S.C.lfo_shape(slot, i - 1, lfo.shape or 0) end
    end
    if patch.env then S.C.instrument_env(slot, 0, patch.env.dest or 0, patch.env[1], patch.env[2], patch.env[3])
    elseif patch.pool or patch.fx then S.C.instrument_env(slot, 0, 0, 0, 0, 0) end
end

-- an effect slot: the last patch's pedals on its bus switched off
local function pedalsOff(slot)
    S.C.instrument_chorus(slot, 1.5, 0, 0)
    S.C.instrument_flanger(slot, 0.3, 0, 0, 0)
    S.C.instrument_phaser(slot, 0.8, 0, 0, 0, 6)
    S.C.instrument_autopan(slot, 1, 0, 0)
    S.C.instrument_tape(slot, 0, 0, 0)
    S.C.instrument_tape_warble(slot, 0)
    S.C.instrument_drive(slot, 0)
    local leslie = optionalFn('instrument_leslie')
    if leslie then leslie(slot, 1, 0, 0.5, 0, 0) end -- mix 0: bypassed
end

local function definePatch(slot, patch, name)
    defineVoice(slot, patch)
    definePlaying(slot, patch)
    restLanes(slot, patch)
    defineModulation(slot, patch)
    if patch.pool then return end -- inserts take an FX bus for good: never on a pool slot
    if patch.fx then pedalsOff(slot) end -- then put on these
    S.pedals[name] = pedalsFromPatch(patch) -- a load starts from the patch's own settings
    sendPedals(slot, name)
end

-- A slot-owning patch onto its slot, and its choke (another patch's name: a note on this one cuts that
-- one's ringing note, the 808's hats). Chokes are per slot, so the other needn't be defined yet.
local function defineOwnSlot(name)
    local patch = lib.patches[name]
    if not (patch and patch.slot) then return end
    definePatch(patch.slot, patch, name)
    local other = patch.choke and lib.patches[patch.choke]
    local choke = other and other.slot and optionalFn('instrument_choke')
    if choke then choke(patch.slot, other.slot) end
end

-- The engine's request queue holds 511 calls and DROPS the rest ("[sound] WARNING: request queue
-- overflow"); defining every patch at once is ~600 (2026-11-04, with the 808), and lib.start does it
-- before the render thread drains anything. A dropped define leaves its slot the engine's default, a
-- flat square wave: a "tooter" in whatever plays there. So the patches go in a few at a time (about
-- 150 calls), the rest from lib.update, a frame each; a note for one still waiting defines it first
-- (slotOf), which is also all the offline renderer needs (it never calls update).
local DEFINES_PER_STEP = 8
local function defineSome(n)
    local pending = S.pendingDefines
    while pending and #pending > 0 and n > 0 do
        local name = table.remove(pending, 1)
        S.pendingSet[name] = nil
        defineOwnSlot(name)
        n = n - 1
    end
end

local function definePatches()
    S.C.reverb(lib.reverbSize, lib.reverbDamping)
    local names = {}
    for name, patch in pairs(lib.patches) do
        if patch.slot then names[#names + 1] = name end
    end
    table.sort(names) -- the same order every run
    S.pendingDefines, S.pendingSet = names, {}
    for _, name in ipairs(names) do S.pendingSet[name] = true end
    defineSome(DEFINES_PER_STEP)
    S.pool, S.fx = {}, {} -- the shared slots load their patches on first use
end

-- The engine has 48 instrument slots (SOUND_INSTR_SLOTS) and every one was taken. Patches that only
-- one music style plays are `pool = true`: they share these slots, and a pool slot takes a patch the
-- first time a note needs it, from a slot whose notes have all ended (one style plays at a time, so
-- that's the last style's). S.pool[slot] = { name, ends = audio time its last note is done }.
lib.poolSlots = { 8, 18, 21, 28, 30, 32, 45, 46 } -- 8 was the slide whistle's (gone 2026-10-30)

-- The FX buses: 7 (SOUND_FX_BUSES), and a slot's first pedal claims one for good (the engine can't
-- give it back). So the patches with pedals (fx = true) share these effect slots the same way, each
-- slot keeping its bus: loading a patch switches the bus's pedals off and puts on the patch's own.
-- Any number of styles can have pedals, as long as no more than #lib.fxSlots of them sound at once.
lib.fxSlots = { 13, 19, 22, 26, 47 }

-- the shared slot a patch sits in now, taking one (free, or quiet longest) on its first note
local function claim(name, patch, t, durMs, slots, residents)
    local ends = t + (durMs + patch.adsr[4]) / 1000
    local pick, oldest
    for _, slot in ipairs(slots) do
        local resident = residents[slot]
        if resident and resident.name == name then
            resident.ends = math.max(resident.ends, ends)
            return slot
        end
        if not resident then pick = pick or slot
        elseif not oldest or resident.ends < residents[oldest].ends then oldest = slot end
    end
    -- a free slot, else the one that went quiet longest ago (cut short only if every one still sounds)
    pick = pick or oldest
    definePatch(pick, patch, name)
    residents[pick] = { name = name, ends = ends }
    return pick
end

local function slotOf(name, patch, t, durMs)
    if patch.slot then
        if S.pendingSet and S.pendingSet[name] then -- not defined yet (definePatches spreads them): now
            for i, pending in ipairs(S.pendingDefines) do
                if pending == name then table.remove(S.pendingDefines, i) break end
            end
            S.pendingSet[name] = nil
            defineOwnSlot(name)
        end
        return patch.slot
    end
    if patch.fx then
        S.fx = S.fx or {}
        return claim(name, patch, t, durMs, lib.fxSlots, S.fx)
    end
    S.pool = S.pool or {}
    return claim(name, patch, t, durMs, lib.poolSlots, S.pool)
end

-- the slot a shared patch holds right now (nil if it holds none)
local function residentSlot(name, patch)
    if patch.slot then return patch.slot end
    local residents
    if patch.fx then residents = S.fx else residents = S.pool end -- not and/or: S.fx may still be nil
    for slot, resident in pairs(residents or {}) do
        if resident.name == name then return slot end
    end
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
    local path, C -- path stays nil on iOS: the render thread then uses ffi.C too
    if IS_IOS then
        -- iOS loads no dylib of ours: native/ios/device.sh links the synth into the app
        -- (native/desound/build-ios.sh), so its functions are the app's own
        C = ffi.C
    else
        path = love.filesystem.getSource() .. '/' .. lib.libPath
        if not love.filesystem.getInfo(lib.libPath) then
            S.failed = 'missing ' .. lib.libPath .. ' (run native/desound/build.sh)'
            print('[synth] ' .. S.failed)
            return false
        end
        local ok, loaded = pcall(ffi.load, path)
        if not ok then
            S.failed = tostring(loaded)
            print('[synth] ' .. S.failed)
            return false
        end
        C = loaded
    end
    local missing = lib.missingFunctions(C)
    if #missing > 0 then
        S.failed = (IS_IOS and 'the app was built without the synth (native/ios/device.sh needs dreamengine)'
            or lib.libPath .. ' is older than src/synth.lua (rerun native/desound/build.sh)')
            .. ', it lacks ' .. table.concat(missing, ', ')
        print('[synth] ' .. S.failed)
        return false
    end
    S.C = C
    S.hasNoteAt = nil -- scheduleAt looks again (a rebuilt library may have the #47 functions now)
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
    -- effects the engine had no room for: that slot plays dry, with no other sign (SHARED-INSTRUMENTS I5b)
    local overflow = optionalFn('de_lua_pool_overflow')
    if overflow then
        local pools, full = { 'FX bus', 'reverb bus', 'granular tank', 'shimmer tank', 'bowed body' }, {}
        for i, what in ipairs(pools) do
            local n = overflow(i - 1)
            if n > 0 then full[#full + 1] = string.format('%s %d', what, n) end
        end
        lines[#lines + 1] = #full == 0 and 'effect pools: none ran out'
            or ('effect pools RAN OUT, so those effects are silently missing (requests refused): '
                .. table.concat(full, ', '))
    end
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
    -- the patches still waiting (definePatches), a batch only once the audio clock has moved since the last
    -- one: the render thread is draining the queue then (at startup it takes a while to begin, and slow
    -- first frames sent batch after batch into a queue nobody emptied: 33 calls dropped)
    if S.pendingDefines and #S.pendingDefines > 0 then
        local now = S.C.audio_time and S.C.audio_time() or 0
        if not S.definedAt or now > S.definedAt then
            defineSome(DEFINES_PER_STEP)
            S.definedAt = now
        end
    end
    S.C.de_lua_tick(dt)
    if S.fxHeld and #S.fxHeld > 0 then -- release the hits played as held notes (lib.hit, below full FX volume)
        local now = lib.audioTime() or 0
        for i = #S.fxHeld, 1, -1 do
            if now >= S.fxHeld[i].off then
                S.C.note_off(S.fxHeld[i].handle)
                table.remove(S.fxHeld, i)
            end
        end
    end
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
-- Hits are the WORLD's sounds (impacts, snap clicks), so they play at the FX volume (lib.fxVolume).
-- That can't live on the slot: an impact may borrow a band patch (mipo-voice MW7), whose slot the music
-- plays on at the same moment. So below full FX volume a hit is a held note at its own FRACTIONAL volume
-- (started at the nearest whole step, so the engine's quick slew to the exact value never softens the
-- attack), released by lib.update when its time is up. At full FX volume it is the plain hit, as before.
function lib.hit(patchName, midi, vol, durMs, x, y)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not patch then return end
    local fx = lib.fxVolume or 1
    if fx <= 0 then return end
    local slot = slotOf(patchName, patch, lib.audioTime() or 0, durMs)
    if fx < 0.999 then
        local exact = math.max(0, math.min(7, vol)) * fx
        local handle = S.C.note_on(midi, slot, math.floor(exact + 0.5))
        S.C.note_vol(handle, exact)
        if x then S.C.note_pos(handle, x, y) end
        S.fxHeld = S.fxHeld or {}
        S.fxHeld[#S.fxHeld + 1] = { handle = handle, off = (lib.audioTime() or 0) + durMs / 1000 }
        return
    end
    vol = math.max(0, math.min(7, math.floor(vol + 0.5)))
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

-- Names for the engine's numbers (#defines don't cross the FFI): dreamengine runtime/studio.h.
lib.SHP = { pitch = 1, gain = 2, harmonics = 3, timbre = 4, morph = 5, cutoff = 6 } -- a curve's target:
                                       -- cents, dB, macro offsets -1..1, octaves
lib.SHAPE = { linear = 0, ease = 1, fast = 2 }                      -- how a curve moves between its points
lib.LANE = { damper = 0, cutoff = 1, level = 2, vib = 3 }            -- 0..1 pedal, octaves, dB, vibrato scale
lib.NEV = { reartic = 1, damp = 2, release = 3 }                    -- events inside a booked note
lib.RELEASE = { linear = 0, exp = 1, damper = 2 }                   -- a patch's releaseShape

-- A note at audio time t exactly (sample-accurate; book it at least a buffer ahead). Not placed in the world.
-- opts (optional, dreamengine-studio#47): { glide = ms } SLIDES from this patch's note still sounding at
-- t instead of attacking (legato: the previous note must last past t; a phrase stays on one slot because
-- a patch keeps its slot while it sounds), { accent = 0..1 } leans on it (louder, a harder filter kick,
-- the engine's own "harder" macro), { harmonics/timbre/morph = -1..1 } shifts this note's macros.
-- Humanized playing (dreamengine humanized-playing.md §8; docs/guides/humanizing-sounds.md there):
--   cents       this note's pitch offset (±1200): a player a little sharp or flat
--   cutoff      its filter, octaves (±6)
--   damp        0..1 how fast its ring dies (1 = stopped at once: a closed hat, a ghost note)
--   release     its own release, ms (0 = the slot's)
--   regionStart, regionEnd   its sample chop (sample engines; 0, 0 = the slot's)
--   vib         its own vibrato { cents, rate (Hz, 0 = 5.5), delay (ms), fade (ms, blooming in), wander 0..1 }
--   shapes      up to 3 curves { id = a lib.defineShape id, target = 'pitch' / 'gain' / ... (lib.SHP),
--               scale (0 = 1), stretch (times, 0 = 1) }: a scoop, a swell, a phrase-end fade
--   origin      ms after note-on where the curves' time 0 is (the vowel after the consonant)
-- Returns the booking id (for lib.noteEvent) when the note went out with opts and the engine has events;
-- nil otherwise. A library without schedule_note_at plays the note plainly.
-- Music notes play at the MUSIC volume (lib.musicVolume) as each note's own gain (dreamengine 898a7aa4's
-- NoteOpts.gain), never as a slot level: an impact may borrow this patch's slot (see lib.hit).
-- Without schedule_note_at, or with a NoteOpts declared before gain existed (LuaJIT keeps the first
-- typedef across a hot reload, so a running game has the old one until restart), the 0..7 vol is
-- scaled instead: coarser, but never an error.
local function noteOptsHasGain()
    if IS_WEB then return true end -- the page writes the struct itself, gain included
    if S.noteGain == nil then S.noteGain = ffi ~= nil and pcall(ffi.offsetof, 'NoteOpts', 'gain') and
                                               ffi.offsetof('NoteOpts', 'gain') ~= nil or false end
    return S.noteGain
end

-- The humanizing fields (cents ... origin_ms) in the NoteOpts declared this run (not in a game that
-- hot-reloaded this file over the old 24-byte typedef).
local function noteOptsFull()
    if IS_WEB then return true end
    if S.noteFull == nil then S.noteFull = ffi ~= nil and pcall(ffi.offsetof, 'NoteOpts', 'origin_ms') and
                                               ffi.offsetof('NoteOpts', 'origin_ms') ~= nil or false end
    return S.noteFull
end

-- May NoteOpts go to this library at all? Its engine reads the whole struct: if the engine's is bigger
-- than ours, it'd read past our end. The library says its size (de_note_opts_size, native/desound/desound.c);
-- one built before that has the 24-byte engine, which our bigger struct (same start) suits. A mismatch
-- turns the extras off (plain schedule_at) and says so once, instead of playing garbage.
local function noteOptsFits()
    if IS_WEB or not ffi then return true end -- the page checks its wasm (webtest/desound-processor.js)
    if S.noteFits == nil then
        local sizeFn = optionalFn('de_note_opts_size')
        local engine, ours = sizeFn and sizeFn(), ffi.sizeof('NoteOpts')
        S.noteFits = not engine or engine <= ours
        if not S.noteFits then
            print(string.format('[synth] NoteOpts: the engine\'s is %d bytes, ours %d: booked extras off ' ..
                '(declare the engine\'s NoteOpts in src/synth.lua, see dreamengine runtime/studio.h)', engine, ours))
        end
    end
    return S.noteFits
end

local function shapeTarget(target)
    return lib.SHP[target] or tonumber(target) or 0
end

-- opts.filter: this note's own filter TYPE (dreamengine 409701fd), a name or the engine's FILTER_* number;
-- nil/0 = the slot's, 'off' = unfiltered (NOTE_FILTER_OFF)
local FILTER_TYPE = { off = -1, low = 1, high = 2, band = 3, notch = 4, ladder = 5, steiner = 6,
                      steiner_hp = 7, steiner_bp = 8, steiner_nf = 9, diode = 10 }
local function filterType(f)
    return FILTER_TYPE[f] or tonumber(f) or 0
end

-- filter in the NoteOpts declared this run (not in a game that hot-reloaded over the 108-byte typedef)
local function noteOptsHasFilter()
    if IS_WEB then return true end
    if S.noteFilter == nil then S.noteFilter = ffi ~= nil and pcall(ffi.offsetof, 'NoteOpts', 'filter') and
                                                   ffi.offsetof('NoteOpts', 'filter') ~= nil or false end
    return S.noteFilter
end

-- the humanizing fields, flat (the web sends them as text; the page builds the struct): 25 numbers
local function humanFields(opts)
    local v = opts.vib or {}
    local out = { opts.cents or 0, opts.cutoff or 0, opts.damp or 0, opts.release or 0,
                  opts.regionStart or 0, opts.regionEnd or 0,
                  v.cents or 0, v.rate or 0, v.delay or 0, v.fade or 0, v.wander or 0, opts.origin or 0 }
    for i = 1, 3 do
        local sh = opts.shapes and opts.shapes[i]
        out[#out + 1] = sh and sh.id or 0
        out[#out + 1] = sh and shapeTarget(sh.target) or 0
        out[#out + 1] = sh and sh.scale or 0
        out[#out + 1] = sh and sh.stretch or 0
    end
    out[#out + 1] = filterType(opts.filter)
    return out
end

local function noteOptsStruct(opts, gain)
    local o = ffi.new('NoteOpts')
    o.glide_ms, o.accent = opts.glide or 0, opts.accent or 0
    o.harmonics, o.timbre, o.morph = opts.harmonics or 0, opts.timbre or 0, opts.morph or 0
    if gain then o.gain = gain end
    if noteOptsFull() then
        o.cents, o.cutoff_oct, o.damp = opts.cents or 0, opts.cutoff or 0, opts.damp or 0
        o.release_ms = opts.release or 0
        o.region_start, o.region_end = opts.regionStart or 0, opts.regionEnd or 0
        local v = opts.vib
        if v then
            o.vib.cents, o.vib.rate_hz, o.vib.wander = v.cents or 0, v.rate or 0, v.wander or 0
            o.vib.delay_ms, o.vib.fade_ms = v.delay or 0, v.fade or 0
        end
        for i = 1, 3 do
            local sh = opts.shapes and opts.shapes[i]
            if sh then
                o.shape[i - 1].id, o.shape[i - 1].target = sh.id or 0, shapeTarget(sh.target)
                o.shape[i - 1].scale, o.shape[i - 1].stretch = sh.scale or 0, sh.stretch or 0
            end
        end
        o.origin_ms = opts.origin or 0
    end
    if opts.filter and noteOptsHasFilter() then o.filter = filterType(opts.filter) end
    return o
end

S.nextBooking = S.nextBooking or 0 -- the web's own booking numbers (the page maps them to the engine's)

-- A mono patch (one voice): of two notes at the same instant (root + fifth) the first one plays,
-- the other is dropped. 15 ms: the parts humanize each note's time on its own (a few ms), while the
-- fastest real line, 16ths, is ~100 ms apart.
local function monoDrops(patchName, patch, t)
    if not patch.mono then return false end
    S.monoAt = S.monoAt or {}
    local last = S.monoAt[patchName]
    if last and math.abs(t - last) < 0.015 then return true end
    S.monoAt[patchName] = t
    return false
end

-- the optional #47 functions (CDEF_OPTIONAL): looked up once, on first use (the offline renderer too)
local function lookUpNoteAt()
    local ok, f = pcall(function() return S.C.schedule_note_at end)
    S.hasNoteAt = (ffi ~= nil or IS_WEB) and ok and f ~= nil and noteOptsFits()
    S.hasEvents = optionalFn('note_event_at') ~= nil -- else schedule_note_at's return is no id (void before)
end

-- a note with NoteOpts (or its own gain): its booking id, when the engine gives them
local function scheduleWithOpts(t, midi, slot, vol, dur, opts, gain)
    if IS_WEB then -- no struct over the page's text bridge: the fields flat, the page builds the NoteOpts
        S.nextBooking = S.nextBooking % 1000000 + 1
        S.C.schedule_note_at_flat(t, midi, slot, vol, dur, opts.glide or 0, opts.accent or 0,
            opts.harmonics or 0, opts.timbre or 0, opts.morph or 0, gain or 0,
            S.nextBooking, unpack(humanFields(opts)))
        return S.nextBooking
    end
    local id = S.C.schedule_note_at(t, midi, slot, vol, dur, noteOptsStruct(opts, gain))
    return S.hasEvents and tonumber(id) and id > 0 and id or nil
end

function lib.scheduleAt(patchName, t, midi, vol, durMs, opts)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not patch then return end
    local music = lib.musicVolume or 1
    if music <= 0 then return end
    local gain = music < 0.999 and music or nil
    -- a note's own gain (opts.gain 0..1: a player's touch, finer than the 0..7 vol) times the music volume;
    -- the engine reads gain 0 as unset (full), so a tiny one stays a tiny one
    if opts and opts.gain then gain = math.max(0.001, math.min(1, (gain or 1) * opts.gain)) end
    vol = math.max(0, math.min(7, math.floor(vol + 0.5)))
    if monoDrops(patchName, patch, t) then return end
    local slot, dur = slotOf(patchName, patch, t, durMs), math.max(1, math.floor(durMs))
    if (opts or gain) and S.hasNoteAt == nil then lookUpNoteAt() end
    local exactGain = gain and S.hasNoteAt and noteOptsHasGain()
    if gain and not exactGain then -- no per-note gain here: scale the whole-step vol
        vol = math.floor(vol * gain + 0.5)
        if vol <= 0 then return end
    end
    if (opts or exactGain) and S.hasNoteAt then
        return scheduleWithOpts(t, midi, slot, vol, dur, opts or {}, exactGain and gain)
    end
    S.C.schedule_at(t, midi, slot, vol, dur)
end

-- Something inside a booked note at audio time t (booking = what scheduleAt returned): 'reartic' a bow
-- change or the wind's onset again (amount 0..1 = how slowly the bow turns), 'damp' its ring dies at
-- amount (0..1) from t, 'release' key up at t. False without the engine call.
function lib.noteEvent(booking, t, event, amount)
    if not (S.started and booking) then return false end
    local f = optionalFn('note_event_at')
    if not f then return false end
    f(booking, t, lib.NEV[event] or event, amount or 0)
    return true
end

-- A curve booked notes can carry (opts.shapes), defined ONCE at setup (never per frame): id 1..63,
-- up to 6 points, times in ms and values in the target's unit (cents, dB, ...), interp 'linear' /
-- 'ease' / 'fast'. Defining an id again replaces it. False without the engine call.
function lib.defineShape(id, times, values, interp)
    if not S.started then return false end
    local f = optionalFn('shape_define')
    if not f then return false end
    local n = math.min(6, #times, #values)
    local how = lib.SHAPE[interp] or interp or 0
    if IS_WEB then -- arrays don't cross the text bridge: the points flat, the page builds them
        local flat = {}
        for i = 1, n do flat[#flat + 1] = times[i] end
        for i = 1, n do flat[#flat + 1] = values[i] end
        f(id, n, how, unpack(flat))
        return true
    end
    local tArr, vArr = ffi.new('float[?]', n), ffi.new('float[?]', n)
    for i = 1, n do tArr[i - 1], vArr[i - 1] = times[i], values[i] end
    f(id, n, tArr, vArr, how)
    return true
end

-- A curve shared by every sounding note of a patch's slot, booked at audio time t: the lane ramps to
-- value over rampMs. 'damper' the sustain pedal (0 up .. 1 down), 'cutoff' the hand on the filter
-- (octaves), 'level' a swell (dB), 'vib' the notes' own vibrato scaled (the mod wheel). The slot the
-- patch holds now; unschedule takes its booked lane points back too. False without the engine call.
function lib.laneAt(patchName, t, lane, value, rampMs)
    if not S.started then return false end
    local patch = lib.patches[patchName]
    local slot = patch and residentSlot(patchName, patch)
    local f = slot and optionalFn('lane_at')
    if not f then return false end
    f(t, slot, lib.LANE[lane] or lane, value, math.floor(rampMs or 0))
    return true
end

-- Take back a patch's booked notes that start in [t1, t2) on the audio clock (scheduleAt's t; t2 nil = from
-- t1 on): a part resting while a stinger plays (docs/STINGERS.md). Notes already sounding ring on. The
-- slot is the one the patch holds now; a shared pool slot handed to another patch inside the window
-- loses that patch's notes too. Returns false without the engine call (an older library, the web).
function lib.unschedule(patchName, t1, t2)
    if not S.started then return false end
    local patch = lib.patches[patchName]
    local slot = patch and residentSlot(patchName, patch)
    local f = slot and optionalFn('unschedule')
    if not f then return false end
    f(slot, t1, t2 or 0)
    return true
end

-- Ride a patch's lowpass live (the music's tone automation); the patch keeps its filter mode.
-- Turn a patch's flanger pedal now: rate 0.05..5 Hz, depth 0..1, feedback -0.95..0.95 (high = the jet,
-- below 0 = through-zero), mix 0..1 (0 = off). Patches with pedals (fx) only, while they hold a slot.
function lib.slotFlanger(patchName, rate, depth, feedback, mix)
    if not S.started then return end
    local patch = lib.patches[patchName]
    local slot = patch and patch.fx and residentSlot(patchName, patch)
    if not slot then return end
    S.pedals[patchName] = S.pedals[patchName] or {}
    S.pedals[patchName].flanger = { rate, depth, feedback, mix }
    sendPedals(slot, patchName, 'flanger')
end

-- Turn a patch's tape pedal now: wow, flutter, saturation, warble, each 0..1. fx patches only.
function lib.slotTape(patchName, wow, flutter, saturation, warble)
    if not S.started then return end
    local patch = lib.patches[patchName]
    local slot = patch and patch.fx and residentSlot(patchName, patch)
    if not slot then return end
    S.pedals[patchName] = S.pedals[patchName] or {}
    S.pedals[patchName].tape = { wow, flutter, saturation, warble }
    sendPedals(slot, patchName, 'tape')
end

-- The effects slider: every pedal's amount times a (0 = dry, 1 = as designed, 2 = extreme), at once
-- on whatever holds a slot. The flanger's feedback stops at 0.95, where it resonates loudly.
function lib.setEffectAmount(a)
    S.effectAmount = math.max(0, math.min(2, a))
    if not S.started then return end
    for name, patch in pairs(lib.patches) do
        local slot = (patch.fx or patch.slot) and S.pedals[name] and residentSlot(name, patch)
        if slot then sendPedals(slot, name) end
    end
end
function lib.effectAmount() return S.effectAmount end

-- A patch's pedals as they sound now (scaled), for the settings panel: { kind = amount } where the
-- amount is the one the slider turns (tape wow, flanger mix, phaser mix, auto-pan depth, drive,
-- chorus mix); nil when it has none
function lib.pedalsOf(name)
    local p, a = S.pedals[name], S.effectAmount
    if not p or not next(p) then return nil end
    local out = {}
    if p.drive then out.drive = math.min(1, p.drive[2] * a) end
    if p.tape then out.tape = math.min(1, p.tape[1] * a) end
    if p.autopan then out.autopan = math.min(1, p.autopan[2] * a) end
    if p.chorus then out.chorus = math.min(1, p.chorus[3] * a) end
    if p.flanger then out.flanger = math.min(1, p.flanger[4] * a) end
    if p.phaser then out.phaser = math.min(1, p.phaser[4] * a) end
    return out
end

function lib.slotFilter(patchName, cutoff)
    if not S.started then return end
    local patch = lib.patches[patchName]
    if not (patch and patch.filter) then return end
    local slot = residentSlot(patchName, patch) -- a shared patch: only while it holds a slot
    if slot then S.C.instrument_filter(slot, patch.filter.mode, math.floor(cutoff), patch.filter.resonance) end
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
    for _, residents in ipairs({ S.pool or {}, S.fx or {} }) do
        for slot, resident in pairs(residents) do
            S.C.instrument_level(slot, v * (lib.patches[resident.name].level or 1))
        end
    end
end

-- FX volume (settings panel): the world's sounds, i.e. impacts and snap clicks through lib.hit, and the
-- Mipo voices (src/mipo-voice.lua reads it). Applied per hit, never per slot (see lib.hit).
function lib.setFxVolume(v)
    lib.fxVolume = v
    S.fxVolume = v
end

-- MUSIC volume (settings panel): every scheduleAt note (the parts, stingers, the jam's crash answer) and
-- the Mipo band's samples (src/mipo-band.lua reads it). Applied per note, never per slot (see scheduleAt).
function lib.setMusicVolume(v)
    lib.musicVolume = v
    S.musicVolume = v
end

-- A hot reload (lurker) of this file re-applies the patches, so saving a tweak is audible right away.
-- The volumes set in settings live on state, so they survive that.
lib.volume = S.volume or lib.volume
lib.fxVolume = S.fxVolume or 1
lib.musicVolume = S.musicVolume or 1
if S.started then definePatches() end

return lib
