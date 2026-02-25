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

Busted is the primary test framework. Specs live in `spec/`.

### Running specs

```bash
# Pure unit specs (no LÖVE needed)
busted spec/                              # all pure specs
busted spec/math-utils_spec.lua           # single file

# Full suite including LÖVE integration tests
love . --specs                            # all specs (pure + physics + integration)
love . --specs spec/physics_spec.lua      # single file

# Via the bridge (while app is running)
curl -X POST localhost:8001/specs                                              # run all
curl -X POST localhost:8001/specs -d '{"target":"spec/physics_spec.lua"}'      # single file
curl -X POST localhost:8001/specs -d '{"fresh":true}'                          # clear cached src.* modules first
```

### Spec conventions

- Pure specs (math, utils, shapes): work everywhere, no guard needed
- LÖVE-dependent specs (physics, rendering): start with `if not love then return end`
- Integration specs that test src modules against live state: use `fresh:true` via bridge or manage setup/teardown carefully
- Spec files: `spec/<module>_spec.lua` (e.g. `spec/shapes_spec.lua`)

### Setup

Busted must be installed for Lua 5.1 (LuaJIT):
```bash
luarocks --lua-version 5.1 install busted
```

### Legacy

`lua tests/run.lua` runs the old mini-test suite (17 tests). Still works but busted is preferred for new tests.

## Luacheck

```bash
luacheck src/ main.lua --std "lua51+love" --only 111 112   # check global leaks (currently 0)
luacheck src/ main.lua --std "lua51+love"                   # full check (0 warnings, 0 errors)
```

All globals have been converted to explicit `local require()` calls. Luacheck is fully clean: **0 warnings / 0 errors** across 41 files (down from 628 warnings).

## Architecture

- `main.lua` — entry point, keybindings, UI callbacks
- `src/` — core modules (playtime-ui, object-manager, io, joints, etc.)
- `claudetools/` — dev tools (e.g. find-forward-refs.lua)
- `vendor/` — third-party libs (claude-bridge, lurker, dkjson, ProFi, jprof, loveblobs, etc.)
- `scripts/` — scene scripts (.playtime.lua) + scene data (.playtime.json)
- `textures/` — character textures (~290 files, OMP system: outline + mask + pattern)

### Key modules
- `src/object-manager.lua` — body creation/destruction/recreation
- `src/io.lua` — save/load, clone
- `src/playtime-ui.lua` — editor UI orchestrator (~2900 lines, see "UI cleanup status" below)
- `src/ui/` — extracted UI modules (all.lua, textinput.lua, world-settings.lua, joint-update.lua)
- `src/physics/` — Box2D modules (box2d-draw, box2d-draw-textured, box2d-pointerjoints, physics-callbacks, snap)
- `src/physics/box2d-draw-textured.lua` — textured rendering, OMP compositing
- `src/physics/snap.lua` — proximity-based snap joints
- `src/joints.lua` — joint creation/recreation
- `src/registry.lua` — central registry for bodies, joints, sfixtures
- `src/character-manager.lua` — character DNA system, body part assembly
- `src/character-experiments.lua` — character experiment keybindings (extracted from main.lua)
- `src/game-loop.lua` — fixed-timestep love.run() with panic detection (extracted from main.lua)
- `src/state.lua` — shared app state
- `src/math-utils.lua` — shared math utilities (clamp, sign, lerp, distance, etc.)
- `src/utils.lua` — general utilities (deepCopy, round, randomHexColor, etc.)
- `src/shapes.lua` — shape generation (rect, capsule, polygon, etc.)

### No classes/OOP — modules return tables of functions.

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
- **Snap module**: `activeSnapJoints` (not `mySnapJoints`), `snapInfo`/`snapInfoA`/`snapInfoB` (not `it`/`it1`/`it2`)
- **Shape data**: `vertices` and `dimensions` as keys (not `v`/`d`), `vertices` for vertex arrays (not `vv`)
- **Body/mesh data**: `bodyData`/`meshData` (not `bud`/`mud`)
- **`ud`**: acceptable shorthand for `getUserData()` — used consistently across the codebase
- **`thing`**: the runtime property bag on body userData — persisted indirectly (decomposed on save, reconstructed on load)
- **`extra`, `subtype`, `scriptmeta`**: persisted in `.playtime.json` — do not rename without migration

## UI cleanup status

### Layout helpers (in src/ui/all.lua)
- `ui.alignedLabel(x, y, text, color)` — vertically centers label within a row. Use instead of `ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ...)`
- `ui.sameLine(spacing)` — returns x, y to place the next widget to the right of the previous one (default spacing=10). Widgets (button, checkbox, textinput, sliderWithInput) track their cursor via `ui.setCursor()`.

### What's been done
- Patch layer dedup: patch1/patch2/patch3 accordions collapsed into `drawPatchAccordion(layer)`
- 23 manual `x + offset` patterns converted to `ui.sameLine()`
- 36 label alignment patterns converted to `ui.alignedLabel()`

### Remaining ~19 `x + offset` patterns (intentionally kept)
These are special cases not suited for sameLine: dead code (button grid inside `if false`), tiny internal offsets inside handlePaletteAndHex/handleURLInput helpers (20px color swatch + textinput), overlay labels on sliders, reverse widget order (checkbox at x, slider at x+50).

### Pick-up points for further cleanup

**Luacheck: fully clean (0 warnings)**

**UI file extractions (playtime-ui.lua ~2900 lines → 648 line orchestrator):**
Ordered by ease/risk, each function is self-contained and has smoke test coverage:
1. ~~`drawJointUpdateUI()` (413 lines) → `src/ui/joint-update.lua`~~ — **done**
2. ~~`drawWorldSettingsUI()` (136 lines) → `src/ui/world-settings.lua`~~ — **done**
3. ~~`drawAddShapeUI()` (146 lines) → `src/ui/shape-panel.lua`~~ — **done**
4. ~~`drawRecordingUI()` (137 lines) → `src/ui/recording-panel.lua`~~ — **done**
5. ~~`drawSelectedSFixture()` (1249 lines) → `src/ui/sfixture-editor.lua`~~ — **done**
6. ~~`drawUpdateSelectedObjectUI()` (603 lines) → `src/ui/body-editor.lua`~~ — **done**
7. Small panels (drawAddJointUI 29L, drawSelectedBodiesUI 68L, drawBGSettingsUI 44L) — trivial

**Extraction pattern:** modules return `lib = {}` table, live in `src/ui/`. Accordion state tables (`accordionStatesSF`, `accordionStatesSO`, `accordeonStatesAS`) moved with their respective extracted modules.

**Smoke tests:** `spec/ui-smoke_spec.lua` (30 tests) covers all panels including sfixture subtypes, joint types, and combined panel states. Run with `love . --specs spec/ui-smoke_spec.lua`.
