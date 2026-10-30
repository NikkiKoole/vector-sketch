#!/bin/bash
# Build a web version of Playtime (love.js, LÖVE 11.4 in the browser, PUC Lua 5.1).
# Usage: ./build-web.sh [scene]          (default: dollhouse, started in play mode)
# Then:  ./serve.sh 8080 <scene>         and open http://localhost:8080
#
# It packages the real main.lua and src/; only desktop-only modules get stand-ins:
# the bridge and lurker (main.lua skips them on the web), the profilers, and LuaJIT's ffi.
# The synth plays through the page: src/synth-web.lua prints the calls, the page hands them
# to the engine built to wasm (native/desound/build-web.sh, needs emcc) in an AudioWorklet.
# Needs love.js (npm i -g love.js); override with LOVEJS=/path/to/love.js.

set -e

SCENE="${1:-dollhouse}"
WEBTEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYTIME_DIR="$(cd "$WEBTEST_DIR/.." && pwd)"
OUTPUT_DIR="$WEBTEST_DIR/output-${SCENE}"
BUILD_DIR="$(mktemp -d)"
LOVE_FILE="$BUILD_DIR.love"
trap 'rm -rf "$BUILD_DIR" "$LOVE_FILE" "$BUILD_DIR.desound.wasm"' EXIT

LOVEJS="${LOVEJS:-$(command -v love.js || ls "$HOME"/.nvm/versions/node/*/bin/love.js 2>/dev/null | head -1)}"
[ -x "$LOVEJS" ] || { echo "love.js not found (npm i -g love.js, or set LOVEJS)" >&2; exit 1; }
[ -f "$PLAYTIME_DIR/scripts/${SCENE}.playtime.json" ] || { echo "no scene scripts/${SCENE}.playtime.json" >&2; exit 1; }

echo "=== Web build of '$SCENE' ==="

cp "$PLAYTIME_DIR/main.lua" "$PLAYTIME_DIR/conf.lua" "$BUILD_DIR/"
cp -r "$PLAYTIME_DIR/src" "$PLAYTIME_DIR/vendor" "$PLAYTIME_DIR/assets" "$PLAYTIME_DIR/textures" "$BUILD_DIR/"
mkdir -p "$BUILD_DIR/scripts"
# The scene and every room its doors lead to, door by door (DOOR behaviors' `to`, src/doors.lua):
# with only the start scene, going through a door had nothing to load.
ROOMS="$(python3 - "$PLAYTIME_DIR/scripts" "$SCENE" <<'EOF'
import json, os, sys
scripts, start = sys.argv[1], sys.argv[2]
seen, todo = [], [start]
while todo:
    room = todo.pop()
    path = os.path.join(scripts, room + '.playtime.json')
    if room in seen or not os.path.exists(path):
        continue
    seen.append(room)
    for body in json.load(open(path)).get('bodies', []):
        for behavior in body.get('behaviors') or []:
            if behavior.get('name') == 'DOOR' and behavior.get('to'):
                todo.append(behavior['to'])
print(' '.join(seen))
EOF
)"
for room in $ROOMS; do
    cp "$PLAYTIME_DIR/scripts/${room}.playtime."* "$BUILD_DIR/scripts/"
done
echo "rooms: $ROOMS"

# LuaJIT's ffi doesn't exist here (src/synth.lua doesn't need it on the web); the stand-in keeps
# anything else that requires it (the voice lab) from failing at load.
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

# The synth for the page: the engine built to wasm, and the AudioWorklet that runs it. Without it
# the build still works: no marker, so src/synth.lua doesn't start and the Mipos use their samples.
SYNTH_WASM="$BUILD_DIR.desound.wasm"
if ! command -v emcc > /dev/null; then
    echo "no emcc (brew install emscripten): building without the synth"
elif ! "$PLAYTIME_DIR/native/desound/build-web.sh" "$SYNTH_WASM" > /dev/null; then
    echo "the synth didn't build (dreamengine at ~/Projects/dreamengine? or set DREAMENGINE): building without it"
    rm -f "$SYNTH_WASM"
else
    mkdir -p "$BUILD_DIR/native/desound"
    echo "desound.wasm is next to index.html" > "$BUILD_DIR/native/desound/web-synth"
fi

(cd "$BUILD_DIR" && zip -qr "$LOVE_FILE" . -x "*.DS_Store")
echo ".love: $(du -sh "$LOVE_FILE" | cut -f1)"

rm -rf "$OUTPUT_DIR"
"$LOVEJS" "$LOVE_FILE" "$OUTPUT_DIR" --title "Playtime: ${SCENE}" --memory 268435456 > /dev/null

# A full-window page that starts the scene in play mode (`--play <scene>`, like ./playtime.sh play).
HAS_SYNTH=false
[ -f "$SYNTH_WASM" ] && HAS_SYNTH=true
sed -e "s/__SCENE__/${SCENE}/g" -e "s/__SYNTH__/${HAS_SYNTH}/g" "$WEBTEST_DIR/index.template.html" > "$OUTPUT_DIR/index.html"
cp -r "$WEBTEST_DIR/fonts" "$OUTPUT_DIR/"   # Lora for the page's message, with its license
if [ -f "$SYNTH_WASM" ]; then
    cp "$SYNTH_WASM" "$OUTPUT_DIR/desound.wasm"
    cp "$WEBTEST_DIR/desound-processor.js" "$OUTPUT_DIR/"
    rm -f "$SYNTH_WASM"
fi

echo "Output: $OUTPUT_DIR"
echo "Serve:  $WEBTEST_DIR/serve.sh 8080 $SCENE   (then http://localhost:8080)"
