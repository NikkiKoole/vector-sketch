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
- ~~`playtime-files/meta.playtime.json`~~ moved to `scripts/meta.playtime.json`; directory removed

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

**Result**: All busted tests pass. The mini-test suite (17 tests) also passes. Both frameworks are healthy. Busted covers math-utils and utils comprehensively (~6x more tests than mini-test).

**Decision**: Busted is the primary framework. Installed for Lua 5.1 (`luarocks --lua-version 5.1 install busted`) so it runs inside LÖVE too. Three ways to run: `busted spec/` (pure, 140 tests), `love . --specs` (full, 263 tests), `POST /specs` (via bridge).

### 0.4 Set up luacheck — DONE

~~Install luacheck, create `.luacheckrc`, run once to get baseline.~~

**Result**: Luacheck initially found **1490 warnings / 0 errors across 34 files**. All warnings have since been resolved: **0 warnings / 0 errors across 35 files** (down from 628 after globals were fixed, then shadowing, unused vars, line-too-long, and misc warnings all cleared).

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

## Phase 2: Tests — MOSTLY DONE

Done using busted (not mini-test) with LÖVE integration. Went beyond the original plan.

### 2.1 Make logger a singleton — not started

Still a global. Deferred to Phase 3 (Explicit Requires).

### 2.2 Add unit tests for pure modules — DONE (exceeded plan)

Built busted-inside-LÖVE infrastructure (`run-specs.lua`, `love . --specs`, bridge `POST /specs`).

Added `_test` seams to expose local functions for testing:
- `shapes.lua` — `shapes._test` exposes all geometry builders
- `io.lua` — `io._test` exposes `needsDimProperty`, `remapAndRestoreInfluences`

| Spec file | Tests | Coverage |
|-----------|-------|----------|
| `math-utils_spec` | 56 | Geometry, paths, polygons (pre-existing) |
| `utils_spec` | 42 | deepCopy, sanitizeString, etc. (pre-existing) |
| `shapes_spec` | 63 | All geometry builders + createShape with real Box2D |
| `physics_spec` | 18 | Real physics: world, bodies, fixtures, joints, simulation |
| `io_spec` | 49 | needsDimProperty, influence remapping, gatherSaveData |
| `fixtures_spec` | 23 | Ordering invariant, all 9 sfixture subtypes, destroy |
| **Total** | **251** | standalone: 140 / LÖVE: 263 (+ 1 pending) |

**Notable finding**: Fixtures spec confirmed Box2D reorders fixtures — the ordering invariant from DEEPER-ISSUES.md is a real risk.

**Global stubs needed for tests**: `snap`, `logger`, `registry` — documents the coupling Phase 3 must fix.

### 2.3 Add save/load round-trip integration test — DONE

`io_spec.lua` tests `gatherSaveData` (dim gating, fixture data, body types, camera) plus a full round-trip test that loads **all 20 scene files**, builds a world, gathers save data, and compares bodies (count, IDs, positions, angles, types, dims, fixture counts), joints (count, IDs, types, body references), and camera state. Found and fixed a real crash bug (snap fixture at/to stale references) during development.

---

## Phase 3: Explicit Requires — ✅ DONE

All global module access replaced with explicit `local require` statements.

### What was done

1. **Phase 1** converted all 68 global leaks to local requires across 12 files
2. **Phase 3** converted the remaining 8 bare `require` statements in main.lua to explicit locals with `_` prefix (side-effect-only imports for `package.loaded` caching):
   - `src.logger`, `vendor.inspect`, `vendor.ProFi`, `src.object-manager`, `src.uuid`, `src.registry`, `src.math-utils`, `src.character-manager`

Every file now shows its full dependency list at the top. Luacheck: **0 warnings / 0 errors** across 35 files. Busted: **140/140 tests pass**.

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
| Clone OMP not marked dirty | io.lua (cloneSelection) | See detailed analysis below | **Deferred** — needs OMP image cache (Phase 8) |
| Redundant reference angle | io.lua:930-932 | Removed unused `oldRef` and `newRef` + dead logger line | **DONE** |
| Unused `swapBodies` param | joints.lua:162 | Removed from signature | **DONE** |
| Snap at/to crash on save | io.lua:541 | Stale Box2D refs crash `gatherSaveData`; added pcall guard + type check | **DONE** — found by round-trip test |
| `sharedFixtureData.sensor` | io.lua:499 | Was already fixed (loop finds non-userData fixture); cleaned up stale comment, added guard + logger warning for edge case | **DONE** |
| endNode mismatch in DNA | character-manager.lua:317,333 | `endNode = 'lfoot'` → `'lhand'`/`'rhand'` on arm connected-hair; no runtime effect (joint chains are hardcoded) but data was misleading | **DONE** |

