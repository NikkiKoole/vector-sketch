# Rigging friction audit

Short notes from walking through the rigging flow in playtime. Used to decide
whether rigging needs its own editor mode or just targeted fixes. See
`docs/UV-BACKDROP-FRAGILITY.md` for the texture/UV deep-dive.

## 2026-04-15

- **Default scene opens textureless.** `scripts/test.playtime.json` has
  `selectedBGIndex: 0` but no `selectedBGURL`, no `backdrops` field, no `uvs`
  on the RESOURCE. `state.backdrops = {}` at startup. Hits
  `UV-BACKDROP-FRAGILITY.md` #1/#2/#3 at once. Good friction-audit bait.
  → middle fix: snapshot `{url, rect}` into RESOURCE at bind; big fix: split
  backdrops into references / scene-bg / textures.
- **Mesh was invisible on load.** Two vertex-color bugs in
  `box2d-draw-textured.lua:1593,1615` (`.100` byte → 0; missing 4th color
  component → 0 alpha). Fixed. Also added `lib.drawMeshOutline` debug wireframe.
- **Scene reload crashed.** `scene-loader.lua` wasn't clearing
  `selectedSFixture` / `selectedBodies`; stale fixture ref in
  `editor-render.lua:58` crashed on `:getUserData()`. Fixed both.
- **meshX/Y + scaleX/Y sliders dead after bind.** Transforms baked into
  `bindVerts` at bind time, then thrown away in draw path
  (`box2d-draw-textured.lua:1547-1565`). Fixed: hidden post-bind behind an
  "adjust transform" toggle so you can still tweak + re-bind when you want.
- **Mesh visually "jumps" after bind** from bone position → polygon position.
  Fixed: bind now captures `bindVerts` in the MESHUSERT-owning body (bone)
  world space, matching the pre-bind draw path. What-you-see-is-what-you-bind.
  (`sfixture-editor.lua`)
- **No way to undo bind.** Fixed: added "unbind (reset mesh)" button — clears
  influences / bindVerts / vertexAssignments so the mesh falls back to the
  undeformed draw path. Keeps nodes + transforms for quick re-bind.
- **Point-distance weights collapse mesh width at joints.** Fixed: ported
  segment-distance + smoothstep weighting from `deform-textured/main.lua:570`.
  Consecutive node pairs on the same body form bone segments; each vertex
  weights by distance-to-segment instead of distance-to-anchor-point. Added
  `bindRadius` slider (default 80). Confirmed working on test scene.
  Deferred: per-endpoint radii — decided to prefer "add more anchors" for
  coverage/control before adding per-node radii knobs. Alpha-aware path check
  still TODO.
- **No visual feedback for bindRadius.** Fixed: orange capsule outline rendered
  around each bone segment when MESHUSERT is selected (`editor-render.lua`).
  Updates live as slider moves.
- **Texture/triangulation flickered during deformation.** Per-frame
  `mathutils.decompose` added Steiner points when the deformed polygon became
  self-intersecting; those points had no UVs → corner-pixel texture artifacts.
  Fixed: pre-triangulate the polygon ONCE at UV-compute time on the rest pose,
  store triangle vertex indices in `data.triangles`. Draw is now an index
  lookup — stable topology, direct UV access, no per-frame triangulation.
- **Backdrop images lazy-loaded in draw loop** meant `w/h` unknown at scene
  load time, so anything that needed the rect (UV compute, etc) couldn't run
  until first draw. Fixed: `io.lua` `buildWorld` now eagerly calls
  `love.graphics.newImage` for every backdrop on scene load and populates
  `image/w/h` immediately.
- **UVs only computed when RESOURCE selected in UI.** Scene loads with a
  backdrop and a RESOURCE but no UVs → mesh renders untextured until you
  click the RESOURCE. Fixed: post-load pass in `io.lua` `buildWorld` auto-
  computes UVs + triangle indices for any RESOURCE with `selectedBGIndex` but
  missing `uvs`/`triangles`. Default scene now opens fully textured with
  zero UI interaction.
- **Triangulation-to-indices lookup fell off a precision cliff.** `%.3f`
  string-key matching missed triangle verts whose floats rounded to
  different strings than the source polygon (e.g. `5606.9775` → `"5606.978"`
  vs source `5606.9774` → `"5606.977"`, ~1e-4 drift from love.math.triangulate).
  Result: `triangles` never stored → fallback to per-frame triangulation →
  weird triangles during deformation. Fixed: extracted
  `mathutils.triangulateToIndices(polyVerts, tol)` using nearest-vertex
  matching with 0.01 tolerance. Used by both io.lua auto-compute and
  sfixture-editor UI compute.
