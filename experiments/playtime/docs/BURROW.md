# Burrow — an underground Mipo home you dig yourself

status: idea

A side view of the earth under the grass: drag a finger to dig, the Mipos tumble into the
tunnels and live there. One verb (dig), like an ant farm. Water flowing in is the later payoff,
only once digging feels right.

## The picture

James Gulliver Hancock's *Underworld*: https://jamesgulliverhancock.com/projects/underworld/
(a traced copy from 2022: `resources/svg_to_love/molletjes.svg` in the vector-sketch root).
Legs walking on the grass, naked mole-rats in the tunnels, worms in a pale top soil, a potato
hanging its roots into a darker earth with bones and stones, soft pale tunnels between the layers.
Take the palette and the layering, not the drawing.

## Where it is now

The spike (2026-10-30, d045b154): `scripts/burrow.playtime.lua`, `./playtime.sh play burrow`.
Nikki: "feels nice", "pretty good already".

- A grid of densities (0 air .. 1 earth), drawn and collided with interpolated marching squares
  at 0.5 (the same idea as `../liquid` and `~/Projects/love/underground`).
- Cut into 16×16-cell chunks; each chunk is one static body with chain shapes along its outline,
  rebuilt only where a stroke touches it. A short stroke costs ~2 ms, a full rebuild 32 ms.
- A panel in play mode: dig / earth back (shift for the other one), brush 100-800, cell size
  15-120 (resamples what was dug; ~200 ms at 20), reset (earth + Mipos), new landscape.
- `script.call('drawBelow')` in main.lua: a scene script's ground draws under the bodies.

## What could be next

- The look, after the picture: a pale top soil over darker earth, a hand-drawn rim, worms,
  stones, bones and roots in the earth for digging to uncover.
- Floors Mipos can stand on: curved floors over ~10° make them walk downhill
  (`WORLD-METRICS.md`). A flat-bottomed brush, or a tool that flattens.
- Small: leftover specks of earth, floating earth that could fall, a cell-size change can bury a Mipo.
- A place: a door on the grass that goes down (`WORLDS-AND-DOORS.md`), saving what was dug.
- Then water: the cellular water of `../liquid` on the same grid, buoyancy on the Mipos
  (`WATER.md`).

## Parked: an interesting outline for any shape

Not just the burrow: a quick way to give any shape (a body, a prop, the earth) an outline that
looks drawn. Nikki 2026-10-30: the idea is good, not sure this route is it.

**Picked (Nikki 2026-10-30): a textured stroke + line boil as a toggle.**

**Tried (2026-10-30): `../drawn-outline/`**, random blobs, angular shapes and long planks
outlined with the crayon strokes below. Nikki: "pretty nice", "looks pretty good".
- Works: the stroke picture repeats along the outline (only its middle 80%, the ends fade); a
  wobble scaled to the shape's narrowest side (planks keep straight sides); tapered ends that
  overshoot where they meet; line boil at 10 Hz; misregistration; a pencil hatch over the fill.
- Hiding the repeat: each repeat picks another picture of its kind and may be mirrored or run
  backwards. Any `strokes/line*.png` (drawn upwards, ~500 px) or `track*.png` (sideways) joins
  the mix; Nikki will add a few lines of their own.
- Left: sharp corners fold the strip over itself (a dark notch); break the stroke there and
  start a new piece. The hatch shows vertical bands.
- Next: put it on the burrow rim, then on playtime shapes.
- The stroke: a triangle strip along the outline (like `src/render/ribbon.lua`) with a scanned
  line of Nikki's own (pencil, crayon, brush pen) repeating along its length, tapered ends, a
  little width change. Seeded per shape so it stays put.
- Line boil, switched on per shape: re-roll the wobble / texture offset 8-12 times a second, not
  every frame (the hand-animated "alive" shimmer).
- Try it on the burrow rim first: generated outline, no textures in the way.
- Strokes we already have (white crayon on transparent, tint them):
  - `textures/line1.png`, `line2.png` (66×486, 82×512): straight chunky strokes, rough
    edges. Start with these, laid sideways and repeated along the outline.
  - puppet-maker2 `assets/ui/interfaceparts/slider-track1.png`, `-track2.png`: a long thin
    crayon line; its end caps could be the tapered ends.
  - puppet-maker2 `assets/img/candyparts/*-line.png` (circle, rect, octa, capsule, ruit) and
    `assets/ui/colorpick/uiline.png`: crayon outlines of whole shapes, the look to aim for.
  - puppet-maker2 `assets/img/worldparts/ground3.png`, `ground52.png`: pencil and crayon
    hatching, for the earth fill rather than the rim.
  - More of Nikki's own scans (pencil, brush pen) only if we want other kinds of line.
- Maybe with it: misregistration (the fill a few px off its outline, like old print).

Considered and not picked: wobbly geometry alone (reads digital), stamped brush dabs, rough.js
double strokes, a screen-space edge shader (no per-shape control).

The old route: vector-sketch's own shaky border (`../../lib/border-mesh.lua`: a spline through the
points, evenly spaced, then `../../lib/polyline.lua:295-307` draws it with a random width).
`src/polyline.lua` is a copy of that file with the random-width mode taken out (unused then).
Other routes still to look at: a textured stroke along the outline (like the hair ribbons in
`src/render/ribbon.lua`), or a shader.

Colours: vector-sketch's `../../src/palettes.lua` has a `jamesGulliverHancock` palette (~90
colours), next to childCraft, quentinBlake, fabuland and others.
