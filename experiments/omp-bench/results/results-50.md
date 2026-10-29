# OMP bench results

Run: 2026-10-29 12:58 on OpenGL 4.1 ATI-5.5.17 (ATI Technologies Inc., AMD Radeon Pro 575X OpenGL Engine).
Scene: scripts/dollhouse.playtime.json, 5 Mipos, 118 OMP parts. Extra Mipos are recoloured copies. Ribbon parts (connected-texture) are drawn as quads at their source size.
Source images (outline/mask/pattern, shared, not in the MB columns): 31.3 MB.
Oversampling at full size (texture px per screen px): median 4.5 (p10 2.5, p90 6.4) at the dollhouse zoom 0.35; median 1.6 at zoom 1.0.

Frame test: 50 Mipos scattered at the dollhouse zoom, vsync off, 600 frames.
diff = mean difference per channel (0-255) against baseline; % px changed = pixels off by more than 8/255.
Randomize: Mipo 1 re-baked 25 times next to the others; +MB over the start.

| option | MB@5 | MB@12 | MB@25 | MB@50 | MB per Mipo | bake ms/Mipo | frame ms median | frame ms p95 | draw calls | diff game | % px changed game | diff close | % px changed close | randomize peak +MB | randomize end +MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline | 22.5 | 54.1 | 112.3 | 224.5 | 4.49 | 29.8 | 5.76 | 8.04 | 1180 |  |  |  |  | 6.9 | 5.0 |
| shrink-1.5 | 9.9 | 23.9 | 49.6 | 99.2 | 1.98 | 21.6 | 5.60 | 7.43 | 1180 | 0.48 | 2.0 | 1.95 | 6.9 | 3.2 | 2.2 |
| shrink-2 | 5.6 | 13.4 | 27.9 | 55.8 | 1.12 | 18.4 | 5.70 | 7.56 | 1180 | 0.50 | 2.1 | 2.05 | 7.7 | 2.0 | 1.2 |
| release | 22.5 | 54.1 | 112.3 | 224.5 | 4.49 | 26.5 | 5.80 | 9.93 | 1180 | 0.00 | 0.0 | 0.00 | 0.0 | 0.6 | 0.0 |
