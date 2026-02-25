# Playtime — LÖVE2D Physics Editor

## Running the app

```bash
./playtime.sh start    # start with --bridge (skips start screen), captures errors
./playtime.sh stop     # graceful quit via bridge, force kill as fallback
./playtime.sh restart  # stop + start
./playtime.sh status   # check if running
./playtime.sh log      # show stdout/stderr log
./playtime.sh errors   # show startup errors + bridge /errors
```

Love executable: `/Applications/love114.app/Contents/MacOS/love`
LÖVE version: 11.4, window 1200x768.

## Claude Bridge (port 8001)

HTTP JSON API for interacting with the running game. All endpoints return `{ok, data, meta}`.

### Key endpoints
- `GET /ping` — health check
- `GET /bodies` — list all bodies
- `GET /body?id=X` — body detail
- `GET /joints` — list joints
- `GET /selection` — currently selected body/joint
- `GET /errors` — captured errors (lurker, etc.)
- `GET /console?n=10` — last N print() lines
- `GET /help` — list all endpoints
- `POST /eval` — run Lua code, get result (preamble: state, registry, objectManager, joints, sceneIO, inspect, utils)
- `POST /exec` — run Lua code, fire-and-forget
- `POST /screenshot` — capture screenshot
- `POST /profile/benchmark` — benchmark code snippet (iterations, returns mean/median/min/max/p95)
- `POST /profile/frames` — profile N physics frames with ProFi

### Important
- Always quote URLs with `?` in zsh: `curl 'localhost:8001/console?n=5'`
- Must clear Box2D callbacks before destroying bodies to avoid SEGFAULT
- `playtime.sh start` passes `--bridge` which skips the start screen automatically
- macOS buffers stderr from .app bundles until process exit; `playtime.sh` handles this by killing the process to flush errors on startup failure

## Hot Reload

Lurker watches files every 0.5s and hot-swaps Lua modules. Check `/errors` after changes.

## Testing

Busted is the primary test framework. Specs live in `spec/`. Full suite: **8 spec files, 367 tests**.

```bash
# Pure unit specs (no LÖVE needed)
busted spec/                              # all pure specs
busted spec/math-utils_spec.lua           # single file

# Full suite including LÖVE integration tests
love . --specs                            # all specs (pure + physics + integration)
love . --specs spec/integration_spec.lua  # single file

# Via the bridge (while app is running)
curl -X POST localhost:8001/specs                                              # run all
curl -X POST localhost:8001/specs -d '{"target":"spec/integration_spec.lua"}'  # single file
curl -X POST localhost:8001/specs -d '{"fresh":true}'                          # clear cached src.* modules first
```

- Pure specs (math, utils, shapes): work everywhere, no guard needed
- LÖVE-dependent specs (physics, integration, ui-smoke): start with `if not love then return end`
- Busted must be installed for Lua 5.1: `luarocks --lua-version 5.1 install busted`

## Luacheck

```bash
luacheck src/ main.lua --std "lua51+love" --only 111 112   # check global leaks (currently 0)
luacheck src/ main.lua --std "lua51+love"                   # full check (0 warnings, 0 errors)
```

Fully clean: **0 warnings / 0 errors** across 42 files.

## Architecture

- `main.lua` — entry point, keybindings, UI callbacks
- `src/` — core modules (42 files across src/, src/ui/, src/physics/)
- `claudetools/` — dev tools (e.g. find-forward-refs.lua)
- `vendor/` — third-party libs (claude-bridge, lurker, dkjson, ProFi, jprof, loveblobs, etc.)
- `scripts/` — scene scripts (.playtime.lua) + scene data (.playtime.json)
- `textures/` — character textures (~290 files, OMP system: outline + mask + pattern)

### Key modules

**Core data & state:**
- `src/state.lua` — shared app state
- `src/registry.lua` — central registry for bodies, joints, sfixtures
- `src/object-manager.lua` — body creation/destruction/recreation
- `src/io.lua` — save/load, clone
- `src/fixtures.lua` — fixture creation, shape attachment, property management

**Editor & input:**
- `src/input-manager.lua` — mouse/keyboard input handling, drag, selection, tool modes
- `src/editor-render.lua` — editor overlay rendering: selection boxes, handles, guides
- `src/camera.lua` — camera singleton (pan, zoom via vendor/brady)

**UI:**
- `src/playtime-ui.lua` — editor UI orchestrator (~648 lines)
- `src/ui/` — extracted UI panels: all.lua, textinput.lua, body-editor.lua, sfixture-editor.lua, joint-update.lua, world-settings.lua, shape-panel.lua, recording-panel.lua

**Physics & rendering:**
- `src/physics/` — Box2D modules (box2d-draw, box2d-draw-textured, box2d-pointerjoints, physics-callbacks, snap)
- `src/joints.lua` — joint creation/recreation
- `src/joint-handlers.lua` — per-type joint create/update handlers
- `src/shapes.lua` — shape generation: rect, capsule, polygon, etc.

