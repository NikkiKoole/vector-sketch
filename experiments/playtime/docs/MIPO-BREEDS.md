# Mipo breeds — kinds of Mipo that share DNA but still vary

status: idea

**Started:** 2026-10-30.

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
- **The Sago Rule:** breeds feed the follow-up app's Mipo, they're not a feature of their own.
  Keep it to "random Mipos look better and come in kinds".

---

## Steps, if it becomes a plan

- [ ] **B1. Tag the catalogs.** Look at each torso/head, ear, hand/foot and pattern picture and
  give it tags (round, square, pointy, long, floppy, simple). `C.tags['shapes3'] = {'round'}`.
- [ ] **B2. Breed table + `randomizeAll(instance, breed)`.** Ranges and lists read through the
  breed with fallback to the defaults; `textureOpts`/`faceOpts` go away. Bathhouse becomes the
  first breed. Same Mipos out for the same seed when no breed is given (refactor snapshot).
- [ ] **B3. Breed palettes.** HSL ranges instead of `randomHexColor()`, one accent.
- [ ] **B4. First breeds:** teddy, fat, tall, then hairy, bad, geometric. Judge them by eye: 10
  in a row on stage.
- [ ] **B5. `dna.breed` + a breed picker** next to randomize in the Mipo editor.
- [ ] **B6. Breed from this:** save a breed from the Mipo in the editor, with a "how alike"
  slider.
- [ ] **B7. Families:** "a child of this one" (`mutateSizes` + small draws, same breed).
- [~] **B8. New parts** for cat/dog/mouse (tail, snout, whiskers, floppy ears): only after B4,
  one at a time.

## Open questions

- Should a breed also set behaviour (how a teddy walks, how a bad one reacts to being
  thrown), or only looks and voice? Start with looks.
- Do breeds mix? A teddy × tall child is fun, but keep it for later.
- Names: breeds with real-animal names (cat, dog) or Mipo names (`mipomi-lang`)?
