# Landing the spikes: order, collisions, choices (November 2026)

status: active

A report from 2026-11-10, built on ENGINE-MERGE.md (its owner table and reusable-code list still
hold). It adds what came after 11-09 (hair in C, maker, rides, flora, the lit face, festoon), the
order to land things in, what bites what, and the questions only Nikki can answer.

## Where things stand

**Already in the engine** (the engine's own files call them, no script needed): scene light and
the contact / projected shadows, the lit face and feet with small-flat, face patches, facing (the
pose, not the turning), soft torso (lobes, jiggle), the spine, breeds, `liquid` (cups),
fabuland's parts, grass.

**Engine code, but only a scene script drives it**: `hair-locks` (+ C), `wearables`, `cloth`,
`fluid`, `festoon`, `wet`, `materials` (half: there's a picker). These are the cheapest to land:
the code is written, it only needs a home in the frame.

**Modules that live in `scripts/spikes/`**: the trees (`tree-grow`, `tree-mesh`, `bark-look`), the
new flora (`plant-kinds`, `plant-grow`, `plant-look`), and `drawn-stroke` (loaded by 11 spikes,
including both of those). Loaded with `love.filesystem.load`, so lurker doesn't hot-swap them.

**Big single-scene spikes** (600-2,900 lines): garden, wearables, plants, seaside / drawn-sea /
sea, burrow, maker, tracks, rides, mirrors, clouds, depth, weather, mudready.

## What bites what

1. **Add-ons draw by themselves, over everything.** Hair draws `'back'` behind all Mipos and
   `'front'` over all of them (the hair scene says "for now"); wearables draw through their own
   canvas; cloth after the world. With one Mipo it looks right. With two overlapping, Mipo A's
   bangs go over Mipo B's face. Anything that hangs on a Mipo needs **draw slots per Mipo**
   (behind the body, between parts, over the face) inside `box2d-draw-textured`'s order, not
   passes of their own. Depth layers (DEPTH-LAYERS) are the same question one level up: back /
   play / front for the world.
2. **Facing turns everything that hangs on a side.** Bangs and front locks, the coat's face oval,
   a cap's bill (WR8), face patches, a mask. Promoting turning (MF6) before hair and wearables
   land means they're built facing-aware; after, they get retrofitted.
3. **Light and shadows must know the add-ons.** `shadow-silhouettes` already reads hair;
   wearables, cloth and plants don't cast. Each landing needs "lit like the part it's on" (hair
   does this, f0f1804c) and "in the shadow outlines" (LS24 wants one draw for both).
4. **The DNA and the scene file grow without a version.** Breeds, patches, softness, haircuts,
   material per part (MT6a), wearables, facing all want fields. `scene-save` always writes
   `"1.0"`; migrations are scattered (REVIEW-2026-11). And there are no player saves on the
   phone yet (W2, F4). Cheap now, dear once saves are out in the world.
5. **The phone budget is shared.** Today on the iPhone SE 2: a room's zoom holds 60 fps at every
   light level; all 20 Mipos on screen lit is ~48 fps; long hair on 20 Mipos ~1.2 ms. Not
   measured: wearables' canvas per frame (WR3), cloth (C2: a curtain is 784 points), flora,
   fluid in a full room. Each landing adds to the same 16 ms; the order should measure as it goes.
6. **Three of a kind.** Plants: the `plants` spike (parked, picking), `flora` (new, modules), the
   garden's simple flowers. Sky: clouds, weather, depth. Ribbons along a chain of points: garden
   `drawSkinStrip`, plants `drawRibbon`, flora's stems, tree-mesh, connected-texture, hair strips.
   Landing one copy without deciding which leaves the others to rot or fork.
7. **Water doesn't scale with the metre.** The water spikes' speeds and forces are raw pixels,
   not through `physics-units`: at `METER=400` they'd be off. Fix when landing EM3, not before.
8. **Shared shader slots.** 8 lights a part (LS27), materials, wet, festoon, the face all go
   through `shaders.lua` (restart after changing it). Bark-as-material (BK3) and leaf
   translucency (MT5) add more there.
9. **Cloth vs Box2D.** A Mipo inside a face-on curtain squashes its points (C3); a door's curtain
   (C5) would meet it every time a Mipo walks through.

## The order

Each step is small enough to finish, and makes the next one cheaper.

**0. Foundations (before landing anything that saves or draws on a Mipo)**
- [x] **L1. One frame hook for "systems".** Done 2026-11-10: `src/systems.lua`, a list the game
  loop calls (`update(dt)` while running, `drawBelow`, `draw`, `unload` on a scene load), each
  system's module looked up per call (hot swaps). Hair is the first: it runs in every scene now,
  the hair spike no longer calls it. Cloth, fluid, festoon and wearables join when they land
  (their scenes still place and draw them by hand); a new system is one entry there, and its
  scene scripts stop calling it. The scenes smoke spec runs the systems as main.lua does.
- [x] **L2. Draw slots per Mipo** (bites 1, 3). Done 2026-11-10: `src/mipo-layers.lua` names the
  places between a Mipo's own pictures (hairBack 50, headscarf 230, hairFront 255, mask 256, pants
  302, shirt 305, hat 380, scarf 390, sleeve 404; the wearables spike reads them from there). The
  textured world merges the scene's splits with the systems' (`splits` hook in `src/systems.lua`),
  skipping an off-screen Mipo's. Hair is drawn in its Mipo's layers: its back behind that Mipo
  only (it used to vanish behind the Mipos in front), bangs over the face but now under the arms
  and hands (they used to go over everything); a torso's coat just over the torso, under the head.
  Spec `mipo-layers_spec.lua`. Left: the shadow passes (`only`) still draw no splits (the hair
  casts through `shadow-silhouettes` as before), and world layers back / play / front stay for
  DEPTH-LAYERS.
