#!/bin/sh
# Build libdesound.dylib (dreamengine's synth for LuaJIT FFI, see src/synth.lua).
# Needs a dreamengine checkout; override with DREAMENGINE=/path/to/dreamengine.
# The engine is used unmodified; rebuild after pulling dreamengine
# (runtime/sound_ctx.h is generated there, so pin to a known-good commit).
set -e
cd "$(dirname "$0")"
DREAMENGINE="${DREAMENGINE:-$HOME/Projects/dreamengine}"
R="$DREAMENGINE/runtime"
[ -f "$R/sound.h" ] || { echo "no dreamengine runtime at $R" >&2; exit 1; }
clang -std=gnu11 -O2 -DDE_NO_RAYLIB -I"$R" -dynamiclib desound.c ribbon.c place.c grid.c -o libdesound.dylib \
    -undefined dynamic_lookup
echo "built $(pwd)/libdesound.dylib from dreamengine $(git -C "$DREAMENGINE" rev-parse --short HEAD)"
