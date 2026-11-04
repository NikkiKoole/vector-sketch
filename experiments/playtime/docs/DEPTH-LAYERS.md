# Depth layers — back, play, front

status: idea

**Started:** 2026-10-31, from the Fabuland parts: a door block is a solid body, so a Mipo can
never reach its door; it's walled in. In Box2D everything solid blocks everything, but a toy
house needs depth: Mipos walk *in front of* a wall with a door. Fabuland figures do the same:
they stand in front of the house, in its doorway, on its top.

**The idea:** every part or body has a **layer**, which says what it collides with and where
it's drawn. It's the same idea as parallax: some things are only there to look at.

| layer | collides with Mipos and toys | drawn | examples |
|---|---|---|---|
| **back** | no: Mipos pass in front | behind the Mipos, optionally a little parallax | window and door blocks, wall panels, a back fence, house fronts, hills, trees |
| **play** | yes, solid (today's default) | at Mipo depth | floors, planks, stairs, roofs to stand on, posts, ramps, toys |
| **front** | no | over the Mipos, optionally parallax the other way | a front railing, bushes, a porch pillar, a lamp post |

## The pieces

- **Back parts still stack and weld.** They only skip collisions with Mipos and loose toys, not
  with the ground or other building parts, so a house stays physics and can still be knocked
  over. Box2D does this per pair with a contact filter (back part with Mipo: no; with floor or
  another part: yes). `World:setContactFilter`, or `preSolve` disabling the contact
  (`src/physics/physics-callbacks.lua`).
- **The top of a back block is a one-way floor.** A Mipo walks in front of the window block,
  but can be set on its top or its roof: one thin solid edge, which you pass up through from
  below and stand on from above. The old `platforms` scene does one-way platforms already
  (`scripts/spikes/platforms.playtime.lua`, `preSolve`).
- **A door on a back block is a real door.** A Mipo stands in front of it; with the `DOOR`
  behaviour (`src/doors.lua`, W1), dropping one there takes it inside, into another room. That's
  Scarry's cut-open house and the worlds-and-doors idea in one.
- **Per part, not fixed.** A block can be back (a house wall) or play (a block to climb), switched
  on the part (an inspector row; saved with the body). A `PARTS` entry only gives the default:
  window and door blocks back; planks, stairs and roofs play.
- **Drawing.** Back is drawn before the Mipos' z-groups, front after them (the grass already
  draws a back and a front layer: `WORLD-BUILDING.md` open questions, `grass.FRONT_Z`).
  Parallax per layer is G4's slider.
- **All scenery, not only Fabuland:** hills, trees and clouds as back-layer decor with parallax.
  That's scrolling-world's lesson ("scenery doesn't need to be physics"), but here it can still
  become physics where it's played with.

- **A boat needs one too** (Nikki 2026-11-04, scene `boat2`: a boat of planks): the far side
  behind the Mipos (the far gunwale and railing, the cabin's back wall seen past them), the deck
  to stand on (play), the near railing in front. The spike fakes it per plank (a back / mid /
  front draw order, the back ones sensors), so a boat with real depth is a case for this doc.
  The `planks` treehouse does the same by hand (back wall, solid floor, porch railing in front).

## The spike (2026-11-04, scene `depth`)

Nikki: "a good experiment" (2026-11-04); kept as a spike, the idea still open.

`scripts/spikes/depth.playtime.lua`: a toy house of chunky blocks, a porch, a picket fence,
crates, and Mipos in two lanes.

- **Blocks drawn with depth:** every block's front face is its body; its sides and top go back
  to a vanishing point near the top of the screen (sliders: depth, persp, horizon), so the house
  turns a little as the camera moves; `v` for oblique (a fixed slant) instead. All sides of a
  layer first, then all fronts, so a neighbour's side never lands on a front. Windows and the
  door are holes with a reveal (the wall's thickness shows on two sides). Light from the upper
  left. Front faces get the crayon outline (`drawn-stroke.lua`), the sides plain lines.
- **Layers in the physics** (`preSolve`): back blocks (walls, the floor between the storeys,
  the roof) let Mipos pass in front, and their tops are one-way floors: decided when the pair
  first touches (the Mipo's lowest point above the top there, not going up) and kept until they
  part. Play blocks are solid (porch floor, crates); front blocks (pillars, porch roof, railing,
  fence) never touch Mipos. Blocks only collide with blocks in their own layer. `k` makes the
  house loose; the porch and fence are welded together.
- **Mipos with depth:** a soft contact shadow on whatever is under them (a ray down from the
  torso), and **two lanes**: a back-lane Mipo walks on the path behind the house, drawn behind
  it and hazed, touching only the path, the ground and other back Mipos (`l` swaps the Mipo at
  the mouse). The world's draw is split between the lanes: a scene can set
  `state.drawSplits = { { z, fn } }` and `drawTexturedWorld` calls `fn` before the first drawable
  at that z; back-lane Mipos get z groups under the split, front ones `500 + n`.
- **Mipos with a body** (sliders `mipo depth`, its own apart from the house's `depth`; `round`, `roundSize`): each lane's Mipos are drawn
  into a canvas (the lane splits open and close it), then laid down with copies of it behind,
  each shrunk a little toward the same vanishing point as the blocks and darkened: a cut-out's
  edge going back, so a Mipo looks like a chunky wooden or cardboard figure. `round` is a shader
  on the real one: a warm light edge toward the light, a shaded edge away (the silhouette's
  alpha looked up both ways), so it reads a bit pillowy. Both act on the whole lane's
  silhouette, not per part (an arm in front of the body gets no edge of its own).
- **Engine bits it needed:** `state.drawSplits` (`src/physics/box2d-draw-textured.lua`);
  `state.passableBodies` so the joint guard doesn't take a static wall Mipos pass in front of
  for a wall a limb is stuck through (it ghosted limbs, which then fell through floors);
  `instance.lane` so two Mipos in different lanes don't count as knotted (untangle fired).

## Open questions

- In **play mode**, can back parts still be dragged and snapped (building while playing, as in
  Fabuland), or only in the editor? Building *is* playing in Fabuland, but a toddler could drag
  a whole house wall away by accident.
- Do loose toys (a ball) pass in front of back parts, like Mipos? Probably: everything that
  moves around is in play.
- Box2D categories (16 of them) vs a contact filter function: the filter is simpler and has room
  for rules (same building, static ground), but runs for every new pair of fixtures.

## Where it touches

- `FABULAND.md`: which parts are back by default, the door block, one-way tops
- `WORLD-BUILDING.md`: G4 parallax, 1e "scenery doesn't need to be physics"
- `BUSYTOWN.md`: cut-open buildings, a door into every building
- `WORLDS-AND-DOORS.md`: a door block is a door into a room
- `DOLL-PLAY.md` R5: stacked rooms and one-way floors between them
- `SCENES.md`: the `platforms` scene, kept for its one-way floors
- the `boat2` and `planks` spikes: back / mid / front by hand, per plank
