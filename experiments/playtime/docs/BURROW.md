# Burrow — an underground Mipo home you dig yourself

status: idea

**Nikki's favourites** (2026-11-04): of all the spikes (sea, clouds, burrow, materials, cellophane), the sea, the burrow and the clouds inspired her most. Hand-drawn assets come first from now on; these are where a shader earns its place.

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

The spike (2026-10-30, d045b154): `scripts/spikes/burrow.playtime.lua`, `./playtime.sh play burrow`.
Nikki: "feels nice", "pretty good already".

- A grid of densities (0 air .. 1 earth), drawn and collided with interpolated marching squares
  at 0.5 (the same idea as `../liquid` and `~/Projects/love/underground`).
- Cut into 16×16-cell chunks; each chunk is one static body with chain shapes along its outline,
  rebuilt only where a stroke touches it. A short stroke costs ~2 ms, a full rebuild 32 ms.
- A panel in play mode: dig / earth back (shift for the other one), brush 100-800, cell size
  15-120 (resamples what was dug; ~200 ms at 20), reset (earth + Mipos), new landscape.
- `script.call('drawBelow')` in main.lua: a scene script's ground draws under the bodies.
- 2026-11-03, the earth's look ("pretty good"): a shader works it out per pixel from where it is
  (the sand in the sea spike, `SEA.md`): topsoil, clay, deeper ground with wobbling edges,
  sediment bands, grain, fine roots near the top. The dug-out wall is the earth a metre further
  back: the same layers at the same depths, its own noise, darker. `t` toggles it off.
- Rocks: shader stones looked wrong ("the rocks need to be handdrawn"), so they're 70 shape8
  bodies with an OMP skin, borrowing the Mipo body outlines until rocks are drawn
  (`THINGS-TO-DRAW` A8). Kinematic while there's earth under them (no dragging them out), then
  a 0.7 s wobble and they turn dynamic and fall. Scene scripts get `fixtures` for this.

- **Depth** (2026-11-04): the grass on top a little 2.5D, as in the clouds spike (a band in Nikki's
  grass pattern with perspective, blades behind and in front), only where the top is still the
  landscape's: dig through it and the grass is gone. Underground, the back wall is further away
  (`tunnel`) and every edge of the earth is joined to it by a face, like a box cut out of the
  ground: floors lit, walls by how they face the light, ceilings darker; a face turned away lands
  inside the earth and is covered. Sliders: back, front, behind, infront, blades, tunnel.

## What could be next

- The look, after the picture: a hand-drawn rim, worms and bones in the earth for digging
  to uncover; drawn rocks in place of the borrowed outlines.
- Floors Mipos can stand on: curved floors over ~10° make them walk downhill
  (`WORLD-METRICS.md`). A flat-bottomed brush, or a tool that flattens.
- Small: leftover specks of earth, floating earth that could fall, a cell-size change can bury a Mipo.
- A place: a door on the grass that goes down (`WORLDS-AND-DOORS.md`), saving what was dug.
- Then water: the cellular water of `../liquid` on the same grid, buoyancy on the Mipos
  (`WATER.md`).

## diglive: the world answers the finger (2026-11-16)

`scripts/spikes/diglive.playtime.lua` (`./playtime.sh play diglive`), burrow's earth with a new finger. Nikki: burrow
felt boring, dig jobs not direct enough, plain finger digging "feels not nice"; after looking around (Sago Mini
Trucks and Diggers: dirt you move back and forth; Where's My Water: earth that resists; the shovel's sound in A Game
About Digging a Hole): "i like the feel".

- **The scoop:** digs in bites (a crunch each), slower the deeper (topsoil, clay, deep); what it digs it carries, a
  lump on the finger, until full. Let go: it pours out as clumps (Box2D), and a clump lying still turns back into
  earth (loose earth: digs soft), small pockets in a settling pile fill. Dig here, build a hill there.
- **The Mipos** look at the finger, walk over and reach for it, squeak when dug out from under.
- **The earth** crumbles where it's thin near the dig (a shake, a rumble, clumps).
- **Things to build with:** beams and toy blocks buried in the earth; dug free they come loose (their footprint dug
  out first: lying inside solid earth they fell through its edges). Tried and dropped the same day: plain planks
  ("a bit useless"), Fabuland's parts ("a bit much the big fabuland pieces"). More sky above the grass for towers.
