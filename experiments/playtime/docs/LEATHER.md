# Leather — parts that look like stitched leather

status: idea

Nikki (2026-11-11): "and then some more shader fun, with a more leathered look?". Leather is in the
material palette already (MATERIALS MT4, 2026-11-06: a surface grain with a sheen, one of the stronger
ones read from screenshots). What says leather most is at the edges, and the per-part hook
(`state.drawableWrap`, CUT-PAPER.md; fur and cut paper use it) gives a part its own edges.

## The idea, per part

- **Stitching**: a dashed seam a few px inside the outline, all the way round (from the mask: the distance
  in from its edge, as the cut-paper fringe measures it), the stitches small dark-and-light dashes with a
  hole each end. The strongest "made of leather" signal.
- **Burnished edges**: the cut edge darker and a little glossy, as a worn wallet's.
- **Creases**: soft folds where a part bends (near its joints), darker in the dip with a light ridge.
- **Scuffs**: worn, lighter patches here and there, more at the ends.
- **Grain and sheen**: fine pores and a soft highlight (the palette's leather grain, reused).
- Tooled or embossed lines (a pattern pressed in) as a later extra.

## With the rest

- Shoes (SHOES.md): a leather upper with stitching is what makes a shoe read as one.
- Drawn live (OMP-LIVE.md), the stitching follows the mask exactly at any zoom; on today's bake it works
  on the baked picture's alpha, like the fur and cut paper.
- Felt with a fuzzy edge, felt appliqué and cardboard with torn edges (MATERIALS' table) are the same kind
  of per-part edge effect, next in line if this works.

## Steps

- [ ] **LE1. The spike** (scene `leather`, on the hook): stitching, burnished edges, creases, scuffs, sheen
  on two Mipos, sliders for each; baked like the fur if it costs.
- [ ] **LE2. Nikki plays with it**: keep, change or park.
- [ ] **LE3. If kept**: leather as a material on a part (the palette, MT6's editor row), and on shoes.