**Characters & scripting:**
- `src/character-manager.lua` — character DNA system, body part assembly
- `src/script.lua` — per-scene Lua script loading and execution
- `src/recorder.lua` — animation recording and playback

**Infrastructure:**
- `src/game-loop.lua` — fixed-timestep love.run() with panic detection
- `src/math-utils.lua` — shared math utilities: clamp, sign, lerp, distance, etc.
- `src/utils.lua` — general utilities: deepCopy, round, randomHexColor, etc.
- `src/logger.lua` — structured logging

### No classes/OOP — modules return tables of functions.

### Core data model

**thing** — the runtime property bag stored on `body:getUserData().thing`:
```lua
{ id, label, shapeType, body, shapes, vertices, radius, width, height,
  width2, width3, height2, height3, height4, mirrorX, mirrorY,
  zOffset, behaviors, label }
```

**sfixture** — special sensor fixture on a body (9 subtypes: anchor, snap, texfixture, connected-texture, meshusert, trace-vertices, resource, bone, script). Stored as `fixture:getUserData()` with `{ type, subtype, id, label, extra }`.

**Fixture ordering invariant**: all fixtures with userData (sfixtures) must come before fixtures without userData (collision shapes) on each body. Validated by `fixtures.hasFixturesWithUserDataAtBeginning()`.

## Lua Gotchas

- Closures capture upvalues by reference — `local x, y` must be declared before any closure that uses them
- When making functions `local`, check for forward references (function used before its definition). Lurker hot-reload re-executes files top-to-bottom, so a local function must be defined before first use. Use `claudetools/find-forward-refs.lua` to scan for these.
- `registry.getBodyByID()` — capital ID, not Id
- `require('src.game-loop')` — use parentheses for module names with hyphens; bare string syntax (`require 'src.game-loop'`) can confuse the parser
- Circular requires: `registry.lua` ↔ `src/physics/snap.lua` — registry uses a lazy `getSnap()` wrapper to break the cycle. If adding cross-module requires, watch for `loop or previous error loading module` errors

## Naming conventions

- **`require` aliases**: use descriptive names — `sceneIO` (not `eio`), `sceneLoader`, `box2dDrawTextured`
- **UI draw functions**: use `draw` prefix — `drawJointUpdateUI`, `drawAddShapeUI`, `drawWorldSettingsUI`
- **Function names**: no redundant suffixes — `updateSFixtureDimensions` (not `...Func`)
- **Joint variables**: spell out `joint` in function params (not `j`)
- **Shape data**: `vertices` and `dimensions` as keys (not `v`/`d`), `vertices` for vertex arrays (not `vv`)
- **Body/mesh data**: `bodyData`/`meshData` (not `bud`/`mud`)
- **`ud`**: acceptable shorthand for `getUserData()` — used consistently across the codebase
- **`thing`**: the runtime property bag on body userData — persisted indirectly (decomposed on save, reconstructed on load)
- **`extra`, `subtype`, `scriptmeta`**: persisted in `.playtime.json` — do not rename without migration

## UI patterns

- Modules return `lib = {}` table, live in `src/ui/`
- Layout helpers: `ui.alignedLabel()` for vertical centering, `ui.sameLine()` for horizontal flow
- Accordion state tables are local to their respective extracted module

## Known issues

See `docs/DEEPER-ISSUES.md` for full details. Key remaining issues:

**Bugs:**
- Cloned OMP texfixtures not marked `dirty` — composite texture won't regenerate on first render
- Unused `swapBodies` parameter in `joints.recreateJoint()` — dead code
- Redundant reference angle read during clone — reads old joint twice

**Architectural risks:**
- Box2D doesn't guarantee fixture ordering — the ordering invariant can break silently
- Z-sort uses unstable `table.sort` — same-z drawables can flicker
- `state.currentMode` has 27 writers across 3 files with no state machine
- Image/OMP/canvas caches never cleared — memory grows over long sessions
- Clone pipeline: influence references can become nil silently when cloning partial selections

## Further documentation

Deep-dive docs live in `docs/`:
- `PLAN-OF-ATTACK.md` — master work plan with phase status
- `DEEPER-ISSUES.md` — bugs, hidden constraints, architectural risks
- `BLIND-SPOTS.md` — undocumented systems (thing structure, fixture subtypes, OMP pipeline)
- `MODULE-ANALYSIS.md` — full module inventory, dependency map, serialization pipeline
- `CLAUDE-BRIDGE.md` — complete bridge API reference
- `DEEP-DIVE-NOTES.md` — analysis of DNA/character system, texture deformation, UI flow
- `AI-COLLABORATION-PLAN.md` — strategy and completed phases
- `TOOLING-SETUP.md` — dev tool setup (luacheck, busted, profiling)
- `TOOLING-IDEAS.md` — proposed observability tools (not yet implemented)
- `done/PROJECT.md` — original project overview (outdated, kept for reference)
- `done/TODO-BRIDGE.md` — bridge feature wishlist (mostly implemented)
