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
  (`scripts/platforms.playtime.lua`, `preSolve`).
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
