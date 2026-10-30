# Code cleanup — simpler, less copy-paste (October 2026 review)

status: active

From the 7-agent read-only review of 2026-10-30. The aim is plain, boring code: delete what's
dead, write each small thing once, give modules one job. Line numbers as of commit 65c48eb8; a
file:line is where to start looking, not a promise. Bugs from the same review are in
`CODE-BUGS-2026-10.md` (do those first); splitting the big files is `CODE-SPLITS-2026-10.md`
(after this). The older Feb list `CODEBASE-CLEANUP.md` (parked) still has a few of its own items
(shape8 anchor logic, UVUSERT, `thing.zOffset`).

Order: delete (CL1-CL5), then the small helpers (CL6-CL12), then the bigger de-duplication
(CL13-CL18), then module jobs (CL19-CL26). Sizes: S = under half an hour, M = an hour or two,
L = more.

## Delete

- [x] **CL1. Dead modules.** `src/character-experiments.lua` (only reachable through commented-out
  code), with its require, its call and the commented `createCharacter` lines in `love.load`;
  `src/benchmarks.lua`; `tests/` and the `--test` branch at the top of `main.lua`.
  **Done 2026-10-30.**
- [ ] **CL2. Unused functions.** **Done 2026-10-30:** `io.reload`, `uuid.uuid128` / `uuid64_base62` /
  `uuid128_base62`, draw-textured `setShrinkFactor` / `getShrinkFactor`, `ui.dropdown`,
  `ui.centeredLabel`, `playtime-ui` `assignTrianglesToGroup`, `utils.printTableKeys`, `Logger.new`,
  pointerjoints `onPressedFunc` and its empty connector loop. Not unused after all: `registry.print`
  (world settings calls it through `require(...)`), `io` `getNewId` (load calls it; an identity
  function, could be inlined), `isRecordingPointers` (the tool rail reads it, nothing sets it).
  Left: `character-manager` `updateShape8`, `getBoundingBox`, `instance.textures` /
  `instance.positioners` (after the ears work); `music.stepAt`, music `lib.trace`,
  `mipoVoice.squeakBody`, `synth.isRunning` (with BUG7); on `state` (restart the game after:
  hot-swapping state.lua unsettles it) `positioningMesh`, `jointLengthParams`, `lastSelectedBody`,
  `axisEnabled`, `showTexFixtureDim`, `texFixtureEdit.verts`. S.
- [x] **CL3. Unused maths.** `math-utils.lua`: `unloosenVanillalineOLD` with `unpackNodePoints` /
  `evenlySpreadPath`, `slicePolygon` with `findIntersections` (`splitPoly` stays: `decompose` uses
  it). `polyline.lua` is `polyline.miter(coords, halfWidth)` now, 383 → 93 lines, same output (checked
  on 500 random lines). **Done 2026-10-30**, `spec/polyline_spec.lua`.
- [ ] **CL4. Commented-out code.** **Done 2026-10-30** in src/ and main.lua: ~640 lines, found by
  a script that takes a run of `--` lines as code only when the text compiles as Lua, then read
  through. Left: character-manager, character-topology, io.lua (other work in them), state.lua,
  and the sound files (with BUG7). S.
- [ ] **CL5. slide-sound: delete or say it's parked.** `lib.enabled = false` since 2026-10-27, but it
  still runs every frame and the `whistle` patch keeps a synth slot. S.

## Write small things once

- [ ] **CL6. Use the maths helpers.** `math.max(a, math.min(b, x))` is written out 40 times in 16
  files while `mathutils.clamp` is used twice. Same for lerp (25 inline), remap (12), distance (34),
  and angle wrapping `(a + pi) % 2pi - pi` (7: mipo-actions, keep-angle, blob). Local copies:
  `clamp` character-topology:86, `clampAxis` camera-follow:160, `lerpClamped` slide-sound:86,
  `mapInto` mipo-voice:367, `lerp` draw-textured:87, `getDistance` / `lerp` inside math-utils itself.
  Fix: `mathutils.clamp / lerp / remap / dist / wrapAngle`, one mechanical pass. M.
- [ ] **CL7. `thingOf(body)`.** `getUserData().thing` is written ~80 times in 26 files, 8 of them
  calling `getUserData()` twice. `ui/on-stage.lua:14` already has a private `thingOf`; move it to
  registry or utils. M.
