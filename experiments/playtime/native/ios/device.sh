#!/usr/bin/env bash
# Pack Playtime into a .love, build LÖVE 11.5 for iOS around it, install and launch it on the
# connected iPhone/iPad. No Xcode GUI. Modelled on dreamengine's ios/device.sh (its notes explain
# the device-finding traps; the short versions are kept here).
#
#   native/ios/device.sh [scene] [--play]   # or: ./playtime.sh device [scene]
#   DEVICE=iPad native/ios/device.sh        # pick a device by name (default: an iPhone if one is there)
#   CONFIG=Debug native/ios/device.sh       # default Release (what players get; Debug is slower)
#   LOVE_DIR=claudetools/drawcall-bench native/ios/device.sh  # another LÖVE program instead (replaces Playtime there)
#
# The LÖVE iOS source is appelflap (NikkiKoole/appelflap, LÖVE 11.5 + IAP, ios/libraries
# included), cloned into native/ios/love (gitignored) on the first run. Its project packs
# ../../../flap.love, which is native/ios/flap.love. After the first build a deploy takes ~20 s.
#
# A new Mac needs: Xcode, signed in to the team (Xcode → Settings → Accounts), and the phone
# paired once (cable, "Trust This Computer"). Developer Mode is per phone, not per Mac.
#
# On the device the bridge answers the Mac too (its LAN address goes in the whitelist):
#   curl 'http://<device-ip>:8001/ping'
#
# One-time: the iPhone on the cable, unlocked, "Trust This Computer" accepted; Developer Mode on
# (Settings → Privacy & Security → Developer Mode, needs a restart; the toggle only appears after
# a Mac has tried an install once). First launch may need Settings → General → VPN & Device
# Management → trust the "Apple Development" profile.
set -euo pipefail
cd "$(dirname "$0")"
IOS_DIR="$(pwd)"
PLAYTIME_DIR="$(cd ../.. && pwd)"

TEAM="${TEAM:-JH2ZCZH58D}"
BUNDLE_ID="${BUNDLE_ID:-com.mipolai.playtime.dev}" # a throwaway dev id, not a shipping one
CONFIG="${CONFIG:-Release}"
APPELFLAP="${APPELFLAP:-}" # a local appelflap checkout to copy instead of cloning it

SCENE="dollhouse"; PLAY=""
for a in "$@"; do
    case "$a" in
        --play) PLAY=1 ;;
        *) SCENE="$a" ;;
    esac
done
# LOVE_DIR=<folder>: pack that LÖVE program instead of Playtime (a bench, a spike), same app
# id, so it replaces Playtime on the device until the next plain run
LOVE_DIR="${LOVE_DIR:-}"
[ -n "$LOVE_DIR" ] && LOVE_DIR="$(cd "$PLAYTIME_DIR" && cd "$LOVE_DIR" && pwd)"
if [ -z "$LOVE_DIR" ]; then
    [ -f "$PLAYTIME_DIR/scripts/$SCENE.playtime.json" ] || { echo "✗ no scene scripts/$SCENE.playtime.json"; exit 1; }
fi

# appelflap's repo has the ios/libraries in it, so on a new machine this is all the setup there is
if [ ! -d love/platform/xcode/ios/libraries ]; then
    if [ -n "$APPELFLAP" ]; then
        echo "▸ copying the LÖVE iOS source from $APPELFLAP…"
        rsync -a --exclude xcuserdata --exclude .git "$APPELFLAP/" love/
    else
        echo "▸ cloning the LÖVE iOS source (appelflap)…"
        rm -rf love
        git clone --depth 1 git@github.com:NikkiKoole/appelflap.git love
    fi
fi
# The home-screen name. Not PRODUCT_NAME on the command line: that renames liblove.a too.
PLIST=love/platform/xcode/ios/love-ios.plist
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Playtime' "$PLIST"
# Landscape only, both ways round, on iPhone and iPad. (For the App Store an iPad app that
# can't rotate to every orientation also needs UIRequiresFullScreen: dreamengine's
# ios/project.yml records that rejection.)
for key in UISupportedInterfaceOrientations 'UISupportedInterfaceOrientations~ipad'; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :$key array" \
        -c "Add :$key:0 string UIInterfaceOrientationLandscapeRight" \
        -c "Add :$key:1 string UIInterfaceOrientationLandscapeLeft" "$PLIST"
