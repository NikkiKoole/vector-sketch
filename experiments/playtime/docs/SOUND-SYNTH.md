# Sound synth (dreamengine in Playtime)

Playtime uses the synth from the user's own engine, dreamengine (`git@github.com:NikkiKoole/dreamengine-studio.git`), unchanged. It's called from LuaJIT through FFI. The synth plays the impact plonks, the box drums, the snap clicks and the background music.

Ideas for the music: [MUSIC-IDEAS.md](MUSIC-IDEAS.md).

## Setting up on a new machine
1. Clone dreamengine to `~/Projects/dreamengine`, or anywhere else and set `DREAMENGINE=/path`.
2. Run `native/desound/build.sh` to make `native/desound/libdesound.dylib`. The dylib is gitignored, so every machine builds its own. Rebuild after pulling dreamengine. It was last built against dreamengine `9abe3f44`.
3. Without the dylib the app still runs. Every synth call does nothing, and `[synth] missing ...` is printed once.

## How it fits together
| File | What it does |
|---|---|
| `native/desound/desound.c` | A small C wrapper around dreamengine's `sound.h`, built with `-DDE_NO_RAYLIB` |
| `native/desound/synth-thread.lua` | A `love.thread` that renders audio into a QueueableSource (44.1 kHz stereo, 3 × 512 frames) |
| `src/synth.lua` | The FFI wrapper (cdef, patches, API) |
| `src/mipo-voice.lua` | Impacts: plonks, the ball (upright pizz), boxes (conga/djembe/tabla per box). Starts the synth lazily. |
| `src/snap-sound.lua` | A tiny click when a snap joint forms |
| `src/slide-sound.lua` | The slide whistle, disabled (the user disliked it) |
| `src/music.lua` | Generative background music: bossa (or ballad) on the Rhodes |
| `claudetools/render-music.lua` | Renders the real `music.lua` + `synth.lua` offline to a WAV, no app needed |

The main thread calls the dreamengine API, which drops commands into a lock-free queue. The render thread calls `de_lua_render_s16`. This is still safe on iOS with the JIT off, because FFI keeps working there (link statically and use `ffi.C`).

## synth.lua API
- `start()`, `isRunning()`, `stop()`, and `update(dt, camera)` (moves the listener for stereo placement).
- `hit(patch, midi, vol, durMs, x, y)` plays a one-shot note at a world position.
- `noteOn(patch, midi, vol, x, y)` returns a handle; then `noteSet(handle, ...)` and `noteOff(handle)`.
- `audioTime()` and `scheduleAt(patch, t, midi, vol, durMs)` book sample-accurate notes. The music uses these.
- Patches are named in `lib.patches`. Each has a slot, an instrument id (`lib.INSTR`), adsr, three macros (harmonics/timbre/morph), and optionally level, reverb, filter, tape, autopan and phaser.

## Music, in short
- Chords: lofi.c's method, ported. Rootless four-note voicings, the one that moves least, no minor ninth inside.
- The chords are "played": the notes drift in one by one, and the Rhodes' left hand plays the bass.
- `music.bump()` on each impact raises a play level. When it gets high the drums join (kick, shaker, rim on the clave), and they leave again when play calms down.
- `music.chordNotes(lo, hi)` gives sound effects notes from the chord sounding right now, so impacts are in key.
- The settings are at the top of `src/music.lua`: style, rhythmSection, upright, melody, melodyPatch, and more.

## Gotchas
- **Keep the render thread outside `src/`.** Lurker would hot-swap it into the main thread, where `ffi.load` breaks.
- **A new FFI function must go in synth.lua's `CDEF`.** It's declared once at module load, so the next hot reload picks it up. Redeclaring an identical function is fine.
- **Module state goes on `state.synth` / `state.music` / `state.snapSound`.** A hot reload would wipe module-local state.
- **Measure loudness before choosing levels.** Render offline and compare peaks. One instrument (MODAL) came out 10× louder than the rest.
- **The user's taste so far:** likes the Rhodes, the drums, the membrane boxes and the click. Disliked the celesta, the slide whistle and (in the music) the upright.
