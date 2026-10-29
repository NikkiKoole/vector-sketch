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
| `src/music.lua` | Generative background music, planned like dreamengine's lofi.c: a live set of bossa (Rhodes) and guaraldi (felt piano, brushes) songs, or one style |
| `claudetools/render-music.lua` | Renders the real `music.lua` + `synth.lua` offline to a WAV, no app needed |

The main thread calls the dreamengine API, which drops commands into a lock-free queue. The render thread calls `de_lua_render_s16`. This is still safe on iOS with the JIT off, because FFI keeps working there (link statically and use `ffi.C`).

## synth.lua API
- `start()`, `isRunning()`, `stop()`, and `update(dt, camera)` (moves the listener for stereo placement).
- `hit(patch, midi, vol, durMs, x, y)` plays a one-shot note at a world position.
- `noteOn(patch, midi, vol, x, y)` returns a handle; then `noteSet(handle, ...)` and `noteOff(handle)`.
- `audioTime()` and `scheduleAt(patch, t, midi, vol, durMs)` book sample-accurate notes. The music uses these.
- Patches are named in `lib.patches`. Each has a slot, an instrument id (`lib.INSTR`), adsr, three macros (harmonics/timbre/morph), and optionally level, reverb, filter, tape, autopan and phaser.

## Music, in short
- Chords: lofi.c's method, ported: the voicing that moves least, no minor ninth inside. Each style has its own chord vocabulary (`lib.qualities`): rootless jazz, plain sevenths, triads, or a stacked quartal shape.
- The chords are "played": the notes drift in one by one, and the Rhodes' left hand plays the bass.
- `music.bump()` on each impact raises a play level. When it gets high the drums join (where the song's form lets them), and they leave again when play calms down.
- `music.chordNotes(lo, hi)` gives sound effects notes from the chord sounding right now, so impacts are in key.
- The settings are at the top of `src/music.lua`: style ('set' or one style), set, rhythmSection, upright, melody, melodyPatch, and more. `music.nowPlaying()` says which style, key and section is playing.

## Gotchas
- **Keep the render thread outside `src/`.** Lurker would hot-swap it into the main thread, where `ffi.load` breaks.
- **A new FFI function must go in synth.lua's `CDEF`.** It's declared once at module load, so the next hot reload picks it up. Redeclaring an identical function is fine.
- **Module state goes on `state.synth` / `state.music` / `state.snapSound`.** A hot reload would wipe module-local state. Settings too: a hot reload (lume.hotswap) copies the new functions onto the old module table, but they keep reading the new chunk's own table. So a plain field the settings panel sets on the module is never seen, and a reload resets it. Music's switches (`style`, `enabled`, ...) live on `state.musicSettings` behind the module's metatable for that reason (2026-10-29: picking a style did nothing until the song ended).
- **Only 7 slots can have inserts (tape, autopan, phaser, chorus, echo, ...).** Each slot with one takes an aux FX bus (`SOUND_FX_BUSES` 8 = master + 7), never freed. 6 are used (rhodes, celesta, rhodesLead, piano, pianoLead, whistle). Past that the effect is silently absent and `sound_tick` prints a warning. Until 2026-10-28 that warning **segfaulted the app**: `printh` was unresolved in libdesound (NULL under `-undefined dynamic_lookup`). desound.c now defines it (stderr). Rebuild with `native/desound/build.sh` while the app is stopped.
- **An LFO is not an insert.** A patch's `lfo = { { dest, rate, depth } }` (tremolo, pan, pitch wow) takes no FX bus, so that's the way to add motion while the buses are full. `synth.slotFilter(patch, cutoff)` rides a patch's lowpass live; the lofi style's tone automation uses it.
- **Measure loudness before choosing levels.** Render offline and compare peaks. One instrument (MODAL) came out 10× louder than the rest.
- **The user's taste so far:** likes the Rhodes, the drums, the membrane boxes and the click. Disliked the celesta, the slide whistle and (in the music) the upright.
