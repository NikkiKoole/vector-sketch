# Code bugs — found in the October 2026 review

status: active

Bugs a 7-agent read-only code review found on 2026-10-30 (rendering, characters, UI, save/load,
input/plumbing, sound/world, cross-cutting). Every one was read in the code; none was run yet,
so reproduce first. Line numbers are as of commit 65c48eb8. The cleanup and the file splits from
the same review: `CODE-CLEANUP-2026-10.md`, `CODE-SPLITS-2026-10.md`.

Each is small (under half an hour) unless it says otherwise.

## Things that break

- [x] **BUG1. Rebuilt joints lose their settings.** `src/joint-handlers.lua`: `create` only puts
  back revolute limits and wheel springs, not what `extract` reads (motors, reference angle,
  distance/weld frequency + damping, prismatic limits and motor, wheel axis, motor-joint offsets).
  So `joints.recreateJoint` (collide toggle `joint-params.lua:47`, dragging an anchor, flip) and
  resizing a body (`object-manager.lua:481` → `reattachJoints`) quietly switch motors off and reset
  springs. Fix: each handler gets `apply(joint, props)` that sets back everything `extract` returns.
  Load and save can then use the handlers too (CL13). Size: an hour or two.
  **Done 2026-10-30:** every handler has `apply`, `extract` also reads reference angle and axis,
  and `recreateJoint` puts the caller's settings over the extracted ones (the axis sliders).
  `spec/joints-keep-settings_spec.lua`.
- [x] **BUG2. Clone and flip should crash on welds, ropes, distance joints.** `io.lua:1510` (clone)
  and `object-manager.lua:932` (flipThing) call `areLimitsEnabled()`/`getLimits()` on every joint;
  only revolute and prismatic have them. Specs only use revolute joints. Fix: check
  `joint.areLimitsEnabled` first, or let `apply` from BUG1 carry the limits.
  **Done 2026-10-30:** clone lets `apply` carry the limits; flip passes mirrored limits,
  reference angle, axis and motor direction as recreate settings. Same spec.
