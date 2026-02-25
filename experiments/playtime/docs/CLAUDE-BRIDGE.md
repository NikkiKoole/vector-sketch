# Claude Bridge

HTTP JSON API for AI-game interaction. Runs on **port 8001** inside the LÖVE game.

## Setup

Already integrated — just run `love .` and click to get past the start screen.

Two lines in `main.lua`:
```lua
local bridge = require 'vendor.claude-bridge'
-- in love.update(dt):
bridge.update()
```

## Response format

Every response:
```json
{
  "ok": true,
  "data": { ... },
  "meta": { "fps": 60, "frame": 1234, "paused": true, "bodyCount": 12, "jointCount": 8 }
}
```

## Endpoints

### Read

| Command | What |
|---------|------|
| `curl localhost:8001/ping` | Health check |
| `curl localhost:8001/state` | Overview (paused, gravity, selection, currentMode) |
| `curl localhost:8001/bodies` | List all bodies (id, label, type, position) |
| `curl localhost:8001/body?id=X` | Full body detail (fixtures, joints, thing data) |
| `curl localhost:8001/joints` | List all joints |
| `curl localhost:8001/joint?id=X` | Joint detail with type-specific properties |
| `curl localhost:8001/selection` | Whatever is currently selected |
| `curl localhost:8001/scene` | Full scene via gatherSaveData() |
| `curl localhost:8001/world` | World settings (gravity, meter, speed, etc.) |
| `curl localhost:8001/registry` | All registered IDs with summary |
| `curl localhost:8001/sfixtures` | Special fixtures list |

### Execute Lua

```bash
# Eval — run Lua, get result back as JSON
curl -X POST localhost:8001/eval -d '{"code":"return 1+1"}'
# -> {"ok":true,"data":2,"meta":{...}}

# Exec — run Lua, fire-and-forget
curl -X POST localhost:8001/exec -d '{"code":"print(\"hello\")"}'
```

The eval/exec preamble auto-requires: `state`, `registry`, `objectManager`, `joints`, `eio`, `inspect`, `utils`.

### Write / Control

| Command | What |
|---------|------|
| `curl -X POST localhost:8001/world/pause` | Pause physics |
| `curl -X POST localhost:8001/world/unpause` | Unpause physics |
| `curl -X POST localhost:8001/world/step -d '{"frames":10}'` | Step N physics frames |
| `curl -X POST localhost:8001/body/create -d '{"shape":"rectangle","opts":{"x":100,"y":100,"width":40,"height":40}}'` | Create body |
| `curl -X POST localhost:8001/body/destroy -d '{"id":"abc123"}'` | Destroy body |
| `curl -X POST localhost:8001/scene/save -d '{"filename":"path.json"}'` | Save scene |
| `curl -X POST localhost:8001/scene/load -d '{"filename":"path.json"}'` | Load scene |
| `curl -X POST localhost:8001/reload` | Hot-reload current script |

### Snapshot / Diff

```bash
# Take a snapshot
curl -X POST localhost:8001/snapshot -d '{"name":"before"}'

# Make some changes...

# Take another snapshot
curl -X POST localhost:8001/snapshot -d '{"name":"after"}'

# Compare
curl 'localhost:8001/diff?from=before&to=after'
```

## Screenshots

```bash
curl -X POST localhost:8001/eval -d '{"code":"love.graphics.captureScreenshot(\"name.png\"); return \"ok\"}'
```
Saved to: `/Users/nikkikoole/Library/Application Support/LOVE/playtime/`

## Useful eval examples

```bash
# Get all body positions
curl -X POST localhost:8001/eval -d '{"code":"local r = {}; for id,b in pairs(registry.bodies) do r[id] = {x=b:getX(), y=b:getY()} end; return r"}'

# Change body type (colors: static=yellow, dynamic=green, kinematic=red)
curl -X POST localhost:8001/eval -d '{"code":"registry.bodies[\"ID\"]:setType(\"kinematic\")"}'

# Spawn 100 random rectangles
curl -X POST localhost:8001/eval -d '{"code":"local om = require \"src.object-manager\"; for i=1,100 do om.addThing(\"rectangle\", {x=math.random(0,1200), y=math.random(-500,300), width=20, height=20}) end; return \"done\""}'

# Clear everything
curl -X POST localhost:8001/eval -d '{"code":"for id,body in pairs(registry.bodies) do if not body:isDestroyed() then body:destroy() end end; registry.reset(); return \"cleared\""}'
```

## Technical details

- Single file: `vendor/claude-bridge.lua` (~580 lines)
- Non-blocking coroutine-based HTTP server (same pattern as lovebird)
- Localhost only (127.0.0.1 whitelist)
- Eval has timeout protection via debug.sethook (~1M instructions)
- Safe serialization handles Box2D userdata, cycles, NaN/inf
- JSON via vendor/dkjson.lua
