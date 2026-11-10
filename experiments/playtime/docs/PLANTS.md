# Plants — drawn leaves and stems, grown into real plants

status: parked — kept as a spike, undecided: "not too great, but might become one"; Nikki wants plants interactable, not sure like this (tried 2026-11-04, scene `plants`)

Followed by FLORA.md (2026-11-10): plants grown by modules like the trees (plant-kinds / plant-grow /
plant-look), weight, phyllotaxis in 3D, age; scene `flora`.

Nikki, 2026-11-03, right after the scan tool worked: "start adding some vegetation: leaves and stems,
and grow real plants that are random, physicsy and great."

## What's there to start from

- **Drawing them in**: `tools/scan2tex` (ASSETS-AND-BUILDS.md AB1): a sheet of leaves and stems on
  paper, a phone photo, named parts into `textures/` (outline + mask, so they take colours and
  patterns like a Mipo part). The old Scan 14 already has three sprouts and a fern on it.
- **Physics plants, tried before**: `../vehicles-vegetation/main.lua:794` `makeGrassThing`, each plant a
  dynamic body on a revolute joint to a static anchor, springing back to a random rest angle
  (`:2272`), drawn by `../../lib/texturedBox2d.lua:184` `drawPlantOver`; and 13 unused leaf
  sprites in its `assets/leaves/` (WORLD-BUILDING.md 1d).
- **Bending ribbons**: CONNECTED_TEXTURE (a textured ribbon through joints, the Mipo's hair and arm
  hair) could be a stem; the grass edge (`src/grass.lua`) for the small stuff.
- **Growing over time**: dreamengine's `plants.c` (growth stages) and `lsystem.c` (L-system plants),
  HARVEST-NAVKIT-DREAMENGINE.md 1i.

## The tension to decide early

WORLD-BUILDING's lesson: scenery doesn't need to be physics (cheaper to draw and step; the iPhone SE
2 floor, ~20 Mipos a room). So probably both: a few plants you can grab, bend and pull out (real
bodies: a stem as a chain, leaves on it), and many decor plants that only sway (a fake bend, no
bodies), made from the same drawn parts and the same random recipe.

## A first spike, when it's picked up

One random plant from drawn parts: a stem of 3-6 segments (bodies on springy joints, the ears' weld
feel), a leaf or two per joint, a flower or bud on top, random but seeded; tap it and it wobbles, a Mipo
bumps it and it bends back. Then: does it look drawn, is it fun to knock about, what does it cost on
the phone.

## The plants spike (tried 2026-11-04): "nice"

`scripts/spikes/plants.playtime.lua` (scene `plants`): a row of plants grown from L-systems, each
with its own seed: daisy, sunflower, tulip, fern (leaflet pairs), berry bush, grass tuft,
succulent (a rosette), yucca (a trunk with sword-leaf crowns), a fern of Nikki's drawn fronds.
- Stems are ribbons of Nikki's crayon strokes (a dark one under a green one); leaves, petals and
  hearts are her drawn shapes (outline + mask, `textures/plants/`, copied from the scans and from
  `vehicles-vegetation`), tinted.
- Growing (grow / all the way / new seeds, `p` a plant at the mouse): a sprout drawing first, then
  segments from the root up (the turtle runs each frame with the grown lengths, so a branch starts
  where its stem has got to), leaves after their stem, buds last opening into flowers; fans of
  leaves (rosette, crown, fronds) ring by ring. Everything sways.
- Grab and bend: each grown plant has a spine (four light bodies on soft welds up its height, the
  bottom one welded to the ground) and the drawing follows its bend; the wind sways it, a Mipo
  passing brushes it aside. The spines weigh nothing (with gravity the soft welds folded every plant
  over) and collide with nothing (a spine made again inside a Mipo shot it away; a Mipo lying on a
  plant pinned it). A plant leans as one stick: a branch or a flower doesn't move on its own.
