# Drawing parts live instead of baking (OMP without the bake)

status: active

Nikki (2026-11-11): "it looks like we might go in a direction where the omp stuff with patches will not be
the greatest route, i believe not doing that also would help us in some optimization iirc, can you check".

## How it is now

Each part of each Mipo gets one picture baked when the Mipo is made, randomized or loaded
(`src/render/omp-bake.lua` `makeCombinedImages`): outline, mask fill, pattern and up to 5 patch layers
(patch1..5) flattened into it on a canvas, read back from the GPU (`newImageData`) and made an image.
Face patches are drawn live already (`src/face-patches.lua`, a decal clipped to the skin): baked ones slid
off a turning face (MIPO-BREEDS B10, tried 2026-11-08); the 5 baked slots stay for torso patches.

## What the bake costs (measured before)

- **Memory**: ~1.1 MB a Mipo, baked at half size (EXPERIMENTS-HARVEST, omp-bench 2026-10-29: 4.5 -> 1.1 MB;
  50 Mipos 56 MB), unique per Mipo, on top of 31 MB of shared source drawings.
- **A hitch when Mipos appear or change**: 17 ms a Mipo on the Mac (28 at full size), the canvas read back
  from the GPU; the phone not measured. A litter, a randomize, and every save (it drops every baked
  picture: EXPERIMENTS-HARVEST, "the full rebake after every save") pay it.
- **Softness**: half size: close up the grain is softer.
- **The rebake check** every frame: ~1.1 ms at 100 Mipos (MIPO-DRAWING; small at 20).

## Without the bake

