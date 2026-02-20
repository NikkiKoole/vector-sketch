# Plan of Attack

A concrete, ordered sequence of work. Each phase builds on the previous one. The ordering is designed to maximize safety: early phases make later phases less risky by adding verification tools.

---

## Guiding Principles

1. **Never change behavior and structure in the same step** — Fix a bug OR refactor, not both at once
2. **Add tests before changing code** — Tests catch regressions from the changes that follow
3. **Each step should be independently committable** — If we stop halfway, nothing is left broken
4. **The app must run after every step** — You verify visually, I verify via tests/tools
5. **Boring changes first** — Mechanical fixes (globals, dead code) before design changes (DNA refactor, UI split)

---

## Phase 0: Housekeeping (1-2 sessions, near-zero risk)

Things that can't break anything. Pure deletion, trivial fixes, and tooling setup.

### 0.1 Delete dead files

| Action | What |
|--------|------|
| Delete | `src/polylineOLD.lua` (392 lines) |
| Delete | `temp/OLDOLD-dna.lua` (14KB) |
| Delete | `temp/OLDOLD-guycreation.lua` (44KB) |
| Delete | `output.md` (~551KB generated file) |
| Delete | `profilingReportOLD2.txt` through `profilingReportOLD5.txt` |
| Delete | `scripts/straightOLD.playtime.lua` |
| Delete | `scripts/bettertOLD.playtime.json` |
| Decide | `playtime-files/meta.playtime.json` — ask you if it's needed |

**Risk**: Zero. These files aren't required by anything.
**Verification**: `love .` still starts. `love . --test` still passes.
**Time**: 5 minutes.

### 0.2 Delete dead code inside active files

| Action | File | What |
|--------|------|------|
| Delete | `box2d-draw-textured.lua` | `texturedCurveOLD2()` (~45 lines at 705) |
| Delete | `box2d-draw-textured.lua` | `texturedCurveOLD()` (~50 lines at 809) |
| Delete | `box2d-draw-textured.lua` | `drawSquishableHairOverOLD()` |
| Delete | `box2d-draw-textured.lua` | `doubleControlPointsOld()` |
| Delete | `keep-angle.lua` | First `rotateBodyTowards` definition (lines 4-19, shadowed by second) |
| Fix | `joints.lua:104` | Replace `print('apjspaiosjdposdjf')` with `logger:error("Cannot create joint: bodyA and bodyB are the same")` |
| Remove | `joints.lua:266,296` | `if true then` wrappers (keep the contents) |
| Remove | `box2d-draw-textured.lua:318,358,495` | `if true then` wrappers (keep the contents) |

**Risk**: Low. The OLD functions aren't called. The duplicate `rotateBodyTowards` shadows the first. The `if true` blocks are no-ops.
**Verification**: `love .` — run the app, load a scene with textured bodies, verify rendering looks the same.
**Time**: 15-30 minutes.

### 0.3 Check spec/ tests — DONE

~~Run the busted tests to see if they pass.~~

**Result**: All 98 busted tests pass in 0.1 seconds. The mini-test suite (17 tests) also passes. Both frameworks are healthy. Busted covers math-utils and utils comprehensively (~6x more tests than mini-test).

**Decision**: Keep both. Busted is the stronger framework for new tests.

### 0.4 Set up luacheck — DONE

~~Install luacheck, create `.luacheckrc`, run once to get baseline.~~

**Result**: Luacheck found **1490 warnings / 0 errors across 34 files**, including:
- **88 W111** (setting non-standard global variable) — more than double our manual estimate of ~40
- **786 W113** (accessing undefined global) — using globals without require
- **206 W211** (unused local variable)
- **58 W212** (unused function argument)
- **36 W411** (variable shadowing)
- Worst file: playtime-ui.lua with 708 warnings (half the total)
- New discoveries: `x`/`y` leaking as globals in ~10 locations in playtime-ui.lua

The `.luacheckrc` config from TOOLING-SETUP.md should be created to get a cleaner baseline with known globals whitelisted.

### 0.5 Set up hot reload (lurker + lovebird)

Copy `vendor/lurker.lua` and `vendor/lume.lua` from the parent vector-sketch project (or adjust require paths). Add to main.lua:

```lua
local lurker = require('vendor.lurker')
-- In love.update:
lurker.update()
```

Optionally, also add lovebird for browser-based REPL:
```lua
local lovebird = require('vendor.lovebird')
-- In love.update:
lovebird.update()
-- Then open http://localhost:8000 in a browser
```

**Why now**: Hot reload makes every subsequent phase faster and safer. Edit a file → see the result live → no restart needed. Lovebird lets us query runtime state from a browser, which replaces the need for some custom CLI tools (Phase 4).

**Risk**: Zero — lurker is a read-only file watcher. Lovebird is an opt-in HTTP server.
**Prerequisite**: None, but becomes much more useful after Phase 1 (global leaks fixed = clean hot swaps).
**Time**: 15 minutes.

---

## Phase 1: Fix All Global Leaks (88 leaks, 1-2 sessions, low risk)

Luacheck found **88 W111 warnings** (setting non-standard global variable) — more than double our manual estimate of ~40. Each fix is adding `local` to a function or variable definition. Mechanical, greppable, individually testable.

### Why this is first

Global leaks are the single biggest source of potential silent bugs. Every other phase involves editing files — if a global named `add` or `inside` or `x` is silently shadowing something, we'll get mysterious failures when refactoring. Fixing this first means every subsequent change happens on solid ground.

**Also**: Fixing globals directly unlocks reliable hot reload (Phase 0.5). Lurker can only swap functions that live in module tables — global functions bypass it entirely. The sooner globals are fixed, the sooner we get live code editing.

### Order within this phase

**Round 1 — Critical globals (the ones most likely to actually clash):**

| File | Function | Fix |
|------|----------|-----|
| `character-manager.lua:102` | `add` | → `local function add(...)` |
| `math-utils.lua:42` | `lerp` | → `local function lerp(...)` (keep `lib.lerp` at 1235) |
| `math-utils.lua:875` | `inside` | → `local function inside(...)` |
| `math-utils.lua:879` | `intersection` | → `local function intersection(...)` |

**Verification**: `love . --test` and load a scene with characters (uses `add`, `lerp`).

**Round 2 — Module-level globals (wrong but unlikely to clash):**

All remaining leaks in: `snap.lua`, `keep-angle.lua`, `object-manager.lua`, `joints.lua`, `script.lua`, `scene-loader.lua`, `camera.lua`, `editor-render.lua`, `box2d-draw-textured.lua` (13 functions), `character-manager.lua` (2 more).

For each: grep to confirm it's only used within that file, then add `local`.

**Round 3 — playtime-ui.lua globals (largest batch):**

Luacheck found playtime-ui.lua has the most global leaks, including:
- 9 nested function definitions without `local` (updateOffsetA, updateOffsetB, handlePaletteAndHex, handleURLInput, patchTransformUI, combineImageUI, flipWholeUI, renderDistances, inArray)
- `x` and `y` leaking as globals in ~10 locations (loop variables, coordinates)
- Other variable leaks

These are trickier because they're defined inside other functions. Each needs `local` added at the definition site. The `x`/`y` leaks are especially dangerous — they silently overwrite any other `x`/`y` in global scope every frame.

**Verification method**: Run `luacheck src/ main.lua --only 111` after each round — watch the W111 count drop from 88 toward zero. This is machine-verified, no manual checking needed. Also run the app and exercise affected features.

**Risk**: Low per change. Each is a one-keyword addition. If something breaks, the error message will immediately say "attempt to call a nil value" pointing at the exact line that expected the global.
**Time**: 2-3 hours total (more than originally estimated given 88 vs ~40 leaks).

---

## Phase 2: Tests & Logger Singleton (1-2 sessions, zero behavioral risk)

### 2.1 Make logger a singleton

Change `logger.lua` to return an instance instead of the class:

```lua
-- Bottom of logger.lua, change:
return Logger
-- To:
local instance = Logger:new()
return instance
```

Then in every file that uses `logger` as a global, add:
```lua
local logger = require 'src.logger'
```

And remove `logger = Logger:new()` from main.lua.

**Why now**: This unblocks adding `require` statements everywhere (Phase 3), and is needed before any module can properly require its own logger.
**Risk**: Low — the logger API doesn't change, just how you get the instance.
**Verification**: `love .` — check that log output still appears.
**Time**: 30 minutes.