- [x] **CL8. `fixtures.findSFixture(body, subtype)` / `eachSFixture`.** 44 loops over
  `getFixtures()` in 20 files, several with `type(ud) == 'table' and subtypes.is(ud, X) and ud.extra`
  ladders (object-manager:608, 621, blob:409, input-manager:41, liquid). S-M.
  **Done 2026-10-30:** `fixtures.sfixtureData(body, subtype)` (their userData), used in
  object-manager (2) and input-manager. Most of the 44 loops want every fixture or several
  subtypes at once, blob and liquid loop over the registry now, snap's one-liner stays (it's
  in the registry/snap require cycle), draw-textured's decal loop goes with CL20.
- [x] **CL9. `behaviors.find(body, name)`.** Written four times: signals:24 `findBehavior`,
  doors:26 `doorOf`, mipo-voice:470 `isSquishy`, mipo-actions:38. Plus `isSignal(b)` for the test
  repeated 3x in signals. S. **Done 2026-10-30:** `behaviors.all / find / isSignal`; a shadowed
  `behaviors` loop variable in `signals.renameForCopy` renamed on the way.
- [x] **CL10. One list of shape dimension keys.** radius/width/width2/width3/height/height2-4 are
  copied ~10 times (io:422, 944, 1294, 1385; object-manager:327, 363, 409, 492, 590, 695) and the
  copies disagree (BUG3). Fix: `shapes.DIM_KEYS`, `copyDims(from, to)`, and a
  `DIMS[shapeType]` table used by io's `needsDimProperty` and body-params. S.
  **Done 2026-10-30:** `shapes.DIM_KEYS`, `copyDims(from, to, over)`, `usesDim(key, shapeType)` (was io's
  `needsDimProperty`; capsules also keep height2 as before) and `usedDims(thing)` in shapes.lua; io load,
  save and clone, object-manager create, rebuild and the ten-copies tool, and body-params use them.
  Clone no longer turns a missing width2 into 1. Editor spawn defaults stay apart (one preference each).
  `spec/shapes_spec.lua`, `spec/io_spec.lua`.
- [x] **CL11. Mipo body helpers in one place.** `part.body and not part.body:isDestroyed()` 37 times;
  subtree walk 4 times (character-manager `subtreeOf`, mipo-actions `subtreeBodies`, joint-guard
  `collectSubtree`, body-rotate `collectDescendants`); parent-child joint lookup 4 times; Mipo
  total mass 3 times (input-manager:242, snap:241, mipo-actions:22); `mass * 9.8 * units.meter()`
  3 times; "scale density to a mass" in balanceArms/Head/Neck. Fix: `src/mipo-parts.lua`
  (`liveBody`, `subtreeBodies`, `jointBetween`, `totalMass`, `scaleMass`) and `units.weight(mass)`. M.
  **Done 2026-10-30:** `mipoRegistry.totalMass / subtreeBodies / jointBetween(parent, child, type)`
  replace the copies in mipo-actions, character-manager, snap and input-manager; `units.weight(mass)`
  the three `mass * 9.8 * units.meter()`. Left on purpose: the inline
  `part.body and not part.body:isDestroyed()` (a short readable line, also on plain things), the
  joint guard's `collectSubtree` (part names, not bodies), body-rotate's walk (any bodies), and the
  balance* density scaling (with CL18). `spec/mipo-registry_spec.lua`.
- [ ] **CL12. Small copies.** `C.x[math.ceil(math.random() * #C.x)]` 31 times → `pick(list)`;
  weighted pick 3 times (mipo-chatter:30, music:664, 719); `setting(extra, key)` in liquid, grass,
  blob; `hexColor` in liquid and grass (use `hexToColor`); `doubleControlPoints` in draw-textured:1629
  and spine-mesh:84; "subtract the centroid" in box2d-draw:56, editor-render:434, cdt:383 (use
  `makePolygonRelativeToCenter`); `getPointerPosition` in recorder:75 and pointerjoints:9; main's
  `getRelativePath` = `utils.getPathDifference`; dna-defaults `deepCopySimple` = `utils.deepCopy`;
  bone/group colour hash `(b*97)%256` in sfixture-editor and editor-render. S each.

## Bigger de-duplication

