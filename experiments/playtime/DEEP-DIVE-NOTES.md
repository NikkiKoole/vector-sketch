# Deep Dive Notes: Pain Points

Analysis of the three areas where development got stuck, with ideas for improvement.

---

## 1. DNA / Character System (`character-manager.lua`)

### The Problem

The character topology (who connects to who, where) is encoded in **cascading if/elseif chains** rather than in data. Three functions carry most of the burden:

- **`getParentAndChildrenFromPartName`** (lines 537-692) — 155 lines of branching that manually handles every combination of `isPotatoHead`, `neckSegments`, `torsoSegments`, `noseSegments` to return {parent, children} for a given part name.

- **`getOwnOffset`** (lines 698-823) — Returns where on THIS body the attachment point is. Repeats the same shape8 vertex lookup 6+ times with minor variations per body part.

- **`getOffsetFromParent`** (lines 826-1079) — 250 lines. Returns where on the PARENT body this part attaches. Same repeated pattern, plus special cases for arms-on-torso, legs-on-torso, ears-on-head-vs-potato, nose positioning via lerp, etc.

The repeated pattern in both offset functions is:
```lua
if part.shape == 'shape8' then
    local raw = shape8Dict[part.shape8URL].v
    local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
    local index = getTransformedIndex(N, sign(part.dims.sx), sign(part.dims.sy))
    return -vertices[(index * 2) - 1] * scale, vertices[(index * 2)] * scale
else
    return 0, (part.dims.h / 2) * scale
end
```

This appears at least 6 times for: torso, head, ears, feet, hands, nose.

### Why It's Painful

- Adding a new body part (e.g. tail, wings) means touching `getParentAndChildrenFromPartName`, `getOwnOffset`, AND `getOffsetFromParent` — each with new branches for every combination of creation flags.
- Changing how a part connects (e.g. ear attachment point) requires finding the right branch in 250 lines of elseif.
- The `shape8Dict` (lines 137-178) is ~40 entries of hardcoded vertex data for textures. Adding a new shape texture means manually copying coordinates.
- Bugs are hard to find because the same logic is spread across 3 functions with subtle differences.

### Other Issues

- `add` (line 102) is a **global function** that just merges tables. It shadows any other meaning of "add" in the entire program.
- `createDefaultTextureDNABlock` (line 66) and `initBlock` (line 85) are also globals.
- The DNA template (lines 181-433) mixes data (dimensions, joint limits) with runtime objects (calling `initBlock()` which creates cached color data at require-time).
- `updateSinglePart` (line 1226) recursively rebuilds children, but destroys and recreates physics bodies each time — expensive for a small dimension change.

### Improvement Direction: Topology as Data

Instead of encoding parent/child relationships and attachment points in code, put them in the DNA template:

```lua
-- Current: logic scattered across 3 functions
['luleg'] = {
    dims = { w = 80, h = 200, w2 = 4 },
    shape = 'capsule',
    j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } }
}

-- Proposed: self-describing attachment
['luleg'] = {
    dims = { w = 80, h = 200, w2 = 4 },
    shape = 'capsule',
    j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } },
    parent = 'torso1',               -- or function(creation) return 'torso'..creation.torsoSegments end
    parentAttach = { vertex = 6, lerp = {to = 5, t = 0.5} },  -- "between vertex 6 and 5, at t=0.5"
    ownAttach = { edge = 'top' },    -- "top of my bounding box" or { vertex = 1 }
    angleOffset = 0,
}
```

Then the three giant functions collapse into one generic resolver:

```lua
function getAttachmentPoint(partName, instance)
    local partData = instance.dna.parts[partName]
    local attach = partData.parentAttach
    if attach.vertex then
        return getVertexPoint(parentBody, attach.vertex, scale)
    elseif attach.lerp then
        local a = getVertexPoint(parentBody, attach.lerp.from, scale)
        local b = getVertexPoint(parentBody, attach.lerp.to, scale)
        return lerp(a, b, attach.lerp.t)
    elseif attach.edge then
        return getEdgeCenter(parentBody, attach.edge, scale)
    end
end
```

