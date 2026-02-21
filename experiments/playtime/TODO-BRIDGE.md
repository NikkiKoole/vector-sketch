# Claude Bridge - TODO & Wishlist

## Bugs found

- **`addThing` ignores `bodyType`**: In `src/object-manager.lua:395`, `bodyType = bodyType or 'dynamic'` sets a local variable but never reads `conf.bodyType`. Workaround: call `thing.body:setType("static")` after creation.
- **`/body/create` ignores `angle`**: Angle isn't applied via the create endpoint. Workaround: use `/body/update` with `angle` after creation.

## Implemented

### Camera control -- DONE
- `GET /camera` — camera position, scale, visible bounds
- `POST /camera` — set position/scale, or `fitToScene: true` to auto-frame all bodies

### Screenshot -- DONE
- `POST /screenshot` — captures screenshot, returns file path

### Scene reset -- DONE
- `POST /scene/clear` — destroys all bodies, resets registry

### World inspection -- DONE
- `GET /bounds` — AABB encompassing all bodies
- Body count with type breakdown available via `GET /bodies` or meta

### Playback control -- DONE
- `POST /world/run` — unpause, step N frames, re-pause
- `POST /world/step` — step N frames while paused

### Quality of life -- DONE
- `GET /help` — lists all available routes with descriptions
- `/eval` returns compile errors with line numbers

### Console & errors -- DONE
- `GET /console` — recent print() output
- `GET /errors` — captured errors (lurker, pcall, etc.)
- `POST /console/clear`, `POST /errors/clear`

### Collision logging -- DONE
- `GET /collisions`, `POST /collisions/start`, `POST /collisions/stop`, `POST /collisions/clear`

### Input simulation -- DONE
- `POST /input`, `POST /input/click`, `POST /input/drag`, `POST /input/key`

### Watch expressions & breakpoints -- DONE
- `POST /watch`, `GET /watch`, `DELETE /watch`
- `POST /breakpoint`, `GET /breakpoint`, `POST /breakpoint/reset`, `DELETE /breakpoint`

### Body editing -- DONE
- `POST /body/update` — position, velocity, angle, type, friction, impulse, force, etc.

### Snapshot/diff -- DONE
- `POST /snapshot`, `GET /diff`

### Profiling -- DONE
- `POST /profile/benchmark` — benchmark a Lua code snippet (iterations, warmup, returns mean/median/min/max/p95)
- `POST /profile/frames` — profile N frames of physics with ProFi, returns full text report

## Still missing / wishlist

### Body creation improvements
- Fix the `bodyType` bug so `/body/create` works for static bodies without workarounds
- Fix `angle` support in `/body/create`
- Batch create endpoint — creating many bodies one-by-one via curl is slow

### Screenshot improvements
- Option to wait for next frame render before capturing (captureScreenshot is async)
- Return base64 image data directly (avoid reading from disk)

### World inspection
- `/body/count` with type breakdown (static vs dynamic vs kinematic)

## Things that worked great

- `/eval` and `/exec` are incredibly powerful — being able to run arbitrary Lua is the ultimate escape hatch
- The auto-preamble (state, registry, objectManager etc.) saves a lot of boilerplate
- Response format with meta (fps, frame, bodyCount) is very useful for quick health checks
- Safe serialization handling Box2D userdata without crashing
- Snapshot/diff system is a clever idea for testing
- Watch expressions + breakpoints are great for debugging physics behavior
- Input simulation (click, drag, key) enables automated testing workflows
- Collision logging helps debug physics interactions
