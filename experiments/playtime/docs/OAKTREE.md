# Oak tree — Mipos at mole size, a burrow under one giant oak and treehouses in it

status: active

Nikki (2026-11-16): "imagine mipos being like mole, groundsquirrel size, a burrow we can dig, a large tree,
tree houses, slides, ladders, balcony, etc". Scene `oaktree` (`scripts/spikes/oaktree.playtime.lua`),
`./playtime.sh play oaktree`. At this size the oak is ~15 Mipos tall (WORLD-METRICS: real trees are 15-20),
so it's never on screen whole: keys 1-4 (or the panel) jump the camera to the burrow, the ground, the
treehouses and the top; right-drag pans.

## What's in it (2026-11-16, first pass)

Nothing new underneath; the spikes' parts put together:

- **The earth** is burrow's (`burrow.playtime.lua`, loaded with options: its own state `oakEarth`, a 20000-wide
  world, `hollow` for the rooms already dug, `surfaceAt`, `canDig`, `env` for the scene names it needs). Dug
  before they came: a molehill way in on the west, a den, a tunnel under the tree, a pantry, a back door up
  to an east molehill. Dig and fill as in burrow (its panel starts folded, bottom left).
- **The oak** is the bark spike's grower (`tree-grow`, oak, size 3.2, age 1.2, bark 16 'old mossy'), with two
  kinds of extra branches in the same bark: a nearly level **limb** out of the trunk's left (a static body
  along its top: Mipos walk on it) and eight **roots** flaring out of the trunk's foot over the grass and down
  through the earth (drawn only, over the tunnels). Leaves: a clump at every outer twig, a few in front
  away from the houses.
- **Treehouses** on three floors (L1 -2600, L2 -5200, L3 -7800), static planks with the crayon outline
  (`src/drawn-stroke.lua`, planks' look without its nails): floors solid, back walls with windows, roofs
  and braces to the trunk behind the Mipos, railings in front; an end post where a floor has no way off.
- **Ladders** (rig-zones' rung grip): grass to L1, L1 up through its house to L2, L2 to the crow's nest.
- **Slides** (rig-zones' chute): L1's balcony to the grass east (x 2400 to 7900 in ~4 s, tried), the crow's
  nest onto the limb, the limb's end to the grass west (tried: a Mipo on the limb walks off the end and slides
  down to x -9400).
- **One-way** (2026-11-16, Nikki: "places where i want to drag a mipo from the bottom of the platform"): the
  floors, the limb and the slides are in the back depth layer (`src/depth-layers.lua`): dragged up from below
  or off a ladder a Mipo passes through, dropped from above it stands. The end post stays solid (it stops feet).
  The roofs too (each slope one-way along its top plank): a Mipo stands on the ridge; on a slope (~28°) it slides
  off, as WORLD-METRICS says from 10°.
- **Another tree** (2026-11-16, Nikki: "some ui where i regrow the whole thing with another tree"): the oak
  panel's tree rows: 'another tree' (a random kind in one of its barks, new seed and age), kind and bark
  buttons, age / size / organic sliders, a new seed. Regrown when a slider rests; the treehouses stay. Every
  kind grown to ~15 Mipos (at most 4x, so an olive stands lower); leaves per kind (needles darker).
- **A swing** under the limb (rigzones' swing hung from the limb's body).
- 7 Mipos: two in the den, one in the pantry, one on the grass, one on each floor.

The helpers `box`, `ladder`, `chute`, `swing` are copies of the rigzones scene's (scene-local there too).

## Next, if it's liked

- [ ] OT1. Try the ladders by hand (the climbing is rigzones' code, not tried here yet).
- [ ] OT2. A door in the trunk's foot down into the burrow, and the burrow's rooms furnished (bed, pantry
      shelves, a lamp).
- [ ] OT3. More to do up there: a rope bridge between two floors, a pulley bucket, a fireman's pole.
- [ ] OT4. Leaves that look drawn (the clumps are plain circles), the roots' cut tops above the grass.
- [ ] OT6. The construction as a real thing with joints (Nikki 2026-11-16, put aside the same day): every plank a
      body, nailed like the `planks` spike; open: do nails pop when pulled, and do the ladders stay fixed.
- [ ] OT5. On the phone: one big tree, 300-odd planks and 20 Mipos (`./playtime.sh bench device`).
