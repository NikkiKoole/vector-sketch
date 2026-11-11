# Felt — Mipo parts made of felt

status: parked — kept as a spike (Nikki 2026-11-12: "commit both, keep them in the spike, park"); the next step when it comes back is below

Nikki (2026-11-11), asked which of the earlier materials to look at on their own: felt first ("y"). The
palette's felt (MATERIALS MT1b, one of the stronger ones from screenshots) was a grain inside the shape;
the diorama mood pictures are felt Mipos. The per-part hook (`state.drawableWrap`, CUT-PAPER.md) adds the
edge.

## The spike (2026-11-11, scene `felt`)

`scripts/spikes/felt.playtime.lua`, each Mipo part (not the face):
- **A fuzzy edge first**: a few short shells past the outline (as the fur, FUR-SHELLS.md) keeping only stray
  fibres, fading ('fuzzy edge', 'fuzz length', 'fuzz layers'); their colour from a little further in (at the
  edge it's the drawn outline: the first fuzz was a dark halo).
- **The part through a felt shader**: fibres whose direction wanders (three stretched noise layers, their
  angle turning slowly; one direction made a triangle grid in the first materials spike) ('fibres', 'fibre
  size'), mottled wool ('mottled'), puffy (lit softly by the distance in from its own edge, 'puffy'), small dark
  needle pokes ('needle pokes'), a little lighter and duller than paint ('felt colour').
- **drawn lines**: felt has no hard lines: the drawing's colour mixed with the colour around it, the dark
  lines left out of that average (else the outline stayed dark); 0 the lines gone, 1 as drawn.

First look: hands and feet as soft felt shapes, mottled and striped, a fuzz of their own colour round them,
no hard outline at 'drawn lines' 0.1. The feet's lower edge still gets some dark fuzz (the colour borrowed
from further in crosses a drawn line). Live, the part drawn 5 times (4 fuzz shells), phone not measured.

## Steps

- [x] **FE1. The spike**: fibres, mottling, puff, needle pokes, softened lines, the fuzzy edge.
- [x] **FE2. Nikki plays with it**: keep, change or park.
  Kept 2026-11-12 (Nikki 2026-11-12: "commit both, keep them in the spike, park"): kept as a spike, parked.
- [ ] **FE3. If kept**: felt appliqué (the part's pattern as felt pieces stitched on, LEATHER's seam), felt
  as a material on a part (MT6's editor row), baked like the fur if it costs; real felt scans (MATERIALS:
  drawn and scanned beat noise).