- [x] **CL13. Joints written once.** Joint properties are read and written three times: load
  (io:462-575), save (io:1135-1198) and joint-handlers. After BUG1's `apply`, load and save use the
  handlers; about 200 lines go from io.lua. M.
  **Done 2026-10-30:** save writes `handler.extract`, load builds through `joints.createJoint`;
  the file format stays (axis and pulley ground anchors converted at the edge). Revolute and
  friction joints take a loaded scene's anchor B. io.lua -220 lines. Every joint of every scene in
  scripts/ (1812 revolute, 28 wheel, 4 prismatic, 2 friction, 2 rope) compared before and after,
  loaded and round-tripped: identical. `spec/joints-save-load_spec.lua` covers all nine types.
  Files now also keep a disabled motor's speed and disabled limits.
- [x] **CL14. Connected texture and trace vertices onto the inspector.** `ui/sfixture-editor.lua:1288-1872`
  (~580 lines) copies texture / hairs / plasticine settings that `texfixture-params` already has,
  and the copies drifted. Fix: `[CONNECTED_TEXTURE]` and `[TRACE_VERTICES]` in
  `sfixtureParams.bySubtype` (position + a few own rows + `texfixtureParams.texture/.hairs/.plasticine`),
  then delete the hand-made branch and the helpers only it uses (:158-291). Removes BUG4 and BUG10. M.
  **Done 2026-10-30:** `sfixtureParams.bySubtype` has connected texture (add node, nodes from joints,
  width, bend, direction), trace vertices (from/to vertex, tension, spacing, width) and decals
  (position); both strips share `texfixtureParams.texture/hairs/plasticine` and `position`. The hand-made
  branch and its helpers are gone: sfixture-editor.lua 1854 -> 1130 lines. Hairs now also get the
  light and mottle rows (one `surfaceLight` list both shaders read). New strips get their defaults
  when made (fixture-types), not the first time the old panel was drawn. `spec/inspector_spec.lua`
  runs every row of the new panels.
- [x] **CL15. `forPartAndMirror` in the Mipo editor.** "Apply to this part, then its mirror if
  symmetric, then rebuild textures" is pasted ~18 times (`ui/mipo-editor.lua` 1087, 1146, 1250,
  1265, 1355, ...); connected skin and connected hair (1786-1962) are near-copies; "all torso
  segments" loops 9 times. Fix: `forPartAndMirror(instance, part, fn)` + `forAllTorso`, one
  `drawConnectedAccordion(kind, ...)`. Likely 300+ lines less. Also the shape grid (1065) mirrors with
  symmetric off. M.
  **Done 2026-10-30:** `partAndMirror`, `editPartAndMirror` (rebuilds once) and `bodyhairParts`
  (whole torso, else part + mirror) in `ui/mipo-editor.lua`; shape, dims, skin, bodyhair, connected
  skin and hair all go through them, 2023 -> 1820 lines. The shape grid follows the symmetric
  checkbox now. Connected skin and hair stay two panels (bendiness, masks and 'none' differ), each
  edit one `setConnectedSkin/Hair(vals)` line. 45 `tonumber` calls after sliders dropped (BUG14).
  `spec/mipo-editor_spec.lua` (also draws every panel open for every part).
- [x] **CL16. Render copies.** Shader setup 3 times (draw-textured 2546, 3106, 3299; caused BUG11)
  → `beginSurfaceShader(extra, body)`. LBS skinning loop 3 times (1923, 1976, 2026) → `lbsVertex`.
  Rigid bone blend twice (2865, 2885). Mouth curve points 4 times (3495, 3550, 3596, 3646) and upper/lower
  reordering 3 times. `composedZ` line 10 times in createDrawables. `browBends` (3423) = `browBendVecs`
  (38). Alpha divided by 5 in `makeTexturedCanvas` and multiplied by 5 by every caller (its own TODO
  says so): pass 0-1. M.
  **Done 2026-10-30** (shader setup was BUG11): one `lbsVertex` for the three linear-blend loops; one
  `placeVertex` and one vertex list (with or without UVs) for MESHUSERT; one `animatedCurvePoints` for the
  four mouth copies; `composedZ` once per sfixture; the brow bend shapes one table (mipo-face); alpha no
  longer *5 then /5. Checked: 8 scenes render the same pixels (also with every mouth animated), the 9 skinned
  meshes in the Knut scenes get the same vertices, skinning output the same number for number. Left: the
  lip order flip (3x), makeTexturedCanvas' 17 arguments. Found on the way: as written, the 'DQS' blend
  is algebraically the same as LBS (the blended rotation cancels: R·b + Σw(P - R·b)/Σw = ΣwP/Σw), so
  `useDQS` changes nothing; a real fix for the candy-wrapper collapse would blend positions differently.
