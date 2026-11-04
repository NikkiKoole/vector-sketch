# Plants — drawn leaves and stems, grown into real plants

status: parked — kept as a spike, undecided: "not too great, but might become one"; Nikki wants plants interactable, not sure like this (tried 2026-11-04, scene `plants`)

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

