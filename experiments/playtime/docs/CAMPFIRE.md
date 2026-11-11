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
- **Day and night** (Nikki 2026-11-11: "during the day the fire is not causing that many shadows and light
  and during the night it is"): the fire's light, shadows and glow each go from a day value to a night value
  following the sun (`fire.nightness`: src/sky-light.lua's sun arc, from the sky's hour whatever the light
  level): half as the sun touches the horizon, the change spread over the panel's `dusk` hours of the sun's
  height round sunset and sunrise (4: 16:00 to 20:00), eased at both ends. The first try followed the hour's
  light, which drops within about an hour (and isn't there with the light level off: the fire stood still).
  A panel bottom right with the sliders (h hides); the values live on `state.campfire.settings`, not saved
  with the scene yet. Judge it with a long day (settings -> sky): at a 10 s day an hour is 0.4 s.

## Next

- [ ] **CF1. Nikki plays with it**: the flames' colours and size, the logs, `bands` / `fps` on keys to try.
- [ ] **CF2. Smoke**: soft grey drawn blobs (or hair strokes) eroding as they rise and drift.
- [x] **CF3. The fire throws shadows** (2026-11-11): the scene sets `state.projectedShadows` each frame with
  one point lamp where the flames are (`fire.light`), `FIRE_IN_FRONT` (120) in front of the Mipos, the wall
  `WALL_BEHIND` (160) behind them: big, stretched shadows up the wall, wobbling with the flames, their edge
  softening with the flicker. Darkening only (no `glow`: the wall's warm pool already comes from
  src/walls.lua), strongest at night, faint by day beside the sun's. Nikki to judge: size (`FIRE_IN_FRONT`),
  strength, whether the shadows should be holes in the pool (`glow`) instead.
- [ ] **CF4. Heat haze** above the flames (needs the scene drawn into a canvas first).
- [ ] **CF5. On the shelf**: a fire prop any scene can place (EDITOR-ARRANGE / ENGINE-MERGE EM2).
