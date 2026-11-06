# Tracks — pipes and rails through depth layers, a cart that carries Mipos

status: idea

A track that runs through depth: a marble or a cart rolls down a pipe, goes behind the house,
comes out in front, crosses itself on another layer. A Mipo rides along in a cart. It's a
knikkerbaan to watch (like the bike and the soapbox), and the bones of a roller coaster, a
buizenpost (pneumatic tube), a tube slide, a toy train, a spiral around a tree, a sushi belt.
From a talk Nikki had outside the repo (2026-11-06), checked against this repo.
Spike to build: `scripts/spikes/tracks`.

## The idea

- **Depth layers as collision categories.** A handful of layers, each its own Box2D category.
  Depth only decides draw order and size; under the hood it's all 2D.
- **A track is a pipe of two walls in one layer**: two chains, offset either side of a centre
  line. Where the track crosses itself on another layer the walls overlap on screen but never
  touch, because the categories don't collide.
- **Changing layers without a jump.** At a transition both layers' walls run side by side for a
  short stretch, in the same place. Somewhere in that stretch the moving body's filter switches
  from layer A to B. Physically nothing happens: same position, same speed, it keeps rolling.
  Only the drawn depth eases from A to B over the stretch.
- **Arc length is only for drawing.** The track's centre line keeps its arc length (as in
  achtbaan). The nearest arc position gives depth (draw order and size) and how far into a
  transition a body is. Physics stays fully Box2D: gravity pulls things down the pipe; a
  buizenpost's suction is a force along the pipe.
- **The cart is the only thing that touches the track.** Riders are jointed to it and their
  mask ignores the track, so they never catch on a pipe wall; cart and riders share a negative
  group so they don't collide with each other. Only the cart switches layers; riders are drawn
  at the cart's depth, so a Mipo is never split across two layers on screen.
- **The cart drawn as a 3D box.** Box2D keeps a flat box; the drawing is a box turned in 3D:
  forward in the plane from the body's angle, into or out of the screen from how fast the
  track's depth changes there, and a roll per track point (banking, corkscrews; replaces
  achtbaan's `flip`). Project the 8 corners like the layers (smaller toward the back), draw the
  faces that face the camera, back to front. Riders stay flat puppets anchored to the projected
  seat: a paper theatre, which suits the cut-out look. Accepted mismatch: a cart turned toward
  the back is drawn shorter but its Box2D box isn't; only loose things hitting it notice.

## Corrections for this repo (LÖVE 11.5 = Box2D 2.3, not v3)

The talk assumed Box2D v3 (`b2Shape_SetFilter`, `b2Body_SetBullet`, one-sided chains). Here:

- Filters are `fixture:setCategory / setMask / setGroupIndex / setFilterData`; `body:setBullet`.
- **Chains collide on both sides** in 2.3, so a pipe is just two chains: no winding to get right.
  Tunnelling is still real: `setBullet` on marbles and the cart, walls not too thin, and a pipe
  wider than the body by a margin.
- **Don't switch a filter inside a contact callback** (the world is locked). Decide the switch
  in update, after `world:update`. Better still, decide it from the arc position (below), not a
  sensor.
- **16 categories**, and `src/hair-tufts.lua` already takes 16. Five layers fit; reserve them
  in one place.
- A **soft weld is only soft in its turning** (SOAPBOX.md tried list): at the hips it sways but
  doesn't bob. The soapbox seats its rider on a wheel joint (`soapbox.playtime.lua:279`); reuse
  that.
- Breaking a rider out: `joint:getReactionForce(1 / dt)` above a threshold, then destroy it.

## Choices for the spike

- **Switch by arc position, not a sensor.** We compute the nearest arc position anyway for
  drawing; past the middle of a transition stretch the cart is in layer B, before it in A. That
  also works when it rolls back, which a one-shot sensor gets wrong. The switch point sits where
  only the pipe's inside overlaps the new layer (nothing of B's walls touches the cart then).
- **One track primitive: a channel.** The cart runs between both walls (wheels or a low-friction
  rounded box held top and bottom), so loops and upside-down stretches hold it without upstop
  wheels. A marble is the same with a circle.
- **The track as data first**: points with a layer, a roll and achtbaan's flags (accelerate,
  brake, hoist) in the scene script. Drawing tracks in the editor comes later, from achtbaan's
  drawing (`../achtbaan/main.lua`: `Track:addPoint`, `findClosestPoint`, flags toggled on points).
- **Drive by forces, not by setting speed.** achtbaan's hoist overrides the speed and
  accelerate/brake kick the acceleration once per segment (`Cart:update`, :338). Here a hoist is
  a force (or a motor) along the tangent up to a speed, boosters and brakes the same.
- **Runs on its own**, no buttons on screen (BIKE.md: "def no in game buttons"). Switches,
  sockets and dropping a Mipo in are things in the world, not UI.

