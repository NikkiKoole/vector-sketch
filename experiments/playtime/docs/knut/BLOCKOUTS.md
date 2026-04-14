# Knut scene blockouts — implementation status

Tracking what's actually been built for each scene in `docs/knut/SCENES.md`.
This is the "what's in the code" doc; `SCENES.md` is the "what the scene IS"
design doc.

---

## 1. Cliff / Level Select — `scripts/cliff.playtime.json`

**Status:** Blockout complete, no script wired up yet.

**Backdrop:** `gevaarland.jpg` at `(-500, -363)` scale 0.5 (landscape,
2002×1452 source). Saved via `/ping` → drag & save flow.

**Bodies:** 28 bodies, 23 joints, 2 statics.

**Labels used:**
- `knut`, `pandora`, `django` — each a multi-body ragdoll standing on the
  cliff edge. (The joint count tells us they're jointed body-part assemblies.)
- `cliff` — the static cliff edge / ground the characters stand on.
- `below` — static sensor/zone below the cliff, intended as the "fell off /
  entered the level" trigger.

**Pending work:**
- `scripts/cliff.playtime.lua` — navigation script. Plan:
  - On `beginContact` between any of `knut`/`pandora`/`django` and `below`,
    load `stapelaar.playtime.json` + `.playtime.lua`.
  - Possibly also: tap somewhere (arrow sign?) to trigger the same.
- Decide: all three trigger the same scene (one shared destination), or
  per-character destinations (Knut→stapelaar, Pandora→river, Django→zombies)?
  Deferred until there are more target scenes.
- Character appearance: currently just placeholder bodies. Real art comes
  via the texture deformation / skinned-texture pipeline (see
  `docs/KNUT-TOOLKIT-TODO.md` and `experiments/deform-textured/`).

---

## 2. Stone Balancing — `scripts/stapelaar.playtime.json` + `.playtime.lua`

**Status:** First gameplay sketch working.

**Backdrop:** `stapel-met.jpg` at `(-242, -352)` scale 0.5 (portrait,
968×1406 source).

**Bodies:** 10 base bodies (person ragdoll + ground + 2 side walls) plus
however many stones have been spawned.

**Labels used:**
- `stone` — applied automatically by `spawnStone()` to every spawned rock.
- `anchor` (optional) — if any body carries this label, it overrides the
  auto-detected spawn base. Currently not used in the saved scene; the
  first static body (the ground) is used instead.

**Gameplay (controls in-app):**
- `SPACE` — spawn a random-sized stone at the mouse cursor.
- `B` — insert a stone at the stack's base anchor, lifting the existing
  column + anyone standing on it by the new stone's height.
- `C` — clear all spawned stones.

**How the lift works:**
1. Seed: the last stone spawned via `B` (`currentBase`). Fallback: any
   `stone`-labelled body within `STACK_X_TOLERANCE` (60px) of the anchor X.
2. Flood via contacts — *but only to bodies above the current one* (with
   a small Y jitter margin). This keeps the chain strictly vertical and
   excludes fallen stones sitting beside the base.
3. Flood via joints unconditionally — once any body part of a multi-body
   character is reached, the rest of them come along.
4. Everything in the resulting set gets `setPosition(x, y - dy)` +
   velocities zeroed.

**Side-wall reset:**
- `beginContact` hook: if a `stone`-labelled body touches a static that
  isn't the main ground (i.e. a side wall), that specific stone is queued
  for destruction in the next `update()` (deferred because Box2D callbacks
  fire mid-solver).
- Stones resting on the main ground are always fine.

**Pending work:**
- Better feel: stone shape variety (irregular polygons instead of
  rectangles), tuning friction / lift overlap.
- Topple detection → "score" when Knut falls off the stack.
- Character: currently a placeholder multi-body ragdoll; will eventually
  be the real Knut character once the toolkit lands.

---

## 6. Moon & Robots — `scripts/maan.playtime.json` + `.playtime.lua`

**Status:** First gameplay sketch working — orbital fling.

**Backdrop:** `maan.jpg` at `(-393, -427)` scale 0.4 (portrait-ish,
1965×2133 source).

**Bodies:** 19 bodies, 14 joints, 1 static (the moon).

**Labels used:**
- `planet` — the static moon body. The script applies inverse-square
  gravity from each body labelled this (singular here, but the list
  scales).
- `knut`, `django` — multi-body astronaut characters (jointed ragdolls).
- `robotbig`, `robotsmall` — dynamic robot obstacles. They also feel
  gravity, so they orbit/crash the same as the player characters.

**Gameplay:** Drag any dynamic body with the mouse to fling it. The
moon's gravity bends the trajectory into an ellipse (or a crash, or an
escape, depending on throw strength). World gravity is zeroed in
`onStart` so the moon is the only attractor.

