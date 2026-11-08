# Wearables — glasses, hats, headscarves, shirts, masks, underpants for Mipos

status: parked — Nikki 2026-11-08: "good as an experiment to come back later to". Hats liked ("feel nice"), pants and headscarves promising; scarves' cloth ribbons disliked. Scene `wearables`, code in src/wearables.lua

**Coming back to it:** load the scene `wearables`, tab to play. g u h b t x: glasses, pants, hat,
headscarf, shirt, mask at the mouse; w n y v i z: one on every Mipo; o all off. Next would be Nikki's
verdicts (WR1, WR6, WR9, WR10), then her drawings for the greybox (WR2), the phone cost (WR3).

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
- **Coming off inside the Mipo** (a hat in the head, glasses on the face): colliding again at once,
  Box2D stuck it in the face (Nikki 2026-11-08). Now it stays in that Mipo's collision group until
  its shapes are clear of the Mipo's (`love.physics.getDistance`), for every sort.
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
- Soft and spine torsos: the seat is drawn through the torso picture's own grid
  (`spineSkin.drawGrid` with the torso's bones), so it bends and squishes with what you see. Laid
  flat on the torso body it slid off a soft torso being pulled (Nikki 2026-11-08: "much better").
  Its outline is the mask's edge darkened in the shader, so it bends too.
- Not yet: the dots and stripes don't bend with the torso (the stencil does), loose pants are a
  flat greybox shape drawn over everything.

## Hats (2026-11-08)

Beanie (with a pompom), top hat, cap, party hat, sun hat, crown, greybox. Let go of one over the
top of a head and it goes on; `hatGrip` (default 1100: hats come off easier than glasses).
- Where: the head's skin mask (a potato head's torso1): the brim `sink` of the head's height down
  from where the mask starts, as wide as the mask's row there × `fit`, at least half the head's
  widest (a pointy head's top made the party hat a thimble). On a spine torso1 it rides the bend
  (`spineSkin.transformAt`, as a face does).
- Drawn in the Mipo's layers at z +380: over the hair (220), so hair sticks out under and round it
  (Nikki 2026-11-08), the ears (190) behind, the arms (402) in front.
- **Stacking** (Nikki 2026-11-08): let go of a hat over a hat and it sits on top, up to 6. Each
  sits on the one below's top (`topH`), its brim sunk a little in, at least 0.8 of its width (the
  top's width × fit made a tower of four end in a thimble). Higher hats come off easier (grip
  -12% a level, at least 40%); a hat whose hat below comes off falls too. `y` adds one more to
  every head.
