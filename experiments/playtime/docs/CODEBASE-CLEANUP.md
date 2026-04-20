# Codebase Cleanup — AI-Friendliness Pass

Painpoints identified 2026-02-28. Work through top-to-bottom.

## 1. Extract repeated shape8 anchor logic
**Status:** TODO
**Why:** The `recenterPoints` bug existed in 4 identical copy-pasted blocks (ears, feet, hands, nose). We fixed all 4 separately. One shared function prevents this class of bug entirely.
**Where:** `src/character-manager.lua` — `getOwnOffset()` around lines 1155-1235
**Task:** Extract a single `getShape8AnchorPoint(part, index, scale)` function and call it from all 4 places.

## 2. Standardize module aliases
**Status:** TODO
**Why:** Same modules required with different names across files makes grep unreliable. Hard to find all call sites.
**Mismatches found:**
- `joints` vs `Joints` vs `jointslib` (5 files)
- `objectManager` vs `ObjectManager` (5 files)
- `box2dDrawTextured` vs `drawTextured` (3 files)
**Task:** Pick one canonical name per module, rename all aliases to match.

## 3. Add param docs to table-parameter functions
**Status:** TODO
**Why:** Functions like `updatePart(partName, values, instance)` accept tables with implicit keys. Have to trace callers to understand the contract.
**Priority targets:**
- `character-manager.lua`: `updatePart`, `updateSkinOfPart`, `updateFaceAppearance`, `updatePositioners`, `updateConnectedAppearance`
- `object-manager.lua`: `addThing`
- `io.lua`: save/load data structures
**Task:** Add one-line comments listing expected table keys, e.g. `-- values: {shape8URL, sy, sx, w, h}`

## 4. Split largest functions
**Status:** TODO
**Why:** Monster functions (600+ lines) are impossible to reason about in pieces. Bugs hide in deep branches.
**Targets (by size):**
- `mipo-editor.lua`: `drawMipoEditor()` ~1,300 lines — split into per-section draw functions
- `character-manager.lua`: `randomizeMipo()` ~620 lines — split into randomize sub-functions per body region
- `character-manager.lua`: `addFaceDecals()` ~323 lines — split per face feature
- `character-manager.lua`: `getOffsetFromParent()` ~253 lines — group by part category
**Task:** Extract named sub-functions within same file. No new modules needed.

## 5. Add module export comments
**Status:** TODO
**Why:** `randomizeMipo` lives on CharacterManager but sounds like it belongs to MipoEditor. Caused two bugs.
**Task:** Add a `-- Exports: functionA, functionB, ...` comment block near the top of each src/ module listing its public `lib.*` functions. Start with the most-used modules:
- `character-manager.lua`
- `object-manager.lua`
- `io.lua`
- `joints.lua`
- `fixtures.lua`
- `registry.lua`

## 6. Clean up dead code / stale comments
**Status:** TODO
**Why:** Commented-out code blocks add noise when scanning files. 45+ blocks across 14 files.
**Worst offenders:**
- `physics/box2d-draw-textured.lua` — 22 comment blocks
- `character-manager.lua` — 9 comment blocks
- `object-manager.lua` — 8 comment blocks
**Task:** Remove commented-out code that's been dead for 2+ commits. Keep genuine TODO comments.

## 7. Retire UVUSERT
**Status:** TODO
**Why:** UVUSERT is the ancestor of MESHUSERT — textured polygon riding a body, no skinning. MESHUSERT with no bound influences does the same thing, with cached triangulation and access to z-order groups. UVUSERT re-runs ear-clip every frame, so it's also slower at runtime. Kept around only because `scripts/uvs.playtime.json` and `scripts/resources.playtime.json` still reference it.
**Where:** `src/physics/box2d-draw-textured.lua:1851-1975` (draw path, ~125 lines incl. commented debug blocks), `src/subtypes.lua:11`, `src/object-manager.lua` creation path.
**Task:** Migrate UVUSERT → MESHUSERT-without-bones on load (`src/io.lua` subtypes.migrate already has the pattern — see `uvmappert` → `uvusert` rename). Delete the UVUSERT draw branch. Delete UVUSERT from `shape-panel.lua` UI if exposed. Retire the constant.
**Win:** ~125 lines off the draw path, one less sfixture variant to maintain, DECAL stays as the one "simple textured thing."

## 8. Remove dead `thing.zOffset`
**Status:** TODO
**Why:** Body-level `thing.zOffset` has no live readers — the render path that used it is commented out in `box2d-draw-textured.lua:939-942` and the UI slider is commented out in `body-editor.lua:228-235`. The **active** z-sort uses `ud.extra.zOffset` on the sfixture. Dual key paths invite confusion.
**Options:**
  - **Delete:** strip `thing.zOffset` from `createThing` defaults, `gatherSaveData`, `buildWorld`, comment-removed UI. Scenes saved with non-default values lose that data — but nothing reads it anyway.
  - **Wire up:** uncomment the render path, make it a body-wide override (added to every sfixture's composedZ). Gives us "move this whole body forward/back in z" without editing each sfixture.
**Task:** Pick one. Probably delete unless there's a real use case for body-wide z.

## 9. Retire `strip-merge.lua` + overlay when sure Goal 4 stays parked
**Status:** parked — live debug tool for now
**Why:** `src/strip-merge.lua`, `renderStripMergeOverlay` in `editor-render.lua`, the `main.lua` hook, and lazy `state.stripMergeOverlay` init were built during the merge+bridge experiment (Goal 4). Goal 4 is parked (see `MESH-DEFORM-PLAN.md`); the code remains as a useful debug tool. If Goal 4 stays parked after a few months of real character work, the code is dead weight.
**Where:** `src/strip-merge.lua` (~165 lines), `src/editor-render.lua:renderStripMergeOverlay`, `main.lua` call site, state init comment.
**Task:** If still unused in three months, delete the module + overlay + hook. Keep the Goal 4 section in `MESH-DEFORM-PLAN.md` as rationale.

## 10. Extract zOffset slider pattern (done this session, keep as reference)
**Status:** done 2026-04-20
**Why:** `sfixture-editor.lua` had 4 copies of the same zOffset slider (all labeled `texfixzOffset`, a leftover from when only TEXFIXTURE had one). MESHUSERT, UVUSERT, DECAL were missed.
**Done:** Added `ui.zOffsetSlider(id, extra, x, y, width)` helper in `src/ui/all.lua`. Replaced the 4 call sites; added to MESHUSERT. UVUSERT/DECAL still missing the slider (intentional — see #7).

## 11. Watch out for forward-reference bugs in io.lua
**Status:** done 2026-04-20 (root-caused)
**Why:** When adding a new `local function foo` near the bottom of a large module, it's easy to miss that a function earlier in the file already calls `foo` — Lua resolves it as nil global at runtime, not a compile error. Happened with `roundFloats` in io.lua; crashed every save attempt until the helpers were hoisted above `lib.save`. Specs didn't catch it because the `_test` table is at the tail and captures the locals fine.
**Task:** Convention: when adding helpers used by `lib.*` methods, put the helper block **above** the first `lib.*` method that needs it, not at the end near `lib._test`. Or: use a forward declaration (`local roundFloats` near the top, then `function roundFloats(...)` later).
**Possible tooling:** a luacheck rule or quick grep-at-commit-time check for "is this local called before its definition line?" — probably overkill for now. Awareness is the fix.
