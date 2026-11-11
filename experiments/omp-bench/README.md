# OMP bench

Baked part pictures against drawing them live (`../playtime/docs/OMP-LIVE.md` OL1).

**Baked** is what Playtime does today: each part's outline + mask + pattern (+ patches) flattened once
into its own picture by Playtime's own code (`makeTexturedCanvas` in `src/render/omp-bake.lua`, half
size). **Live** draws the shared source pictures (mipmapped) and mixes the same layers in a shader per
draw: nothing per Mipo in memory, nothing to bake. `+patches` gives each torso the DNA's two default
skin patches.

Options (`OPTIONS` in main.lua), the live ones differing in how a part's numbers reach the shader:
1. `baked`, 2. `baked+patches`: today.
3. `live`, 4. `live+patches`: one `shader:send` per uniform (9 a part, 17 with patches).
5. `packed`, 6. `packed+patches`: one array send a part; pictures sent only when they change.
7. `mesh`: each part its own mesh, the numbers as vertex attributes; only pictures sent.
8. `mesh+rg`: as mesh, with outline alpha + mask in one shared rg8 picture per shape (outlines are
   white, masks only use red), so a pixel reads two pictures instead of three. The fastest live one.
9. `mesh+rg-skip`: as 8, parts that show no pattern skip the pattern read (no gain).
10. `baked-canvas`, 11. `baked-canvas+p`: today's bake without the read-back from the GPU (the small
    canvas is kept and drawn): the same pixels, a Mipo appears ~7x faster.

The parts are the 20 Mipos of `scripts/tests/crowd.playtime.json`. `src`, `vendor`, `textures` and
`scripts` are symlinks into `../playtime`, so it always measures the current code.

```bash
cd experiments/omp-bench
/Applications/love115.app/Contents/MacOS/love . --auto   # every option, writes results/, quits (~2 min; ~6 min on the phone)
/Applications/love115.app/Contents/MacOS/love .          # look for yourself: 1-11 option, z zoom
# on the phone (replaces Playtime there until the next plain ./playtime.sh device); runs by itself,
# the table stays on screen and goes to omp-live-results.md in the save folder:
cd ../playtime && LOVE_DIR=../omp-bench native/ios/device.sh
```

Results: `results/live-<OS>.md`, `results/looks-<option>-<game|close>.png`.

Measures per option: texture memory per Mipo, the time a Mipo takes to appear (and a litter of 5 in
one frame), love.draw's CPU time and the frame time with the 20 on screen, how many Mipos fit in a
60 fps frame, and a pixel diff of live against baked.

Limits: parts are drawn as quads scattered at the dollhouse's zoom (ribbons too), a load test, not
a pose. On iOS 'draw ms' is mostly waiting on the GPU, not Lua; 'Mipos in 60 fps' is the number to
compare there. The pull of the results file: `xcrun devicectl device copy from --domain-type
appDataContainer --domain-identifier com.mipolai.playtime.dev --source "Library/Application
Support/omp-bench/omp-live-results.md"`.

The first run (2026-10-29: baseline, shrink-1.5, shrink-2, release; `results/results.md`) is in git
history; shrink 2 and release went into Playtime.
