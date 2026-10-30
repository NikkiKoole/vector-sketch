# Splitting the big files (October 2026 review)

status: parked — until CODE-CLEANUP-2026-10 is done

Seven files are over 1400 lines. From the 2026-10-30 review: do the cleanup inside each file first
(`CODE-CLEANUP-2026-10.md`), then a split is mostly cut and paste. Keep the old module as a thin
front that re-exports the same names, so requires elsewhere don't change. Hot reload: new modules
keep no local state that must survive (put it on `state`). One file per sitting, specs green after
each.

- [ ] **SPLIT1. `physics/box2d-draw-textured.lua` (3746).** `drawTexturedWorld` is one ~1280-line
  function with a 13-branch `if type ==` chain; make it a `drawers[subtype]` table of one function
  each. Then: `src/mipo-face.lua` (blink, brows, mouth tween, pull-face; CL20),
  `src/render/shaders.lua` (GLSL, defaults, lighting, `beginSurfaceShader`; the two shaders share
  noise and a ~45-line light loop that can be one string chunk), `src/render/omp-bake.lua` (image
  cache, `makeTexturedCanvas`, patches), `src/render/skinning.lua` (LBS/DQS, rigid bones, MESHUSERT
  vertex build, testable without a window), `src/render/ribbon.lua` (strips, curves, hair over),
  `src/render/mouth.lua`. What stays: createDrawables, the sort, the drawers (~500).
- [ ] **SPLIT2. `character-manager.lua` (2886).** `mipo-shape8` (data, CL23), `mipo-dna` (template,
  zOffsets), `mipo-appearance` (the update*OfPart setters), `mipo-textures` (skins, hair, connected,
  face decals), `mipo-randomize` (randomizers, mutateSizes, arm reach), `mipo-balance`
  (balance*/apply*/settlePose). character-manager keeps building, rebuilding and save/load (~700).
  Dependencies only point one way.
- [ ] **SPLIT3. `ui/mipo-editor.lua` (2020).** After CL15: `ui/mipo/widgets.lua`,
  `ui/mipo/body-panel.lua`, `ui/mipo/face-panel.lua`, `ui/mipo/look-panel.lua`; mipo-editor keeps the
  header and accordion order (~120). `getMirrorPart`, `getLimbRoot` and the faceOwner rule (twice,
  :1429, :1661) go to character-topology.
- [ ] **SPLIT4. `ui/sfixture-editor.lua` (1886).** After CL14 and CL21 most of it is gone. What's
  left: `ui/meshusert-panel.lua` (bind buttons, sliders, triangle painter; the plain sliders could be
  inspector rows), `ui/resource-panel.lua`, and sfixture-editor as dispatch (~150).
- [ ] **SPLIT5. `music.lua` (1646).** `music-styles` (pure data), `music-theory` (pure functions,
  specs welcome), `music-plan` (planSong and friends), `music-parts` (bass, drums, lofi, strum,
  loop bars); music.lua keeps settings, `state.music`, bookBar/bookNext and the public API (~350).
  The music session owns this file: check with it first.
- [ ] **SPLIT6. `io.lua` (1615).** `scene-save`, `scene-load` (buildWorld split into camera/backdrops,
  bodies, joints via handlers, sfixture fix-ups), `save-migrations` (everything only there for old
  files: one place to delete from later), `influences` (restoreInfluenceBodies with an optional id map,
  replacing `remapAndRestoreInfluences`). Clone goes away with CL17.
- [ ] **SPLIT7. `math-utils.lua` (1424).** After CL3 (~1000 left): `polygon.lua` (transforms,
  centres, bounds, edges, insert/remove vertex), `spline.lua`, `polygon-ops.lua` (triangulate,
  decompose, clip), `mesh-weights.lua` (mean value coordinates). math-utils keeps clamp, sign, lerp,
  rotatePoint. Note: `computeCentroid` returns the bounding-box centre, not a centroid; say so in a
  comment (or one `bbox` and `bboxCenter`) rather than rename 24 call sites.
- [~] **SPLIT8. `input-manager.lua` (922) and `object-manager.lua` (967).** No split needed; the
  function extractions in CL22 and CL26 are enough.
