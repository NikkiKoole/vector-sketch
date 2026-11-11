# Coaster — draw a track in the editor, ride it

status: active

A roller coaster (an achtbaan) built into playtime: you draw the track like a freepath, it's a
real thing in the scene (saved, edited, copied), and real Box2D things ride it. First the track,
then a cart, then riders. A knikkerbaan (balls rolling down it) comes for free on the way.

Nikki 2026-11-11: "a way of building an achtbaan in playtime, basically drawing like a freepath,
lets first get the track under our belly"; not a fan of the `tracks` spike (TRACKS.md): "no glass
pipe, just a track/rails, i didnt like the fakeness of the depth change with another box2d
representation"; "real box2d but some special thing to make this easier"; "i want to have solved
the 3d layers, go in front or back yourself".

## The ideas

- **The track is a shape type, `track`**: a static body whose one fixture is a Box2D chain along the
  drawn line. `thing.vertices` is the centre line (smoothed, a point every ~20 px); `thing.track`
  keeps the rest (`closed`, the crossings' over/under choices). Saved and loaded like any body (the
  chain as `fixtureData.chain`; a loop repeats its first point at the end), cloned through save data,
  points dragged with the custom-polygon vertex editing.
- **Depth is draw order and who touches what, never size.** The `tracks` spike drew back layers
  shrunk toward a vanishing point while their Box2D walls stayed where they were: what you saw wasn't
  what was there. Here physics and picture stay in one plane. Every track point has a lane, front or
  back. Where the track crosses itself the front stretch is drawn over the back one (a knot drawing,
  a coaster in a picture book), and the two never touch: a contact between a mover and a chain edge
  of the other lane is switched off in `preSolve` (by the edge's child index, so one chain serves both
  lanes, no doubled walls). Depth cues that stay honest: the back stretches darker, the near rail over
  the rider and the far rail under it later.
- **Lanes come from the crossings.** Draw the line; every place it crosses itself is a crossing, the
  stretch drawn later goes over. Tap a crossing (later: in the editor) to swap. Between two crossings
  that want different lanes the lane changes halfway, over a **transition** stretch whose edges carry
  both lanes, so whatever rolls there keeps its floor while it changes lane. Nothing moves on screen.
