# Light and shadow — lamps, colour, roundness, and later shadows

status: active

**Picking up (2026-11-06, end of the day):** Nikki: "I like where we are with the light"; the shadows
are done until they move into the engine (LS13). Everything up to LS22 is built and judged in one test
scene, `light-grass-check`. Since lunch: 20 lit Mipos run at 60 fps on the iPhone SE 2 (LS23: the light
search and per-part sends fixed, ~9.8 -> ~1.8 ms), shadows every other frame and only what shows in a
shadow (LS25), so lit + 3D is ~41-53 fps; dawn and dusk smooth and not too dark (sun and moon blended,
no picking; the sky light's own strength). Open: LS13 (light as a scene setting, so a real room gets
it; decide LS23's costs there), LS24 (draw once for screen and shadows, probed, wait for a real room),
LS20 (a Mipo's parts shadowing each other), LS21 (cloud shadows), LS15 (small ones).
To see it: `./playtime.sh start light-grass-check`; the panel (top left; – folds it, p hides it) has
everything: 'back to the liked settings' for the lights, then '3D shadows (and the ground)', 'backdrops
at depths', 'stones further back', 'from …' (which lights), 'a lamp circling round', 'night'. The keys
still work (the script's top comment).
Where the code is: `src/render/shaders.lua` (lights, sky / back types, adding up, baked form),
`src/render/form-bake.lua`, `src/contact-shadows.lua`, `src/backdrop-shadows.lua` (the soft wall
shadows), `src/projected-shadows.lua` (the 3D ones: wall, floor, boards, the ground in front, lanes,
a lamp's glow), `src/shadow-silhouettes.lua` (the world drawn once a frame for the shadows; one lane at a
time with `drawTexturedWorld(world, only)`), all off unless a scene sets `state.contactShadows` /
`backdropShadows` / `projectedShadows`, hooked around the textured world in main.lua; the panel rows in
`src/texfixture-params.lua` and `src/sfixture-params.lua`. The scene script does the rest: the clock and
its five looks, the sun and moon (sun from in front, moon from behind), the circling lamps, lighting the
Mipos' parts (their own frontal light and swing), the wall, floor, ground and boards, the panel.
Parallel sessions: one game window each, its own port (8001 this one, others on 8002+); check the port
is held by your own pid (`lsof -nP -iTCP -sTCP:LISTEN`) before sending anything.

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

- [x] **LS12. Measure it on the phone.** Before building on it: the iPhone SE 2 is the floor, ~20 Mipos
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
  Not measured yet: lanes (each drawn on its own, and the soft wall shadow then draws the world once
  more), the lamps' glow, the circling lamps. The materials session measured a lit Mipo at ~0.47 ms a
  frame on the phone (MATERIALS.md 'What the Mipo shaders cost'): LS23.
- [ ] **LS13. Light as a scene setting.** So any room gets it without a script: a light section in the
  world settings, saved with the scene: the sky (a colour, or a time of day with the cycle; G5's open
  question in WORLD-BUILDING, a sky per scene), sun and moon, sky light, back light, contact and wall
  shadows on/off, which body is the back wall (and its surface: flat, smooth clay, plaster), and
  "Mipos take the light" (with or without clay). What the scene script does now (the clock, the
  looks, the arc, lighting the Mipos' parts, the wall's shader, the shadows' length) moves into src.
  Then try it in a real room (the dollhouse, the overworld).
  Before it (ENGINE-MERGE.md, 2026-11-06): MATERIALS MT2 (which materials stay), then LS23 and LS15
  (a full room's defaults: clay or not, which Mipos are lit, a new lamp a sun or not).
  **How (Nikki 2026-11-06):** a light button under the sound button that steps through levels, "like
  disabling the volume": off -> lit -> shadows -> full, saved with the scene (LS23's levels). Each level a
  table of settings (`src/scene-light.lua` LEVELS), so tuning is editing data; a more flexible shader
  setup grows from that. Moving it in also makes speed-ups pay that didn't inside one test scene (LS24,
  fewer lights per part, lights and parts found once for every scene).
  **Slice 1 built (2026-11-06):** off and lit. `src/scene-light.lua`: the level on state, saved as the
  scene's `light` (nothing when off); lit puts light-grass-check's liked Mipo settings (clay off) on every
  Mipo part, contact shadows on, and, in a scene with no lights of its own, a sun high on the left and a
  sky light (its day values; `state.sceneDefaultLights`, read in `src/render/shaders.lua`). The settings
  come off again when the level drops and before a save (the part's own values back). Off touches
  nothing, so light-grass-check and mipo-materials work as before. spec/scene-light_spec.lua.
  **Slice 2 (2026-11-06): shadows** = lit + the soft wall shadows (src/backdrop-shadows.lua), away from
  the default sun, every other frame (LS25). What they land on: 'everything' behind the things for now
  (Nikki: rooms want that; "be a bit flexible, can this be changed later, with an option"): the level's
  `wall` names one of `scene-light.WALLS`, so 'backdrops only' or 'bodies marked as wall' slot in as other
  choices. The dollhouse at 60 fps on the Mac. A level only sets the shared state fields the scene hasn't
  set itself, and clears only those (`state.sceneLightOwned`).
  **Slice 3 (2026-11-06): full** = shadows + the Mipos in clay, and with a floor set the 3D shadows
  (src/projected-shadows.lua, from the sun a little out of the wall, strength 0.5) with the soft wall
  shadows only above the floor and lighter. The floor is a scene setting, `light.floor = { standY, depth }`
  (light-grass-check's GROUND_TOP and SOLID_DEPTH), set in the settings panel's new light section
  (src/light-params.lua: the level, 'floor = under the Mipos' from their feet, stand y, depth, 'no floor').
  One floor per scene: the dollhouse (storeys) leaves it unset and full there is shadows + clay. Seen in
  the kitchen: clay, contact shadows, the Mipo's 3D shadow along the floor and up the wall.
  Not moved in (scene-specific, left in light-grass-check): lanes, boards, the lamps' glow, the day's
  clock.
  **Measured (2026-11-06, iPhone SE 2, the kitchen with 20 Mipos, floor under them, draw p50 over three
  runs, ±1.5 ms between runs):** off 3.7 ms (frame 16.7, 60 fps); lit 8.5-10 (frame 16.7-17.2, about 60);
  shadows 11-13 (frame 19-22, ~46-50 fps); full ~11 (frame 18-20, ~50). The first lit run is dearer
  (14 ms: every Mipo picture's roundness baked the first time). So the steps aren't priced evenly: off ->
  lit is the big one (+5-6 ms, ~100 parts lit one by one), the shadows +1-3 (every other frame), full
  ~nothing more (clay is cheap, the 3D shadows share the outline pass). With 20 Mipos only off and lit
  hold 60. Slow frames also make the physics catch up (1.4 -> 2 steps a frame). The lever: lighting a
  part for less (its settings sent once, not every frame: setSurfaceShader's per-part sends). Next: measure each level on the phone (`./playtime.sh bench device`, a room of ~20 Mipos);
  then the details behind the button's arrow (time of day, which wall, a floor picker drawn on stage).
- [x] **LS14. A lamp's wall shadows both ways.** Now one direction per scene (from the sun or moon): a
  lamp in a room's middle should throw shadows away from it on both sides, which needs a pass per
  thing (or per side). Only if a real room wants it (after LS12).
  Done another way (2026-11-06): the 3D shadows (LS22) project from a lamp's point, so a lamp in the
  middle throws them away from it on every side.
- [x] **LS16. Shadows on things, not only the wall.** A Mipo's shadow falling across the stone or fence
  beside it, or on another Mipo: the shifted silhouettes (the wall shadow's canvas) cut to what's
  behind each thing, not to the wall; needs an order of what's in front (z, or DEPTH-LAYERS).
  Done 2026-11-06 in LS22: lanes at depths, drawOnThings (a Mipo's shadow on the stones behind it).
- [x] **LS17. Shadows on the floor.** In a side view the ground strip catches a long, squashed shadow
  stretching away from a low sun: between the contact shadow (touching) and the wall shadow (behind).
  The silhouette flattened onto the ground's top band, its length from the sun's height.
  Done 2026-11-06 in LS22: the floor behind the things and the ground in front of them.
- [x] **LS18. Softness by distance.** Close to the wall a sharp shadow, far from it soft and wide: the
  blur (and shift) per thing by how far in front of the wall it stands, so the Mipos in front of the
  stones throw softer ones than the stones. Needs a per-thing depth, like LS16.
  Done 2026-11-06 in LS22: a lamp of a size (the 'edges' setting) softens a shadow more the further it
  lands from its thing, per lane, and the boards at depths show it.
- [x] **LS19. Coloured shadows.** Not plain black: tinted with the sky's colour (blue under a warm sun,
  warm under the cool moon), the painterly look of the mood pictures (MATERIALS.md: no hard black).
  Cheap: the shadow's colour from the sky light, in both shadow modules.
  Done 2026-11-06 for the 3D shadows (LS22): each takes the other lights' and the sky's colour, darkened
  (x / the panel's 'coloured shadows'). The soft wall shadows are still black.
- [ ] **LS20. Parts shadowing each other.** A Mipo's arm darkening its torso where it lies over it
  (soft occlusion between a Mipo's own parts, by their z order).
- [ ] **LS21. Cloud shadows.** Clouds drifting over the ground and the wall (CLOUDS.md's spike: "near
  clouds cast shadows on the grass"), with the day-night light.
- [x] **LS22. 3D shadows: along the floor and up the wall, hard.** Nikki (2026-11-06): "the next level of
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
  Backdrops at depths (Nikki: "a few backdrops at different depths to see how shadow affects"): boards
  = { {x0, x1, z, height} } on projectedShadows, flat boards standing on the floor between the wall and
  the things; a shadow lands on the nearest one covering the spot, so close behind the things it's near
  their size and crisp, further back bigger and softer. light-grass-check: three plaster boards at 90,
  210 and 330 in front of the wall (the panel's 'backdrops at depths'); the soft wall shadows skip them
  (backdropShadows.notOn).
  Things at depths (LS16, LS18): layers = { { z, only = function(body) } } back to front; each lane throws
  from its own depth (each drawn on its own: drawTexturedWorld(world, only)), and drawOnThings (after
  the textured world) paints the shadows landing on things further back, only where that thing is the
  front-most drawn (a depth picture of the lanes). Further back means higher up the floor, so
  light-grass-check lifts the six stones onto a back lane (230 in front of the wall, the Mipos and the
  fence at 400; their shapes sensors meanwhile, so Mipos walk past): panel 'stones further back', with
  3D on. The boards moved to 50, 110, 170 to stay behind the stones.
  On the ground in front (Nikki: "shadows on the ground in front of things"): a spot in front of the
  things takes its light from behind them, so a lamp between them and the wall (the lamp distance below
  0) or a sun from behind ('sun out of wall' below 0) throws their shadows forward. The scene draws that
  ground late (a split, over the ground's plain shape), so it calls projectedShadows.drawFront (in the
  script sandbox) after drawing it.
  A lamp's light (glow): in the dark the wall and floor are dark, so a shadow on them didn't show. A lamp
  now lights the wall, floor, boards and ground around it, added on and falling off with distance,
  except where its shadows are: at night the shadows are holes in its light (light-grass-check mixes
  glow and darkening by how dark the sky is).
  Circling lamps (Nikki: "more lights ... circling around differently"): a lamp on a ring round the
  scene in 3D (light-grass-check: the turning lamp's light, pink, 'a lamp circling round'), in front of
  the things, past the side and behind them, so its shadows swing from the wall round onto the ground in
  front; on screen an ellipse, drawn behind the things while it's behind them, bigger nearer you. 'warm
  and cool lamps circle too' puts those on the ring a third of the way round at other heights;
  'circling speed'; the light set 'both lamps'.
  Sun in front, moon behind (Nikki: "a sun that during the day cast shadow backward and a moon that cast
  forward"): with 3D on, the moon shines from behind the things, its shadows forward onto the ground in
  front, and throws no soft shadow back onto the wall; they swap at the handover, both faint then (the
  panel's 'moon from behind'). The sun's 3D shadows fade out near the horizon (they vanished at once just
  before 18:00).
  Mipos too dark by day (Nikki): they took the stones' light settings (light mostly from the side,
  frontal 0.35, a strong swing 0.5), so a flat drawing faced away from the light most of the day. Their
  own now: frontal 0.75, swing 0.3, and the sky light x1.3 (panel sliders 'Mipos: frontal', 'Mipos:
  swing', 'sky light strength'). Measured on the lit pixels at 12:00: drawn 128, before 129, now 136; at
  16:00 drawn 133, before 128, now 131. p hides the panel.
  Smoother dawn and dusk (Nikki: "some transitions aren't smooth ... mathematically like our sun and
  moon"): sampled every 3 minutes of the clock, the back light, both shadows' sides and the sky all
  changed within ~20 minutes of 6:00 and 18:00, at the places where the code picked the stronger of sun
  and moon. Now nothing picks: the sun and the moon each throw their own 3D shadows by their own
  strength (both at once around dawn and dusk); the soft wall shadow is their blend by strength; the back
  light turns from the moon's way to the sun's by their shares through 'from above', its strength from
  their sum. The moon is up 17:00-7:00 (overlapping the sun), both fade over ~1.5 h near the horizon,
  the sun's 3D shadows fade below 0.3 of its height. ; and ' step five minutes.
  Then extra dark around dusk and dawn (Nikki): the panel's sky light strength and the sun and moon's
  light for the wall shared one name (c.skyStrength), so the sky light went out with the sun: the total
  light (sun + moon + sky) fell to 0.04 at 18:15 and 0.29 at 6:00, between the day's 1.9 and the night's
  0.45. Own name now (c.skyLightStrength): the total slides from 1.98 by day to 0.74 at night, never
  below, the sky light carrying the twilight.
  Not yet: within a lane one depth (a Mipo's own parts, LS20) (per-thing depth,
  LS16/LS18), nothing on the floor in front of the things, the same cost as the wall shadows (LS12).
  Nikki: "I like where we are with the light" (2026-11-06).
- [ ] **LS23. Lit Mipos in a full room.** A lit Mipo costs ~0.47 ms a frame on the phone (the materials
  session's measure), so 20 of them ~9-10 ms on top of the shadows' ~5: tight at 60 fps. Measure a room
  of 20 lit Mipos with the 3D shadows; if it's too much, fewer lights per part, no clay by default, or
  lighting only the near ones. Decide before LS13 makes it a scene setting.
  **Direction (Nikki 2026-11-06):** "I basically want it all, but not always, in cost-efficient steps." So
  not one default but a light **level** per scene, LS13's main setting, each step adding the next cheapest:
  0 as drawn (no light) / 1 lit (Mipos lit without clay, contact shadows, ~6 ms for 20 Mipos) / 2 shadows
  (+ wall and 3D, one shared canvas, ~+4 ms) / 3 full (+ clay, lanes, lamp glow, ~+4-5 ms). A busy room
  1-2, a quiet one 3. Maybe later: step down by itself when frames run slow. The levels' exact contents
  are tuned when LS13 is built.
  Measured 2026-11-06 (iPhone SE 2, 3 Mipos, 60 fps throughout, draw p50 = the CPU's time; GPU-heavy
  pixel work only shows once a frame misses 60): no shadows 5.2; contact 5.3; + soft wall 8.1;
  contact + 3D + ground 8.2 (6.4 another run); + soft wall 8.2 (shared); + lanes 8.4, lanes + soft wall
  11.6 (the soft one draws the world again); + backdrops 8.2; plaster wall flat or smooth clay the same;
  night lamps: sun/moon 6.5, one glowing lamp 6.5, two 6.5, three circling 6.6, big soft edges (13
  rays) 6.8; everything on (lanes, backdrops, soft wall, three lamps) 8.6. So the CPU cost is the
  extra drawing of the world (~3 ms; again with lanes + soft wall); lights, glows, soft edges, the
  ground and the plaster are free on the CPU. Still to do: the GPU side (the shaderCost tool) of the
  plaster, earth and glow passes.
  20 Mipos (17 added with createCharacter + randomizeMipoConstrained, 14:00, draw p50): as drawn, no
  shadows 9.9 ms, 52 fps; lit without clay 58.8, 13 fps; lit with clay 60.4, 13 fps; + contact 62.7;
  lit + 3D 104.5, 8 fps. ProFi: gatherLightsForBody (src/render/shaders.lua) 90% of the frame, 630 calls
  a frame (every lit part, and again in the shadows' silhouette pass), each looping all of
  registry.sfixtures to find the lights (subtypes.is 790,000 calls a frame). The lighting itself is
  cheap; finding the lights per part is the cost. Levers: the light list kept (rebuilt when the
  sfixtures change), and the silhouette pass drawn without lighting (it only needs alpha).
  Both done (gatherLightsForBody walks registry.sfixturesOf(LIGHT); state.drawingOutlines while
  src/shadow-silhouettes.lua draws). 20 Mipos again: as drawn 10.1 ms draw; lit + clay 18.8 (was 60.4);
  contact + 3D, lit 26.9 (was 104.5); + soft wall 26.7; night, three circling lamps 27.6. Still 22-26 fps:
  the update is ~12 ms with 20 Mipos (physics, as drawn too), lighting ~9 ms (~0.45 ms a Mipo: the
  per-part uniforms), the shadows' outline pass ~8 ms (every part drawn again). Next levers: send a
  body's lights once for all its parts, the outline pass for the casters only, or less often.
  Measured again with the Mipos at rest (that run's 12 ms update was the 17 new ones still falling;
  each setting twice, the same): as drawn 60 fps (draw 4.3, update 3.3); lit + clay 60 fps (7.1 / 3.6);
  lit + clay + contact + 3D 44-48 fps (13.0 / 6.8: over a frame, so two physics steps a frame); no clay
  the same. So 20 lit Mipos fit at 60; the 3D shadows' outline pass (~6 ms with 20 Mipos) is what's
  left to win back for 60 with shadows.
  Shadows every other frame (state.shadowEveryOther, src/shadow-silhouettes.lua: the outlines drawn
  every second frame and kept in between; a moved or zoomed camera redraws them at once; the panel's
  'shadows every other frame', on in light-grass-check): 20 lit Mipos + 3D, each twice, draw 29.7 / 28.6
  ms every frame -> 25.0 / 24.2 every other, ~4.5 ms back. (That run's Mipos were still moving, 312 of
  322 bodies awake, update ~11 ms, so its totals are higher than the at-rest run's.)
  The lights worked out once a frame (the materials session, a006a2bd: shaders.newFrame; per part only
  the body's turn): same 20 Mipos, physics paused, the cache switched off and on from the bridge, each
  twice: lit, no shadows, draw 19.6 / 19.6 ms the old way, 15.9 / 16.2 cached, as drawn 9.8: lighting
  20 Mipos ~9.8 -> ~6.2 ms. What's left in setSurfaceShader: the scalar and material sends ~37%, the
  light arrays ~34%, the other shared uniforms ~28%: next, send only what changed (the materials session).
  Note: these phone runs were in the editor (the device build starts there), so box2d-draw's debug
  shapes (~18% of the draw) are in them; play mode doesn't draw those. Compare runs only within one
  install: how many Mipos land on screen changes the totals (paused is steadiest).
  Then only what changed sent (the materials session, 988e4ecd: a uniform skipped when equal to what the
  shader last got, the light colours/types/ranges once a frame): one install, paused, editor: as drawn
  7.6 / 7.6, lit 9.3 / 9.5 (60 fps), lit with the frame cache forced off 12.4; lit + 3D every other
  frame 17.3, 53 fps. Lighting 20 Mipos: ~9.8 ms in the morning, ~1.8 now. What's left for 60 fps with
  shadows is the outline pass (LS24, LS25).
- [ ] **LS24. Draw once for the screen and the shadows.** The outlines for the shadows are the world
  drawn a second time (~6 ms with 20 lit Mipos on the phone; every other frame halves it, LS23). The GPU
  can write two pictures in one pass (several canvases at once, `love.graphics.setCanvas` with a list;
  a shader writes `love_Canvases[1]`): the scene to the screen and its alpha to the silhouettes, so the
  second pass costs ~nothing. Every shader the textured world uses (plasticine, hairs, the materials,
  the default one) would write the second output, and the world would be drawn into a canvas, not
  straight to the screen. Try first on a small test that LÖVE 11 does it on the phone (GLES), then
  only if shadows go into real rooms (LS13). Idea, Nikki 2026-11-06: 'note it down'.
  Probed 2026-11-06 on the iPhone SE 2 and the Mac (setCanvas(a, b), one rectangle): several canvases
  work (4 on the phone, 8 on the Mac), but LÖVE's default drawing and any `vec4 effect` shader write
  only the first; a `void effect()` shader writing love_Canvases[0] and [1] fills both, on the phone too.
  So it needs: an MRT variant of every shader the textured world draws with (plasticine, hairs, the
  mouth's, the default for plain pictures: the source's effect renamed and wrapped), the drawers' resets
  to 'no shader' going to the MRT default during that pass, the textured world drawn into a canvas pair
  and laid on the screen (premultiplied alpha, with a stencil for the contact shadows), the wall and
  floor shadows using the previous frame's outlines (they're drawn before the things), and lanes
  falling back to their own passes. Saves the outline pass (~5-6 ms with 20 lit Mipos; ~3 with LS25 and
  every other frame), costs a full-screen copy (~1 ms on the phone).
- [x] **LS25. Only what shows in a shadow.** The outline pass draws every drawable: faces, decals,
  grass, mouths, small bits that barely change a shadow. Drawing only the bodies, heads and limbs
  (a filter on the drawable's type in drawTexturedWorld's `only`, or a list per Mipo) makes it cheaper;
  measure what it saves with 20 Mipos. Idea, Nikki 2026-11-06: 'note it down'.
  Done 2026-11-06: src/shadow-silhouettes.lua leaves out decals, brows, the mouth's parts, grass and
  water (drawTexturedWorld's `only` now gets the drawable too; state.shadowAllParts puts them back, to
  compare). iPhone SE 2, one install, 20 lit Mipos, paused, 3D every frame, each twice: all parts 24.1 /
  24.3 ms draw (38 fps), without them 20.7 / 20.9 (41-42 fps); every other frame 18.8.
- [ ] **LS15. Small ones:** should a new directional light be a sun (not fade) by default; the back
  light on a drawn stone lands on its black outline (reach past it, as the contact shadow does);
  grass on a moving body rebuilds its blades every frame (LITTLE-USED, the grass round).

Not light, but where this started (`LITTLE-USED.md`): three rounds left there, skinned mesh, UV mesh,
the recorder (the feature-rounds sweep, `claudetools/feature-rounds_spec.lua`, takes a recipe each).
