# OMP bench

Measures what Playtime's baked part textures (outline + mask + pattern, "OMP") cost, per option:
texture memory (total, per extra Mipo), bake time, frame time, draw calls, how it looks
(screenshots + pixel diff against today), and memory while randomizing a Mipo.

It runs Playtime's own bake code (`makeTexturedCanvas` in `src/physics/box2d-draw-textured.lua`)
on the real Mipo parts from `scripts/dollhouse.playtime.json`. `src`, `vendor`, `textures` and
`scripts` are symlinks into `../playtime`, so it always measures the current code.

```bash
cd experiments/omp-bench
/Applications/love115.app/Contents/MacOS/love . --auto   # all options, writes results/, quits (~15 s)
/Applications/love115.app/Contents/MacOS/love .          # look for yourself: 1-4 option, z zoom
```

Results: `results/results.md` (table + run notes), `results/results.csv`,
`results/looks-<option>-<game|close>.png`.

Options so far (follow-up of `../playtime/docs/EXPERIMENTS-HARVEST.md` §8):
1. `baseline`: what Playtime does today.
2. `shrink-1.5`, `shrink-2`: bake smaller (`shrinkFactor`, already in the code, set to 1).
3. `release`: `:release()` the old image when a part is re-baked, instead of waiting for the GC.

Planned: r8 sources, shader compositing (no bake), patches as markings.

Limits: measured on this Mac; the iPad is the real target for anything GPU-heavy. Ribbon parts
(connected-texture) are drawn as plain quads at their source size, so the frame test is a load
test, not a real Mipo pose.
