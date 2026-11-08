# Bark — tree trunks in real bark, lit

status: active

Nikki (2026-11-08): "can we try to nail down some tree barks, fetch some assets, do the setup and
show a variety of trees or just their main stem". Scene `bark` (`scripts/spikes/bark.playtime.lua`),
a spike: two rows of 15 main stems, each its own shape and bark, under a light at the mouse.

## The barks

15 scans from ambientCG (CC0: free for anything, no credit needed; ambientcg.com, Bark001-016,
Bark005 left out: a cut-off strip). Each in `textures/world/bark/` as `bark-NN.jpg` (colour, 512 px
wide), `bark-NN-normal.jpg` (the normal map, OpenGL way up) and `bark-NN-height.jpg` (256 px,
grey: lighter is higher). The 1K downloads scaled down; 4.3 MB for all 15. Names by what they look
like: 01 oak (deep furrows), 02 elm, 03 smooth brown, 04 pine (plates), 06 lichen, 07 cracked,
08 olive, 09 plane (patches), 10 beech, 11 grey, 12 cork, 13 mossy, 14 red, 15 striped, 16 old mossy.

## How it's made

- **A stem** is a strip along a bent middle line: tapering, roots flaring at the foot, a lean and
  an S-bend per tree, some with a branch stub. Drawn branch first, stem over it.
- **Round**: the shader turns the place across the strip into the angle round the stem, so the bark
  squeezes toward the edges as it turns away, and the stem's normal leans out there. The bark's
  normal map tilts that normal; the light at the mouse lights it (a point a little in front, `light
  out`). The height map darkens the cracks.
- **Outline**: Nikki's crayon strokes (`drawn-stroke.lua`), both edges and the cut at the top.
- **Three looks** (v): *photo* the bark as photographed; *tinted* its light and dark in one colour
  per tree (the photo's grain, the drawn world's colours); *relief* a flat colour, only the bumps and
  cracks taking the light. Painted (p): the light in four steps. Detail (d) and the bark's size (s).

## Steps

- [x] **BK1. The spike** (2026-11-08): the 15 barks, the stems, the three looks, the panel.
- [ ] **BK2. Nikki judges**: which look (photo / tinted / relief) sits with the drawn Mipos, which
  barks to keep. A Mipo next to a trunk for the scale (WORLD-METRICS.md).
- [ ] **BK3. Into the engine, if kept**: a bark as a material on a ribbon (connected-texture) or a
  texfixture, through the plasticine shader (MATERIALS.md), the scene's lights instead of the mouse.
- Later, if it earns it: the crown (leaf blobs, PLANTS.md), branches that fork, bark drawn by Nikki
  as a height sheet (MATERIALS MT11) next to the scans.
