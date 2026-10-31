# Fabuland — chunky parts that click together

status: parked — "pretty nice", left as a spike in its own scene (`fabuland`): "got me thinking" (2026-10-31)

**Started:** 2026-10-31 (spike). Grew out of `WORLD-BUILDING.md` 1f. Pictures behind it: Fabuland
window and door blocks, shingle roofs, stairs, the slide, the Town Hall (`INSPIRATIONS.md`).

**Goal:** big solid parts you stack quickly into a house, a tower, a town hall, for Mipos to stand
on, climb and play around. They click the moment they touch the right spot and land square; the
finished thing is ordinary physics again (knock out the bottom and it comes down).

## The machine (how to add a part)

Everything lives in `src/fabuland.lua`, and **one entry in `PARTS` is a whole part**:

```lua
{ name = 'arch window block', w = 750, h = 1000, shape = 'rect',
  snaps = { 'top', 'bottom', 'left', 'right' }, sets = { 'yellow', 'red', 'blue' },
  details = { 'archWindow', 'studs' } },
```

- **size** `w`, `h` in world units, on the **250 grid** (a block is 750 × 1000: 3 × 4 cells; a Mipo,
  median 658 tall, fits under it, `WORLD-METRICS.md`)
- **shape** `'rect'`, or vertices around the box's centre (a roof is a triangle, the stairs a
  staircase outline)
- **snaps**: the box edges that snap. Snap points go at the centres of the grid cells along each,
  counted from the edge's start, so two parts whose edges sit on the grid have points on the same
  spots. They're *stiff* (`snap.addPoint(..., stiff)`): two stiff points weld instead of hinging,
  the weld turns the part to the nearest quarter turn, and they click in from 120 away
  (`snap.stiffDistance`; other snaps need 40)
- **sets**: colour sets (`SETS`: a body colour and a trim colour for frames and doors); a new part
  gets one at random. Colours in `COLORS`
- **details**: drawers from `DETAILS` (round / wheel / arch window, door, studs, shingles, railing),
  drawn in the box's space and clipped to the outline

From the entry follow: the body (objectManager, saves with the scene), its label
`fab:<part>:<set>` (how the look is found after a load), the snap points, the look (`fabuland.draw`,
called in `main.lua` behind the Mipos, only while `state.fabuland.on`) and a button in the
`fabuland` scene's panel (`scripts/fabuland.playtime.lua`). Spec: `spec/fabuland_spec.lua` builds every part in `PARTS`, so a new entry is
tested by being there.

**A new detail** (a chimney pot, a clock, a balcony door) is a function in `DETAILS`:
`function DETAILS.clock(w, h, bodyColor, trim) ... end`, drawing with `love.graphics` around (0, 0).

**Gotcha:** a custom shape's `thing.vertices` are the *world* points it was made from (its body sits
on their centroid); a rectangle's are body-local. `localOutline` handles both: use it, not
`thing.vertices`, to draw.

## Where it stands

**To try it:** `./playtime.sh play fabuland`: a Mipo, a wide floor, a house of four blocks with a
roof, stairs, a railing and a plank; the panel makes any part. It's a spike, kept out of the
app: no toys-shelf buttons, and the drawing runs only in that scene. To bring it into the app,
put the parts back on the toys shelf (`src/toys.lua`, one line looping over `fabuland.PARTS`) and
turn `state.fabuland.on` on for every scene (or drop the check).

- [x] **F1. The machine and a first set** (2026-10-31): window blocks (round, wheel, arch), door
  block (door drawn open), block, half block, roof left/right (shingles), stairs, post, plank,
  railing. Stiff welds, square. Drawn flat: fill, trim, a dark outline, studs along a block's foot.
  Tried in spine-test: a house of four blocks and a roof, built through the bridge.
- [ ] **F2. Feel it in the hand.** Build with the toys shelf and drag in play mode: does it click
  right, is 120 too far or too near, do welded stacks wobble (Box2D welds are a little soft in long
  chains), does dragging one part break it off when you mean to move the whole house
  (`state.snap.jointBreakThreshold`), can a Mipo stand on a roof terrace and walk the stairs.
- [ ] **F3. The crayon outline** from `../drawn-outline/` instead of the plain dark line
  (`BURROW.md`: "pretty nice"). The parts' outlines are simple polygons, which it handles.
- [ ] **F4. Parts that move:** the door swinging on a hinge snap (a separate leaf, revolute), the
  windmill's sails, a well's winch. Then the door block as a real door into a room (`src/doors.lua`,
  W1), which pulls in `WORLDS-AND-DOORS.md` W2.
- [ ] **F5. More from the pictures:** the slide with a snap at its top (`props.makeSlide` exists),
  balcony railing with a gap, chimney, the lollipop tree, the parasol, the clock, a back panel
  between posts (drawn behind Mipos, not solid), the car chassis (the snap cart is close).
- [ ] **F6. Drawings on top:** window frames, roof tiles, a door handle as Nikki's own pictures,
  part by part, once it's clear which parts stay.

## Known limits (spike)

- `fabuland.draw` walks every body in the world each frame and reads its label: fine for a room,
  but on the phone cache the list (the registry's version, as `omp-bake` does).
- Parts spawned overlapping are pushed apart hard and can fly off (seen while placing the kit).
- The scene is spine-test's copy; the kit (and its `fab-ground`, 3100–10100) is built by the
  script when there are no parts, so a saved scene with parts keeps its own.
