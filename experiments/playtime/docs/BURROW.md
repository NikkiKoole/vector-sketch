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
One route: vector-sketch's own shaky border (`../../lib/border-mesh.lua`: a spline through the
points, evenly spaced, then `../../lib/polyline.lua:295-307` draws it with a random width).
`src/polyline.lua` is a copy of that file with the random-width mode taken out (unused then).
Other routes still to look at: a textured stroke along the outline (like the hair ribbons in
`src/render/ribbon.lua`), or a shader.

Colours: vector-sketch's `../../src/palettes.lua` has a `jamesGulliverHancock` palette (~90
colours), next to childCraft, quentinBlake, fabuland and others.