- Leaves are all the same scanned ovals: `THINGS-TO-DRAW.md` A12 asks for many kinds.

Other ways to make them interactable, if it's picked up:
- A spine per branch: every stem, branch and flower stalk its own small springy chain (pull one
  flower, only it bends; a bush rustles in parts). Richer, more bodies.
- Touch, not physics: tap or drag through a plant and it wiggles from that point out, the leaves
  flutter. Cheap, good for small hands.
- Things to do with a plant: pick a flower and give it to a Mipo to hold, shake a bush and the
  berries drop, blow a dandelion. Play rather than bending.
- The struggle for light (below): plants answering the Mipos and the sun.

## Idea: the struggle for light (Nikki, 2026-11-04)

Plants fight for light: wars are fought in the canopy. Not sure this is the place, noted to keep.
- A sun (or a lamp a Mipo carries) and shade: what's under a leaf gets less light.
- Plants grow towards it (bending to the light), faster in it; shaded ones grow slow, or tall and
  thin to get out (etiolation), and put their leaves where the light is.
- Neighbours race: the tall one shades the small one, which leans out sideways or gives up.
- Play: a Mipo holds a big leaf over a plant (an umbrella) and it leans away; moves the sun; plants
  a seedling in the gap a fallen one left. A garden that slowly sorts itself out.
- The spike already has what it needs to start: each plant's turtle knows where its leaves are,
  so a shade map along x (or a coarse grid) and a growth rate per segment would do.


## Wild plants in three biomes (2026-11-05)

Nikki: "can you research what they look like and grow; we have 3 biomes: normal, shaded forest,
waterside". The scene now sows these instead of the first row (the old kinds stay in `TYPES`);
`p` plants a kind of the biome under the mouse. Meadow left (x < -1100), forest in the middle
(trunks out of view, a canopy of drawn ovals, shafts of light, dark soil), waterside right (shallow
see-through water over the plants' feet from x 1500, a sloping bank). The colours blend over 300 px.
Small flowers are dots of Nikki's drawn crayon rings (the Mipo eye outlines, `berry-0n`): green buds
that colour as they open. Berries use them too (2026-11-05, "I don't like your berries").

What each one is and how it's built:
- **Wilde marjolein** (*Origanum vulgare*): a bushy clump of upright reddish stems, small opposite
  leaves, at the top a branched flat-topped corymb of tiny pink flowers on dark purple bracts.
  Five stems, opposite leaves (`O`), three tufts each (`M`, a flattened ball of pink/purple dots).
- **Grote tijm** (*Thymus pulegioides*): a low mat (to ~25 cm) of thin stems from a woody base,
  tiny oval leaves, every stem a short erect spike of lilac-pink flowers. Seven short stems, `S`.
- **Blauwe knoop** (*Succisa pratensis*): a rosette of long whole leaves, a tall thin stem (60 cm–1 m)
  with a pair of narrow leaves, forking at the top into long stalks; the heads blue-violet balls,
  half-round as they start. A low fan (`R`), the stem, three `K` knobs.
- **Beemdkroon** (*Knautia arvensis*): hairy stem, opposite leaves deeply pinnately lobed (the lowest
  often whole), flat lilac pincushions with the outer florets bigger than the middle ones. Opposite
  leaves from Nikki's drawn fronds, `Q`: a ring of petals round a small ball of dots.
- **Tongvaren** (*Asplenium scolopendrium*): a tuft of whole, strap-shaped, glossy leaves arching out.
  Two rings of narrow ovals.
- **Mannetjesvaren** (*Dryopteris filix-mas*): a shuttlecock of long lance-shaped fronds out of one
  crown. Nikki's drawn fronds in two rings.
- **Koningsvaren** (*Osmunda regalis*): big (to 2 m) fronds of oblong leaflets, like an ash's; some
  topped by fertile tips, clusters of spore beads green, then rust-brown ("flowering fern"). An
  L-system frond with oval leaflet pairs (`V`), about half the tips a rust spike (`Z`).
- **Grote kattenstaart** (*Lythrum salicaria*): stiff upright stems to 1.5 m, opposite narrow leaves,
  long dense magenta spikes. Three stems, `P` spikes that open from the bottom up.
- **Gele lis** (*Iris pseudacorus*): a fan of sword leaves out of the mud, flower stems among them,
  yellow irises with three big falls and small standards. A tall narrow fan (`Y`), two stems, `I`
  (a closed bud, then the falls swing out).
- **Watermunt** (*Mentha aquatica*): square, often reddish stems, opposite oval toothed leaves, a round
  lilac head at the top and whorls lower down (the top cluster the biggest). Two stems, `W` and `w`.

Sources: Thijsse's Hof (blauwe knoop), BSBI and Minnesota Wildflowers (Knautia), Wikipedia and
Minnesota Wildflowers (Osmunda), first-nature and naturespot (Mentha aquatica), Kew Grow Wild and
the Victorian flora (Origanum), RHS (Thymus pulegioides).

### More kinds, and no two the same (2026-11-05)

Nikki: "how do we make the plants look realistic but not all identical?" Added paardenbloem (yellow
heads or white clocks), klaproos (nodding bud, four petals, seed capsule), duizendblad (white umbel,
sometimes pink), vingerhoedskruid (one-sided bells, sometimes white), salomonszegel (arching stems,
bells hanging in pairs, blue-black berries), bosanemoon (a carpet), lisdodde (cigar + spike, in the
water, bursting into fluff), dotterbloem (round leaves, golden cups).

What makes them differ:
- **Each plant its own recipe** (`vary`): the kind's numbers nudged, angles ±25 %, internodes and
  stems ±15 %, leaves ±20 %, heads ±15 %, fan leaf counts ±2; leaf colours shifted together, the
  flowers on their own, a rare white or pink form. In the forest's shade: longer stems, bigger leaves.
- **Genes the recipe doesn't have**: how many stems and at what angles (`stems = {min, max, spread}`,
  `^` in the L-system), a lean, a bend as it grows, some leaves missing, some heads late (still buds
  when the plant is grown), some gone over (faded, or their own seed head: clocks, capsules, berries,
  fluff).