### 2.2 Add unit tests for pure modules

Create test files following the existing `tests/unit/test_math_utils.lua` pattern:

| File | What to test | Est. tests |
|------|-------------|-----------|
| `tests/unit/test_utils.lua` | `deepCopy`, `shallowCopy`, `sanitizeString`, `round_to_decimals`, `map`, `tableConcat`, `findByField` | ~20 |
| `tests/unit/test_shapes.lua` | `makePolygonVertices`, `capsuleXY`, `torso`, `approximateCircle`, `ribbon` | ~15 |
| `tests/unit/test_uuid.lua` | Format, uniqueness, base62 encoding | ~5 |

**Why now**: These tests protect the pure functions we'll rely on in every later phase. If a refactor accidentally changes how `deepCopy` handles cycles or how `capsuleXY` generates vertices, we catch it immediately.
**Risk**: Zero — only adding files, not changing existing code.
**Verification**: `lua tests/run.lua` — all tests pass.
**Time**: 1-2 hours.

### 2.3 Add save/load round-trip integration test

```lua
-- tests/integration/test_io_roundtrip.lua
-- For each test scene:
--   1. Load scene
--   2. gatherSaveData → table1
--   3. Save to temp file
--   4. Load temp file
--   5. gatherSaveData → table2
--   6. Deep-compare table1 vs table2
--   7. Report differences
```

This is the single highest-value integration test. It will immediately tell us:
- Whether the known vertices-after-load bug is real
- Whether `sharedFixtureData.sensor` survives round-trip
- Whether any fixture extra fields are lost

**Risk**: Zero — read-only test, doesn't modify scenes.
**Verification**: `love . --test` — see which scenes pass/fail round-trip.
**Time**: 1-2 hours.

---

## Phase 3: Explicit Requires (2-3 sessions, medium risk)

Replace all global module access with explicit `require` statements.

### Why this comes after tests

If adding a `require` creates a circular dependency or changes initialization order, the tests from Phase 2 catch the regression.

### Order

Do one module at a time. For each:
1. Grep for all uses of the global (e.g., `registry.` across all files)
2. Add `local registry = require 'src.registry'` to each file that uses it
3. Remove the global assignment from `main.lua`
4. Run tests, run app

| Global | Used in ~N files | Difficulty |
|--------|-----------------|-----------|
| `inspect` | ~5 | Easy — just add vendor require |
| `benchmarks` | ~2 | Easy |
| `keep_angle` | ~1 (main.lua) | Easy — barely used outside main |
| `registry` | ~10 | Medium — many users but already a module |
| `snap` | ~3 | Medium |
| `logger` | ~15 | Already done in 2.1 |
| `prof`/`PROF_CAPTURE`/`ProFi` | ~5 | Medium — need conditional require pattern |

**Risk**: Medium. Circular dependencies could surface (especially around the object-manager ↔ snap path). If a circular dependency appears, we'll need to break it by extracting shared logic.
**Verification**: After each global is removed, run tests and app.
**Time**: 2-3 hours total.

---

## Phase 4: Observability Tools (1-2 sessions, low risk)

Build tools for runtime inspection. If lovebird was set up in Phase 0.5, some of these can be lovebird commands instead of CLI tools — the running game already has all the state loaded.

### 4.1 Scene Validator

**Option A — CLI** (`love . --validate`): New file `src/validator.lua`, entry point alongside existing `--test`.
**Option B — Lovebird command**: Run validation in the browser REPL against the live scene.
**Option C — Both**: Validator module that can be called from CLI or lovebird.

Checks:
- Every joint's bodyA/bodyB exist in registry
- Every registry ID maps to a live object
- All sfixtures have sensor=true
- No NaN/inf in positions/velocities
- No duplicate IDs
- Fixture ordering invariant holds
- Texture URLs resolve to files

**Why now**: Every subsequent phase changes code that could break scenes. Having a validator means we can check after each change.
**Risk**: Low — new file, only reads state.
**Time**: 1-2 hours.

### 4.2 State Dump

**With lovebird**: Much of this is already possible via the browser REPL — `inspect(body:getUserData())`, `registry:get(id)`, `world:getBodyCount()`, etc. A dedicated dump function adds structured output.