**Benefits**:
- Adding a new body part = adding one table entry, no code changes
- Attachment points are visible in the data, not buried in code
- The resolver function is testable (unit tests with mock vertex data)
- `shape8Dict` lookup happens in one place

### What About Segmented Parts (torso1..N, neck1..N, nose1..N)?

These are currently handled by templates (`torso-segment-template`) that get deep-copied at creation time. The proposed system still works — the segment generation code in `createCharacterFromExistingDNA` would stamp out parts with computed parent names:

```lua
for i = 1, torsoSegments do
    local partName = 'torso' .. i
    parts[partName] = deepCopy(template)
    parts[partName].parent = (i == 1) and nil or ('torso' .. (i - 1))
    parts[partName].parentAttach = { vertex = 1 }  -- top of previous torso
end
```

---

## 2. Texture Deformation (`box2d-draw-textured.lua`)

### The Problem

`drawTexturedWorld` (line 960) is a ~900 line function containing **6 different rendering paths**, each with its own data pipeline:

| Type | Lines | What It Does | Caching? |
|------|-------|-------------|----------|
| `texfixture` | 1230-1270 | Fan mesh stretching image to polygon vertices | OMP images cached, meshes pooled |
| `connected-texture` | 1644-1693 | Bezier curve ribbon between joints | Strip meshes cached |
| `trace-vertices` | 1761-1830 | Image along a subset of polygon edges (haircut) | Mesh created every frame |
| `tile-repeat` | 1695-1759 | Tiled texture across triangulated polygon | Mesh cached on first draw |
| `meshusert` | 1380-1505 | Custom mesh with vertex deformation via influences | Mesh created every frame |
| `uvusert` | 1507-1642 | Custom mesh with UV mapping from resource fixture | Mesh created every frame |

### Specific Issues

**1. The UV matching in meshusert/uvusert is fragile** (appears at lines 1471-1480 and 1566-1575):
```lua
for l = 1, #verts do
    if math.abs(x - verts[l]) < 0.001 then
        u = data.uvs[l]
    end
    if math.abs(y - verts[l]) < 0.001 then
        v = data.uvs[l]
    end
end
```
This matches x/y coordinates independently against ALL vertex values to find UV pairs. If two vertices share a similar x or y value, it picks the wrong UV. It should use vertex indices instead.

**2. `addMidpoint` is defined as a global inside the draw loop** (line 1071):
```lua
function addMidpoint(points)  -- global, defined inside drawTexturedWorld!
```

**3. Deformation math is in the draw loop** — `deformWorldVerts` (line 1330) computes weighted blends of joint/anchor influences per vertex every frame. This should be computed in update and cached.

**4. Three versions of the same function exist**:
- `texturedCurve` (line 750) — current, optimized
- `texturedCurveOLD2` (line 705) — previous version
- `texturedCurveOLD` (line 809) — oldest version
- Same for `drawSquishableHairOver` / `drawSquishableHairOverOLD`
- Same for `doubleControlPoints` / `doubleControlPointsOld`

**5. `createDrawables`** (line 964) rebuilds the entire drawable list from scratch every frame by iterating all bodies and all fixtures. The TODO comment on line 1118 acknowledges this.

### Improvement Direction

**Separate the rendering paths** — each type becomes its own module or at least its own top-level function:
```
src/render/texfixture.lua
src/render/connected-texture.lua
src/render/trace-vertices.lua
src/render/tile-repeat.lua
src/render/mesh-deform.lua
src/render/uv-mapped.lua
```

**Fix the UV pipeline for meshusert/uvusert**:
- At load time (not draw time), store UVs indexed by vertex index, not by coordinate matching
- The `data.uvs` array should directly correspond to vertex indices: `uvs[vertexIndex] = {u, v}`
- Then in the draw loop: `u, v = data.uvs[vertexIndex].u, data.uvs[vertexIndex].v`

**Cache the drawable list**:
- Build it once when scene loads or when objects change
- Mark dirty when bodies/fixtures are added/removed
- Sort only when dirty

