# Vector-Sketch - Claude AI Working Guide

## Project Overview

LÖVE2D (Lua) vector graphics drawing tool for creating flat-shaded figures with hand-drawn outlines. Runs with `love .` in the project root. LÖVE version 11.2, window 1200x768.

## Architecture

- **Entry point**: `main.lua` -> delegates everything to `tool.lua` (called `mylib`)
- **Pattern**: Hierarchical scene graph (tree of nodes with transforms)
- **Rendering**: Immediate mode via LÖVE callbacks
- **State**: Mostly global variables in `tool.lua` (`currentNode`, `editingMode`, etc.)
- **No classes/OOP**: Modules return tables of functions

### Key directories
- `lib/` — Core libraries (48 files): mesh, render, UI, math, physics, etc.
- `src/` — App screens: dopesheet, file-screen, palettes
- `vendor/` — Third-party libs (inspect, json, lume, concord ECS, etc.)
- `experiments/` — 73+ prototype subdirectories (not part of main app)

### Node structure (the core data model)
```lua
{
  name = "shape",
  folder = true/false,
  transforms = { l = {x, y, rot, sx, sy, px, py, skx, sky}, _g = globalTransform },
  children = {...},        -- if folder
  points = {{x,y}, ...},  -- if leaf
  color = {r, g, b, a},
  texture = { url, wrap, filter },
  mesh = love2dMesh,       -- cached, regenerated when dirty=true
  dirty = false
}
```

## Running & Development

```bash
love .                           # Run the app
# Press 'u' in-app for hot reload (lurker)
# Press 'p' for profiler toggle
# Press F5 for console
# Press 's' to save
# Press tab for dopesheet
```

## How to run tests

There are currently no automated tests for the main application.