- Not yet: ears in front of a hat by kind (a beanie with ears poking through), lobes on a potato
  head (the hat doesn't follow them), the cap's bill always points right.

## Scarves (2026-11-08) — parked

Parked, tried 2026-11-08: cloth ribbon tails as clothing disliked (Nikki: "i dont really like the
ibbons as clothing"). The code stays (`k` a scarf, `j` on every Mipo); the scene no longer stocks
them. If picked up: drawn tails that bend with the torso (as the pants' legs), or the wrap alone.

Stripes, dots, gingham, velvet (the cloth spike's fabrics). Let go of one over the neck (the head's
joint on torso1) and it goes on; `scarfGrip` (default 2000: scarves stay on). Not on potato heads
(no neck).
- The wrap: a rounded band round the neck and a knot, filled with the fabric, drawn in the Mipo's
  layers at z +390 (over the chin and the pants, under the arms). As wide as the torso at the
  neck, at least 55% of its widest.
- The tails: two `cloth.new` strips (4 columns), pinned along their top to torso1 (`pinBody`),
  one longer, hanging down the front and swinging; `collide = false` so far.
- Taller (Nikki 2026-11-08: "the scarfs can be taller"): `scarfTall` (default 1.6) times the
  wrap's and knot's first heights; the tails hang from the lower knot (made when it goes on).
- Not yet: the tails pass through the Mipo (collide off), potato heads.

## Headscarves (2026-11-08)

Teal, rose, cream (the cloth's new `plain` fabric, tinted), dots, gingham. Let go of one over a
head and it goes on; `headscarfGrip` (default 2200). Not on potato heads (the hood would cover
the whole Mipo).
- The hood: the head's own mask drawn `hood` (1.22) times bigger, an oval cut out round the face
  (from the eyes, brows, nose and mouth decals), filled with the fabric, its edges dark (a shader:
  the mask, the hole, the edge, in one). Drawn at z +230: over the hair (220) and the ears (190),
  under the face (250..254), so the eyes and mouth show in the opening.
- The drape: one cloth sheet (9 columns, not ribbons) pinned along a line under the hood to the
  head, hanging over the shoulders, drawn under the hood. One try (Nikki 2026-11-08), after the
  scarves' ribbon tails were disliked.
- Nikki 2026-11-08: "looks promising". A flipped head (`dims.sy < 0`) had its hood upside down: the
  mask was mirrored by a negative scale and again by the shader's flip; now only the shader (the
  pants' flat path had the same).
- A randomized Mipo: an item whose body went goes back on at its spot on the new one (was: dropped);
  a drape (and the parked tails) is made again when the head or its picture changes.

## Shirts (2026-11-08)

T-shirt (yellow), breton (horizontal stripes), tank top (no sleeves, a wider neck), sweater (sleeves
to the elbow, dots). Drop one on the chest; `shirtGrip` (default 2200).
- The body is the torso's skin from its top (a potato head: below the mouth) to the `hem`, a neck
  hole where the head hangs (an oval cut in the same shader as the rows), a hem band; drawn at z
  +305, over the pants (untucked), bending with soft and spine torsos as the pants do.
- Sleeves: tubes down the upper arms (the pants legs' code, now `tube`), drawn at z +404, over the
  arms (402, 403), under the hands.
- The cut shader now outlines every cut edge (the rows, the hole), the pants' waist too.
- A headscarf's drape (z 230) goes under a shirt.

## Masks (2026-11-08, not seen yet)

Eye bands (hero red, bandit black, with ties) and animal faces (cat with pointed ears, nose and
whiskers; bear with round ears and a muzzle; frog with eye bumps, cheeks and a smile). Drop one on
a face; `maskGrip` (default 1800).
- Laid over the face from its own parts: the band from the eyes' middle, spacing and height, the
  animal face from the face oval (the headscarf's: eyes, brows, nose, mouth). Holes where the eyes
  are (a stencil), so the Mipo's own eyes look out; drawn at z +256, over the face's parts (250..254),
  under hats and arms. Potato heads too (on a spine torso1 along the bend, as hats).
- Built while the game was on another scene: lint-clean, never drawn yet.

Steps:
- [ ] WR1. Nikki plays with the glasses: the fit, the jolt, the lens look. Keep, change or park?
- [ ] WR2. Drawn frames: scan glasses (front view, outline + mask like the Mipo parts, the lens
      hole as its own mask) to replace the greybox lines
- [ ] WR3. Cost on the phone: the screen canvas per frame (`./playtime.sh bench device wearables`);
      without it, lenses could tint and glint only
- [x] WR4. Hats, stacking (Nikki 2026-11-08: "hats feel nice")
- [ ] WR8. Hat leftovers: ears in front by kind, the cap's bill the way the Mipo faces, a soft
      potato head's lobes
- [x] WR5. Scarves: built and parked 2026-11-08 (cloth ribbons as clothing disliked)
- [ ] WR9. Headscarves: Nikki plays with them ("looks promising"); keep the drape or drop it
- [ ] WR10. Shirts: Nikki plays with them (the hem, the sleeves, the neck hole)
- [ ] WR11. Masks built 2026-11-08, not seen yet: x a mask, z on every Mipo
- [ ] WR6. Underpants: Nikki plays with them (the cut, the waist heights, the drop on the hips).
      Soft torsos done 2026-11-08
- [x] WR7. The wear/jolt code in `src/wearables.lua` (2026-11-08, with the underpants)
