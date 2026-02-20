# Module-by-Module Analysis

Full codebase analysis covering every module in `src/`, with dependency mapping, issue inventory, and solidification ideas.

---

## Dependency Map

How modules connect to each other. Arrows mean "requires" or "calls into."

```
main.lua
  ├── state.lua (central state)
  ├── registry.lua (ID lookups)
  ├── io.lua ──────────────────┬── registry
  │                            ├── object-manager ── shapes, uuid, registry, joints, joint-handlers,
  │                            │                     fixtures, snap, math-utils, utils, polyline
  │                            ├── fixtures ──────── uuid, registry, math-utils, utils, state
  │                            ├── joints ───────── uuid, registry, math-utils, joint-handlers
  │                            └── character-manager ── shapes, uuid, registry, joints, fixtures,
  │                                                     math-utils, utils, state, object-manager
  ├── input-manager.lua ───────┬── object-manager
  │                            ├── joints
  │                            ├── fixtures
  │                            ├── math-utils
  │                            └── state
  ├── playtime-ui.lua ─────────┬── (requires almost everything)
  │                            └── 29 lines of requires
  ├── box2d-draw-textured.lua ─┬── math-utils, utils, state
  ├── box2d-draw.lua ──────────┤
  ├── editor-render.lua ───────┤
  ├── snap.lua ────────────────┬── registry, joints, fixtures, uuid
  ├── keep-angle.lua ──────────┤   (uses registry global)
  ├── scene-loader.lua ────────┤
  ├── script.lua ──────────────┤
  ├── camera.lua ──────────────┤
  ├── recorder.lua ────────────┤
  └── box2d-pointerjoints.lua ─┘
```

**Key observation**: `playtime-ui.lua` is a hub that depends on almost everything. `object-manager.lua` is the second biggest hub. Both are hard to test in isolation because of these deep dependency chains.

**Circular risk**: `object-manager` requires `snap`, and `snap` could potentially call back into object-manager patterns through registry callbacks.

---

## Module Inventory

### Core Data & State

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `state.lua` | 135 | Central app state table | Good — clean, single responsibility |
| `registry.lua` | 82 | ID-based lookup for bodies/joints/sfixtures | Good — clean API |
| `uuid.lua` | 67 | ID generation | Fair — 32-bit clash risk, module-level side effects |

### Physics & Objects

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `object-manager.lua` | 987 | Body creation, destruction, editing | Fair — large functions, goto statements, heavy state coupling |
| `joints.lua` | ~280 | Joint creation, recreation, metadata | Fair — uses logger global |
| `joint-handlers.lua` | ~180 | Per-type joint create/extract handlers | Good — clean data-driven pattern |
| `fixtures.lua` | 247 | Fixture creation and management | Fair — 9-branch if/elseif for types |
| `shapes.lua` | ~400 | Pure geometry: polygon, capsule, circle, ribbon | Good — mostly pure, testable |
| `snap.lua` | 351 | Snap-to fixtures, runtime joint creation/breaking | Fair — module-level state, global leaks |
| `keep-angle.lua` | 78 | PD controller for body angle maintenance | Poor — duplicate function definition, missing requires |
| `behaviors.lua` | 11 | Behavior name definitions | Stub — just a lookup table |

### Rendering

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `box2d-draw-textured.lua` | 1860 | 6 rendering paths for textured bodies | Poor — massive function, globals, fragile UV matching |
| `box2d-draw.lua` | 271 | Debug wireframe rendering | Good |
| `editor-render.lua` | 374 | Editor overlays (grid, vertices, handles) | Fair — magic numbers, deep state coupling |
| `polyline.lua` | 384 | High-quality polyline with joins | Good — clean geometry |
| `polylineOLD.lua` | 392 | Dead code | Delete |

### UI

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `playtime-ui.lua` | 3527 | All editor panels | Poor — too large, mixes rendering and mutation |
| `ui-all.lua` | 659 | Immediate-mode UI framework | Good — well-structured |
| `ui-textinput.lua` | 490 | Multi-line text input widget | Good |

### Input & Interaction

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `input-manager.lua` | 757 | Mouse/touch/keyboard handling | Fair — monolithic 392-line handlePointer |
| `box2d-pointerjoints.lua` | 228 | Drag interaction via mouse joints | Good |
| `selection-rect.lua` | 103 | Multi-select rectangle | Good |
| `camera.lua` | 64 | 2D viewport pan/zoom | Fair — global `offset` leak |

