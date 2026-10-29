# World building — grass, ground, sky and outside scenes

**Started:** 2026-10-29 (survey + brainstorm). **Status:** plan, nothing built yet.

**Goal:** make an outside world quickly. Ground with grass along its edge, a sky with layers,
hills, and a few Mipos in it, the way Puppetmaker 2's "outside" felt, without hand-drawing
every patch. The tools build normal Playtime bodies and sfixtures, so everything stays editable
and saves like any other scene.

**How to use this doc:** part 1 lists what exists in experiments/ (with paths, so nobody
re-surveys). Part 2 is what Playtime has. Part 3 is the order to build; tick it there.
Related: `WORLDS-AND-DOORS.md` (an outside scene is a natural overworld), `WORLD-METRICS.md`
(rules for anything a Mipo stands on), `DOLL-PLAY.md` (toys, rooms),
`LIBRARY-AND-RESOURCES.md` Phase 6 (parallax layers, planned), `REBUILD-IN-PLAYTIME.md`
(parallax + procedural terrain listed as missing), `knut/KNUT-TOOLKIT-TODO.md` (`addGrass`,
`createScene`, planned).

**Who does what (2026-10-29):** this doc's session builds the items in part 3. Session
`playtime-ef` is surveying the rest of experiments/ (read-only) for reusable pieces. Its finds
for grass, sky and terrain go in part 1d.

---

## 1. What exists

### 1a. Puppetmaker 2 "outside" (`../puppet-maker2/scenes/outside.lua`)
- **Ground:** none visible. Invisible static boxes around the camera
  (`../../lib/mainPhysics.lua:165` `rebuildPhysicsBorderForScreen`), plus one floor box (`outside.lua:255`).
- **Grass:** single blade sprites `assets/world/spriet1-8.png` (gray + alpha, ~49×192), tinted
  green at draw time and drawn by `../../lib/texturedBox2d.lua:606` `drawSpriet`. There's one
  blade every 30 units, in rows (`outside.lua:235-252`). Back rows are taller to fake depth.
  Two rows are drawn behind the characters and one in front. Wind is one global `sin` rotation.
  The blades don't react to anything.
- **Sky:** `../../lib/gradient.lua:77` `makeSkyGradient` (2-colour mesh), plus `world/clouds1.png` at
  alpha 0.6, in screen space. There's no parallax. A vignette (`ui/border_shaduw.png`) is drawn over everything.
- **The five:** `mainPhysics.lua:139` `setupBox2dSceneWithFiveGuys`, evenly spaced across the
  view, dropped from the top.
- Unused there: `world/stoelL.png`, `stoelR.png`, `tafel.png` (chairs, a table).

### 1b. physics-testbed downhill (`../physics-testbed/scenes/downhill.lua`, `renderJoy.lua`)
- **Endless terrain:** `getYAtX(x, stepSize)` (`downhill.lua:95`) sums three octaves of 1D
  `love.math.noise` (amplitudes 2156 / 755 / 216, freqs 30 / 17 / 5) and adds a downhill ramp.
  `stepSize` is 300. `lerpYAtX` (`:177`) interpolates between steps.
  `updateGround` (`:141`) rebuilds one static `ChainShape` around the camera every frame.
- **Ground art:** `drawHillGround` (`renderJoy.lua:577`) draws a "road" band along the top
  (y-100…y+200) and a side down to the screen bottom. Both are stencilled and filled with
  repeat-wrapped `assets/world/grasspattern*.png`, offset by the camera
  (`drawRepeatedPatternUsingStencilFunction`, `:92`). Colours are at `renderJoy.lua:8-13`.
- **Grass blades:** `drawGrassLeaves` (`renderJoy.lua:366`) uses the `assets/sprieten.png`
  atlas (8 quads, bottom-centre origin, `downhill.lua:522-533`). There's a blade every 75 units.
  Height and sprite come from noise at the blade's world x, so blades stay put while scrolling.
  There's a back layer (dark green) and a front layer (light green). A new SpriteBatch is
  built every frame, which is wasteful, and each layer is capped at 500 blades. The sway is
  global. Nothing reacts to the bodies.
- **Dandelions:** `drawSinglePaardenBloem` / `drawPaardenBloemen` (`renderJoy.lua:302/340`). The
  stem is a Bezier with a swaying control point, textured as a strip. The head colour lerps
  day → night. Assets: `world/stengel1.png`, `bloemHoofd1.png`, `bloemBlad2.png`.
- **Sky:** a gradient blended by day/night, stars twinkling by noise (`downhill.lua:1219`),
  and a sun and moon with faces (`renderJoy.lua:555`). There are no clouds (`world/clouds1.png` is unused).