New file: `src/cli-dump.lua`. Extends `gatherSaveData` with runtime physics state.

**Risk**: Low — new file.
**Time**: 1 hour.

### 4.3 Screenshot + Metadata (F12 keybinding)

Add to `main.lua`: capture screenshot + write JSON companion file.

**Risk**: Very low — single keybinding addition.
**Time**: 30 minutes.

---

## Phase 5: Fix Known Bugs (1-2 sessions, targeted risk)

Now that we have tests and validator, fix the bugs we've documented.

| Bug | File | Fix | Risk |
|-----|------|-----|------|
| `not doneJoints[ud.id] == true` | io.lua:884 | → `if not doneJoints[ud.id] then` | Low — the current code happens to work |
| Clone OMP not marked dirty | io.lua (cloneSelection) | Set `ud.extra.dirty = true` after clone | Low |
| `sharedFixtureData.sensor` | io.lua:499 | Find first non-userData fixture explicitly | Medium — need to understand the fixture ordering |
| Duplicate key == 'u' handler | main.lua:722,738 | Ask you which one is correct, delete the other | Low (needs your input) |
| endNode mismatch in DNA | character-manager.lua:323,339 | `endNode = 'lfoot'` → `'lhand'`/`'rhand'` | Low but needs visual verification |
| Redundant reference angle | io.lua:932 | `local newRef = newJoint:getReferenceAngle()` | Very low |
| Unused `swapBodies` param | joints.lua:162 | Remove from signature | Very low |

**Verification**: Round-trip test should show sensor and vertices surviving. Validator catches orphaned joints. Visual check for character endNode fix.
**Time**: 1-2 hours.

---

## Phase 6: Extract from main.lua (1 session, medium risk)

main.lua is 999 lines. Extract the biggest chunks.

### 6.1 Extract debug keybindings (~335 lines)

Move lines 480-815 (character experiment keys) to `src/debug-keys.lua`.

```lua
-- In main.lua, replace 335 lines with:
local debugKeys = require 'src.debug-keys'
-- ... in love.keypressed:
debugKeys.handle(key, humanoidInstance)
```

**Risk**: Low — these are isolated if/elseif blocks with no interactions between them.
**Time**: 30 minutes.

### 6.2 Extract physics callbacks (~15 lines)

Move `beginContact`/`endContact`/`preSolve`/`postSolve` globals to `src/physics-callbacks.lua`.

**Risk**: Low — thin wrappers around script.call.
**Time**: 15 minutes.

### 6.3 Consider: Extract game loop

The fixed-timestep loop (lines 893-998) is self-contained. Could move to `src/game-loop.lua`. But this is riskier because it wires into `love.run()`.

**Risk**: Medium — touching the game loop can cause subtle timing issues.
**Decision**: Only do this if main.lua is still too big after 6.1 and 6.2. It'll be down to ~650 lines which is manageable.

---

## Phase 7: Structural Improvements (multi-session, higher risk)

These are the changes that actually improve the architecture. Each one is independently valuable — do them in whatever order matches what you're working on next.

### 7a. Move snap state into state.lua

`snap.lua` has hidden module-level state (`snapFixtures`, `mySnapJoints`, `cooldownList`). Move these into `state.snap` so they're visible to serialization, debugging, and the validator.

**Risk**: Medium — snap behavior must remain identical.
**Verification**: Load a snap scene, verify joints still form/break. Validator checks snap state.
**Prerequisite**: Phase 1 (global leaks fixed in snap.lua).
**Time**: 1 hour.

### 7b. Fixture type registry

Replace the 4-file if/elseif chains for fixture subtypes with a `src/fixture-types.lua` registry (design in MODULE-ANALYSIS.md).

**Risk**: High — touches fixtures.lua, io.lua, box2d-draw-textured.lua, playtime-ui.lua.
**Verification**: Round-trip test, validator, visual check of all fixture types.
**Prerequisite**: Phases 1-5 (globals fixed, tests exist, bugs fixed).
**Time**: 4-6 hours across sessions.

### 7c. Mode handler table for input-manager

Replace the if/elseif chain in `handlePointer` with a table-dispatch pattern.

