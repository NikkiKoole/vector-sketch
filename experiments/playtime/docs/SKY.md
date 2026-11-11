# Sky — a day-night sky gradient, and the climb to space

status: active

Nikki (2026-11-11): "I like the idea of a day-night cycle that shows us the sky gradient, and also we
should always have an option to go to space when dragging long enough." Not every scene: "we don't
always want to be able to drag a Mipo up there, it's just I want a system where we can have that to
space transition working over day, night etc."

Two sources, one sky:
- `../sky-atmosphere/` (2026-10-29, WORLD-BUILDING G5): how the sky looks. Colour stops over altitude
  (`palettes.lua`: 7 stops, night / dawn / day / dusk at the same heights, blended stop by stop in linear
  RGB, a timeline of the day), a shader that looks up each pixel's altitude from the camera, stars by
  night *and* by altitude, the moon small in the sky that slides into a real one, gravity fading out
  above the atmosphere. Heights kept as there (Nikki): black space at 60000 world units above the
  horizon, the moon at 120000.
- `scripts/tests/light-grass-check` (LIGHT-AND-SHADOW): what the hour does to the light. Five looks
  (night, dawn, day, golden hour, dusk) blended by the hour: the sun and moon on arcs with their colours
  and strengths, the sky light (sky colour from above, ground colour from below), the back light, how
  dark the shadows go.

One clock drives both, so the sky and the light always match. Part of ENGINE-MERGE (sky as a scene
setting, decided 2026-11-10 in LANDING-2026-11) and LIGHT-AND-SHADOW LS13 ("the sky: a colour, or a
time of day with the cycle").

## Steps

- [x] **SK1. The sky gradient and the clock in the engine.** Done 2026-11-11 (no stars: Nikki "take the stars
  out"). With a sky, the wall shadows fall on the backdrops only (scene-light 'falls on' auto). `src/scene-sky.lua`: sky-atmosphere's
  palettes and shader drawn behind everything, the hour and "the day runs" (day length) on state; a sky
  section in the settings panel (on/off, hour, day runs, day length, the horizon's y), saved with the
  scene (nothing when off). Altitude counted up from the scene's horizon.
- [ ] **SK2. The clock lights the scene.** At the light levels (src/scene-light.lua), the default sun and
  sky light follow the hour: the light scene's five looks, the sun and moon on their arcs, the back light.
  A scene without sky keeps today's fixed noon.
- [ ] **SK3. The light scene on the engine clock.** light-grass-check drops its own clock and day looks
  for SK1/SK2's; its lamps, festoon and panel extras stay.
- [ ] **SK4. Space, as a scene option.** 'space above' in the sky section: the camera may climb (edge
  pan while dragging, no ceiling on its bounds), the gradient goes to black and starry at any hour, and
  above the atmosphere gravity fades out (each body's gravity scale by its altitude). Off: the sky is
  only a backdrop.
- [ ] **SK5. The moon.** Small in the sky from the ground, by the hour; climbing, it slides into a real
  one (a static body at 120000) that pulls near it.

Later, if wanted: clouds that take the sky's colour around them (CLOUDS.md), far hills.
