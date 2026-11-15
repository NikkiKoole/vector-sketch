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
- [x] **SK2. The clock lights the scene.** Done 2026-11-11 (Nikki: "now the light and sky"): `src/sky-light.lua`,
  the light scene's five looks (golden hour included) and arcs; a sky scene's level gets its own lights
  (sun, moon, sky light, back light) filled every frame, the contact, wall and 3D shadows turned and
  stretched with them, a no-sky scene's noon defaults untouched (spec/sky-light_spec.lua, minute by minute:
  no jumps). The walls take the hour's light too (`skyLight.ambient`; Nikki "y walls"). Was: At the light levels (src/scene-light.lua), the default sun and
  sky light follow the hour: the light scene's five looks, the sun and moon on their arcs, the back light.
  A scene without sky keeps today's fixed noon.
- [x] **SK2b. A later sunset** (Nikki 2026-11-15: "a", of a later sunset or earlier looks). The golden hour and
  dusk were timed after the sun had set (18:00): 18:00-19:30 had almost no light, no back light (0.05) and
  no shadows. Now the sun 6:00-20:00, the moon 19:00-7:00, golden at 19:00, dusk 20:00, night from 21:30,
  the sky gradient the same (day to 18:00, dusk 20:00, night 21:30), the dusk moon 0.3 (0.1 left a second
  dip). Sampled every 5 minutes: the back light's biggest step 0.14, the shadows' 0.09; 19:00-21:00 an
  orange back light 1.8-2.2 with shadows all the way.
- [~] **SK2c. The moon the other way** (tried 2026-11-15: Nikki "it would be cool if the arc went opposite, so the
  moon starts right side and goes left"; the shadows then swing back and forth like a pendulum, never across.
  Rolled back the same hour: "what is a relaxed realistic way"; a real full moon rises opposite the setting sun.)
- [x] **SK2d. Twilight** (Nikki 2026-11-15: "a relaxed realistic way", after SK2c). The moon rises opposite
  the setting sun (a full moon's way), so the shadows change sides at each handover; they did it visibly,
  swept over the top at ~60% between 19:30 and 20:00. Now the directional shadows (wall, 3D; not the
  contact ones) are as strong as one light outshines the other: they soften away as the sun sinks (19:15-19:50),
  turn while they're 1-9% (the direction by the squared strengths, so the turn sits at the even moment), and
  the moon's come in (to ~0.5 by 20:30); the sky light and the back light stay. Morning the same (5:30-7:00).
  spec: no visible turn in any minute.
  Then (Nikki: "still the shadows are a bit weird, where they show up after sunset?", the first of three
  guesses): the moon's came in under a sunset still glowing. Now they wait for the sky to go dark (the sky
  light falling from 0.6 to 0.42), and the shadows' way follows the shadows' own strengths (the back light
  the lights'): the sun's soften 19:15-20:15, none 20:15-20:35 under the glow, the moon's 20:40-21:10;
  morning the moon's go as the dawn sky brightens (5:20-6:00), the sun's from 6:00.
  Then (Nikki: "something flips in the face shader or something when the day starts"): the back light swapped
  sides at full strength (6:08, 19:47; the rim on hair and head edges jumped). It follows the shadows' way now
  and dims through their turn (out 5:50-6:00 and 20:00-20:20, back by 6:15 and 20:45); spec: no visible
  back-light jump in any minute.
- [x] **SK2e. The moon from behind** (Nikki 2026-11-15, "y looks interesting this"; from the light lab,
  2026-11-06). With a floor (light 'full'): by day the 3D light in front of the things, shadows back along the
  floor and up the wall; as the moon's shadows take over (the twilight, while there are none) the light goes
  round behind them (sky-light: z by the shadows' sunShare), and the moon's shadows fall forward over the
  ground in front, drawn just above that ground's pictures under the things (projected-shadows lib.splits,
  an engine system). The light section's 'moon from behind' (on unless moonInFront is saved). Scene
  `sunyard` to see it. Faint at night: moonlight on dark soil.
- [ ] **SK3. The light scene on the engine clock.** light-grass-check drops its own clock and day looks
  for SK1/SK2's; its lamps, festoon and panel extras stay.
- [ ] **SK4. Space, as a scene option.** 'space above' in the sky section: the camera may climb (edge
  pan while dragging, no ceiling on its bounds), the gradient goes to black and starry at any hour, and
  above the atmosphere gravity fades out (each body's gravity scale by its altitude). Off: the sky is
  only a backdrop.
- [ ] **SK5. The moon.** Small in the sky from the ground, by the hour; climbing, it slides into a real
  one (a static body at 120000) that pulls near it.

Later, if wanted: clouds that take the sky's colour around them (CLOUDS.md), far hills.