done
/usr/libexec/PlistBuddy -c 'Delete :UIRequiresFullScreen' "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :UIRequiresFullScreen bool true' "$PLIST"
# Dev builds play through the silent switch (the seam: native/ios/patch-love.py)
/usr/bin/python3 patch-love.py love/src/common/ios.mm
/usr/libexec/PlistBuddy -c 'Delete :LoveIgnoreSilentSwitch' "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :LoveIgnoreSilentSwitch bool true' "$PLIST"
# The wording of the Local Network prompt (see the packet in main.lua below)
/usr/libexec/PlistBuddy -c 'Delete :NSLocalNetworkUsageDescription' "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :NSLocalNetworkUsageDescription string "So the Mac can talk to the game while testing (the Claude bridge)."' "$PLIST"

# ── the device ──────────────────────────────────────────────────────────────────────────────
# devicectl (CoreDevice, iOS 17+) first; xctrace + ios-deploy for older devices. Parse the JSON,
# not the table (model names have spaces and parentheses). devicectl also lists every device it
# ever paired with; a cabled one stays `disconnected` until first used, so go by the transport:
# the cable, then a live tunnel, then wifi (a paired device on the same network; if it's not
# really there, the install fails).
DC_ID=""; DC_UDID=""; DC_NAME=""
JSON="$(mktemp -t playtime-devices)"
if xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1; then
    # (a plain $(...): macOS's bash 3.2 loses a heredoc inside < <(...))
    PICKED="$(/usr/bin/python3 - "$JSON" "${DEVICE:-}" <<'EOF'
import json, sys
want = sys.argv[2].lower()
def label(x):
    return (x['deviceProperties'].get('name', '') + ' ' + x.get('hardwareProperties', {}).get('productType', '')).lower()
def rank(x):  # the cable first, then a live tunnel, then wifi (a paired device on the same network)
    c = x.get('connectionProperties', {})
    if c.get('transportType') == 'wired': return 0
    if c.get('tunnelState') == 'connected': return 1
    if c.get('transportType') == 'localNetwork': return 2
    return None
d = [x for x in json.load(open(sys.argv[1]))['result']['devices']
     if rank(x) is not None and ('iphone' in label(x) or 'ipad' in label(x))]
# DEVICE= wins, then an iPhone over an iPad (the iPad nearby is not ours to install on unasked:
# on the cable it beat the phone on wifi, 2026-10-31), then the best connection
d.sort(key=lambda x: (bool(want) and want not in label(x), 'iphone' not in label(x), rank(x)))
if d:
    x = d[0]
    print(x['identifier'], x.get('hardwareProperties', {}).get('udid', ''), x['deviceProperties'].get('name', '').replace(' ', '_'))
EOF
)" || true
    read -r DC_ID DC_UDID DC_NAME <<< "$PICKED" || true # empty when there's no device
fi
rm -f "$JSON"
# no `exit` in the awk: closing the pipe early gives xctrace a SIGPIPE and pipefail kills the script
XT_ID="$(xcrun xctrace list devices 2>&1 | sed -n '/== Devices ==/,/== Devices Offline ==/p' \
    | grep -E 'iPhone|iPad' | grep -i "${DEVICE:-}" | awk -F'[()]' '!seen && NF>3 {print $(NF-1); seen=1}' || true)"

if [ -z "$DC_ID" ] && [ -z "$XT_ID" ]; then
    echo "✗ no iPhone/iPad found: connect + unlock it and accept 'Trust This Computer'"
    xcrun devicectl list devices 2>&1 | sed 's/^/    devicectl: /'
    xcrun xctrace list devices 2>&1 | sed -n '/== Devices/,/== Simulators/p' | sed 's/^/    xctrace:   /'
    exit 1
