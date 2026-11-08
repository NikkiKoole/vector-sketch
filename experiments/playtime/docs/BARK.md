# Bark — tree trunks in real bark, lit

status: active

Nikki (2026-11-08): "can we try to nail down some tree barks, fetch some assets, do the setup and
show a variety of trees or just their main stem". Scene `bark` (`scripts/spikes/bark.playtime.lua`),
a spike: two rows of 18 bare trees, each grown by its kind in its own bark, under a light at the mouse.

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
- [x] **BK1d. Grown trees** (2026-11-08, Nikki: "more grown, more side branches in the way that suits the
  types of tree"): the trunks replaced by whole bare trees, grown in the scene by kind (KINDS in the
  script; the L-system idea of `experiments/lsystem-master`, whose turtle draws only thin lines, so a
  grower of its own: every branch makes side branches by its kind's rules, down to twigs, each a tapering
  stem in the bark). Oak: a short thick trunk forking into three crooked limbs. Elm: a vase of four rising
  limbs. Beech: two upward limbs, dense. Plane: crooked, zigzagging. Olive and cork: low, twisted, wide.
  Pine: a straight trunk to the top, whorls shorter toward it, side shoots. Poplar: a narrow column.
  Aspen: bare below (the eyes are there, where it dropped its branches), a crown on top. Birch: weeping
  twigs. All of a depth in one mesh, drawn deepest first (twigs behind branches, branches behind the
  trunk); a forked trunk narrows to a point between its limbs. Not yet: leaves, the trees swaying.
- [x] **BK1e. Less polygon** (2026-11-08, Nikki: "still looks very much like polygons ... more organic"): a
  branch turns slowly (smooth noise along it, not a random kink per step) and its middle line is rounded
  off; its width eases off (thick for longer, then thin); a side branch starts inside its parent and swells
  into a collar there; each edge has its own slow bumps (never mirror-alike). Seen: much more grown, the oak
  old and gnarled; olive and cork (wander 0.35) now twist into S-shapes, maybe too far.
  The panel's **organic** slider (0..2) scales it all: 0 straight, even branches (no collars, no bumps), 1 as
  tuned, 2 fairy-tale gnarled (olive and cork curl into knots). Each tree keeps its seed, so it stays
  itself; a regrow takes ~0.1 s, so it waits until the slider rests.
