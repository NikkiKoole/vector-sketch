# OMP bench: baked against live

Run: 2026-11-11 23:46 on iOS (OpenGL ES OpenGL ES 3.0 Metal - 101, Apple Inc. Apple A13 GPU), window 667x375 at dpi scale 2, msaa 4, vsync 0.
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
| baked | 1.32 | 39.39 | 150.1 | 5.31 | 6.11 | 16.66 | 17.18 | 479 | 280 |  |  |  |  |
| baked+patches | 1.32 | 49.66 | 274.0 | 5.62 | 5.92 | 16.67 | 16.92 | 479 | 270 |  |  |  |  |
| live | 0.00 | 0.16 | 1.1 | 6.14 | 7.44 | 16.64 | 17.30 | 479 | 90 | 0.56 | 2.6 | 2.22 | 11.0 |
| live+patches | 0.00 | 0.18 | 1.6 | 5.17 | 7.99 | 16.61 | 17.39 | 479 | 90 | 0.57 | 2.6 | 2.26 | 10.6 |
| packed | 0.00 | 0.19 | 1.5 | 5.89 | 6.66 | 16.67 | 17.04 | 479 | 100 | 0.56 | 2.6 | 2.22 | 11.0 |
| packed+patches | 0.00 | 0.19 | 1.4 | 5.91 | 6.82 | 16.66 | 17.15 | 479 | 90 | 0.57 | 2.6 | 2.26 | 10.6 |
| mesh | 0.00 | 1.41 | 10.2 | 5.87 | 6.39 | 16.67 | 17.11 | 479 | 100 | 0.56 | 2.6 | 2.22 | 11.0 |
| mesh+rg | 0.00 | 1.47 | 11.5 | 5.89 | 6.27 | 16.67 | 17.01 | 479 | 170 | 0.56 | 2.6 | 2.22 | 11.0 |
| mesh+rg-skip | 0.00 | 1.45 | 10.4 | 5.89 | 6.25 | 16.67 | 17.01 | 479 | 160 | 0.56 | 2.6 | 2.22 | 11.0 |
| baked-canvas | 1.32 | 5.48 | 26.6 | 5.50 | 5.89 | 16.67 | 16.91 | 479 | 270 | 0.00 | 0.0 | 0.00 | 0.0 |
| baked-canvas+p | 1.32 | 5.63 | 33.7 | 5.54 | 5.92 | 16.67 | 16.94 | 479 | 210 | 0.00 | 0.0 | 0.00 | 0.0 |
