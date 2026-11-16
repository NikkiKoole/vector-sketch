# Sand — a falling-sand toy with Mipos in it

status: idea

A powder toy (sand, water, oil, stone, wood, fire, lava, steam) in a box, with Mipos in it. It grew from
the dreamengine `sand` cart (`~/Projects/dreamengine/tools/carts/sand.c`, see `HARVEST-NAVKIT-DREAMENGINE.md`).

## Where it is now

The spike (2026-11-16): `scripts/spikes/sand.playtime.lua`, `./playtime.sh play sand`. Nikki: "interesting", not sure yet what to do with it.

- A 300×170 grid, 16 world units a cell (a Mipo is ~40 cells tall), one pixel a cell, drawn nearest.
  Each cell makes one local move a frame, scanned bottom-up with alternating sides. Sand piles, liquids
  find their level (oil floats on water, sand sinks through both), gases rise and fade, and steam
  rains back down as water. Fire climbs, lights oil quickly and wood slowly (wood burns in place and
  leaves ash and smoke), and water puts it out as steam. Lava is thick, lights things and turns to
  stone in water.
- 16×16-cell chunks sleep while nothing in them moves. On the Mac it costs ~2-4 ms a frame
  (the panel shows it). Not measured on the phone.
- **The Mipos are in it through the physics:** every cell a body covers counts as submerged in what's
  there, which gives a lift (by the material's weight, at the centre of what's covered, so it rights
  them too) and a drag. Mipos float in water, sit in sand and stand on stone. Empty cells under a body
  can't be moved into, so sand piles up on a head. Inside a body's outline the cells are drawn again
  over it (sand nearly solid, water see-through) through a mask canvas of the body shapes.
- Play mode: drag to paint; a press on a Mipo still grabs it. The panel has the materials (keys 1-9),
  brush, drag and water lift. Keys: m a Mipo, r reset, c clear, space pauses the sand.

## What could be next

- Nikki plays with it: does painting feel good, which materials matter?
- The look: one pixel a cell reads like a 90s powder toy. Smoothed edges (marching squares, as in the
  burrow), a grain texture, or a shader per material.
- Mipos pushing grains aside (now sand stays inside a sinking Mipo; it's just drawn over it).
- Mipos getting wet or sandy (`DIRT.md`).
- The phone: SE 2 timing.
