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
  `POST /profile/benchmark` (a snippet). The draw functions have names since 2026-10-30, so ProFi
  reports `drawMeshusert`, `drawTraceVertices`, ... instead of anonymous lines.
- `./playtime.sh audio`: synth dropouts and what was busy then.
- `claudetools/snapshot.sh`: before/after snapshots for refactors that shouldn't change anything:
  scenes (pixel hash of every scene in scripts/, knut/, tech/), mipos (6 seeded Mipos through
  create, randomize, parts, mutate, save and load), editor (every ui call of the Mipo editor, then
  every widget clicked once). `take before`, change, `take after`, `diff before after`.

## Steps

- [x] **M1. Named draw functions.** `drawers` / `mouth.drawers` list named functions. Done 2026-10-30.
- [x] **M2. Snapshots kept.** The SPLIT1-3 safety nets as `claudetools/snapshots/` + `snapshot.sh`.
  Done 2026-10-30.
- [ ] **M3. A standing benchmark.** The crowd scene (20 Mipos), N frames headless: ms per frame for
  update, physics and draw (by kind, from drawTimes), GC per frame, texture memory. A report to run
  before and after a change, not a pass/fail spec (timing depends on what else the machine runs).
- [ ] **M4. Memory over a long session.** The image and OMP caches are never cleared (DEEPER-ISSUES).
  The bake is one module now (`render/omp-bake.lua`): count what's cached, watch it over 10 minutes
  of randomizing (M3 can run that), then cap or clear it.
- [ ] **M5. Micro-benchmarks for the pure parts.** busted benches for skinning, the polygon modules
  and song planning: they run anywhere, the web build too.
- [ ] **M6. The potato-torso click.** The editor snapshot forces every slider to its midpoint; on a
  potato head's torso1 panel that makes a shape Box2D refuses (`fixtures.lua:132: Box2D assertion
  failed`), and the next click finds the Mipo half rebuilt. Same before and after the splits, so
  older. Find which slider, and keep its values to shapes Box2D takes.
