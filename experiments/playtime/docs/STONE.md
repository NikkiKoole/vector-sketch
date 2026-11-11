# Stone — Mipo parts carved in stone

status: active

Nikki (2026-11-11): "sounds like we need some stone", then "Mipo as stone" (a per-part look like leather,
not stones as things). Tried before and weak: the material palette's stone (MATERIALS, a cell-pattern
grain: "weakest stone / wet stone"), the burrow's shader rocks ("the rocks need to be handdrawn",
BURROW.md). Both were noise; this one is a scan.

## The spike (2026-11-11, scene `stone`)

`scripts/spikes/stone.playtime.lua`, on the drawing hook (`state.drawableWrap`, CUT-PAPER.md), like leather:
each Mipo part (not the face) drawn once through a stone shader.
- **The stone**: four ambientCG scans (CC0: free for anything, no credit needed), colour + normal map at
  512 px in `textures/world/stone/`: stone-01 granite (Rock042S, grey-beige with a crack), stone-02
  sandstone (Rock004, pale), stone-03 limestone (Rock019, white, layered), stone-04 ochre (Rock054). Laid
  in the part's own space, so it moves with the part ('stone scale').
- **Carved**: the shader finds the nearest edge (rings of 8 samples, 2..16 px: how far, and which way) and
  tilts the surface out toward it within 'bevel' px ('carving depth'), lit from the top left like a chisel
  cut; the scan's normal map adds its own bumps ('bumps').
- **Chipped edge**: bits knocked off the outline ('chipped edge').
- **Lines cut in**: the drawing's own dark lines as grooves ('lines cut in').
- **Cracks** (thin dark lines) and **moss** in the lower dips near the edge ('cracks', 'moss').
- **tint**: 0 a grey statue, 1 the Mipo's own colours painted on the stone (by the stone's lightness, so it
  stays stone).

First look (granite, tint 0.35): leg and foot like a little statue, the bevel lit like a chisel cut, the edge
chipped, moss settling on the foot. One draw a part, ~65 samples a pixel (the edge rings), not baked,
phone not measured.

## Steps

- [x] **SN1. The spike**: the four scans, carving, chips, grooves, cracks, moss, tint.
- [ ] **SN2. Nikki plays with it**: keep, change or park.
- [ ] **SN3. If kept**: stone as a material on a part (the palette, MT6's editor row), the same carving for
  stone things (rocks, a statue on the shelf), baked like the fur if it costs.
