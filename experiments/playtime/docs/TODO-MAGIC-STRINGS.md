# Magic String Centralization TODO

Scattered string literals that should be constants modules. Typo = silent bug.

## Done

- [x] **Sfixture subtypes** — `src/subtypes.lua` (snap, anchor, texfixture, etc.)
  - [x] Module created with constants + `is()` + `migrate()`
  - [x] All hardcoded strings replaced across all files

- [x] **Shape types** — `src/shape-types.lua` (rectangle, circle, capsule, etc.)
  - [x] 14 constants, adopted in 8 files

- [x] **Joint types** — `src/joint-types.lua` (distance, weld, revolute, etc.)
  - [x] 9 constants, adopted in 8 files (including joint-handlers.lua)

- [x] **Body types** — `src/body-types.lua` (dynamic, static, kinematic)
  - [x] 3 constants, adopted in 6 files

## Medium priority

- [ ] **Node/influence type strings** — 15+ occurrences, 6 files, inconsistent naming
  - `'joint'`, `'anchor'` — sometimes `node.type`, sometimes `infl.nodeType`
  - Files: editor-render, input-manager, io, box2d-draw-textured, sfixture-editor, character-manager

## Low priority

- [ ] **Script event names** — 6 occurrences, 3 files
  - `'onStart'`, `'beginContact'`, `'endContact'`, `'preSolve'`, `'postSolve'`

- [ ] **File extensions** — 3 occurrences, 2 files
  - `'.playtime.json'`, `'.playtime.lua'`

- [ ] **Side identifiers** — 8 occurrences, 4 files, inconsistent quoting
  - `'A'`/`'B'` vs `"A"`/`"B"`
