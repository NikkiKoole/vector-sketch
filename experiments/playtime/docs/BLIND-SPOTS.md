# Blind Spots & Undocumented Systems

Things we discovered after the initial analysis that are important but weren't visible from just reading module APIs. This document exists so we can pick up where we left off.

---

## 1. The "thing" — Undocumented Central Data Structure

The body userData (`body:getUserData().thing`) is the most important data structure in the entire app, and it has no formal definition. It's constructed in `object-manager.lua:441-468`, extended at runtime by UI interactions, serialized in `io.lua:430-509`, and read everywhere.

### Canonical Shape (from createThing)

```lua
thing = {
    -- Identity
    id = "t7CsE",                  -- uuid32_base62 (32-bit, clash risk)
    label = "torso",               -- user-assigned name, used by scripts

    -- Shape definition
    shapeType = "rectangle",       -- 'circle', 'rectangle', 'capsule', 'torso',
                                   -- 'shape8', 'custom', 'ribbon', 'oval',
                                   -- 'approximateCircle'
    vertices = {x1,y1, x2,y2...}, -- only meaningful for 'custom' and 'ribbon'

    -- Dimensions (which fields exist depends on shapeType)
    radius = 50,                   -- circle, approximateCircle
    width = 100,                   -- most polygon types
    width2 = 80,                   -- torso, capsule
    width3 = 80,                   -- torso
    height = 200,                  -- most polygon types
    height2 = 200,                 -- torso, capsule
    height3 = 200,                 -- torso
    height4 = 200,                 -- torso

    -- Visual
    mirrorX = 1,                   -- 1 or -1 (horizontal flip)
    mirrorY = 1,                   -- 1 or -1 (vertical flip)
    zOffset = 0,                   -- rendering z-order

    -- Runtime refs (stripped before save, restored after load)
    body = <love.Body>,            -- the Box2D body
    shapes = {<love.Shape>, ...},  -- shapes for destruction

    -- Optional (added by UI at runtime)
    behaviors = {                  -- keep-angle.lua reads this
        { name = "KEEP_ANGLE", target = 0.0 },
        { name = "LIMB_HUB" },
    },
}
```

### What's NOT in thing but lives on the body

The body also carries fixture userData on its individual fixtures. The "thing" is the body-level data; fixture-level data is separate. They're linked only by the body reference.

### Where thing gets extended at runtime

- `playtime-ui.lua` adds/modifies `behaviors` array
- `character-manager.lua` sets `label`, shape params, and creates sfixtures
- `object-manager.recreateThingFromBody` destroys and rebuilds while preserving the thing's ID
- `io.lua` strips `body` and `shapes` before save, restores after

### The Circular Reference Problem

`thing.body` points to the Box2D body. `body:getUserData().thing` points back to thing. This means:
- JSON serialization must strip `body` first (io.lua does this)
- Deep copying must handle the cycle (utils.deepCopy would infinite-loop without the strip)
- GC can handle it (Lua has cycle detection) but it's still a design smell

---

## 2. The Fixture UserData System — 9 Subtypes

Every "special fixture" (sfixture) has this structure:

```lua
fixtureUserData = {
    type = "sfixture",         -- always this string
    subtype = "texfixture",    -- one of 9 types below
    id = "2cdjyX",             -- unique ID, registered in registry
    label = "meta8",           -- user-assigned
    extra = { ... },           -- subtype-specific, see below
}
```

### Subtype: texfixture (textured polygon)

The most complex and most commonly used. This is how characters get their visual appearance.