- **Culling:** off-screen Mipos, bikes and obstacles get `setActive(false)` (`downhill.lua:228-298`).
- Also: ski jumps on local low points (`locatePeakX`, `:63`), vehicles (`vehicle-creator.lua`).

### 1c. Leads from git history
These leads were checked by playtime-ef; the results are in 1d. They came from commit `c6fa2614`
(batchdraw, vehicles-vegetation) and commit `29e7c8f9` (discord-experiment).

### 1d. From the experiments survey (playtime-ef, 2026-10-29)
The full ranked survey is planned at `EXPERIMENTS-HARVEST.md` (not written yet). The finds:
- **`../batchdraw/main.lua`**: the fast way to draw grass. It loads `sprieten.png` as an ArrayImage with
  8 quads plus a **base origin per quad** (`origins = {{22,185},{12,187},...}`, the pivots for
  sway). It adds 300 blades to one SpriteBatch **once**, at load, and draws them in one call. For
  G1: build the batch per sfixture when it's dirty, and do the sway in a vertex shader (or
  setTransform), never a new SpriteBatch per frame. The folder also has `floweratlas.png` (flowers;
  its quads are commented out) and `Morning/Sunrise/Sunset/Evening.png` (sky images).
- **`../vehicles-vegetation/main.lua:794` `makeGrassThing`**: plants as real physics. Each is a dynamic
  body on a revolute joint to a static anchor. The "keep-rotation" behaviour (`:2272`) springs it
  back toward a random rest angle ±0.2. It's commented out at `:1252`, and the drawing is
  `../../lib/texturedBox2d.lua:184` `drawPlantOver`. For a few big plants or bushes (G7) this
  could beat a fake bend; for blades, G2's fake bend is better. Also `assets/leaves/leave1-13.png`
  (13 leaf sprites, unused). Its blade layout is 4 rows under the characters and 1 over (`:1235-1246`).
  Dead end: `haarnew*.png` is body hair for character parts, not vegetation.
- **`../skies/SkyGradient.lua`** (168 lines): sky gradients from hex colour stops, blended in linear
  RGB (gamma-correct), so it's smoother than `lib/gradient.lua`. Use it as the base for G5.
- **`../noiseclouds/main.lua`**: 32×32 canvas clouds from `love.math.noise`, with camera x/y/zoom
  offsets and moving in time. It redraws per pixel every frame on the CPU, so it would need a
  shader to be worth porting (G5, later).
- **`../shadow2/main.lua`**: a character's shadow projected from a light point onto the ground. A
  possible later item: ground shadows under Mipos.
- `../discord-experiment`: no world material.
- **Parallax, ready-made** (second batch; paths checked, line numbers as reported):
  - `../../lib/camera.lua:31` `createCamData` (the repo-root lib, used by `../scrolling-world`) maps an
    item's `depth` to a per-layer camera scale (far 0.4 … near 1.0).
  - Playtime already vendors brady with layers (`vendor/brady.lua:44` `addLayer`), but nothing in
    `src/` uses it yet.
  - **Read both before designing G4.**
- `../scrolling-world/src/groundplane.lua:51`: a fake-3D ground plane, textured quads between the far and
  near camera layers.