- [x] **CL17. Clone through the library path.** `cloneSelection` (io:1252-1598, ~350 lines) rebuilds
  shapes by hand with its own id map and influence remap. `library.place` already does gather →
  renewIds → move → buildWorld additive. Clone = the same with the selection, +50,+50. Keep only
  the Mipo pose copy if clones should keep their pose. L, worth it.
  **Done 2026-10-30:** `library.clone(things)`: the selection's save data (a Mipo whole), new ids
  (Mipo ids too), its own signal names, +50,+50, built; `place` and `clone` share those steps.
  `io.cloneSelection` (~320 lines) and its influence remapper are gone. A Mipo keeps its pose; any
  selected part now copies the whole Mipo (before: only the selected parts). Ribbon nodes on a joint
  that wasn't copied keep pointing at the original (before: lost). `spec/clone_spec.lua` passed on
  the old clone first.
- [x] **CL18. Character copies.** `addFaceDecals` (character-manager:1884-2222, ~340 lines): the OMP
  block 5 times → `ompMain(...)`, `addDecal(body, label, extra)`, then placeEyes/Brows/Nose/Mouth.
  Loose z numbers (190, 220, 250-254, 300, ...) → one `Z = {...}` table (`TORSO_SKIN_Z` exists but
  :1065 writes 192). DNA prep twice (:2519, :2765) → `prepareDNA`; group/z loop 4 times →
  `applyGroupAndZ`; instance constructor 3 times; physics settings twice. `randomizePart` redoes
  the other randomizers; `randomizeMipo` / `randomizeMipoConstrained` differ only in opts. Teeth
  `newImage` per rebuild just for its size. M-L.

## One job per module

  **Done 2026-10-30:** face decals through `addDecal / omp / maskOf / maskedOrPlain` and a `FACE_Z`
  table, split into placeEyes / Brows / Nose / Mouth around one face box (teeth size cached, not a
  newImage per rebuild); `newInstance`, `prepareDNA` (with `migrateDNA`, the nose-490 fix moved in),
  `partSettings` and `applyGroupAndZ` replace the copies; `pick(list)` and `randomLook()`, one
  `randomizeAll` behind randomizeMipo / Constrained, arm/leg and foot/hand branches folded. Random
  draws kept in the same order. character-manager.lua 2886 -> 2470 lines. Checked with a one-off
  snapshot (10 seeded Mipos: randomized, parts randomized, rebuilt, potato, saved and loaded; every
  fixture, decal and joint): identical before and after.
- [ ] **CL19. `sound.update(dt)`.** See BUG7: synth, music, snap and slide out of mipo-voice. S-M.
- [x] **CL20. The renderer only draws.** Blink, brows, mouth tween and the click-to-pull-a-face
  (`box2d-draw-textured.lua:30-283`, polls `love.mouse.isDown` inside draw) → `src/mipo-face.lua`,
  called from update. The mouth-decal migration in `initFaceDecals` → io.lua load. `hexToColor` and
  `palette` (used by 5 UI modules) → `src/color.lua`, and cache the colours instead of parsing hex
  per drawable per frame. `cdt.computeResourceMesh` → resource-link (and just require mathutils). M.
  **Done 2026-10-30:** blink, brows, mouth tween and the pull-a-face click in `src/mipo-face.lua`, ticked
  from love.update; `src/color.lua` (palette, hexToColor remembered) for the renderer, UI, grass and
  liquid. Left: the old mouth-decal migration still runs when a face first ticks (not at load), and
  computeResourceMesh stays in cdt.lua next to refreshResourceMesh.
- [ ] **CL21. MESHUSERT binding out of the UI.** `ui/sfixture-editor.lua:368-692, 702-737, 1026-1130`:
  the bind maths are closures inside a button handler; vertex prep 3 times, "clear bind state" 5
  times, `for _, rv in ipairs({ resourceLink.find(ud) })` 4 times (just `local rv = ...; if rv`).
  → `src/meshusert-bind.lua` (prepBindVerts, bindDQS, bindSpine, clearBind, autoAssign*,
  splitTriangles), with specs. M-L.