fi
if [ -n "$DC_ID" ]; then
    echo "▸ device: ${DC_NAME//_/ } (devicectl, udid $DC_UDID)"
    DEST="platform=iOS,id=$DC_UDID"
    MODE="$(xcrun devicectl device info details --device "$DC_ID" 2>/dev/null \
        | awk -F': ' '/developerModeStatus/ && !seen {print $2; seen=1}')"
    # Not a stop: the toggle only shows in Settings once a Mac has tried an install, so on a
    # new device the install below has to fail once first.
    if [ "$MODE" = "disabled" ]; then
        echo "  ⚠ Developer Mode is off: the install will fail, and after that the toggle is in Settings"
    fi
else
    echo "▸ device: $XT_ID (ios-deploy)"
    DEST="platform=iOS,id=$XT_ID"
fi

# ── the .love ──────────────────────────────────────────────────────────────────────────────
# What the web build packs: main, conf, src, vendor, assets, textures, and the scene with every
# room its doors lead to.
STAGE="$IOS_DIR/build/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE/scripts"
if [ -n "$LOVE_DIR" ]; then
    rm -rf "$STAGE"; cp -r "$LOVE_DIR" "$STAGE"
    rm -f "$IOS_DIR/flap.love"
    (cd "$STAGE" && zip -q -r -9 "$IOS_DIR/flap.love" . -x '.*' -x '*/.DS_Store')
    echo "▸ packed: $LOVE_DIR (not Playtime)"
else
cp "$PLAYTIME_DIR/conf.lua" "$STAGE/"
cp -r "$PLAYTIME_DIR/src" "$PLAYTIME_DIR/vendor" "$PLAYTIME_DIR/assets" "$PLAYTIME_DIR/textures" "$STAGE/"
mkdir -p "$STAGE/native/desound" # the synth's render thread
cp "$PLAYTIME_DIR/native/desound/synth-thread.lua" "$STAGE/native/desound/"
ROOMS="$(/usr/bin/python3 - "$PLAYTIME_DIR/scripts" "$SCENE" <<'EOF'
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
for room in $ROOMS; do cp "$PLAYTIME_DIR/scripts/${room}.playtime."* "$STAGE/scripts/"; done