- `../scrolling-world/src/removeAddItems.lua:7-75`: props streamed in and out per 100-unit ground tile as
  the camera moves (for G6's endless mode).
- `../scrolling-world/src/pointer-interactions.lua:250-262`: edge-pan. Dragging something to the screen
  edge scrolls the camera (DOLL-PLAY "drag to pan").
- `../../lib/screen-transitions.lua:51-153`: circle, rect and fade wipes. Could replace the plain fade in
  `src/doors.lua`.
- `../tiled-polygons-01/tiled-polygons.lua:126`: marching squares over a weight grid, a possible
  sculpt/dig terrain tool. It makes one body per tile, so the output would need merging into one chain.
- `../shadow/main.lua` (`makeSingleShadow`, `applyBlur`) and `../polyfun/main.lua:350`: blurred drop
  shadows baked per polygon. The CPU blur is slow, so use a GPU blur or a cached canvas.
- `../lsystem-master/l-system.lua`: a small L-system turtle for trees and branches (also dreamengine
  `lsystem.c`, see `HARVEST-NAVKIT-DREAMENGINE.md`).
- `../level-ed/readme.md`: a checklist of what a level holds (mipos, hill generator, vehicles, sky,
  parallax layers, overlay, triggers).
- Dead ends: `liquid`, `buoyancy` (no Box2D coupling, or a stub).
- **Tweens:** `timer.lua` (hump), `flux.lua` and `tween.lua` are in the **repo-root** `vendor/` (`../../vendor/`),
  not in Playtime's `vendor/`. Playtime sets no `package.path` to reach them, so copy one into
  `vendor/` when sway or tween work needs it (DOLL-PLAY F3).

## 2. What Playtime has

- **tile-repeat sfixture**: this is the "grass" attach that already exists (`src/subtypes.lua:9`;
  tool rail → attach → looks → "tile", `src/ui/tool-rail.lua:256`). It fills the host body's whole
  polygon with a repeating texture (`src/physics/box2d-draw-textured.lua` ~2923, UVs from world
  position). It's used in `scripts/knut/knutjump.playtime.json` with `knut/gras.png`.
  The inspector has texture, tint, tile w/h, rotation and z (`src/sfixture-params.lua:118`).
  Limits: it can't do edge grass, and the vertex alpha is hardcoded to 140.
- **Ground:** free polygon, freepath ribbon (`object-manager.lua:53/103`) and soft surface (`:21`), all
  drawn by hand. Nothing is procedural.
- **Backdrops:** `state.backdrops` `{url,x,y,scale,border,foreground}`, drawn in `main.lua:423-451`
  and edited in `src/ui/world-settings.lua:35`. Flat, with no parallax.
- **Props/toys/library:** `src/props.lua`, `src/toys.lua`, `src/library.lua` (prefabs, place at the mouse).
- **Rooms/doors:** `src/doors.lua` (W1). **Scene scripts:** the `script.call('draw')` hook (`main.lua` ~443).

## 3. Order to build

- [ ] **G1. Grass edge sfixture.** An attach kind (looks → "grass") on any ground body:
  - Blades along the edges whose normal points up (a settable max angle). The noise for height
    and sprite uses the blade's world x, as downhill does, so a scene looks the same every time it loads.
  - A back layer behind the Mipos and a front layer in front. Both go through the z-sort, so
    two sfixtures or one with a split.
  - Each blade sways at its own phase. One cached SpriteBatch per sfixture, rebuilt only when
    the body or a setting changes; sway in a vertex shader, pivoting on batchdraw's per-quad origins (1d).
  - Settings: density, height, height variation, colour back/front, front share, sprite set
    (`sprieten.png` atlas or `spriet1-8`), sway.
  - Copy the sprites into `textures/world/` (with the asset sizes measured first).
- [ ] **G2. Blades that react.** Blades near a body (a Mipo's feet, a ball) bend away and
  spring back. Per patch, query the bodies in its AABB, and per blade use a spring angle. A
  hard landing flattens the grass for a moment. This is the Sago bit; neither old version had it.
- [ ] **G3. tile-repeat as a ground skin.** An alpha setting instead of the fixed 140 (old
  scenes keep 140). An optional top band: a strip texture along the up-facing edges with the
  fill below, like downhill's road. A grass lip over dirt is then one attach.
- [ ] **G4. Parallax backdrops.** First look at the ready-made parallax in 1d (`lib/camera.lua`
  `createCamData`, brady's `addLayer`). A `parallax` value 0..1 per backdrop (0 = fixed to the
  screen, 1 = moves with the world). It's a small change where `main.lua` draws backdrops, plus a slider in world
  settings. It's saved with the scene, with a default of 1 for old scenes.
- [ ] **G5. Sky.** A gradient sky as a world setting (`../skies/SkyGradient.lua`, gamma-correct; or `../../lib/gradient.lua`'s presets), and later
  day/night with sun/moon (downhill). Clouds come as parallax backdrops (G4).
- [ ] **G6. Terrain tool.** A "hill" shape from noise (amplitude, frequency, octaves, seed,
  length) that becomes a normal editable body (a polygon or a ribbon). It checks `WORLD-METRICS.md` and
  flattens the stretches marked as standing spots (slope ≤5°, ≥650 wide). The endless mode is
  optional: a world setting that rebuilds the chain around the camera, as downhill does.
- [ ] **G7. Scatter.** Along a surface, scatter dandelions (port downhill's), stones, or any
  library prefab, with random spacing, scale and flip, and noise so it's reproducible. Either
  part of the grass edge (flowers in the grass) or a brush.
- [ ] **G8. Outside starter scene.** "New outside scene": ground with a grass edge, sky, clouds and
  five Mipos dropping in (Puppetmaker's recipe). It's also a candidate overworld for `WORLDS-AND-DOORS.md`.

## Open questions
- Should G1 be one sfixture that draws in two z-layers, or two sfixtures? It depends on how the
  z-sort takes a drawable from one sfixture at two depths.
- Which blade sprites? Look at `sprieten.png` vs `spriet1-8.png` side by side (Nikki's call).
- Should endless terrain fight the "everything stays where you put it" rooms idea? Probably keep it for
  travel scenes only.
