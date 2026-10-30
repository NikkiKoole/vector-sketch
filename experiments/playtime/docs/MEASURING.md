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
  calls, physics, the draw by kind, garbage per step, GPU stats. Real speed (no hooks), wall clock,
  so C time (Box2D, drawing) counts where it's spent. Usage at its top.
- `claudetools/sample-profile.lua`: LuaJIT's sampling profiler (jit.profile), a few % overhead:
  how the time splits between Lua, C and the garbage collector, the Lua functions by share of the
  Lua time, and a flame graph file for speedscope.app. It can't place C time on a function (it
  pinned 55% on a cache lookup worth 0.08 ms a frame): use frame-profile for that. Use ProFi only
  for call counts.
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
  40 KB joint guard, 25 KB mipo actions. But the sampler puts the collector at only ~1.3% of the
  time. The split (sample-profile): ~89% C (Box2D, LÖVE drawing, driver), ~10% Lua, ~1.3% GC; of
  the Lua time createDrawables is 32%. ProFi: 8500 `thingOf`, 14000 `subtypes.is`, 3000
  `physics-units.factors` calls a frame.
  **200 Mipos, physics paused (2026-10-30)**, the crowd plus default Mipos on a grid; paused means
  no world step and no Mipo behaviour, only drawing and face animation:

  | Mipos | update | draw | textured: texfixture / ribbons / list / sort | garbage | draw calls | textures |
  |---|---|---|---|---|---|---|
  | 20  | 0.9 ms  | 12.4 ms  | 2.7 / 2.3 / 1.3 / 0.3   | 0.6 MB | 612  | 80 MB  |
  | 50  | 2.6 ms  | 27.6 ms  | 6.0 / 5.3 / 3.3 / 0.8   | 1.2 MB | 1395 | 115 MB |
  | 100 | 9.4 ms  | 59.7 ms  | 12.7 / 11.0 / 7.4 / 1.9 | 2.4 MB | 2700 | 172 MB |
  | 200 | 25 ms   | 125 ms   | 27.5 / 23.6 / 16.1 / 4.3 | 4.8 MB | 5310 | 286 MB |

  Drawing grows in step with the Mipos: ~0.6 ms each (~8 fps at 200). The paused update grows
  faster (mipo face 0.3 -> 11.7 ms, blobs-before 0.3 -> 9.9 ms with no blobs): their loops are
  linear, but they allocate first after the draw's garbage, so the GC's steps are charged to them.
  The sampler: GC 1.3% of the time at 20 Mipos, 5.4% at 200; Lua 10% -> 40%. So the garbage (M7)
  matters more the more Mipos there are. Making a Mipo: 2-5 ms (more with more Mipos around).
  Texture memory ~1.1 MB a default Mipo.
  Other findings that day: the sampler at 1 ms hung the game at 200 Mipos (a timer signal keeps
  restarting a C call longer than the interval; now 10 ms); `/eval` answers slowly at ~7 fps, so
  poll for results rather than wait a fixed time; nothing off screen is culled, texfixture fans are
  rebuilt every frame though they don't change, ribbons recomputed while still: see
  [MIPO-DRAWING.md](MIPO-DRAWING.md) (levels L0-L4 to draw Mipos cheaper, with their cost).
  Lessons (2026-10-30): compare before/after in one running process (swap the files, lurker reloads
  them) when other programs load the machine (node scripts at ~170% CPU made an hour-old number look
  like a 40% regression); a render test must bake (`makeCombinedImages`) before setting its canvas.
- [ ] **M4. Memory over a long session.** The image and OMP caches are never cleared (DEEPER-ISSUES).
  The bake is one module now (`render/omp-bake.lua`): count what's cached, watch it over 10 minutes
  of randomizing (M3 can run that), then cap or clear it.
- [ ] **M5. Micro-benchmarks for the pure parts.** busted benches for skinning, the polygon modules
  and song planning: they run anywhere, the web build too.
- [ ] **M8. The 17 ms.** Mostly C: the ~600 draw calls and the per-frame mesh rewrites (ribbons'
  setVertices, squish fans), and Box2D (2.7 ms). Then Lua: createDrawables + sort (rebuilt every
  frame; keep the list while nothing was added or removed?).
- [ ] **M7. The draw's garbage.** ~430 KB a frame from the textured draw (per-drawable tables, fan
  vertex tables, a Bezier curve per ribbon per frame, mouth polygons). Only ~1.3% of the time on
  the desktop, so after M8; worth it before an iPad build. Fix main.lua's "~1.6 KB" comment.
- [x] **M9. Missing bodyhair masks.** `borsthaar1..7-mask.png` don't exist, and getLoveImage asked the
  filesystem again every frame (40 a frame in the crowd, 0.08 ms). **Done 2026-10-30:** getLoveImage
  and the Mipo editor's thumbnail grid remember what isn't there (`spec/omp-bake_spec.lua`); scenes
  and Mipos identical. Left as is: bodyhair DNA still names the masks (changing it changes saved
  Mipos for no visible difference).
- [ ] **M6. The potato-torso click.** The editor snapshot forces every slider to its midpoint; on a
  potato head's torso1 panel that makes a shape Box2D refuses (`fixtures.lua:132: Box2D assertion
  failed`), and the next click finds the Mipo half rebuilt. Same before and after the splits, so
  older. Find which slider, and keep its values to shapes Box2D takes.
