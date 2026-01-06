# Playtime - Box2D Physics Editor

## Quick Summary

**Playtime** is a Box2D-based interactive physics editor and character animation tool built with LÖVE2D (Love2D). It allows users to create physics scenes with articulated bodies, joints, soft bodies, and textured characters through an interactive UI.

- **Language**: Lua (100%)
- **Framework**: LÖVE 11.3
- **Physics**: Box2D (via LÖVE's physics module)
- **Scene Format**: JSON (`.playtime.json` files)
- **Total Source**: ~17,000 lines across 33 modules

---

## Project Structure

```
playtime/
├── main.lua              (991 lines)  - Entry point, LÖVE callbacks, game loop
├── conf.lua                           - LÖVE configuration
├── src/                               - Core source modules (17,032 lines total)
├── tests/                             - Test suite (see Testing section)
│   ├── mini-test.lua                  - Single-file test framework
│   ├── run.lua                        - Test runner
│   ├── unit/                          - Pure Lua tests (no LÖVE required)
│   └── integration/                   - Tests requiring LÖVE runtime
├── scripts/                           - Scene files (*.playtime.json)
├── vendor/                            - Third-party libraries
├── assets/                            - UI icons and fonts
├── textures/                          - Character textures (~17MB)
└── backdrops/                         - Background images
```

---

## Module Reference (by size)

| Module | Lines | Purpose |
|--------|-------|---------|
| `playtime-ui.lua` | 3,527 | **LARGEST** - All UI panels (world settings, object inspector, joint editor, etc.) |
| `box2d-draw-textured.lua` | 1,860 | Textured rendering for physics bodies, mesh creation |
| `character-manager.lua` | 1,729 | Humanoid character creation, rigging, DNA/genetics system |
| `math-utils.lua` | 1,415 | 50+ math functions (geometry, splines, paths, vectors) |
| `io.lua` | 990 | Scene serialization/deserialization |
| `object-manager.lua` | 986 | Physics object creation, polygon finalization |
| `input-manager.lua` | 757 | Mouse/touch handling, drag operations, mode management |
| `ui-all.lua` | 658 | Base UI component library (buttons, sliders, panels) |
| `shapes.lua` | 567 | Shape generation (rectangles, circles, polygons) |
| `ui-textinput.lua` | 489 | Text input UI components |
| `polyline.lua` | 383 | Polyline/path operations |
| `editor-render.lua` | 373 | Editor overlays (selection, handles, guides) |
| `snap.lua` | 351 | Snap-to-grid and snap fixtures |
| `joints.lua` | 336 | Joint creation (revolute, distance, rope, weld, etc.) |
| `box2d-draw.lua` | 270 | Debug drawing for Box2D shapes |
| `fixtures.lua` | 246 | Fixture creation and management |
| `box2d-pointerjoints.lua` | 227 | Mouse/touch interaction with physics bodies |
| `recorder.lua` | 220 | Recording/playback of interactions |
| `joint-handlers.lua` | 189 | Joint-specific behavior handlers |
| `utils.lua` | 175 | Generic utilities (map, filter, tablelength) |
| `state.lua` | 135 | **CENTRAL STATE** - All application state |
| `script.lua` | 115 | Lua script loading for scenes |
| `selection-rect.lua` | 102 | Selection rectangle drawing |
| `scene-loader.lua` | 89 | Scene loading coordination |
| `registry.lua` | 82 | ID-based lookup for bodies, joints, fixtures |
| `keep-angle.lua` | 77 | Angle constraint behavior |
| `uuid.lua` | 66 | UUID generation |
| `camera.lua` | 63 | Camera/viewport management |
| `logger.lua` | 57 | Logging utility |
| `file-browser.lua` | 54 | File browser UI |
| `benchmarks.lua` | 42 | Performance benchmarking |
| `behaviors.lua` | 10 | Behavior system (stub) |
| `polylineOLD.lua` | 392 | **DEAD CODE** - Old polyline implementation |

---

## Architecture Overview

### Core Flow

```
main.lua
    │
    ├── love.load()
    │   ├── Initialize UI (ui-all.lua)
    │   ├── Create physics world
    │   ├── Load scene (scene-loader.lua → io.lua)
    │   └── Optional: Create characters (character-manager.lua)
    │
    ├── love.update(dt)
    │   ├── Physics step (state.physicsWorld:update)
    │   ├── Snap constraints (snap.lua)
    │   ├── Keep-angle constraints (keep-angle.lua)
    │   ├── Pointer/mouse joints (box2d-pointerjoints.lua)
    │   └── Script callbacks (script.lua)
    │
    └── love.draw()
        ├── Draw grid (editor-render.lua)
        ├── Draw backdrops
        ├── Draw physics world (box2d-draw.lua)
        ├── Draw textured bodies (box2d-draw-textured.lua)
        ├── Draw editor overlays (editor-render.lua)
        └── Draw UI panels (playtime-ui.lua)
```

### State Management (`state.lua`)

All application state lives in a single `state` table:

```lua
state.scene           -- Current scene data, script, checkpoints
state.selection       -- Selected objects (body, joint, fixture)
state.interaction     -- Drag state, polygon vertices being drawn
state.panelVisibility -- Which UI panels are open
state.editorPreferences -- Grid, snap, default values
state.polyEdit        -- Polygon vertex editing state
state.texFixtureEdit  -- Texture fixture editing state
state.vertexEditor    -- Vertex assignment for rigging
state.currentMode     -- Current editor mode (e.g., 'drawFreePoly', 'jointCreationMode')
state.world           -- Physics world settings (gravity, paused, debug draw, etc.)
state.physicsWorld    -- The actual Box2D world object
state.backdrops       -- Background images
```

### Registry System (`registry.lua`)

Central ID-based lookup for all physics objects:

```lua
registry.bodies[id]     -- Box2D body lookup
registry.joints[id]     -- Box2D joint lookup  
registry.sfixtures[id]  -- "Snap fixtures" (special fixtures for snapping)
```

### Global Variables

The following are set as globals in `main.lua` and used throughout:

| Global | Module | Purpose |
|--------|--------|---------|
| `snap` | src/snap.lua | Snap-to-grid system |
| `keep_angle` | src/keep-angle.lua | Angle constraint system |
| `registry` | src/registry.lua | Object ID registry |
| `benchmarks` | src/benchmarks.lua | Performance measurement |
| `logger` | src/logger.lua | Logging |
| `inspect` | vendor/inspect.lua | Table inspection |
| `prof` | vendor/jprof.lua | Profiling |
| `ProFi` | vendor/ProFi.lua | Profiling |

---

## Key Concepts

### Bodies and UserData

Every Box2D body has userData containing:

```lua
body:getUserData() = {
    id = "unique-id",
    thing = {
        type = "rectangle" | "circle" | "custom",
        vertices = {...},  -- For polygons
        radius = number,   -- For circles
        width = number,
        height = number,
        ...
    },
    extra = {
        subtype = "...",   -- Special body types
        subdata = {...},   -- Type-specific data
        ...
    }
}
```

### Joint Types Supported

- Revolute (rotation around a point)
- Distance (fixed distance between bodies)
- Rope (maximum distance constraint)
- Weld (rigid connection)
- Prismatic (sliding along axis)
- Wheel (vehicle suspension)
- Pulley
- Friction
- Motor

### Character System (`character-manager.lua`)

Characters are articulated ragdolls with:

- **DNA System**: Genetic parameters for character generation
- **Parts**: torso1-N, neck1-N, head, luarm/ruarm, llarm/rlarm, luleg/ruleg, llleg/rlleg, lhand/rhand, lfoot/rfoot, lear/rear, nose1-N
- **Texturing**: Multi-layer textures (skin, hair, patches)
- **Rigging**: Vertex assignments to bones for mesh deformation

### Snap Fixtures (`snap.lua`)

Special sensor fixtures that enable snapping behavior between bodies:

```lua
registry.sfixtures[id] = fixture  -- Sensor fixtures for snap points
snap.rebuildSnapFixtures()        -- Rebuild spatial index
```

### Scene Format (`.playtime.json`)

```json
{
  "camera": { "x": 0, "y": 0, "scale": 1 },
  "world": { "gravity": 9.8, "meter": 100, ... },
  "bodies": [
    {
      "id": "body-uuid",
      "type": "dynamic",
      "thing": { "type": "rectangle", "width": 100, "height": 50 },
      "fixtures": [...],
      "x": 100, "y": 200,
      "angle": 0
    }
  ],
  "joints": [
    {
      "id": "joint-uuid",
      "type": "revolute",
      "bodyA": "body-uuid-1",
      "bodyB": "body-uuid-2",
      ...
    }
  ],
  "sfixtures": [...],
  "characters": [...]
}
```

---

## Vendor Libraries

| Library | Purpose |
|---------|---------|
| `dkjson.lua` | JSON encoding/decoding |
| `inspect.lua` | Table pretty-printing |
| `loveblobs/` | Soft body physics |
| `peeker.lua` | Debug visualization |
| `jprof.lua` | Profiling |
| `ProFi.lua` | Profiling |
| `batteries/` | Utility library (manual_gc) |
| `MessagePack.lua` | Binary serialization |
| `brady.lua` | Unknown/unused |

---

## Known Issues and TODOs

### Bugs (from main.lua comments)

1. **Vertices not populated after load** - `.vertices` aren't set correctly after scene load
2. **destroyBody doesn't destroy joints** - Joints may be orphaned when body is destroyed
3. **sfixtures sensor=false** - Some snap fixtures incorrectly have sensor=false
4. **Humanoid reference after reload** - Character references break on scene reload

### Missing Features

1. Swap body parts on characters
2. UI to change body properties
3. Z-order configuration for characters (currently predefined)
4. Character facing directions (left/right/front)
5. Group ID handling (should be < 0, different per character)
6. Dirty list for texture regeneration

### Code Quality Issues

1. **`playtime-ui.lua` is 3,527 lines** - Should be split into separate panel modules
2. **`math-utils.lua` has 50+ functions** - Many likely unused, needs audit
3. **Global variables** - `snap`, `registry`, `keep_angle`, `benchmarks` should be explicit imports
4. **Profiling code in production** - `prof.push()`/`prof.pop()` calls throughout
5. **Dead code** - `polylineOLD.lua` (392 lines) is unused
6. **JIT disabled** - `jit.off()` in main.lua, unclear if still needed

### Performance Notes

From profiling:
- UI drawing is the bottleneck (~50% of frame time)
- `drawWorldSettingsUI` alone is ~42% of frame time
- Physics update is only ~1% of frame time
- Meshes are recreated every frame in `box2d-draw-textured.lua` (has TODO to cache)

---

## Editor Modes

The editor has multiple modes controlled by `state.currentMode`:

| Mode | Description |
|------|-------------|
| `nil` | Default selection/manipulation mode |
| `jointCreationMode` | Creating a new joint |
| `pickAutoRopifyMode` | Selecting bodies for auto-rope |
| `drawFreePoly` | Free-hand polygon drawing |
| `drawClickPoly` | Click-to-place polygon vertices |
| `positioningSFixture` | Placing a snap fixture |
| `setOffsetA` / `setOffsetB` | Setting joint anchor offsets |
| `addNodeToConnectedTexture` | Adding nodes to texture mesh |

---

## How to Run

```bash
# macOS/Linux
love .

# Or with specific LÖVE version (on this machine)
/Applications/love114.app/Contents/MacOS/love .
```

### Running Tests

```bash
# Run all tests (unit + integration) - requires LÖVE
/Applications/love114.app/Contents/MacOS/love . --test

# Run unit tests only (no LÖVE required)
lua tests/run.lua
```

### Default Scene

The default scene loaded is `scripts/test.playtime.json` (set in `main.lua:love.load()`).

### Drag & Drop

- Drop `.playtime.json` files to load scenes
- Drop `.playtime.lua` files to load/run scripts
- Drop images to add as backdrops

---

## Refactoring Priorities

### High Priority (KISS/YAGNI)

1. **Split `playtime-ui.lua`** into ~10 smaller modules:
   - `ui-world-settings.lua`
   - `ui-body-inspector.lua`
   - `ui-joint-editor.lua`
   - `ui-fixture-editor.lua`
   - `ui-character-editor.lua`
   - etc.

2. **Audit `math-utils.lua`** - Find and remove unused functions

3. **Remove dead code**:
   - Delete `polylineOLD.lua`
   - Remove commented-out code blocks
   - Remove unused profiling reports

4. **Convert globals to explicit imports** in all modules

### Medium Priority

5. **Cache meshes in `box2d-draw-textured.lua`** (has TODO)
6. **Fix vertices not populated after load** bug
7. **Make profiling optional** - Move `prof.push/pop` behind flag

### Low Priority

8. **Split `math-utils.lua`** into focused modules
9. **Decouple character-manager** from rendering
10. **Create configuration file** for magic numbers

---

## Dependency Graph (simplified)

```
main.lua
├── state.lua (central state)
├── registry.lua (object lookup)
├── playtime-ui.lua (UI - depends on almost everything)
│   ├── ui-all.lua
│   ├── object-manager.lua
│   ├── joints.lua
│   └── ... (many dependencies)
├── input-manager.lua (user input)
│   ├── box2d-pointerjoints.lua
│   ├── object-manager.lua
│   └── state.lua
├── scene-loader.lua
│   └── io.lua (serialization)
│       ├── shapes.lua
│       ├── fixtures.lua
│       ├── joints.lua
│       └── registry.lua
├── box2d-draw.lua (debug rendering)
├── box2d-draw-textured.lua (textured rendering)
└── character-manager.lua
    ├── fixtures.lua
    ├── joints.lua
    └── box2d-draw-textured.lua
```

---

## Quick Reference: Common Tasks

### Add a new UI panel

1. Currently: Add to `playtime-ui.lua` (not recommended)
2. Better: Create new file `src/ui-panel-name.lua`, require in `playtime-ui.lua`

### Add a new shape type

1. Add shape generation in `shapes.lua`
2. Add serialization in `io.lua`
3. Add UI in `playtime-ui.lua`

### Add a new joint type

1. Add creation logic in `joints.lua`
2. Add handlers in `joint-handlers.lua`
3. Add UI in `playtime-ui.lua`
4. Add serialization in `io.lua`

### Debug physics issues

1. Enable `state.world.debugDrawMode = true`
2. Enable `state.world.debugDrawJoints = true`
3. Check `box2d-draw.lua` for rendering

---

## Testing

### Strategy: Hybrid Approach

This project uses a hybrid testing approach because it's a graphical, interactive, physics-based application.

| Test Type | Location | Requires LÖVE | Good For |
|-----------|----------|---------------|----------|
| Unit | `tests/unit/` | No | Pure functions (math, utils, shapes) |
| Integration | `tests/integration/` | Yes | Physics, serialization, scene loading |

### Test Framework: mini-test.lua

A single-file test framework (~200 lines) with no external dependencies:

```lua
local T = require 'tests.mini-test'

T.describe("module", function()
    T.it("does something", function()
        T.expect(value).toBe(expected)
        T.expect(value).toBeCloseTo(3.14, 0.01)
        T.expect(table).toEqual({a = 1})
        T.expect(fn).toThrow()
    end)
end)

T.run()
```

### Writing New Tests

**Unit test** (`tests/unit/test_<module>.lua`):
```lua
local T = require 'tests.mini-test'
local myModule = require 'src.my-module'

T.describe("my-module", function()
    T.it("handles input correctly", function()
        T.expect(myModule.fn(input)).toBe(expected)
    end)
end)
```

**Integration test** (`tests/integration/test_<feature>.lua`):
```lua
local T = require 'tests.mini-test'

T.describe("feature", function()
    T.it("works with physics", function()
        local world = love.physics.newWorld(0, 100, true)
        -- test...
        world:destroy()  -- always clean up
    end)
end)
```

### Current Test Coverage

- `tests/unit/test_math_utils.lua` - 17 tests for math functions
- `tests/integration/test_physics_world.lua` - 5 tests for physics basics

See `tests/README.md` for full testing documentation.

---

## File Checksums for Change Detection

Key files to watch for changes:

```
main.lua           - 991 lines  - Entry point
src/state.lua      - 135 lines  - All state
src/playtime-ui.lua - 3527 lines - All UI (refactor target)
src/io.lua         - 990 lines  - Serialization
src/object-manager.lua - 986 lines - Object creation
```
