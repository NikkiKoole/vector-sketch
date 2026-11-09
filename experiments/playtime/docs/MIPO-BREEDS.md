# Mipo breeds — kinds of Mipo that share DNA but still vary

status: active, focus

**Started:** 2026-10-30. **Focus since 2026-11-01.**

**Why now (2026-11-01):** a time to get to grips with the Mipo character: stronger, designed
characters instead of leaving it to the player, and a story that grows from playing with the kids.
Nothing about the world is decided. A hunch from that day: a world with an underground part, the
pear-bodied Mipos (rubberleg-pearbod) living below and other breeds above (`BURROW.md`,
`DEPTH-LAYERS.md`).

**The idea:** right now a random Mipo is random in every way at once. Breeds narrow that down:
little teddy bears, cats, dogs, fat ones, tall ones with long necks, hairy ones, bad ones,
geometric ones. Mipos of one breed share a lot of DNA and still differ from each other.

It helps two things:
- **Better random Mipos.** Narrowed-down randomness looks designed. Fully random looks like a clown.
- **Stories.** A breed is a cast member. Mr Men is one trait taken to the extreme (Mr Tall).
  Fabuland gives each species a job (the mouse baker, the bear policeman). Breeds and families
  give a place a population, and stories grow from that (`KING-ROLLO.md`, `INSPIRATIONS.md`).

---

## What's already there

The randomizer is nearly ready for this. Every random choice in `src/mipo-randomize.lua` reads
from one of two places:

- **Number ranges:** `D.randomRanges` in `src/dna-defaults.lua` (bodyScale, legH, armH, earScale,
  limbWMul, eye/nose/mouth/brow sizes, teethChance, …), drawn with a triangle distribution
  (`randomInRangeWeighted`).
- **Lists:** `src/shape-catalogs.lua` (torsoHeadShapes, earShapes, handShapes, haircutTextures,
  bodyhairTextures, limbSkinTextures, patternTextures, eye/pupil/brow/nose/teeth shapes).

`randomizeMipoConstrained` (the Bathhouse Mipos) is already a breed without the name. It locks
the limb skin to `leg1`, keeps the eyes round and allows only calm pupils. It passes this as two
loose opts tables (`textureOpts`, `faceOpts`), and that doesn't grow well.

What's missing:
- **Colours** are `randomHexColor()` everywhere: any hue, any brightness, chosen separately for
  skin, pattern, ears, hands and feet.
- **Catalog names say nothing**: `shapes1`…`shapes13`, `earx1r`…`earx16r`. A breed that wants
  "round torsos, pointy ears" can't ask for that.

---

## A breed is a table of overrides

Anything the breed doesn't name falls back to the defaults. That fallback is how breeds share
DNA and still vary.

```lua
teddy = {
    label   = 'teddy',
    ranges  = { legH = { min = 60, max = 200 }, armH = { min = 60, max = 220 },
                earScale = { min = 0.5, max = 0.8 }, limbWMul = { min = 0.4, max = 0.5 },
                teethChance = 0 },
    shapes  = { torso = { tag = 'round' }, ears = { tag = 'round' }, bodyhair = 'always' },
    palette = { hue = { 20, 40 }, sat = { 0.3, 0.6 }, light = { 0.35, 0.6 } },  -- browns
    creation = { neckSegments = 0 },
    -- later: voice = { set = 'theo', root = 'c4' }  (P6 in PUPPETMAKER-SOUND.md)
}
```

- **ranges** replace entries of `D.randomRanges` for this draw. Narrow a range, shift it, or pin
  it (`min == max`).
