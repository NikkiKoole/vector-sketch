# Tooling Ideas: Instrumenting for AI Collaboration

Tools to bridge the gap between "I can read code" and "I can understand what the app is doing at runtime." The app is a visual physics editor — most interesting state is runtime state that an AI collaborator can never see directly.

---

## What the AI Is Blind To Right Now

- What the physics world looks like after loading a scene (body positions, joint connections, fixture shapes)
- What happens during a simulation (did a joint break? did bodies drift?)
- What textures/meshes look like when rendered
- Whether a character was assembled correctly (are all parts connected? are offsets right?)
- What the user sees when something "looks wrong"

---

## Tool 1: State Snapshot to JSON (`love . --dump`)

**What**: A CLI mode that loads a scene, optionally runs N physics steps, and writes the full world state to a readable JSON file.

**Usage**:
```bash
love . --dump scripts/test.playtime.json
love . --dump scripts/test.playtime.json --steps 60
love . --dump scripts/test.playtime.json --steps 60 --out snapshot.json
```

**Output** (`snapshot.json`):
```json
{
  "scene": "scripts/test.playtime.json",
  "stepsRun": 60,
  "bodyCount": 12,
  "jointCount": 8,
  "bodies": [
    {
      "id": "abc123",
      "label": "torso1",
      "type": "dynamic",
      "x": 100.5,
      "y": 300.2,
      "angle": 0.03,
      "linearVelocity": [0.1, 2.3],
      "angularVelocity": 0.0,
      "fixtureCount": 3,
      "fixtures": [
        { "id": "fix1", "subtype": "texfixture", "isSensor": true },
        { "id": "fix2", "subtype": null, "isSensor": false, "shape": "polygon", "vertexCount": 8 }
      ]
    }
  ],
  "joints": [
    {
      "id": "jnt1",
      "type": "revolute",
      "bodyA": "abc123",
      "bodyB": "def456",
      "anchorA": [100.5, 280.0],
      "anchorB": [100.5, 260.0],
      "limitsEnabled": true,
      "lowerLimit": -0.39,
      "upperLimit": 0.39
    }
  ],
  "registry": {
    "bodies": 12,
    "joints": 8,
    "sfixtures": 5
  }
}
```

**What this enables**:
- Diff two snapshots to see what changed after a code modification
- Verify scene loads correctly without visual inspection
- Check physics simulation outcomes (did bodies settle where expected?)
- Debug "it looks wrong" by comparing expected vs actual positions

**Implementation**: Hook into `main.lua`'s arg parsing (the `--test` pattern already exists). Use `io.lua`'s `gatherSaveData` as a starting point, add runtime physics state on top.

**Effort**: Low-medium. Most serialization logic exists in `io.lua`.

---

## Tool 2: Scene Validator (`love . --validate`)

**What**: Loads a scene and checks invariants. Reports violations without rendering anything.

**Usage**:
```bash
love . --validate scripts/test.playtime.json
```

**Output**:
```
Validating: scripts/test.playtime.json
  [OK] 12 bodies loaded
  [OK] 8 joints loaded, all reference live bodies
  [OK] 5 sfixtures loaded, all are sensors
  [OK] Registry counts match world counts
  [OK] No NaN/inf in positions or velocities
  [WARN] Body 'abc123' has 0 non-sensor fixtures (no collision shape)
  [FAIL] Joint 'jnt5' references body 'xyz789' which is not in registry
  [FAIL] SFixture 'sf3' has sensor=false (should always be true)
  [WARN] Texture 'textures/missing.png' referenced but file not found

Result: 2 failures, 2 warnings
```

**Checks to implement**:

| Check | Severity | What It Catches |
|-------|----------|----------------|
| Every joint's bodyA and bodyB exist | FAIL | Orphaned joints after body deletion |
| Every registry ID maps to a live object | FAIL | Registry/world desync |
| All sfixtures have sensor=true | FAIL | Known bug from TODO comments |
| No NaN/inf in positions, velocities, angles | FAIL | Physics explosion |
| No duplicate IDs in registry | FAIL | UUID collision or registration bug |
| All texture URLs resolve to files | WARN | Missing assets |
| Every body has at least one non-sensor fixture | WARN | Bodies that can't collide |
| Joint anchor positions are reasonable (not 10000 units away) | WARN | Misconfigured joints |
| Body positions are within reasonable bounds | WARN | Bodies that flew off screen |
| World body count matches registry body count | WARN | Unregistered bodies |

**What this enables**:
- Catch "vertices aren't populated after load" (the known bug)
- Catch "sfixtures sensor=false" (the known bug)
- Catch "destroyBody doesn't destroy joints" (the known bug)
- Run after any code change to verify nothing broke
- Could be added to the test suite: `love . --test` runs validator on test scenes

**Implementation**: New file `src/validator.lua`. Iterate world bodies/joints/fixtures and check each invariant. Entry point in main.lua alongside --test.

