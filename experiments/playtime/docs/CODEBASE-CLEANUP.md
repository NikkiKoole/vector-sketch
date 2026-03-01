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
