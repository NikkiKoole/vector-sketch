# Web Export via love.js

status: active

## Overview

love.js (Davidobot/love.js) compiles LÖVE to WebAssembly via Emscripten. Supports LÖVE 11.4 natively (11.5 experimental). This lets us package Playtime scenes as shareable browser links — key for demoing to publishers and distributing Knut content.

Worked 2026-04-11 (catapult, Knut). Rebuilt 2026-10-30: the dollhouse runs in Chrome in play mode,
Mipos and all, with no errors; no sound from the synth yet (see WEB2).

- [x] **WEB1. Build from the real game** (2026-10-30). `build-web.sh` packages the real `main.lua`
  and `src/` instead of its own copy of main.lua (that copy had fallen behind: it still loaded the
  removed loveblobs). Desktop-only modules get stand-ins (profilers, LuaJIT's `ffi`); the bridge and
  lurker are already skipped by main.lua on the web. The four `goto`s in the draw loops are gone
  from the source (`spec/draw-skips_spec.lua`), so the goto patcher isn't needed any more.
- [x] **WEB2. The synth in the browser** (2026-10-30). `native/desound/build-web.sh` builds the
  same `desound.c` (unmodified dreamengine) with emcc into a 218 KB standalone `desound.wasm`;
  `webtest/desound-processor.js` runs it in an AudioWorklet. Lua has no FFI there, so
  `src/synth-web.lua` stands in for the C library: it writes each frame's calls down and prints
  them as one `@desound` line, which the page's `Module.print` catches and posts to the worklet
  (one frame's calls per 128 samples). `audio_time` is Lua's own clock; the worklet maps the
  times in `schedule_at` onto the engine's clock (re-synced only past 80 ms of drift), and gives
  `note_on` handles out on the Lua side. Audio starts on the first click or key (browser rule);
  setup calls made before that wait, notes don't. Checked in Chrome: the music plays (peak 0.18),
  the clock runs. Not on the web: `sample_load` (the voice lab).
  - Gotcha found on the way: the standalone wasm prints through WASI `fd_write`. A stub that
    answered 0 made the C library retry forever on the engine's first warning (its request queue
    overflowed when a pile of frames was applied at once): the audio thread hung, and the page with
    it as soon as anything touched the audio graph. `fd_write` now reports the bytes and passes the
    text to the page console (`desound: ...`).
- [ ] **WEB4. Bridge tools for the web build** (noted for Nikki, 2026-10-30; nothing built). Testing
  it from Claude meant pasting analyser code into the page each time, and the claude-bridge
  (port 8001) doesn't exist there. Worth having:
  - a page helper `playtime.audio()`: audio state, clock, output peak, calls/s, the engine's
    warnings, instead of hand-made AnalyserNodes;
  - eval into the running Lua: the page drops code into love's filesystem (`Module.FS`), Lua polls
    an inbox file each frame and prints the result back with an `@bridge` prefix, so `/eval`-style
    checks work in the browser too (through Chrome's javascript tool or a small relay);
  - input from Lua (or slow drags from the page): the automated drag was too quick to grab a Mipo;
  - a headless run (Playwright) of build → load → click → audio check, so the web build gets
    tested without a person or a Chrome extension.
- [ ] **WEB3. Check by hand**: grab and throw Mipos (an automated drag didn't take, probably too
  fast for a frame), touch on an iPad, tab into the editor.

## Quick start

```bash
# Build any scene for web:
./webtest/build-web.sh dollhouse

# Serve it locally:
./webtest/serve.sh 8080 dollhouse

# Open http://localhost:8080
```

Replace `dollhouse` with any scene name from `scripts/`. The page starts it in play mode (`--play`); tab goes to the editor.

## Why web matters

- Shareable URL = instant demo for publishers ("here, click this")
- No install friction for parents/kids/teachers
- itch.io handles mobile browser embedding well
- Can be wrapped as PWA for "app-like" mobile experience

## Source changes for web compatibility

These changes live in the main source and are backwards-compatible with LuaJIT:

### 1. `main.lua` — IS_WEB guard for bridge/lurker/jit
```lua
local IS_WEB = love.system.getOS() == "Web"
-- bridge and lurker only loaded when not IS_WEB
-- jit.off() guarded with `if jit then`
```

### 2. `src/scene-loader.lua` — love.filesystem fallback
`getFiledata()` tries `io.open` first (native), falls back to `love.filesystem.read` (web/.love bundles).
`loadScriptAndScene()` tries absolute paths first, falls back to relative paths.

### 3. `src/script.lua` — Lua 5.1 compatible load()
```lua
-- Lua 5.1 (love.js): loadstring + setfenv
-- LuaJIT/5.2+: load(string, name, mode, env)
if setfenv then
    chunk, err = loadstring(content, name)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = load(content, name, "t", env)
end
```

### 4. `src/joints.lua` + `src/object-manager.lua` — removed goto/continue
`goto label` / `::label::` is LuaJIT/Lua 5.2+. Replaced with if/else nesting.

### 5. `src/physics/box2d-draw-textured.lua` — safe texture loading
Default pattern/outline textures loaded with `safeLoadImage()` which returns nil for missing files. `tex1` falls back to a 1x1 white pixel so textured rendering doesn't crash when pattern textures aren't bundled.

## Build pipeline

### What build-web.sh does
1. Copies main.lua, conf.lua, src/, vendor/, assets/, textures/ and the scene's files to a temp dir
2. Puts a stand-in `ffi` in front of main.lua (src/synth.lua then stays off) and stubs the profilers
   (jprof, ProFi, peeker); main.lua itself skips the bridge and lurker when `love.system.getOS() == "Web"`
3. Zips a .love and packages it with love.js (found on PATH or under ~/.nvm; or set LOVEJS)
4. Writes index.html from `index.template.html`: full window, `--play <scene>`
5. Output: `webtest/output-<scene>/`, static files for any web host (not in git)

### What serve.sh does
Serves the output directory with `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers (required for SharedArrayBuffer / love.js threads).

## Bundle size

| Component | Size | Notes |
|---|---|---|
| love.js + love.wasm | ~5MB | Fixed, same for all scenes |
| game.data (no textures) | ~2MB | Lua source + assets (font, icons) |
| game.data (knut scene) | ~2MB | +5 small texture files |
| **Total download** | **~7MB** | Acceptable for web demo |

### Remaining size wins (not yet done)
- Strip `assets/playtime2.png` (1.2MB logo, not needed in shipped scenes)
- Strip editor-only modules (mipo-editor, character-manager, sfixture-editor)
- These would bring game.data to under 500KB

## Lua 5.1 vs LuaJIT gotchas

love.js uses PUC Lua 5.1, not LuaJIT. Watch out for:

| Feature | LuaJIT | Lua 5.1 (love.js) | Fix |
|---|---|---|---|
| `goto label` / `::label::` | Yes | No | Use if/else |
| `load(str, name, mode, env)` | Yes | No (only 2 args) | Use `loadstring` + `setfenv` |
| `jit.off()` / `jit` global | Yes | No | Guard with `if jit then` |
| `bit` library | `bit` | Not available | Use love.math or manual |
| `io.open` | Yes | Unavailable in browser | Use `love.filesystem.read` |

## Known issues (web)

- **Mouse wheel zoom** — needs `preventDefault()` on canvas wheel event (handled in custom index.html)
- **Audio autoplay** — browsers block audio until user clicks. Need a "tap to start" screen for scenes with sound.
- **Editor UI panels** — full editor UI loads in web build; for shipped scenes, should strip to just the scene player
- **Missing textures** — scenes that reference pattern/outline textures not bundled will use white pixel fallback (looks wrong but doesn't crash)

## Hosting options

- **itch.io** — easiest, handles mobile, has payment/tipping built in
- **Own domain** — static hosting (Netlify, Vercel, GitHub Pages)
- **Embed** — iframe on publisher's site for demos

## Performance notes

- Browser performance is ~70-80% of native LÖVE
- VRAM more constrained — watch OMP texture compositing (6.4 MB per uncached character)
- For a few Knut characters per scene: should be fine
- Profile once we get there

## Touch input

LÖVE touch events map to browser touch:
- `love.touchpressed` / `love.touchmoved` / `love.touchreleased`
- The catapult script's onPressed/onReleased work via input-manager which handles touch

## Open questions

- Audio format support in browser (OGG vs MP3 vs WAV)
- Save state across sessions (IndexedDB via love.filesystem)
- Strip editor UI for shipped scenes (only scene player needed)
- Multi-scene navigation (scene selector in web build)