### Clone OMP: Why This Is Deferred

**The bug**: When cloning bodies via `io.cloneSelection()`, the cloned sfixtures don't get the original's `extra` data (OMP settings, texture URLs, patches, etc.). The clone appears untextured.

**The naive fix** — deep-copy `extra` and set `dirty = true` — is dangerous:

**GPU memory cost of OMP images** (measured via bridge on a single humanoid):
- 1 humanoid = **13 composited OMP canvases** (8 texfixtures + 5 connected-textures)
- Total GPU memory per character: **~6.4 MB** (canvases range from 343 KB to 741 KB each)
- Each OMP image is created by `makeCombinedImages()` in `box2d-draw-textured.lua`: it renders outline + mask + pattern + optional patches into an ImageData via `makeTexturedCanvas()`, then converts to a `love.graphics.newImage()`
- **40 cloned characters × 6.4 MB = ~255 MB GPU memory** just for OMP textures

**Why dirty=true makes it worse**: Setting `dirty = true` on 40×13 = 520 sfixtures triggers `makeCombinedImages()` for all of them, which renders 520 canvases in a single frame — a massive frame spike on top of the memory cost.

**The real fix**: An **OMP image cache** keyed on the compositing inputs. Two clones with identical OMP settings (same URLs, same colors, same patches) produce pixel-identical images and should share one GPU texture. The infrastructure is partially there:

- `imageCache` (line 16 in box2d-draw-textured.lua) already caches **source** images by file path
- `_stripCache` (line 156) already caches triangle strip meshes by image
- What's missing: a cache for the **composited result** of `makeTexturedCanvas()`, keyed on a hash of `(bgURL, fgURL, pURL, colors, patches, flips)`

**Proposed approach** (for Phase 8):
1. Build a cache key from the OMP settings: `bgURL .. fgURL .. pURL .. tint_hex .. patch_urls ...`
2. Before calling `makeTexturedCanvas()`, check the cache — if hit, reuse the existing `love.graphics.Image`
3. On clone: copy the OMP *settings* (URLs, colors, patches) but **not** `ompImage` — set `dirty = true` — the next `makeCombinedImages()` pass will find the cache hit and reuse the image
4. Cache eviction: use weak values (`__mode = "v"`) so images get GC'd when no fixture references them

This turns 40 identical clones from 255 MB into ~6.4 MB (one shared set of images). Characters that are visually modified after cloning get their own images on-demand.

**Prerequisite**: Phase 8 "Canvas pooling for OMP" / "Image cache clearing" — this is the same work.

---

## Phase 6: Extract from main.lua (1 session, medium risk)

### 6.1 Extract debug keybindings — DONE

Extracted to `src/character-experiments.lua` (~340 lines removed from main.lua).

### 6.2 Extract physics callbacks (~15 lines)

Move `beginContact`/`endContact`/`preSolve`/`postSolve` globals to `src/physics-callbacks.lua`.

**Risk**: Low — thin wrappers around script.call.
**Status**: Open.

### 6.3 Extract game loop — DONE

Extracted both `love.run()` implementations to `src/game-loop.lua` (~150 lines removed from main.lua).
Active loop: `createFixedTimestepRun(tickrate)` with panic detection + adaptive sleep.
Old simple loop preserved as commented historical reference in the module.

