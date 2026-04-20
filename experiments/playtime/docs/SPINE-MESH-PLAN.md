# Spine-Deformed Mesh — Plan

A hybrid between CONNECTED_TEXTURE (smooth bendy curve through joints) and MESHUSERT (arbitrary polygon with backdrop UVs). The goal: use limb-shaped traced meshes whose **silhouette** can be anything (traced from an illustration) and whose **deformation** comes from a live Bezier through the limb's joint anchors — no DQS weight painting, no manual Steiner-for-smoothness.

**Started:** commit `78d7e127` (this plan). POC attempt followed in the same session.

## Pivot — humanoid-first sandbox (added after first POC attempt)

The original Phase 1 plan (generic polygon + arbitrary node chain, driven from inside playtime) produced layout pain: unsorted `pairs()` order for nodes, coordinate-frame ambiguity between body-local / authoring-world, forward-reference bugs, and visible wrong behaviour even when the math ran. Debugging inside the full playtime editor is hard because too many things move at once.

**New plan:** skip straight to a **predefined humanoid skeleton** in a minimal standalone LÖVE app. Bounded topology, no ordering guesses, no playtime dependencies. Same spine-mesh math, but applied to known-named chains.

### The humanoid skeleton schema

~12 named joints with a fixed parent-child structure:

```
pelvis
 ├── spine  → chest → neck → head
 ├── leftShoulder  → leftElbow  → leftWrist
 ├── rightShoulder → rightElbow → rightWrist
 ├── leftHip  → leftKnee  → leftAnkle
 └── rightHip → rightKnee → rightAnkle
```

Each limb is a fixed 3-point chain. No runtime inference of "which nodes form this limb" — it's data in the schema.

### Sandbox plan

Build `experiments/spine-humanoid-sandbox/` (parallel to playtime, zero deps on it):

- `main.lua` — LÖVE entry, draggable joints, renders.
- `skeleton.lua` — joint schema (names, defaults, parent-child table).
- `spine-mesh.lua` — copy of bind/evaluate, simplified for hardcoded chains.
- Maybe `limb.lua` — a hand-authored limb polygon for one arm to start.

Phases inside the sandbox:
- **A — Skeleton layout only.** 12 joints at sensible defaults. Drag any with the mouse. No meshes yet. Visual feedback on connectivity (draw lines between parent-child).
- **B — One traced limb bound to its chain.** Spine-mesh math on just `[leftShoulder, leftElbow, leftWrist]` + a hardcoded arm polygon. Move the three joints, see the arm deform.
- **C — All 4 limbs + torso.** Copy bindings; torso is a static polygon anchored to shoulders/hips.
- **D — Texturing.** UVs from a backdrop image.

When the math is solid in the sandbox, promote back into playtime by (1) replacing CONNECTED_TEXTURE's ribbon constraint with traced-mesh-per-limb in `src/character-manager.lua`, and (2) providing playtime-authoring tools for the polygon tracing step.

### What changes in the original plan

The "Phase 1 POC" section below was written assuming the generic-polygon-inside-playtime path. That's now replaced by sandbox Phase A–C. Phase 2 (subtype decision) and later still apply, after the sandbox proves the geometry. If you read beyond this section, treat the Phase 1 descriptions as historical — the live POC is now in the sandbox.

## Why

The three existing paths each miss something:

| | MESHUSERT | CONNECTED_TEXTURE | This proposal |
|---|---|---|---|
| Arbitrary silhouette (any traced shape) | yes | **no** (ribbon only) | yes |
| Arbitrary UV source (backdrop/illustration) | yes | **no** (strip texture) | yes |
| Smooth bending for free | no | yes | yes |
| No weight painting / bind tuning | no | yes | yes |
| Sharp-bend tolerance | needs Steiners + weights | miter clamp handles it | miter clamp handles it |

For Knut (storybook illustrations, gentle articulation, art not always ideal), this is the pattern that fits. Limbs traced from the page with their actual silhouette, deform smoothly via a Bezier spine.

## Concept — (t, s) decomposition