## Where it touches

- `DEPTH-LAYERS.md` and the `depth` spike: lanes by `preSolve` (`instance.lane`, `state.drawSplits`,
  `state.passableBodies`). Track layers are categories instead; if both live in one scene, a
  track layer should map to a lane (back track = back lane) so the draw splits agree.
- `SOAPBOX.md`: the rider on a wheel-joint seat, rider muscles (aimed at fixed world angles, gentle:
  aimed at the cart's angle they rolled it over, at standing strength they braked it), ballast.
- `BIKE.md`: the lift that carries the vehicle back to the start, the rescue after 8 s stuck.
- `EXPERIMENTS-HARVEST.md` #13 (rail ride): proposed a kinematic cart on achtbaan's arc length;
  this plan keeps the cart in Box2D and uses the arc length only for drawing.
- `LIGHT-AND-SHADOW.md`: projected shadows per depth (`projectedShadows.layers`).

## Steps (spike `tracks`)

- [x] **TR1. One pipe, one marble** (2026-11-06). `scripts/spikes/tracks` (`m` a marble, `r`
  start over): a closed glass pipe zigzagging down, then a riser back up. The centre line is
  pieces (lines, arcs of radius 200) smoothed and resampled every 15 px (arc length; nearest point
  searched around the last one); the walls are two closed chains offset 46 px either side, in
  track layer A's category (2; 2..6 reserved for track layers). Marbles (r 30, bullets) roll down
  by gravity. Instead of a separate lift, the bottom bend, the riser and the top bend are a
  **hoist stretch**: a force along the pipe that cancels gravity there and pulls up to 700 px/s
  (a buizenpost). A marble stopped for 6 s outside it gets a push. Measured: 12 marbles for a
  minute, top speed ~1350 px/s, none out; all 12 thrown at 5000 px/s into a wall, none out
  (an escape is counted in `state.tracksSpike.stats` and printed). Not measured on the phone yet.
- [x] **TR2. Two layers and a crossing.** The track goes behind itself: layer B's stretch crosses
  layer A's on screen. A transition stretch with both layers' walls; the filter switches at its
  middle by arc position; the drawn depth (order, size, a little haze) eases across it. Check:
  rolling back through a transition, two marbles at once.
  Built 2026-11-06: the course is waypoints with rounded corners (radius 200; each stretch has a
  layer and maybe a hoist; a waypoint in the middle of a straight stretch changes layer there).
  The zigzag is layer A; the riser up through the middle (the hoist) and the way back over the
  top are layer B, so the riser crosses the zigzag three times. Walls are open chains, per layer,
  over every point that layer covers (its own stretches plus the transitions, 600 long). A marble
  takes its nearest point's layer after the step: its own category, every other track layer
  masked out. Drawn back to front per layer, B shrunk 16% toward a vanishing point and hazed;
  across a transition the pipe visibly bends away into the back (at 360 long it showed as a jog).
  12 marbles for 45 s: 73 layer switches, none out, top ~1390 px/s. Headless (a throwaway spec,
  `love . --specs`): a marble sent back up the bottom run at 900 px/s turned from B to A right at
  the transition's middle and rolled on in A; 12 marbles for two simulated minutes: 190
  switches, none out, top ~1460 px/s.
  A stretch must be longer than its corners take (~200 each for a right angle), or the arcs
  overlap and the walls fold (a Box2D chain assertion).
- [x] **TR3. The cart.** A box in the channel (wheels on both walls or a rounded slider), bullet,
  ballast, switching layers like the marble. Loops and a drop. Hoist, booster and brake as forces.
  Built 2026-11-06 (`c` a cart): a box on four wheels on revolute joints, two on each wall with 3 px
  of play (a bend widens the pipe along the cart's normal, so it never jams; the box never
  touches a wall). All its fixtures switch layer together. The pipe is wider (half 70). The
  course gets a drop and a **loop** at the bottom: it crosses its own way in, which only works
  with layers. The way in is A, the loop turns to B over its top, and the way out passes behind.
  Drives per stretch (forces at the mover's mass): `hoist` (cancels gravity, holds 700 both ways),
  `pace` (holds 2000 both ways, a coaster's tyre drive: on the run-in and up the loop's climb),
  `brake` (slows only, to 500, on the run-out). Waypoints can have their own corner radius.
  Measured headless (three simulated minutes): one cart and four marbles, 11 loops by the
  cart (a lap every ~16 s), none out, top ~2000 px/s; one cart and 13 marbles, 10 loops, none
  out, traffic queues at the loop but clears.
  Tried on the way: 200 px corners on the loop at ~2000 px/s (~10 g): the cart wedged sideways
  and everything piled up behind it (the loop is now a circle of 300). Light wheels under a heavy
  box let the joints stretch (wheels now near the box's weight). Marbles of radius 30 in the wider
  pipe wedged across it in pairs (now 40). A pace of 1750 only on the run-in: rolling marbles need
  ~1800 for the loop (spin takes some), rolled back and blocked the cart, and a bunched train
  stalled halfway up (now 2000, and up the climb too). The loop is drawn as a pear (its back half
  shrinks toward the vanishing point): TR5's depth should fix it.
- [x] **TR4. A rider.** A Mipo seated on the soapbox's wheel-joint seat, the track masked out,
  one negative group with the cart, drawn at the cart's depth and size. Loose shoulders; does
  the seat hold in a loop (stiffen at speed if it stretches)?
  Built 2026-11-06: every cart gets a Mipo (scale 0.15: about the cart's length standing, head and
  shoulders above the box sitting; 0.3 was twice the cart and hung off it). Its solid shapes add
  the track layers (2..6) to their mask: no pipe, marble or cart touches it, so it never switches
  layer. Not the soapbox's seat: in Box2D every U-turn turns the cart over (TR5d), so a seat on one
  side hung the Mipo under the cart after one. The hips sit on a **pivot at the cart's middle whose
  motor is a servo**: the torso, relative to the cart, to the track's `upright` (screen-up on
  ordinary track, toward the centre in a loop, rolled round in a U-turn). Legs forward from it
  (mirrored, and the Mipo turned to face the way the cart goes on screen), head and neck along it,
  arms loose. The cart weighs 4 riders (ballast).
  Drawn by the scene at the cart's depth: `state.sceneDrawnMipos` (an engine change in
  `src/physics/box2d-draw-textured.lua`) keeps them out of the world pass, and the scene draws each
  with `drawTexturedWorld(world, only)` (now in the script env) inside the cart's move and size.
  The pipe is in `state.passableBodies`, or the Mipo joint guard took it for a wall a limb was
  stuck through and ghosted limbs ([unstick] every few frames).
  Measured headless (with the joint guard, actions and muscles stepped as main.lua does): the
  torso within ~20 degrees of its aim most of the time, swinging further in the quick roll of a
  U-turn; two minutes, marble run 3 loops, coaster 8 (two carts), none out.
  Tried on the way: the torso's KEEP_ANGLE aimed at the up (on a pivot at its hip the joint took
  ~3/4 of each step's spin away: the torso lay flat in the cart); a standing Mipo's head and neck
  holding world-up pulled the torso back in loops; the servo at 4000 per unit of mass (LÖVE takes
  torque in px, divided by the meter twice: ~0.08 N m, nothing); a pivot with a little friction
  (fought the muscle); the cart at 4/3 and 2 riders' weight: the riders flailed the speed away and
  the coaster stalled after its loop. The coaster now has tyres into its loop and up the climb,
  lower crests (camelback 200, airtime 400) and tyres up the turnaround (two carts wedged there
  when one rolled back).
  Still open: riders aren't hazed at depth (the cars and pipes are); legs show over the box.
- [ ] **TR5. The cart in 3D.** The box drawn from the body's angle, the track's depth change and a
  roll per point; faces back to front, shaded from the scene light; the rider anchored to the
  projected seat. A banked turn and one corkscrew.
  The box is drawn, 2026-11-06 (done ahead of TR4, Nikki asked): a frame from the body's angle
  (forward), the track's depth change per px times `DEPTH_Z` (600 px a layer: forward tips into
  the screen where the layer changes), up made square to that, then the stretch's roll about
  forward (a waypoint's `roll = n` turns n times along its stretch: the way back over the top is
  a corkscrew, drawn only). The 8 corners go through the same shrink as the layers, read as a
  perspective with the eye `DEPTH_Z / DEPTH_SHRINK` in front of the vanishing point; a face is
  drawn when its normal faces the eye (a convex box, so the drawn faces never overlap), shaded
  by a light up-left and toward us; a stripe in the cart's colour on the sides; the wheels as
  discs on the far side under the box and the near side over it. Seen: flat on A the side and
  one end; over the loop's top it turns end-on into the screen; in the corkscrew the top and
  then the dark underside come round. Still open: a banked turn, the scene light (it uses its
  own), and the rider on the projected seat (after TR4).