Also improved `playtime.sh`: captures startup errors (kills process to flush macOS's buffered stderr),
passes `--bridge` to skip start screen, added `log` and `errors` commands.
**Status**: Open — main.lua is now ~660 lines which is manageable.

---

## Phase 7: Structural Improvements (multi-session, higher risk)

These are the changes that actually improve the architecture. Each one is independently valuable — do them in whatever order matches what you're working on next.

### 7a. Move snap state into state.lua

`snap.lua` has hidden module-level state (`snapFixtures`, `activeSnapJoints`, `cooldownList`). Move these into `state.snap` so they're visible to serialization, debugging, and the validator.

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

### 7f. Consolidate scattered utility functions

Many generic helper functions are duplicated or stranded as locals inside domain modules. Centralizing them reduces copy-paste bugs and makes them testable.

**Confirmed duplicates** (same function in multiple files):

| Function | Locations | Status |
|---|---|---|
| `rect(w, h, x, y)` | shapes.lua, fixtures.lua, playtime-ui.lua (**triplicate**) | **DONE** — exported from shapes.lua, copies replaced |
| `getCenterAndDimensions(body)` | playtime-ui.lua:39, character-manager.lua:455 (has TODO to move) | **DONE** — added to math-utils, copies replaced |
| `randomHexColor()` | character-manager.lua:57, character-experiments.lua:7 | **DONE** — moved to utils.lua, copies replaced |
| `calculateDistance` | snap.lua:206 duplicates `math-utils.lib.calculateDistance` | **DONE** — replaced with `mathutils.calculateDistance` |
| `lerp` | character-manager.lua:520 duplicates `math-utils.lib.lerp` (with clamp) | **DONE** — replaced with `mathutils.clampedLerp` |
| `makeTransformedVertices` | character-manager.lua:482 duplicates `math-utils.scalePolygonPoints` | **DONE** — replaced with `mathutils.scalePolygonPoints` |
| `tableConcat` | math-utils.lua:838 duplicates `utils.tableConcat` | **Skipped** — would add cross-module dependency, only 1 internal use |
| `getRelativePath` | main.lua:457 near-duplicate of `utils.getPathDifference` | **Skipped** — different edge case handling, only 1 call site |

**Generic functions — newly added to math-utils.lua**:

| Function | Status |
|---|---|
| `lib.clamp(x, min, max)` | **DONE** — added to math-utils, replaces local in character-manager |
| `lib.sign(value)` | **DONE** — added to math-utils, replaces local in character-manager |
| `lib.clampedLerp(a, b, t)` | **DONE** — added to math-utils (lerp with t clamped to 0..1) |
| `lib.getCenterAndDimensions(body)` | **DONE** — added to math-utils, replaces locals in playtime-ui + character-manager |
| `lib.randomHexColor()` | **DONE** — added to utils.lua, replaces locals in character-manager + character-experiments |
| `shapes.rect(w, h, x, y)` | **DONE** — exported from shapes.lua, replaces locals in fixtures + playtime-ui |

**Generic functions still missing from any shared module**:

| Function | Current location | Category |
|---|---|---|
| `getEndpoint(x, y, angle, length)` | box2d-draw.lua:32 | geometry |
| `pointInTriangle` | shapes.lua:236 | geometry |
| `cross` (2D cross product) | shapes.lua:227, polyline.lua:11 (different signatures) | geometry |
| `segmentNormal` / `normal_xy` | object-manager.lua:39, polyline.lua:10 (same thing) | geometry |
| `cyclicShift(arr, shift)` | character-manager.lua:21 | array |
| `resolveIndex` / `getIndices` | box2d-draw-textured.lua:134,138 | array |

**Remaining approach**:
1. Export `rect` from `shapes.lua`, replace copies in fixtures.lua and playtime-ui.lua
2. Move `getCenterAndDimensions` to a shared location (math-utils or a new `geometry-utils.lua`)
3. Replace remaining duplicate locals one file at a time, test after each

**Risk**: Low per change — each replacement is mechanical. Main risk is circular dependencies if geometry-utils needs something from shapes or vice versa.
**Prerequisite**: Phase 3 (explicit requires) makes this easier since imports are already cleaned up.
**Time**: 2-3 hours across sessions, can be done incrementally.

### 7g. Readability renames — ✅ DONE

Renamed unclear variables and functions across the codebase. Only runtime names were changed (persisted keys like `extra`, `subtype`, `scriptmeta`, `thing` were left alone).

**Variable renames:**
| Old | New | Files |
|-----|-----|-------|
| `eio` | `sceneIO` | playtime-ui, scene-loader, claude-bridge, io_spec |
| `it`/`it1`/`it2` | `snapInfo`/`snapInfoA`/`snapInfoB` | snap.lua |
| `mySnapJoints` | `activeSnapJoints` | snap.lua |
| `j` (joint param) | `joint` | playtime-ui.lua |
| `bud`/`mud` | `bodyData`/`meshData` | editor-render.lua |
| `vv` | `vertices` | fixtures.lua |
| `v`/`d` (shape8Dict keys) | `vertices`/`dimensions` | character-manager.lua |

**Function renames:**
| Old | New | Why |
|-----|-----|-----|
| `doJointCreateUI` | `drawJointCreateUI` | Consistent `draw` prefix |
| `doJointUpdateUI` | `drawJointUpdateUI` | Consistent `draw` prefix |
| `updateSFixtureDimensionsFunc` | `updateSFixtureDimensions` | Redundant `Func` suffix |

Naming conventions documented in CLAUDE.md.

### 7e. Extract world-settings panel from playtime-ui.lua ─── ✅ DONE

Extracted `drawWorldSettingsUI` (~138 lines) to `src/ui/world-settings.lua`.
Also moved `createSliderWithId` helper to `src/ui/all.lua` as `ui.createSliderWithId` (shared by ~50 call sites).

### 7f. Move UI files to src/ui/ subfolder + Extract drawJointUpdateUI ─── ✅ DONE

Moved `src/ui-all.lua`, `src/ui-textinput.lua`, `src/ui-world-settings.lua` into `src/ui/` subfolder.
Extracted `drawJointUpdateUI` (~413 lines) to `src/ui/joint-update.lua`.

**Verification**: luacheck 0 warnings/0 errors (38 files), busted 140/140, UI smoke tests 30/30, app restart 0 errors.

---

## Phase 8: Performance & Polish (as needed)

Only do these when they matter for what you're building.

| Task | Trigger | Time |
|------|---------|------|
| Cache drawable list (dirty flag) | Noticing frame drops with many bodies | 2-3 hours |
| Move deformWorldVerts to update | Working on skeletal deformation | 1-2 hours |
| Fix UV pipeline (vertex-index based) | Working on meshusert/uvusert | 2-3 hours |
| OMP composited image cache | Cloning characters duplicates GPU textures (~6.4 MB/char). See "Clone OMP" in Phase 5. | 2-3 hours |
| Canvas pooling for OMP | Many textured characters causing GPU memory issues | 1-2 hours |
| Image cache clearing | Long sessions causing memory growth | 1 hour |
| Add stable sort tiebreaker | Noticing z-fighting flicker | 30 minutes |

---

## Visual Overview

```
Phase 0 ─── Housekeeping ──────────── ✅ DONE
  │          ✓ dead files deleted (17,500 lines)
  │          ✓ dead code removed (850 lines)
  │          ✓ busted: 140 pure tests pass
  │          ✓ luacheck: 0 warnings / 0 errors (down from 1490 → 628 → 0)
  │          ✓ lurker hot reload active
  │          ✓ playtime.sh lifecycle helper
  │          ✓ CLAUDE.md project guide
  │          ✓ bridge profiling endpoints
  │          ✓ readability renames (see below)
  ▼
Phase 1 ─── Fix Global Leaks ──────── ✅ DONE (87 → 19 intentional)
  │          ✓ 68 globals fixed across 12 files
  │          ✓ verified via luacheck + screenshots
  ▼
Phase 2 ─── Tests ─────────────────── ✅ DONE
  │          ✓ busted-inside-LÖVE infrastructure (run-specs.lua)
  │          ✓ bridge POST /specs endpoint
  │          ✓ 6 spec files, 140 pure + LÖVE integration tests
  │          ✓ _test seams on shapes.lua and io.lua
  │          ✓ save/load round-trip: all 20 scene files tested
  │          - logger singleton: deferred to Phase 3
  ▼
Phase 3 ─── Explicit Requires ─────── ✅ DONE
  │          ✓ 8 bare requires in main.lua → explicit locals
  │          ✓ all files show dependencies at top
  │          ✓ luacheck 0 warnings, busted 140/140
  ▼
Phase 4 ─── Observability Tools ───── ✅ DONE
  │          ✓ bridge: eval, console, errors, screenshots, profiling, specs
  │          ✓ scene validator: covered by round-trip test + bridge /eval
  ▼
Phase 5 ─── Fix Known Bugs ────────── done (8/9 fixed, 1 deferred)
  │          ✓ io.lua precedence, joints.lua gibberish, duplicate key=='u'
  │          ✓ reference angle (dead code removed), swapBodies param removed
  │          ✓ snap at/to crash on save (found by round-trip test)
  │          ⏸ clone OMP dirty: deferred — needs OMP image cache (Phase 8)
  │          ✓ sensor: was already fixed, added guard + logging
  │          ✓ endNode: fixed misleading DNA values on arm connected-hair
  ▼
Phase 6 ─── Extract from main.lua ─── mostly done (6.1, 6.3 done)
  │          ✓ character experiments extracted
  │          ✓ game loop extracted to src/game-loop.lua (~150 lines)
  │          ✓ playtime.sh: error capture, --bridge flag, log/errors commands
  │          - physics callbacks: not started
  ▼
Phase 7 ─── Structural Improvements ─ 7f done
  │    ├── 7a. Snap state → state.lua
  │    ├── 7b. Fixture type registry
  │    ├── 7c. Mode handler table
  │    ├── 7d. DNA topology-as-data
  │    ├── 7e. Extract world-settings panel ─── ✅ DONE
  │    └── 7f. Consolidate utility functions ─── ✅ DONE
  │          ✓ clamp, sign, clampedLerp, getCenterAndDimensions → math-utils
  │          ✓ randomHexColor → utils
  │          ✓ rect exported from shapes
  │          ✓ 6 duplicates replaced across 8 files
  │          ⏸ tableConcat, getRelativePath: skipped (not worth the dep/churn)
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
| 0.1 | Is `playtime-files/meta.playtime.json` needed? Can we delete it? | **RESOLVED** — moved to scripts/, directory removed |
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
| 7f | No more copy-pasted helpers; `clamp`, `sign`, `rect` etc. are testable and centralized |

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
