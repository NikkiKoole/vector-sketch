# Story ideas — tales, rhymes and nature topics as Mipo spikes

status: idea

Started 2026-11-16 from Childcraft (the 1970s volumes Nikki owns, `INSPIRATIONS.md`). The volume titles here
are from memory: check them against the shelf. Nikki: "i like all these ideas". Folk tales, fables and nursery
rhymes are public domain. Each idea gets a verb (what the kid does) and the spikes it would build on. These are
ideas to pick from, not a plan. A picked one becomes a spike (run `./playtime.sh tried <word>` first) or a
candidate for app one (`APP-ONE.md` AO1).

## Folk tales and fables (Folk and Fairy Tales, Stories and Fables)

- **The Enormous Turnip** — *pull.* Mipos grab each other into a chain and pull; the joints stretch and
  wobble until *pop*, everyone tumbles. Pure physics, very little to build. reach, ragdoll.
- **Three Billy Goats Gruff** — *cross.* A wobbly plank bridge, a troll underneath who bumps it. planks.
- **The Three Little Pigs** — *build, blow.* A house of straw, sticks or Fabuland blocks, then the wind
  blows: which one stands? fabuland, weather.
- **The Gingerbread Man** — *bake, chase.* Decorate the dough like Puppetmaker; out of the oven it runs away.
  maker, food.
- **Stone Soup** — *add.* A big pot every Mipo throws something into: bubbles, a colour change, a bowl each.
  food, liquid, waterjar.
- **The Mitten** (Ukrainian) — *squeeze in.* Animals squeeze one by one into a mitten that stretches, until a
  mouse sneezes and *pop*. soft torso, blob.
- **The Little Red Hen** — *sow, grow, bake.* Grain to flour to bread. plant-grow, food.
- **Henny Penny** — *panic.* Something falls on a head, everyone runs. emotions.
- **The Tortoise and the Hare** — *race.* Two breeds on a track. tracks, coaster, breeds.
- **The Lion and the Mouse** — *free.* A net or a knot a small Mipo gnaws through. cloth, rope.
- **Town Mouse and Country Mouse** — two worlds side by side, burrow and house. burrow, depth. (The
  underground-Mipos hunch of 2026-11-01.)
- **The Elves and the Shoemaker** — *make at night.* You make shoes; in the morning the Mipos wear them.
  wearables, `SHOES.md`.

## Nursery rhymes (Poems and Rhymes)

- **Humpty Dumpty** — *fall, put back together.* Off the wall in pieces, then snap the parts back on. The
  Mipo ragdoll is already the toy.
- **Rub-a-dub-dub, three men in a tub** — *sail.* A tub with three Mipos in it. boat2, drawn-sea.
- **Hickory Dickory Dock** — *climb.* A big clock with a pendulum, a mouse runs up, *bong*, it runs down.
  music, synth.
- **The Old Woman Who Lived in a Shoe** — a shoe as a dollhouse, full of Mipos. dollhouse.
- **Jack and Jill** — *carry, roll.* A bucket of water up the hill, then down it. waterjar, a slope.
- **Hey Diddle Diddle** — *jump.* The cow over the moon: a trampoline arc, the moon in the sky. clouds.
- **Row, Row, Row Your Boat** — *row,* sung as a round. choir, boat.

## Nature and science (About Animals, The Green Kingdom, World and Space, How Things Change, Science All Around)

- **Underground** — moles and worms in their tunnels. burrow.
- **The seasons** — one tree through the year: leaves fall, snow stays. tree-grow, weather.
- **Caterpillar to butterfly** — *feed,* a cocoon, the surprise. A reveal like the bathhouse's.
- **The water cycle** — cloud, rain, river, sea, steam. clouds, sand (its steam rains back down).
- **Nests and eggs** — *bring sticks,* a bird builds a nest, an egg hatches a baby Mipo.
- **Day and night** — *turn* a dial; the Mipos go to bed. light.
- **Floats or sinks?** — *throw* things in the water, the encyclopedia experiment. The sand spike's buoyancy
  already does it.
- **Simple machines** — a seesaw, a crane, a pulley with a bucket. joints, motors.

## Make and Do, Children Everywhere

- **Paper crafts** — *cut, fold, glue,* and the drawing comes alive. cutpaper.
- **Puppet theatre** — the curtain opens, the kid plays the story with Mipos. Puppetmaker's natural sequel.
- **The kitchen** — Mipos baking cookies. food, an oven.
- **Houses of the world** — stilt houses, igloos, windmills. fabuland parts per style.

## Built as spikes (2026-11-16)

The four quickest, each its own scene in `scripts/spikes/`, not yet played by Nikki by hand:

- **turnip** — a chain of Mipos pulls; a Mipo dropped behind the last one grabs on with both hands. One or two
  can't, three can (the count decides: Mipos in the chain + 0.7 for the kid's drag must reach `need` 2.8;
  measured through the chain the pull depended on how well the random Mipos' feet gripped). Pop: a kick, a
  camera shake, everyone tumbles, the turnip lies on the ground (Nikki: "when pulled should be on top of the
  ground"). Open: the chain never lets go after the pop; the turnip and leaves are plain shapes.
- **humpty** — a pear-bodied Mipo (rubberleg-pearbod) on a brick wall. A hard landing breaks the shoulder and
  hip joints (recorded first); drag a piece within 170 of its pulsing socket and it clicks back on (the
  engine's createJoint, same id). Open: a grey bar on loose limbs; `humpty-joints.lua` exists only because the
  script env has no `joints`.
- **mitten** — ~100 wool beads on springs, each pulled to its place in the mitten's shape, open at the cuff.
  Five inside: "ah… ah… tchoo!", the mitten puffs, everyone flies out, it springs back. Open: the cuff (~600)
  is lower than a Mipo (~660); the bulge barely shows; the camera starts too far left.
- **floats** — a glass tub (`props.makeBath`, the engine's level water) and 11 things on a table: ball, cork,
  duck, block, apple and ice float; egg sinks slowly, the sponge soaks and sinks, stone, key and coin drop.
  Lift by displaced water per fixture (the engine's floatIn lifts by mass, so everything floated alike), a
  splash and bubbles, a bloop. Open: the table and tub frame are plain grey; a Mipo can pin the cork.

## Quickest as a spike (2026-11-16)

Closest to a one-verb toy: **the Enormous Turnip** (pull), **Humpty Dumpty** (fall, put back together),
**the Mitten** (squeeze in, pop), **floats or sinks?** (half built in the sand spike).
