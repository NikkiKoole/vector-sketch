# OMP bench: baked against live

Run: 2026-11-11 23:19 on OS X (OpenGL 4.1 Metal - 90.5, Apple Apple M1), window 1000x800 at dpi scale 1, msaa 4, vsync 0.
Scene: scripts/tests/crowd.playtime.json, 20 Mipos, 479 OMP parts (ribbons drawn as quads). JIT off.
Shared source pictures: 49.9 MB as the game loads them; 64.3 MB more for live's mipmapped copies;
mesh+rg's outline+mask pictures (rg8, mipmapped) 14.6 MB, in place of the outlines and masks.

MB per Mipo: texture memory the 20 Mipos added, over 20. appear: making one Mipo's pictures (baked) or
working out its uniforms (live). litter: 5 Mipos in one frame. draw ms: love.draw's CPU time
for the 20 (median of 600 frames, sends included); frame ms: the time between frames.
Mipos in 60 fps: Mipos added 10 at a time until the median frame is over 17.5 ms.
diff: live against baked (each with its own patches or not), mean per channel 0-255; % px: off by more than 8/255.
| option | MB per Mipo | appear ms/Mipo | litter of 5 ms | draw ms | draw p95 | frame ms | frame p95 | draw calls | Mipos in 60 fps | diff game | % px game | diff close | % px close |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baked | 1.32 | 18.34 | 91.8 | 1.03 | 1.52 | 2.84 | 4.97 | 479 | >300 |  |  |  |  |
| baked+patches | 1.32 | 19.35 | 100.0 | 1.01 | 1.54 | 2.90 | 5.09 | 479 | >300 |  |  |  |  |
| live | 0.00 | 0.06 | 0.2 | 2.03 | 2.68 | 3.97 | 5.69 | 479 | 160 | 0.55 | 2.6 | 2.23 | 11.1 |
| live+patches | 0.00 | 0.06 | 0.2 | 2.70 | 3.45 | 5.00 | 7.21 | 479 | 110 | 0.56 | 2.6 | 2.26 | 10.6 |
| packed | 0.00 | 0.06 | 0.5 | 1.77 | 2.32 | 3.74 | 6.12 | 479 | 190 | 0.55 | 2.6 | 2.23 | 11.1 |
| packed+patches | 0.00 | 0.07 | 0.4 | 2.36 | 3.05 | 4.43 | 6.95 | 479 | 130 | 0.56 | 2.6 | 2.26 | 10.6 |
| mesh | 0.00 | 1.02 | 7.7 | 1.71 | 2.34 | 3.87 | 6.12 | 479 | 190 | 0.55 | 2.6 | 2.23 | 11.1 |
| mesh+rg | 0.00 | 0.90 | 5.5 | 1.46 | 1.98 | 3.46 | 5.56 | 479 | 190 | 0.55 | 2.6 | 2.23 | 11.1 |