```lua
extra = {
    -- Shape
    vertexCount = 8,                -- 4 or 8
    vertices = {x1,y1, ...},       -- polygon vertices

    -- OMP texturing (Outline + Mask + Pattern)
    OMP = true,                     -- enables composite texture pipeline
    dirty = true,                   -- needs re-render
    main = {                        -- primary texture layer
        bgURL = "earx1r.png",      -- outline image (in textures/)
        fgURL = "earx1r-mask.png", -- mask image (in textures/)
        pURL = "pat1.png",         -- pattern image (in textures/pat/)
        bgHex = "ff000000",        -- outline color
        fgHex = "ffcc8844",        -- fill color
        pHex = "ff884422",         -- pattern color
        fx = 1, fy = 1,            -- flip
        pr = 0,                    -- pattern rotation
        psx = 1, psy = 1,          -- pattern scale
        ptx = 0, pty = 0,          -- pattern translation
    },
    patch1 = { ... },               -- optional extra patches (same structure as main)
    patch2 = { ... },
    patch3 = { ... },

    -- Skeletal deformation (optional)
    nodes = {                       -- anchor/joint references for skinning
        { type = "anchor", id = "sf3" },
        { type = "joint", id = "jnt1" },
    },
    influences = {                  -- computed weights per vertex (runtime)
        [1] = {                     -- vertex 1's influences
            { nodeIndex=1, body=<Body>, offx=0, offy=0,
              nodeType="anchor", nodeId="sf3", side=nil,
              dx=5.2, dy=3.1, dist=6.05, w=0.65 },
            { nodeIndex=2, body=<Body>, offx=0, offy=0,
              nodeType="joint", nodeId="jnt1", side="A",
              dx=10.1, dy=7.3, dist=12.46, w=0.35 },
        },
        [2] = { ... },  -- vertex 2
        -- ...
    },

    -- Runtime cache (stripped before save)
    ompImage = <love.Image>,        -- cached composite image
    _mesh = <love.Mesh>,            -- cached LÖVE mesh
}
```

### Other subtypes (simpler)

```
snap           extra = {}                              -- proximity joint trigger
anchor         extra = {}                              -- attachment point for deformation
connected-texture  extra = { nodes = [{type, id}] }    -- bezier ribbon between bodies
trace-vertices     extra = { zOffset = 0 }             -- haircut-style edge tracing
tile-repeat        extra = { zOffset = 0 }             -- tiled texture fill
resource           extra = { selectedBGIndex = 0 }     -- background image selector
meshusert          extra = { meshY = "88.89",          -- NOTE: string, not number!
                             nodes = [{type, id}] }
uvusert            extra = {}                          -- UV-mapped mesh
```

### Why This Matters

1. **No schema** — The `extra` structure varies per subtype with no validation. A typo in a field name creates silent bugs.
2. **meshY is a string** — This looks like a serialization accident. Something parses it as a number at runtime, but it's saved as a string.
3. **influences contain body references** — These must be stripped before save and restored after load via `restoreInfluenceBodies()` in io.lua:29-44. If a referenced node ID doesn't exist, the restore silently fails.
4. **OMP pipeline is 3 layers deep** — outline image + mask + pattern, each with color, alpha, flip, rotation, scale, translation. That's ~15 parameters per layer, times 4 layers (main + 3 patches) = 60 parameters per textured fixture.

---

## 3. OMP — Outline, Mask, Pattern

The mystery acronym. After reading the shader and `makeCombinedImages`, here's how it works:

```
Outline image (bgURL)  →  provides the line art / edge shape
Mask image (fgURL)     →  alpha channel defines where fill goes
Pattern image (pURL)   →  texture that fills the mask area
```

The `maskShader` (box2d-draw-textured.lua:230-243) composites these:
1. Background color fills everywhere the mask allows
2. Pattern texture is overlaid with rotation/scale/translation
3. Outline image provides the final alpha shape

`makeCombinedImages()` (line 488) renders this to a cached image per fixture, which is then mapped onto the polygon mesh during draw. The cache is invalidated by setting `extra.dirty = true`.

**Patches** (`patch1`, `patch2`, `patch3`) are additional layers drawn on top with the same pipeline — used for things like spots, scars, or detail textures on character parts.

This system is powerful but entirely undocumented. It's the core of how characters look.

---

## 4. Skeletal Mesh Deformation — Half-Shipped Feature

### What exists

1. **UI for setup** — In `playtime-ui.lua:1666-1775`, there's working code to compute influence weights:
   - `computeInfluences()` — calculates distance from each vertex to each node (anchor/joint)
   - `applyWeights()` — supports 3 weighting modes: inverse distance, gaussian, linear falloff
   - `pruneTopK()` — keeps only the K strongest influences per vertex (default 3), renormalizes