- **No way to align bones to drawn character pre-bind.** Capsules/rects are
  axis-aligned; drawn images are at arbitrary rotations. Had to manually
  rotate each bone one at a time, breaking the chain connections. Fixed:
  R + mousewheel over a body now FK-rotates that body plus its descendant
  joint chain around the parent joint anchor. Shift = fine step (~0.3°).
  `src/body-rotate.lua` + hook in `main.lua` `love.wheelmoved`.

- **Texture slightly misaligned with polygon (~3-4 px drift).** UV,
  mesh-render, and bind-pose all centered by `mean-of-verts` (polyCenter)
  while collision-polygon render used `body.position`. Drift =
  `(body.position - polyCenter)` ≈ 3-4 px. Fixed: all three now center by
  the polygon body's `getPosition()` so mesh, texture, collision, and
  bindVerts live in the same frame. (First attempt via `body:getLocalPoint`
  broke everything because `thing.vertices` isn't true world coords —
  it's authoring-world, only equal to world while the body hasn't been
  moved since save.)
- **Textured mesh picked up a brownish/tinted cast** from whichever TEXFIXTURE
  (OMP character) happened to draw just before it. Global `love.graphics`
  color state leaks across the drawables loop; mesh vertex colors are white
  so the leftover tint multiplies straight through. Fixed:
  `love.graphics.setColor(1,1,1,1)` before the mesh draw in
  `box2d-draw-textured.lua` MESHUSERT branch.
- **CDT bridging triangles across armpits / crotches.** Centroid-inside
  filter alone lets Delaunay span a triangle across a concave notch when
  the centroid happens to land in the solid mass next door. Fixed:
  `filterInsidePoly` in `src/cdt.lua` now also drops any triangle whose
  edges properly cross a polygon outline edge. Caveat: won't catch
  bridges that run parallel-to or along the outline inside thin concave
  pockets — that'd still need proper CDT with edge-flipping. Verified
  on a synthetic U-shape test (0 bridges) and on the real character.
- **Long, skinny triangles across the polygon even at rest.** Ear-clipping on
  a concave silhouette picks ears in vertex order; no interior verts means
  every triangle spans outline-to-outline. Visible as sliver artifacts that
  worsen during deformation. Addon shipped: `src/cdt.lua` — Bowyer-Watson
  Delaunay on {polygon outline + interior Steiner points}, centroid-inside-
  polygon filter, shared entry `cdt.computeResourceMesh`. A/B toggle on the
  MESHUSERT panel flips `state.triangulationMode` between `'basic'` and
  `'cdt'`, recomputes the linked RESOURCE's mesh, and clears the MESHUSERT
  bind so the user re-binds against the new topology. Polygon outline is
  stored first in `meshVertices` so UVs remain aligned for legacy paths.
  Fallback: if CDT fails it falls back to basic automatically.

- **MESHUSERT centering used live RESOURCE body position.** Caused three
  symptoms: (1) mesh positioned wrong, (2) moving RESOURCE body moved mesh
  in mirrored direction, (3) UVs mapped out-of-bounds → brown texture.
  Root cause: `thing.vertices` is in authoring-world space (frozen at
  creation), but centering subtracted the RESOURCE body's *current*
  position. Body gets moved after creation → mismatch. Fixed both sides:
  - **Render** (`box2d-draw-textured.lua`): center by
    `computeCentroid(verts)` (bbox center) — same as
    `makeShapeListFromPolygon` uses for fixtures. Stable, matches
    collision polygon.
  - **UV compute** (`cdt.lua`): convert each vertex to actual world
    position via `body:getWorldPoint(vert - computeCentroid)` before
    mapping to backdrop rect. Handles moved + rotated bodies.

## Next session — directions

- Walk through building a full skeleton: spine + arms + legs as multiple
  bones, then a single mesh skinned across them. Test segment weighting at
  scale (does width hold across 5+ bones? do anchors-per-bone scale up
  comfortably?).
- May surface: joint chain ordering, anchor placement UX, weight visualization
  needs, connected-texture for hair/straps as second pipeline.
- Proper constrained Delaunay (edge-flip pass to enforce outline edges) — for
  deeply concave silhouettes where unconstrained Delaunay's centroid filter
  drops real triangles.
- Steiner spacing control (slider) — right now auto-picks from bbox/12.
  Denser = smoother, slower; surface the tradeoff.
