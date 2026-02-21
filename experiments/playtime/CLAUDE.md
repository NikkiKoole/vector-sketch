# Playtime — LÖVE2D Physics Editor

## Running the app

```bash
./playtime.sh start    # start (checks if already running, handles port conflicts)
./playtime.sh stop     # graceful quit via bridge, force kill as fallback
./playtime.sh restart  # stop + start
./playtime.sh status   # check if running
```

Love executable: `/Applications/love114.app/Contents/MacOS/love`
LÖVE version: 11.4, window 1200x768.

## Claude Bridge (port 8001)

HTTP JSON API for interacting with the running game. All endpoints return `{ok, data, meta}`.

### Key endpoints
- `GET /ping` — health check
- `GET /bodies` — list all bodies
- `GET /body?id=X` — body detail
- `GET /joints` — list joints
- `GET /selection` — currently selected body/joint
- `GET /errors` — captured errors (lurker, etc.)
- `GET /console?n=10` — last N print() lines
- `GET /help` — list all endpoints
- `POST /eval` — run Lua code, get result (preamble: state, registry, objectManager, joints, eio, inspect, utils)
- `POST /exec` — run Lua code, fire-and-forget
- `POST /screenshot` — capture screenshot
- `POST /profile/benchmark` — benchmark code snippet (iterations, returns mean/median/min/max/p95)
- `POST /profile/frames` — profile N physics frames with ProFi

### Important
- Always quote URLs with `?` in zsh: `curl 'localhost:8001/console?n=5'`
- Must clear Box2D callbacks before destroying bodies to avoid SEGFAULT
- App must be past the start screen click before bridge responds

## Hot Reload

Lurker watches files every 0.5s and hot-swaps Lua modules. Check `/errors` after changes.

## Testing

```bash
busted spec/             # run busted tests (98 tests)
lua tests/run.lua        # run mini-test suite (17 tests)
```

## Luacheck

```bash
luacheck src/ main.lua --std "lua51+love" --only 111 112   # check global leaks
```

19 intentional globals remain (main.lua: logger, inspect, registry, etc. + script.lua sandbox).

## Architecture

- `main.lua` — entry point, game loop, keybindings
- `src/` — core modules (playtime-ui, object-manager, io, joints, box2d-draw-textured, etc.)
- `vendor/` — third-party libs (claude-bridge, lurker, dkjson, ProFi, jprof, loveblobs, etc.)
- `scripts/` — scene scripts (.playtime.lua) + scene data (.playtime.json)
- `textures/` — character textures (~290 files, OMP system: outline + mask + pattern)

### Key modules
- `src/object-manager.lua` — body creation/destruction/recreation
- `src/io.lua` — save/load, clone
- `src/playtime-ui.lua` — all editor UI panels (~3500 lines)
- `src/box2d-draw-textured.lua` — textured rendering, OMP compositing
- `src/joints.lua` — joint creation/recreation
- `src/registry.lua` — central registry for bodies, joints, sfixtures
- `src/character-manager.lua` — character DNA system, body part assembly
- `src/snap.lua` — proximity-based snap joints
- `src/state.lua` — shared app state

### No classes/OOP — modules return tables of functions.

## Lua Gotchas

- Closures capture upvalues by reference — `local x, y` must be declared before any closure that uses them
- When making functions `local`, check for forward references (function used before its definition)
- `registry.getBodyByID()` — capital ID, not Id