**How orbital gravity works (`maan.playtime.lua`):**
- `onStart`: zeroes both `state.world.gravity` and the Box2D world
  gravity, finds all `planet`-labelled bodies, caches their gravity
  strength + influence radius.
- `update(dt)`: for each planet × each dynamic body, applies a force
  toward the planet of magnitude `GRAVITY / d²` (capped by
  `INFLUENCE_RADIUS` for perf).
- `draw()`: paints faint guide rings at 2x/4x/6x the planet's radius so
  you can eyeball orbit sizes while tuning.

**Tuning (top of script):**
- `GRAVITY = 25000000` — much higher than the planets.lua defaults
  because the moon body is huge (radius 280) and characters spawn
  64–130px from its surface, deep in the gravity well.
- `INFLUENCE_RADIUS = 50000` — large enough that nothing in this scene
  escapes the cutoff.

**Pending work:**
- Robots are spawned 64–65px from the moon surface — they crash on the
  surface within a fraction of a second after unpause. Either move them
  out for orbit-as-obstacles, or treat them as decor on the moon.
- Goal area / win condition.
- Booster control — currently throw-once; could add tap-while-airborne
  thrust for steering mid-flight.

---

## 3-5, 7. Not yet blocked out

See `docs/knut/SCENES.md` for the catalog:

3. Crocodile River — floating crocs, buoyancy + timing jumps
4. Zombie Soccer — ragdoll characters kicking a ball
5. Juggling Monster — catch/throw fireballs
7. Shadow Island — catapult / slingshot (catapult script already exists)

---

## Cross-cutting infrastructure (already done)

- **Per-scene backdrops:** `state.backdrops` persisted in scene JSON (url,
  x, y, scale, border, foreground). Scenes bring their own backdrops;
  session defaults are empty. See `src/io.lua` and `src/state.lua`.
- **Physics callbacks wired:** `main.lua` registers
  `state.physicsCallbacks` on the world at startup so scene scripts get
  `beginContact` / `endContact` / etc.
- **Lurker preswap for scene scripts:** `scripts/*.playtime.lua` files are
  skipped by lurker's hotswap (they're not modules; scene-loader reloads
  them via mtime poll instead). Prevents the error overlay when adding a
  new scene script during a live session.
- **Dev-scaffolding disabled:** the starter humanoid mipo + ground
  rectangle in `main.lua`'s `love.load` are commented out so their cached
  DNA doesn't leak into gameplay scenes (the `c` key was cloning mipos).
- **Pointer-joint safety:** `getInteractedWithPointer` skips destroyed
  bodies so destroying a body mid-drag (e.g. a stone flying into a wall)
  doesn't crash `love.update`.

## Known quirks to revisit

- `did panic!` lines occasionally appear in the log when bodies are
  destroyed under specific conditions. Game-loop's panic detector notices
  something odd mid-frame but gameplay keeps running. Worth chasing once
  we hit a real reproducible case.
- After a sharp B-press sequence (multiple presses in one frame), stones
  can scatter horizontally instead of stacking cleanly — harmless at human
  press rate, but worth noting.
- The UV/backdrop reference system is still index-based in memory with
  a URL fallback on disk; see `docs/UV-BACKDROP-FRAGILITY.md` for the
  remaining hardening work (much of it addressed by the recent DQS
  commit).
