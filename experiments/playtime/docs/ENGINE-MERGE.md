# Merging the spikes into the engine

status: active, focus

Where it stood on 2026-11-06: about 35 spike scenes, most of them one big scene script (600-2,900 lines)
with their own drawing, shaders and physics. A few have code in `src/` already (cloth, liquid, fluid,
wet, materials, raspberry, facing, hair locks/tufts, fabuland). About 20 are parked as "kept as a
spike" with Nikki's verdict. None are on the toys shelf (`src/props.lua`, 15 recipes).

## What "merged" means

A spike is merged when it works **without its scene script**, as one of:
- **a thing on the shelf**: a prop recipe with 🎲 and its own few settings (EDITOR-ARRANGE.md):
  a critter, a plank, a glass bead, a stone with a material, a curtain, a plant;
- **a scene setting**: light, sky and clouds, water level, depth layers, music style, as sliders
  in the scene panel.
What's neither (the soapbox ride, the burrow) stays a scene, a shorter one, built from the merged parts.

## The themes

| Theme | Spikes | In the engine as |
|---|---|---|
| Water | sea, drawn-sea, seaside, waterjar, water, cellophane, boat, boat2, the mirrors pond | one kind of water (seaside already brings them together) |
| The scene's look | light and shadow, materials, clouds, depth, mirrors | scene settings; a material as a setting on a picture |
| Built from drawn parts | planks, boat2, wild's shed, fabuland, soapbox and bike tracks | prop recipes with drawn outlines |
| Creatures and plants | garden (the biggest), plants | things to place |
| The Mipo | breeds, facing, raspberry, choir, tufts, soft torso | DNA and actions (mostly on the way in) |
| Places | burrow, soapbox, bike, planets, platforms | stay scenes |

## Who owns what (2026-11-09)

The owner is the version the next spike builds on, and the one to merge from. The others are older or
side copies: read them for one idea, don't start from them. From a read of every spike's script.