**Risk**: Medium — input handling is sensitive to ordering.
**Verification**: Test every editing mode manually (draw polygon, draw circle, draw capsule, etc.).
**Prerequisite**: Phase 1 (globals fixed).
**Time**: 2-3 hours.

### 7d. DNA topology-as-data

The big one from DEEP-DIVE-NOTES.md. Move parent/child relationships and attachment points from code (3 functions, ~560 lines) into the DNA template data.

**Risk**: High — the character system is the most complex part of the codebase.
**Verification**: Character assembly report tool (TOOLING-IDEAS.md Tool 3), visual inspection of created characters, round-trip test on character scenes.
**Prerequisite**: Phases 1-4 (especially the validator and dump tools to compare before/after).
**Time**: Multiple sessions. Start with extracting `getAttachmentPoint` as a data-driven resolver, then migrate parts one at a time.

### 7e. Extract world-settings panel from playtime-ui.lua

Start the UI split with the performance bottleneck: `drawWorldSettingsUI` (42% of frame time).

**Risk**: Medium — extracting one panel is safer than splitting the whole file.
**Verification**: Open world settings, verify all sliders/checkboxes work. Profile to confirm perf improvement.
**Prerequisite**: Phase 1 (global leaks in playtime-ui.lua fixed).
**Time**: 2-3 hours.

---

## Phase 8: Performance & Polish (as needed)

Only do these when they matter for what you're building.

| Task | Trigger | Time |
|------|---------|------|
| Cache drawable list (dirty flag) | Noticing frame drops with many bodies | 2-3 hours |
| Move deformWorldVerts to update | Working on skeletal deformation | 1-2 hours |
| Fix UV pipeline (vertex-index based) | Working on meshusert/uvusert | 2-3 hours |
| Canvas pooling for OMP | Many textured characters causing GPU memory issues | 1-2 hours |
| Image cache clearing | Long sessions causing memory growth | 1 hour |
| Add stable sort tiebreaker | Noticing z-fighting flicker | 30 minutes |

---

## Visual Overview

```
Phase 0 ─── Housekeeping ──────────── [zero risk, 30 min]
  │          delete dead files/code
  │          ✓ busted: 98 tests pass
  │          ✓ luacheck: 1490 warnings baselined
  │          + set up lurker (hot reload) + lovebird (browser REPL)
  ▼
Phase 1 ─── Fix 88 Global Leaks ───── [low risk, 2-3 hrs]
  │          add 'local' keyword
  │          verify: luacheck --only 111 → zero warnings
  │          UNLOCKS: reliable hot reload via lurker
  ▼
Phase 2 ─── Tests + Logger ────────── [zero risk, 2-3 hrs]
  │          unit tests, logger singleton, round-trip test
  ▼
Phase 3 ─── Explicit Requires ─────── [medium risk, 2-3 hrs]
  │          remove global module access
  │          verify: luacheck --only 113 count drops
  ▼
Phase 4 ─── Observability Tools ───── [low risk, 2-3 hrs]
  │          validator, dump, screenshot
  │          (some replaceable by lovebird REPL commands)
  ▼
Phase 5 ─── Fix Known Bugs ────────── [targeted risk, 1-2 hrs]
  │          clone bugs, sensor flag, endNode, etc.
  ▼
Phase 6 ─── Extract from main.lua ─── [medium risk, 1 hr]
  │          debug keys, physics callbacks
  ▼
Phase 7 ─── Structural Improvements ─ [higher risk, multi-session]
  │          (pick based on what you're building next)
  │    ├── 7a. Snap state → state.lua
  │    ├── 7b. Fixture type registry
  │    ├── 7c. Mode handler table
  │    ├── 7d. DNA topology-as-data
  │    └── 7e. Extract world-settings panel
  ▼
Phase 8 ─── Performance & Polish ──── [as needed]
             caching, memory, UV fix
             (use jprof/AppleCake to identify targets)
```

---

## Decision Points

Places where we need your input before proceeding:

| Phase | Question | Status |
|-------|----------|--------|
| 0.1 | Is `playtime-files/meta.playtime.json` needed? Can we delete it? | **Open** |
| 0.3 | Do you have `busted` installed? Should we try the spec/ tests? | **RESOLVED** — busted is installed, 98 tests pass |
| 0.5 | Want lurker + lovebird set up for hot reload and browser REPL? | **Open** |
| 2.3 | Which scene files are the best test cases? (We'll use them for round-trip) | **Open** |
| 5 | The duplicate `if key == 'u'` handler (main.lua:722 vs 738) — which one is correct? | **Open** |
| 5 | The `endNode = 'lfoot'` on arm parts — is this intentional or a bug? | **Open** |
| 7 | Which structural improvement matters most for what you want to build next? | **Open** |

---

## What Each Phase Unlocks

| After Phase | What becomes possible |
|-------------|----------------------|
| 0 | Less noise when reading code. Luacheck gives exact issue count. Busted spec/ tests verified working. Hot reload available (if 0.5 done). |
| 1 | Grep actually works for function usage; no surprise name collisions. **Hot reload becomes reliable** — lurker can swap all module functions cleanly. `luacheck --only 111` reports zero globals. |
| 2 | Can verify math functions, shape generation, and save/load correctness without running app |
| 3 | Every file shows its full dependency list at the top; can reason about modules in isolation |
| 4 | AI can inspect runtime state via lovebird, validate scenes, get context from screenshots |
| 5 | Known bugs are fixed; save/load is more reliable |
| 6 | main.lua is readable (~650 lines); debug code is separated |
| 7a | Snap system is inspectable and serializable |
| 7b | Adding a new fixture type = one file instead of four |
| 7c | Adding a new editing mode = one function instead of a branch in a 392-line function |
| 7d | Adding a new body part = one data entry instead of editing 3 functions |
| 7e | World settings panel is isolated and can be performance-optimized |

---

## Estimated Total Time

| Phase | Effort | Notes |
|-------|--------|-------|
| 0 | 45 minutes | Includes lurker/lovebird setup (15 min) |
| 1 | 2-3 hours | Updated: 88 globals, not ~40 |
| 2 | 2-3 hours | |
| 3 | 2-3 hours | |
| 4 | 2-3 hours | Less if lovebird replaces some CLI tools |
| 5 | 1-2 hours | |
| 6 | 1 hour | |
| **Phases 0-6 total** | **~11-16 hours across sessions** | |
| 7 (each) | 2-6 hours | |
| 8 (each) | 30 min - 3 hours | |

Phases 0-6 are the "solidification foundation." After those, the codebase is clean, tested, observable, and safe to make bigger changes to. Phases 7-8 are driven by what feature work you want to do next.

**AI workflow after Phase 1**: With lurker + lovebird + luacheck in place, the development loop becomes: edit file → lurker hot-swaps it → `curl` lovebird to verify → run `luacheck` to check for regressions. No browser needed — lovebird accepts `curl` POST requests with Lua code and returns output via GET. Claude can query the running game directly from the terminal. See TOOLING-SETUP.md Section 8 for the exact HTTP protocol.

---

## All Research Documents

For reference, here's everything we've written and what it covers:

| Document | Purpose | Read when... |
|----------|---------|-------------|
| `PROJECT.md` | Original architecture overview | Starting a new session, need the big picture |
| `AI-COLLABORATION-PLAN.md` | What makes AI collab hard + fix priorities | Planning test/refactor work |
| `DEEP-DIVE-NOTES.md` | Pain point analysis: DNA, textures, UI | Working on character system, rendering, or editor UI |
| `TOOLING-IDEAS.md` | 6 custom tools for runtime inspection | Building CLI tools (Phase 4) |
| `MODULE-ANALYSIS.md` | Full module inventory, dependency map, global leaks | Looking up any specific module or cross-cutting concern |
| `BLIND-SPOTS.md` | Undocumented systems: thing, fixtures, OMP, skinning | Working on serialization, textures, or deformation |
| `DEEPER-ISSUES.md` | Bugs, hidden constraints, state mutation chaos | Debugging weird behavior or planning clone/joint work |
| `TOOLING-SETUP.md` | External tools: luacheck, LuaLS, busted, profiling, hot reload | Setting up dev environment, choosing tools |
| `PLAN-OF-ATTACK.md` | This document — ordered work plan | Starting a work session, deciding what to do next |