### Serialization & Scripting

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `io.lua` | 990 | Save/load scenes to JSON | Fair — complex pipeline, known vertex bug |
| `scene-loader.lua` | 90 | Hot-reload scenes from disk | Fair — global leaks (`getFiledata`, `jsoninfo`, `luainfo`) |
| `script.lua` | 115 | Sandboxed Lua scripting for scenes | Fair — global leaks (`getObjectsByLabel`, `mouseWorldPos`) |
| `file-browser.lua` | 55 | Directory listing with filters | Incomplete |

### Utilities

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `math-utils.lua` | ~1300 | Geometry, vectors, paths, transforms | Fair — global `lerp`, `inside`, `intersection` |
| `utils.lua` | ~200 | Table manipulation, string, deep copy | Good — mostly pure |
| `logger.lua` | 57 | Logging utility | Fair — returns class not instance |
| `benchmarks.lua` | 43 | Performance measurement | Good |
| `recorder.lua` | 220 | Record/replay interactions | Fair |

### Character System

| Module | Lines | Purpose | Health |
|--------|-------|---------|--------|
| `character-manager.lua` | 1729 | DNA, topology, character assembly | Poor — topology-in-code, globals, massive functions |

---

## Complete Global Leak Inventory

Every function or variable defined without `local` that pollutes the global namespace:

### Critical (dangerous names that could shadow builtins or clash)

| File | Name | Line | Risk |
|------|------|------|------|
| `character-manager.lua` | `add` | 102 | **Extremely high** — shadows any other meaning of "add" |
| `math-utils.lua` | `lerp` | 42 | High — common name, also has `lib.lerp` at 1235 |
| `math-utils.lua` | `inside` | 875 | High — common word |
| `math-utils.lua` | `intersection` | 879 | Medium |

### Moderate (specific enough to rarely clash, but still wrong)

| File | Name | Line | Risk |
|------|------|------|------|
| `snap.lua` | `checkForJointBreaks` | 73 | Medium |
| `snap.lua` | `calculateDistance` | 206 | Medium — duplicates math-utils |
| `keep-angle.lua` | `rotateBodyTowards` | 4, 22 | Medium — defined TWICE |
| `object-manager.lua` | `getClosestEdge` | 176 | Low-medium |
| `joints.lua` | `moveUntilEnd` | 222 | Low-medium |
| `script.lua` | `getObjectsByLabel` | 16 | Low-medium |
| `script.lua` | `mouseWorldPos` | 27 | Low-medium |
| `scene-loader.lua` | `getFiledata` | 49 | Low-medium |
| `scene-loader.lua` | `jsoninfo` | 25 | Low |
| `scene-loader.lua` | `luainfo` | 26 | Low |
| `camera.lua` | `offset` | 14 | Low |
| `editor-render.lua` | `roundArray` | 178 | Low |

### In box2d-draw-textured.lua (many, concentrated in one file)

| Name | Line | Risk |
|------|------|------|
| `getLoveImage` | 26 | Medium |
| `setBgColor` | 162 | Low |
| `setFgColor` | 168 | Low |
| `setPColor` | 174 | Low |
| `makePatch` | 444 | Low |
| `meshGetVertex` | 670 | Low |
| `createTexturedTriangleStrip` | 676 | Low |
| `texturedCurveOLD2` | 705 | Low |
| `texturedCurve` | 750 | Low |
| `texturedCurveOLD` | 809 | Low |
| `addMidpoint` | 1071 | Low — defined inside draw loop |
| `resolveIndex` | 1838 | Low |
| `getIndices` | 1842 | Low |

### In character-manager.lua

| Name | Line | Risk |
|------|------|------|
| `createDefaultTextureDNABlock` | 66 | Low |
| `initBlock` | 85 | Low |

**Total: ~30 global leaks across 9 files.**

---

## Serialization Pipeline (io.lua) — Deep Analysis

### Save Path
```
lib.save(filename)
  → lib.gatherSaveData()
      → For each body in registry:
          → Strip runtime refs (body, ompImage, _mesh)
          → Serialize thing.vertices, thing.dims, thing.shape, etc.
          → For each fixture on body:
              → Serialize fixture userData (subtype, sharedFixtureData)
          → For each joint in registry:
              → Use joint-handlers[type].extract() to get type-specific data
      → Return big table
  → json.encode(data)
  → love.filesystem.write(filename, jsonString)
```

### Load Path
```
lib.load(filename)
  → json.decode(fileContents)
  → Version check
  → lib.buildWorld(data)
      → For each saved body:
          → object-manager.createThing(shape, settings)
              → Creates physics body + fixtures
          → Restore thing.vertices from saved data
          → For each saved sfixture:
              → fixtures.createSFixture(body, ...)
      → For each saved joint:
          → joints.createJoint(bodyA, bodyB, type, settings)
      → snap.rebuildSnapFixtures()
```

