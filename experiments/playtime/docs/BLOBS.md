# Blobs: textured soft bodies as real Playtime things

Scope, 2026-10-29. A squishy body that wobbles, squashes and bounces back into shape, wearing
the same OMP textures as the Mipos' heads and bodies. For jelly toys, pillows, puddings, a blob
Mipo, a blob head on a normal Mipo.

## What exists

- **Playtime's `vendor/loveblobs`**: `softbody` (a ring of small circle bodies, each tied to a
  centre body and to its neighbours with distance joints) and `softsurface` (a jelly floor
  from a polygon). Behind `state.world.playWithSoftbodies` (off, no UI switch): right-click
  spawns one (`input-manager.lua:606`), `main.lua:238` adds a test blob and floor, and a free
  polygon can be finished as a soft surface (`object-manager.lua:21`). Drawn as a flat colour
  (`editor-render.lua:163`). Not saved, not in the registry, not selectable.
- **`experiments/loveblobs2`**: the same library plus `options` (stiffness, damping, friction,
  restitution), a textured draw (`softbody.lua:192`) and push/rotate/move helpers
  (`main.lua:138-290`). The textured draw is a proof of concept: a new mesh every frame, a fan
  without a centre vertex (breaks on concave shapes) and planar UVs with a hard-coded stretch.
  Take the idea, not the code.
- **The shape outlines**: every head/body texture has an 8-point outline in texture pixels,
  `shape8Dict` in `character-manager.lua:916` (shapeA1-4, shapes1-13). That is the rest shape
  of a blob, and it tells where each rim point sits in the texture.
- **OMP baking** works per texfixture (`makeCombinedImages`), so a blob's picture can be baked,
  randomized and edited in the Mipo editor like any part.
- Elsewhere: dreamengine `jelly.c` (rim + gas pressure, area restore: squishier and stacks
  better; `HARVEST-NAVKIT-DREAMENGINE.md` #3) and the bathhouse mud clusters (overlapping
  circles, not a soft body).

## Design: a blob is a normal body with a SOFTBODY sfixture

Like the grass sfixture (blades generated from the body, not saved one by one), the blob's rim is
generated at runtime from settings stored on an sfixture:

- **The centre** is an ordinary Playtime body: registered, saved, selectable, clonable, can carry
  behaviors and joints (so a blob can be a Mipo's head on the neck joint). Its own collision
  shape becomes a small inner circle so it doesn't fight the rim.
- **The SOFTBODY sfixture** (new subtype) persists `extra = { outline = 'shapeA1.png',
  nodes = 24, stiffness, damping, friction, restitution, pressure? }`. On create/load it
  spawns the rim: the 8-point outline smoothed (Catmull-Rom) and resampled into N points, a
  small circle body per point, spoke joints to the centre and rim joints between neighbours.
  Rim bodies are *not* registered (no clutter in the editor, not saved). Their fixtures get
  table userData pointing back at the centre, so grabbing a rim point grabs the blob.
- **The texture** is the centre body's texfixture with OMP, baked as today. Drawing: one mesh
  per blob, a fan with a centre vertex, built once; each frame only the vertex positions are
  updated (`setVertices`). UVs are fixed at creation from each rim point's rest position:
  `u = x / w + 0.5, v = y / h + 0.5` (with mirror), so squashing the rim squashes the picture.
  Plasticine shading can run on top.
- **Editor**: moving or rotating the centre in the editor moves the rim with it (rebuild or
  transform the rim); the inspector gets the stiffness/damping/nodes sliders from the
  sfixture params, like grass.

## Order

1. **Spike (S, ~half a day)**: a scene script that makes one blob from `shapeA1` with a baked OMP
   texture and the fan mesh draw. Answers the only real unknowns: does it look good squashed,
   and does it hold the head shape (the 8-point outlines are not round; spokes should hold it,
   otherwise add pressure).
2. **Real thing (M)**: SOFTBODY subtype, rim generation on create/load, save/load, the draw in
   `box2d-draw-textured.lua`, grab through rim fixtures, editor move/rotate, clone, inspector
   params, a "blob" entry in the toys menu. Retire the old `playWithSoftbodies` path.
3. **Later**: pressure (area restore, from `jelly.c`) for puddings that stack; a blob head on a
   Mipo; a soft-surface floor (jelly floor, bouncy castle) through the same sfixture idea.

## Costs and risks

- Physics: ~24 rim bodies + ~48 joints per blob, about one Mipo's worth. A few toys per room are
  fine; dozens are not.
- Small fast rim circles tunnel through thin floors. loveblobs sets `isBullet` (Playtime's copy
  calls `b:isBullet(true)`, a getter, so that's actually off: use `setBullet`).
- Fixtures with non-table userData (loveblobs puts the node index there) already needed a guard
  in the draw code (`box2d-draw-textured.lua`, "softbodies"); the table back-pointer fixes that.
- Door/room carrying (`WORLDS-AND-DOORS.md`) has to bring the rim along, or rebuild it on arrival.
