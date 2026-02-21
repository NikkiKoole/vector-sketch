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

### 0.1 Delete dead files — DONE

All dead files deleted:
- ~~`src/polylineOLD.lua`~~ (392 lines)
- ~~`temp/OLDOLD-dna.lua`~~ (14KB)
- ~~`temp/OLDOLD-guycreation.lua`~~ (44KB)
- ~~`output.md`~~ (~551KB)
- ~~`profilingReportOLD2-5.txt`~~
- ~~`scripts/straightOLD.playtime.lua`~~
- ~~`scripts/bettertOLD.playtime.json`~~
- `playtime-files/meta.playtime.json` — still open, not yet decided

**Total deleted**: ~17,500 lines across 9 files.

### 0.2 Delete dead code inside active files — DONE

All items completed:
- ~~`texturedCurveOLD2()`~~ deleted (box2d-draw-textured.lua)
- ~~`texturedCurveOLD()`~~ deleted
- ~~`drawSquishableHairOverOLD()`~~ deleted
- ~~`doubleControlPointsOld()`~~ deleted
- ~~`rotateBodyTowards` duplicate~~ renamed to `rotateBodyTowardsSimple`
- ~~`print('apjspaiosjdposdjf')`~~ replaced with `logger:error()`
- ~~`if true then` wrappers~~ removed (5 total: 2 in joints.lua, 3 in box2d-draw-textured.lua)
- ~~Character experiment keybindings~~ extracted to `src/character-experiments.lua`
- ~~Dead `key == 'p'` benchmark block~~ removed from main.lua

**Total deleted**: ~850 lines of dead/old code.

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

### 0.5 Set up hot reload (lurker + lovebird) — DONE

Lurker was already integrated. Claude bridge (port 8001) replaces much of lovebird's functionality.

Additional tooling added:
- `playtime.sh` — app lifecycle management (start/stop/restart/status)
- `CLAUDE.md` — project guide for working across machines
- Bridge profiling endpoints: `POST /profile/benchmark` and `POST /profile/frames`

---

## Phase 1: Fix All Global Leaks — DONE

Fixed **68 global leaks** across 12 files (87 → 19 remaining). The 19 remaining are intentional globals in main.lua (logger, inspect, registry, ProFi, etc.) and script.lua (sandbox globals). These require a larger refactor (Phase 3: Explicit Requires) and were left intentionally.

Key tricky fixes:
- playtime-ui.lua `drawAccordion` pattern: `x, y` shared between closures via upvalue
- scene-loader.lua: `getFiledata` needed to be moved before its first caller
- 33 fixes in playtime-ui.lua alone, verified via before/after screenshots

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

| Bug | File | Fix | Status |
|-----|------|-----|--------|
| `not doneJoints[ud.id] == true` | io.lua:884 | → `if not doneJoints[ud.id] then` | **DONE** |
| Debug print gibberish | joints.lua:104 | → `logger:error(...)` | **DONE** |
| Duplicate key == 'u' handler | main.lua:722,738 | Merged into single block | **DONE** |
| Clone OMP not marked dirty | io.lua (cloneSelection) | Set `ud.extra.dirty = true` after clone | **Open** |
| Redundant reference angle | io.lua:932 | `local newRef = newJoint:getReferenceAngle()` | **Open** |
| Unused `swapBodies` param | joints.lua:162 | Remove from signature | **Open** |
| `sharedFixtureData.sensor` | io.lua:499 | Find first non-userData fixture explicitly | **Open** — needs investigation |
| endNode mismatch in DNA | character-manager.lua:323,339 | `endNode = 'lfoot'` → `'lhand'`/`'rhand'` | **Open** — needs visual verification |

---

## Phase 6: Extract from main.lua (1 session, medium risk)

### 6.1 Extract debug keybindings — DONE

Extracted to `src/character-experiments.lua` (~340 lines removed from main.lua).

### 6.2 Extract physics callbacks (~15 lines)

Move `beginContact`/`endContact`/`preSolve`/`postSolve` globals to `src/physics-callbacks.lua`.

**Risk**: Low — thin wrappers around script.call.
**Status**: Open.

### 6.3 Consider: Extract game loop

The fixed-timestep loop is self-contained. Could move to `src/game-loop.lua`.

**Risk**: Medium — touching the game loop can cause subtle timing issues.
**Status**: Open — main.lua is now ~660 lines which is manageable.

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
Phase 0 ─── Housekeeping ──────────── ✅ DONE
  │          ✓ dead files deleted (17,500 lines)
  │          ✓ dead code removed (850 lines)
  │          ✓ busted: 98 tests pass
  │          ✓ luacheck baselined
  │          ✓ lurker hot reload active
  │          ✓ playtime.sh lifecycle helper
  │          ✓ CLAUDE.md project guide
  │          ✓ bridge profiling endpoints
  ▼
Phase 1 ─── Fix Global Leaks ──────── ✅ DONE (87 → 19 intentional)
  │          ✓ 68 globals fixed across 12 files
  │          ✓ verified via luacheck + screenshots
  ▼
Phase 2 ─── Tests + Logger ────────── not started
  │          unit tests, logger singleton, round-trip test
  ▼
Phase 3 ─── Explicit Requires ─────── not started
  │          remove global module access (19 remaining)
  ▼
Phase 4 ─── Observability Tools ───── partially done (bridge covers most)
  │          ✓ bridge: eval, console, errors, screenshots, profiling
  │          - scene validator: not started
  ▼
Phase 5 ─── Fix Known Bugs ────────── partially done (3/8 fixed)
  │          ✓ io.lua precedence, joints.lua gibberish, duplicate key=='u'
  │          - clone OMP dirty, reference angle, swapBodies, sensor, endNode
  ▼
Phase 6 ─── Extract from main.lua ─── partially done (6.1 done)
  │          ✓ character experiments extracted
  │          - physics callbacks: not started
  ▼
Phase 7 ─── Structural Improvements ─ not started
  │    ├── 7a. Snap state → state.lua
  │    ├── 7b. Fixture type registry
  │    ├── 7c. Mode handler table
  │    ├── 7d. DNA topology-as-data
  │    └── 7e. Extract world-settings panel
  ▼
Phase 8 ─── Performance & Polish ──── not started
             caching, memory, UV fix
             (bridge /profile/benchmark + /profile/frames available)
```

---

## Decision Points

Places where we need your input before proceeding:

| Phase | Question | Status |
|-------|----------|--------|
| 0.1 | Is `playtime-files/meta.playtime.json` needed? Can we delete it? | **Open** |
| 0.3 | Do you have `busted` installed? Should we try the spec/ tests? | **RESOLVED** — busted is installed, 98 tests pass |
| 0.5 | Want lurker + lovebird set up for hot reload and browser REPL? | **RESOLVED** — lurker active, bridge replaces lovebird |
| 2.3 | Which scene files are the best test cases? (We'll use them for round-trip) | **Open** |
| 5 | The duplicate `if key == 'u'` handler (main.lua:722 vs 738) — which one is correct? | **RESOLVED** — merged into single block |
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
