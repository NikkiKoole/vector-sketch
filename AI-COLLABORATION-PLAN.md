# Vector-Sketch: Plan for AI-Assisted Development

This document outlines concrete changes to make the codebase more maintainable and
easier for Claude (or any AI tool) to work with effectively.

---

## 1. The Big Problem: `tool.lua` is 3,320 lines

This single file is the heart of the application. It contains UI rendering, input
handling, node editing, file I/O, selection logic, transformation operations, and
drawing — all interwoven with global state. This makes it hard for anyone (human or
AI) to:

- Understand what a change will affect
- Make targeted edits without breaking something else
- Find the right place to add new features

### Recommended split

Break `tool.lua` into focused modules:

| New file | Responsibility | Approx lines to extract |
|---|---|---|
| `src/input.lua` | Keyboard/mouse handlers from `keypressed`, `mousepressed`, `mousereleased`, `mousemoved` | ~600 |
| `src/selection.lua` | `setCurrentNode`, rectangle selection, multi-select, `childrenInRectangleSelect` | ~200 |
| `src/transforms.lua` | `rotateGroup`, `resizeGroup`, `flipGroup`, `recenterGroup`, point manipulation | ~200 |
| `src/node-tree-ui.lua` | The scrollable node tree panel (expand/collapse, drag reorder) | ~400 |
| `src/properties-panel.lua` | The right-side properties panel (name, color, texture, sliders) | ~300 |
| `src/file-io.lua` | Save, load, export, hot-reload logic | ~200 |
| `src/drawing.lua` | The main canvas draw routine, help overlay, console overlay | ~400 |
| `tool.lua` | Remains as the coordinator — wires modules together, holds shared state | ~800 |

**How to do it safely**: Extract one module at a time. After each extraction, run the
app and verify things still work. Don't try to do all of them at once.

---

## 2. Tame Global State

Currently, `tool.lua` uses many implicit globals:

```lua
currentNode          -- which node is selected
editingMode          -- current interaction mode
editingModeSub       -- sub-mode
childrenInRectangleSelect
dopesheetEditing
scrollviewOffset
changeName
```

These make it impossible to reason about what a function depends on or modifies.

### Recommendation

Create an explicit `state` table that all modules share:

```lua
-- src/state.lua
local state = {
    currentNode = nil,
    editingMode = nil,
    editingModeSub = nil,
    selectedChildren = {},
    dopesheetEditing = false,
    scrollviewOffset = 0,
    changeName = false,
}
return state
```

Then pass `state` to modules or require it. This way:
- Every dependency is visible
- AI can trace data flow by searching for `state.currentNode`
- Functions become testable (inject a mock state)

---

## 3. Add a Test Framework

There are zero tests for the main application. This is the single biggest improvement
for working with AI, because:

- AI can verify its changes didn't break anything
- AI can write tests before making changes (TDD)
- Regressions get caught immediately

### Recommended approach

Use **busted** (the standard Lua test framework):

```bash
luarocks install busted
```

Create a `tests/` directory with this structure:

```
tests/
  test_node.lua        -- node creation, manipulation, tree ops
  test_math_utils.lua  -- pure math functions (easy to test)
  test_numbers.lua     -- lerp, round, clamp
  test_geometry.lua    -- geometric calculations
  test_bbox.lua        -- bounding box calculations
  test_hit.lua         -- hit detection
  test_transform.lua   -- transform composition
  test_formats.lua     -- file format serialization/deserialization
  test_mesh.lua        -- mesh generation (may need love mocks)
```

### Start with pure functions (easiest wins)

These files have zero LÖVE dependencies and can be tested immediately:

| File | Testable functions |
|---|---|
| `lib/numbers.lua` | `lerp`, `round2`, `round`, `clamp` |
| `lib/math-utils.lua` | Distance, angle, curve calculations |
| `lib/node.lua` | `getIndex`, `setPos`, `setPivot` |
| `lib/basics.lua` | `deepcopy`, `tableConcat` |
| `lib/text.lua` | Text manipulation utilities |
| `lib/geometry.lua` | Point-in-polygon, line intersection |
| `lib/bbox.lua` | Bounding box merge, point containment |

### Mock LÖVE for testing

For modules that use `love.graphics` or `love.math`, create a minimal mock:

```lua
-- tests/mock_love.lua
love = {
    graphics = {
        newMesh = function() return {} end,
        newImage = function() return { getWidth = function() return 100 end, getHeight = function() return 100 end } end,
    },
    math = {
        newTransform = function() return { setTransformation = function() end, transformPoint = function(_, x, y) return x, y end } end,
    },
    filesystem = {
        read = function() return "" end,
    }
}
```

### Example test