### Known Fragilities

1. **Vertices not populated after load** — The `thing.vertices` array is saved but may not be properly restored because `createThing` generates new vertices from shape parameters, overwriting the saved ones. The saved vertices only matter for custom polygons.

2. **Save-then-restore pattern** — `gatherSaveData` temporarily strips runtime references (`body`, `ompImage`, `_mesh`) before serializing, then restores them after. If serialization throws, the references are lost. No try/finally protection.

3. **ID preservation** — The save/load pipeline preserves IDs, which is good. But `cloneSelection` generates new IDs while remapping joint references — a complex operation with edge cases for multi-body joint chains.

4. **No schema versioning** — There's a version check but no migration path. If the save format changes, old files just fail.

5. **`sharedFixtureData.sensor` bug** — Comment at line 499 notes this doesn't always work correctly.

### Solidification Ideas

- **Round-trip test** (described in TOOLING-IDEAS.md) would catch issues 1 and 2
- **Schema versioning with migrations** — add a `schemaVersion` field and migration functions per version bump
- **Wrap gatherSaveData in pcall** with proper cleanup of stripped references
- **Validate after load** — check that all joints reference live bodies, all fixtures are registered, etc.

---

## Input Flow (input-manager.lua) — Deep Analysis

### The handlePointer Monster

`handlePointer` (lines 24-416) is a 392-line function that handles ALL press/release events. Its structure:

```
handlePointer(x, y, isPressed, pointer)
  → Convert screen coords to world coords via camera
  → If pressed:
      → Check mode (drawClickPoly, drawCustomPoly, drawRibbon, etc.)
      → For each mode: handle the click differently
      → If no mode: query world for body under cursor
          → Handle selection (body, joint, sfixture, multi-select)
          → Handle vertex editing
          → Handle snap fixture clicking
  → If released:
      → Clear drag state
      → Finalize polygon if in drawing mode
```

### Issues

1. **Mode explosion** — Every new editing mode adds another branch to this function. Current modes: `drawClickPoly`, `drawCustomPoly`, `drawClickRect`, `drawClickCircle`, `drawClickOval`, `drawClickCapsule`, `drawRibbon`, `drawSoftBody`, plus default selection mode.

2. **World query in input handler** — Physics world queries (`world:queryBoundingBox`, `world:getBodyList`) happen inside the input handler, mixing input concerns with physics queries.

3. **Selection logic is tangled** — Selecting a body vs. a joint vs. an sfixture vs. a vertex involves nested conditionals checking fixture userData types.

4. **No undo** — Actions triggered by input are immediate and irreversible. No command history.

### Solidification Ideas

- **Mode handler table** — Replace the if/elseif chain with a table of mode handlers:
  ```lua
  local modeHandlers = {
      drawClickPoly = function(x, y, isPressed) ... end,
      drawCustomPoly = function(x, y, isPressed) ... end,
      -- etc.
  }
  ```
  Then `handlePointer` becomes: `modeHandlers[state.currentMode](x, y, isPressed, pointer)`

- **Separate hit-testing from input** — Create a `hitTest(worldX, worldY)` function that returns what's under the cursor (body, joint, sfixture, vertex, nothing) without acting on it. Then input handler decides what to do with the hit result.

- **Command pattern for undo** — Store actions as command objects with `execute()` and `undo()` methods. This is a bigger investment but high payoff for an editor.

---

## Snap System (snap.lua) — Deep Analysis

### How It Works

Snap fixtures are sensor fixtures placed on bodies at specific positions. When two snap fixtures overlap during physics simulation, a joint is automatically created between their parent bodies. Joints can also break when force exceeds a threshold.

### Module-Level State

```lua
local snapFixtures = {}   -- all snap fixtures in the scene
local mySnapJoints = {}    -- joints created by the snap system
local cooldownList = {}    -- recently broken joints (prevents immediate re-snap)
```

This state is NOT in `state.lua`. It's invisible to the rest of the app and can't be serialized or inspected.

### Issues

1. **Hidden state** — The snap system maintains its own parallel state that nobody else can see. If you dump `state`, you miss the snap joints and cooldowns.

2. **`calculateDistance` duplication** — Line 206 defines a global `calculateDistance` that does the same thing as `math-utils.calculateDistance`.

3. **`checkForJointBreaks` is global** — Line 73, called from main.lua's update loop.

