# MESHUSERT Spine-Bind Mode — Plan

Add a second bind mode to MESHUSERT that deforms the paired RESOURCE's polygon via a Bezier curve through the node chain — the same smooth-bend behaviour CONNECTED_TEXTURE gives its ribbon, but applied to an arbitrary traced polygon with backdrop-captured UVs.

**Cross-references:** `SPINE-MESH-PLAN.md` (the original generic-spine-mesh plan, now superseded by this one for the playtime integration), `experiments/spine-humanoid-sandbox/` (the math proven in isolation).

## Why here, not a new subtype

MESHUSERT already has every piece this feature needs:

- Paired RESOURCE by label → polygon, uvs, triangles, meshVertices
- `ud.extra.nodes` → chain of joints/anchors
- Bind-state storage model (extending, not disrupting)
- Draw path that iterates triangles, transforms verts, draws mesh
- Z-order groups, triangle painter, save/load plumbing

Adding a new sfixture subtype would duplicate all of that. The only meaningful difference between "DQS MESHUSERT" and "spine-bind MESHUSERT" is **how each vertex gets transformed**. Everything else — polygon source, UVs, triangulation, render path, persistence — is identical.

Hence: a `bindMode` field on MESHUSERT, not a new subtype.

## Data model

Single new field on `ud.extra`:

```
ud.extra.bindMode = 'dqs' | 'spine'    -- default 'dqs' for backward compat
```

When `bindMode == 'spine'`, a new bind-state field holds the spine-bind data:

```
ud.extra.spineBind = {
    tsPerVert   = { t1, s1, t2, s2, ... },  -- one (t, s) pair per polygon vert
    bindNodes   = { {x,y}, {x,y}, ... },    -- world positions of nodes at bind time
                                            -- (ordered same as ud.extra.nodes)
}
```

Existing DQS fields (`influences`, `bindVerts`, `rigidLookup`, `rigidBindCoords`, `triangleBones`) are untouched and ignored while `bindMode == 'spine'`.

Switching modes drops the other mode's bind state (same pattern as triangulation-mode changes today).

## Draw-path changes

In `src/physics/box2d-draw-textured.lua` MESHUSERT branch, branch on `bindMode`:

- `dqs` (default) → existing DQS logic, unchanged
- `spine` → call the spine evaluator with `spineBind.tsPerVert` + live node positions, producing deformed verts; hand them to the same textured-mesh render code DQS uses

Rest of the MESHUSERT draw (meshVertices source, triangle index array, triangleGroup re-ordering, UV lookup) works unchanged regardless of bind mode.

## Bind-flow

The sfixture-editor.lua MESHUSERT panel gains a small mode toggle. The single "bind" button's behaviour branches on mode:

- **DQS bind** (existing): computes influences from node world positions + bind radius + segment weights.
- **Spine bind** (new):
  1. Snapshot current world positions of each node → `bindNodes`.
  2. Build a rest polyline from those nodes.
  3. For each vert of the RESOURCE's polygon, compute `(t, s)` against the polyline.
  4. Store as `spineBind.tsPerVert`.

Unbind clears whichever bind state is present for the active mode.

## `src/spine-mesh.lua` — ported from the sandbox

The math already exists and works (`experiments/spine-humanoid-sandbox/spine-mesh.lua`). Port into `src/spine-mesh.lua` with:

- `arcLengths`, `closestOnPolyline`, `doubleControlPoints` as internal helpers.
- `bind(polygon, chain)` → returns `{ tsPerVert, bindNodes }`.
- `evaluate(spineBind, liveNodes, bendiness)` → returns deformed flat verts.

Single-chain only for v1. No soft-root, no multi-chain, no weighted blending. Those stay as sandbox experiments until there's a concrete case for them.

## Invalidation

Same hooks as existing MESHUSERT bind state:

- Polygon-vertex-count change in `src/object-manager.lua:recreateThingFromBody` — drop `spineBind` (same block where we already drop `triangleBones`, `triangleGroups`, `uvs`, etc.).
- Node list change (add/remove node in the MESHUSERT panel) — drop `spineBind`. Re-bind needed.
- Mode toggle — drop the other mode's bind state.

## Save / load

`ud.extra.bindMode` + `ud.extra.spineBind` serialize as plain fields via the existing JSON path. No special handling needed in `src/io.lua`; `gatherSaveData` and `buildWorld` copy `ud.extra` as-is today.

