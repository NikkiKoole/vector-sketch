# AI Collaboration Plan for Playtime

## What This Document Is

A practical guide for making the playtime codebase easier to work on together (human + AI). Focused on changes that give the most leverage: things that let us verify correctness without running the app, reduce coupling so changes don't break distant code, and make the codebase easier to reason about in chunks.

---

## Current State Assessment

### What's Good
- **`state.lua` is centralized** — all app state in one place, easy to find
- **`registry.lua` is a clean pattern** — ID-based lookups, small API surface
- **Test infrastructure exists** — mini-test.lua, test runner, unit/integration split
- **Module pattern is consistent** — `local lib = {} ... return lib`
- **PROJECT.md is thorough** — good map of the codebase

### What Makes AI Collaboration Hard Right Now

1. **Globals everywhere** — `logger`, `snap`, `registry`, `keep_angle`, `benchmarks`, `inspect`, `prof` are all globals set in main.lua. When I read a module, I can't see what it depends on just from the `require` calls.

2. **Almost no tests** — 17 unit tests for math-utils, 5 integration tests for basic physics. That's 22 tests for ~17,000 lines. When I change something, I can't verify it works without you running the app visually.

3. **main.lua is a god file** (999 lines) — Mixes initialization, game loop, input handling, debug key bindings, and two different fixed-timestep implementations. Hard to understand what a change affects.

4. **Large files with mixed concerns** — `playtime-ui.lua` (3,527 lines), `character-manager.lua` (1,729 lines). I can't hold these in context easily, and changes have unpredictable ripple effects.

5. **Functions coupled to Box2D/LÖVE** — Most modules call `love.physics.*` or `body:getX()` directly, making them untestable without LÖVE running.

6. **~30 global function leaks** — `lerp`, `add`, `inside`, `calculateDistance`, `getLoveImage`, and many more are defined without `local` keyword, polluting global scope. A global named `add` (character-manager.lua:102) is particularly dangerous.

7. **Lots of dead/commented code** — main.lua has ~200 lines of commented-out character experiments. `polylineOLD.lua` is 392 lines of dead code.

---

## Priority 1: Make Pure Functions Testable (Low Risk, High Value)

These are changes that don't affect runtime behavior at all — just make it possible to verify correctness.

### 1a. Add tests for existing pure modules

These modules have functions that are pure or nearly pure and can be tested without LÖVE:

| Module | Testable Functions | Estimated Tests |
|--------|--------------------|-----------------|
| `src/utils.lua` | `map`, `getPathDifference`, `sanitizeString`, `round_to_decimals`, `tablelength`, `tableConcat`, `shallowCopy`, `deepCopy`, `findByField`, `tablesEqualNumbers` | ~20 |
| `src/math-utils.lua` | Most of the 50+ functions (geometry, paths, vectors) | ~40 more |
| `src/shapes.lua` | `makePolygonVertices`, `capsuleXY`, `torso`, `approximateCircle`, `ribbon` — all pure geometry | ~15 |
| `src/uuid.lua` | `generateID` — verify format, uniqueness | ~3 |
| `src/polyline.lua` | Path manipulation functions | ~10 |

**How to do it**: Create test files following existing pattern:
```
tests/unit/test_utils.lua
tests/unit/test_shapes.lua
tests/unit/test_uuid.lua
tests/unit/test_polyline.lua
```

**Why this helps me**: When you ask me to modify a math function or add a new shape, I can write the test first, then the code, and we can verify it passes with `lua tests/run.lua`.

### 1b. Fix global function leaks (MANY more than expected)

Cross-checking PROJECT.md against actual code reveals **~30 global function leaks** across the codebase. These are functions defined without `local` or `lib.` prefix, so they pollute the global namespace:

**math-utils.lua:**
- `lerp` (line 42) — also has `lib.lerp` at line 1235 (duplicate!)
- `inside` (line 875)
- `intersection` (line 879)

**character-manager.lua:**
- `createDefaultTextureDNABlock` (line 66)
- `initBlock` (line 85)
- `add` (line 102) — this name is *extremely* dangerous as a global

**box2d-draw-textured.lua:**
- `getLoveImage` (line 26)
- `setBgColor` (line 162), `setFgColor` (line 168), `setPColor` (line 174)
- `makePatch` (line 444)
- `meshGetVertex` (line 670)
- `createTexturedTriangleStrip` (line 676)
- `texturedCurveOLD2` (line 705), `texturedCurve` (line 750), `texturedCurveOLD` (line 809)
- `resolveIndex` (line 1838), `getIndices` (line 1842)

