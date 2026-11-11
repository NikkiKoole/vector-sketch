# Drawing parts live instead of baking (OMP without the bake)

status: idea

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

- [ ] **OL1. The bench first**: 20 Mipos on the iPhone SE 2, baked against live (a shader compositing
  outline + mask + pattern + patches per part): frame time, draw ms, memory, and the hitch of a litter
  appearing. omp-bench or a playtime scene; the phone on the cable (`./playtime.sh bench device`).
- [ ] **OL2. Decide**, with Nikki: if live wins or ties, the plan to switch (the Mipo editor's thumbnails,
  saves, the materials and lights that read the baked picture today, the spine skin and ribbons).
- [ ] **OL3. r8 masks** for the sources (a quarter of their memory), either way.
