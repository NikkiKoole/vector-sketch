# Bark — tree trunks in real bark, lit

status: active

Nikki (2026-11-08): "can we try to nail down some tree barks, fetch some assets, do the setup and
show a variety of trees or just their main stem". Scene `bark` (`scripts/spikes/bark.playtime.lua`),
a spike: two rows of 15 main stems, each its own shape and bark, under a light at the mouse.

## The barks

15 scans from ambientCG (CC0: free for anything, no credit needed; ambientcg.com, Bark001-016,
Bark005 left out: a cut-off strip). Each in `textures/world/bark/` as `bark-NN.jpg` (colour, 512 px
wide), `bark-NN-normal.jpg` (the normal map, OpenGL way up) and `bark-NN-height.jpg` (256 px,
grey: lighter is higher). The 1K downloads scaled down; 4.3 MB for all 15. Names by what they look
like: 01 oak (deep furrows), 02 elm, 03 smooth brown, 04 pine (plates), 06 lichen, 07 cracked,
08 olive, 09 plane (patches), 10 beech, 11 grey, 12 cork, 13 mossy, 14 red, 15 striped, 16 old mossy.

## Aspen, birch and their eyes (2026-11-08)

Nikki showed aspens: white bark with dark "eyes", the scars where the tree shed its lower branches
("can we get an occasional eye in there"; not drawn by us: "look further"). No texture library has
aspen or birch (ambientCG, Poly Haven, ShareTextures; the birch sets elsewhere are AI-made under their
own licences), so photos from Wikimedia Commons, CC0 or public domain only:
- [the aspen eye](https://commons.wikimedia.org/wiki/File:Bark_close-up_-_American_Aspen_-_Populus_tremuloides.jpg)
  (CC0): its top half is `aspen-01` (the bark), its eye the first eye
- [a birch with two scars](https://commons.wikimedia.org/wiki/File:Birch_trunk_with_bark_in_Norrkila.jpg)
  (CC0): a strip above the scars is `birch-01`, the scars the second and third eye
- not used yet, also free: [aspen with scars and dots](https://commons.wikimedia.org/wiki/File:Closeup_of_aspen_bark_(52456823444).jpg),
  [smooth aspen](https://commons.wikimedia.org/wiki/File:McKenzie_Aspen_Bark_(3630771528).jpg),
  [aspen with lichen](https://commons.wikimedia.org/wiki/File:Lichens_Making_a_Living_(92fc0ad4-1dd8-b71c-079b-496d8dd87212).jpg)
  (all public domain)

Photos don't tile and have no normal map: each bark's light evened out (divided by a big blur of its
brightness), its normal and height made from its light and dark (mild: strong made it look like
metal), repeated mirror-wise. The eyes in one picture (`bark-eyes.png`, three cells), each eye's white
made 1 and its edge a soft oval, so it multiplies into any bark; the shader lays each in the stem's own
frame (round it and up it), so one round the side squeezes like the bark. Aspens get 4-5 eyes, the
birch 3, every other tree one now and then (one in three); e turns them off. The prep is a one-off
script (not kept: the crops are written here). Seen: the aspen reads right, the eyes scattered in size
and place; the birch's mirror-repeat shows as mirrored pairs of marks (a longer strip would hide it).

## How it's made

- **A stem** is a strip along a bent middle line: tapering, roots flaring at the foot, a lean and
  an S-bend per tree, some with a branch stub. Drawn branch first, stem over it.
- **Round**: the shader turns the place across the strip into the angle round the stem, so the bark
  squeezes toward the edges as it turns away, and the stem's normal leans out there. The bark's
  normal map tilts that normal; the light at the mouse lights it (a point a little in front, `light
  out`). The height map darkens the cracks.
- **Outline**: Nikki's crayon strokes (`drawn-stroke.lua`), both edges and the cut at the top.
- **Three looks** (v): *photo* the bark as photographed; *tinted* its light and dark in one colour
  per tree (the photo's grain, the drawn world's colours); *relief* a flat colour, only the bumps and
  cracks taking the light. Painted (p): the light in four steps. Detail (d) and the bark's size (s).

## Steps

- [x] **BK1. The spike** (2026-11-08): the 15 barks, the stems, the three looks, the panel.
- [x] **BK1b. Aspens, a birch, eyes** (2026-11-08): two aspens and a birch from Commons photos, branch-scar
  eyes from the same photos on them and now and then on the others.
- [x] **BK1c. Mipo eyes on the trees** (2026-11-08, Nikki: "curious how our own Mipos' eyes would look on the
  aspen"): m swaps every eye for a Mipo eye in the same place (cells 4-10 of `bark-eyes.png`: eye-01..07's
  outline in ink, its inside white, pupil-01 dark in the middle), a little smaller. They sit in the bark,
  lit and curved with it, but read as drawn onto the tree, not grown in it. Not yet: pupils that follow
  the mouse or a passing Mipo, two side by side as a face.
- [ ] **BK2. Nikki judges**: which look (photo / tinted / relief) sits with the drawn Mipos, which
  barks to keep. A Mipo next to a trunk for the scale (WORLD-METRICS.md).
- [ ] **BK3. Into the engine, if kept**: a bark as a material on a ribbon (connected-texture) or a
  texfixture, through the plasticine shader (MATERIALS.md), the scene's lights instead of the mouse.
- Later, if it earns it: the crown (leaf blobs, PLANTS.md), branches that fork, bark drawn by Nikki
  as a height sheet (MATERIALS MT11) next to the scans.
