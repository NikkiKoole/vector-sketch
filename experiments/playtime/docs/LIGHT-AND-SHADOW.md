# Light and shadow — lamps, colour, roundness, and later shadows

status: active

Started 2026-11-06 from the light round in `LITTLE-USED.md`. The workbench is the scene
`light-grass-check` (scripts/tests): a sun, a warm and a cool lamp to carry about in play mode, a
turning lamp, six plasticine shapes; 1 day, 2 evening, 3 night, 4 the turning lamp; g z f b n step the
shapes' light settings, 0 shows them as every other scene draws them (the keys are in its script's top
comment).

What there is (`src/render/shaders.lua`): LIGHT sfixtures (directional, point or sky) reach the plasticine
and hairs shaders, up to 8 at once. A light's colour tints a shape (the lights' colours averaged by how
much each reaches); its intensity and nearness decide how lit the shape is. The shapes' own settings,
all off by default (the defaults draw byte for byte as before):
`plasticineLightGain` (how far the light brightens and darkens: 0 = x0.82..x1.09, else x(1-g)..x(1+g)),
`plasticineLightZ` (0.9: the light mostly from the front; lower and its side shows more),
`plasticineLightAdd` (lights add up, the sky the base: LS3),
`plasticineFormBaked` + `plasticineFormRise` (the roundness baked from the picture's mask,
`src/render/form-bake.lua`, after the glass bead spike: 1 a dome, 0.2 a pebble; the shader's own guess
rounds only the outer edge).

Things found on the way: a directional light lit the side facing away from where it's aimed (fixed,
spec/light-aim_spec.lua); a directional light fades with its lamp's distance (`range`; 0 means no
fade, a sun, but the panel can't set 0).

- [x] **LS1. More lamps and colour.** 8 lights, the scene's lamps and times of day (2026-11-06).
- [x] **LS2. Roundness baked from the mask**, next to the quick guess, switchable (2026-11-06).
- [x] **LS8. Sky and ground light.** A light type `sky`: its colour from all of above, its ground
  colour (`groundHex`, a row on the light's panel) from all of below, wherever the light is; above is
  the world's above (spec/light-sky_spec.lua). In the scene per time of day, k off / on: it fills the
  sun's dark sides with the sky's blue (2026-11-06).
- [x] **LS3. Light that adds up.** How lit a shape was stopped at 1 (colours averaged): a second lamp
  near a lit shape added little, and a shape no light reached kept a middling brightness. A shape's
  `plasticineLightAdd`: the sky lights the base, every other light adds its colour and strength, a soft
  shoulder past full (as is up to 0.8, then towards 1.35); nothing reaching it, it's dark
  (spec/light-add_spec.lua). Off by default. In the scene on, a switches; the moods' intensities tuned
  for it (night lamps 2.0 and 1.6) (2026-11-06).
- [ ] **LS4. The settings in the panel.** Swing, front, baked and rise as rows in the texfixture's
  plasticine section; a sun (range 0) settable on the light's panel.
- [ ] **LS5. Mipos under the light.** The same light on a Mipo's parts, to judge it on what it's for
  (and against the hand-drawn look: shaders for moments, `feedback_handdrawn_over_shaders`).
  Ready to judge (2026-11-06): three Mipos in `light-grass-check`, their picture parts, limb ribbons
  and torso lit like the shapes (not the face's decals), m lit / as drawn. With the plasticine clay
  (grain, dents, sheen) the crayon strokes went muddy; without it (c, the default for the Mipos) they
  stay, the light and roundness on top. Night looks best: as drawn they sat bright in the dark. By
  day a little darker than drawn (the sun or sky could go up).
- [ ] **LS6. Contact shadows.** A soft dark patch under what rests on something (`DEPTH-LAYERS.md`).
- [ ] **LS7. Cast shadows.** Bodies throwing 2D shadows away from a lamp onto what's behind them.