- **Movers take the lane of where they are.** A body touching a track with no lane yet takes the lane
  of the edge it touches; then each frame its lane is the lane of its nearest track point (searched
  around the last one, so at a crossing it doesn't jump to the other stretch). Away from the track for
  a while, it lets go of the lane.
- **The cart: real Box2D plus a rail lock** (step 2). A dynamic body; after each step it's put back on
  its rail: its place along the track found, moved onto the line, turned along it, and only the
  velocity along the track kept. A joint that slides along a curve, which Box2D doesn't have. Loops and
  upside down just work, with no upstop wheels or pipe walls (the `tracks` spike's cart wedged in
  them). Lift, boost and brake are forces along the track; derailing is a choice for later.

## The scene

`coaster` (scripts/spikes): a station, a drop, a loop (r 260), two hills and a ski jump, drawn as one
track, and a cart (a RAIL_CART box). It plays by itself: the cart waits at the station, gets a nudge,
makes the loop on gravity alone, flies off the jump and is put back at the station (also when it's stuck
on the rail). `r` back to the station, `f` follow the cart. Made by a throwaway headless run that rode
the course before writing the file (the bridge's eval stopped at its instruction limit on it).

## Steps

- [x] **CO1. The track.** A `track` tool in the draw rail (next to freepath): drag to draw; smoothed
  and resampled; closes into a loop when it ends near its start. Shape type `track` with its chain,
  saved and loaded, cloned, picked by clicking near the line, points dragged. Drawn as two rails and
  sleepers. Crossings found, lanes and transitions laid out, contacts filtered by lane, movers'
  lanes kept. Check: balls and boxes roll along it and pass in front of and behind themselves
  without touching; a scene saved and loaded keeps it.
  Built 2026-11-11: `src/track.lua` (an engine system: movers' lanes in update, the back lane in
  drawBelow, the front lane in draw), `modes.DRAW_TRACK` (off after one stroke, like freepath: left on, it swallowed every click), the chain
  saved as `fixtureData.chain`, `thing.track` through save, load, clone and recreate. The stroke gets 3
  rounds of Chaikin and a point every 20; near a crossing (110 along the track) an edge is solid for
  its own lane only, elsewhere for both; the drawn depth eases over 160 either side of a lane change
  (the back hazed, the same size). Each lane's rails and sleepers are one mesh with colours per vertex.
  `contact:getChildren()` counts chain edges from 1 (`spec/track_spec.lua` checks it).
  Live (a figure-eight loop, 192 points, one crossing): a ball rolled down the front stretch through
  the crossing and a ball down the back stretch through it, neither caught on the other's rail; saved
  to JSON and loaded back the same. Balls sit on top of the rail, so where the track turns under
  them they fall off (real; holding on is the cart's job, CO3). Not yet tried by hand with the mouse.
  Still open: the front lane is drawn over all bodies (also Mipos walking in front of the track, not
  on it), until the lanes meet EM8's; the editor's cyan debug line draws over the rails.
- [x] **CO2. Swap a crossing**: tap a crossing in the editor to swap over and under; saved.
  Built 2026-11-11: a selected track shows a marker on each crossing (a ring, the front stretch drawn
  through it whole, the back one broken, as in a knot drawing); a click or tap on it swaps
  (`track.crossingAt` / `flipCrossing`, kept in `thing.track.flips`, nothing kept when swapped back).
  Found on the way, from Nikki trying CO1: the track tool stayed on after a stroke and turned every
  click into a too-short track; box selection took a track as inside any box (a chain gave it no
  points). Both fixed. Not yet clicked by hand.
- [x] **CO3. The cart and the rail lock.** Drop a cart on the track; it rides it, loops included.
  Built 2026-11-11: `src/rail-cart.lua` and the `RAIL_CART` behavior (any body: give it the behavior,
  let it go near a track while the world runs). Locks onto the nearest track within its half height
  + 30, on the side it was dropped on; after every physics substep (`main.lua`'s loop: between
  substeps it would fly straight) the change in its velocity along the track is kept, the rest goes,
  and it's moved on along the line by its speed, turned along it, given the matching spin. Picked up
  by the pointer, it lets go; off an open end it flies on and doesn't lock on again until it has been
  clear of every rail. Locked carts touch no rail (track preSolve), so crossings don't matter to them.
  Drag: 0.03 of the speed per second, plus air drag with speed. `railCart.setSpeed` for launches.
  Measured (`spec/rail-cart_spec.lua`): with no drag a cart climbs back to within 4% of its starting
  height over a valley; round a vertical loop (r 300, launched at 3000) upside down and out. Live: a
  drop of 700 into a loop of r 320 isn't enough (it climbs half way and rolls back, still on the rail:
  honest); launched at 2900 it goes over the top and on over two hills to the end.
  Found: the bridge's eval stops at its instruction limit when a stroke of ~400 points is made into a
  track in the same call (the crossing search is every edge against every edge, once per change).
  Not yet tried by hand: making a cart in the inspector, picking it off the rail.
- [x] **CO4. Lift, boost, brake**: stretches of the track painted (achtbaan's zones), forces along it.
  Built 2026-11-11 (Nikki: "we need to be able to draw / mark hoist, boost, brake, flip? from achtbaan").
  achtbaan marks points by holding h / a / d / f while drawing or tapping them over a point: hoist sets
  the speed to 100, accelerate / decelerate kick once per segment, flip swaps the cart to the other side
  of the rail (a 10 px offset). Here: a brush in the inspector of a selected track (lift, boost, brake,
  roll, clear), dragged along the track; the points get a character each in `thing.track.marks`
  (saved), the sleepers there are wider and in the zone's colour (lift yellow, boost green, brake red,
  roll pink). In `src/rail-cart.lua` as changes to the cart's speed along the track: a lift catches a
  slower cart and pulls it on at 260 (along the drawn way, so no rolling back), a boost pushes 900/s^2
  the way it's going, a brake slows 1400/s^2 down to a crawl of 90, never backwards (numbers at 100 px
  per metre). A roll (achtbaan's flip): over a painted run the cart turns round the rail, from on top to
  hanging under it (seen from the side: a corkscrew); every roll run passed is half a turn.
  Also from Nikki playing: a cart couldn't be put on her own track (the scene sent it back to the
  station whenever it was off a rail a moment). Now a cart's home is where it last locked on, it goes
  back there, `n` makes a new cart at the mouse, and the lock-on reach is half height + 70.
  Specs: a lift pulls a still cart up a slope at its speed; a brake slows to the crawl; a boost speeds
  up; a roll leaves the cart under the rail, upside down. Not yet painted by hand.
  Then (Nikki: "while dragging/drawing the track, if you could hold some keys to paint them live"): while
  drawing a track, hold h (lift / hoist), b (boost), s (brake / slow) or f (roll / flip), dreamengine's
  keys; the stroke shows the painted pieces thick in their colour, and after smoothing and resampling
  each point takes the zone at the same share of the way along. The coaster scene's follow key moved
  from f to v.
- [x] **Editing a track after drawing it** (2026-11-11, Nikki: "we need a way to add, remove, move points
  after the fact? also to connect the loop"). With 'verts unlocked': dragging a point bends the track
  around it (neighbours follow over 160 along it, eased off, measured where they were); `i` puts a point
  on the nearest edge, `d` takes away the nearest one, and the painted zones move with them (the polygon
  versions looked at an edge from the end back to the start, which an open track doesn't have). The
  inspector's 'close the loop' bridges the end back to the start with points and makes the chain a loop;
  'open the loop' opens it. Not yet tried by hand.
- [ ] **CO5. Riders**: Mipos seated in the cart (TRACKS TR4's pivot servo is a start).
- [ ] **CO6. Nikki plays with it**; then supports to the ground, the hand-drawn look, sounds
  (achtbaan's clacks and the crowd, dreamengine's `coaster` cart).

## Where it touches

- `TRACKS.md` (the `tracks` spike, parked): what was tried with pipes, layers and a wheeled cart.
- `DEPTH-LAYERS.md` / ENGINE-MERGE EM8: back / play / front lanes for Mipos. A back-lane track should
  line up with the back lane there, so a Mipo behind the house walks behind the front track too.
- achtbaan (`../achtbaan/main.lua`) and dreamengine's `tools/carts/coaster.c`: drawing, zones,
  the arc-length cart, sounds; its review is dreamengine-studio issue #49.