**Effort**: Low. Just iteration and checks, no complex logic.

---

## Tool 3: Character Assembly Report (`love . --check-character`)

**What**: Creates a character from DNA and reports the full assembly tree — what connected to what, at what offsets, with what joint types. Flags suspicious values.

**Usage**:
```bash
love . --check-character humanoid --scale 0.15
```

**Output**:
```
Character Assembly Report: humanoid (scale=0.15)
Creation: isPotatoHead=true, torsoSegments=1, neckSegments=0, noseSegments=1

Assembly Tree:
  torso1: pos=(100,300) angle=0.00 shape=shape8(shapeA1.png) 8 vertices
    ├── luarm: joint=revolute at parent vertex 7, offset=(-45,-120)
    │   └── llarm: joint=revolute at parent h/2=(0,100)
    │       └── lhand: joint=revolute shape=shape8(hand3r.png)
    ├── ruarm: joint=revolute at parent vertex 3, offset=(45,-120)
    │   └── rlarm: joint=revolute at parent h/2=(0,100)
    │       └── rhand: joint=revolute shape=shape8(hand3r.png)
    ├── luleg: joint=revolute at parent lerp(v6,v5,0.5)
    │   └── llleg: joint=revolute at parent h/2=(0,100)
    │       └── lfoot: joint=revolute shape=shape8(feet6r.png) angleOffset=pi/2
    ├── ruleg: joint=revolute at parent lerp(v4,v5,0.5)
    │   └── rlleg: joint=revolute at parent h/2=(0,100)
    │       └── rfoot: joint=revolute shape=shape8(feet6r.png) angleOffset=-pi/2
    ├── lear: joint=revolute at parent lerp(v8,v7,0.5) stanceAngle=-1.26
    ├── rear: joint=revolute at parent lerp(v2,v3,0.5) stanceAngle=1.26
    └── nose1: joint=revolute at parent midlineLerp(v1,v5,0.35)

Textures:
  torso1: skin(main+patch1+patch2) + bodyhair(borsthaar4) + connected-skin(leg5->head) + connected-hair(hair10->head) + haircut(hair7, idx 6->2)
  head: [NOT CREATED - isPotatoHead=true]
  luarm: connected-skin(leg5->lhand) + connected-hair(hair10->lfoot)  ← endNode mismatch?
  ruarm: connected-skin(leg5->rhand) + connected-hair(hair10->lfoot)  ← endNode mismatch?
  lfoot: skin(main)
  rfoot: skin(main)
  lhand: skin(main)
  rhand: skin(main)
  lear: skin(main)
  rear: skin(main)
  nose1: skin(main, shapeA2)

Warnings:
  [WARN] luarm connected-hair endNode='lfoot' — expected 'lhand' for arm part
  [WARN] ruarm connected-hair endNode='lfoot' — expected 'rhand' for arm part
  [WARN] rear dims.w=10 vs lear dims.w=100 — large asymmetry
  [WARN] nose1 dims.w=40, h=40 with shape8(shapeA2.png) — shape8 dims are sx/sy scaled, w/h unused

Parts: 14 created, 0 failed
Joints: 13 created, all limits set
```

**What this enables**:
- Immediately see if DNA changes produce the expected skeleton
- Catch wiring bugs like the lfoot/lhand endNode mismatch (which actually exists in the current code)
- Verify that segmented parts (multi-torso, multi-neck, nose chain) connect correctly
- Compare reports before/after DNA refactoring to ensure nothing changed

**Implementation**: New file `src/character-report.lua`. Walk the DNA, call the existing topology functions, format the output. Doesn't need to create actual physics bodies — can operate on DNA data alone if the topology-as-data refactor happens first. Or with current code, create the character, inspect the result, destroy it.

**Effort**: Medium. Needs to understand the character assembly pipeline, but output is just text.

---

## Tool 4: Structured Event Logging

**What**: Replace ad-hoc `logger:info()` with structured events that write to a queryable file.

**Current state**: Logging is `logger:info('joint:', parent, partName)` — useful for printf-debugging but impossible to analyze programmatically.

**Proposed**:
```lua
-- src/events.lua
local events = {}
local log = {}

function events.emit(type, data)
    data._type = type
    data._time = love.timer.getTime()
    data._frame = love.timer.getFPS()
    table.insert(log, data)
end

function events.save(filename)
    -- Write log as JSONL (one JSON object per line)
end

function events.query(type)
    -- Return all events of a given type
end

return events
```

**Usage in code**:
```lua
-- Instead of: logger:info('joint:', parent, partName)
events.emit('joint_created', {parent=parent, child=partName, type='revolute', id=id})

-- Instead of: logger:info('Updating SFixture Position')
events.emit('sfixture_moved', {id=fixtureID, oldPos={oldX,oldY}, newPos={localX,localY}})

-- Instead of: logger:warn('blob surface wanted instead?')
events.emit('warning', {msg='blob surface requested', vertCount=#polyVerts})
```

