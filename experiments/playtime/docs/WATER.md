# Water in containers

**Parked (Nikki, 2026-10-29): "ok as an experiment, not too sure about all the water, leave it for now."**
W1 (level water + spilling) is built and tested; the grid-water experiment (`../liquid/`) is fixed and
drawn with marching squares. Nothing past that is started.

Cups, jugs and a bath with water that stays level, pours, sloshes and floats things.
The idea came from navkit's water and pressure (`HARVEST-NAVKIT-DREAMENGINE.md` 1c) and
dreamengine's `ripple.c`. Playtime's own scene scripts had already tried buoyancy (below).

**The rule everything hangs on:** a container holds an *amount* of water, and the surface
is always level in the world. Each frame the level is found where the part of the cavity
below it holds exactly that amount. Tilting a cup sloshes the water to the low side, and
the amount never changes unless something pours it.

## What Playtime already had

- `scripts/water.playtime.lua`: buoyancy by the **real submerged area**, `polygonClip` of
  each body against a water sensor, pushed at the centre of the clipped part. Weak spots: the
  force is `area x 2` (depends on pixel units), globals, damping set and never put back,
  polygons only (no circles), the water a fixed shape.
- `scripts/mudready.playtime.lua` (the Bathhouse spike): **mass-relative** buoyancy
  (`mass x g x submerged fraction x FLUID_DENSITY`, so 1 hangs still and more floats up; stable
  at any size), drag and angular damping that grow with depth, **splashes** (a crown of
  drops going in, a sideways spray coming out), a wave line of two sines. Weak spots: the
  submerged fraction is guessed from the body's height, the water is a flat rectangle, it
  pushes anything below the line even outside the tub, and it resets every body's damping to 0.
- W4 takes the submerged area from the first and the mass-relative force from the second; W3
  takes the splashes from the second.

## The grid-water experiment (`../liquid/`)

Nikki's port (January 2024) of W-Shadow's cellular water (`water.pde`/`compression.pde` sit next to
it). Each cell holds a mass: water falls, spreads sideways and settles flat, and a slightly
compressible column pushes water up the other side (U-tubes). Fixed and extended 2026-10-29:
- **Bugs:** four checks let water flow into rock. Three tested `.blocktype` (the field is `.type`)
  and one compared a cell table to a number.
- **Faster:** the sideways spread was 1/4 of the difference, then halved; now 1/4 un-halved, 8
  steps a frame. Before, a tap built a water mountain that never levelled.
- **Drawn:** interpolated marching squares, with samples at cell centres and the outline where the
  value crosses 0.5. One smooth flat-colour body of water with a light line where it meets air (not
  rock). Rock is drawn the same way. `THIN` makes a thin falling stream count as water when drawn.
- A noise landscape with a dip, a tilted ledge and a hanging lake, a tap (t), rain (a), brushes,
  and `--selftest` (pours for 100 frames, then lets it settle, screenshots at 80 and 400).
- About 3 ms simulation + 3 ms drawing for 96 x 60 cells.

It's the candidate for the puddle half of W2: what a cup spills becomes grid water that runs off and
pools. Static bodies would be stamped into the grid as rock.

## Build order

- [x] **W1. Level water** (2026-10-29). The LIQUID sfixture, `src/liquid.lua`:
  - On any body. The body is the container; a cup is a U-shaped custom polygon
    (`props.makeCup`, `props.makeBath`; toys 'cup' and 'bath').
  - The hollow is the body's **convex hull minus the body's own shapes**, so a drawn curved bowl holds
    water in its curve and the water never covers a wall (it's drawn with the body stencilled out).
    The mouth is whichever hull edge runs through air, not along the body. (First version: the body's
    bounds less a `wall`; a drawn bowl got a rectangle of water. Nikki's screenshot, 2026-10-29.)
    `extra.cavity` (body-local, first edge = mouth) still overrides it.
  - `fill` is the part of the hollow that's water. The level comes from
    `liquid.levelFor(hull, amount, holes)`: a binary search on `areaBelow` (the hull clipped below the
    line, less the body's shapes clipped the same way).
  - It's drawn as the water polygon (triangulated) plus a lighter line on the surface.
    'in front' draws it above the Mipos (the bath), at `liquid.FRONT_Z`.
  - **Spilling** (added after Nikki saw the water held in by an invisible lid when the cup tipped).
    The cavity's first edge is its mouth. While playing, `liquid.update` (in main.lua after the
    physics step) caps the amount at `liquid.capacity`, the part of the hollow below the mouth's
    lowest point, and lowers `extra.fill` to match. So a tipped cup keeps what's below its rim's low
    corner, and a cup on its side or upside down ends up empty. Paused, nothing spills, so rotating
    a cup in the editor keeps its water. For now the spilled water just disappears; W2 makes it a stream.
  - Inspector: fill, color, surface, in front, z offset. In the tool rail under attach → looks.
  - Test scene: `scripts/kitchen.playtime.json` + `.lua` (`./playtime.sh play kitchen`). It has a
    table with two cups, a bath on the floor, and one Mipo (copied from dollhouse).
  - Specs: `spec/liquid_spec.lua`. The pure part covers area, clip, level upright and tilted, and
    the cavity. The scene part loads the kitchen, lets the cups settle, tilts one, and draws.
- [ ] **W2. Pouring.** Mark the cavity's opening (its top edge). When the level rises above the
  opening's lowest point, the extra amount leaves from there as a stream of simple drops (no
  Box2D bodies). A drop landing in another cavity adds to its amount; one landing on the floor
  splashes and fades. Open: lost, or puddles you can mop up?
- [ ] **W3. Wobble and splash.** The surface as a row of ~12 springs (ripple in 1D). Moving or
  tilting the container excites it; things falling in make a ring. Splash particles from
  mudready.
- [ ] **W4. Floating.** In `src/liquid.lua`. Bodies overlapping the water (`queryBoundingBox`, not
  only ones with `ud.thing`) get `mass x g x submerged fraction x density` up, at the centre of
  the submerged part. They get drag by depth, and their own damping back when they leave. Blob
  rims (`state.blobRims[body]`, no userData) float per rim circle; tell playtime-ef when it lands.
  Forces can go in `liquid.update` (after the step): Box2D clears forces at the end of a step, so
  ones applied after it act in the next one.
- [ ] **W5. Cause and effect.** A tap (a stream switched by `signals.lua`), a plug, a float switch
  (level -> signal, like navkit's pressure light), and `thing.wet` (darker, drips; a hook for
  navkit's materials later).

## Notes

- Containers: Playtime's custom polygons may be concave (`shapes.lua` decomposes them), so a
  U-shaped body collides like a cup without extra work.
- A Mipo made fresh with `createCharacter` and saved straight away isn't round-trip stable:
  its part sfixture ids change on every load (the `io_spec` double round-trip caught it while
  making the kitchen scene). Mipos in saved scenes (dollhouse) are stable, which is why the
  kitchen's Mipo was copied from dollhouse. Not looked into further.
