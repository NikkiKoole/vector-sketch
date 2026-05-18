# Mipo Code — Design Idea

A short, memorable, portable string that uniquely identifies a Mipo character.
Bidirectional: encode existing DNA → code, decode code → spawn identical Mipo.
Works across apps as long as they share the same kind definitions and alphabet.

## Format

```
SPUD-XKBMR-TVQZN
```

Three segments separated by dashes:

1. **KIND** — a meaningful English word (variable length) that sets the archetype
2. **BODY** — 5 characters encoding body/limb/texture decisions
3. **FACE** — 5 characters encoding all face feature decisions

## Archetypes — Mipo families

The KIND word is more than a topology flag — it defines a **design family**. Members of the
same family are recognizably related, like species. A bathhouse full of BLOBs are all clearly
BLOBs, but each one is still unique within that space.

Each family has:
- Fixed topology (isPotatoHead, torso segments, neck)
- Constrained ranges for body scale, limb proportions, face placement
- An aesthetic character — silhouette, feel, personality implied by shape

`randomizeMipoConstrained` can eventually accept a kind parameter so "give me a random SPUD"
always produces something that reads unmistakably as a SPUD.

| word | family character |
|------|---------|
| BLOB | round, compact, normal head — the default friendly Mipo |
| SPUD | potato head — torso is the face, no separate head, very expressive body |
| TALL | long limbs, narrow body — elegant or lanky depending on face |
| TWIG | very thin, small scale — delicate, almost insect-like |
| CHUNK | wide, short limbs — solid, heavy, low center of gravity |
| WIDE | squat and broad — almost square proportions |
| (more TBD) | families can be added as new apps need them |

Families are the stable unit of cross-app compatibility — a SPUD in the bathhouse app
is the same SPUD family as in any future app that knows the kind definitions.

## Alphabet for BODY and FACE blocks

32-symbol alphabet — consonants only, no vowels (avoids accidental words), no confusable pairs (O/0, I/1):

```
BCDFGHJKLMNPQRSTVWXYZ23456789
```

5 bits per character × 5 characters = **25 bits per block**, 50 bits total across both blocks.

## What the 50 bits encode (draft)

### BODY block (25 bits)

| bits | decision |
|------|---------|
| 2 | body scale tier (4 options: tiny / small / medium / large) |
| 2 | leg length tier (4 options) |
| 2 | arm length tier (4 options) |
| 2 | ear scale tier (4 options) |
| 2 | feet scale tier (4 options) |
| 2 | hand scale tier (4 options) |
| 4 | skin texture index (up to 16 options from constrained set) |
| 4 | hair color bucket (hue family: warm / cool / neutral / vivid etc.) |
| 3 | (reserved / future) |

### FACE block (25 bits)

| bits | decision |
|------|---------|
| 3 | eye shape index |
| 2 | eye scale tier (uniform wMul/hMul, 4 options) |
| 3 | pupil shape index (from allowed set: 1,2,3,6,7,8) |
| 2 | pupil scale tier (4 options) |
| 2 | eye X position tier |
| 2 | eye Y position tier |
| 2 | brow shape + scale tier (combined) |
| 2 | nose shape + size tier (combined) |
| 2 | nose Y position tier |
| 2 | mouth shape + width tier (combined) |
| 1 | teeth: yes/no |

## Open questions

- How many kind words do we need before launch?
- Should some kinds force specific body block constraints (e.g. SPUD always forces isPotatoHead)?
- Tier cutoff values per decision — needs tuning once kinds are defined
- Should hair color be a full hue bucket (6 families) or a direct palette index?
- Lip texture constraint in constrained path — lock to black line style?
- Should BODY block encode torso segment count, or is that always baked into KIND?

## What needs to be built

1. Define tier ranges per decision (matching `dna-defaults.lua` ranges)
2. `dnaToCode(dna)` — reads DNA, maps each value to nearest tier, packs bits, base-32 encodes
3. `codeToDna(code)` — decodes kind + two blocks, expands tiers to mid-range DNA values
4. `spawnFromCode(code, x, y)` — decode → `createCharacterFromJustDNA`
5. UI: show code for selected Mipo, input field to spawn from code

## Why not a seed

A random seed only works if recorded at creation time and the character is never tweaked.
The code approach works at any moment — design a Mipo, hit "get code", share it.