**Output** (`events.jsonl`):
```jsonl
{"_type":"scene_loaded","_time":0.5,"file":"scripts/test.playtime.json","bodies":12,"joints":8}
{"_type":"joint_created","_time":0.6,"parent":"torso1","child":"luarm","type":"revolute","id":"abc123"}
{"_type":"body_destroyed","_time":5.2,"id":"def456","reason":"user_delete"}
{"_type":"sfixture_moved","_time":5.3,"id":"sf1","oldPos":[10,20],"newPos":[30,40]}
```

**What this enables**:
- Grep for specific event types: "show me all joint_created events"
- Trace what happened: "what events occurred between frame 100 and frame 200?"
- Find correlations: "every time a body is destroyed, is the joint also cleaned up?"
- Compare event logs between two runs to find behavioral differences

**Implementation**: New file `src/events.lua`, ~50 lines. Then incrementally replace `logger:info()` calls in key places.

**Effort**: Low for the framework. Medium to instrument all the interesting call sites.

---

## Tool 5: Save/Load Round-Trip Checker (`love . --roundtrip`)

**What**: Loads a scene, saves it to a temp file, loads the temp file, and compares the two world states. Reports any fields that didn't survive serialization.

**Usage**:
```bash
love . --roundtrip scripts/test.playtime.json
```

**Output**:
```
Round-trip test: scripts/test.playtime.json

Load 1: 12 bodies, 8 joints, 5 sfixtures
Save -> /tmp/roundtrip.playtime.json
Load 2: 12 bodies, 8 joints, 5 sfixtures

Comparing...
  [OK] Body count matches
  [OK] Joint count matches
  [OK] All body positions match (tolerance: 0.01)
  [OK] All joint types match
  [FAIL] Body 'abc123' field 'thing.vertices' differs:
         Load 1: {10, 20, 30, 40, 50, 60}
         Load 2: {} (empty)
  [WARN] Body 'def456' fixture groupIndex: -1 vs 0

Result: 1 failure, 1 warning
```

**What this enables**:
- Directly catches the "vertices aren't populated after load" bug
- Catches any serialization gaps (fields saved but not loaded, or vice versa)
- Can run on every scene file as a regression test
- Validates that io.lua's save and load are inverses of each other

**Implementation**: Use existing `io.gatherSaveData` for the "before" snapshot, save with `io.save`, load with `io.load`, gather again for "after", deep-compare. The comparison logic is the new part.

**Effort**: Medium. The save/load is done, the comparison function is the work.

---

## Tool 6: Screenshot with Metadata

**What**: A key binding (e.g. F12) that saves both a screenshot and a companion JSON file describing the world state at that moment. When the user shares a screenshot in conversation, the AI can read the JSON to understand context.

**Usage**: Press F12 in the app.

**Files created**:
```
screenshots/shot_2024_001.png    -- the visual
screenshots/shot_2024_001.json   -- the context
```

**JSON content**:
```json
{
  "timestamp": "2024-11-20T14:30:00",
  "camera": { "x": 325, "y": 325, "scale": 1.5 },
  "windowSize": [1000, 800],
  "mode": "drawClickPoly",
  "paused": true,
  "selection": {
    "selectedBody": "abc123",
    "selectedJoint": null,
    "selectedSFixture": null
  },
  "panelsOpen": ["worldSettings", "addShape"],
  "bodyCount": 12,
  "jointCount": 8,
  "fps": 60,
  "bodies": [
    { "id": "abc123", "label": "torso1", "x": 100.5, "y": 300.2, "angle": 0.03, "onScreen": true }
  ]
}
```

**What this enables**:
- User shares screenshot: "this looks wrong"
- AI reads the companion JSON to know: what's selected, where the camera is, what mode the editor is in, what bodies are visible
- Much richer context than just a screenshot alone

**Implementation**: Add a keybinding in main.lua. Use `love.graphics.captureScreenshot` for the image. Use `io.gatherSaveData` + camera/UI state for the JSON.

**Effort**: Low. LÖVE has built-in screenshot support, and most state is already accessible.

---

## Implementation Priority

| Tool | Effort | Value for AI Collaboration | Dependencies |
|------|--------|---------------------------|-------------|
| 2. Scene Validator | Low | **Highest** — catches known bugs, runnable in CI | None |
| 1. State Dump | Low-medium | **High** — enables diffing and state inspection | None |
| 5. Round-Trip Checker | Medium | **High** — catches serialization bugs | None |
| 6. Screenshot + Metadata | Low | **High** — bridges visual gap | None |
| 4. Structured Events | Low (framework) | Medium — useful for debugging sessions | None |
| 3. Character Report | Medium | Medium — specific to DNA work | None, but benefits from DNA refactor |

Tools 1, 2, and 5 all share the same entry point pattern (`main.lua` arg parsing) and could share a `src/cli.lua` module that routes `--dump`, `--validate`, `--roundtrip`, `--test` to the right code.
