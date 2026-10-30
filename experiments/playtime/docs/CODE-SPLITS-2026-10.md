# Splitting the big files (October 2026 review)

status: active

Opened 2026-10-30, when the cleanup was done. Sizes in brackets are from the review; after the
cleanup (2026-10-30): draw-textured 2897, music 2470, character-manager 2445, mipo-editor 1822,
math-utils 1079, io 998, sfixture-editor 686.

Seven files were over 1400 lines. From the 2026-10-30 review: do the cleanup inside each file first
(`CODE-CLEANUP-2026-10.md`), then a split is mostly cut and paste. Keep the old module as a thin
front that re-exports the same names, so requires elsewhere don't change. Hot reload: new modules
keep no local state that must survive (put it on `state`). One file per sitting, specs green after
each.

- [x] **SPLIT1. `physics/box2d-draw-textured.lua` (3746).** `drawTexturedWorld` is one ~1280-line
  function with a 13-branch `if type ==` chain (still ~940 lines, 17 branches); make it a
  `drawers[subtype]` table of one function each. Then (`src/mipo-face.lua` is out already, CL20):
  `src/render/shaders.lua` (GLSL, defaults, lighting, `beginSurfaceShader`; the two shaders share
  noise and a ~45-line light loop that can be one string chunk), `src/render/omp-bake.lua` (image
  cache, `makeTexturedCanvas`, patches), `src/render/skinning.lua` (LBS/DQS, rigid bones, MESHUSERT
  vertex build, testable without a window), `src/render/ribbon.lua` (strips, curves, hair over),
  `src/render/mouth.lua`. What stays: createDrawables, the sort, the drawers (~500).
  **Done 2026-10-30** (de6d9452 and the next commit): `src/render/` omp-bake (image cache, colours, the
  bake), shaders (plasticine, hairs, lights, `setSurfaceShader`, the defaults texfixture-params reads),
  ribbon (strips, textured curves, hair over, trace mesh), mouth (mouth polygon, lip edges, the four
  mouth drawers), skinning (LBS/DQS, rigid bones, UV lookup, `meshusertVertices` without a window).
  The `if type ==` chain is `drawers[type]`; drawTexturedWorld is a 30-line loop. 2897 -> 900 lines
  (createDrawables and the other drawers stay). Same pixels in all 36 scenes after each step.
  `texturesCreated` is `ompBake.texturesCreated` (main.lua), `useDQS` is in skinning.
- [ ] **SPLIT2. `character-manager.lua` (2886).** (`shape8-dict` is out already, CL23.) `mipo-dna` (template,
  zOffsets), `mipo-appearance` (the update*OfPart setters), `mipo-textures` (skins, hair, connected,
  face decals), `mipo-randomize` (randomizers, mutateSizes, arm reach), `mipo-balance`
  (balance*/apply*/settlePose). character-manager keeps building, rebuilding and save/load (~700).
  Dependencies only point one way.
- [ ] **SPLIT3. `ui/mipo-editor.lua` (2020).** After CL15: `ui/mipo/widgets.lua`,
  `ui/mipo/body-panel.lua`, `ui/mipo/face-panel.lua`, `ui/mipo/look-panel.lua`; mipo-editor keeps the
  header and accordion order (~120). `getMirrorPart`, `getLimbRoot` and the faceOwner rule (twice,
  :1429, :1661) go to character-topology.
- [ ] **SPLIT4. `ui/sfixture-editor.lua` (1886).** After CL14 and CL21 most of it is gone (686 now:
  maybe no split needed, look first). What's
  left: `ui/meshusert-panel.lua` (bind buttons, sliders, triangle painter; the plain sliders could be
  inspector rows), `ui/resource-panel.lua`, and sfixture-editor as dispatch (~150).
- [x] **SPLIT5. `music.lua` (1646).** `music-styles` (pure data), `music-theory` (pure functions,
  specs welcome), `music-plan` (planSong and friends), `music-parts` (bass, drums, lofi, strum,
  loop bars); music.lua keeps settings, `state.music`, bookBar/bookNext and the public API (~350).
  The music session owns this file: check with it first. It grew to 2470 with new styles.
  **Done 2026-10-30** (7ca3f55f, playtime-b5): music.lua 2470 -> 418, music-styles (data), music-theory
  (pure), music-plan, music-parts; requires one way (styles <- theory <- plan <- parts <- music); old
  names re-exported; every note of all 15 styles the same as before.
- [x] **SPLIT6. `io.lua` (1615).** `scene-save`, `scene-load` (buildWorld split into camera/backdrops,
  bodies, joints via handlers, sfixture fix-ups), `save-migrations` (everything only there for old
  files: one place to delete from later), `influences` (restoreInfluenceBodies with an optional id map,
  replacing `remapAndRestoreInfluences`). Clone went with CL17 and joints with CL13: 998 now.
  **Done 2026-10-30** (deb1f178, playtime-fc): io.lua a 32-line front over scene-load (buildWorld as
  named steps), scene-save, influences, save-migrations. All 48 scenes give the same save data.
- [x] **SPLIT7. `math-utils.lua` (1424).** After CL3 (~1000 left): `polygon.lua` (transforms,
  centres, bounds, edges, insert/remove vertex), `spline.lua`, `polygon-ops.lua` (triangulate,
  decompose, clip), `mesh-weights.lua` (mean value coordinates). math-utils keeps clamp, sign, lerp,
  rotatePoint. Note: `computeCentroid` returns the bounding-box centre, not a centroid; say so in a
  comment (or one `bbox` and `bboxCenter`) rather than rename 24 call sites.
  **Done 2026-10-30** (7a36fbc2, playtime-fc): math-utils keeps clamp, lerp, remap, dist, wrapAngle,
  normalizeAxis, sign and passes the rest to polygon, spline, polygon-ops, mesh-weights (rotatePoint in
  polygon: the new modules mustn't require math-utils back). computeCentroid says it's the bbox centre.
- [~] **SPLIT8. `input-manager.lua` (922) and `object-manager.lua` (967).** No split needed; the
  function extractions in CL22 and CL26 are enough.