# iOS passes no command line, so the launch options go into main.lua's arg here, and the Mac's
# address into the bridge's whitelist.
MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
{
    echo "-- added by native/ios/device.sh"
    echo "arg = arg or {}"
    echo "for _, a in ipairs({ '--scene', '$SCENE'${PLAY:+, '--play', '$SCENE'} }) do arg[#arg + 1] = a end"
    if [ -n "$MAC_IP" ]; then
        echo "table.insert(require('vendor.claude-bridge').whitelist, '$MAC_IP')"
        # iOS drops incoming connections from the local network until the app is allowed on it,
        # and it only asks when the app sends something out. The bridge only listens, so: one
        # packet to the Mac, and the prompt comes up (allow it once, the phone remembers).
        # What it did goes in the save folder as ios-net.txt (devicectl can copy it back).
        cat <<LUA
do
    local log = {}
    local ok, socket = pcall(require, 'socket')
    log[#log + 1] = 'require socket: ' .. tostring(ok)
    if ok then
        local u = socket.udp()
        local r, err = u:sendto('playtime', '$MAC_IP', 8001)
        log[#log + 1] = 'udp sendto: ' .. tostring(r) .. ' ' .. tostring(err)
        u:close()
        local t = socket.tcp()
        t:settimeout(1)
        r, err = t:connect('$MAC_IP', 8001)
        log[#log + 1] = 'tcp connect: ' .. tostring(r) .. ' ' .. tostring(err)
        t:close()
    end
    love.filesystem.write('ios-net.txt', table.concat(log, '\n') .. '\n')
end
LUA
    fi
    cat "$PLAYTIME_DIR/main.lua"
} > "$STAGE/main.lua"

rm -f "$IOS_DIR/flap.love"
(cd "$STAGE" && zip -q -r -9 "$IOS_DIR/flap.love" . -x '.*' -x '*/.DS_Store')
echo "▸ packed: $SCENE${PLAY:+ (play mode)}, rooms: $ROOMS ($(du -h "$IOS_DIR/flap.love" | cut -f1))"
fi

# ── build, install, launch ────────────────────────────────────────────────────────────────
# Build for the device itself, not generic/platform=iOS: only then does automatic signing
# register the device and make a profile that includes it.
# The native library linked in: the synth (src/synth.lua), the limb ribbons
# (src/ribbon-native.lua) and whatever a LOVE_DIR program declares. Nothing in the app calls
# its functions, Lua finds them by name (ffi.C), so the linker would strip them: -u keeps each
# one a `local CDEF = [[ ... ]]` block declares, in src/ and in LOVE_DIR, and the de_lua_* ones
# the synth's thread uses. Without dreamengine the game is silent.
SYNTH_FLAGS=""
if "$PLAYTIME_DIR/native/desound/build-ios.sh" "$IOS_DIR/build/libdesound-ios.a" >/dev/null 2>&1; then
    SYNTH_FLAGS="-force_load $IOS_DIR/build/libdesound-ios.a"
    CDEF_FILES="$(grep -rl '^local CDEF = \[\[' "$PLAYTIME_DIR/src" ${LOVE_DIR:+"$LOVE_DIR"} --include='*.lua')"
    for f in $(sed -n '/^local CDEF = \[\[/,/^\]\]/p' $CDEF_FILES \
        | grep -oE '[a-z_0-9]+\(' | tr -d '(' | sort -u) de_lua_init de_lua_render_s16; do
        SYNTH_FLAGS="$SYNTH_FLAGS -Wl,-u,_$f"
    done
    echo "▸ synth: linked in"
else
    echo "  ⚠ no synth: native/desound/build-ios.sh failed (needs dreamengine, DREAMENGINE=…)"
fi

echo "▸ building ($CONFIG, signed for the device)…"
LOG="$IOS_DIR/build/xcodebuild.log"
if ! xcodebuild -project love/platform/xcode/love.xcodeproj -scheme love-ios -configuration "$CONFIG" \
    -destination "$DEST" -derivedDataPath build \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" ${SYNTH_FLAGS:+OTHER_LDFLAGS="$SYNTH_FLAGS"} \
    build >"$LOG" 2>&1; then
    grep -E 'error:|warning: .*(provision|sign)' "$LOG" | sort -u | head -20
    echo "✗ build failed, full log: $LOG"
    exit 1
fi

APP_PATH="build/Build/Products/$CONFIG-iphoneos/love.app"
echo "▸ installing + launching…"
if [ -n "$DC_ID" ]; then
    if ! xcrun devicectl device install app --device "$DC_ID" "$APP_PATH" >/dev/null; then
        echo "  ▸ Developer Mode? Settings → Privacy & Security → Developer Mode → on → restart →"
        echo "    'Turn On' after the reboot. Then run this again."
        exit 1
    fi
    if ! LAUNCH="$(xcrun devicectl device process launch --terminate-existing --device "$DC_ID" "$BUNDLE_ID" 2>&1)"; then
        if echo "$LAUNCH" | grep -q 'Locked'; then
            echo "✗ installed, but the device is locked: unlock it and run this again (or open Playtime)"
        else
            echo "$LAUNCH" | tail -5
            echo "✗ installed, but it didn't start"
        fi
        exit 1
    fi
else
    ios-deploy --id "$XT_ID" --bundle "$APP_PATH" --justlaunch >/dev/null
fi
# The device's wifi address, from Bonjour (<name with dashes>.local). Not the 169.254 one: that's
# the cable, and the Mac's address on it isn't in the bridge's whitelist.
DEVICE_IP=""
if [ -n "$DC_NAME" ]; then
    DEVICE_IP="$( (dns-sd -G v4 "${DC_NAME//_/-}.local" & sleep 2; kill $! 2>/dev/null) 2>/dev/null \
        | awk '$6 ~ /^(192\.168|10\.|172\.)/ && !seen {print $6; seen=1}' || true)"
fi
mkdir -p build && echo "${DEVICE_IP:-}" > build/device-ip
echo "✓ running on the device."
echo "  bridge: curl 'http://${DEVICE_IP:-<device-ip>}:8001/ping'   (allow the Local Network prompt on the device)"
