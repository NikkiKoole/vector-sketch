# Flora — flowers and plants from L-systems, made organic like the trees

status: active

Nikki (2026-11-10): "we have a pretty good trees setup, can we do something similar to plants flowers etc,
like good L-systems with a bunch of organicizing?" Scene `flora` (`scripts/spikes/flora.playtime.lua`), a
spike next to `bark` (BARK.md): four rows, each kind twice (two seeds), a Mipo at each row's end for scale.
The older `plants` spike (PLANTS.md, parked) grows its plants inside one 1500-line scene; this one is built
like the trees, in modules any scene can load.

## The modules

- `scripts/spikes/plant-kinds.lua`: each kind as an L-system plus its habits (the data; tune a kind here)
- `scripts/spikes/plant-grow.lua`: `grow(kind, rng, x, y, env)` -> stems and organs (leaves, heads); env
  { organic, age, wind, sun }
- `scripts/spikes/plant-look.lua`: `draw(plant, opts)`: crayon-ribbon stems, bent leaves, heads by style, sway

## The kinds

Margriet, klaproos, paardenbloem, tulp, watermunt, gras; zonnebloem, vingerhoedskruid, salomonszegel,
mannetjesvaren, fluitenkruid. Heads by style: ray (petals round a heart, seen at a slant), cup (tulip, poppy;
a poppy goes to a pepperpot), bell (hanging: foxglove to one side, Solomon's seal in pairs), dots / whorl /
umbel / spike (Nikki's crayon rings, as the plants spike's small flowers), a dandelion's clock.

More kinds (2026-11-10, Nikki: "can we add brandnetel, klaver, more succulent type of plants, more tall
grasses"): brandnetel (a clump of square stems, crossing pairs of drooping heart leaves, green tassels
hanging from the upper leaves' feet: `catkin`), witte klaver (three-part leaves on long stalks from the
ground, white balls) and rode klaver (upright leafy stems, pink balls), huislook (a tight rosette curving
in, red tips, offsets round it: `pups`), echeveria (blue-grey cupped rosette, an arching stalk of orange
bells), aloë (sword-leaf rosette, a tall stalk of hanging orange tubes), hemelsleutel (fleshy upright stems,
a flat pink head); riet (tall canes, long drooping blades, a purple-brown plume: `panicle`), vossenstaart (a
tuft, soft cylinder heads: `tail`), struisgras (many thin culms, airy reddish clouds). New in the code for
them: a leaf's droop below 0 cups it upward (fat succulent leaves), `oldColor` tints the outer leaves,
`leaflets = 3` makes a clover leaf, `closing` stands a rosette's inner leaves up.

## The organic part (the trees' ideas, for plants)

- The L-system is the structure only. The walk turns it into stems in small steps that wander by smooth
  noise, ease into a branch's angle instead of kinking, and reach for the light (the sun slider).
- **Weight**: each stem part knows what it carries (stems, leaves, heads above it) and bends under it, more
  the further it leans and the thinner it is (stiffness ~ width squared). Heavy heads nod, Solomon's seal
  arches, fern fronds arch, grass seed spikes bow.
- **Widths add up** (the pipe model): a stem is as thick as the square root of what it carries.
- **Internodes** short at the foot, long in the lower middle, shorter under the flower.
- **Phyllotaxis in 3D**: leaves go round the stem (spiral 137.5 degrees, alternate, crossing pairs, or flat
  two rows for fern pinnae). Seen from the side: a leaf pointing at you looks short and narrow and sits in
  front of the stem; one pointing away sits behind it, darker.
- **Leaves** older lower down: bigger, standing out further, drooping more, first to yellow. Each leaf is the
  drawn shape bent along its droop (a strip), not a stiff sprite. Some turn their blades flat to the light
  (`level`); rosette leaves lie on the ground instead of bending into it.
- **Habits**: a poppy bud hangs and straightens as it opens; a sunflower bows as it seeds; fern fronds
  unroll from a curl as they grow (the curl is on young fronds, only a hint on grown ones).
- **Age**: 0 a seed, grown from the foot up (leaves after their stem, heads last, lower flowers first), 1
  flowering, 2 gone over (petals falling, clocks, capsules, leaves yellowing from below, stems leaning more).
- **organic** 0 is the bare L-system (straight segments, textbook angles, leaves flat left and right), 1 as
  tuned, 2 wild. Each plant keeps its seed, so it stays itself as the sliders move.

Cost: growing a plant takes 0.1-1.2 ms (the fern most); drawing is meshes made once (FL3), ~0.4 ms a
frame for all 42.

## Steps

- [x] **FL1. The spike** (2026-11-10): the three modules, eleven kinds, the scene with the panel (organic,
  age, wind, sun, sway, grow, new seeds).
- [ ] **FL2. Nikki judges**: which kinds read right, what looks off, organic and age at their ends.
- [x] **FL3. Cheaper drawing** (2026-11-10): each plant drawn once into three meshes (leaves behind, stems,
  leaves in front and heads) and kept; the sway and each leaf's flutter in a vertex shader (by height above
  the foot). plant-look records the drawing (its few love.graphics calls into triangles); the drawn parts
  are in one atlas, the stems keep their crayon stroke. All 42 in view: ~45 ms a frame -> 0.4 ms, 19 -> 60
  fps. While growing (every plant regrown and recorded each frame) ~17 fps with all in view. Not yet
  measured on the phone (`./playtime.sh bench device`).
- [ ] **FL4. Into the plants spike, if kept**: its kinds grown by plant-grow, keeping its picking (a picked
  head comes off as a body) and its biomes.
- Later, if it earns it: plants answering each other (PLANTS.md's struggle for light: a shaded plant grows
  tall and thin, leans out), a touch that rustles a plant from where you touch it, the trees' crowns in
  leaves grown this way (BARK.md).
