# Deeper Issues — Second Pass Findings

Issues found by digging into cross-cutting concerns, runtime behavior, and code paths we accepted at face value in the first pass.

---

## 1. Actual Bugs (not just design debt)

### ~~Bug: Operator precedence in cloneSelection (io.lua:884)~~ — FIXED

Changed to `if not doneJoints[ud.id] then`.

### Bug: Cloned OMP fixtures not marked dirty (io.lua cloneSelection)

When cloning bodies with OMP texfixtures, the `extra.dirty` flag is not set to `true` on the cloned fixture. The OMP composite image (`ompImage`) is a runtime cache that gets stripped during serialization, but during cloning the old reference may be copied or lost. Without `dirty = true`, the cloned fixture won't regenerate its composite texture on first render.

### Bug: Unused `swapBodies` parameter (joints.lua:162)

```lua
function lib.recreateJoint(joint, newSettings, swapBodies)
```

The `swapBodies` parameter is accepted but never read inside the function. Either dead code from a removed feature, or an unfinished feature.

### ~~Bug: Debug print left in production code (joints.lua:104)~~ — FIXED

Replaced with `logger:error("Cannot create joint: bodyA and bodyB are the same body")`.

### ~~Bug: `if true then` blocks (5 occurrences)~~ — FIXED

Removed all 5 wrappers: joints.lua (2) and box2d-draw-textured.lua (3).

---

## 2. The Fixture Ordering Invariant — Hidden Constraint

A critical invariant that's nowhere documented but enforced in 4 files:

**All fixtures with userData must come before fixtures without userData on each body.**

```
body.fixtures = [sfixture, sfixture, sfixture, collision_shape, collision_shape]
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                 must come first                   must come after
```

This is validated by `fixtures.hasFixturesWithUserDataAtBeginning()` (fixtures.lua:78-100) and checked in:
- `io.lua:774` (during clone)
- `object-manager.lua:577` (during recreate)
- `playtime-ui.lua:3013` (during rendering)

**Why this matters**: If a fixture is added or removed in a way that breaks this ordering, the system silently fails — special fixtures won't be found, textures won't render, snap points won't work. The error is logged but execution continues.

**What can break it**: Box2D doesn't guarantee fixture ordering across operations. When you add/remove fixtures, the internal order may shift. The code works around this by always adding sfixtures first during creation, but any manual fixture manipulation could violate it.

---

## 3. Z-Ordering: Rebuild Every Frame, Unstable Sort

### The performance problem

`createDrawables()` (box2d-draw-textured.lua:964-1115) is called every frame. It:
1. Iterates ALL bodies in the physics world
2. Iterates ALL fixtures on each body
3. Checks userData on each fixture
4. Builds a drawable array
5. Sorts the entire array by z-value

This is O(bodies × fixtures × log(n)) every single frame. The TODO comment at line 1118 acknowledges this:

```lua
-- todo this list needs to be kept around and sorted in place,
-- resetting and doing all the work every frame is heavy!
```

### The z-order formula

```lua
composedZ = (zGroupOffset or 0) * 1000 + (zOffset or 0)
```

`zGroupOffset` provides coarse layering (×1000 separation). `zOffset` provides fine ordering within a group (UI sliders allow -180 to 180).

### Unstable sort

Lua's `table.sort` is not stable. Two drawables with the same `composedZ` will appear in arbitrary order, and that order can change frame-to-frame. This causes **z-fighting flicker** when fixtures share a z-value (which is the default — `zOffset = 0`).

---

## 4. State Mutation Chaos — 27 Writers for currentMode

Analysis of who writes to shared state reveals no clear ownership:

### state.currentMode — 27 writes across 3 files

| File | Write count | Examples |
|------|-------------|---------|
| `playtime-ui.lua` | 19 | Set to 'setOffsetA', 'drawFreePath', 'jointCreationMode', 'pickAutoRopifyMode', nil |
| `input-manager.lua` | 5 | Set to nil (clearing after mode completion) |
| `object-manager.lua` | 3 | Set to nil (clearing after finalize) |

There's no state machine. Any code can set `currentMode` to any string at any time. Invalid transitions aren't caught. If two buttons both try to set the mode in the same frame, the last one wins silently.

### state.world.paused — 3 independent writers

| Writer | Context |
|--------|---------|
| `input-manager.lua` | Toggle on space key, force-pause on certain modes |
| `playtime-ui.lua` | Toggle from play/pause button, set during playback |
| `recorder.lua` | Set during replay synchronization |

If the recorder sets paused=false while the user holds a mode that requires paused=true, the pause state flips unexpectedly.

### state.selection — scattered across UI and input

