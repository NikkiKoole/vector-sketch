# Glass beads — Nikki's closed shapes as see-through glass

status: parked — kept as a spike: "very nice! love the glass", the laughing-mirror lens "nice" (tried 2026-11-04, scene `glass`)

`scripts/spikes/glass.playtime.lua`. Every bead is one of the drawn Mipo parts with an outline +
mask (bodies, patches, rings, a heart, 22 in all): the mask is the glass, the outline is drawn on
top in white. A hand-drawn shape with a shader for the one thing drawing can't do (light through
glass): a moment, not a material system (SHADER-LOOKS.md, parked).

## How it's made

- **Roundness from the mask**, baked once per picture on a ~96 px grid: average the mask per cell
  (some masks are painted with a grainy brush), fill small holes (big ones stay: a ring, the
  triangle frame), distance in from the edge, a pebble height (round at the rim, flat on top),
  blurred twice, a normal from it. A second, wide dome for the lens.
- **Behind the glass** is a screen-sized canvas: the wall, the shadows, the table, and the Mipos
  (drawBelow turns the canvas on and the game draws the bodies into it; draw puts it on the
  screen, then the beads).
- **The glass shader**: magnifies what's behind, most in the middle, and stretches it in bands
  along the bead (the laughing mirror: *lens*, *wave*, *waves*); the rim bends it more (*bend*);
  colour by thickness (*tint*); darker rim and a pale edge line; light gathered on the side away
  from the light; a sharp and a soft highlight from the top left; the middle partly see-through
  (*clear*). Optional: a Mipo-look pattern (`textures/pat/type*`) inside, under the curve.
- **Shadow** on the wall in the bead's colour, *offset* away from the light.
- Beads are real bodies (the mask's convex outline, at most 8 corners).

## What's left, if picked up

- Beads don't bend beads behind them (a full-screen copy per bead; too much for the phone).
- A Mipo part baked mid-frame sets the screen back: that frame can flicker.
- Close up the glass gets blotchy (the 96 px bake, the grain coming through).
- The bake is plain Lua at first sight of a shape: bake all at scene start, or to files.
- Not measured: `./playtime.sh bench device glass`, with beads and with `g` (plain OMP).
