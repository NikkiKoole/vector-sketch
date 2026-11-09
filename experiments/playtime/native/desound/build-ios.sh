#!/bin/sh
# Build libdesound-ios.a: dreamengine's synth for the iOS build (native/ios/device.sh runs this).
# The same desound.c as build.sh, as a static library linked into the app: iOS loads no
# dylibs of ours, so src/synth.lua finds the functions in the app itself (ffi.C).
# Needs a dreamengine checkout; override with DREAMENGINE=/path/to/dreamengine.
set -e
cd "$(dirname "$0")"
DREAMENGINE="${DREAMENGINE:-$HOME/Projects/dreamengine}"
R="$DREAMENGINE/runtime"
[ -f "$R/sound.h" ] || { echo "no dreamengine runtime at $R" >&2; exit 1; }
OUT="${1:-libdesound-ios.a}"
OBJ="$(mktemp -t desound).o"
RIBBON_OBJ="$(mktemp -t ribbon).o"
PLACE_OBJ="$(mktemp -t place).o"
GRID_OBJ="$(mktemp -t grid).o"
CLOTH_OBJ="$(mktemp -t cloth).o"
FLUID_OBJ="$(mktemp -t fluid).o"
HAIR_OBJ="$(mktemp -t hair).o"
CC="xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=12.0 -std=gnu11 -O2"
$CC -DDE_NO_RAYLIB -I"$R" -c desound.c -o "$OBJ"
$CC -c ribbon.c -o "$RIBBON_OBJ" # limb ribbons (src/ribbon-native.lua)
$CC -c place.c -o "$PLACE_OBJ" # a spike: parts moved to their bodies (claudetools/drawcall-bench)
$CC -c grid.c -o "$GRID_OBJ" # bent pictures: spine torsos, ears (src/spine-skin.lua)
$CC -c cloth.c -o "$CLOTH_OBJ" # cloth: curtains, flags (src/cloth.lua)
$CC -c fluid.c -o "$FLUID_OBJ" # particle water (src/fluid.lua, scene waterjar)
$CC -c hair.c -o "$HAIR_OBJ" # hair locks (src/hair-native.lua, scene hair)
rm -f "$OUT"
xcrun libtool -static -o "$OUT" "$OBJ" "$RIBBON_OBJ" "$PLACE_OBJ" "$GRID_OBJ" "$CLOTH_OBJ" "$FLUID_OBJ" "$HAIR_OBJ" 2>/dev/null
rm -f "$OBJ" "$RIBBON_OBJ" "$PLACE_OBJ" "$GRID_OBJ" "$CLOTH_OBJ" "$FLUID_OBJ" "$HAIR_OBJ"
echo "built $OUT from dreamengine $(git -C "$DREAMENGINE" rev-parse --short HEAD)"