4. **Rebuild from scratch** — `rebuildSnapFixtures` iterates all bodies in registry to find snap fixtures. This is O(bodies × fixtures) every time it's called.

5. **No event notification** — When a snap joint is created or broken, there's no way for other systems to know. Useful for sound effects, visual feedback, or logging.

### Solidification Ideas

- Move snap state into `state.lua` or make it inspectable via accessor functions
- Replace `calculateDistance` with `mathUtils.calculateDistance`
- Make `checkForJointBreaks` a `lib.` function
- Add event callbacks: `onSnapJointCreated(bodyA, bodyB, joint)`, `onSnapJointBroken(joint, force)`
- Cache snap fixture lookups instead of rebuilding from registry each time

---

## Scene Scripting (script.lua) — Analysis

### How It Works

Scenes can have companion `.playtime.lua` files that run in a sandboxed environment. The sandbox provides:
- `getObjectsByLabel(label)` — find bodies by label
- `mouseWorldPos()` — get cursor position
- Physics callbacks: `beginContact`, `endContact`, `preSolve`, `postSolve`
- Limited Lua stdlib: `math`, `print`, `pairs`, `ipairs`, `tostring`, `tonumber`, `type`, `unpack`, `table`, `string`

### Issues

1. **`getObjectsByLabel` and `mouseWorldPos` are globals** — They should be in the sandbox environment only, not polluting the global namespace.

2. **Sandbox is incomplete** — No access to `love.timer`, `coroutine`, or `os.clock`. Scripts can't do time-based logic without workarounds.

3. **No script update loop** — Scripts only get physics callbacks. There's no `onUpdate(dt)` or `onDraw()` hook for per-frame script logic.

4. **Error handling** — `pcall` is used for script loading but error messages may not surface clearly to the user.

### Solidification Ideas

- Move `getObjectsByLabel` and `mouseWorldPos` into the sandbox env table only
- Add `onUpdate(dt)` and `onDraw()` hooks to the sandbox
- Add `onKeyPressed(key)` for interactive scripts
- Consider a `getJointsByLabel(label)` helper
- Add script error display in the editor UI (overlay or panel)

---

## The Fixture Type System — Cross-Cutting Concern

Fixtures are one of the most cross-cutting concepts in the codebase. A fixture can be:

| Subtype | Created in | Rendered in | Serialized in | Edited in |
|---------|-----------|-------------|---------------|-----------|
| (none) — collision shape | object-manager | box2d-draw | io.lua | playtime-ui |
| `snap` | fixtures.lua | editor-render | io.lua | playtime-ui |
| `anchor` | fixtures.lua | editor-render | io.lua | playtime-ui |
| `texfixture` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |
| `connected-texture` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |
| `trace-vertices` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |
| `tile-repeat` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |
| `resource` | fixtures.lua | (data source) | io.lua | playtime-ui |
| `meshusert` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |
| `uvusert` | fixtures.lua | box2d-draw-textured | io.lua | playtime-ui |

Every time a new fixture subtype is added, you touch 4+ files. Each file has its own if/elseif chain for subtypes.

### Solidification Idea: Fixture Type Registry

```lua
-- src/fixture-types.lua
local fixtureTypes = {}

fixtureTypes['texfixture'] = {
    isSensor = true,
    defaultData = { ... },
    create = function(body, localX, localY, cfg) ... end,
    serialize = function(fixture) ... end,
    deserialize = function(body, data) ... end,
    draw = function(fixture, body) ... end,
    drawEditor = function(fixture, body) ... end,
    drawUI = function(fixture, ui) ... end,  -- returns action table
}
```

Then `fixtures.createSFixture` becomes:
```lua
function lib.createSFixture(body, localX, localY, subtype, cfg)
    local handler = fixtureTypes[subtype]
    if not handler then error("Unknown fixture subtype: " .. subtype) end
    return handler.create(body, localX, localY, cfg)
end
```

And `drawTexturedWorld` becomes:
```lua
for _, drawable in ipairs(drawables) do
    local handler = fixtureTypes[drawable.subtype]
    if handler and handler.draw then handler.draw(drawable, ...) end
end
```

This is a bigger refactor but it eliminates the cross-cutting if/elseif chains and makes adding a new fixture type a single-file operation.

---

## Performance Hotspots

From profiling notes and code analysis:

