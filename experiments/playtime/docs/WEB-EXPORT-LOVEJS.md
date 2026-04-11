# Web Export via love.js

## Overview

love.js (Davidobot/love.js) compiles LÖVE to WebAssembly via Emscripten. Supports LÖVE 11.4 natively (11.5 experimental). This lets us package Playtime scenes as shareable browser links — key for demoing to publishers and distributing Knut content.

**Status:** Working (2026-04-11). Catapult and Knut scenes run in browser with physics, scripting, and textures. ~2MB per scene build.

## Quick start

```bash
# Build any scene for web:
./webtest/build-web.sh catapult

# Serve it locally:
./webtest/serve.sh 8080 catapult

# Open http://localhost:8080
```

Replace `catapult` with any scene name from `scripts/` (e.g., `knut`, `platforms`, `water`).

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
1. Copies src/, vendor/, assets/, scripts/ to temp dir
2. **Parses scene JSON** for `bgURL`, `outlineURL`, `maskURL`, `patternURL` — only copies referenced textures (not the whole textures/ folder)
3. Creates a web-specific main.lua (scene player, no editor chrome)
4. Stubs out vendor modules (bridge, lurker, jprof, ProFi, peeker)
5. Patches goto/continue if any remain (Lua 5.1 compat)
6. Zips into .love file, packages with love.js
7. Overwrites love.js default HTML with responsive fullscreen layout
8. Output: static files ready for any web host

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
