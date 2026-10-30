#!/bin/bash
# Build a web version of Playtime (love.js, LÖVE 11.4 in the browser, PUC Lua 5.1).
# Usage: ./build-web.sh [scene]          (default: dollhouse, started in play mode)
# Then:  ./serve.sh 8080 <scene>         and open http://localhost:8080
#
# It packages the real main.lua and src/; only desktop-only modules get stand-ins:
# the bridge and lurker (main.lua skips them on the web), the profilers, and LuaJIT's
# ffi (src/synth.lua then finds no native library and the synth stays off: no music).
# Needs love.js (npm i -g love.js); override with LOVEJS=/path/to/love.js.

set -e

SCENE="${1:-dollhouse}"
WEBTEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYTIME_DIR="$(cd "$WEBTEST_DIR/.." && pwd)"
OUTPUT_DIR="$WEBTEST_DIR/output-${SCENE}"
BUILD_DIR="$(mktemp -d)"
LOVE_FILE="$BUILD_DIR.love"
trap 'rm -rf "$BUILD_DIR" "$LOVE_FILE"' EXIT

LOVEJS="${LOVEJS:-$(command -v love.js || ls "$HOME"/.nvm/versions/node/*/bin/love.js 2>/dev/null | head -1)}"
[ -x "$LOVEJS" ] || { echo "love.js not found (npm i -g love.js, or set LOVEJS)" >&2; exit 1; }
[ -f "$PLAYTIME_DIR/scripts/${SCENE}.playtime.json" ] || { echo "no scene scripts/${SCENE}.playtime.json" >&2; exit 1; }

echo "=== Web build of '$SCENE' ==="

cp "$PLAYTIME_DIR/main.lua" "$PLAYTIME_DIR/conf.lua" "$BUILD_DIR/"
cp -r "$PLAYTIME_DIR/src" "$PLAYTIME_DIR/vendor" "$PLAYTIME_DIR/assets" "$PLAYTIME_DIR/textures" "$BUILD_DIR/"
mkdir -p "$BUILD_DIR/scripts"
cp "$PLAYTIME_DIR/scripts/${SCENE}.playtime."* "$BUILD_DIR/scripts/"

# LuaJIT's ffi doesn't exist here. A stand-in lets src/synth.lua load; it then finds no
# native/desound library, so lib.start() returns false and everything plays without the synth.
MAIN="$BUILD_DIR/main.lua"
{
    echo "package.preload.ffi = package.preload.ffi or function()"
    echo "    return { cdef = function() end, load = function() error('no ffi in the browser') end }"
    echo "end"
    cat "$PLAYTIME_DIR/main.lua"
} > "$MAIN"

# Profilers: main.lua calls them every frame; here they do nothing.
echo "return { push = function() end, pop = function() end, write = function() end }" > "$BUILD_DIR/vendor/jprof.lua"
echo "return {}" > "$BUILD_DIR/vendor/ProFi.lua"
echo "return { update = function() end, attach = function() end, detach = function() end }" > "$BUILD_DIR/vendor/peeker.lua"

(cd "$BUILD_DIR" && zip -qr "$LOVE_FILE" . -x "*.DS_Store")
echo ".love: $(du -sh "$LOVE_FILE" | cut -f1)"

rm -rf "$OUTPUT_DIR"
"$LOVEJS" "$LOVE_FILE" "$OUTPUT_DIR" --title "Playtime: ${SCENE}" --memory 268435456 > /dev/null

# A full-window page that starts the scene in play mode (`--play <scene>`, like ./playtime.sh play).
sed -e "s/__SCENE__/${SCENE}/g" "$WEBTEST_DIR/index.template.html" > "$OUTPUT_DIR/index.html"

echo "Output: $OUTPUT_DIR"
echo "Serve:  $WEBTEST_DIR/serve.sh 8080 $SCENE   (then http://localhost:8080)"
