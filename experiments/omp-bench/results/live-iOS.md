# OMP bench: baked against live

Run: 2026-11-11 23:02 on iOS (OpenGL ES OpenGL ES 3.0 Metal - 101, Apple Inc. Apple A13 GPU), window 667x375 at dpi scale 2, msaa 4, vsync 0.
Scene: scripts/tests/crowd.playtime.json, 20 Mipos, 479 OMP parts (ribbons drawn as quads). JIT off.
Shared source pictures: 49.9 MB as the game loads them; 64.3 MB more for live's mipmapped copies.

MB per Mipo: texture memory the 20 Mipos added, over 20. appear: making one Mipo's pictures (baked) or
working out its uniforms (live). litter: 5 Mipos in one frame. draw ms: love.draw's CPU time
for the 20 (median of 600 frames, sends included); frame ms: the time between frames.
Mipos in 60 fps: Mipos added 10 at a time until the median frame is over 17.5 ms.
diff: live against baked (each with its own patches or not), mean per channel 0-255; % px: off by more than 8/255.
| option | MB per Mipo | appear ms/Mipo | litter of 5 ms | draw ms | draw p95 | frame ms | frame p95 | draw calls | Mipos in 60 fps | diff game | % px game | diff close | % px close |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baked | 1.32 | 41.01 | 238.2 | 3.94 | 4.75 | 16.67 | 17.15 | 479 | 260 |  |  |  |  |
| baked+patches | 1.32 | 43.30 | 267.7 | 5.28 | 6.02 | 16.67 | 17.10 | 479 | 230 |  |  |  |  |
| live | 0.00 | 0.15 | 1.1 | 6.00 | 7.11 | 16.66 | 17.40 | 479 | 90 | 0.56 | 2.6 | 2.22 | 11.0 |
| live+patches | 0.00 | 0.19 | 1.3 | 5.12 | 7.97 | 16.63 | 17.48 | 479 | 80 | 0.57 | 2.6 | 2.26 | 10.6 |