Each part drawn straight from the shared outline, mask and pattern pictures, its colours, pattern
transform and patches mixed in a shader as it draws.
- **Gains**: the per-Mipo memory, the hitch and the rebake check gone; sharp at any zoom; a colour change
  (a blush, dirty, wet, a feeling's tint) a uniform instead of a re-bake.
- **It fits where the looks are going**: materials, leather stitching (LEATHER.md), fur (FUR-SHELLS.md),
  cut paper (CUT-PAPER.md) and shoes (SHOES.md) all want the outline and the mask apart, not a flat
  picture.
- **Costs**: every pixel reads three pictures instead of one, every frame; each part sends its colours
  and pattern transform to the shader (a send a part). On the iPhone SE a draw is ~1.9 us and a texture
  switch costs nothing (MIPO-DRAWING L2a), so it's likely cheap; not measured.
- **Patches** become extra layers in the shader or separate draws ("patches as markings", omp-bench's
  own plan).
- Unproven: omp-bench lists "shader compositing (no bake)" as planned and never ran it, next to r8
  (single-channel) masks for the 31 MB of sources.

## Steps

- [x] **OL1. The bench first**: 20 Mipos on the iPhone SE 2, baked against live (a shader compositing
  outline + mask + pattern + patches per part): frame time, draw ms, memory, and the hitch of a litter
  appearing. Done 2026-11-11 in `experiments/omp-bench` (reworked: baked / live, each with and without
  two torso patches; the crowd scene's 20 Mipos, 479 parts, drawn as quads; on the phone with
  `LOVE_DIR=../omp-bench native/ios/device.sh`). Results `omp-bench/results/live-iOS.md`, `live-OSX.md`.

  | iPhone SE 2 | MB a Mipo | a Mipo appears | litter of 5 | draw ms (CPU, 20 Mipos) | frame | Mipos in 60 fps |
  |---|---|---|---|---|---|---|
  | baked | 1.32 | 41 ms | 238 ms | 3.9 (5.3 with patches) | 16.7 | 260 (230) |
  | live | 0 | 0.15 ms | 1 ms | 6.0 (5.1 with patches) | 16.7 | 90 (80) |

  - **The hitch is the big one**: on the phone a Mipo's bake is 41 ms, 2-3 lost frames each; a litter of
    5 in one frame is a quarter of a second. Live: 1 ms.
  - **Memory**: 1.3 MB a Mipo gone (26 MB for 20). But live wants mipmaps on the sources (without them the
    grain shimmers at the game's zoom): 50 -> 64 MB shared. Break-even at ~11 Mipos; OL3's r8 masks matter more then.
  - **Per frame live costs ~1-2 ms more CPU** at 20 Mipos (runs vary by ~1 ms: patches made baked
    slower and live faster, which is noise), from 9 `shader:send`s a part one by one, the simplest way. Both hold 60 fps at 20;
    live's limit is 80-90 Mipos against 230-260, still 4x the room's design limit (25). Cheaper sends
    (one array send, or the colours as vertex attributes) not tried.
  - **Looks**: the same picture (diff 0.6/255 at the game zoom), sharper close up (11% of pixels differ
    there, the bake's half size); patches land where the bake puts them.
  - Mac M1 for comparison: bake 21 ms a Mipo, live +1.2 ms draw, 150 Mipos in 60 fps against >300.
  - **Cheaper sends, tried 2026-11-11** (Nikki: "try the cheaper sends first, then rerun on the phone"):
    *packed* (one array send a part, pictures sent only when they change), *mesh* (the numbers as vertex
    attributes, only pictures sent) and *mesh+rg* (as mesh, outline alpha and mask in one shared rg8
    picture per shape, 14.6 MB for all of them mipmapped, against 64 MB of mipmapped outlines and masks;
    only the pattern sent). Pixels the same as the naive shader. On the phone:

    | iPhone SE 2 | draw ms (20 Mipos) | Mipos in 60 fps |
    |---|---|---|
    | baked | 5.1 | 280 |
    | live (9 sends) | 6.2 | 100 |
    | packed | 5.9 | 100 |
    | mesh | 5.9 | 100 |
    | mesh+rg | 6.0 | 160 |

    On the phone the sends weren't the cost: the CPU time hardly moves (5-6 ms for all, most of it
    waiting on the GPU, not our Lua: 479 draws are ~1 ms at 1.9 us), and only reading fewer pictures
    raised the ceiling (100 -> 160). Live's limit there is the GPU reading 3 pictures a pixel where baked
    reads 1. 160 is still 6x the room's 25. On the Mac the sends did count: draw 2.0 -> 1.5 ms (baked 1.0).
    So if live: mesh+rg, the two-channel outline+mask made once per shape (offline, as a build step).
  - **Leaving things out, tried 2026-11-11** (Nikki: "could we get the cost down by simplifying something,
    leaving something out we do now that is most costly?"). Two cuts, on the phone:
    - *baked-canvas*: the bake keeps its small canvas instead of reading it back from the GPU
      (`canvas:newImageData`) and making an image of it again. A Mipo appears in **5.5 ms instead of
      39** (a litter of 5: 27 ms instead of 150), pixels identical (diff 0), the frame the same. The
      read-back was most of the hitch. Small to do in Playtime: makeTexturedCanvas's three callers are
      all in omp-bake.lua (makePatch, makeCombinedImages, bakePreview); nothing reads the picture's pixels.
      **In Playtime since 2026-11-12**: `ompBake.bakeCanvas` (those three use it); `makeTexturedCanvas`
      still returns ImageData for the spike scripts that make their own Image (bike, garden, soapbox,
      scan-test). Checked: the scenes snapshot pixel-identical (81 scenes; facing, light-grass-check and
      mipo-materials differ run to run without the change), specs as before (face-patches @ 99 fails
      without the change too).
    - *mesh+rg-skip*: live parts that show no pattern (216 of 479) skip the pattern read: no gain
      (160 against 170 Mipos, noise). The pattern read isn't what costs.
    With the read-back gone, baked keeps its frame speed (270-280 Mipos) and its hitch is close to
    live's: what's left for live is memory (1.3 MB a Mipo) and sharpness, and the looks that want
    the layers apart.
- [x] **OL2. Decide**, with Nikki: if live wins or ties, the plan to switch (the Mipo editor's thumbnails,
  saves, the materials and lights that read the baked picture today, the spine skin and ribbons).
  The trade-off in short (from OL1, iPhone SE 2): baked is the fastest per frame (60 fps up to ~280
  Mipos, live mesh+rg ~160) and costs ~1.3 MB a Mipo on top of 50 MB of shared sources (~76 MB with
  20), plus a 25-46 ms hitch each time a Mipo appears or changes (a litter of 5: 150-270 ms). Live
  mesh+rg: no hitch (~1 ms), 14.6 MB of rg8 outline+mask pictures plus the patterns (not measured
  apart, a small part), sharper close up. Both hold 60 fps at the room's 20-25 Mipos.
  **Decided 2026-11-12** (Nikki: "y"): **keep baked**, now that the bake keeps its canvas (hitch 39 ->
  5.5 ms a Mipo): fastest per frame, 1.3 MB a Mipo is fine for a room of 20. **Live part by part, later**:
  when the first look that needs the layers apart (leather LEATHER.md, shoes SHOES.md, fur FUR-SHELLS.md,
  cut paper CUT-PAPER.md) goes into the engine, only those parts draw live (mesh+rg: numbers as vertex
  attributes, outline + mask in one rg8 picture per shape); the rest stays baked. Not worth doing:
  cheaper uniform sends or skipping the pattern read (no gain on the phone).
- [ ] **OL3. r8 masks** for the sources (a quarter of their memory): outline alpha + mask in one rg8
  picture per shape, which the bake can read too (50 MB of sources for the crowd). If live: mesh+rg's
  rg8 outline+mask per shape already is this (14.6 MB for the crowd's shapes, mipmapped).
