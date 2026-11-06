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
- [ ] **LS3. Light that adds up.** How lit a shape is stops at 1: a second lamp near a lit shape adds
  nothing, so night is only dark away from the lamps. Decide: lights that add (and can over-light),
  or an ambient level per scene that the lights add to.
- [ ] **LS4. The settings in the panel.** Swing, front, baked and rise as rows in the texfixture's
  plasticine section; a sun (range 0) settable on the light's panel.
- [ ] **LS5. Mipos under the light.** The same light on a Mipo's parts, to judge it on what it's for
  (and against the hand-drawn look: shaders for moments, `feedback_handdrawn_over_shaders`).
- [ ] **LS6. Contact shadows.** A soft dark patch under what rests on something (`DEPTH-LAYERS.md`).
- [ ] **LS7. Cast shadows.** Bodies throwing 2D shadows away from a lamp onto what's behind them.