2. **Runtime deformation** — In `box2d-draw-textured.lua:1330-1366`, `deformWorldVerts()` transforms vertices based on current body positions weighted by influences

3. **Serialization** — `io.lua:29-44` has `restoreInfluenceBodies()` that re-links body references from IDs after loading, plus `remapAndRestoreInfluences()` for cloning

### What's missing

- **No user-visible UI to trigger influence computation** — The code exists but is buried deep in the sfixture editing panel. A user would need to know to click a specific button on a meshusert fixture.
- **No visual feedback** — No way to see the computed weights, the node connections, or the deformation preview in the editor.
- **Global function leak** — `renderDistances` at playtime-ui.lua:1755 is defined without `local` inside a nested scope.

### How it works conceptually

```
1. User creates a texfixture on a body
2. User adds "nodes" (anchors or joints) to the fixture
3. System computes influence weights: for each vertex, how much each node affects it
4. At draw time, each vertex position is computed as:
   finalPos = sum(weight_i * transform_by_body_i(bindPoseOffset_i))
5. The deformed vertices are used to build the draw mesh
```

This is essentially a **skeletal animation / skinning system** built on top of Box2D. The "bones" are physics bodies, the "skin" is the texfixture mesh.

---

## 5. Scene Scripts Are More Capable Than They Look

### Documented sandbox (in script.lua:35-64)

```lua
scriptEnv = {
    math, print, pairs, ipairs, tostring, tonumber, type, unpack, table, string,
    getObjectsByLabel, mouseWorldPos,
    worldState  -- reference to state.world
}
```

### What scripts actually access (from reading catapult.playtime.lua, torso.playtime.lua)

```lua
-- Full LÖVE API access:
love.physics.newWeldJoint(...)     -- create joints at runtime
love.graphics.setColor(...)        -- custom draw calls
love.graphics.circle(...)

-- Body manipulation:
body:setPosition(x, y)
body:setLinearVelocity(vx, vy)
body:setBullet(true)
fixture:setCategory(2)
fixture:setMask(2)
fixture:setSensor(true/false)
joint:getMaxLength()
joint:destroy()

-- Module access:
objectManager.recreateThingFromBody(body, settings)  -- torso.lua
ui.panel(...)                                          -- torso.lua
ui.sliderWithInput(...)                                -- torso.lua
ui.createLayout(...)                                   -- torso.lua
ui.nextLayoutPosition(...)                             -- torso.lua
ui.label(...)                                          -- torso.lua
```

### The gap

The sandbox in `script.lua` defines a limited environment, but scripts in practice reach far beyond it — accessing `love.*`, `objectManager`, `ui`, and doing direct physics manipulation. Either:
- The sandbox isn't actually enforced (scripts run in a wider scope), or
- These global names leak through from the host environment

This means scripts can do **anything** the main app can do, which is powerful but means there's no real sandboxing.

### Script hooks observed in practice

| Hook | Called from | Purpose |
|------|-----------|---------|
| `s.onStart()` | Scene load | Initialize variables, set up physics |
| `s.onKeyPress(key)` | main.lua keypressed | Respond to keyboard |
| `s.update(dt)` | main.lua update | Per-frame logic |
| `s.draw()` | main.lua draw | Custom rendering |
| `s.onPressed(objs)` | Input handler | Body clicked |
| `s.onReleased(objs)` | Input handler | Body released |
| `s.drawUI()` | UI draw | Custom UI panels |

**Note**: `s.update(dt)` (catapult) vs `s.onUpdate(dt)` — naming isn't consistent. Need to check which main.lua actually calls.

---

## 6. Soft Bodies (loveblobs) — Disabled Feature

### What's there

- `vendor/loveblobs/` contains `softbody.lua`, `softsurface.lua`, `util.lua`
- `object-manager.lua:finalizePolygonAsSoftSurface()` creates soft surfaces from drawn polygons
- The UI button for soft bodies exists but is **commented out** in `playtime-ui.lua:3228`:
  ```lua
  -- if ui.button(x, y, 260, 'blob') then
  ```

### Status

Partially integrated, disabled at the UI level. Unknown if it still works end-to-end. Could be a feature that was abandoned or is waiting for polish.

