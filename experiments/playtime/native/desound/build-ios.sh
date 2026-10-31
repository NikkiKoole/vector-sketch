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
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=12.0 -std=gnu11 -O2 -DDE_NO_RAYLIB \
    -I"$R" -c desound.c -o "$OBJ"
rm -f "$OUT"
xcrun libtool -static -o "$OUT" "$OBJ" 2>/dev/null
rm -f "$OBJ"
echo "built $OUT from dreamengine $(git -C "$DREAMENGINE" rev-parse --short HEAD)"
