# Measuring — speed, memory, and "nothing changed"

status: parked — pick up when something feels slow, or before the next big refactor

After the October cleanup and splits (CODE-CLEANUP-2026-10, CODE-SPLITS-2026-10) the work sits in
named modules: the renderer in `src/render/` with one draw function per kind, Mipos in `mipo-*`,
music in `music-*`, io in `scene-*`. So a measurement can now say *which* part costs, and some
parts (music-theory, skinning's `meshusertVertices`, the polygon modules) run without a window.

## What there is

- `state.drawTimes = { frames = 0, ms = {}, count = {} }` over the bridge: draw time per drawable kind,
  plus building and sorting the list.
- `POST /profile/frames` (ProFi over real frames, ms and calls per frame per function) and
  `POST /profile/benchmark` (a snippet). ProFi names a function by how it's called: the draw loop
  calls `draw(d)`, so the drawers show as `draw  box2d-draw-textured.lua:<line>` (the line says which).
- `claudetools/frame-profile.lua`: where a frame goes, step by step: every update step main.lua
  calls, physics, the draw by kind, garbage per step, GPU stats. Real speed (no hooks). Usage at its top.
- `./playtime.sh audio`: synth dropouts and what was busy then.
- `claudetools/snapshot.sh`: before/after snapshots for refactors that shouldn't change anything:
  scenes (pixel hash of every scene in scripts/, knut/, tech/), mipos (6 seeded Mipos through
  create, randomize, parts, mutate, save and load), editor (every ui call of the Mipo editor, then
  every widget clicked once). `take before`, change, `take after`, `diff before after`.

## Steps

- [x] **M1. Named draw functions.** `drawers` / `mouth.drawers` list named functions (one table to
  read; ProFi still names them by the call, see above). Done 2026-10-30.
- [x] **M2. Snapshots kept.** The SPLIT1-3 safety nets as `claudetools/snapshots/` + `snapshot.sh`.
  Done 2026-10-30.
- [x] **M3. A standing benchmark.** `claudetools/frame-profile.lua` in the running game (a copy on
  its own bridge port: `--scene crowd`). A report, not a pass/fail spec. Done 2026-10-30.
  **The crowd, 2026-10-30** (20 Mipos, 380 bodies, 305 joints, Apple M1, interpreter, editor):
  update 5.5 ms (physics 2.7, joint guard 0.9, keep angle 0.5, mipo actions 0.45, blobs 0.3),
  draw 11.6 ms (textured 8.6: texfixture 2.6 for 200, connected-texture 2.1 for 160 ribbons,
  createDrawables 1.3, mouth backdrop 0.7, brows 0.6, sort 0.4; the rest is the editor's outlines
  and panels, ~2 ms in play mode too). About 17 ms of CPU a frame: at the edge of 60 fps.
  **Garbage: ~610 KB a frame** (main.lua's comment says ~1.6 KB): 430 KB from the textured draw,
  40 KB joint guard, 25 KB mipo actions. ProFi: 8500 `thingOf`, 14000 `subtypes.is`, 3000
  `physics-units.factors` calls a frame: tiny functions, but the interpreter pays for each call.
- [ ] **M4. Memory over a long session.** The image and OMP caches are never cleared (DEEPER-ISSUES).
  The bake is one module now (`render/omp-bake.lua`): count what's cached, watch it over 10 minutes
  of randomizing (M3 can run that), then cap or clear it.
- [ ] **M5. Micro-benchmarks for the pure parts.** busted benches for skinning, the polygon modules
  and song planning: they run anywhere, the web build too.
- [ ] **M7. The draw's garbage.** Find what the textured draw allocates per frame (the per-drawable
  tables in createDrawables, squish-fan vertex tables, a Bezier curve per ribbon per frame, mouth
  polygons) and reuse it. Then check main.lua's GC comment and the frame time again (M3).
- [ ] **M8. The 17 ms.** After M7: texfixture and ribbons per drawable, createDrawables + sort
  (rebuilt every frame; cache while nothing moved?), the hot tiny calls (thingOf, subtypes.is,
  units.factors) in the update loops.
- [ ] **M6. The potato-torso click.** The editor snapshot forces every slider to its midpoint; on a
  potato head's torso1 panel that makes a shape Box2D refuses (`fixtures.lua:132: Box2D assertion
  failed`), and the next click finds the Mipo half rebuilt. Same before and after the splits, so
  older. Find which slider, and keep its values to shapes Box2D takes.