- [x] **TR5b. A classic coaster course** (2026-11-06, Nikki: "more classically rollercoaster
  shape, another level"). `n` switches course in the `tracks` scene (the knikkerbaan, the
  coaster); `f` makes the camera follow the first cart (on for the coaster: it's ~10000 px wide).
  An out-and-back seen from the side: a station (tyres at 300), a chain lift (hoist at 450), a
  steep first drop straight into a loop (the loop turns to B over its top; its way out passes
  behind its way in), back to A for a camelback and an airtime hill, a turnaround up into C
  (furthest back) and home through C, behind everything, braked, lifted by tyres round a U-turn
  into the station. Courses carry their own vanishing point, camera and layer depths (the coaster's
  are 0 / 0.6 / 1.2: three layers at the knikkerbaan's spacing went too hazy); waypoints can set
  their drive's speed. Headless, two carts for four simulated minutes: 14 loops, a lap ~25 s,
  none out.
  Energy (logged as height minus v²/2g along a lap): the bends cost the most. The first drop's
  bottom corner at r 400 and ~2500 px/s lost ~600 px of height, the loop ~300, the hills ~170.
  With the loop after the hills, and the turnaround climbing 800 px, the carts rocked in a
  valley for good. Now the loop comes straight after the drop (as on classic looping coasters),
  the drop's bottom corner is r 700, and the turnaround and the way home stay low. The wheels'
  friction went down to 0.05 (they skidded each time the cart swapped walls), which wasn't the
  main loss. With 14 movers the knikkerbaan now makes 7 loops in three minutes (was 10), none out.
- [x] **TR5c. Gentler depth changes** (2026-11-06, Nikki: "smoother, slower, less jarring").
  Depth moved things toward the vanishing point as much as it shrank them, so far from that point
  a layer change slid the pipe hundreds of px across the screen over a short stretch (the
  coaster's turnaround: a wedge; the loops drawn as pears). Now depth shrinks sizes 16% per
  layer but moves positions only 5% (`DEPTH_SHIFT`): the pipe narrows around its own centre line,
  and the cart's 3D box keeps its full perspective around its own centre. Layer changes are
  900 px long (was 600; a course can set `transition`), eased with smootherstep (flat at both
  ends). Checked that no same-layer crossing falls inside the longer stretches. Both courses run
  as before (headless: the knikkerbaan 11 loops in three minutes, the coaster 14 in four, none out).
- [x] **TR5d. The cart the right way up; no colour steps** (2026-11-06).
  Nikki: "the cart is not always facing up (except in the corkscrew)". In Box2D the cart's up is the
  wall it rides on, and every U-turn in this side view (standing for a turn on the ground) turns
  that over: after one it rode on upside down, and the drawing showed it. Each track point now
  gets `upright`, a roll of 0 or pi (smoothed over 300 px either side) that brings the drawn up to
  screen-up on ordinary track and toward the centre in a loop (waypoints with `loop = true`), so a
  U-turn rolls it over gradually, and it's still upside down over a loop's top. On a vertical
  stretch it's on its side (a vertical track has no screen-up).
  Nikki (relayed): the colour stepped where a curve met the straights. Not the haze (that's per
  point already) but the drive tints (station green, lift yellow, brake red), each starting in one
  step: the glass tint is now blended along the track over 250 px either side. The rims were one
  line per run as thick as its deepest point, a notch where layers meet: now short pieces, each as
  thick as its own depth (the see-through glint stays one line per run: its pieces' overlaps showed
  as dots).
- [x] **TR4b. The rider faces the way the cart goes** (2026-11-06, Nikki: the facing experiment,
  docs/MIPO-FACING.md, "seems relevant here"). From the same 3D forward the cart is drawn with:
  how much it points to the rider's right on screen, cos(upright) / |(1, dz)|. Right or left going
  sideways on screen, **front** where the cart is end-on: the layer changes, the middle of a U-turn
  (reads as the turn on the ground it stands for), straight up the marble run's riser (a lift
  coming toward you). The face turns with it continuously (`instance._turnAngle`,
  `mipoFacing.applyFace`), the body switches in place at the thresholds (`switchFacing`, side above
  0.55, front below 0.3); facing front the legs hang straight down in the box (a front-on Mipo
  can't sit, MIPO-FACING). Headless, two minutes: marble run right 25% / front 25% / left 45% of
  the time, 23 switches in 3 laps; coaster 14 switches in 8 laps; leaning within ~10 degrees most of
  the time (front-on the legs no longer lever the torso). Not used: the facing spike's leaning foot,
  hop, autowalk and arm timing (feet in the box, arms loose); with MF6 the riders could use the
  promoted turning (head slower than the body).
- [ ] **TR6. In and out.** Drop a Mipo near a seat: it's seated. Pull hard: the joint breaks and the
  Mipo is back in the world with its own filter (flies off if the cart is fast).
- [ ] **TR7. Nikki plays with it**: keep, change or park? Then which contraption first
  (buizenpost, tube slide, train, spiral around a tree, sushi belt), and drawing tracks in the
  editor.

## Open questions

- Categories or `preSolve` lanes? Categories are cheap and simple for tracks; the `depth` spike's
  lanes have rules (one-way tops) that categories can't. Probably both: categories for tracks,
  lanes for Mipos walking about.
- How many layers, and how far apart in depth (size, haze)?
- Several carts in a train: joints between carts (a tow bar), each switching on its own.
