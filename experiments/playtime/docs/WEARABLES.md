# Wearables — glasses, hats, headscarves, scarves, underpants for Mipos

status: active

Things a Mipo wears, as **loose toys** (Nikki 2026-11-08): you put them on and take them off by
hand, a bump knocks them off. Not in the DNA. Greybox first; Nikki draws the real ones. Built on
what's there: the glass bead lenses (GLASS-BEADS.md, form-bake), the cloth spike (CLOTH.md) for
ends that hang, the face box (mipo-textures placeEyes) for where things go on a face.

## Glasses (spike `glasses`, 2026-11-08)

`scripts/spikes/glasses.playtime.lua`. Five greybox pairs: granny (round, gold, magnifying),
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
- Keys in play mode: g a pair, m a Mipo, w a pair on every face, o all off, r reset, p panel.

Steps:
- [ ] WR1. Nikki plays with the glasses: the fit, the jolt, the lens look. Keep, change or park?
- [ ] WR2. Drawn frames: scan glasses (front view, outline + mask like the Mipo parts, the lens
      hole as its own mask) to replace the greybox lines
- [ ] WR3. Cost on the phone: the screen canvas per frame (`./playtime.sh bench device glasses`);
      without it, lenses could tint and glint only
- [ ] WR4. A hat: same wear/jolt code on the head's top (shape8 vertex 1), drawn behind the ears or
      in front of the hair, by kind
- [ ] WR5. A headscarf: drawn layer hugging the head + cloth ends (CLOTH.md pins riding a body)
- [ ] WR6. Underpants (boxers, knickers): a layer on torso and upper legs that follows the parts
      (bodyhair-like overlay, or a connected texture over the hips); put on how? (a drop on the
      torso?)
- [ ] WR7. Pull the wear/jolt/fit code into `src/wearables.lua` once a second wearable uses it
