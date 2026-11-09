# Mipo maker — Puppetmaker 2's dress-up screen, in Playtime

status: active

**Started:** 2026-11-09. The editor's Mipo panel (`src/ui/mipo/`) stays: it is the developer's tool,
reaches everything, accordions and numbers, mouse first. The maker is for kids playing: tap a Mipo,
change it with pictures, sounds and a few icon sliders, on a phone or an iPad.

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
drawings and the feel, not the code.

## Steps

- [ ] **MM1. Open and close.** A per-scene setting (`maker = true`, saved with the scene, a checkbox in
  world settings; off by default). In play mode a tap (not a drag) on a Mipo opens the maker: the
  camera moves in, the panels slide in, 'done' goes back. The Mipo stays live. The pointer doesn't
  reach the world under the panels (`ui.blockRect`).
- [ ] **MM2. The catalog: controls as data.** `src/mipo-maker-catalog.lua`: per category its icon,
  camera focus (head / body), its tabs, its children, its sliders (`path, min, max, step, iconLess,
  iconMore`), and `dev = true` on the dev-only ones. Writes go through the setters and rebuilds the
  editor's Mipo panels use, so both stay one path. (The idea of `src/ui/inspector.lua`'s declared params.)
- [ ] **MM3. The drawings in.** Puppetmaker 2's `assets/ui/` (panels, icons, interfaceparts,
  colorpick, circles, whiterects) to `textures/ui/maker/`; on the web and device ship lists
  (`claudetools/ship-list.py`).
- [ ] **MM4. Widgets** in `src/ui/maker/`: the endless icon strip (flick, tick), the paper-tab panel,
  the icon slider, the flickable grid, colour blobs, pattern circles, material balls (MT6's).
  Laid out from the screen size, not picture pixels. Flick scrolling is new to our UI.
- [ ] **MM5. Part thumbnails.** Cells from `textures/mipo/<part>/` plus the mask tinted in the Mipo's
  colour; cached by picture and colour (a cache that levels off, CLAUDE.md).
- [ ] **MM6. First slice, Nikki judges:** MM1 + the strip + the **part** tab for body, eyes and hair.
  Keep, change or park?
- [ ] **MM7. Colours, then icon sliders, then patterns**, the other categories from the catalog.
- [ ] **MM8. Feel.** The growl through `src/mipo-voice.lua`, pitched by the value; clicks and ticks;
  the camera tween (DOLL-PLAY F3's tween layer: this is the real sequence it waited for); the
  picked wobble; dice for a part / the whole Mipo with E5's prefer-the-middle randomize
  (MIPO-EDITOR-LEFTOVERS.md).
- [ ] **MM9. Breeds in the maker:** the breed picker (MIPO-BREEDS B5), breed from this (B6),
  families (B7) as maker buttons.
- [ ] **MM10. Touch and sizes.** iPad landscape first, then the phone (`./playtime.sh device`).
  Bench a slider drag (`./playtime.sh bench device`): a rebuild per frame may need throttling.
- [ ] **MM11. New icons** for what Puppetmaker 2 never had: spine segments, haircut tufts,
  materials, facing, voice, breeds. Onto THINGS-TO-DRAW.md when MM7 shows which are missing.

## Open

- Which options are dev-only: decide per row while filling the catalog (MM2, MM7).
- What "a ship build" is for hiding them: the device and web builds, or a flag.
