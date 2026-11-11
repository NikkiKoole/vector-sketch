# OMP bench

Baked part pictures against drawing them live (`../playtime/docs/OMP-LIVE.md` OL1).

**Baked** is what Playtime does today: each part's outline + mask + pattern (+ patches) flattened once
into its own picture by Playtime's own code (`makeTexturedCanvas` in `src/render/omp-bake.lua`, half
size). **Live** draws the shared source pictures (mipmapped) and mixes the same layers in a shader per
draw: nothing per Mipo in memory, nothing to bake, a few uniforms sent per part. `+patches` gives each
torso the DNA's two default skin patches.

The parts are the 20 Mipos of `scripts/tests/crowd.playtime.json`. `src`, `vendor`, `textures` and
`scripts` are symlinks into `../playtime`, so it always measures the current code.

```bash
cd experiments/omp-bench
/Applications/love115.app/Contents/MacOS/love . --auto   # every option, writes results/, quits (~80 s)
/Applications/love115.app/Contents/MacOS/love .          # look for yourself: 1-7 option, z zoom
# on the phone (replaces Playtime there until the next plain ./playtime.sh device); runs by itself,
# the table stays on screen and goes to omp-live-results.md in the save folder:
cd ../playtime && LOVE_DIR=../omp-bench native/ios/device.sh
```

Results: `results/live-<OS>.md`, `results/looks-<option>-<game|close>.png`.

Measures per option: texture memory per Mipo, the time a Mipo takes to appear (and a litter of 5 in
one frame), love.draw's CPU time and the frame time with the 20 on screen, how many Mipos fit in a
60 fps frame, and a pixel diff of live against baked.

Limits: parts are drawn as quads scattered at the dollhouse's zoom (ribbons too), a load test, not
a pose. The live shader sends its uniforms one by one per part (9 sends, 17 with patches): the
simplest way, not the cheapest.

The first run (2026-10-29: baseline, shrink-1.5, shrink-2, release; `results/results.md`) is in git
history; shrink 2 and release went into Playtime.
