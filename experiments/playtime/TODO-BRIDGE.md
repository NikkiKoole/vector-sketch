# Claude Bridge - TODO & Wishlist

## Bugs found

- **`addThing` ignores `bodyType`**: In `src/object-manager.lua:395`, `bodyType = bodyType or 'dynamic'` sets a local variable but never reads `conf.bodyType`. Workaround: call `thing.body:setType("static")` after creation.

## Missing hooks / endpoints I wished I had

### Camera control
- **`/camera`** (GET) — get current camera position, scale, and visible world bounds
- **`/camera`** (POST) — set camera position/scale, or "fit to scene" to auto-frame all bodies
- Right now I had to use `/eval` with `require("src.camera")` to figure out the viewport, which was clunky

### Screenshot improvements
- **`/screenshot`** (POST) — dedicated endpoint that captures + returns the file path (or even base64 image data), instead of the two-step eval + wait + read-from-disk dance
- Option to wait for next frame render before capturing (the current `captureScreenshot` is async and you have to sleep/guess)

### Scene reset
- **`/scene/clear`** — one-call full reset (destroy all bodies, reset registry). Currently requires an eval with a loop + `registry.reset()`

### Body creation improvements
- Fix the `bodyType` bug so `/body/create` works for static bodies without workarounds
- **`/body/create` with `angle`** — currently angle isn't applied via the create endpoint either, had to use eval to call `setAngle()`
- Batch create endpoint — creating 30 bodies one-by-one via curl is slow; a single call to create multiple bodies would help

### World inspection
- **`/bounds`** — get the AABB of all bodies (useful for auto-framing camera)
- **`/body/count`** with type breakdown (how many static vs dynamic vs kinematic)

### Playback control
- **`/world/run`** with `duration` param — unpause, run for N seconds, pause, return final state. Currently I have to unpause, sleep in bash, then pause — timing is imprecise
- **`/world/step`** already exists but stepping individual frames is very slow for "run for 3 seconds" scenarios

### Quality of life
- **`/eval` returning errors inline** — when eval code has a syntax error, it's hard to debug (would be nice to get line numbers in the error response)
- **`/help`** endpoint — returns the list of all available endpoints (self-documenting API)

## Things that worked great

- `/eval` and `/exec` are incredibly powerful — being able to run arbitrary Lua is the ultimate escape hatch
- The auto-preamble (state, registry, objectManager etc.) saves a lot of boilerplate
- Response format with meta (fps, frame, bodyCount) is very useful for quick health checks
- Safe serialization handling Box2D userdata without crashing
- Snapshot/diff system is a clever idea for testing