- [x] **CL22. Polygon editing out of object-manager.** `object-manager.lua:84-311` (finalizePath,
  finalizePolygon, ribbon pair / custom vertex insert+remove) → `src/poly-edit.lua`. The three
  "rebuild an sfixture with new points" functions (fixtures.updateSFixturePosition,
  updateSFixtureDimensions, objectManager.maybeUpdateTexFixtureVertices) → one
  `fixtures.replaceShape(fixture, points)`; two of them drop friction/groupIndex. Small ones:
  `addThing` only wraps `createThing`; both flip axes do the same; `joints.reattachJoints` A and B
  branches differ by side; `tranlateBody`; `recreateJoint` logs a missing handler and calls it anyway. M.
  **Done 2026-10-30:** `src/poly-edit.lua` (draw a polygon or path, add/remove vertices, apply edited
  texfixture corners), object-manager 829 -> 570 lines. `fixtures.replaceShape(fixture, points, ud)`
  for move, resize, edited corners and N/E/S/W/C (resize and corners lost friction and group);
  `updateSFixtureDimensions` takes the fixture instead of reading the selection. Delete radius named,
  the doubled `if edge` gone. `recreateJoint`'s missing-handler return was BUG1. Still small and open:
  `addThing` only wraps `createThing`, `reattachJoints`' A/B branches, `tranlateBody`.
  `spec/poly-edit_spec.lua`, `spec/fixtures_spec.lua`.
- [x] **CL23. `shape8Dict` as its own data file.** It lives in character-manager (:924-1015), gets
  pushed into topology via `setShape8Dict`, and spine-skin / blob require character-manager lazily
  just to read it. Move it to shape-catalogs or its own file; the setter and lazy requires go. S.
  **Done 2026-10-30:** `src/shape8-dict.lua` (data only); topology, spine-skin, blob and specs
  require it, nothing loads character-manager to read shapes. `topology.setShape8Dict` stays for
  specs (the topology spec puts the real shapes back after).
- [ ] **CL24. Plain requires.** 134 lazy `require(` calls, 9 `local function x() return require(...) end`
  wrappers; the `state()` ones (sfixture-params:13, texfixture-params:10, world-params:8) and
  behaviors:9 break no cycle. Only registry ↔ snap needs a lazy require; comment it with the cycle.
  187 bare `require 'x'`, 43 with hyphens (CLAUDE.md says parentheses) → one sed pass. S.
- [ ] **CL25. Names.** `addTexturesFromInstance2` (131 call sites, no version 1) → `rebuildTextures`
  (alias for a while); `bud` (draw-textured:3359), `mud` (sfixture-editor:403, 707), `j` for joints
  (16 places), `fud` vs `ud` (38 places); raw subtype strings in editor-render:95 and draw-textured:180;
  topology's `guy` → `instance`; signals' module-level `triggers` vs the local in `lib.wires`. S.
- [ ] **CL26. Long functions in input and music.** `input-manager.lua` `handlePointer` (:333-614):
  `pressedPlaceSteiner`, `findVertexNear` (polyEdit and texFixtureEdit loops are the same),
  `clearSelectionAndPanels` (":533, todo this is dumb"), `brushTriangles` (6 deep, :728-809),
  `pressedSetOffset(which)`; name the panel width 300 (4x), palette 400, grab radii 10/20/30.
  `music.lua` `bookBar` (~200 lines) and `planSong` → plain local steps; `rememberChord`,
  `pickupNote`, `bookPercussion`; styles carry data instead of switching by name (`bassLo = 38` on
  guaraldi, `groove = 'lofi'` instead of `drums == 'jazzhop'`). recorder's five record functions →
  `addEvent`. M each.

## Leave alone

The reviewers agreed these are clear and fine; don't churn them: registry, subtypes, resource-link,
library, toys, props, scene-loader, snap, camera-follow, play-mode, modes, physics-units,
contact-tracker, statemachine, tool-rail, inspector, textinput, right-column, on-stage,
spine-skin, spine-mesh, the cdt triangulation, mouth-shapes, blob and liquid physics, signals'
debounce, synth's patch table, mipo-registry, mipo-chatter, keep-angle, body-rotate, doors,
the `state.X = state.X or {}` hot-reload habit, and the "why" comments on tuning values.
