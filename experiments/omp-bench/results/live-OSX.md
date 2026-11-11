# OMP bench: baked against live

Run: 2026-11-11 23:40 on OS X (OpenGL 4.1 Metal - 90.5, Apple Apple M1), window 1000x800 at dpi scale 1, msaa 4, vsync 0.
Scene: scripts/tests/crowd.playtime.json, 20 Mipos, 479 OMP parts (ribbons drawn as quads). JIT off.
Shared source pictures: 49.9 MB as the game loads them; 64.3 MB more for live's mipmapped copies;
mesh+rg's outline+mask pictures (rg8, mipmapped) 14.6 MB, in place of the outlines and masks.

MB per Mipo: texture memory the 20 Mipos added, over 20. appear: making one Mipo's pictures (baked) or
working out its uniforms (live). litter: 5 Mipos in one frame. draw ms: love.draw's CPU time
for the 20 (median of 600 frames, sends included); frame ms: the time between frames.
Mipos in 60 fps: Mipos added 10 at a time until the median frame is over 17.5 ms.
diff: against baked (each with its own patches or not), mean per channel 0-255; % px: off by more than 8/255.
| option | MB per Mipo | appear ms/Mipo | litter of 5 ms | draw ms | draw p95 | frame ms | frame p95 | draw calls | Mipos in 60 fps | diff game | % px game | diff close | % px close |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baked | 1.32 | 18.54 | 85.9 | 1.00 | 1.57 | 2.90 | 4.85 | 479 | >300 |  |  |  |  |
| baked+patches | 1.32 | 19.48 | 91.3 | 1.03 | 1.65 | 2.89 | 4.96 | 479 | >300 |  |  |  |  |
| live | 0.00 | 0.06 | 0.1 | 2.06 | 3.01 | 3.93 | 5.83 | 479 | 150 | 0.55 | 2.6 | 2.23 | 11.1 |
| live+patches | 0.00 | 0.08 | 0.2 | 2.72 | 3.73 | 5.06 | 7.14 | 479 | 110 | 0.56 | 2.6 | 2.26 | 10.6 |
| packed | 0.00 | 0.06 | 0.2 | 1.75 | 2.73 | 3.70 | 5.83 | 479 | 180 | 0.55 | 2.6 | 2.23 | 11.1 |
| packed+patches | 0.00 | 0.07 | 0.2 | 2.34 | 3.23 | 4.34 | 6.60 | 479 | 130 | 0.56 | 2.6 | 2.26 | 10.6 |
| mesh | 0.00 | 1.08 | 6.0 | 1.70 | 2.52 | 3.77 | 5.93 | 479 | 180 | 0.55 | 2.6 | 2.23 | 11.1 |
| mesh+rg | 0.00 | 1.02 | 5.7 | 1.44 | 2.11 | 3.37 | 5.73 | 479 | 220 | 0.55 | 2.6 | 2.23 | 11.1 |
| mesh+rg-skip | 0.00 | 1.03 | 5.2 | 1.44 | 2.13 | 3.28 | 5.55 | 479 | 220 | 0.55 | 2.6 | 2.23 | 11.1 |
| baked-canvas | 1.32 | 4.44 | 23.4 | 1.05 | 1.67 | 3.03 | 5.61 | 479 | 290 | 0.00 | 0.0 | 0.00 | 0.0 |
| baked-canvas+p | 1.32 | 4.53 | 22.9 | 1.17 | 1.84 | 3.23 | 5.87 | 479 | 270 | 0.00 | 0.0 | 0.00 | 0.0 |