Selection state is written from `playtime-ui.lua` (many locations), `input-manager.lua` (8 locations), `fixtures.lua` (1), `object-manager.lua` (1), and `scene-loader.lua` (2). No centralized selection API.

### Direct body:setUserData bypass

`playtime-ui.lua:3507` directly modifies `thing.behaviors` and writes back via `body:setUserData()`, bypassing `object-manager`. This means:
- Object-manager doesn't know behaviors changed
- No validation or change tracking
- The thing structure can get out of sync with what object-manager expects

---

## 5. Nine More Global Leaks in playtime-ui.lua

The first-pass analysis missed these because they're defined inside nested scopes (inside functions), but they still leak to global scope because they lack `local`:

| Function | Line | Scope |
|----------|------|-------|
| `updateOffsetA` | 344 | Inside joint offset panel |
| `updateOffsetB` | 358 | Inside joint offset panel |
| `handlePaletteAndHex` | 1128 | Inside texture editor |
| `handleURLInput` | 1163 | Inside texture editor |
| `patchTransformUI` | 1179 | Inside texture editor |
| `combineImageUI` | 1221 | Inside texture editor |
| `flipWholeUI` | 1289 | Inside texture editor |
| `renderDistances` | 1755 | Inside influence computation |
| `inArray` | 2091 | Inside selected object UI |

This brings the **total global leak count to ~40** (up from the ~30 we counted before).

---

## 6. The Clone Pipeline Has Multiple Fragility Points

`io.cloneSelection` (lines 718-988) is one of the most complex operations in the codebase. Issues found:

### Influence references can become nil silently

When cloning, `remapAndRestoreInfluences` remaps node IDs through `idMapping`. If a connected-texture or meshusert references a node (anchor/joint) that's NOT in the cloned selection, `idMapping[originalId]` returns `nil`. The influence entry then has `nodeId = nil`, and the next `restoreInfluenceBodies` call will crash when trying to look up `nil` in the registry.

### Joints only clone if both bodies are selected

Line 899 skips any joint where both connected bodies aren't in the cloned set. This is correct behavior but provides **no feedback** to the user. If you select 3 bodies connected by 4 joints but miss one body, some joints silently disappear from the clone.

### Redundant reference angle read (line 932)

```lua
local oldRef = originalJoint:getReferenceAngle()
local newRef = originalJoint:getReferenceAngle()  -- reads OLD joint again
```

Gets reference angle from the original joint twice instead of reading the new joint's value. The variable `newRef` is misleading.

### Disabled collision detection

Three blocks of UUID collision detection code (lines 734-737, 805-813, 916-919) are commented out with notes about clashes. This suggests ID collisions have happened before but the protection was removed rather than fixed.

---

## 7. The Joint Metadata System Is Fragile

### How joints store data

Joint userData is just a table: `{ id = "...", offsetA = {x,y}, offsetB = {x,y} }`. Additional metadata is added via `setJointMetaSetting` which just adds keys to this table.

### recreateJoint destroys and rebuilds

Every joint property change (offset, limits, motor settings) requires destroying the joint and creating a new one. This is because Box2D joints are immutable once created for many properties.

**Cascade risk**: When a joint is destroyed and recreated, any code holding a reference to the old joint object now has a dangling reference. The `registry` is updated, but anything that cached the joint locally doesn't know it changed.

### moveUntilEnd — recursive body chain traversal

This global function (joints.lua:222) recursively moves chains of connected bodies. It's used when dragging a body to move its children along. The visited-set prevents infinite loops in cyclic joint graphs, but there's no depth limit — a very long chain could stack overflow.

---

## 8. Memory Management Patterns — Mostly Manual

### Image cache (box2d-draw-textured.lua)

`getLoveImage` (line 26, global) caches loaded images by URL. The cache is never cleared. Over a long session with many texture changes, this accumulates stale images in memory.

### Mesh pooling (box2d-draw-textured.lua:92-103)

```lua
local pool = setmetatable({}, { __mode = 'v' })  -- weak values
```

Mesh objects are pooled with weak references, so they can be GC'd when no longer drawn. This is actually good design — but it's the only place in the codebase that uses this pattern. Other caches (image cache, OMP cache) use strong references and never clean up.

### OMP image cache

`extra.ompImage` on each texfixture holds a LÖVE Image object. These are created by `makeCombinedImages()` and replaced when `dirty = true`. Old images are dereferenced but depend on GC to actually free GPU memory. No explicit `:release()` call.

### Canvas allocation in makeTexturedCanvas

`love.graphics.newCanvas()` is called every time a texture needs re-compositing (line 322). LÖVE canvases consume GPU memory. There's no canvas pooling.

