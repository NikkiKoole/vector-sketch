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

- [ ] **A11. Nail tops, screw tops and other markings on wood.** For the plank spikes (`planks`,
  `boat2`, `drawn-sea`, `wild`; `PLANKS.md`, `BOAT.md`), where they're drawn in code today: nails
  are two grey circles, rivets the same, stains are dark ellipses, rust a straight line, knots a
  stroked oval, moss clumps of circles, vine leaves a diamond with a line.
  - Draw, outline + mask, about 48×48, a few of each so they don't repeat: **nail heads** (round,
    a bit off-centre, one hammered in crooked), **screw heads** (slot, cross), **rivets**, a
    **bolt with a washer**.
  - Markings, white on transparent (tinted, no mask), a few variants each: **rust streaks**
    running down from a nail (about 40×160), **stains / water marks** (soft blotches, 200×120),
    **knots** (with the grain bending round them), **cracks and splits** from a plank's end,
    **end grain** (rings, for a plank seen end on), **paint chips / peeling** (for the grime end of
    `wild`), a **saw mark** or two.
  - For `wild`'s growth end, if they're drawn too: **moss clumps** (outline + mask), **vine
    leaves** (two or three shapes), a **cobweb** for a window corner, **small flowers**.

- [ ] **A12. Leaves, many kinds.** For the `plants` spike (`PLANTS.md`), which grows L-system plants
  and hangs leaves on them; today every leaf is one of the scanned ovals (`textures/plants/oval-*`,
  `petal-*`, from Scan 12), so a daisy, a sunflower and a bush all wear the same leaf.
  - Draw, outline + mask, drawn pointing **up with the stalk end at the bottom** (that's where it
    joins the stem), about 150×300, a few of each so they don't repeat: round, heart-shaped,
    long and narrow (grass, tulip), serrated, lobed (oak-ish), a fern leaflet, a big floppy one
    (sunflower), a small one for bushes, a curled or folded one. A vein down the middle is welcome.
  - Also handy: petals in a few shapes (round, pointed, ragged), buds, a seed head, a sprout or two
    more (`sprout-*` has three).
  - Now really A13: the wild plants want their own parts, all at one scale.

