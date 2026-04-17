# Mesh Deform — Triangle Painter Plan

Three goals for the MESHUSERT triangle painter. Status tracked inline. All changes live in the working tree (uncommitted) unless noted.

## Goal 1 — Paint triangles → bones
**Status:** not started. This is the next step.

Per-triangle bone assignment drives DQS (instead of segment-weight auto-bind).

- **Data:** `ud.extra.triangleBones[triIdx] = nodeIndex` on the MESHUSERT sfixture.
- **UI:** reuse the triangle-select brush; add a bone picker (nodes list) and "Assign to bone N" button alongside the group picker in `src/ui/sfixture-editor.lua`. Clear selection after Assign (same pattern as groups).
- **Draw path:** `src/physics/box2d-draw-textured.lua` DQS sampling — if `triangleBones[t]` is set, use that node's bind transform for all 3 verts of triangle `t`; else fall back to current per-vertex influences.
- **Invalidation:** retriangulation (`src/cdt.lua`) and polygon-vertex change (`src/object-manager.lua`) already drop group data; add `triangleBones = nil` at the same spots.
- **Open design question:** per-triangle *rigid* (whole tri follows one bone — cheap, may show seams at bone boundaries) vs per-triangle *blend* (2–3 weighted bones per tri — smoother seams, more UI). Start rigid; upgrade only if seams look bad.

## Goal 2 — Z-ordering by group
**Status:** done (working-tree diff, not committed).

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
