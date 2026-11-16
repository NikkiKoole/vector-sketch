# Drag feel — a dragged Mipo that feels handled, not hauled

status: parked — kept as a spike; tried 2026-11-16, Nikki unsure ("gosh, unsure, park")

Nikki (2026-11-16): "anticipation while dragging a mipo? so it sort of feels more natural dragging" and "imagine
the mipo testing his surroundings a bit while dragging to try to avoid or connect with things". Scene `dragfeel`
(`scripts/spikes/dragfeel.playtime.lua`), the behaviour in `scripts/spikes/drag-feel.lua` (`lib.on` switches,
`lib.tuning` numbers: ready to land as an engine module with its sliders). Physics and muscles only.

## The stages (2026-11-16, first pass)

- **notice**: the finger hovering near and above: it looks at it and lifts its arms, higher the nearer.
- **pickup**: grabbed off the ground, a crouch first (the drag held at half its weight for 0.16 s), then up.
- **middle**: held by the torso's centre wherever pressed (a held hand swung the whole Mipo round it).
- **spring**: the drag a softer spring (2.6 Hz, damping 0.45; the engine's 5 Hz): lag, and a swing past on a stop.
- **upright**: the torso steered upright, leaning with the drag (feet trailing). Steered directly: the engine's
  KEEP_ANGLE skips a body the pointer holds (`src/keep-angle.lua`, `hitted`), so a torso muscle did nothing
  and it spun (the first try: -148..128 degrees; after: within the lean).
- **dangle**: arms and legs on soft muscles (kp 3) while held, so they swing instead of standing stiff.
- **brace**: a ray along the drag (0.3 s ahead): something there, arms toward it, knees up, eyes on it.
- **feel**: a ray down: a floor within 1.8 leg lengths, the legs firm up to land; higher, they walk in the air.
- **reach**: the drag slower than 600 px/s near a hold (the bar, rungs, the ledge's corner, other Mipos' hands):
  the near arm aims at it, and a hand on it grips (a revolute joint). A grip breaks pulled 2.5 x its weight for
  0.15 s or with the finger 450 px off. Let go holding on, it hangs (8 s, 0 for good).

Tried over the bridge with a fake pointer (`getPointerPosition` swapped in a test window): grabbed by a hand
it moved to the torso, crouched, lifted, upright; a fast drag at the wall braced; held slowly under the bar both
hands gripped, and let go it hung there. Not tried: notice (it reads the real mouse), the ladder, the ledge.

## Next

- [ ] DF1. Nikki tries it by hand: which stages help, which numbers.
- [ ] DF2. Landing: knees give and a settle on a drop (the jump's landing, MIPO-LOCOMOTION LO8).
- [ ] DF3. Into the engine for every scene: the liked stages as `lib.tuning` (settings → tuning).