---

## 9. The Connected-Texture Pipeline — Underdocumented

Connected textures draw bezier curve ribbons between two bodies (think: arms connecting torso to hand, or stretchy tentacles). The pipeline:

1. **Setup**: An sfixture of subtype `connected-texture` is created on body A. Its `extra.nodes` references body B (via anchor/joint ID).

2. **At draw time** (box2d-draw-textured.lua:1039-1110):
   - Start point = fixture's position on body A
   - End point = referenced node's position on body B
   - Control points computed from body angles
   - Bezier curve subdivided into segments
   - Triangle strip mesh created and textured

3. **The texture stretches** along the curve, creating the appearance of skin/cloth/tentacle connecting the two bodies.

**Issue**: The curve control point computation uses body angles directly. If bodies rotate wildly during physics simulation, the curve can flip inside-out or create self-intersections. There's no clamping or smoothing.

**Issue**: `texturedCurve` (the current version) and `texturedCurveOLD`/`texturedCurveOLD2` (the dead versions) all exist. The comment trail suggests the current version was hard-won through iteration, but there's no documentation of what changed or why.

---

## 10. The Behaviors System — Barely Exists

`behaviors.lua` is 11 lines defining two behavior names:

```lua
{ name = "KEEP_ANGLE", description = "..." },
{ name = "LIMB_HUB", description = "..." },
```

But the actual behavior execution is scattered:

- **KEEP_ANGLE**: Implemented in `keep-angle.lua` which reads `thing.behaviors` and applies a PD controller
- **LIMB_HUB**: Referenced in behaviors.lua but **grep shows no implementation anywhere**. It's defined but never executed.

The behavior system has no:
- Registration mechanism (behaviors are checked by string name)
- Parameter schema (each behavior needs different params but there's no definition)
- Lifecycle (no start/stop/cleanup hooks)
- UI for parameter editing (behaviors are added via a simple dropdown in playtime-ui.lua)

This is effectively a stub waiting to be designed.

---

## 11. Error Handling — Almost None

Across the codebase, error handling follows this pattern:

```lua
-- Pattern 1: Log and continue (most common)
if not joint or joint:isDestroyed() then
    logger:error("WARN: something bad"); return nil
end

-- Pattern 2: Silent skip
if thing and thing.id then
    -- do work
end
-- (if thing is nil, nothing happens, no error)

-- Pattern 3: pcall in exactly one place
local ok, err = pcall(function() ... end)  -- object-manager.lua:427

-- Pattern 4: Assert never used
-- (zero assert() calls in the entire codebase)
```

**Impact**: When something goes wrong (missing body, destroyed joint, nil fixture data), the system silently continues with corrupted state rather than failing loudly. This makes bugs extremely hard to trace — the symptom appears far from the cause.

---

## 12. What the `spec/` Tests Tell Us

The `spec/` directory contains busted-framework tests that are **significantly more comprehensive** than the `tests/` versions:

| File | Size | What it tests |
|------|------|--------------|
| `spec/math-utils_spec.lua` | 23KB | Extensive geometry, path, polygon tests |
| `spec/utils_spec.lua` | 15KB | deepCopy, shallowCopy, sanitizeString, round_to_decimals, map, tableConcat, etc. |

These look like they were generated by a previous AI session (comprehensive, systematic coverage). They use `describe`/`it`/`assert.are.same` syntax (busted framework).

**Problem**: Nobody knows they exist. They're not mentioned in any docs, not run by `tests/run.lua`, and require `busted` to be installed separately. They may or may not pass against the current code.

---

## Summary: Bug/Issue Count (updated)

| Category | Original | Fixed | Remaining | Examples of remaining |
|----------|----------|-------|-----------|----------------------|
| Actual bugs | 5 | 3 | 2 | OMP dirty flag, unused swapBodies, redundant reference angle |
| Hidden constraints | 2 | 0 | 2 | Fixture ordering invariant, z-sort instability |
| Global leaks | 87 | 68 | 19 | Intentional globals in main.lua/script.lua (Phase 3 work) |
| State mutation risks | 4 | 0 | 4 | currentMode (27 writers), paused (3 writers), selection, setUserData bypass |
| Memory leaks | 3 | 0 | 3 | Image cache never cleared, OMP images not released, canvas allocation |
| Missing features | 2 | 0 | 2 | LIMB_HUB behavior, behaviors system stub |
| Silent failure paths | 3+ | 0 | 3+ | Clone influence nil, clone joint skip, fixture ordering |
| Dead/debug code | 8+ | 8+ | 0 | All `if true then`, gibberish print, OLD functions removed |
