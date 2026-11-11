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

## Steps

- [x] **CO1. The track.** A `track` tool in the draw rail (next to freepath): drag to draw; smoothed
  and resampled; closes into a loop when it ends near its start. Shape type `track` with its chain,
  saved and loaded, cloned, picked by clicking near the line, points dragged. Drawn as two rails and
  sleepers. Crossings found, lanes and transitions laid out, contacts filtered by lane, movers'
  lanes kept. Check: balls and boxes roll along it and pass in front of and behind themselves
  without touching; a scene saved and loaded keeps it.
  Built 2026-11-11: `src/track.lua` (an engine system: movers' lanes in update, the back lane in
  drawBelow, the front lane in draw), `modes.DRAW_TRACK` (stays on for the next track), the chain
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
- [ ] **CO2. Swap a crossing**: tap a crossing in the editor to swap over and under; saved.
- [ ] **CO3. The cart and the rail lock.** Drop a cart on the track; it rides it, loops included.
- [ ] **CO4. Lift, boost, brake**: stretches of the track painted (achtbaan's zones), forces along it.
- [ ] **CO5. Riders**: Mipos seated in the cart (TRACKS TR4's pivot servo is a start).
- [ ] **CO6. Nikki plays with it**; then supports to the ground, the hand-drawn look, sounds
  (achtbaan's clacks and the crowd, dreamengine's `coaster` cart).

## Where it touches

- `TRACKS.md` (the `tracks` spike, parked): what was tried with pipes, layers and a wheeled cart.
- `DEPTH-LAYERS.md` / ENGINE-MERGE EM8: back / play / front lanes for Mipos. A back-lane track should
  line up with the back lane there, so a Mipo behind the house walks behind the front track too.
- achtbaan (`../achtbaan/main.lua`) and dreamengine's `tools/carts/coaster.c`: drawing, zones,
  the arc-length cart, sounds; its review is dreamengine-studio issue #49.
