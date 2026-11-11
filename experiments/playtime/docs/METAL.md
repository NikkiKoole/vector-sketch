# Metal — Mipo parts made of metal

status: active

Nikki (2026-11-12): "do the metal one", the second from the shortlist of earlier materials to look at on their
own (after felt). The palette's metals (MATERIALS MT1/MT1b: brass, gold, copper, tin, iron) were the strongest
read from screenshots, inside the shape; the per-part hook (`state.drawableWrap`, CUT-PAPER.md) adds the edge.

## The spike (2026-11-12, scene `metal`)

`scripts/spikes/metal.playtime.lua`, each Mipo part (not the face) through a metal shader that finds its own
edge (rings of samples: how far, which way), like stone:
- **Shape**: rounded toward the edge and top to bottom ('rounded'), reflecting a **studio** round it: bright
  sky above, a horizon band, a warm floor, a window to one side; seen a little from above so a face-on
  surface catches sky (straight on it reflected the horizon: dull brown middles). A sharp highlight from the
  top left ('shine').
- **Finish**: hammered (smooth hollows: the slope of a soft bumpy field; faceted cells caught a band each and
  made a woven grid), brushed (fine streaks) or smooth ('dents / streaks').
- **Rivets**: little domes in a row a few px inside the outline ('rivets', 'rivets in', 'rivet gap'), counted
  along the edge as leather's stitches.
- **Seams**: the drawing's dark lines as grooves ('seams').
- **Patina / rust** in the lower dips near the edge: verdigris on brass and copper, rust on iron.
- **Painted (tin toy)**: the Mipo's own colours printed on the metal, worn off at the edges and dents.
- Metals: brass, copper, tin, iron, chrome.

First look (brass, smooth): polished brass Mipos, bright on top, the horizon band across belly and legs, gold
rims, the face as drawn; the rivets faint at this zoom. One draw a part, ~65 samples a pixel, phone not measured.

## Steps

- [x] **ME1. The spike**: the studio reflection, finishes, rivets, seams, patina, tin-toy paint, five metals.
- [ ] **ME2. Nikki plays with it**: keep, change or park.
- [ ] **ME3. If kept**: metal as a material on a part (a brass leg, a tin hat: MT6's editor row, the palette's
  presets), the studio from the scene's own light and sky (SKY.md), baked like the fur if it costs.