- **Sowing like a real patch**: uneven gaps, the same kind often next to itself (a smaller one, it
  spread there; at most three in a row), iris and bulrush only in the water.
Next, if wanted: age as its own gene (a young plant isn't just a small old one), plants answering
each other (the light idea above), seasons.

### Picking flowers and fruit (2026-11-05)

Nikki: "gameplay wise we want to be able to pick flowers and fruit". Tap a flower head or a fruit and
it comes off: a small light body (a stalk, the head drawn on top, label `picked-flower` /
`picked-fruit`) that the pointer carries; a snap point at the stalk's end, so a Mipo's hand takes it
when you bring it there (snaps only form while the pointer holds one of the two). On the plant a bud
comes back after ~6 s and opens over ~14 s. At most 25 picked lie about (the oldest go). A press
on stems and leaves still bends the plant; a press on a head picks. Fern spores and the mint's
lower whorl stay on. The engine side: `box2dPointerJoints.grab(id, body, wx, wy)`, in scene scripts
as `pointerGrab`.
- Fruit plants for it: **wilde aardbei** (three-part leaves, white flowers, strawberries hanging,
  green, white, red) in the meadow and the forest; **braam** (arching canes, berry clusters, each
  drupelet ripening at its own pace, green, red, black) in the forest.
- Next, if wanted: Mipos reacting to what they're given (sniff, a happy squeak, eat a berry: a
  munch and it's gone), a bouquet (several flowers in one hand), a basket, only ripe fruit
  comes off (an unripe one wobbles back), touch on the phone (untested: LÖVE turns touches into
  mouse presses, so it may just work).
