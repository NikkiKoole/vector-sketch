# Doll play — the Puppetmaker follow-up

status: active, focus

**Started:** 2026-10-27.

**Goal:** the same Mipo as Puppetmaker (or a bit better), but in a world where you
play with them like dolls. Think Sago Mini / Fiete World: several characters
who notice your finger and look at what you're doing. You can pick them up,
drag, throw and drop them, throw things around, put things in containers, and
drag a character to pan the world.

**How to use this doc:** the Foundation goes first, because everything else
plugs into it. After that, pick from the menu (`DOLL-PLAY-MENU.md`): move the item
you pick into "Picked from the menu" below, build it, see it running in the play
scene, tick it. One at a time. The Mipo's voice items (V1–V6) live in
`PUPPETMAKER-SOUND.md`.

---

## Foundation (do first, about a week)

- [x] **F1. Play scene** `scripts/dollhouse.playtime.json` + `.lua` (2026-10-27): ribbon
  floor/walls and 2 Mipos, built in the editor. The default for `./playtime.sh start`.
  No props yet. The Mipos start high and drop to the floor.
- [x] **F2. Play mode** (2026-10-29, `src/play-mode.lua`): **tab** goes in and out (escape also leaves),
  `love . --play <scene>` / `./playtime.sh play <scene>` starts in it. No editor panels, overlays, grid,
  selection rectangle or HUD; physics runs; the pointer takes its own path (`handlePlayPointer` in
  `input-manager.lua`): left grabs (onPressed/onReleased, signals, doors, squeaks) whatever tool mode is
  active, right/middle pans, the wheel only zooms. Editor keys rest, the scene script still gets
  `onKeyPress`. Leaving puts back the editor's pause; selection and tool mode are kept. A 'tab: editor'
  hint fades out after going in. Spec: `spec/input-manager_spec.lua` "play mode". The `x > w - 300`
  gates are only on the editor path now; removing them there is still open.
- **F3. Tween/timer layer — postponed until something really needs it** (2026-10-31). Built once
  (hump.timer as `timer` in scene scripts) and reverted: nothing used it, and the always-on things
  (blinks, brows, mouths, cooldowns) are fine and cheaper as timestamps. A layer like this costs a
  little everywhere it creeps in, so add it only for a real sequence (a splash/intro like Puppetmaker 2's,
  a chained reaction): bring back commit 1534dc50 (`git revert` of its revert), and use it there only.
- [ ] **F4. Load *your* Mipo**: spawn characters from saved DNA/JSON
  (`characterManager.createCharacterFromJustDNA`). Puppetmaker-style continuity:
  the Mipo you made shows up in the world.
- [x] **F5. Per-Mipo gaze target** (2026-10-27): `mipoActions.lookAt(mipo, target)` / `stopLooking`.
  Without one: what it points at, else the cursor/finger within 1000, else it looks around
  every 1.5-4s. Pupils read `thing.gazeX/Y` on the face part; the head tilts up to 20 deg
  toward the gaze. Original note: (the "aware" part): right now the pupils follow the
  **mouse**, and that's hardwired in the renderer
  (`box2d-draw-textured.lua` ~3096, `love.mouse.getPosition()`). Change this to
  `instance.gazeTarget = {x, y}` (or nil). Then a small "attention" function
  picks the target each frame: the pointer, a thrown object, another Mipo, or
  idle wander. Touch has no hover, so on iPad "pointer" means the last touch
  point or the object being dragged.

Already there: multi-touch pointer joints (`src/physics/box2d-pointerjoints.lua`),
priority-based grab (picks the best fixture under the finger), the fixed
timestep, touch callbacks, scene-script hooks, snap fixtures (`src/physics/snap.lua`).

---

## The road (order, 2026-10-30)

How to get from here to the brainstorm in `DOLL-PLAY-MENU.md` ("From a brainstorm"). Most of it
rests on two missing pieces: a reusable **place** to put a Mipo, and **snaps that break and heal**.
Build those, and the rest is content. F4 (load your Mipo) stands apart: slot it in for a quick win.

- [ ] **R1. The hand feels right.** Throw clamp, squash on a gentle drop, a held face, snap spots
  glow while a Mipo is dragged near. F3 (tweens) is postponed: do this with timestamps unless a real sequence needs it.
- [ ] **R2. One "place" primitive.** A seat = a snap point that sets a pose (sit/lie); a container
  = a sensor that holds and can run something on what's inside. Chair, bed, box. After that the
  fridge, washer, closet and bucket are small behaviors, not new systems.
- [ ] **R3. Breakable snaps, properly.** Break on force or speed any time (not only while
  dragged), pop + boing, the snap point heals. Unlocks the swing, the rider thrown off the
  skateboard, the high-chair escape.
- [ ] **R4. Building.** Weld stacks with a threshold that grows with the load above, a nudge into
  alignment; a stack sways as one. Needs R3; snap blocks and the cart exist.
- [ ] **R5. Rooms that remember.** W2, then W3 (`WORLDS-AND-DOORS.md`). Then decide: stacked
  rooms with trapdoors in one scene, or doors between scenes? Slopes through floors and the
  draining bathtub hang on that.
- [ ] **R6. Room toys.** Content without end: one toy at a time, a week or less each (pulley,
  fan, xylophone floor, wrecking ball, swappable wheels), picked per room.
- [ ] **R7. Alive extras.** Personalities, boredom and wandering, day/night. Last: heavy and
  helium Mipos fight "light and quick to throw".

R1–R3 plus a few rooms is a whole Sago-sized app; the rest can be updates or a sequel.

## Picked from the menu

(Nothing in progress. Move an item here from `DOLL-PLAY-MENU.md` when you start it.)

## Guardrails

- One menu item in progress at a time. Finish it, see it in the play scene, tick it.
- Art comes last. Use greybox props until the feel is right.
- Watch for "and also": a new idea goes into the menu's *Other ideas*, not into the item in progress.