- No rocks (the borrowed Mipo body outlines: not these).
- 2026-11-17, digging "really feels weak still": bigger bites, a scoop that holds 12, and each bite lands (chunks
  flung back, a dust puff, the ring kicking, a small camera knock, a thud under the crunch); while it waits for the
  next bite the ring squashes against the earth (harder ground, longer push).
- **Boards for straight walls** ("a thing you can hold against it"): a loose beam or block let go of against the
  earth sticks there (a press pulls it off); the scoop doesn't dig past it, poured dirt settles flat against it.
  Liked ("i like the sticks"). Tried and taken out the same day: strokes locking onto flat / upright / 45 degrees
  with square bites ("i dont like the locking angles").
- **Kinds of ground and a kiln** (2026-11-19, Nikki: "certain types of ground, say clay, sand and mud/dirt, each
  with different properties, dirt is good for growing stuff on, clay can be baked into bricks"; clay "in layers /
  pockets", "a kiln at the top surface where you can drop in your clumps"). Every place in the earth is dirt, clay
  or sand (its own 40 px grid, `c.mat`), drawn by burrow's shader from a small picture of it (burrow's new
  `opts.materials`; other scenes keep the layers by depth). A clay layer under the topsoil, clay and sand pockets,
  a sand band under the cave. Clay digs slowest and pours as heavy sticky clumps; sand digs fastest, its clumps
  slide, and it doesn't hold over a hole or past ~45 degrees (it trickles down near the dig). The lump on the
  finger shows what it carries, and settled clumps stay what they were. The kiln (left of the cave, on the grass):
  clay landing on it hisses in; every 10 clumps bake into a brick (1.6 s) that pops out over a rim, glowing and
  cooling, a piece like the blocks. Dirt and sand on it are flicked off (else they settled into earth on its rims).
  Not yet: anything growing in dirt.
  The same day, from playing it: sand ran away (160 clumps and ~300 waiting to crumble, 25 fps): settled sand
  crumbled again, every fall kept the dug place watched, and the clump cap turned the oldest clump into earth in
  mid-air. Now only sand that was there runs, the watched place lasts 6 s at most, and at the cap the oldest
  still clump settles (none still: the oldest goes). A loose piece with earth inside its edges is dug out (one
  block lying still in closed-in earth made ~400 contact calls a step: update 13 -> 3 ms). A NaN earth chunk is
  rebuilt (put back, its contact made it NaN again every step and the world paused).
- **Grass where the sun reaches dirt** (2026-11-19, Nikki: "grass on top of soil/dirt that is exposed to air and
  sun ... more dynamic"): each column's top, the first earth from the sky down, has grass if it's dirt (burrow's new
  `opts.grassOn`; mole and oaktree keep the old rule, grass near the first surface). A top that moves (dug, poured
  onto) starts bare and grows in over 8 s, blade by blade; no grass across a step. Kept per column and looked at
  only where a stamp changed something (before: every visible column searched from the sky down every frame).

## Parked: dig jobs (Mipos dig what you mark)

tried 2026-11-16: `scripts/spikes/digjobs.playtime.lua` (`./playtime.sh play digjobs`). Burrow felt boring
("nothing answers the dig"), so: the finger marks tiles, a free Mipo walks to the nearest one it can reach and
digs it bite by bite, only what it can touch from where it stands (it can't climb). It worked, but Nikki:
"finnicky and too systems like, also not direct enough". Marking and waiting took the dig away from the
finger; the tile grid and the Mipos giving up on tiles they couldn't reach read as a system, not a toy. Keep
the finger digging; if the world should answer, let it answer the finger directly.

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
- **On the burrow rim (2026-11-04): "as a spike it's promising".** The stroke pictures are in
  `textures/strokes/`. Three things needed changing:
  - The earth's edge comes in chains cut at chunk borders, so the wobble and width are read from
    the place in the world.
  - Sharp corners (over 55°) break the stroke into pieces that run on past the corner and taper
    (the dark notch is gone).
  - Which picture goes where comes from a world grid, starting exactly where the line crosses a
    grid line, so digging changes only the strokes near it. Before, the textures shifted along the
    whole edge.
  - Each edge loop in one fixed form before it's stroked (it starts at its top-left-most point
    and runs one way round; open chains from their top-left-most end): rebuilding a chunk could
    string a hole's edge together from another point, so digging near an unconnected hole
    changed its strokes.
  Keys: `o` the drawn rim or the plain line, `b` boil. Sliders: rim width, rim wobble. Left: a
  tunnel opening into another can still change a piece's strokes; boil isn't measured on a
  well-dug burrow.
- Next: on Playtime shapes (bodies, props).
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
