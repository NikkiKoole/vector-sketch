# Waterjar — particle water you tip and slosh

status: parked — kept as a spike: "pretty good experiment!" (tried 2026-11-06, scene `waterjar`); its pouring went into `seaside` (WJ4); on the phone it holds 60 fps at 1600 points (WJ3)

A spike (2026-11-06): dreamengine's `waterjar` cart (`~/Projects/dreamengine/tools/carts/waterjar.c`)
brought over. Water as ~1000 points that push each other apart (Position-Based Fluids, Macklin &
Müller / Ten Minute Physics), so a tank you swing throws a wave that climbs the far wall and folds
over. Nikki asked for it after remembering the cart ("a wave that really drops"). It's option 1 of
two; option 2 is in the checklist below.

Scene `waterjar` (`scripts/spikes/waterjar.playtime.lua`): a wooden tank on a stand, ~55% full, and
a crate. Play mode: a/d or left/right tip the tank, a drag that starts on no body stirs, space pours
at the mouse, m a Mipo, b a crate, r fill again, v points / water, h the panel (gravity, damping,
viscosity, cohesion, iterations, push, density, opacity).

How it's made:
- `src/fluid.lua`, the step in C (`native/desound/fluid.c`, in libdesound like cloth.c, linked
  into the iOS app the same way); the same step in Lua for the web and pure specs, with 350 points
  instead of 1600.
- The cart's numbers were tuned at h = 7 sim px; here every length is that times h / 7
  (h = 36 px, points ~22 px apart). Gravity is the world's.
- **The tank is a kinematic body**, turned about the middle of its floor. In the cart the jar
  stays put and gravity turns; here gravity stays down so Mipos and crates behave. A point that
  was inside the tank is kept inside in the tank's own frame (a box clamp, the cart's
  phys_bounds), so a fast swing can't push points through a wall.
- **Bodies and water push each other.** Box2D shapes near the water (circles and polygons, not
  sensors) push the points out; each point's change of speed goes back to the body as an impulse
  (`push`, `density` on the panel). Floating comes out of that without a buoyancy rule: in the spec
  a crate of density 0.3 floats, one of 6 sinks.
- **Drawing:** each point is a soft blob added into a screen canvas (red: water, green: fast
  water); a shader makes one body of water out of the sum: an ink line at the edge, deeper blue
  inside, foam only on the fastest water. The cart's metaball render, on the GPU.

Measured (`spec/fluid_spec.lua`, the Mac): C 1088 points 0.5 ms a frame; Lua 350 points 4.8 ms.

- [x] **WJ1. The spike** (2026-11-06): the tank, the C and Lua steps, bodies pushed both ways, the
  blob drawing, the panel; `spec/fluid_spec.lua` (calm and level at rest, stays in, the slosh
  climbs the wall, light floats and heavy sinks, for both steps).
- [x] **WJ2. Nikki plays with it** (2026-11-06): "pretty good experiment!", kept as a spike. Still to judge: how
  Mipos feel in the water (light ones get thrown far by a wave).
- [x] **WJ3. Cost on the phone** (2026-11-06, iPhone SE 2, `./playtime.sh bench device`): the C
  step is linked in and runs. 1088 points still: update 2.9 ms a frame (p95 4.3), draw 1.4 ms;
  sloshing: update 3.3 (p95 4.7, max 8.6); full at 1600 points, sloshing: update 3.7 (p95 7.7, max
  13.8), draw 1.4. A steady 60 fps throughout, no frame over 20 ms: the blob canvas is cheap
  enough. Not measured yet: the tank with Mipos in it (each Mipo adds shapes the points test).
- [x] **WJ4. Points only while water moves** (2026-11-06, in `seaside`): cups and the bath stay
  level LIQUID water; what pours out (SEASIDE SS2's spill hook) leaves the rim as fluid points
  (`h` 30, one fluid for the scene, `fluid.calibrate` since there's no tank to settle in). They fall,
  splash and puddle on the table and the sand (a flat `floorY` for the beach, which is a chain
  shape the step can't see), join a cup or the bath they land in, join the sea, and a still point
  soaks away after ~2.5 s. Drawn by seaside's own see-through stream shader. Nikki to judge.