---

## 7. Test Infrastructure — RESOLVED

### Busted (primary — `spec/`)

Busted is now the primary test framework, installed for Lua 5.1 to run inside LÖVE.

| Spec file | Tests | Coverage |
|-----------|-------|----------|
| `math-utils_spec` | 56 | Geometry, paths, polygons |
| `utils_spec` | 42 | deepCopy, sanitizeString, etc. |
| `shapes_spec` | 63 | All geometry builders + createShape with real Box2D |
| `physics_spec` | 18 | Real physics: world, bodies, fixtures, joints, simulation |
| `io_spec` | 49 | needsDimProperty, influence remapping, gatherSaveData |
| `fixtures_spec` | 23 | Ordering invariant, all 9 sfixture subtypes |
| **Total** | **251** | |

Three ways to run:
- `busted spec/` — pure unit specs only (140 tests, no LÖVE needed)
- `love . --specs` — full suite including LÖVE integration (263 tests)
- `curl -X POST localhost:8001/specs` — via bridge while app is running

LÖVE-dependent specs are guarded with `if not love then return end`.

Test seams (`_test` tables) expose local functions on `shapes.lua` and `io.lua`.

### tests/ (mini-test.lua) — legacy

Still works (`lua tests/run.lua`, 17 tests). Not used for new tests.

---

## 8. Dead Weight Inventory

### Deleted files (Phase 0.1 — DONE)

These files were identified as dead weight and deleted (~17,500 lines removed):

| Item | Description | Status |
|------|-------------|--------|
| `src/polylineOLD.lua` | Old polyline renderer | **Deleted** |
| `temp/OLDOLD-dna.lua` | Old character DNA system | **Deleted** |
| `temp/OLDOLD-guycreation.lua` | Old character creation | **Deleted** |
| `output.md` | Generated concat2.lua output | **Deleted** |
| `profilingReportOLD2-5.txt` | Old profiling runs (4 files) | **Deleted** |
| `scripts/straightOLD.playtime.lua` | Old version of straight.lua | **Deleted** |
| `scripts/bettertOLD.playtime.json` | Old version of bettert.json | **Deleted** |

### Still present (not deleted — intentional)

| Item | Size | Description | Verdict |
|------|------|-------------|---------|
| `playtime-files/meta.playtime.json` | 91KB | Large scene file | Investigate — orphaned? |
| `concat2.lua` | 61 lines | Utility to dump all code to markdown | Dev tool, keep |
| `profiler.sh` | 98 bytes | Profiling helper script | Keep (still useful) |

### Dead code inside active files

| File | Code | Description | Status |
|------|------|-------------|--------|
| `box2d-draw-textured.lua:705` | `texturedCurveOLD2()` | Old bezier curve renderer | **Deleted** (Phase 0.2) |
| `box2d-draw-textured.lua:809` | `texturedCurveOLD()` | Older bezier curve renderer | **Deleted** (Phase 0.2) |
| `box2d-draw-textured.lua` | `drawSquishableHairOverOLD()` | Old hair renderer | **Deleted** (Phase 0.2) |
| `box2d-draw-textured.lua` | `doubleControlPointsOld()` | Old control point calculation | **Deleted** (Phase 0.2) |
| `main.lua:~480-815` | Character debug keybindings | ~335 lines of key handlers | **Extracted** to `src/character-experiments.lua` |
| `main.lua` | ~200 lines commented code | Commented-out experiments | **Deleted** (Phase 0.2) |

---

## 9. Asset Organization & Risks

### Texture directory structure

```
textures/
├── brow*.png          (eyebrow shapes)
├── ear*.png           (ear shapes, with -mask variants)
├── eye*.png           (eye shapes)
├── feet*.png          (foot shapes)
├── hair*.png          (hair textures)
├── hand*.png          (hand shapes)
├── leg*.png           (leg shapes)
├── lip*.png           (lip shapes)
├── neck*.png          (neck textures)
├── nose*.png          (nose shapes)
├── pupil*.png         (pupil shapes)
├── romp*.png          (torso shapes)
├── patch*.png         (torso detail patches)
├── shapeA*.png        (generic shapes for shape8 system)
├── teeth*.png         (teeth shapes)
├── borsthaar*.png     (chest hair)
├── knut/              (character-specific textures? ~18 files)
└── pat/               (pattern fill textures ~20 files)
```

