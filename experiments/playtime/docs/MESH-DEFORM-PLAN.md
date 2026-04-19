# Mesh Deform — Triangle Painter Plan

Five goals for the MESHUSERT triangle painter and humanoid authoring. Status tracked inline. All changes live in the working tree (uncommitted) unless noted.

## Goal 1 — Paint triangles → bones
**Status:** done.

Per-triangle bone assignment drives DQS (instead of segment-weight auto-bind).

- **Data:** `ud.extra.triangleBones[triIdx] = nodeIndex` on the MESHUSERT sfixture.
- **UI:** reuse the triangle-select brush; add a bone picker (nodes list) and "Assign to bone N" button alongside the group picker in `src/ui/sfixture-editor.lua`. Clear selection after Assign (same pattern as groups).
- **Draw path:** `src/physics/box2d-draw-textured.lua` DQS sampling — if `triangleBones[t]` is set, use that node's bind transform for all 3 verts of triangle `t`; else fall back to current per-vertex influences.
- **Invalidation:** retriangulation (`src/cdt.lua`) and polygon-vertex change (`src/object-manager.lua`) already drop group data; add `triangleBones = nil` at the same spots.
- **Open design question:** per-triangle *rigid* (whole tri follows one bone — cheap, may show seams at bone boundaries) vs per-triangle *blend* (2–3 weighted bones per tri — smoother seams, more UI). Start rigid; upgrade only if seams look bad.

## Goal 2 — Z-ordering by group
**Status:** done (committed). UI hidden behind `if false` in sfixture-editor.lua — re-enable once bones are proven. May fold into bone-driven z-order.

- **Data:** `ud.extra.triangleGroups[triIdx]` + `ud.extra.triangleOrderDirty` on RESOURCE sfixture.
- **Sort:** stable, lower group drawn first. Reorders `triangles` + `triangleGroups` together in `box2d-draw-textured.lua:1610+`.
- **Invalidation:** retriangulation + polygon-vertex change drop groups and clear dirty flag.
- **UI:** 1–8 group picker buttons tinted with a cheap-hash color (`(g*73, g*151, g*211) % 256 / 255`). Paint with brush → "Assign to group N" → selection clears.
- **Overlay colors (editor-render.lua):** grouped tris get their group color at 0.25 alpha; selected tris preview the *target* group's color at 0.55 alpha (so you can see what Assign will paint).

### Bugs hit during goal 2 (already fixed in working tree)
- **Selection overlay was orange for every group** — swapped for target-group color preview.
- **Clicking Assign repeatedly painted *different* triangles each time** — the sort reshuffles `triangles`, which makes the ordinal `selectedTriangles` indices stale. Fix: clear `state.triangleEditor.selectedTriangles = {}` right after Assign. Same applies to goal 1's bone assign.

### Verification tip
Group-color tints only show in the editor overlay. Real z-order proof is in the textured draw: paint two *overlapping* regions (e.g. hand to group 5, torso to group 1), then the hand tris should render on top where they overlap.

## Goal 3 — Drop nodes/anchors?
**Status:** deferred until goals 1+2 are lived with.

Open question: if every triangle has a bone and a group, do we still need the node/anchor abstraction? Answer only after painting a real character. Revisit once goal 1 is stable.

## Goal 4 — Combined-strip mesh — **PARKED**
**Status:** parked. Merger primitive built and validated; bridging approach abandoned. Industry-standard cutout + z-order is the better default — see Goal 5.

### What we built before parking
- `src/strip-merge.lua` — `merge(bodyIds)` and `mergeAndBridge(bodyIds, opts)`. Extracts each ribbon body's `thing.vertices`, transforms from authoring-world through body-local (via `body:getWorldPoint` on `vert - centroid(thing.vertices)`) into the host's local frame, concatenates verts + index-shifted triangles. Per-ribbon meta tracked so every triangle knows its source strip.
- `editor-render.lua` → `lib.renderStripMergeOverlay()` — renders the cached merge result in the host's world space, colored per ribbon (cheap hash). Bridge tris render white/red to stand out. Toggleable via `state.stripMergeOverlay.enabled`; populated from bridge `/eval`.
- `buildBridges(combined, opts)` — naive nearest-foreign-vertex stitcher. For each ribbon's two end-ribs, finds the closest foreign vert to each rib point; if both within `threshold`, emits 2 triangles.

### Why we parked it
Proximity-only junction detection is fragile: picks wrong verts, double-detects the same junction from both sides, and can't distinguish "close but not connected" from "connected." Authoring-side hints (snap-on-draw, explicit connection points, joint-anchor-driven detection) would fix it, but at that point you're building non-trivial authoring UX for something no industry tool actually does.

Spine, Live2D, DragonBones, Moho, Rive — none merge separately-authored mesh pieces procedurally. They all use overlapping attachments with z-order. When they want a continuous-skin look, it's authored as one polygon from the start, with per-vertex weighted bones at joints. Procedural stitch tools (Maya Bridge, Blender Bridge Edge Loops) require manual edge-loop pairing — not proximity guessing.

