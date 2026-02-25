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

- [x] **Node/influence types** — `src/node-types.lua` (joint, anchor)
  - [x] 2 constants, adopted in 6 files
  - [x] Note: `node.type` (creation) vs `infl.nodeType` (influence) naming is structural, not a bug

- [x] **Script event names** — `src/script-events.lua` (onStart, beginContact, etc.)
  - [x] 6 constants, adopted in 3 files

- [x] **File extensions** — `src/file-extensions.lua` (.playtime.json, .playtime.lua)
  - [x] 2 constants, adopted in 2 files

- [x] **Side identifiers** — `src/sides.lua` (A, B, bodyA, bodyB)
  - [x] 4 constants, adopted in 4 files
