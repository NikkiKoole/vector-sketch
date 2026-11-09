# Mipo maker — Puppetmaker 2's dress-up screen, in Playtime

status: active

**Started:** 2026-11-09. The editor's Mipo panel (`src/ui/mipo/`) stays: it is the developer's tool,
reaches everything, accordions and numbers, mouse first. The maker is for kids playing: tap a Mipo,
change it on one card of pictures, colours and a few icon sliders, on a phone or an iPad.

**Decided with Nikki (2026-11-09):**
- For kids playing, but with a few **dev-only** options in it while developing (marked in the
  catalog, hidden in a ship build).
- Opened by **tapping a Mipo in play mode**, only where the **scene allows it**: a per-scene setting,
  like the camera settings (`state.cameraSettings`, saved with the scene, set in world settings).
- **Puppetmaker 2's drawings as they are**: copied from `experiments/puppet-maker2/assets/ui/`.

## What Puppetmaker 2 does (the model)

`experiments/puppet-maker2/scenes/editGuy.lua`, `src/editguy-ui.lua`:
- **Left:** an endless strip of category icons (body, ears, brows, lips…): it wraps, flicks with
  momentum, ticks per icon passing; the picked one wobbles.
- **Middle:** the Mipo, physics live (poke it while dressing it); the camera tweens to the head or
  the whole body by category.
- **Right:** a tall drawn panel with three paper tabs, **part / colours / pattern**. On top, rows of
  **icon sliders** on taped strips (icon button, drawn slider, icon button: mouth narrow ↔ wide), a
  child picker for categories with children (face → eyes / brows); below, a **flickable grid**: part
  pictures tinted through their mask in the Mipo's colour (the picked one pulses), paint-blob colour
  dots (fill / line / pattern), pattern circles in the part's colours.
- **Feel:** every change growls, pitched by the slider's value; clicks, ticks; big drawn buttons
  (dice for a random Mipo).

Not to copy: the ~900-line `if category == ...` chain, layout tied to the tab picture's pixels
(650×1240), its DNA shape (FACE-SYSTEM-PLAN.md: different, don't lift it). Copy the layout, the
drawings and the feel, not the code, nor its flow (below).

## The design: one card, two levels (Nikki 2026-11-09)

Puppetmaker 2 chooses in three levels on both sides of the screen: category (strip, left), tab
(right), then the choice (grid). The eyes jump past the Mipo, two panels squeeze it on a phone,
and recolouring the ears means a tab switch that hides the shapes. Here: **one card**, **pick what,
then change it**.

```
 ┌──────────────────────────────┬─────────────────────┐
 │                              │ ◀ ear nose eye … ▶  │  categories: a flickable row in the card
 │                              │  (dice)    (breed)  │  whole-Mipo buttons
 │                              ├─────────────────────┤
 │         the Mipo             │  ▢  ▢  ▢  ▢         │
 │   (live; tap a part to       │  ▢  ▣  ▢  ▢         │  shapes, flick up/down
 │    pick it, drag to poke)    │  ▢  ▢  ▢  ▢         │
 │                              ├─────────────────────┤
 │                              │ ◐ ● ● ● ● ● ● ▸     │  colour blobs, always there
 │                              │ ◌ ◌ ◌ ◌ ◌ ▸         │  patterns, always there
 │                              ├─────────────────────┤
 │                              │ ⇤ ━━━●━━━ ⇥  (more) │  icon sliders on tape, folded
 └──────────────────────────────┴─────────────────────┘
```

- **No tabs.** Shapes, colours and patterns of the picked part are all on the card; fill / line /
  pattern is a small toggle on the colour row.
- **The Mipo picks too.** Tap its ear and the card goes to ears, the camera moves in. The row stays
  for parts too small to hit and whole-Mipo things (dice, breed); tap and row stay in step. On the
  head the camera goes to the face, so eyes and teeth get big enough to tap.
- **Icon sliders folded** behind 'more' on the tape strip; the dev-only rows live in that fold too.
- **One component, one size rule:** docked right in landscape, from the bottom on a phone if needed;
  shrinks to a tab at the edge so you can play with the Mipo while it stays open.
- Puppetmaker 2's drawings: the paper panel is the card, taped strips hold the sliders, paint blobs
  and pattern circles as they were; the three tab pictures go unused (or one heads the card).

## Steps

- [ ] **MM1. Open and close.** A per-scene setting (`maker = true`, saved with the scene, a checkbox in
  world settings; off by default). In play mode a tap (not a drag) on a Mipo opens the card: the
  camera moves in, the card slides in, 'done' (or shrinking it to its tab) goes back. The Mipo stays
  live. The pointer doesn't reach the world under the card (`ui.blockRect`).
- [ ] **MM2. The catalog: controls as data.** `src/mipo-maker-catalog.lua`: per category its icon,
  camera focus (head / body / face), the Mipo parts a tap picks it by, its shapes, colour layers,
  patterns, its sliders (`path, min, max, step, iconLess, iconMore`), `dev = true` on dev-only rows.
  Writes go through the setters and rebuilds the editor's Mipo panels use, so both stay one path.
  (The idea of `src/ui/inspector.lua`'s declared params.)
- [ ] **MM3. The drawings in.** Puppetmaker 2's `assets/ui/` (panels, icons, interfaceparts,
  colorpick, circles, whiterects) to `textures/ui/maker/`; on the web and device ship lists
  (`claudetools/ship-list.py`).
- [ ] **MM4. The card** in `src/ui/maker/`: one component laid out from the screen size, not picture
  pixels: the category row (flick, tick), the shapes grid (flick), the colour and pattern rows, the
  folded tape strip with icon sliders, the shrink-to-tab. Flick scrolling is new to our UI.
- [ ] **MM5. Tap to pick.** In the maker a tap on a Mipo part picks its category (MM2's part list),
  a drag still pokes; the camera moves to body / head / face by category.
- [ ] **MM6. Part thumbnails.** Cells from `textures/mipo/<part>/` plus the mask tinted in the Mipo's
  colour; cached by picture and colour (a cache that levels off, CLAUDE.md).
- [ ] **MM7. First slice, Nikki judges:** the card + tap to pick + shapes and colours for body, eyes
  and hair. Keep, change or park?
- [ ] **MM8. The rest:** patterns, icon sliders in the fold, the other categories from the catalog.
- [ ] **MM9. Feel.** The growl through `src/mipo-voice.lua`, pitched by the value; clicks and ticks;
  the camera tween (DOLL-PLAY F3's tween layer: this is the real sequence it waited for); the
  picked wobble; dice for a part / the whole Mipo with E5's prefer-the-middle randomize
  (MIPO-EDITOR-LEFTOVERS.md).
- [ ] **MM10. Breeds in the card:** the breed picker (MIPO-BREEDS B5), breed from this (B6),
  families (B7) as whole-Mipo buttons.
- [ ] **MM11. Touch and sizes.** iPad landscape first, then the phone (`./playtime.sh device`): docked
  right or from the bottom, 3-4 shape columns. Bench a slider drag (`./playtime.sh bench device`):
  a rebuild per frame may need throttling.
- [ ] **MM12. New icons** for what Puppetmaker 2 never had: spine segments, haircut tufts,
  materials, facing, voice, breeds. Onto THINGS-TO-DRAW.md when MM8 shows which are missing.

## Open

- Which options are dev-only: decide per row while filling the catalog (MM2, MM8).
- What "a ship build" is for hiding them: the device and web builds, or a flag.
- On a phone: docked right or from the bottom (MM11).
