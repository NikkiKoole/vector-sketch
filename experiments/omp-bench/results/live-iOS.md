# OMP bench: baked against live

Run: 2026-11-11 23:24 on iOS (OpenGL ES OpenGL ES 3.0 Metal - 101, Apple Inc. Apple A13 GPU), window 667x375 at dpi scale 2, msaa 4, vsync 0.
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
| baked | 1.32 | 25.19 | 150.9 | 5.08 | 6.13 | 16.66 | 17.42 | 479 | 280 |  |  |  |  |
| baked+patches | 1.32 | 46.11 | 271.6 | 5.58 | 5.91 | 16.67 | 16.91 | 479 | 270 |  |  |  |  |
| live | 0.00 | 0.14 | 1.2 | 6.16 | 7.49 | 16.62 | 17.37 | 479 | 100 | 0.56 | 2.6 | 2.22 | 11.0 |
| live+patches | 0.00 | 0.17 | 1.6 | 5.23 | 8.05 | 16.63 | 17.41 | 479 | 90 | 0.57 | 2.6 | 2.26 | 10.6 |
| packed | 0.00 | 0.19 | 1.6 | 5.93 | 6.56 | 16.67 | 17.04 | 479 | 100 | 0.56 | 2.6 | 2.22 | 11.0 |
| packed+patches | 0.00 | 0.20 | 1.4 | 5.97 | 6.86 | 16.67 | 17.16 | 479 | 90 | 0.57 | 2.6 | 2.26 | 10.6 |
| mesh | 0.00 | 1.57 | 11.6 | 5.87 | 6.66 | 16.67 | 17.06 | 479 | 100 | 0.56 | 2.6 | 2.22 | 11.0 |
| mesh+rg | 0.00 | 1.45 | 11.4 | 5.99 | 6.47 | 16.67 | 17.01 | 479 | 160 | 0.56 | 2.6 | 2.22 | 11.0 |

