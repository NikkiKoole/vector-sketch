# Measuring — speed, memory, and "nothing changed"

status: parked — the phone baseline is in (M10, 2026-10-31); pick up when something feels slow, or before the next big refactor

After the October cleanup and splits (CODE-CLEANUP-2026-10, CODE-SPLITS-2026-10) the work sits in
named modules: the renderer in `src/render/` with one draw function per kind, Mipos in `mipo-*`,
music in `music-*`, io in `scene-*`. So a measurement can now say *which* part costs, and some
parts (music-theory, skinning's `meshusertVertices`, the polygon modules) run without a window.

## What there is

- `./playtime.sh device [scene] [--play]`: Playtime on the iPhone/iPad (cable or wifi, ~20 s), its
  bridge on the phone's wifi address. `./playtime.sh bench [localhost|device] [secs] [--parts]`
  (`src/frame-bench.lua`): frame, update and draw times, the slow frames with the frame before and
  whether a GC step ran, how much slow motion the loop's budget made; `--parts` times each part of
  `love.update` (Box2D is what's left).
- Live switches for A/B in one session: `require('src.render.ribbon').useNative`,
  `require('src.mipo-joint-guard').scanEvery`, `state.loopBudgetMs`.
- `state.drawTimes = { frames = 0, ms = {}, count = {} }` over the bridge: draw time per drawable kind,
  plus building and sorting the list (seconds in `ms`, despite the name).
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
  **2026-10-30:** the Lua half done in MIPO-DRAWING L0-L1c (kept draw list, kept fans and strips,
  culling): draw 11.9 -> 10.5 ms at 20 Mipos, 62 -> 6 ms at 100 with a normal camera. Left: the
  draw calls (L2a, measure on the iPad first) and the update (unchanged, Box2D the biggest part).
  **2026-10-31:** measured on the iPhone instead (M10) and cut there. Left: the textured shapes'
  draw calls (~1.7 ms on the phone with nothing moving: L2a), Box2D (~2 ms: resting Mipos never
  sleep, the balance keeps them awake), spine skin and ear bends in C (≤0.5 ms).
  **Later that day** (the crowd on the phone, live A/B where a switch allowed): bent pictures in C
  (texfixtures 1.65 -> 0.98 ms), blobs and liquid only asked about their own sfixtures (0.55 ms
  -> ~0), drawWorld remembering which bodies hide under pictures (0.83 -> 0.57, the rest draws
  the props). The crowd: update ~4.4, draw ~5.2, ~9.6 of 16.7 ms. Tried and dropped: the ribbon
  prep in C (no change: what's left per ribbon is reading the joints, the upload, the draw), L2
  (MIPO-DRAWING.md). Next if needed: Box2D (resting Mipos asleep), the Mipo update parts
  (joint guard 0.7, actions 0.5, keep-angle 0.4).
  **The Mipo update parts, probed** (timing points, not kept): arm posing 0.32 (of actions 0.48),
  the untangle 0.31 (of the guard 0.66: per Mipo checked, up to 3 raycasts a joint, and a ray
  reports every sensor it crosses to Lua), keep-angle's balancing 0.24 (170 parts, honest work)
  and its walk over all 380 bodies for their behaviors 0.18, unstick 0.16, the rest < 0.1 each.
  `mipoRegistry.jointBetween` now remembers the joint (getJoints and getBodies every call, ~6 a
  Mipo a step from the arm posing): arm posing 0.32 -> 0.22. Left on purpose: keep-angle's walk
  (remembering each body's thing breaks on an editor flip, which gives a body a new thing) and
  the untangle (cheaper means checking less, a behaviour change: e.g. only Mipos touching
  another Mipo, as the contact tracker knows).
- [ ] **M7. The draw's garbage.** ~430 KB a frame from the textured draw (per-drawable tables, fan
  vertex tables, a Bezier curve per ribbon per frame, mouth polygons). Only ~1.3% of the time on
  the desktop, so after M8; worth it before an iPad build.
  **2026-10-30:** L1-L1c took most of it: 613 -> 289 KB a frame at 20 Mipos, 2.6 MB -> 0.47 MB at
  100 on screen; main.lua's comment fixed. Left: what's still made per frame (find it with
  frame-profile's garbage per step).
- [x] **M9. Missing bodyhair masks.** `borsthaar1..7-mask.png` don't exist, and getLoveImage asked the
  filesystem again every frame (40 a frame in the crowd, 0.08 ms). **Done 2026-10-30:** getLoveImage
  and the Mipo editor's thumbnail grid remember what isn't there (`spec/omp-bake_spec.lua`); scenes
  and Mipos identical. Left as is: bodyhair DNA still names the masks (changing it changes saved
  Mipos for no visible difference).
- [x] **M10. On the phone.** The floor is an iPhone SE 2 (A13, iOS 18; Retina, sound on).
  **Done 2026-10-31.** Dollhouse: 60 fps, ~5 ms a frame. The crowd in play mode (20 Mipos):

  | | update | draw | frame used | fps |
  |---|---|---|---|---|
  | before | 7.1 ms | 9.2 ms | ~16.3 ms | ~54, 30-40% late |
  | after | 4.5 ms | 6.0 ms | ~10.5 ms | 60 |

  What it took: lurker's file check off on phones (a 25 ms scan every 0.5 s); mouth backdrops
  from a cached mesh, no stencil (1.0 -> 0.5 ms); the joint guard's all-Mipo scan every 2nd step
  (-0.5 ms); ribbons (limbs, lips, brows) laid in C, `native/desound/ribbon.c` (28 -> 4 us a strip,
  -1.5 ms); sfixtures masked, feet and lower legs excepted (contacts 4950 -> 2100, Box2D
  3.6 -> 2 ms). Desktop: 60 fps up to ~30-35 Mipos (40: 10 -> 37 fps); past that the loop's time
  budget plays it in slow motion (`state.loopBudgetMs`, 60 Mipos 28 fps at a third of real time).
  **How far it goes** (the same day, Mipos dropped into the crowd in steps, one pile):

  | Mipos | fps | late frames | frame used | game speed |
  |---|---|---|---|---|
  | 20 | 59 | 0.4% | ~10.6 ms | real time |
  | 25 | 57 | 11% | ~15.4 ms | real time |
  | 30 | 43 | 96% | ~22 ms | 98% |
  | 35 | 35 | all | ~26 ms | 82% |
  | 40 | 32 | all | ~27 ms | 54% |

  So ~20 Mipos a room is the comfortable design limit, 25 the ceiling
  ([WORLD-METRICS.md](WORLD-METRICS.md) has the rules for scenes). The next step up is resting
  Mipos that sleep (Box2D skips sleeping bodies; the balance keeps them all awake now).
  Lessons: a phone warms up and throttles (everything ~25% slower, parts nothing touched too):
  compare by switching live in one session, or let it cool. Say before pausing or switching
  things on a phone someone is holding. `device.sh` picks an iPhone before an iPad
  (`DEVICE=iPad` for the iPad). iOS has no JIT: count calls into C (each costs), not
  arithmetic.
- [x] **M11. The Mipo update, what's left.** **Done 2026-10-31.** The untangle: checking only
  Mipos that touch another Mipo would have been safe (0 of 37296 hooks in 90 s of a 35-Mipo
  pile were on one that didn't) but useless (13 of 22041 checks skipped: in a crowd everyone
  touches someone). Instead each Mipo is looked over every 36 steps, not 12 (`hookCheckSteps`,
  ~0.43 s; an untangle waits 2 s anyway): the joint guard 0.64 -> 0.45 ms. keep-angle: each
  body's thing remembered (it never changes for a body: a new thing comes with a new body, a
  flip keeps it; the behaviors are read live, spec/keep-angle_spec.lua) and passed along instead
  of asked three times a part: 0.40 -> 0.33 ms. The crowd's update ~4.0 ms on the phone.
  Seen on the way: that pile untangled 109 times in 90 s, more than once a second (the twitching
  in a crowd?). Bigger, with Box2D, if ever needed: resting Mipos asleep.
- [ ] **M6. The potato-torso click.** The editor snapshot forces every slider to its midpoint; on a
  potato head's torso1 panel that makes a shape Box2D refuses (`fixtures.lua:132: Box2D assertion
  failed`), and the next click finds the Mipo half rebuilt. Same before and after the splits, so
  older. Find which slider, and keep its values to shapes Box2D takes.