**snap.lua:**
- `checkForJointBreaks` (line 73)
- `calculateDistance` (line 206) — also exists as local in math-utils.lua!

**keep-angle.lua:**
- `rotateBodyTowards` defined TWICE (line 4 AND line 22) — second one shadows first

**script.lua:**
- `getObjectsByLabel` (line 16)
- `mouseWorldPos` (line 27)

**scene-loader.lua:**
- `getFiledata` (line 49)

**object-manager.lua:**
- `getClosestEdge` (line 176)

**joints.lua:**
- `moveUntilEnd` (line 222)

**Fix**: Each of these should either be `local function name(...)` if used only in that file, or `lib.name = function(...)` / `function lib.name(...)` if it needs to be exported. This is the single highest-impact code quality fix — a global named `add` could silently break anything.

### 1c. Export currently-local pure functions

Several useful functions in `math-utils.lua` are `local` but could be on `lib`:
- `unpackNodePoints` (line 24)
- `unpackNodePointsLoop` (line 6)
- `getDistance` (line 46)

If they're used by other modules or would be useful in tests, put them on `lib`.

---

## Priority 2: Eliminate Globals (Medium Risk, High Value)

### 2a. Make all globals explicit requires

Current (in various modules):
```lua
-- These work because main.lua sets them as globals
logger:info("something")
registry.getBodyByID(id)
snap.rebuildSnapFixtures()
```

Target:
```lua
local logger = require 'src.logger'
local registry = require 'src.registry'
local snap = require 'src.snap'
```

**Affected globals and where they're set (main.lua)**:
| Global | Line | Fix |
|--------|------|-----|
| `logger` | 40 | Already a module, just add `require` everywhere it's used |
| `inspect` | 41 | Add `require 'vendor.inspect'` where used |
| `snap` | 70 | Already a module |
| `keep_angle` | 71 | Already a module |
| `registry` | 72 | Already a module |
| `benchmarks` | 73 | Already a module |
| `prof` / `PROF_CAPTURE` | 42-43 | Wrap in optional require |
| `ProFi` | 46 | Wrap in optional require |
| `lerp` | math-utils.lua:42 | Move to `lib.lerp` |

**How to do it safely**:
1. For each global, grep for all uses across the codebase
2. Add the `require` at the top of each file that uses it
3. Remove the global assignment from main.lua
4. Run `love . --test` to verify tests still pass
5. Run the app to verify behavior

**Why this helps me**: When I read a file, I can see its complete dependency list at the top. I don't have to guess what globals exist.

### 2b. Logger initialization

`logger` is created with `Logger:new()` in main.lua. Modules that `require 'src.logger'` get the Logger *class*, not an *instance*.

Fix: Make logger.lua return a singleton instance:
```lua
-- At the bottom of logger.lua, replace:
return Logger
-- With:
return Logger:new()
```

---

## Priority 3: Extract Logic from main.lua (Medium Risk, Medium Value)

main.lua currently handles:
1. Module loading and global setup (lines 40-83)
2. `waitForEvent()` focus blocking (lines 86-94)
3. `love.load()` — init, scene loading (lines 102-212)
4. Physics callbacks (lines 214-228)
5. `love.update()` — game loop (lines 232-299)
6. `love.draw()` — rendering (lines 308-410)
7. Input dispatch (lines 412-845) — **this is the big one**
8. Fixed timestep game loop (lines 849-998)

### 3a. Extract debug keybindings

Lines 480-815 are all `if key == 'X' then ... end` blocks for character experimentation. Move to a separate module:

```lua
-- src/debug-keys.lua
local lib = {}
function lib.handleDebugKey(key, humanoidInstance)
    -- all the character manipulation code
end
return lib
```

This alone removes ~350 lines from main.lua.

### 3b. Extract physics callbacks

Lines 214-228 define `beginContact`, `endContact`, `preSolve`, `postSolve` as globals. Move to a module:

```lua
-- src/physics-callbacks.lua
local script = require 'src.script'
local lib = {}
function lib.beginContact(fix1, fix2, contact, ...) script.call('beginContact', fix1, fix2, contact, ...) end
-- etc.
return lib
```

### 3c. Consider extracting the game loop

The fixed-timestep loop (lines 893-998) is a self-contained algorithm. It could live in its own file and be testable (the accumulator/panic logic is pure math).

---

## Priority 4: Add Integration Tests for Key Workflows (Medium Risk, High Value)

These tests need LÖVE but verify actual app behavior:

### 4a. Scene serialization round-trip
```lua
-- tests/integration/test_io.lua
-- Create objects → save to JSON → load from JSON → verify objects match
```
This is the highest-value integration test. It covers io.lua, registry.lua, shapes.lua, fixtures.lua, joints.lua all at once.

### 4b. Object creation
```lua
-- tests/integration/test_object_manager.lua
-- Create rectangle → verify body exists in world and registry
-- Create circle → verify fixture shape
-- Create custom polygon → verify vertices
```

### 4c. Joint creation
```lua
-- tests/integration/test_joints.lua
-- Create two bodies → add revolute joint → verify connection
-- Test joint metadata (offsets, limits)
```

### 4d. Registry operations
```lua
-- tests/integration/test_registry.lua
-- Register/unregister bodies, joints, sfixtures
-- Verify reset clears everything
```

**Why this helps me**: When you ask me to change how saving works, or how objects are created, I can run the integration tests to catch regressions without you having to visually inspect the app.

---

## Priority 5: Module Splitting (Higher Risk, Lower Urgency)

### 5a. Split `playtime-ui.lua` (3,527 lines)

This is the biggest file and touches everything. Split by panel:

```
src/ui/world-settings.lua
src/ui/body-inspector.lua
src/ui/joint-editor.lua
src/ui/fixture-editor.lua
src/ui/character-editor.lua
src/ui/texture-editor.lua
src/ui/toolbar.lua
src/ui/menu-bar.lua
```

Each panel module would:
- Take `state` and relevant data as parameters
- Return whether a UI action was triggered
- Not directly modify physics objects (return actions/intents instead)

This is the riskiest refactor. Do it last, panel by panel.

### 5b. Split `character-manager.lua` (1,729 lines)

Separate concerns:
```
src/character/dna.lua          -- DNA/genetics system (pure data)
src/character/builder.lua      -- Creating physics bodies from DNA
src/character/textures.lua     -- Texture management
src/character/rigging.lua      -- Vertex assignment/skinning
```

The DNA system in particular should be highly testable once extracted.

---

## Priority 6: Code Cleanup (Low Risk)

### 6a. Remove dead code
- Delete `src/polylineOLD.lua` (392 lines, unused)
- Remove ~200 lines of commented-out character experiments in main.lua
- Remove unused profiling reports (`profilingReportOLD*.txt`)
- Audit `math-utils.lua` for unused functions

### 6b. Remove duplicate key handler
Lines 738-743 in main.lua define a second `if key == 'u'` block (nose changes) that shadows the first one (leg/arm length changes on lines 722-737). One of these is dead code.

### 6c. Clean up profiling
The `prof.push()`/`prof.pop()` calls are scattered throughout. Make them conditional:
```lua
-- In main.lua or a config
local PROFILING = false

-- Then wrap:
if PROFILING then prof.push('frame') end
-- ... or just remove them if not actively profiling
```

---

## Recommended Order of Work

1. **Add unit tests for utils.lua and more math-utils.lua** — Zero risk, immediately useful
2. **Fix the `lerp` global and any other leaks** — Tiny change, prevents bugs
3. **Make logger a singleton** — Small change, unblocks #4
4. **Add explicit requires for globals** — File by file, grep-verify each one
5. **Add integration test for save/load round-trip** — Highest-value integration test
6. **Extract debug keybindings from main.lua** — Easy win, big reduction in main.lua size
7. **Add more integration tests** (object creation, joints, registry)
8. **Remove dead code** — Low risk cleanup
9. **Split playtime-ui.lua** — Do last, one panel at a time
10. **Split character-manager.lua** — Do last, by concern

---

## How This Helps AI Collaboration Specifically

| Problem | Solution | Impact |
|---------|----------|--------|
| "Did my change break anything?" | More tests → `lua tests/run.lua` or `love . --test` | Can verify without visual inspection |
| "What does this module depend on?" | Explicit requires, no globals | Can read a file and understand it in isolation |
| "This file is too big for context" | Split large files | Can focus on the relevant 200 lines, not 3,500 |
| "Where is this function called?" | No globals = grep actually works | Can trace call chains reliably |
| "Is this code still used?" | Remove dead code | Less noise to read through |
| "Will this math function work?" | Unit tests for pure functions | Test-driven development possible |
| "How does save/load work?" | Round-trip integration test | Can modify serialization with confidence |

---

## What NOT to Do

- Don't add an OOP class system — the current `local lib = {} return lib` pattern works fine
- Don't add a dependency injection framework — just use explicit requires
- Don't refactor everything at once — work file by file, test after each change
- Don't add TypeScript-style type annotations — Lua isn't that language
- Don't abstract prematurely — three similar lines > one clever function nobody understands
