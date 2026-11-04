# Things to draw — the list for drawing sessions

status: active

**Started:** 2026-11-02. What to bring to a drawing session: what each picture is for, its size,
and what's there already. Pick a few, draw them, drop them in `textures/`, tick them here.

**How pictures are made (keep this, then new ones drop straight into the catalogs):**
- White on transparent; the game tints them.
- A part with colour or a pattern inside is a pair: `name.png` (the outline) + `name-mask.png`
  (the filled shape, same size). Strokes and lines need no mask.
- Draw a few variants of a kind rather than one: breeds and the outline repeats pick between them.
- Mirror-friendly where it can be: a lot of parts are flipped for the other side.

---

## Now (asked for)

- [ ] **A1. Outline lines for any shape.** For the drawn outline (`BURROW.md`, "an interesting
  outline for any shape", `../drawn-outline/`), which repeats a stroke along a shape's edge.
  - Have: `line1.png`, `line2.png` (66×486, 82×512): chunky crayon, drawn upwards.
  - Draw: a few sizes and thicknesses, **several variants of each kind** (thin pencil, chunky
    crayon, brush pen) so the repeat doesn't show. About 70×500, drawn upwards (`strokes/line*.png`)
    or sideways (`track*.png`).
  - Also: a few **tapered ends** as their own pieces, and maybe short **corner pieces** (sharp
    corners fold the strip over itself today, a dark notch).
- [ ] **A2. Lips, upper and lower, bigger.** They get stretched across wide mouths.
  - Have: `upperlip1-4`, `lowerlip1-4`, each with a `-mask`, about 200×256 (upperlip4 256×172).
  - Draw: the same pairs at a higher resolution (check how wide the widest mouth draws on
    screen, draw at about twice that).
- [ ] **A3. Hair tufts.** To try the tuft hair again (`HAIR-LOCKS.md`: the tufts are the route).
  - Have: the tufts borrow the fuzzy ear (`earx2r`, 215×256).
  - Draw: like an ear, outline + mask, about that size. A few kinds: spiky, curly, flat lock,
    wispy. The haircuts (spiky, mohawk, swept, pigtails, cowlick, fringe) want different ones.
- [ ] **A9. A tongue.** For the raspberry (`RASPBERRY.md`); drawn in code until then.
  - Have: nothing; `src/render/mouth.lua` drawTongue draws a pink rounded placeholder.
  - Draw: outline + mask, pointing down, about 120×200, root at the top (it hides behind the
    upper lip). Maybe two or three: plain, with a groove, a fat one.

## Worth doing in the same sessions

- [ ] **A4. Hands.** Only 3 hand shapes (`hand1`-`hand3`, `hand3r`) against 8 feet with r/x
  variants: the tightest list a breed can narrow from.
  - Draw: more hands (mitten, three fingers, round paw, long fingers…), with masks.
  - Missing masks: `hand1`, `hand2` (no colour or pattern fill), `feet4`, `feet5`.
- [ ] **A5. Eyelashes.** Left over from the Bathhouse polish ("for a cuter read"). A few kinds;
  a breed can have them or not.
- [ ] **A6. Breed sheets on paper.** What a breed *should* look like, before tuning numbers
  (`MIPO-BREEDS.md`): a few Mipos of one kind, poses and faces. Start with the pear ones
  (rubberleg-pearbod). The editor work then matches a drawing instead of rolling dice, and the
  kids can point at the one they like (and name it).
- [ ] **A7. New body shapes**, only if the breed sheets want them. They go on the shape8 outline
  sheet (`scripts/tests/meta.playtime.json`, `src/shape8-dict.lua`), so a clean closed outline.

## Only if the underground hunch holds

- [ ] **A8. Underground.** Earth and soil textures, roots, pebbles, a burrow rim (the rim's
  outline is A1). `BURROW.md`, `DEPTH-LAYERS.md`.
  Rocks too: the burrow's 70 falling rocks (abfd9647, 2026-11-03) wear Mipo body outlines with an
  OMP skin until rocks are drawn (outline + mask, `tools/scan2tex`: type `world/rock`). The earth
  itself is a shader for now (topsoil, clay, grain, roots), so drawn soil is optional.

## Later, when something asks for it

- [~] **A9. Breed parts** (`MIPO-BREEDS.md` B8): tail, whiskers, snout, floppy ears. Only once
  a breed wants one; whiskers are the cheapest.
- [~] **A10. World art** (`WORLD-BUILDING.md` G3-G5): ground skins, parallax hills, sky. After the
  world is clearer.

## Have already, not needed now

- `gum1.png` (242×79): the May gum. Today's gum is a tinted stroke (`brow5`), so no new gum.
