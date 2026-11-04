// desound.c — dreamengine's synth (runtime/sound.h) as a plain C library for LuaJIT FFI.
//
// Built against an UNMODIFIED dreamengine checkout with -DDE_NO_RAYLIB (the build the
// iOS/AUv3 host uses: no audio device, the host pulls samples). See build.sh.
//
// Threading (the engine's own SPSC design): call the sound API (hit/instrument/...) and
// de_lua_tick from ONE thread (LÖVE's main thread); call de_lua_render* from ONE other
// thread (src/synth-thread.lua).
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include "raylib_compat.h"
#include "studio.h"
#include "sound.h"

#define DESOUND_API __attribute__((used, visibility("default")))

// studio.c provides rnd(); sound.h needs it for a few randomized voices.
DESOUND_API int rnd(int n) { return n > 0 ? rand() % n : 0; }

// studio.c provides printh() too; sound_tick() calls it for its warnings (a full FX-bus pool,
// a dropped request). Without it the symbol resolves to NULL under -undefined dynamic_lookup and
// the first warning segfaults the app (2026-10-28: an 8th tape insert). Print to stderr instead.
DESOUND_API void printh(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
}

// The engine's pool counters: requests that got nothing, so that effect is silently absent
// (sound_tick's warning says the same, but on stderr, which the .app only flushes at exit).
// 0 instrument FX bus, 1 reverb send-bus, 2 granular tank, 3 shimmer tank, 4 bowed body.
// For ./playtime.sh audio (SHARED-INSTRUMENTS I5b).
DESOUND_API int de_lua_pool_overflow(int which) {
    switch (which) {
    case 0: return fx_bus_overflow;
    case 1: return rvb_bus_overflow;
    case 2: return grain_overflow;
    case 3: return shim_overflow;
    case 4: return bow_body_overflow;
    }
    return 0;
}

// The engine's NoteOpts size, as this dreamengine declares it. src/synth.lua compares it with its own
// declaration: the engine reads the WHOLE struct, so a Lua NoteOpts smaller than the engine's would
// hand it whatever lies past the end (random detune, cut notes, stray curves, no error). The struct
// grew in place (dreamengine humanized-playing §8: 24 bytes, then 108), so a bigger Lua one is fine.
DESOUND_API int de_note_opts_size(void) { return (int)sizeof(NoteOpts); }

static int desound_ready = 0;

DESOUND_API int de_lua_init(void) {
    if (desound_ready) return 0;   // idempotent: lurker hot reload may call it again
    sound_synth_mode = true;       // no raylib stream; the host pulls with de_lua_render*
    sound_init();
    desound_ready = 1;
    return 1;
}

DESOUND_API void de_lua_tick(float dt) { sound_tick(dt); }

// Stereo interleaved floats, frames * 2 values.
DESOUND_API void de_lua_render(float *out, int frames) { sound_callback(out, (unsigned)frames); }

// Stereo interleaved int16, straight into a LÖVE SoundData's memory (no per-sample Lua).
DESOUND_API void de_lua_render_s16(int16_t *out, int frames) {
    static float scratch[4096 * 2];
    while (frames > 0) {
        int n = frames > 4096 ? 4096 : frames;
        sound_callback(scratch, (unsigned)n);
        for (int i = 0; i < n * 2; i++) {
            float s = scratch[i];
            s = s < -1.0f ? -1.0f : s > 1.0f ? 1.0f : s;
            out[i] = (int16_t)(s * 32767.0f);
        }
        out += n * 2;
        frames -= n;
    }
}
