# A hand-drawn font — three drawings per letter

status: active

Nikki (2026-11-12): "fonts, that are handdrawn, say 3 glyphs per glyph, any ideas?"; for signs and titles
first, "but its just an idea at this point". Nothing on hand-drawn fonts tried before (`./playtime.sh tried font`:
only the editor's Comic Shanns, said no 2026-10-27).

## The software route first (built 2026-11-12)

Nikki: "before all this, can we try an all software route, take a font, say comicsans, you try to follow (aka
draw) each glyph (three times)". Before printing a sheet and drawing 120 letters, a font redrawn by the computer:

- `claudetools/lettering-forge.py`: Comic Sans MS's outlines, each followed with a wobbling line (a slow drift
  and a smaller tremble, pushed in and out along the line), the letter a little turned, stretched and shifted;
  three tries per character, printable ASCII + a few accents, 312 drawings -> `textures/lettering/comic.png`
  (2048 x 1819, em 160 px) + `comic.lua`. A quicker tremble looked like torn paper, so it's small.
- `src/lettering.lua`: `lettering.draw(text, x, y, { size, boil, jiggle, seed, align })`. A letter's drawing
  is picked by its place in the text; the same letter right after itself always gets another one. Boil (fps):
  every tick each letter goes round its three in its own order, out of step with its neighbours. Each
  drawing has its own little tilt and bounce (jiggle).
- `scripts/spikes/lettering`: a line, a title, a sign, the alphabet; panel for text, size, boil, jiggle, seed;
  v shows the atlas. `spec/lettering_spec.lua` checks the picking (`LETTERING_PNG=<path>` writes a picture).

- [x] LF1. Nikki looks at it in the spike: the wobble right? boil speed? Keep, change or park? Kept as it is
  (2026-11-12: "its fine like this for now").
- [x] LF4. Looks, as an option and tweakable (Nikki: "some pixel joy with them, like a pseudo 3d graffiti
  outline ... as an option, tweakable"): `scripts/spikes/lettering-looks.lua`, graffiti, candy, chrome, magnet,
  gold, toxic; each a gradient face with a bevel, a band, a thin line, an extruded block, a drop shadow,
  sparkles. Canvases (mask, band, rim) stamped in rings, the block swept a pixel at a time. Sliders: band,
  line, depth, angle, bevel, shadow, sparkles, hue (turns all its colours). l in the spike.
- [ ] LF2. If kept: where it's used first (a sign in a room, the scene titles), and whether it ships with
  every build (it's named in src/, so ship-list packs it: ~360 KB a font, three now)
- [x] LF3. Other fonts through the forge: Windsor (WindsorBT-Roman.otf) and Cooper Bold
  (assets/cooper_bold_bt.ttf, the fridge letters), `textures/lettering/windsor.*`, `cooper.*`; f in the spike.
  Comic Sans MS Bold too (`comicbold`, 2026-11-12).
  Next maybe: a rounder one, (a rounder one, or Nikki's own drawn alphabet when the sheet route
  happens): `--font`, `--name`

## What the three versions are for

- **No two letters the same**: the version picked by the letter's place in the text (a hash), so "ll" or
  "aaa" never repeat one drawing and the text stays still frame to frame.
- **Boil**: or the versions swap a few times a second (on twos, 12 fps), like burrow's drawn rim; a setting
  on a piece of text (titles yes, long labels no).
- A little baseline wobble and tilt per letter on top, so repeats sit differently too.

## How it could be made

1. A template sheet to print: a grid, baseline and x-height in each cell, three cells per character. Drawn by
   hand, scanned.
2. A slicer in `claudetools/` (the scan2tex kind of job, ASSETS-AND-BUILDS AB1): each cell cut out and trimmed,
   its width and baseline measured -> one atlas + a metrics file.
3. Our own text drawer (LÖVE's ImageFont has one drawing per character): picks the version, lays out, draws
   in one SpriteBatch.
4. Start small, for signs and titles: capitals, digits, a few marks, ~40 x 3 = 120 drawings.

Other routes: each letter once as a vector line, drawn with `src/drawn-stroke.lua`'s crayon (less drawing,
generated variation: faithful drawings have won before, feedback "faithful over generated"). A Mipo script
(mipomi-lang) drawn the same way, for signs and speech bubbles, read as pictures by small kids.
