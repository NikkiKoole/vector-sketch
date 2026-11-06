# Light and shadow — lamps, colour, roundness, and later shadows

status: active

**Picking up (2026-11-06, end of the day):** everything below is built and judged; it all lives in one
test scene's script so far. Next is LS12 (measure it on the phone), then LS13 (make it a scene setting
so any room can have it). Nikki also wants more cast shadow work: LS14 and LS16-LS21 (on things, on the
floor, softness by distance, coloured, parts on parts, clouds); LS19 (coloured) is the cheapest. To see where it stands: `./playtime.sh start`, open the scene
`light-grass-check` (scenes tab), press **o** (everything on at the liked settings: lights and
shadows on, Mipos lit with clay, smooth clay wall, the day-night cycle from 9:00). Its keys are in the
script's top comment (`scripts/tests/light-grass-check.playtime.lua`) and on its status line.
Where the code is: `src/render/shaders.lua` (lights, sky / back types, adding up, baked form),
`src/render/form-bake.lua`, `src/contact-shadows.lua`, `src/backdrop-shadows.lua` (both called around
the textured world in main.lua, off unless a scene sets `state.contactShadows` /
`state.backdropShadows`), the panel rows in `src/texfixture-params.lua` and `src/sfixture-params.lua`.
The scene script does the rest: the day-night clock and its five looks, the sun and moon on their arc,
lighting the Mipos' parts every frame, the plaster wall's shader, the wall shadows' length.

Started 2026-11-06 from the light round in `LITTLE-USED.md`. The workbench is the scene
`light-grass-check` (scripts/tests): a sun and a moon, a warm and a cool lamp to carry about in play
mode, a turning lamp, a sky light and a back light, six plasticine stones (smooth clay to rough
render), a plaster fence, three Mipos, a plaster back wall.

What there is (`src/render/shaders.lua`): LIGHT sfixtures (directional, point, sky or back) reach the plasticine
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
fade, a sun: the panel's `fades` switch, LS4).