| Hotspot | Location | Cause | Fix |
|---------|----------|-------|-----|
| `drawWorldSettingsUI` | playtime-ui:934 | Immediate-mode UI rebuilds all sliders every frame | Cache/skip when not interacted |
| `createDrawables` | box2d-draw-textured:964 | Rebuilds drawable list from scratch every frame | Cache, dirty-flag |
| `deformWorldVerts` | box2d-draw-textured:1330 | Weighted vertex deformation computed in draw | Move to update, cache results |
| `trace-vertices` mesh | box2d-draw-textured:1761 | Mesh recreated every frame | Cache mesh, rebuild only when vertices change |
| `meshusert` mesh | box2d-draw-textured:1380 | Mesh recreated every frame | Same |
| `uvusert` mesh | box2d-draw-textured:1507 | Mesh recreated every frame | Same |
| `snap.rebuildSnapFixtures` | snap:179 | O(bodies × fixtures) scan | Cache, rebuild only on add/remove |

---

## What "Solidifying" Would Look Like — A Progression

### Level 1: Safety Net (days, not weeks)
- Fix all ~30 global leaks (each is a 1-line change)
- Delete `polylineOLD.lua` and OLD function variants in box2d-draw-textured
- Delete duplicate `rotateBodyTowards` in keep-angle.lua
- Make logger a singleton
- Add unit tests for `utils.lua`, `shapes.lua`, `uuid.lua`
- Add save/load round-trip integration test

**Result**: You can make changes with more confidence. Global name collisions can't bite you. Basic serialization correctness is verified automatically.

### Level 2: Observability (a week)
- Implement `--dump` and `--validate` CLI tools (from TOOLING-IDEAS.md)
- Move snap state into state.lua (or make it inspectable)
- Add explicit requires for all global module access
- Add integration tests for object creation, joint creation, registry ops

**Result**: The AI can inspect runtime state without running the app visually. Failed changes are caught by automated checks.

### Level 3: Modularity (weeks, incremental)
- Extract fixture type registry (eliminates cross-cutting if/elseif)
- Split `input-manager.handlePointer` into mode handler table
- Extract one UI panel from playtime-ui.lua (start with world-settings, the perf bottleneck)
- Move DNA topology to data (from DEEP-DIVE-NOTES.md)

**Result**: Adding new features (fixture types, editing modes, body parts) becomes a single-file operation instead of touching 4+ files.

### Level 4: Architecture (longer term, as needed)
- Split playtime-ui.lua panel by panel
- Separate rendering paths into individual modules
- Add command pattern for undo/redo
- Cache drawable list with dirty flagging
- Move deformation computation to update phase

**Result**: Editor is extensible, performant, and each module is independently testable.

---

## Cross-Reference: Issues by Severity

### Bugs (things that are actually wrong)

| Issue | File | Description |
|-------|------|-------------|
| Duplicate function | keep-angle.lua:4,22 | `rotateBodyTowards` defined twice, second shadows first |
| Wrong endNode | character-manager.lua:323,339 | `luarm`/`ruarm` connected-hair uses `endNode='lfoot'` instead of `'lhand'`/`'rhand'` |
| Fragile UV match | box2d-draw-textured.lua:1471 | Coordinate-based UV matching with 0.001 tolerance |
| Duplicate key handler | main.lua:722,738 | Two `if key == 'u'` blocks, second shadows first |
| Sensor flag | io.lua:499 | `sharedFixtureData.sensor` not always working |
| Vertices after load | io.lua | `thing.vertices` may not survive save/load round-trip |

### Design Debt (things that work but make changes risky)

| Issue | Impact |
|-------|--------|
| ~30 global function leaks | Silent name collisions possible |
| Logger class vs instance | Modules that require logger get wrong thing |
| Module-level state in snap.lua | State invisible to serialization and debugging |
| 392-line handlePointer | Every new mode adds complexity |
| 3527-line playtime-ui.lua | Can't hold in context, changes have ripple effects |
| 6 rendering paths in one function | Each path is independent but entangled |
| Fixture subtype if/elseif in 4+ files | Adding a fixture type requires coordinated changes |
| DNA topology in code not data | Adding body parts requires touching 3 functions |

---

## Files Safe to Delete

| File | Lines | Reason |
|------|-------|--------|
| `src/polylineOLD.lua` | 392 | Dead code, current version is `polyline.lua` |
| `texturedCurveOLD2` in box2d-draw-textured | ~45 | Superseded by `texturedCurve` |
| `texturedCurveOLD` in box2d-draw-textured | ~50 | Superseded by `texturedCurve` |
| `drawSquishableHairOverOLD` in box2d-draw-textured | ~?? | Superseded by `drawSquishableHairOver` |
| `doubleControlPointsOld` in box2d-draw-textured | ~?? | Superseded by `doubleControlPoints` |
| ~200 lines of commented character experiments in main.lua | 200 | Dead code from development |