```lua
-- tests/test_numbers.lua
local numbers = require 'lib.numbers'

describe("numbers", function()
    it("lerp interpolates correctly", function()
        assert.are.equal(5, numbers.lerp(0, 10, 0.5))
        assert.are.equal(0, numbers.lerp(0, 10, 0))
        assert.are.equal(10, numbers.lerp(0, 10, 1))
    end)

    it("round2 rounds to 2 decimals", function()
        assert.are.equal(3.14, numbers.round2(3.14159))
    end)
end)
```

---

## 4. Add Function-Level Documentation to Key Modules

AI works best when functions have a brief comment explaining:
- What it does
- What it expects as input
- What it returns

You don't need to document everything — focus on the non-obvious functions. For
example, in `lib/mesh.lua`:

```lua
--- Rebuilds the LÖVE mesh for a node from its points and texture.
--- Sets node.mesh and clears node.dirty.
--- @param node table  A leaf node with .points and optionally .texture
--- @param parent table  The parent node (for transform inheritance)
function mesh.remeshNode(node, parent)
```

### Priority files for documentation

1. `lib/mesh.lua` — Complex mesh generation logic
2. `lib/render.lua` — Rendering pipeline
3. `lib/math-utils.lua` — Many utility functions, unclear names
4. `lib/updatePart.lua` — Dynamic part updating
5. `lib/box2dGuyCreation.lua` — Complex physics setup
6. `lib/connectors.lua` — Spline/connector math

The `@param` and `@return` annotations also help the Lua language server give you
better autocomplete, so this benefits you directly too.

---

## 5. Add a CLAUDE.md File (done)

I've created a `CLAUDE.md` in the project root. This file is automatically read by
Claude Code at the start of every session. It contains:

- Project overview and how to run it
- Architecture summary
- Key data structures
- Directory layout

Keep this file updated as we make changes. It's the most direct way to give AI
context about the project.

---

## 6. Error Handling at Boundaries

Currently there's almost no validation or error handling. When AI makes a change that
introduces a bug, the app often just silently breaks or crashes with an unhelpful Lua
stack trace.

### Recommendation: Add assertions to key entry points

```lua
function mesh.remeshNode(node, parent)
    assert(node, "remeshNode: node is nil")
    assert(node.points or node.folder, "remeshNode: node has no points and is not a folder")
    -- ...
end
```

This helps both humans and AI debug issues faster. Focus assertions on:

- `tool.lua` public methods (`setRoot`, `load`, etc.)
- `lib/mesh.lua` functions (wrong input = crash or silent corruption)
- `lib/node.lua` tree operations (out-of-bounds, nil parents)

---

## 7. Extract Magic Numbers into Constants

The codebase has many unexplained literal values:

```lua
local magic = 4.46           -- main.lua, line 10
local part = 0.8             -- main.lua, line 7
-- various unnamed thresholds in tool.lua
```

Create a `lib/constants.lua`:

```lua
return {
    CANVAS_WIDTH_RATIO = 0.8,    -- portion of window used for canvas
    RUBBERHOSE_MAGIC = 4.46,     -- scaling factor for rubberhose length
    DEFAULT_BORDER_STEPS = 10,
    MIN_DRAG_DISTANCE = 3,       -- pixels before drag starts
    SCROLL_SPEED = 20,
    -- etc.
}
```

This makes the code self-documenting and easier to tune.

---

## 8. Suggested Priority Order

Here's what I'd recommend we tackle, in order of impact:

| Priority | Task | Why |
|---|---|---|
| **1** | Add tests for pure `lib/` functions | Immediate safety net, no refactoring needed |
| **2** | Extract global state into `src/state.lua` | Enables everything else |
| **3** | Split `tool.lua` input handling into `src/input.lua` | Biggest single file improvement |
| **4** | Split `tool.lua` UI panels into separate files | Reduces tool.lua to coordinator role |
| **5** | Add assertions to `mesh.lua` and `node.lua` | Catches bugs faster |
| **6** | Add `@param`/`@return` docs to `lib/mesh.lua` and `lib/render.lua` | Helps AI understand the hardest code |
| **7** | Extract magic numbers | Improves readability |

---

## 9. What This Enables

After these changes, working with AI becomes dramatically better:

- **"Add a new shape type"** — AI knows exactly where shape types are handled (mesh.lua,
  render.lua, tool.lua's input section) and can write tests for the new type
- **"Fix the selection bug"** — AI can look at `src/selection.lua` (200 lines) instead
  of searching through 3,320 lines of tool.lua
- **"Change how transforms work"** — AI can modify `src/transforms.lua` and run tests
  to verify nothing broke
- **"Add a new panel"** — AI sees the pattern from existing panel modules and follows it

The goal isn't perfection — it's making the codebase navigable and verifiable.