Zero file-format migration for existing scenes: missing `bindMode` defaults to `'dqs'`, missing `spineBind` is fine because DQS mode doesn't read it.

## UI changes

Minimal. `src/ui/sfixture-editor.lua` MESHUSERT panel:

- Mode toggle button (two-state: DQS / Spine) next to the existing bind/unbind controls.
- The bind button label updates to show which mode it'll bind for.
- A small `bendiness` slider (0..6) visible only in spine mode, analogous to the bind-radius / spacing sliders.

No new panels, no new modes, no new pickers.

## Phases

### Phase 1 — core port + draw branch
- Port sandbox's `spine-mesh.lua` to `src/spine-mesh.lua` (single-chain version only; drop multi-chain helpers, soft-root, cartoon-arm, etc.).
- Add `bindMode` + `spineBind` fields to MESHUSERT creation defaults.
- Add spine-mode branch in `box2d-draw-textured.lua` MESHUSERT draw loop.
- Add mode toggle + spine-bind button to `src/ui/sfixture-editor.lua`.
- Wire polygon-vert-count invalidation in `recreateThingFromBody`.
- Verify on one traced limb with backdrop-captured UVs: bind spine mode, drag the joint chain's owner bodies, mesh deforms smoothly.

### Phase 2 — author polish (later, only if needed)
- Bendiness slider in UI.
- Visual overlay of the rest spine while a MESHUSERT is selected in spine mode.
- Better mode switch UX (confirm before dropping bind state).

### Phase 3 — advanced, only if real need emerges
- Soft-root at the root node (reuse sandbox math).
- Weighted multi-chain (reuse sandbox math).
- Per-triangle rigid override compatible with spine mode.

## Decisions settled

- **Single-chain only.** Spine-bind uses the node list as one linear chain. Multi-chain is sandbox research for later.
- **Either/or mode.** A MESHUSERT is DQS OR spine, not both simultaneously. Switching drops the old bind.
- **Default mode stays `dqs`.** Zero behavioural change for existing scenes.
- **No CONNECTED_TEXTURE changes.** That system keeps its strip-PNG niche.
- **Bezier + `doubleControlPoints`** for the curve, matching CONNECTED_TEXTURE. Bendiness is the `dups` param, 0–6.
- **(t, s) captured at bind time** from current node world positions. Rebind = recapture.

## Open questions (answer before starting if possible)

- **meshRot / scaleX/Y / meshX/Y interaction.** These transform the polygon before the DQS path in current MESHUSERT. Simplest for spine mode: apply them to `meshVertices` the same way (pre-transform), then bind/evaluate as usual. Needs to be confirmed on a real case but probably trivial.
- **Node-order direction.** Spine direction follows the order of `ud.extra.nodes`. If the user adds nodes in a different order than the limb runs, spine will run backwards. Fine for a POC; could add a "reverse nodes" button later.
- **What if the user binds spine with <2 nodes?** Bind fails gracefully, no-op, UI says "need ≥2 nodes."

## What this doesn't do

- Doesn't replace DQS. Existing Mipos keep working exactly as today.
- Doesn't touch CONNECTED_TEXTURE or its strip-PNG workflow.
- Doesn't add soft-root / multi-chain / weighted blending.
- Doesn't change file format (purely additive fields).
- Doesn't solve "whole body as one mesh" — that's separate (cutout or multi-chain bind, both out of scope).

## Files touched (estimate)

- `src/spine-mesh.lua` — new, ~120 lines (sandbox port, trimmed)
- `src/physics/box2d-draw-textured.lua` — ~40 lines added (spine-mode branch)
- `src/ui/sfixture-editor.lua` — ~30 lines added (mode toggle + bind routing)
- `src/object-manager.lua` — 2 lines added (drop `spineBind` on vert-count change)
- `src/fixture-types.lua` or wherever MESHUSERT defaults live — `bindMode = 'dqs'` default
- `docs/MESHUSERT-SPINE-BIND-PLAN.md` — this doc

Roughly 200 lines net, one new file, four existing files lightly modified.

## Rollback plan

Each phase is a separate commit. Phase 1 is self-contained: if anything goes wrong, revert the phase-1 commit and the codebase is back to DQS-only MESHUSERT. Existing scenes don't touch `bindMode` or `spineBind` so there's no migration to undo.
