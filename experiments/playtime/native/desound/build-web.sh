#!/bin/sh
# Build desound.wasm: dreamengine's synth for the browser build (webtest/build-web.sh runs this).
# The same desound.c as build.sh, as a standalone wasm the page's AudioWorklet runs
# (webtest/desound-processor.js); src/synth-web.lua sends it the calls. Needs emcc (brew install emscripten)
# and a dreamengine checkout; override with DREAMENGINE=/path/to/dreamengine.
set -e
cd "$(dirname "$0")"
DREAMENGINE="${DREAMENGINE:-$HOME/Projects/dreamengine}"
R="$DREAMENGINE/runtime"
[ -f "$R/sound.h" ] || { echo "no dreamengine runtime at $R" >&2; exit 1; }
OUT="${1:-desound.wasm}"
# The C functions src/synth.lua declares (its CDEF), plus the render call and malloc for the buffer.
FUNCS=$(sed -n '/^local CDEF = \[\[/,/^\]\]/p' ../../src/synth.lua \
    | grep -oE '[a-z_0-9]+\(' | tr -d '(' | sort -u | sed 's/^/"_/; s/$/"/' | tr '\n' ',')
# and CDEF_OPTIONAL's (slides, accents, unschedule, ...), each only if this dreamengine defines it
for f in $(sed -n '/^local CDEF_OPTIONAL = \[\[/,/^\]\]/p' ../../src/synth.lua | grep -oE '[a-z_0-9]+\(' | tr -d '(' | sort -u); do
    grep -qE "^[a-z].* $f\(" "$R/sound.h" && FUNCS="$FUNCS\"_$f\","
done
emcc -std=gnu11 -O2 -DDE_NO_RAYLIB -DDESOUND_NO_STEINWAY -I"$R" desound.c -o "$OUT" --no-entry -sSTANDALONE_WASM \
    -sALLOW_MEMORY_GROWTH -sEXPORTED_FUNCTIONS="[${FUNCS}\"_de_lua_render\",\"_de_note_opts_size\",\"_malloc\"]" \
    -Wno-shift-count-overflow
echo "built $OUT from dreamengine $(git -C "$DREAMENGINE" rev-parse --short HEAD)"