- [ ] **BK2. Nikki judges**: which look (photo / tinted / relief) sits with the drawn Mipos, which
  barks to keep. A Mipo next to a trunk for the scale (WORLD-METRICS.md).
  Scale, 2026-11-08 (Nikki: "the trees should grow taller ... how tall are we aiming for"): measured, they
  were 1-2.7 Mipos tall (a median Mipo 658; the olive no taller than one), real trees are 15-20 people.
  Chosen: **storybook scale**, as picture books do: olive 2.5 Mipos, birch and aspen 4, oak 4.5 (its trunk
  ~520, wider than a Mipo), beech, plane, elm 5, pine and poplar 6; the kinds keep their real proportions to
  each other. Each tree grows at the old size (its crookedness is in world units) and is then scaled from
  its foot (`stretch`, `thicken` per kind in tree-kinds.lua; twigs stay thin). The scene: trees every 2600,
  rows 4800 apart, a zoomed-out start (scale 0.05; the wheel zooms; camera follow off, min zoom 0.04 in the
  scene's settings), six Mipos standing by trees as rulers on invisible floors, the trees drawn behind them
  (drawBelow). Seen: the oak about 4 Mipos over two Mipos, the pine about 5.
- [ ] **BK3. Into the engine, if kept**: a bark as a material on a ribbon (connected-texture) or a
  texfixture, through the plasticine shader (MATERIALS.md), the scene's lights instead of the mouse.

### Why trees gnarl (2026-11-08)

Ours bent by noise; real ones bend for reasons, and giving each bend a cause makes them look grown.
Why: **weight** (a limb sags as it lengthens, then its tip turns back up: the old oak's elbow), **light**
(branches reach for open sky, away from neighbours; an edge tree leans out, its crown lopsided), **wind**
(the whole tree leans, the windward side stays short), **how the kind grows** (pine and poplar keep one
leading shoot: straight; oak, elm, plane lose their tip bud each year and a side bud takes over: zigzag
twigs), **damage** (a broken top or limb: a side branch takes over, a dog-leg). Afterwards: wounds heal as
rolls of bark (the aspen's eyes are where branches were), stubs, dead limbs, a dead top on an old oak,
hollows, water sprouts round a wound, lower branches dying off in the crown's shade (young trees are
cones, old ones broad on a bare trunk), moss on the damp shady side.

- [x] **BK4. Widths that add up** (da Vinci's rule): a parent's cross-section about equals its children's
  together; each side branch takes its share of the parent's wood where it leaves, the parent goes on
  thinner. Forks look right instead of guessed.
  Done 2026-11-08: a branch picks its side branches first (where, which side, `share` per kind: 0.1 for a
  pine's many whorls, 0.35 for an oak's few limbs), each as wide as the parent there times the square
  root of its share; the parent goes on with what's left (eased, no step); a fork splits what's left
  between its limbs. Trunks thin visibly as limbs leave.
- [x] **BK5. Sag and recover**: a limb droops more as it lengthens (its weight), and its tip turns back up
  (the elbow); pine tips curving up, the birch still weeping. Bends with a reason, the random wander
  only a little on top.
  Done 2026-11-08: `sag` (more the further out and the thinner), `recover` past `recoverFrom` per kind; the
  organic slider scales both (0: straight). Seen: the oaks reach out, sag and turn up into elbows, pine
  tips curve up, the birch arches down. The elm's long limbs sagged into flat arcs: less sag, an
  earlier upturn (a wide vase now). The olive's trunk wander halved (it keeled over); olive and cork lean.
- [x] **BK6. Zigzag or straight** by how the kind grows: oak, elm, plane twigs zigzag (a side bud takes over
  each year), pine and poplar keep one straight leader.
  Done 2026-11-08: a branch kinks at each year's growth (a fifth of its length, 45-130 units), the other
  way each time, more on thin wood (on old limbs the bark has grown over it); `zigzag` per kind: elm 0.45,
  plane 0.38, oak 0.35, beech 0.3, olive 0.2, birch 0.15, aspen 0.1, pine and poplar 0. The organic slider
  scales it. Seen: the oak's and elm's twigs zigzag, their limbs stay smooth.

**Modules** (2026-11-08, Nikki: "can we make our code in such a way we can modularize"; spike modules, the
engine left alone: moving into src/ is ENGINE-MERGE's call). Next to the scene, loaded like drawn-stroke.lua
(`love.filesystem.load(path)()`), so any scene can plant a tree:
- `scripts/spikes/tree-kinds.lua`: how each kind grows (the data; tune a kind here)
- `scripts/spikes/tree-grow.lua`: `grow(kind, rng, x, y, angle, scale, env)` -> branches (env: organic, wind, sun, crowd, left/right room, age)
- `scripts/spikes/tree-mesh.lua`: `parts(branches, seed)` -> a mesh and crayon outline per depth
- `scripts/spikes/bark-look.lua`: `begin(settings)` once a frame, `drawTree(tree, opts)`, `placeEyes`, `reset`
The bark scene is now its layout, panel and light (254 lines, was ~690). Checked with a one-off fingerprint
(every branch's points, widths, eyes, mesh and outline vertex counts, 18 trees at organic 0, 1 and 2):
identical before and after.
- [x] **BK7. Wind**: one direction and strength for the scene; trees lean with it, windward branches stay
  short (a combed crown).
  Done 2026-11-08: the panel's **wind** slider (-1 from the right .. 1 from the left: the wind the trees
  grew up in, not a sway). 'Up' for the tree leans downwind (the trunk leans, tips recover toward it),
  branches are combed to the lee side (more if thin), and a branch's length goes with the wind (x1.45 reaching
  downwind, x0.55 into it, forks too). tree-grow's grow now takes an env table { organic, wind } (light and
  age to follow). Wind 0: the trees identical to before (fingerprint). Seen at 0.8: coast trees, oaks and
  elms windswept, pine and poplar least.
- [x] **BK8. Light**: crowns reach toward the scene's sun and away from the trees next to them (a row
  shapes itself).
  Done 2026-11-08: the panel's **sun** slider (-1 left, 0 overhead, 1 right: where the light came from while
  they grew, apart from the mouse's light) leans 'up' a little sunward (0.15 rad at full, less than wind:
  first try 0.3 read as wind) and makes the crown lopsided (branches x1.5 toward the sun, x0.5 away). The
  **crowd** slider (0..1): each tree gets the room to the next one on each side (half the gap; none at a
  row's end); a branch reaching past it is shortened (to 30% at most), and past 60% of its room it turns up.
  Seen: sun from the left, every crown reaching left; crowd 1, oaks and elms narrower and taller (forest
  trees, not field trees). Sun 0, crowd 0: identical to before (fingerprint, two clean runs; a first run
  differed where a slider was moved during it).
- [ ] **BK9. A history per tree**: a broken top becomes a dog-leg; a lost limb leaves a stub with a scar eye
  and water sprouts round it. The eyes then sit where branches really were.
- [x] **BK10. An age slider**: a young cone to an old giant; lower branches dropping off (leaving eyes), the
  crown broadening, a dead top, a hollow (a Mipo's home?). With PLANTS' growing over time; brings BK9.
  Done 2026-11-08: the panel's **age** slider, 0 a sapling, 1 grown (the trees as before: fingerprint), 2
  ancient; `tree-grow`'s agedKind(kind, age) makes the kind as it is at that age. Young: smaller and thin for
  its height, fewer branchings, branches low on the trunk, the kinds that fork still a cone on one leader
  (under 0.5). Old: the trunk far thicker (x1.45 at 2) but barely taller, lower branches shed (bare trunk
  longer, more eyes: aspen and birch +3, others +1), a broader crown of longer, saggier, more crooked limbs,
  limbs broken to blunt stubs (30% at 2), and past 1.4 a dead top on the kinds that fork (bare limbs high
  up). Seen: saplings at 0.3; at 2 massive gnarled oaks and elms with stubs and dead tops, tall aspens full
  of eyes. First try hit aspens with the dead top (crowns gone) and too many stubs and eyes: tamed.
  Not yet: a hollow (needs its own picture), BK9's broken top and water sprouts.
- [ ] **BK11. Moss on the shady side**: bark facing away from the light greener (in the shader).
- [ ] **BK12. Hand-drawn bark** (Nikki 2026-11-08: "the barks are nice, but it might be better if I
  hand-draw some of it"; what to draw: THINGS-TO-DRAW A18). A bark is three pictures in
  `textures/world/bark/`: `<name>.jpg` (colour), `-normal.jpg`, `-height.jpg`; a drawing needs only
  the colour, the other two are worked out from it as for aspen and birch (or from Nikki's own grey
  height sheet). Order: (1) a tile or two, added to the bark picker next to the scans, judged in the
  three looks (with BK2); (2) drawn eyes, knots, scars as cells in `bark-eyes.png`; (3) maybe a drawn
  trunk edge instead of the computed outline. Start with 1.
- Later, if it earns it: the crown (leaf blobs, PLANTS.md).
