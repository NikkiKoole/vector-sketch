# Digging series — three small apps around one verb: dig

status: active

Nikki (2026-11-16), from APP-ONE AO1: "the single verb digging speaks to me". Three ideas came with it:

1. **The mole** — a mole Mipo, you dig and open up the world underground, a household feel.
2. **Treasure hunters** — digging for diamonds and whatnot, like in the illustrated book (Hancock's
   *Underworld*, INSPIRATIONS.md), more human: tools, a hard hat, tunnels.
3. **The ant farm** — a big group of tiny Mipo-likes digging together.

Nikki asked "one app, 3 minigames?". Claude's advice: **three apps, one engine.** Three minigames in one app
is three things to polish in one six-week window (the Sago Rule's "and also"); three apps is the App Store
bundle the business plan waits for, three mipo_club videos, and the second and third come cheaper because
the dig engine is done by then. Mole first. Not decided as a store plan yet: this page is where it's thought
through.

## The three, side by side

| | The mole | Treasure hunters | The ant farm |
|---|---|---|---|
| Verb | dig | dig | dig (many diggers) |
| What the kid gets | things in the earth, and what the mole makes of them | a find: a gem, a fossil, a chest | a nest that grows by itself |
| What the Mipo does back | eats it, and likes some things more than others | cheers, holds it up, puts it in the cart | they swarm in, carry, follow each other |
| Feel | cosy, small, at home | adventure, tools, lamps | busy, a little world to watch |
| What's built | burrow (earth, rocks, rim), oaktree (mole size, den, pantry), food (eating, tastes) | burrow + the mole's findables; hard hat, pick, lamp to draw | burrow + a tiny cheap Mipo (not built) |
| Phone | burrow not measured on the SE 2 yet | as the mole | the risk: ~20 Mipos a room is the limit (PHONE baseline); a crowd needs a cheaper Mipo |
| Order | 1 | 2 | 3 |

## The mole, thought deeper

Nikki (2026-11-16): "lets just have him eat stuff he finds, but without meaning, well he likes certain things
more than others".

**The loop, all of it:** the kid digs, things come loose from the earth, the mole eats them, and shows how
much he likes each one. That's the whole app. No hunger, no meter, no score, no collection, no "level done".
Eating has no use; it's there because watching him taste things is funny.

**The tastes are the content.** Not good and bad food, but a scale, and each mole has his own:

| He... | What it looks like (from FO1 and EMOTIONS) |
|---|---|
| loves it | a squeak, a happy wiggle or hop, the hum, cheeks pink; goes looking for more |
| likes it | munch munch, mmm, happy face |
| it's fine | chews slowly, a little shrug, a flat "hm" |
| doesn't like it | one chew, "blah", spits it out (the sprout in the food spike) |
| it's not food | sniffs it, licks it, a puzzled look, pushes it away (a pebble, a bone, a button) |

The kid finds out what he loves by trying, without words; that's the 5-second rule and the surprise in one.
The same mole always loves the same things, so it can be learned ("he loves worms!"). A fresh mole (or a
second one met in the earth) has other favourites, so the testing starts over.

**What's in the earth** (each a small drawn thing, held in the earth the way burrow's rocks are: kinematic
while there's earth round it, loose once dug free): worms, beetles, roots, a carrot or potato hanging down
from above (Hancock's potato), seeds, a mushroom, berries fallen in, a snail; and not-food: pebbles, a bone,
a lost button or marble. Rare ones for the surprise: a golden worm, a giant carrot that takes many bites.

**The kid's hands: the mole is the brush.** Drag him into solid ground and he digs through it: the earth
opens round him where he's dragged (Nikki: "we drag him into full ground to have him dig, but basically
it's just your finger"). So it's burrow's finger digging, with the mole at the tip doing it: paws going,
crumbs flying. Let go in a tunnel and he's a Mipo again: falls, stands, walks. A loose thing can also be
dragged to his mouth (as the food spike), and he goes for a loose thing by himself if it's near: he sniffs
towards it.

**The household feel** comes from where he lives, not from chores: the den, the pantry (oaktree), and maybe
things he doesn't eat get carried home. No care meters, no "your mole is hungry".

## Not in the mole app

Treasure, gems, tools and the hard hat (app two). Many diggers (app three). Hunger, meters, score, a
collection screen. The treehouses and the oak above (oaktree is a spike, not this app). Water flooding the
tunnels (BURROW's later payoff; maybe a later update).

## Decided (Nikki 2026-11-16)

- **Who digs:** the mole, dragged into the earth by the kid's finger (above). Changed the same evening: the finger
  digs on its own, a small ring that takes effort ("can i for now just draw with mouse"); dragging him dug too,
  taken out ("its much too easy to tunnel if you just drag the mipo around"). Each stroke throws clumps of dirt,
  real Box2D bodies that pile up in the tunnel.
- **A big field, bounded** (Nikki 2026-11-16, "1 c"): 38,400 x 19,200, about 16 screens each way, bedrock at the
  bottom; not streamed (endless) for now. The finger digs only within reach of the mole (1,100) and the camera
  follows him: to dig further, carry him in. Finds by depth (`mole-finds.lua` BANDS): worms and roots near the
  top, beetles and potatoes in the clay, snails and acorns deep, buttons and marbles near the bottom, golden
  worms deepest. The bottom's own surprise: not decided yet.
- **Eating only:** "just you can eat some things, plant and animal". What lived or grew is food (worms,
  beetles, snails, roots, seeds, berries, mushrooms); stones, bones and lost things are not. No belly that
  fills, no potty: those stay in the food spike.
- **One mole** to start with. Other moles met in the earth maybe later.
- **What a mole Mipo looks like:** not known yet, to figure out (a breed, the underground pear-Mipo hunch,
  digging paws, small eyes?). The spike can start with a plain Mipo.

## Steps

- [x] **DS1. Nikki reads this and answers the open questions** (2026-11-16, under "Decided").
- [ ] **DS6. The mole's look**: a mole breed of Mipo, sketched or rolled from the breeds; not blocking DS3.
- [x] **DS2. On the phone:** the mole's field on the SE 2 (`./playtime.sh bench device`), digging while it
  runs (2026-11-16): 60 fps, 0.3% of frames over 20 ms after the earth's drawing stopped making garbage
  (350 KB a frame before); the earth shader drew black past a diagonal there (medium precision), fixed.
  oaktree not measured.
- [x] **DS3. The mole spike** (2026-11-16, `./playtime.sh play mole`): one mole in a burrow, dragged through the earth to dig it, five or six
  findables held in the earth, eaten with the food spike's mouth and the taste scale above; his tastes
  seeded. Built from burrow + food, the
  findables' look in its own file (`scripts/spikes/<name>-look.lua`).
- [x] **DS4. Nikki plays with it**: keep, change or park. 2026-11-16: "this spike is done now" (as the
  decisions above: the finger digs near the mole, a big bounded field, clumps; the bottom's surprise open).
- [ ] **DS5. The kids play with it** (APP-ONE AO2), on the iPad, without explaining.
