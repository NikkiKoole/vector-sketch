# Web Export via love.js

## Overview

love.js (Davidobot/love.js) compiles LÖVE to WebAssembly via Emscripten. Supports LÖVE 11.4 natively (11.5 experimental). This lets us package Playtime scenes as shareable browser links — key for demoing to publishers and distributing Knut content.

**Status:** Working proof-of-concept (2026-04-08). Catapult scene runs in browser with physics + scripting. Source changes made for Lua 5.1 compatibility.

## Why web matters

- Shareable URL = instant demo for publishers ("here, click this")
- No install friction for parents/kids/teachers
- itch.io handles mobile browser embedding well
- Can be wrapped as PWA for "app-like" mobile experience

## Source changes made (2026-04-08)

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

## Known issues (web)

- **Mouse wheel zoom** — needs `preventDefault()` on canvas wheel event (patched in index.html)
- **Editor UI panels** — full editor UI loads in web build; for shipped scenes, should strip to just the scene player
- **Bundle size** — ~18MB when all textures included; strip unused textures per scene for smaller builds

## Build & serve scripts

Located in `webtest/`:

```bash
# Build a scene for web
./webtest/build-web.sh catapult        # builds to webtest/output-catapult/

# Serve locally (needs CORS headers for SharedArrayBuffer)
./webtest/serve.sh 8080 catapult       # http://localhost:8080
```

### What build-web.sh does
1. Copies src/, vendor/, assets/, scripts/ to temp dir
2. Creates a web-specific main.lua (scene player, no editor chrome)
3. Stubs out vendor modules (bridge, lurker, jprof, ProFi, peeker)
4. Runs `love.js` to package as HTML/WASM
5. Output: static files ready for any web host

### What serve.sh does
Serves the output directory with `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers (required for SharedArrayBuffer / love.js threads).

## Lua 5.1 vs LuaJIT gotchas

love.js uses PUC Lua 5.1, not LuaJIT. Watch out for:

| Feature | LuaJIT | Lua 5.1 (love.js) | Fix |
|---|---|---|---|
| `goto label` / `::label::` | Yes | No | Use if/else |
| `load(str, name, mode, env)` | Yes | No (only 2 args) | Use `loadstring` + `setfenv` |
| `jit.off()` / `jit` global | Yes | No | Guard with `if jit then` |
| `bit` library | `bit` | Not available | Use love.math or manual |
| `io.open` | Yes | Unavailable in browser | Use `love.filesystem.read` |

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
- Whether to lazy-load textures or bundle everything upfront
- Save state across sessions (IndexedDB via love.filesystem)
- Strip editor UI for shipped scenes (only scene player needed)
