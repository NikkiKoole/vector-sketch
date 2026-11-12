# A hand-drawn font — three drawings per letter

status: idea

Nikki (2026-11-12): "fonts, that are handdrawn, say 3 glyphs per glyph, any ideas?"; for signs and titles
first, "but its just an idea at this point". Nothing on hand-drawn fonts tried before (`./playtime.sh tried font`:
only the editor's Comic Shanns, said no 2026-10-27).

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
