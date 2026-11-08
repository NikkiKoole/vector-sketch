# Wearables — glasses, hats, headscarves, scarves, underpants for Mipos

status: active

Things a Mipo wears, as **loose toys** (Nikki 2026-11-08): you put them on and take them off by
hand, a bump knocks them off. Not in the DNA. Greybox first; Nikki draws the real ones. Built on
what's there: the glass bead lenses (GLASS-BEADS.md, form-bake), the cloth spike (CLOTH.md) for
ends that hang, the face box (mipo-textures placeEyes) for where things go on a face.

## Glasses (2026-11-08)

Scene `wearables` (`scripts/spikes/wearables.playtime.lua`; was `glasses`), the wear/jolt code in
`src/wearables.lua`. Five greybox pairs: granny (round, gold, magnifying),
nerd (rounded square, thick black, big magnified eyes), sun (dark), heart (pink), red (round).
- **On**: let go of a pair near a face and it welds on, fitted to that face (eye spacing → width,
  eye height → height; the pupils' `ox/oy/eyeH`, so a facing turn narrows them). While held over a
  face a ring says "let go". Worn, they touch nothing (`setMask` all: a neighbour's head bumping
  them tore them off) but the pointer can still grab them.
- **Off**: grab them (pointer) or a jolt: the face's speed changing by more than `grip` px/s over
  6 steps (~0.1 s). Measured 2026-11-08: standing Mipos 100-1100, a throw and landing 1450-1750,
  default 1300. The weld's reaction force per kilo was tried first and dropped: a standing Mipo's
  jittery head spiked it as high as a throw (92k vs 88-127k).
- **Lenses**: the world drawn into a screen canvas (as in the glass spike), each lens bends and
  magnifies it (form-bake: a pebble map for the rim, a dome for the magnification), tint, dark for
  sunglasses, a rim, highlights, and a storybook glint (two slanted stripes). Drawn over everything,
  arms too.
- Keys in play mode: g glasses, u underpants, m a Mipo, w glasses on every face, n pants on every
  Mipo, o all off, r reset, p panel.

## Underpants (2026-11-08)

Boxers (dots), striped boxers, knickers, briefs. Let go of a pair over the hips (between the two
hip joints) and they go on; `pantsGrip` (default 1600) for the jolt.
- Cut from the Mipo itself: the **seat** is the torso's own mask picture below a waistline (a
  shader drops the rest), so it follows the drawn torso; the 8-point shape8 outline was tried first
  and dropped: the skin picture is the shape8 document * 1.1 with margins, so the seat came out
  narrower than the torso and short of its bottom. A **tube** per upper leg from the hip joint
  toward the knee (`leg`: boxers 0.5, knickers 0.06), flared. A waistband, a dark line under it.
- Drawn in the Mipo's own layers (`state.drawSplits`, z +302): over the torso and legs, under the
  nose, feet and arms. A potato head's waist stays below its mouth.
- Not yet: spine torsos (the picture bends over bands; no pants), soft torsos (the seat doesn't
  squish with the lobes), the outline round the seat looked faint, loose pants are a flat greybox
  shape drawn over everything.

Steps:
- [ ] WR1. Nikki plays with the glasses: the fit, the jolt, the lens look. Keep, change or park?
- [ ] WR2. Drawn frames: scan glasses (front view, outline + mask like the Mipo parts, the lens
      hole as its own mask) to replace the greybox lines
- [ ] WR3. Cost on the phone: the screen canvas per frame (`./playtime.sh bench device wearables`);
      without it, lenses could tint and glint only
- [ ] WR4. A hat: same wear/jolt code on the head's top (shape8 vertex 1), hair sticking out under and round it
      (Nikki 2026-11-08), ears in front or behind by kind
- [ ] WR5. A headscarf: drawn layer hugging the head + cloth ends (CLOTH.md pins riding a body)
- [ ] WR6. Underpants: Nikki plays with them (the cut, the waist heights, the drop on the hips).
      Then spine and soft torsos, the seat's outline
- [x] WR7. The wear/jolt code in `src/wearables.lua` (2026-11-08, with the underpants)