- [ ] **A13. Plant parts, lots, all at the same scale** (Nikki, 2026-11-05: "so linework more or
  less stays consistent"). The `plants` spike has 19 Dutch wild plants now (`PLANTS.md`), made from
  a handful of borrowed pictures stretched to every size, so the crayon line changes thickness from
  part to part: the Mipo eye rings used as tiny florets draw at ~0.2× (hairline), the ovals stretched
  into iris and bulrush leaves at ~2.5× long and 0.15× wide (fat ends, thin sides), the canopy ovals
  at ~3×. Squashing (narrow leaves made from fat ovals) thickens the line one way and thins it the
  other.
  - **The rule:** draw every part at about the size it shows in the game, with the same crayon,
    on the same sheet, scanned at one resolution. Then the code draws them at ~1× (only the plant's
    own size, ±30 %), and the line is the same everywhere. Narrow things are drawn narrow, not
    squashed from wide ones. Outline + mask, white on transparent, as always; leaves and petals
    pointing **up with the stalk end at the bottom**; a few variants of each.
  - **Sizes**, roughly, in game pixels (= picture pixels at 1×), longest side:
    - **Florets / tiny flowers**, ~30 px, a dozen variants (marjoram, thyme, mint, loosestrife,
      yarrow, the spore beads): small round blobs, some a bit open. These are drawn the most.
    - **Flower heads**, ~90–140: a devil's-bit ball, a scabious pincushion (bigger outer florets),
      a dandelion head and a **dandelion clock**, a foxglove **bell** (~100, open mouth), a
      Solomon's seal bell (~45), a bulrush **cigar** (~120) and its thin spike.
    - **Petals**, ~55–180: poppy (broad, crumpled, ~120), anemone (~55), marsh marigold (round,
      cup-shaped, ~60), iris **fall** (~180, hanging) and **standard** (~100, narrow, upright).
    - **Buds and seed heads**: a nodding hairy poppy bud (~70), a poppy capsule with its crown,
      a closed iris bud, round berries (~40, the Solomon's seal ones blue-black).
    - **Small leaves**, ~25–90: thyme (tiny oval), marjoram (oval), water mint (oval, toothed).
    - **Middle leaves**, ~130–190: loosestrife (narrow, pointed), scabious (deeply lobed),
      yarrow (feathery, narrow), Solomon's seal (broad oval, veins along it), marsh marigold
      (round, heart-shaped base), a royal fern leaflet (oblong, ~145).
    - **Rosette leaves**, ~250–350: dandelion (toothed, lying low), devil's-bit (long, whole),
      foxglove (big, soft, wrinkled).
    - **Long leaves**, drawn long and narrow at full length: hart's-tongue (strap, ~400, wavy
      edge), male fern frond (~700, lance-shaped, two-sided), iris sword (~950), bulrush (~1100,
      very thin; maybe in two pieces that join, if a sheet can't take it).
    - **Forest**: canopy leaf clumps (~1000, big, but drawn that big so the line stays crayon),
      a trunk stroke or two (bark), leaf litter for the forest floor.
  - Have: `textures/plants/` (ovals, petals, daisy, heart, sprouts, tufts, two fronds), the eye
    rings copied as `berry-0n`; all fine to keep as fallbacks until the new ones are in.

- [ ] **A19. Beaks: a duck and a stork first** (`BEAKS.md` BE2; Nikki 2026-11-11: "beaks are pretty
  good"). The `beaks` spike builds a 3D beak that opens from three pictures a beak and lays the side
  pictures on it, so the drawing's strokes and grain show.
  - Have: placeholders, flat colour blocks (`textures/beak/<name>-upper/-lower/-top.png`, from
    `claudetools/beak-pictures.py`): duck, stork, finch, parrot, toucan. Draw over them.
  - Draw, three pictures a beak, each 512×512 on transparent, the beak pointing **right**, the
    mouth's corner (the hinge) at the **left edge**, the mouth line at **row 256**, 512 px = the
    upper half's length:
    - `<name>-upper.png`: the upper half from the side, above the mouth line (a hook may come below it).
    - `<name>-lower.png`: the lower half from the side, below it; it may stop short of the tip.
    - `<name>-top.png`: the whole beak from above, centred on row 256: only its width is read.
  - **Unlike the other parts:** in colour, **fill only, no outline** and no mask (the game draws the
    outline; a drawn one would smear across the 3D surface). Markings that run along or around the
    beak (a ridge, a nail, a band, a dark tip) read best from every side.
  - Then maybe a finch, a parrot, a toucan, or new birds.

- [ ] **A20. Shut eyes, one for each eye** (2026-11-12; Nikki: "i just want to see the bottom line").
  A blink past 70 % shut, and settings → mipos → 'eyes shut', draw `eye-NN-closed.png` instead of
  the eye (`src/physics/box2d-draw-textured.lua`, `lib.blinkShutAt`), in the outline's colour, no
  white, no pupil.
  - Have: cut by script from the open outlines (`textures/mipo/eye/eye-01-closed.png` … `07`): the
    outline below the middle of the white, the cut ends faded rather than tapered. The round eyes
    (01, 03, 06, 07) read well; 02 and 05 come out nearly flat; 04 (the arrow) becomes a "7" hook.
  - Draw: a shut lid for each of the 7 eyes, white on transparent, no mask, **the same size as its
    open eye** (01 146×133 … 07 166×162) with the line where the bottom of the open eye sits, ends
    tapered. A lash or two welcome (A5). 04 wants its own idea.
  - On dark fur the black line nearly disappears: a slightly thicker line than the open outline helps.

## For the materials (MATERIALS.md, 2026-11-06)

The materials in `material-check` are lit from each picture's mask; these give them what a mask
can't. Try each on two or three pictures first: the scene shows straight away if it helps.

- [ ] **A14. Hatching sheets.** So the shading can be her own lines (MATERIALS MT8): where a thing is
  darker after the light, it shows denser hatching of hers.
  - Draw: one pencil (or crayon), the same on every sheet, **five densities**: very light, light,
    medium, dense, cross-hatched; **three versions of each** (they swap ~12 times a second, so the
    hatching boils like the burrow rim). Fill a square, about 512×512, edge to edge (it repeats
    across a shape, so no border, lines running off all sides). Strokes all leaning the same way
    on a sheet; a second set at another angle is a bonus.
  - White on transparent like everything else; no mask. One sheet per density, or all on one scan
    with space between (`tools/scan2tex` cuts them).
- [ ] **A15. Height pictures** (MATERIALS MT11). Today every shape is lit as a dome or a cushion,
  because the light only knows the outline: no nose bump, no fold in an ear, no belly.
  - Draw: for a few parts that have a shape inside (a body or two, an ear, a nose, a foot), a
    **grey picture the same size as the part**, `name-height.png`: lighter is nearer you, darker
    further away, soft (a soft pencil or brush, smudged; hard edges show as steps in shiny
    materials). It only has to say where the bumps and dips are; the outline still makes the rim.
  - Also, for parts meant to be **shiny** (metal, glaze, glass): masks filled **solid**, no brush
    gaps. body-04's streaky mask shows on metal as ridges (nice as hammered tin, not as gold).
- [ ] **A16. A material map** (MATERIALS MT3, the sneaker idea): one part, two or three materials.
  - Draw: for two or three parts (a foot with a sole and a cloth top, a body with a belly patch, a
    shoe), next to outline + mask, `name-material.png` the same size: **red** where it's the first
    material (leather), **green** the second (rubber), **blue** the third (cloth). Flat colour, a
    hard edge between them is fine.
- [ ] **A17. Smoke puffs.** The smoke borrows the Mipo body outlines now and reads as pale clumps.
  - Draw: outline + mask, about 200×200, **six or more**: round puffs, lumpy ones (three bumps), a
    small curl, a long wisp, a torn bit for the end of the trail. Loose, soft line. The boat
    scenes' vector puffs (walter-boat) are the look.
- [ ] **A18. Bark, hand-drawn** (`BARK.md` BK12; Nikki 2026-11-08: "the barks are nice, but it might
  be better if I hand-draw some of it"). The `bark` spike's trees now wear photo scans.
  - Draw first: **bark tiles**, one or two kinds (oak furrows, birch, aspen), in colour, about 512
    wide (around the stem) by any height (up the trunk). It repeats upward, so top and bottom should
    meet (or it gets mirror-repeated). Draw it flat: the round stem squeezes the sides itself.
  - Optional: a **grey height sheet** of the same tile (white sticks out, dark is a groove), when
    the bumps should be yours; otherwise they're worked out from the colour (A15 is the same idea).
  - Then: **eyes, knots, scars, branch collars** as stamps, 512×320 each, transparent around
    (they go in `bark-eyes.png`'s cells next to the photo scars).
  - Maybe, after the tiles: a drawn **trunk edge** instead of the computed outline (like A1).
- A12's leaves: **a vein down the middle (and side veins)** shows well now: with the light behind
  a leaf (material-check, b), the veins in the outline come out dark against the glow.
- A3's hair tufts would also give **fur an edge** (tufts sticking out past the outline instead of a
  frayed inside).

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