**Move deformation to update**:
- Compute `deformWorldVerts` in `love.update()` and store results in the fixture's userData
- In draw, just read the cached deformed vertices

**Delete OLD versions** of texturedCurve, drawSquishableHairOver, doubleControlPoints once confirmed the new ones work.

---

## 3. UI Flow (`playtime-ui.lua`)

### The Problem

The file has 3,527 lines with 12 public functions. The main orchestrator `drawUI` (line 3100) is 425 lines of:

```lua
if ui.button('add shape') then toggle panel end
if panel open then lib.drawAddShapeUI() end
if ui.button('add joint') then toggle panel end
if panel open then lib.drawAddJointUI() end
-- ... repeated for every panel
```

Each panel function both **renders the UI** and **directly mutates physics state**. For example, inside drawUpdateSelectedObjectUI you'll find things like:
- `objectManager.destroyBody(body)` — deletes a physics body
- `joints.recreateJoint(joint, newSettings)` — recreates a joint
- `fixtures.createSFixture(body, ...)` — creates fixtures
- Direct mutations of body userData

### Why This Makes Extension Hard

To add a new editable property to a body:
1. Find the right spot in `drawUpdateSelectedObjectUI` (~600+ lines for the selected body panel)
2. Add a slider/checkbox/button
3. Add the mutation logic inline
4. Add serialization in `io.lua`
5. Maybe add input handling in `input-manager.lua`

The UI file is too big to search through effectively, and the interleaving of rendering and logic makes it hard to understand what a change will affect.

### The drawWorldSettingsUI Performance Issue

From profiling notes in PROJECT.md: `drawWorldSettingsUI` alone is ~42% of frame time. This is the settings panel (line 934). It likely creates/lays out many sliders and checkboxes every frame even when the panel isn't interacted with. Worth investigating whether the immediate-mode UI is doing unnecessary work when values haven't changed.

### Improvement Direction

**Split by context** — each panel type gets its own file:
```
src/ui/toolbar.lua              -- top button bar
src/ui/add-shape-panel.lua      -- shape creation
src/ui/add-joint-panel.lua      -- joint creation
src/ui/world-settings.lua       -- world settings (the performance bottleneck)
src/ui/body-inspector.lua       -- selected body editing
src/ui/joint-inspector.lua      -- selected joint editing
src/ui/sfixture-inspector.lua   -- selected sfixture editing
src/ui/multi-select.lua         -- multi-body selection
src/ui/dialogs.lua              -- save, quit, color picker
```

The orchestrator becomes:
```lua
function lib.drawUI()
    ui.startFrame()
    toolbar.draw()
    if state.selection.selectedObj then bodyInspector.draw() end
    if state.selection.selectedJoint then jointInspector.draw() end
    dialogs.draw()
end
```

**Optional: separate intent from execution**. Instead of UI code directly calling `objectManager.destroyBody()`, the UI produces an action table:
```lua
-- In body-inspector.lua:
if ui.button(x, y, w, 'delete') then
    return { action = 'destroyBody', body = body }
end

-- In main.lua or a coordinator:
local action = bodyInspector.draw()
if action then executeAction(action) end
```

This makes the UI testable without a physics world, and centralizes all state mutations.

**This is the lowest-priority refactor** — the current UI works, it's just hard to extend. Do it incrementally: extract one panel when you need to modify it.

---

## Summary: What to Tackle When

| Area | Difficulty | Impact on Getting Unstuck | Suggested Timing |
|------|-----------|--------------------------|-----------------|
| DNA topology-as-data | Medium-high | **Highest** — directly unblocks adding body parts | First |
| Fix globals in all 3 files | Low | Prevents subtle bugs | Anytime (quick wins) |
| Texture UV pipeline fix | Medium | Unblocks meshusert/uvusert | When you return to deformation |
| Delete dead code (OLD functions) | Low | Reduces confusion | Anytime |
| Cache drawable list | Medium | Performance win | When perf matters |
| Move deformation to update | Medium | Correctness + perf | With UV pipeline fix |
| Split playtime-ui.lua | Medium (incremental) | Makes extension easier | As needed, panel by panel |