Each limb mesh is bound to a **rest spine** (a polyline along the limb's axis). For each vertex, decompose position into:

- `t` — arc-length parameter, `[0..1]` along the spine
- `s` — signed perpendicular distance from the spine at that `t`

Store `(t, s)` per vertex instead of absolute coords. At runtime:

1. Gather live joint positions → build a Bezier curve (same path CONNECTED_TEXTURE uses, including `doubleControlPoints` for tight corners).
2. For each vertex: evaluate curve at `t` → world point; evaluate tangent → normal. Place vertex at `curvePoint + s * normal`.
3. Miter-clamp at sharp bends (reuse CONNECTED_TEXTURE's clamp math).
4. UVs are captured at rest pose; travel with vertices unchanged.

No DQS. No per-vertex weighted bones. The curve **is** the skeleton.

## What's reused, what's new

### Reused as-is
- Freepath authoring, `polylineRibbon`, `triangulateRibbonIndexed` — pick a ribbon body as starting point.
- Custom polygon authoring (if starting from a traced shape rather than freepath).
- `cdt.computeResourceMesh` — polygon + Steiner → triangulation + UV capture.
- Steiner authoring (orthogonal — still useful for interior detail, not needed for smoothness).
- CONNECTED_TEXTURE's Bezier-from-joints + `doubleControlPoints` + miter clamp math.
- MESHUSERT's draw path (the mesh becomes another textured-polygon drawable).

### Genuinely new
1. **Rest-spine source.**
   - Freepath body: `thing.pathPoints` (need to persist it — currently thrown away after polygon construction).
   - Custom polygon / ribbon from other sources: derive spine as the polyline through the bound joints' initial world positions.
2. **`(t, s)` bind.** For each vertex: find closest point on rest spine, record arc-length `t` and signed perpendicular `s`. Standard polyline geometry, ~30 lines.
3. **Runtime evaluator.** Loop verts, evaluate curve at `t`, place at `curvePoint ± s·normal`, miter-clamp. ~30 lines.
4. **Subtype.** New `SPINE_MESH` sfixture subtype, or a bind mode on MESHUSERT. See Phase 2 discussion.

Total: ~2 days including a working POC, not counting polish.

## Phases

### Phase 1 — POC (one limb, one hand, minimal UI)

Goal: prove the geometry works. No save/load, no permanent subtype, bridge-triggered.

- Pick a ribbon body in the scene with a freepath + joints (e.g. a Mipo-style limb chain).
- Add a module `src/spine-mesh.lua`:
  - `lib.bindVerts(thing, joints) -> {t, s} per vertex`, using `thing.vertices` + rest-pose joint positions as spine.
  - `lib.evaluate(bind, joints) -> deformed vertex array`, using live joint positions + Bezier + miter clamp.
- Editor-render overlay that draws the deformed verts on top of the live scene. Bridge `/eval` toggle to turn it on for a selected body.
- Visually verify: move a joint, mesh bends.

Parked artifacts: `src/strip-merge.lua` was the same kind of experiment (merge-and-bridge). Keep this lighter; if the POC doesn't pan out, delete the module cleanly.

### Phase 2 — Choose the subtype shape

Two options:

**2A. New `SPINE_MESH` sfixture subtype.**
- Clean separation: only spine-mesh bodies carry the `(t, s)` bind data.
- Draw path is its own branch in `box2d-draw-textured.lua`.
- Doesn't disturb existing MESHUSERT users.

**2B. Extend MESHUSERT with a "spine-bind" mode.**
- `ud.extra.bindMode = 'dqs' | 'spine'`.
- Spine mode replaces the DQS vert-transform pass with curve evaluation.
- Shares the triangulation + UV pipeline.
- Existing MESHUSERTs keep working; new ones can opt in.

**Recommendation: 2B.** Less architectural disruption; MESHUSERT already owns "textured polygon with nodes that deform it." Spine mode is a new transform strategy, not a new kind of mesh. Keeps the z-order / triangle-groups / etc. infrastructure shared.

### Phase 3 — Authoring flow

The path-from-freepath case is easiest. Steps:

1. User draws a freepath (existing). That's the rest spine.
2. Body becomes a RIBBON with `thing.pathPoints` persisted (new — today `pathPoints` is lost after `polylineRibbon`). Freepath pathPoints define both the ribbon polygon and the rest spine.
3. User connects the ribbon's joint anchors (endpoints + any mid-path joints) with revolute joints to neighbouring bodies. Standard joint tool.
4. Add a MESHUSERT with `bindMode = 'spine'` and node list = those joints. The bind pass:
   - Uses `thing.pathPoints` as rest spine.
   - Computes `(t, s)` per vertex of `thing.vertices`.
5. Render uses spine evaluator. UV capture from backdrop (unchanged).

The traced-custom-polygon case (no freepath): rest spine is derived at bind time as a polyline through the joint anchors' rest positions. `(t, s)` computed relative to that. Same runtime.

### Phase 4 — Polish

- **Vertex-count invalidation.** Polygon edit → `(t, s)` array is stale. Drop + rebind (same pattern as dropping `triangles`/`meshVertices`).
- **Joint-count invalidation.** User adds/removes a joint to the chain → spine topology changes → rebind.
- **Inspector.** Show the rest-spine overlay when the mesh is selected (visual feedback for the bind).
- **Miter-clamp reuse.** Extract CONNECTED_TEXTURE's clamp math into `math-utils` so both share one implementation.

## Decisions to settle before Phase 1

1. **Rest spine source for ribbon bodies** — do we persist `thing.pathPoints` (new field) or re-derive from `thing.vertices` top-row at bind time? Persisting is safer (loses information only when the user edits the path explicitly).
2. **Rest spine source for non-ribbon custom polygons** — accept that we need joint positions at rest to derive the spine. No explicit spine authoring.
3. **Curve type.** Bezier via `love.math.newBezierCurve(points)` with `doubleControlPoints` — matches CONNECTED_TEXTURE exactly. No new math.
4. **Stack order of transforms.** `meshRot` / `scaleX/Y` / `meshX/Y` already exist on MESHUSERT. In spine-bind mode, do these apply? Simplest: they apply after the curve evaluation (post-transform). Revisit only if the behaviour feels wrong.

## Honest caveats

- **Not sharp bones.** A 90° elbow becomes a smooth-ish bend, like CONNECTED_TEXTURE's. Feature for storybook style; anti-feature for a rigid-corner aesthetic.
- **Spine must be linear.** No branching. Torso with outgoing arms + legs doesn't fit; it stays a normal mesh or cutout piece. Spine-mesh is a *limb* tool, not a whole-character tool.
- **Rest pose dependency.** The `(t, s)` decomposition is relative to rest-pose joints. Re-bind if the rest setup changes.
- **Polygon topology relative to spine.** Works well when the polygon is "ribbon-shaped-ish" — all verts reasonably near the spine. Fails gracefully for weird shapes (just looks unsettled under motion).

## Success criteria for the POC

1. Move a joint mid-chain → the mesh silhouette bends smoothly at that point.
2. Rotate a joint 90° → no inner-edge fold (miter clamp holds).
3. Traced limb with a bulged calf / knot / etc. → bulge travels correctly down the spine under motion.
4. UV sampled from backdrop → texture looks continuous under bending, not torn.

If all four hold on one limb, commit to Phase 2 (integration into MESHUSERT). If any fail, flag before committing to the subtype decision.

## Relationship to other plans

- `STEINER-OWNERSHIP-PLAN.md` — orthogonal. Steiners still useful for interior detail within a spine-mesh. Doesn't interact with spine-bind math; triangles are just denser.
- `MESH-DEFORM-PLAN.md` — this is a Phase-5-ish addition for the humanoid workflow. Previous goals (triangle painter, z-order groups, strip topology for ribbons) stay as-is.
- `REBUILD-IN-PLAYTIME.md` — if this pattern works, porting Mipo to Knut (with illustrated limbs) becomes viable without forcing ribbon-strip texture art.
- `LIBRARY-AND-RESOURCES.md` — a spine-mesh limb could be a library item later: stored as rest spine + polygon + UVs.

## What this doesn't do

- Doesn't replace MESHUSERT for characters whose pieces can't be spine-described (e.g. torso with four outgoing attachments).
- Doesn't add weight painting; if crease control at bone boundaries becomes the bottleneck, that's still a separate project.
- Doesn't solve shoulder/hip attachment between limb and torso — that remains a cutout-style overlap problem.
