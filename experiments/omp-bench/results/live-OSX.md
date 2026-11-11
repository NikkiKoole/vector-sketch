# OMP bench: baked against live

Run: 2026-11-11 22:56 on OS X (OpenGL 4.1 Metal - 90.5, Apple Apple M1), window 1000x800 at dpi scale 1, msaa 4, vsync 0.
Scene: scripts/tests/crowd.playtime.json, 20 Mipos, 479 OMP parts (ribbons drawn as quads). JIT off.
Shared source pictures: 49.9 MB as the game loads them; 64.3 MB more for live's mipmapped copies.

MB per Mipo: texture memory the 20 Mipos added, over 20. appear: making one Mipo's pictures (baked) or
working out its uniforms (live). litter: 5 Mipos in one frame. draw ms: love.draw's CPU time
for the 20 (median of 600 frames, sends included); frame ms: the time between frames.
Mipos in 60 fps: Mipos added 10 at a time until the median frame is over 17.5 ms.
diff: live against baked (each with its own patches or not), mean per channel 0-255; % px: off by more than 8/255.
| option | MB per Mipo | appear ms/Mipo | litter of 5 ms | draw ms | draw p95 | frame ms | frame p95 | draw calls | Mipos in 60 fps | diff game | % px game | diff close | % px close |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baked | 1.32 | 20.58 | 87.2 | 1.02 | 1.47 | 2.93 | 5.41 | 479 | >300 |  |  |  |  |
| baked+patches | 1.32 | 23.74 | 107.2 | 1.09 | 1.61 | 3.04 | 5.43 | 479 | >300 |  |  |  |  |
| live | 0.00 | 0.07 | 0.2 | 2.19 | 2.83 | 4.13 | 6.21 | 479 | 150 | 0.55 | 2.6 | 2.23 | 11.1 |
| live+patches | 0.00 | 0.07 | 0.2 | 2.78 | 3.43 | 4.92 | 7.32 | 479 | 110 | 0.56 | 2.6 | 2.26 | 10.6 |