- [x] **L3. A scene and DNA version with one ordered list of migrations** (bite 4). Done 2026-11-10:
  `src/save-migrations.lua` has SCENE_VERSION and DNA_VERSION (both 2; "1.0", every file before,
  is 1) and the steps in order (SCENE_STEPS / DNA_STEPS[n] take a version-n file to n+1: the decoded
  scene, each MESHUSERT once its bodies exist, a saved Mipo's DNA, its bodies). Today's fixups for
  old files are step 1, run for old files only: Steiner points to the body, bindVerts, and the Mipo
  ones (were `migrateDNA` / `migrateSavedFixtures` in mipo-build). A scene saved by a newer Playtime
  is refused with why; a newer Mipo is built as it is. Still on every load, written there why:
  texture renames, subtype names, a RESOURCE's image, rigidLookup. Scenes save `version = 2`, each
  Mipo its DNA version; a library prefab keeps its Mipos' versions. A change to what's saved: one up
  and a step (the file's top comment). Spec `save-migrations_spec.lua`.
  Found on the way: `mipo-neck_spec` seed 6 passes or fails by what ran before it in the same run
  (a Mipo's parts are built in `pairs` order, which follows earlier string interning; same DNA, mass
  and random numbers, other build order, Box2D settles otherwise). Fixed the same day: the loops that
  destroy a Mipo's bodies, regroup its fixtures and lay its pictures go by `utils.sortedPairs`; the
  seed-6 head lands on the same spot to 9 decimals whatever ran before, the seeded Mipos' snapshot
  is identical (light-grass-check and mipo-materials differ run to run, before and after alike).
- [x] **L4. EM5's cheap shared bits.** Done 2026-11-10, the copies that were identical only:
  `drawn-stroke` is `src/drawn-stroke.lua` (scene scripts: `drawnStroke()`; trees, flora and the
  maker's card `require` it; planks' byte-identical copy gone), `src/mipo-kit.lua` (`spawn`,
  `alive`, `isAlive`: 16 + 15 + 7 copies now one line each). Left, because the copies differ, so
  each is a choice (the obvious-reuse rule): burrow's older stroke (`canonical()`, a picture per
  cell: merging changes how burrow draws); burrow's, depth's, choir's, cloth's and garden's own
  Mipo helpers; the 11 `clamp`s (if/else: unlike `mathutils.clamp` when lo > hi or for NaN, and
  cheaper with the JIT off). Not looked at in this step: the grass blades (clouds, wild) and the
  Mipo pose helpers (facing, soapbox, tracks); with the scenes that use them.

**1. The Mipo** (the focus, and the product)
- Breeds B1-B10 as planned (focus).
- **Facing promoted** (MF6: turning + autowalk) before the add-ons below (bite 2).
- **Hair into the DNA**: a haircut as a breed / Mipo setting, drawn in L2's slots.
- **Wearables**: only what Nikki liked (hats, masks), facing-aware; scarves stay out.
- Maker (MM1-MM4) after breeds' B5/B6, since its card shows them (MM10).

**2. The room's look**
- EM1 as written: MT2 judge, LS13 light as a scene setting, MT6 material on a part.
- Then bark as a material (BK3) and leaves (MT5) through the same path.

**3. Things on the shelf** (needs EA2-EA4: the shelf and 🎲)
- Planks, glass beads first (EM2), then whichever of cloth / critters / plants / trees Nikki keeps.
- Before plants and trees: one ribbon drawer and decide plants vs flora (bite 6).

**4. Water** (EM3) from seaside, as one piece, through physics-units.

**5. Places stay scenes**, rebuilt shorter on the landed parts: burrow, soapbox, tracks, rides,
weather. Clouds / sky become a scene setting only if kept (G4, G5).

## For Nikki to choose

What goes into the engine and what stays a spike; plants vs flora; whether sky is a setting.
Answers go below and into ENGINE-MERGE's order.

## Decisions

Nikki, 2026-11-10:
- **Into the engine, the Mipo:** hair (haircuts in the DNA), turning + autowalk, hats and masks,
  the Mipo maker card. All four, so L1-L3 come first: they all hang on a Mipo, draw on it and save.
- **Into the engine, the world:** seaside's water (EM3) and sky and clouds as a scene setting.
  Weather and the mirrors' reflections stay spikes.
- **Plants and trees:** too early to say; after playing with flora (FL2). Only drawn-stroke moves
  (L4), so either way they load from `src/`.
- **The shelf** (planks, glass beads, cloth, critters): not answered yet. Ask again before EM2.