~290 files, ~9.6MB total.

### Risks

1. **No texture manifest** — Nothing validates that textures referenced in scenes exist. A renamed or deleted texture fails silently.
2. **Naming conventions vary** — `feet2r.png` vs `feet1x.png`, `earx1r.png` vs `ear4r.png`. The suffixes (`r`, `x`, numbering) aren't consistent.
3. **Mask pairing** — Some textures have `*-mask.png` companions, others don't. The OMP system expects both outline and mask. Missing mask = broken rendering.
4. **The `knut/` subdirectory** — May be character-specific assets. If other characters need similar setups, this organization doesn't scale.

---

## 10. Things We Still Can't See

Even after this analysis, these remain opaque without running the app:

1. **What characters actually look like** — We can read the DNA data and OMP parameters, but we can't evaluate visual quality
2. **Performance in practice** — We know `drawWorldSettingsUI` is 42% of frame time from profiling notes, but we don't know current perf
3. **Which scenes are "good" test cases** — There are 40+ scene files but no indication which ones exercise which features
4. **What "looks wrong"** — The original motivation for some code (like the UV matching workaround) was probably "it looked wrong" — we can't evaluate visual correctness
5. **Interaction feel** — How dragging, snapping, and editing feel in practice. Timing, responsiveness, edge cases.
6. **Soft body behavior** — Whether loveblobs integration actually produces good-looking results
7. **Script behavior at runtime** — Whether catapult/torso/etc scripts work correctly with current code

These are exactly the gaps the tooling ideas (TOOLING-IDEAS.md) were designed to address — screenshot+metadata, state dumps, and validators can bridge much of this.

---

## Summary: What to Read First When Picking This Back Up

| If you're working on... | Read these first |
|--------------------------|-----------------|
| Character creation/DNA | `character-manager.lua:181-433` (DNA template), `DEEP-DIVE-NOTES.md` section 1, this doc section 1 (thing structure) |
| Textures/rendering | `box2d-draw-textured.lua:960+` (drawTexturedWorld), this doc sections 2-3 (fixture subtypes, OMP) |
| Save/load bugs | `io.lua:74-404` (buildWorld/load), `io.lua:430-700` (gatherSaveData), this doc section 2 (serialization gotchas) |
| Adding editor features | `playtime-ui.lua:3100+` (drawUI orchestrator), `input-manager.lua:24-416` (handlePointer), `DEEP-DIVE-NOTES.md` section 3 |
| Skeletal deformation | This doc section 4, `playtime-ui.lua:1666-1775` (weight computation), `box2d-draw-textured.lua:1330-1418` (runtime deform) |
| Scene scripting | This doc section 5, `script.lua`, any `.playtime.lua` file in scripts/ |
| Test infrastructure | `tests/run.lua`, `tests/mini-test.lua`, `spec/` (busted-style, possibly more complete) |
| Code cleanup | `MODULE-ANALYSIS.md` global leak inventory, this doc section 8 (dead weight) |
| Building CLI tools | `TOOLING-IDEAS.md`, `main.lua:1-6` (existing --test pattern) |

---

## All Documents in This Series

1. **`PROJECT.md`** — Original project overview (pre-existing, may be slightly outdated)
2. **`AI-COLLABORATION-PLAN.md`** — Priorities for making the codebase AI-friendly: tests, globals, extraction, integration tests, splitting
3. **`DEEP-DIVE-NOTES.md`** — Analysis of three pain points: DNA/character system, texture deformation, UI flow
4. **`TOOLING-IDEAS.md`** — 6 custom tools: state dump, scene validator, character report, structured events, round-trip checker, screenshot+metadata
5. **`MODULE-ANALYSIS.md`** — Full module inventory, dependency map, global leak list, serialization pipeline, solidification progression
6. **`BLIND-SPOTS.md`** _(this document)_ — Undocumented systems: thing structure, fixture subtypes, OMP pipeline, skeletal deformation, script capabilities, dead weight