- [x] **BUG3. Capsules lose their corner size on save.** `io.lua:907` `needsDimProperty` saves
  `width2` only for TRAPEZIUM and TORSO, but `shapes.lua:455` builds a capsule from `width2`.
  After a load, resizing falls back to `width2 or 1`. Fix: add CAPSULE to the `width2` line (and see
  CL10 for one list of dimension keys).
  **Done 2026-10-30:** `io_spec` (it said capsules don't need `width2`) and a round trip in
  `integration_spec`.
- [x] **BUG4. Connected-texture 'auto' button freezes the app** on a body without joints:
  `ui/sfixture-editor.lua:1381`, the `while not inArray(...)` loop only moves on when the body has
  joints. Fix: `if #attachedJoints == 0 then break end` (or it goes away with CL14).
  **Done 2026-10-30:** the button uses `joints.jointChain(body)`, which also no longer
  repeats the last joint. `spec/joints-recreate_spec.lua`.
- [x] **BUG5. Editor keys fire while you type in a text field.** `main.lua:598-599` calls
  `ui.handleKeyPress` and then `InputManager.handleKeyPressed` without checking focus. Typing a space
  in a label pauses the world, `c` takes a screenshot, `i`/`d` edit polygon vertices. Fix: return
  after `ui.handleKeyPress` when `ui.focusedTextInputID` is set.
  **Done 2026-10-30:** `InputManager.keyPressed(key)` does that; `spec/input-manager_spec.lua`.
- [x] **BUG6. The speed slider is applied twice.** `game-loop.lua:59-70` adds or skips steps for
  `speedMultiplier`, and `main.lua:290` also multiplies each step's dt by it: 2x runs about 4x,
  0.5x about 0.25x. Fix: keep the step count, make `scaled_dt = dt`.
  **Done 2026-10-30, the other way round:** skipping whole updates also skipped input in slow
  motion, so the loop no longer looks at speed. `gameLoop.physicsSteps(dt, speed)` makes the step
  smaller for slow motion and takes more steps when fast (no Box2D step longer than dt).
  `spec/game-loop_spec.lua`.
- [ ] **BUG7. Music and snap clicks hang off the Mipo voice.** `mipo-voice.lua:343-351`:
  `mipoVoice.update` starts and ticks the synth and runs music, snap-sound and slide-sound, but only
  when `synthImpacts` is on, and main only calls it when the world isn't paused. Turning off impact
  sounds silences the music. Fix: a small `src/sound.lua` with `sound.update(dt)` called from main;
  mipo-voice keeps its flaps and cooldowns.
- [ ] **BUG8. `debugIds` can be nil.** `physics/box2d-draw.lua:396` indexes `debugIds`, which is only
  made in the body loop (:293). Show debug ids with no body ids drawn → error. Fix: create it at :188.
- [ ] **BUG9. The add-behavior panel replaces the thing.** `playtime-ui.lua:430` deep-copies the
  body's userData every frame and `setUserData`s the copy on click, so
  `state.selection.selectedObj` points at the old thing. Fix: insert into
  `body:getUserData().thing.behaviors` directly.
- [ ] **BUG10. `handleOffset` doesn't register the new fixture.** `ui/sfixture-editor.lua:1317-1336`
  (N/E/S/W/C buttons on connected texture and trace vertices) destroys and recreates the fixture
  but never calls `registry.registerSFixture`. `placeOnEdge` in `sfixture-params.lua:43` does it
  right; use it (or it goes away with CL14).

## Looks wrong

- [ ] **BUG11. Hair mottle depends on draw order.** Only the connected-texture branch
  (`box2d-draw-textured.lua:3116`) sends `mottleStrength`/`mottleScale` to the hairs shader; the
  texfixture (:2549) and trace-vertices (:3299) branches don't, so they reuse the last value sent.
  Fix: one `beginSurfaceShader(extra, body)` for all three (CL16).
- [ ] **BUG12. Debug wireframe is on by default.** `box2d-draw-textured.lua:325`
  `lib.drawMeshOutline = true` draws green triangle edges over every MESHUSERT, in play mode too.
  Fix: default false.
- [ ] **BUG13. Offset circles ignore body rotation.** `physics/box2d-draw.lua:287` draws at
  `body_x + shape_x`; use `body:getWorldPoint(shape:getPoint())`. Also `:307`
  `setColor(255,255,255, alpha)` should be `1,1,1`. (Not checked by hand.)

## Slow

- [ ] **BUG14. Mipo skin patch sliders rebuild the textures every frame.** `ui/mipo-editor.lua:1249`:
  `ui.sliderWithInput` returns nil when nothing changed and `nil ~= value` is true, so
  `updateSkinOfPart` + `addTexturesFromInstance2` run every frame while the panel is open. Also
  `sliderWithInput` (`ui/all.lua:247-284`) returns a string when dragged and a number when typed,
  which is why there are `tonumber` calls everywhere. Fix: return `tonumber(...)`, and `if val and`.
- [ ] **BUG15. Every save regenerates every OMP texture.** `io.lua:1041-1077` sets
  `extra.dirty = true` and drops `ompImage`/`_mesh` on the live userdata (library saves too, they
  gather the whole world). Fix: deepCopy first, clean only the copy.
- [ ] **BUG16. The RESOURCE panel triangulates every frame.** `ui/sfixture-editor.lua:1254` calls
  `cdt.computeResourceMesh` on each draw while a backdrop is linked. Fix: only when the index
  changes. While there: `if #state.backdrops then` (:1218) is always true, the 'bind-pose' button
  (:1274) does nothing, the 'global mesh ftw!' label (:1287) can go.
- [ ] **BUG17. Blob rims scan every fixture every step.** `blob.lua:400-435` `beforeStep` walks all
  fixtures of all bodies (paused too) and calls `setMask` each step. Fix: loop over
  `registry.sfixtures` like `liquid.lua:461`.
- [ ] **BUG18. `blinkStates` leaks.** `box2d-draw-textured.lua:32` is keyed by `thing` but not
  weak-keyed, so every rebuilt thing stays. Fix: `setmetatable({}, { __mode = 'k' })`.