- [x] **LS11. Plaster and clay.** In light-grass-check (2026-11-06, Nikki: "grit to the background ... fences
  or obstacles with different roughness ... plaster or clay"): the back wall gets a plaster shader of
  the scene's own (a sand speck and a bumped relief from noise, lit from the sun or moon, around the
  wall's own colour; q: smooth / fine / coarse plaster); the six stones go from smooth clay to rough
  render (the plasticine grain, dents, grain size and sheen per stone, labelled) and a fence of
  coarse plaster stands on the right, its posts and rails her drawn body pictures. The first wall
  shading darkened everything to grey stone (a flat bit counted as half in shadow); centred now.
- [x] **LS1. More lamps and colour.** 8 lights, the scene's lamps and times of day (2026-11-06).
- [x] **LS2. Roundness baked from the mask**, next to the quick guess, switchable (2026-11-06).
- [x] **LS8. Sky and ground light.** A light type `sky`: its colour from all of above, its ground
  colour (`groundHex`, a row on the light's panel) from all of below, wherever the light is; above is
  the world's above (spec/light-sky_spec.lua). In the scene per time of day, k off / on: it fills the
  sun's dark sides with the sky's blue (2026-11-06).
- [x] **LS9. Back light (rim).** A light type `back`: from behind a shape, towards you; its edges glow in
  the light's colour, most those facing where it comes from (body +X the way it shines), the middle not
  at all; added on top like the sheen. Its own narrow edge measure (the picture's alpha just around),
  so fur's small gaps don't sparkle (the form's wide measure lit half a stone). Built 2026-11-06, to
  judge: light-grass-check, l off / on; evening orange from the low sun, night the moon's blue, day a
  faint white (spec/light-back_spec.lua). On a drawn stone it mostly lands on the black outline; on
  the Mipos' fur strokes it shows best. It's also the parked claymation plan's "rim tinting from the
  opposing light".
  Nikki: "backlight i like but also need settings" (2026-11-06): its width on the light's panel (LS4).
- [x] **LS10. A day-night cycle.** Built 2026-11-06 in light-grass-check, to judge: a clock (d runs a day
  in two minutes, , and . an hour, 1 noon, 2 dusk, 3 midnight); five looks blended by the hour, after
  ../sky-atmosphere's timeline (WORLD-BUILDING G5) plus a golden hour at 18:00 (blue straight to
  orange went through a muddy grey): the sky, the sun's and moon's colour and strength, the lamps (on
  at night), the sky light, the back light, both shadows' darkness. The sun rises on the left at 6,
  sets on the right at 18 on an arc over the scene, shining at its middle, fading in and out at the
  horizon; the moon the other way round the night; the wall shadows swing with them, the back light
  comes from the stronger. The wall shadows by the sun's height too (Nikki: they should depend on the
  time of day): a high sun throws them short, almost straight down and crisp, a low one long and
  sideways and softer (never up the wall), and they fade at the handover: as strong as the leading
  light is stronger than the other, so the moon's fade out and the sun's in, swapping sides while
  faint (Nikki saw a jump around 07:00: they flipped sides at 6:00, and taken from where the sun
  aimed, their length stuck at its longest until 6:50; now from its height on the arc).
  The back light and the wall's relief jumped sides just after 18:00 (Nikki), taken from the stronger of
  sun and moon: now the way both shine added up by strength, the back light fading while there's little
  of it, so it swings round almost off (out by 18:05, back by ~19:40; dawn quicker).
  Nikki: "nice" (2026-11-06). Scene-only for now: a real scene would want it as a world setting
  (G5's open question: the sky per scene, with a time of day).
- [x] **LS3. Light that adds up.** How lit a shape was stopped at 1 (colours averaged): a second lamp
  near a lit shape added little, and a shape no light reached kept a middling brightness. A shape's
  `plasticineLightAdd`: the sky lights the base, every other light adds its colour and strength, a soft
  shoulder past full (as is up to 0.8, then towards 1.35); nothing reaching it, it's dark
  (spec/light-add_spec.lua). Off by default. In the scene on, a switches; the moods' intensities tuned
  for it (night lamps 2.0 and 1.6) (2026-11-06).
- [x] **LS4. The settings in the panel.** A texfixture's light rows (both plasticine and hairs): adds up,
  swing, from front; plasticine also baked form and its rise (shown with a baked form). The light's
  panel: a directional light's `fades` (off: range 0, a sun), the range only where it counts
  (directional that fades, point), a back light's `width` (extra.rimWidth, how far in its rim reaches;
  it rides in the light's range slot, which a back light doesn't use) (spec/light-settings_spec.lua;
  the editor-actions sweep on light-grass-check clicks them all, clean) (2026-11-06).
- [x] **LS5. Mipos under the light.** The same light on a Mipo's parts, to judge it on what it's for
  (and against the hand-drawn look: shaders for moments, `feedback_handdrawn_over_shaders`).
  Ready to judge (2026-11-06): three Mipos in `light-grass-check`, their picture parts, limb ribbons
  and torso lit like the shapes (not the face's decals), m lit / as drawn. The plasticine clay
  (grain, dents, sheen) on the Mipos in this scene: on for now (Nikki, 2026-11-06), c takes it off
  (Claude first had it off, from screenshots: the crayon strokes looked muddier). Night looks best: as drawn
  they sat bright in the dark. By day a little darker than drawn (the sun or sky could go up).
  Nikki: "looks really nice!" (2026-11-06, seen without the clay).
- [x] **LS6. Contact shadows.** A soft dark patch under what rests on something (`DEPTH-LAYERS.md`).
  Built 2026-11-06, for Nikki to judge: `src/contact-shadows.lua`, on while a scene sets
  `state.contactShadows` (light-grass-check: h, how dark by the time of day). A caster (of a Mipo only
  its feet, hands and torso) finds the up-facing surface under it with three short rays; the shadow
  is a soft oval on that surface, darker and tighter the closer it is, cut with a stencil to what's
  *drawn* of the surface (its pictures, else its collision shapes): no shadow over nothing, past an
  edge or over a picture's see-through corners (Nikki saw one float in the sky over a stone, and a
  Mipo standing on the stone's square). Deep enough to reach past a drawn outline. Drawn just above
  the surface's own pictures (state.drawSplits). The scene's stones got their pictures' outlines as
  collision shapes (shape8-dict), so things stand on the drawn stone (spec/contact-shadows_spec.lua).
  Nikki: "its nice" (2026-11-06); it fades out as a thing rises (by design, it's about touching),
  where you still want a shadow: that one belongs on the backdrop, LS7.
- [x] **LS7. Cast shadows.** Bodies throwing 2D shadows away from a lamp onto what's behind them.
  Nikki (2026-11-06): the shadow you still want when the contact shadow has faded (a thing lifted or
  jumping) is this one, on the vertical plane behind: the backdrop.
  Built 2026-11-06, for Nikki to judge: `src/backdrop-shadows.lua`, on while a scene sets
  `state.backdropShadows` (a wall shape, the shift, blur, how dark). The textured world drawn once more
  into a canvas, shifted the way the sun or moon shines (how far the wall is behind), blurred, laid on
  the wall as soft black and cut to it with a stencil: none on the open sky. light-grass-check paints a
  plaster back wall behind the stones (w off / on); evening's low sun throws long shadows, the moon
  throws them down-left (spec/backdrop-shadows_spec.lua). Not yet: a lamp in the middle throwing
  shadows both ways (one direction for the whole scene), and it costs a second textured pass a frame
  (measure on the phone before a real scene uses it).
  Nikki: "looks nice" (2026-11-06).

## Next (written down 2026-11-06, to pick up)

- [ ] **LS12. Measure it on the phone.** Before building on it: the iPhone SE 2 is the floor, ~20 Mipos
  a room the design limit (MEASURING M10). What costs: the wall shadows draw every picture a second
  time a frame; every lit part runs the plasticine shader with up to 8 lights (and the baked form's
  texture); the contact shadows cast three rays per caster (5 per Mipo); the plaster wall's noise is
  per pixel. `./playtime.sh device` and `./playtime.sh bench device` (`--parts` for love.update), with
  light-grass-check and a room of ~20 lit Mipos; each part switched off in turn (its keys) to see
  what it costs. Write the numbers here; decide what a real scene can afford.
  First numbers (2026-11-06, iPhone SE 2, light-grass-check, 3 Mipos, everything lit as o, 16:00, draw ms
  p50, 6 s each): no shadows 5.4; + contact 6.0; + soft wall 10.9; contact + 3D hard (sun) 10.9; 3D with
  sun and both lamps 10.9; the same with the big soft lamp (13 rays) 10.5; contact + 3D + soft wall 15.2.
  So a shadow costs ~5 ms, all of it drawing the textured world again (CPU); the 3D rays, more lights
  and soft edges are lost in the noise. Soft and 3D together draw it twice more: sharing one silhouette
  canvas between them would save ~4-5 ms. The bigger cost isn't the shadows: the scene script's update
  is 17.7 ms a frame (~9 ms a physics step: lighting every Mipo part, looking lights up by label, every
  step), the frame 30-35 ms, ~30 fps.
  Fixed in the script itself (Nikki: in the spike first): the lights, the shapes' and the Mipos' parts
  found once and kept (looked for again when a body's gone, the body count changes, or once a second),
  the shapes' settings read once instead of once per part, and the light work done once a frame (from
  drawBelow) instead of every physics step: 0.1 ms a frame (on the status line). Measured again: the
  update 0.5 ms, 60 fps steady with every shadow setting; draw p50 no shadows 5.1, contact 5.1,
  + soft wall 9.7, contact + 3D 9.7, contact + 3D + soft wall 13.8 (the first run after the fix read
  far worse, a hot or busy phone: measure twice). Then the soft and the 3D shadows share one silhouette
  canvas (`src/shadow-silhouettes.lua`, drawn once a frame; the soft one shifts it as it lays it down):
  contact + 3D + soft wall 13.8 -> 10.7 ms, the same as one of them alone (10.6-10.7 that run).
- [ ] **LS13. Light as a scene setting.** So any room gets it without a script: a light section in the
  world settings, saved with the scene: the sky (a colour, or a time of day with the cycle; G5's open
  question in WORLD-BUILDING, a sky per scene), sun and moon, sky light, back light, contact and wall
  shadows on/off, which body is the back wall (and its surface: flat, smooth clay, plaster), and
  "Mipos take the light" (with or without clay). What the scene script does now (the clock, the
  looks, the arc, lighting the Mipos' parts, the wall's shader, the shadows' length) moves into src.
  Then try it in a real room (the dollhouse, the overworld).
- [ ] **LS14. A lamp's wall shadows both ways.** Now one direction per scene (from the sun or moon): a
  lamp in a room's middle should throw shadows away from it on both sides, which needs a pass per
  thing (or per side). Only if a real room wants it (after LS12).
- [ ] **LS16. Shadows on things, not only the wall.** A Mipo's shadow falling across the stone or fence
  beside it, or on another Mipo: the shifted silhouettes (the wall shadow's canvas) cut to what's
  behind each thing, not to the wall; needs an order of what's in front (z, or DEPTH-LAYERS).
- [ ] **LS17. Shadows on the floor.** In a side view the ground strip catches a long, squashed shadow
  stretching away from a low sun: between the contact shadow (touching) and the wall shadow (behind).
  The silhouette flattened onto the ground's top band, its length from the sun's height.
- [ ] **LS18. Softness by distance.** Close to the wall a sharp shadow, far from it soft and wide: the
  blur (and shift) per thing by how far in front of the wall it stands, so the Mipos in front of the
  stones throw softer ones than the stones. Needs a per-thing depth, like LS16.
- [ ] **LS19. Coloured shadows.** Not plain black: tinted with the sky's colour (blue under a warm sun,
  warm under the cool moon), the painterly look of the mood pictures (MATERIALS.md: no hard black).
  Cheap: the shadow's colour from the sky light, in both shadow modules.
- [ ] **LS20. Parts shadowing each other.** A Mipo's arm darkening its torso where it lies over it
  (soft occlusion between a Mipo's own parts, by their z order).
- [ ] **LS21. Cloud shadows.** Clouds drifting over the ground and the wall (CLOUDS.md's spike: "near
  clouds cast shadows on the grass"), with the day-night light.
- [ ] **LS22. 3D shadows: along the floor and up the wall, hard.** Nikki (2026-11-06): "the next level of
  shadow casting, a sort of 3D shadow that grows and shrinks and is cast hard"; the long floor shadow
  first, the torch on the wall too; the edges she has to see. Built 2026-11-06, to judge:
  `src/projected-shadows.lua`, on while a scene sets `state.projectedShadows`. The things stand at a depth
  in front of the wall, so the wall's foot moves up and the band between is the floor behind them; a
  point lamp (x, height, depth) or a sun (the way to it) throws each silhouette along that floor and up
  the wall: per pixel a ray to the light, where it crosses the things' plane the textured world (drawn
  once more into a canvas) says shadow or not. A low sun stretches them long over the floor and up at the
  corner; a lamp close to the things throws a giant one on the wall, further off it shrinks (also LS14:
  a lamp in the middle throws both ways). Edges: hard, or a small or big lamp (the penumbra wider the
  further the shadow lands, LS18's look for free). In light-grass-check: v on (in place of w's), e the
  sun or moon / the warm lamp (drag it in play mode), [ ] the lamp's depth, y the sun's way out of the
  wall, j edges (spec/projected-shadows_spec.lua). The ground (Nikki: "a sort of ground to cast on too ...
  what we did over at burrow"): with v on, packed earth seen from a little above from the wall's foot to
  the ground's front edge (grain, worn patches, pebbles, darker into the corner), the earth cut open below
  the edge (burrow's topsoil to clay, grain, fine roots), burrow's crayon strokes along the edge and in
  the corner; the floor behind the things under the shadows, the rest under the things (a draw split).
  Several lights (Nikki: the soft and hard shadows together liked, then shadows from more than one light):
  `lights = { ... }`, each its own pass over the same silhouettes, darker where they cross; e steps the
  sun or moon / the warm lamp / sun and warm lamp / sun and both lamps; w's soft wall shadow can be on too.
  Coloured (LS19 for these shadows; x black / coloured): in one light's shadow the other lights and the
  sky still reach, so it takes their colour, darkened (SHADOW_TINT 0.4).
  Not yet: one depth for everything (per-thing depth,
  LS16/LS18), nothing on the floor in front of the things, the same cost as the wall shadows (LS12).
- [ ] **LS15. Small ones:** should a new directional light be a sun (not fade) by default; the back
  light on a drawn stone lands on its black outline (reach past it, as the contact shadow does);
  grass on a moving body rebuilds its blades every frame (LITTLE-USED, the grass round).

Not light, but where this started (`LITTLE-USED.md`): three rounds left there, skinned mesh, UV mesh,
the recorder (the feature-rounds sweep, `claudetools/feature-rounds_spec.lua`, takes a recipe each).