| Idea | Owner | Older / side copies |
|---|---|---|
| Wave columns, swell, foam | seaside (sea's, identical) | sea (the original); drawn-sea (scrolls with the boat); mirrors pond (simpler) |
| Floating | seaside/sea `float` (by mass, drag against the water's own motion) | drawn-sea `float` for hulls (by wet area, ballast); mirrors (hard numbers); water (oldest, superseded) |
| Splashes, drops, pouring | seaside (`splash`, `particles` + the stream) | sea |
| Particle water | `src/fluid.lua`; waterjar is its stage | seaside uses it for pouring |
| Water look (shader) | seaside (thin cup water, stream shader) | sea, drawn-sea (near-identical); drawn-sea's own extras: drawn bands, glassy waterline |
| Cups, bath | `src/liquid.lua` + seaside's drawing | — (floating in them: WATER W4 / SEASIDE SS4, open) |
| Reflection, ripple rings | mirrors | — |
| Boat of planks | boat2 (drawn-sea has the newer `makeBoat` with ballast) | — ; boat = the kinematic drawn boat |
| Crayon stroke / outline | `src/drawn-stroke.lua` (loaded by 9 spikes) | planks (byte-identical copy, delete); burrow (the ancestor: has `canonical()` and per-cell tile pick, merge those in) |
| Drawn plank | planks (bodies, nails, pop) + boat2's quad grain | wild (seeded wear and chaos, an option on it) |
| Course from a height | soapbox | bike (parked) |
| Course from waypoints, pipes, rails, depth as collision | tracks | — |
| Lift / cable car | soapbox | bike (identical) |
| Rider Mipo | upright: soapbox; upside down / loops: tracks | bike (older) |
| Diggable earth | burrow | — |
| Chunky parts | `src/fabuland.lua` (merged; only the shelf loop is missing) | — |
| Sky, clouds, far hills, parallax | clouds | weather (puff clouds, gradient sky), depth (plain sky, sine hills) |
| Haze by depth | none yet: tracks `hazed()` is the most complete | clouds, depth, weather (`airColours`) |
| 2.5D ground with grass rows | clouds | weather (line blades) |
| Weather | weather (not played with yet) | clouds `rainFrom` |
| Depth layers, lanes | depth | boat2, planks by hand |
| Materials | material-check (src has the kept ones) | materials spike (superseded, don't build on it) |
| Light, day and night | light-grass-check (source of scene-light and the shadows) | scene-light's wall shadow is a sun-only copy |
| Trees and bark | bark (already modules: tree-grow / tree-kinds / tree-mesh / bark-look) | — |
| Glass | glass (its bake became `src/render/form-bake.lua`) | — |
| Ageing, order vs chaos | wild | — |
| Critters | garden (the dog/cat/giraffe kind tables are closest to a prop recipe) | — |
| Plants | plants | garden's simple flowers |
| Wearables | spikes/wearables (engine half in `src/wearables.lua`) | — |
| Singing | choir | — |
| Breeds | `src/mipo-breeds.lua` (all 8 since EM6) | — ; spikes/breeds is its stage |
| Facing, turning, walking | spikes/facing (MF6 plans `src/mipo-walk.lua`) | — |
| Hair | tufts (`src/hair-tufts.lua`) | hair (`src/hair-locks.lua`, the dropped route) |

Stages only, nothing to merge: cloth, raspberry, hair, tufts, scan-test, waterjar. Not owners of an
idea: mudready (Bathhouse game logic), nofeet (its finding is DNA defaults), platforms, planets,
elasto, stapelaar (old toys), cellophane (dead end).

## Reusable code in the spikes

Copied between scenes (identical bodies, checked by md5 with whitespace and comments set aside):
- `spawnMipo(b, x, y)`: 13 scenes + 3 with another name for `b` (burrow, depth differ). `aliveMipos`: 11 + 4.
  `alive(inst)`: 6. A shared `mipoKit.spawn(list, x, y, opts)` / `mipoKit.alive(list)` / `isAlive(inst)`.
- `clamp`: 11 copies of `mathutils.clamp`; `lerp`, `wrapAngle`, `dist`, `deepCopy` copied too.
- `clipUnder`, `areaCentroid`, `fixturePolygon`: identical in sea, drawn-sea, seaside, mirrors.
  Overlaps `src/liquid.lua`'s `area` / `clipBelow` (flat level).
- `pointInPoly`: planks, boat2, drawn-sea; `src/cdt.lua` already has one.
- `viewRect` (4 identical), `ensureCanvas` (3), `overPanel` (pairs, differ only in the label).
- The boat kit (`plank`, `quad`, `makeLook`, `placeNails`, `drawPlank`, `drawBoat`, …): identical
  in boat2 and drawn-sea; `meshesOf`, `waveY`, `drawShape` in boat, boat2, drawn-sea.
- Bike and soapbox share ~400 identical lines (lift, course, wheels, tire pictures, pose helpers).
- The grass blade atlas: clouds and wild copy `src/grass.lua`'s `QUADS` + `ATLAS`.
- Contact shadows drawn by hand in materials, glass, clouds, depth; `src/contact-shadows.lua` does it.
- Sky, far and sand shaders identical in sea and seaside; the water shader near-identical in three.

Worth a home in `src/` (take arguments, no scene state):
- Mipo pose helpers `jointPoint`, `turnParts`, `moveAll`, `mipoHeight` (soapbox, facing, tracks):
  next to `poseTpose` in `src/mipo-build.lua`.
- `muscle(joint, target, rate, torque)`, `shapeBody`, `skinOf`, pupil eyes, `castFrom`, `steerAngle` (garden).
- `drawSkinStrip` (garden) and `drawRibbon` (plants): a picture along a chain of points, two differing copies.
- Wearables' `partBody`, `headOf`, `hipTorso`, `faceOval`, `spot`: into `src/wearables.lua`
  (`jointBetween` there is `mipoRegistry.jointBetween`).
- `hslHex`, `paletteColor` (breeds): B3 needs them.
- `resample`, `nearest`, `ease`, the 3D box projection (tracks); `projector`, `drawSides` (depth).
- `layerCam`, `zoomOf`, `drawHill` (clouds); `updateAmounts` + the weather machine, `airColours` (weather).
- Time of day `sunTheta`, `moonTheta`, `onArc` (light-grass-check); `wallShadow` with the moon.
- L-system `expand`, `turtle`, `vary`, `newPlant` (plants); the vowel formant filter (choir).
- `marchChunk`, `rebuildChunk`, `stamp` (burrow): a terrain module if digging comes back.
- `glassShader`, `hull`, `simplify` (glass); wild's `plank` / `shapeAt` / `lookAt` wear.

Not in `src/physics-units` yet: the water spikes' wave speeds and forces are raw pixel numbers.

## Shelf candidates (a read of the scene scripts, 2026-11-11)

What a scene builds that could go on the library shelf (EM2), easiest first. Kind: **data** = bodies,
joints and sfixtures alone (a saved prefab works today); **system** = needs code every frame, so it
first becomes an sfixture or behavior type plus an engine system that finds its things by label or
subtype (as walls and fabuland do); then the bodies alone are the prefab.

- Quick: **fabuland parts** into `src/toys.lua` (its drawing is on only when a scene sets
  `state.fabuland.on`: switch it on when a `fab:` body exists); **a lamp** (a body with a light
  sfixture, the engine draws it: campfire's `fireLight`, light-grass-check's lamps); **stone, crate,
  table** as `src/props.lua` recipes (stapelaar `spawnStone`, seaside's crate and `spawnTable`), so 🎲
  has something to vary (EA3).
- Medium, a system each: the **catapult** (rooms/catapult: pull and fling as a behavior), the **campfire**
  (`src/fire.lua`: a fire sfixture + system, the light, flicker and shadows with it), **glass beads**
  (name and tint on an sfixture, `src/render/form-bake.lua`), **cloth** (`src/cloth.lua`; the flag pole is
  raw love.physics), the **festoon** (`src/festoon.lua`, its hooks a constant), **drawn planks** (the look
  kept on `state.planks`, nails pop), **wearables** (`src/wearables.lua`, putting on is scene code).
- Large: rides, the plank boat (waits on water), soapbox cart and lift, garden critters (EM4), plants.

What blocks prefabs in general: a prefab has no per-frame code; looks kept in a scene's own tables;
bodies made with raw `love.physics` aren't registered (rides, soapbox, garden, the cloth pole, the
waterjar crate) and can't be selected or saved; a prefab freezes randomness (recipes keep it).

## Order

The landing order, what bites what, and Nikki's keep / spike choices of 2026-11-10: LANDING-2026-11.md.

- [ ] **EM1. Light and materials.** Decisions first, then the move:
  MATERIALS MT2 (Nikki judges the 36 in material-check: keep / change / drop; postponed 2026-11-06,
  another time), then LIGHT-AND-SHADOW LS23 + LS15 (a full room's defaults), then LS13 (light as a
  scene setting) and MT6 (setting a material in the editor, for the kept ones). LS20, LS21 and LS24
  after, in a real room. Started 2026-11-06 with LS13's first slice (the light button: off / lit,
  `src/scene-light.lua`), the order above turned round by Nikki's wish to have the button.
- [ ] **EM7. Sky as a scene setting**: the day-night gradient and the climb to space, one clock for the
  sky and the light (SKY.md, Nikki 2026-11-11).
- [ ] **EM2. Two or three easy shelf things**: cloth (`src/cloth.lua`), planks with drawn outlines,
  glass beads; tries spike thing -> prop recipe -> shelf. Read each spike's script first.
- [ ] **EM3. Water**, as one piece of work, from seaside (into the engine (Nikki 2026-11-10, LANDING-2026-11.md); its speeds
  and forces through src/physics-units.lua).
  **First slice 2026-11-11** (Nikki: "adding a bath from the library shows it"): the water shader moved out of
  seaside into `src/render/water-shader.lua` (byte-identical source; seaside uses it, `waterLook` in the
  script env), and an engine system `src/water-look.lua` (systems' new `drawStart` / `drawEnd` hooks): with
  any LIQUID in a scene the frame is drawn into a canvas and the cups and baths get the shader at seaside's
  thin-water values (`THIN`). A scene with its own hook (seaside) is left alone. Next: tweak the look with
  Nikki (the liquid's own colour is ignored now; settings on a panel or on the liquid), the cost on the
  phone, pouring outside seaside (spills are still lost without a hook), the sea itself. Floating and the
  surface's splash in cups and baths done the same day (`liquid.floatIn`, WATER W4 / W3b). A bake during the
  frame (`omp-bake.makeTexturedCanvas`) put the screen back as the target: with the frame in the water's
  canvas that flickered while dragging Mipos; it puts back what it found now.
- [ ] **EM4. Garden critters**, once the shelf and 🎲 exist (EDITOR-ARRANGE EA2-EA4).
- [ ] **EM5. The cheap shared bits**, any time, each checked by a scene snapshot before/after:
  a `mipoKit` (spawn / alive / isAlive) for the scene scripts, `mathutils.clamp` instead of the copies,
  drawn-stroke into `src/` with burrow's two extras (planks and burrow drop their copies), the grass
  blades from `src/grass.lua`, the Mipo pose helpers into `src/mipo-build.lua`.
  Where it stands (2026-11-11): the spawn copies are one-line wrappers round `mipoKit.spawn` (L4; burrow's
  DNA and depth's lanes keep their own); planks uses `drawnStroke()`; the grass blades: clouds and wild read
  `grass.ATLAS` / `grass.QUADS` (`grass` in the script env). `clamp` stays copied (13 one-liners;
  `mathutils.clamp` differs only with the bounds reversed: plants' `clamp(i, 1, #sp.bodies)` with no bodies,
  plant-look's droop if negative; tried 2026-11-11: Nikki chose to leave them, the gain is small). The pose
  helpers (`jointPoint`, `turnBodies`, `turnParts`, `moveAll`, `mipoHeight`) in `src/mipo-build.lua`, through
  `characterManager` in scenes; bike, facing, rides and soapbox drop their copies (the same code; checked by
  running each: soapbox and bike sit their Mipo as before, facing's sit runs). Left: burrow's stroke extras. Note: the
  scenes snapshot renders a scene's saved bodies without its script, so it doesn't check script-drawn
  things (clouds and wild hash the same, empty); and facing, light-grass-check, mipo-materials vary
  between takes.
- [x] **EM6. The 7 trial breeds** in spikes/breeds into `src/mipo-breeds.lua` with palettes
  (MIPO-BREEDS B2-B4; that plan owns it, listed here so the spike's copy goes). Done 2026-11-09:
  the spike's table and `randomizeAs` are gone, it reads `mipoBreeds` (in the script env).

The focus since 2026-11-11 (Nikki, after facing: "lets look at engine merge next").