### If we ever unpark
The primitive in `strip-merge.lua` is a solid starting point. What's missing:
- Authoring-side help to make junctions unambiguous. Pick one of: (a) snap-on-draw for endpoint↔endpoint and endpoint↔path coincidence, (b) explicit connection-point objects, (c) joint-anchor-driven detection (reuse the existing joint tool).
- `pathPoints` persistence (currently only the resulting ribbon polygon is kept).
- Winding alignment (bridge tris don't match the rest of the mesh's winding yet).
- RESOURCE/MESHUSERT sfixture creation from the merge result.

## Goal 5 — Cutout + z-order (industry-standard humanoid workflow)
**Status:** active direction. Most of the infrastructure already exists.

### Framing
A humanoid is N separate strip meshes (1 per limb + torso), each on its own body, each bound to its own bone. Joints overlap visually; z-order hides the seam. This is what every 2D skeletal tool does (Spine, Live2D, DragonBones, Moho, Rive). No procedural bridging, no continuous-mesh authoring.

### What's already in place
- Freepath → ribbon body → `triangulateRibbon` gives each limb clean bone-aligned strip topology for collision.
- **RESOURCE on a ribbon now uses strip triangulation too** (`src/cdt.lua:computeResourceMesh`). Without this fix, `love.math.triangulate` would ear-clip the ribbon polygon into a fan from vertex 1 — triangles spoking off one corner, spanning the bone axis, deforming badly under multi-bone skinning. Detection is `thing.shapeType == 'ribbon'`; produces `triangulationMode = 'strip'`. Non-ribbon bodies keep the existing basic/cdt/refined path.
- Goal 1 (paint tris → bones) works per-mesh.
- Goal 2 (z-order groups within a mesh) works per-mesh.
- `thing.zOffset` on bodies already drives cross-body render order.

### Authoring flow
1. Draw N freepaths (one per limb/torso), positioning verts against the reference texture.
2. Paint tris → bones on each mesh as needed (Goal 1 UI).
3. Set `zOffset` per body so overlap renders correctly at joints (arm above torso, etc.).
4. Add Box2D joints between bodies for physics.

### What might still need doing
- **Per-body z-offset UI polish.** There's a field; check it's exposed in `body-editor.lua` and easy to tweak. "Send forward / send back" shortcut would be nice.
- **Overlap authoring hint.** When drawing a limb that should overlap the torso, the artist needs to extend the strip's end a bit *past* the joint. No tool needed; just guidance in docs.
- **Soft-looking seams** (optional): if a hard overlap line looks bad in Knut's style, later option is blended per-vertex weights across a joint. But that requires one-mesh authoring — Goal 4 territory. Cross that bridge if/when it matters.

### Things to delete / clean up (eventually)
- `src/strip-merge.lua` — keep for now as a useful debug tool; remove when confident Goal 4 stays parked.
- `renderStripMergeOverlay` + `state.stripMergeOverlay` in editor-render/state — same.
- The `main.lua` call to `renderStripMergeOverlay()` — same.

## Restore-from-error checklist

If hot-reload crashes or a field goes nil mid-edit:

- `state.triangleEditor = { selectedTriangles = {}, selectedGroup = 1, brushSize = 20 }` — reset if fields missing (see `src/state.lua`)
- On RESOURCE `ud.extra`: `triangles` (required, from CDT), `triangleGroups` (nil-safe), `triangleOrderDirty` (nil-safe)
- On MESHUSERT `ud.extra`: `triangleBones` (future, nil-safe), `influences` / `bindVerts` (DQS, clear together via unbind button)
- Draw path must no-op when `triangles` is nil — falls back to `shapes.makeTrianglesFromPolygon` (already in place)
- Selection math uses `mextra.meshVertices` (CDT output with Steiner points) or falls back to polygon verts — both paths must stay aligned with the draw path
- Groups/bones are **index-keyed into `triangles`**. If the triangulation changes, they become meaningless — always drop them at the same time `triangles` is rebuilt.

## Files touched (uncommitted working tree)

- `spec/modes_spec.lua` — rename test
- `src/cdt.lua` — drop `triangleGroups` on retriangulation
- `src/editor-render.lua` — triangle fill/outline overlay, group-color preview
- `src/input-manager.lua` — brush hit-test against tri centroid, selection via `meshVertices`
- `src/modes.lua` — `EDIT_MESH_VERTS` → `EDIT_MESH_TRIS`
- `src/object-manager.lua` — drop `triangleGroups` on polygon-vertex change
- `src/physics/box2d-draw-textured.lua` — stable sort of `triangles` by group when dirty
- `src/playtime-ui.lua` — renamed delegator
- `src/state.lua` — `state.vertexEditor` → `state.triangleEditor` (slim struct)
- `src/ui/sfixture-editor.lua` — painter UI, group picker, Assign button, clear-all, clear-on-assign