- **shapes** narrow a catalog list, by name or by tag.
- **palette** gives a hue, saturation and lightness range. Skin, pattern, ears, hands and feet
  all draw from it, so the colours belong together. One accent hue is allowed (a teddy's paws, a
  bad one's red pattern).
- **creation** sets body structure: torso and neck segments, potato head.
- **chances**, e.g. "always body hair", "never teeth", "teeth stick out half the time".

A Mipo remembers its breed: `dna.breed = 'teddy'`. "Randomize" then means "another of this
breed", and offspring know where they come from.

## Three layers: breed → family → individual

- **Breed:** the kind of Mipo (teddy).
- **Family:** a parent Mipo run through `mutateSizes` (exists: it jitters sizes inside the
  ranges). It looks like its parent, the same way a breed looks like itself. This gives you the
  Bear family.
- **Individual:** the small draws on top: which ear out of the allowed ears, pattern, haircut.

Mr Men characters come from the same idea: one range pushed to its edge. "Mr Tall" is the tall
breed with legH and neck at the maximum.

---

## Breeds (first list)

Breeds that need **no new art**, only numbers, lists and palettes:

| breed | what makes it |
|---|---|
| **teddy** | round torso and head, short thick limbs, small round ears, always furry, browns, no teeth |
| **fat** | high bodyScale, thick limbs (limbWMul up), short legs, small head |
| **tall / long neck** | neckSegments 2–3, long legs, small head, thin limbs |
| **hairy** | body hair always, wide haircut, limb hair always, hair colour close to skin |
| **bad** | angled brows (browBend), teeth stick out, dark/sour palette (greens, purples, greys) |
| **geometric** | square and triangle shapes, flat colours, no pattern (`type0`), simple eyes |
| **bathhouse** | today's `randomizeMipoConstrained`, moved over as the first breed |

Breeds that **may need new parts**: these are the expensive kind, do them later and only one at
a time.

| breed | what's missing |
|---|---|
| **cat** | pointy ears (maybe in the catalog already, see tags), whiskers, a tail |
| **dog** | floppy ears (the ears are springy welds today, `feedback_mipo_ears`), a snout |
| **mouse** | big round ears (likely possible now), thin tail, small pointy snout |

Check first how close the existing ears and noses get. A cat might be good enough with pointy
ears, a small nose and whiskers drawn on the face.

---

## Designing breeds in the editor

Build tools in LÖVE, not in tables. **"Breed from this"** in the Mipo editor: make one Mipo you
like, press the button, and it saves a breed:
- ranges at ± some % around its current values,
- lists narrowed to the shapes it uses (plus similar ones by tag),
- a palette around its colours.

Then press randomize a few times and see whether the litter still looks like one breed. Tighten
or loosen with one slider ("how alike").

Breeds would be saved as files (like the library: `breeds/<name>.lua` or `.json`), so they can be
added without code.

---

## Where it meets other work

- **P6. Voice in DNA** (`PUPPETMAKER-SOUND.md`): a breed sets a default voice. Teddies hum low,
  mice squeak high.
- **Worlds and doors** (`WORLDS-AND-DOORS.md`): a room could have its own population ("the mouse
  house").
- **Doll play** (`DOLL-PLAY.md`, F4 load your Mipo): a breed picker next to randomize.
- **King Rollo shorts** (`KING-ROLLO.md`): breeds as the cast of a season.
- **Burrow / depth layers** (`BURROW.md`, `DEPTH-LAYERS.md`): which breed lives where, if the
  underground hunch holds.

---

## The spike (2026-11-01)

`scripts/spikes/breeds` puts a litter of six Mipos of one breed on a floor; a panel (play mode) or
keys 1-9 pick the breed, r draws a new litter. Since 2026-11-09 (ENGINE-MERGE EM6) the breeds
live in `src/mipo-breeds.lua` (`lib.breeds`, picker order `lib.order`): teddy, fat, tall, hairy,
bad, geometric, bathhouse and rubberleg-pearbod, with 'any' (as today) in the spike to compare.
Edit a breed there and lurker reloads it, then r. A breed swaps `D.randomRanges` entries and
`shape-catalogs` lists in for the draw and puts them back after, and its palette gives every
random colour of the draw (`paletteColor`, through `characterManager.setRandomColor`). Shapes
are grouped by eye there until B1 tags them. `spec/mipo-breeds_spec.lua` checks each rolls, uses
its lists and build, keeps its colours in their bands and leaves nothing swapped in.

## rubberleg-pearbod, the first breed (2026-11-01)

Defined by hand from the vanilla scene (first called rubberleg): the pear body (`shapes7`) only,
always the right way up (`bodyFlipChance = 0`) and sized 1.35-1.6 (`bodyScale`; any Mipo: 1-2),
rope-like limbs (`leg1`, `leg5`), limb hair none half the time, else one of the last three
(`hair9`-`hair11`), and the widest leg stance (`legX = 0`: the hips at the body's lower corners;
positioners aren't randomized, so a breed sets them), eye white 1 and pupil 2 or 3, round and
big eyes set wide apart (`uniformEyeScale`, `eyeWMul` 1.1-1.5, `eyeX` 0.24-0.36), nose 7 (the
snout), 8, 9 or 12, real hands at about half size (`hand3r`, `handScale` 0.5-1) and the round
foot with toes (`feet7r`): the hands and feet draw from `randomHandShapes` and
`randomFootShapes`, so a breed can narrow one (`face`: the face randomizer's options,
`allowedEyeShapes` and `allowedPupilShapes`, indexes into the catalogs), teeth as wide as the
mouth or a little wider (`teethToMouth` 1-1.25: the teeth width setting worked out from the
rolled mouth shape's width, once, at the roll), always a potato head (`creation`: set after the
roll, which flips potato head every time). It lives in `src/mipo-breeds.lua` (`lib.breeds`, the
same swap-for-the-draw as the spike) and has a button in the Mipo editor, **random
rubberleg-pearbod**, above **undo**: every random button there remembers the Mipo from before,
and undo rebuilds it from that DNA, up to 20 steps back. In a breed's list `''` is "none" (limb
hair, for now).

## Steps

- [ ] **B1. Tag the catalogs.** Look at each torso/head, ear, hand/foot and pattern picture and
  give it tags (round, square, pointy, long, floppy, simple). `C.tags['shapes3'] = {'round'}`.
- [ ] **B2. Breed table + `randomizeAll(instance, breed)`.** Ranges and lists read through the
  breed with fallback to the defaults; `textureOpts`/`faceOpts` go away. Bathhouse becomes the
  first breed. Same Mipos out for the same seed when no breed is given (refactor snapshot).
- [ ] **B3. Breed palettes.** HSL ranges instead of `randomHexColor()`, one accent. The ranges are
  in (2026-11-09: `palette = { hues = bands, sat, light }`, `lib.paletteColor`); the accent isn't.
- [ ] **B4. First breeds:** teddy, fat, tall, then hairy, bad, geometric (in `src/mipo-breeds.lua`
  since 2026-11-09, as the spike tried them; not judged yet). Judge them by eye: 10
  in a row on stage.
- [ ] **B5. `dna.breed` + a breed picker** next to randomize in the Mipo editor.
- [ ] **B6. Breed from this:** save a breed from the Mipo in the editor, with a "how alike"
  slider.
- [ ] **B7. Families:** "a child of this one" (`mutateSizes` + small draws, same breed).
- [~] **B8. New parts** for cat/dog/mouse (tail, snout, whiskers, floppy ears): only after B4,
  one at a time.
- [ ] **B10. Face patches** (2026-11-08, `src/face-patches.lua`; spikes `breeds` (right panel) and
  `facing` (`c`)): skin colouring on the face, under the hair, the eyes on top, as a teddy's: eye
  hollows (darker), cheeks (warmer), a snout (lighter), coloured from the Mipo's skin. One decal per
  face holds them, clipped to the skin's inside (its mask less its outline, one stencil a face),
  turned with the face. tried 2026-11-08: baked into the skin picture (patch1..5): clipped for free,
  but a turning face (facing, autowalk) slid off them; kept the 5 slots for torso patches (breast,
  belly: the torso stays front-on). A Mipo has them while `instance.facePatches` holds settings; not
  saved yet. Nikki tries it: keep, tune, which breed gets what? Phone cost with B9.
- [x] **B9. Phone bench: the pupil clip, face patches, the mouth hole** (2026-11-08, iPhone SE 2,
  breeds with the litter at 20, all on screen). All on: 60 fps steady, draw 4.73 ms mean / 6.35 p95,
  frames max 17.1 ms, none over 20. Patches and pupil clip off: draw 4.06 / 5.64, so the two cost
  ~0.7 ms at 20 Mipos (by drawable kind with 5 on screen: patches ~30 us a face, the clip ~19 us a
  pupil). The mouth hole ~50 us a mouth over the plain fill (mostly sending its outline to the
  shader each frame), ~1 ms at 20: fewer outline points if it's ever needed. Kept, all three.
  Since measured: the pupil clip no longer cuts the eye's outline out of its stencil (that showed
  the eye's white through the line's soft edge, a white glare on the pupil's cut edge); it clips to
  the mask and draws the eye's outline again over the pupil. The same number of draws (the line went
  into the stencil before, on screen now), and the same cost: on the phone, A/B on the same 6 Mipos
  (12 pupils), decals 0.449 / 0.467 ms a frame old vs 0.454 / 0.442 new, draw 4.3-4.6 ms both.

## Open questions

- Should a breed also set behaviour (how a teddy walks, how a bad one reacts to being
  thrown), or only looks and voice? Start with looks.
- Do breeds mix? A teddy × tall child is fun, but keep it for later.
- Names: breeds with real-animal names (cat, dog) or Mipo names (`mipomi-lang`)?
