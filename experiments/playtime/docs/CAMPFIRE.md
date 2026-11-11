# Campfire — flames, glow, sparks and a warm flickering light

status: active

Nikki (2026-11-11): "can we do a fire, like campfire, but with good light and flame", then "weird shapes
and blending", "drawn textures we already have", "more organic drawn tree trunk, firewood". Scene
`campfire` (`scripts/spikes/campfire.playtime.lua`), the fire in `src/fire.lua` (a plain table the scene
keeps on `state`), so it can go on the toys shelf later (ENGINE-MERGE EM2).

## What's built (2026-11-11)

- **Flames, 'drawn' style** (the default): licks of Nikki's drawn pictures, the grass blades
  (`textures/world/sprieten.png`, src/grass.lua's quads) and the plants' petal and oval masks, rising,
  stretching and swaying in one draft, coloured by age from yellow to orange to dark red, all added on.
  Not faded but **eroded** (the stylized-VFX way: 80.lv's UE4 campfire, vfxdoc 'alpha erosion'): each
  picture times a world-space noise field scrolling up through the fire, cut at a threshold rising with
  age, a hot rim just inside the cut. `f.bands` (the cut in flat steps, the hand-animated look) and
  `f.fps` (a flipbook's few frames a second) are there, both off. The old **'tongues'** style (noise-driven
  shapes in layers) stays: `f` in the scene switches.
- **Firewood**: a tipi of four organic logs (wobbling, tapering outlines, a knot, branch stubs) leaning in
  over the fire, two behind the flames and two in front, one lying across the front with its end grain;
  bark (`textures/world/bark/bark-07`, coarse), charred towards the fire's heart, its cracks glowing and
  flickering; Nikki's crayon outline (`src/drawn-stroke.lua`).
- **Sparks** drifting and swirling up; **embers** as soft breathing glows at the foot.
- **Light**: a point LIGHT on a body that touches nothing (label 'campfire'), flickering in strength and
  wandering with the flames; a glow round the fire and a pool on the ground; **pools on the walls** from
  any point light (`src/walls.lua`: the shaders don't light walls). In a sky scene the hour's sun, moon and
  sky light stay on beside a scene's own lamps (`src/render/shaders.lua`, `withSceneLights`), so the
  campfire has the moon round it.

## Next

- [ ] **CF1. Nikki plays with it**: the flames' colours and size, the logs, `bands` / `fps` on keys to try.
- [ ] **CF2. Smoke**: soft grey drawn blobs (or hair strokes) eroding as they rise and drift.
- [ ] **CF3. The fire throws shadows**: its point light into the wall and 3D shadows (projected-shadows
  already takes a lamp at a point), the Mipos' shadows long behind them on the wall and the ground.
- [ ] **CF4. Heat haze** above the flames (needs the scene drawn into a canvas first).
- [ ] **CF5. On the shelf**: a fire prop any scene can place (EDITOR-ARRANGE / ENGINE-MERGE EM2).
