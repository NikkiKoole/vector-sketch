# Script API — what a scene script, its helpers and the bridge are missing

status: active

**Started:** 2026-11-12, from building the reach spike (`REACH.md`): what got in the way, roughly by how
much it would have saved. Not checked against how other spikes get around each one. Nikki: "write them up".

## Scene scripts

- [ ] **SA1. A spike's helper module with the scene script's globals, hot-reloaded.** A helper loaded with
  `love.filesystem.load('scripts/spikes/reach-arm.lua')()` runs in `_G`: no `state`, no `cam` (the scene
  script has both), and lurker doesn't watch it, so changing it means reloading the whole scene. Something
  like `script.load('reach-arm')`: the same environment, reloaded when the file changes.
- [ ] **SA2. The script environment has the safe Lua builtins.** `next` is missing (reach crashed on it);
  probably `select`, `setmetatable`, `assert` and `error` too. Start from all the safe builtins instead of
  a list picked by hand (`src/script.lua` baseEnv).
- [ ] **SA3. `onUnload` knows whether it's a reload or the scene closing.** A reload runs onUnload then
  onStart, so a spike that cleans up its Mipo on unload makes a second one on every reload (reach did, twice).
  `onUnload('reload' | 'leave')`, so keeping things across a reload isn't each spike's own `state.xxx` trick.

## Taking over a Mipo's parts

- [ ] **SA4. Hand a limb over to a script, safely.** `body:setActive(false)` looks like the way, but kills
  the game: 17 modules ask every Mipo part for its fixtures' bounding box, and an inactive body has none
  (`Box2D assertion failed: 0 <= childIndex && childIndex < m_proxyCount`, camera-follow, 2026-11-12). Reach
  made "ghosts" instead (sensors, no gravity, 1/2000 of the torso's mass, posed every step;
  `scripts/spikes/reach-arm.lua` `lib.ghost`). An engine `puppet(instance, 'larm')` / `release` would also serve
  carrying, IK and staged animations. At least: CLAUDE.md says never setActive(false) a Mipo part.
- [ ] **SA5. A limb's shape in one call.** Shoulder, elbow and wrist points, segment lengths, which body owns
  which joint anchor (the parent is body A): it took reading the topology, the DNA and a live eval.
  `limb(instance, 'larm')` -> bodies, joints, anchors, lengths. Look at `characterManager.jointPoint` first.

## Drawing

- [ ] **SA6. More than one drawable hook, and a way to draw between one Mipo's parts.** `state.drawableWrap`
  is one global slot (cutpaper, felt, fur and reach each overwrite it); drawing "just before this Mipo's torso"
  took a per-frame flag. Look at `src/mipo-layers.lua` first: it may already be the way.
- [x] **SA7. Keep a body out of the debug drawing.** `state.hiddenBodies` (weak keys) in
  `src/physics/box2d-draw.lua` `showsBody`: bodies whose picture something else draws; shown only with
  'mipo body' on (2026-11-12, for reach's physics arm).

## Bridge

- [ ] **SA8. Load a scene from the bridge.** Now `/eval` with `sceneLoader.loadScriptAndScene(name)` and
  `playMode.enter()`. `POST /scene {"name": "reach", "play": true}`.
- [ ] **SA9. `/errors` that forgets fixed errors.** A fixed error stays in the list, and lurker's error screen
  stays up until the file changes again. `/errors?since=<frame>`, or clear them on a good reload.
- [ ] **SA10. `/eval` with the same names as a scene script.** `cam` is missing, among others.

## Panels

- [ ] **SA11. A spike's panel from declared rows.** Each spike lays out its rows of sliders, checkboxes and
  buttons by hand (beaks, nofeet, reach). Declare them the way engine modules declare `lib.tuning`
  (`src/tuning.lua`) and have one panel draw them.
