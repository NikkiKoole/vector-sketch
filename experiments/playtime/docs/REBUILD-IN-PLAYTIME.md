# Rebuilding Other Experiments Inside Playtime

Playtime has grown into a capable editor/runtime. Other experiments in `experiments/` duplicate effort that could live on top of playtime instead. This doc evaluates whether two specific experiments could be rebuilt as playtime scenes, and what's missing.

Scope right now: `physics-testbed` (mipo-on-bike-downhill) and `puppet-maker2` (character editor + showcase). Both are known quantities; the goal is to identify the minimum gap list before deciding whether to port.

---

## 1. physics-testbed → playtime (downhill bike scene)

**What it is.** A bike-down-a-mountain physics game. Mipo on a scooter/bike, infinite procedurally-generated terrain, input-driven pedaling, wheelies, turbo pickups, particles, organic soundtrack.

**Entry point:** `experiments/physics-testbed/main.lua` → `scenes/downhill.lua`.

**Root-lib dependency.** `vehicle-creator.lua:2` does `package.path = package.path .. ";../../?.lua"` and pulls `lib.box2dGuyCreation`, `lib.connectors`, `lib.mainPhysics`. Playtime is self-contained, so those need adaptation (playtime has equivalents but different APIs).

### Feature status

| Feature | Status | Notes |
|---|---|---|
| Box2D world + bodies + joints | already in playtime | full set |
| Mipo character (DNA) | already in playtime | `src/character-manager.lua`, `randomizeMipo` works |
| Revolute/weld/distance joints for bike | already in playtime | joint-handlers.lua |
| Camera pan/zoom, world coords | already in playtime | `src/camera.lua` |
| Scene scripts (`scripts/*.playtime.lua`) | already in playtime | `src/script.lua` |
| Bike frame assembly | missing, small | port `vehicle-creator.lua` into a scene-script helper |
| Mipo ↔ bike rigging (hands→bars, feet→pedals) | equivalent | playtime's joints cover it; `lib.connectors` is the physics-testbed idiom |
| Input → angular impulse on wheel | missing, small | ~30 lines in `scene.update()` |
| Wheelie / loop detection | missing, small | sensor fixture + contact callback |
| Turbo pickups | missing, small | sensor collision in scene script |
| Procedural infinite terrain | **missing, large** | downhill uses noise-based `getYAtX()` + streaming chain-shape bodies; playtime is designer-placed scenes |
| Parallax scenery (trees, clouds, grass) | missing, medium | no layered-backdrop system; would render in `scene.draw(cam)` |
| Particle effects | missing, small | use `love.graphics.newParticleSystem` directly in the scene script |
| Organic music reactivity | missing, small | `organicMusic.lua` is self-contained — port as-is |

### Biggest gaps

1. **Procedural terrain.** The whole scroll-a-mountain feel depends on it. Two options:
   - Pre-generate ~10 km of terrain once, bake into a `.playtime.json`. Big file, one-time cost.
   - Implement streaming terrain in the scene script — spawn/destroy chain-shape bodies based on camera position.
2. **Input wiring.** Scene scripts don't currently receive `love.keypressed` directly; you poll `love.keyboard.isDown` in `scene.update()` and call `body:applyAngularImpulse(...)`. Minor but not plug-and-play.
3. **Parallax scenery.** Playtime's backdrop is a single reference image. Parallax layers would mean custom rendering in the scene script.

### Smallest viable rebuild

`scripts/downhill.playtime.lua` that:
1. Spawns a mipo + bike (port of `createVehicleUsingDNACreation('bike', ...)`).
2. Loads a pre-baked terrain chunk (~5 km) from the `.playtime.json`.
3. `scene.update(dt)`:
   - Apply pedal/lean impulses from `love.keyboard.isDown(...)`.
   - Follow camera: `cam:setTranslation(bikeFrame:getPosition())`.
4. No particles, no audio, no parallax. Physics + input + camera, that's it.

Playable slice in ~1 day. Then iterate terrain → streaming, add particles, add audio.

---

## 2. puppet-maker2 → playtime (character editor + showcase)

**What it is.** A character editor (the older predecessor to playtime's Mipo editor) plus a multi-character showcase scene with idle animations. See `docs/MIPO-EDITOR-TODO.md` for the feature-by-feature diff against playtime's current Mipo editor — that doc is still accurate.

**Entry point:** `experiments/puppet-maker2/main.lua` → scenes including `outside.lua` (the 5-character playground).

**Root-lib dependency.** Similar to physics-testbed: pulls `lib.updatePart`, `lib.texturedBox2d`, `lib.box2dGuyCreation`, `lib.mainPhysics`, `lib.dna`. Playtime's equivalents exist (`src/character-manager.lua`, `src/dna-defaults.lua`, etc.) but APIs differ.

### Feature status

| Feature | Status | Notes |
|---|---|---|
| Core DNA structure (multipliers/values/positioners) | already in playtime | see MIPO-EDITOR-TODO.md |
| Face parts (eyes, pupils, brows, nose, mouth, teeth) | already in playtime | full parity |
| Face skin patches | equivalent | rendered on head canvas |
| Body/limb hair, haircut | already in playtime | texture selection + color |
| Per-part multipliers | already in playtime | sx/sy/w/h throughout |
| OMP texture compositing | already in playtime | used everywhere |
| Save/load character JSON | already in playtime | |
| Randomize | already in playtime | `randomizeMipo` |
| Symmetric-edit toggle | already in playtime | |
| UI: accordion panels, shape grids | already in playtime | mipo-editor |
| UI: category sidebar + zoom-to-part | missing, small | cosmetic polish, not functional |
| Multi-character showcase scene | missing, medium | scene boilerplate + physics setup for 5 chars |
| Eye-blink tween (eyesOpen 0→1, ~0.15s) | **missing** | no Timer/tween library in playtime |
| Mouth animation (mouthOpen/mouthWide) | missing | same — needs tweens |
| Pupil look-at tracking with tween | missing, partial | `lookAtMouse` flag exists, no tween state |
| Breathing / idle jiggle | missing | applies torso impulse on a timer |

### Biggest gaps

1. **No tween library.** Puppet-maker2 uses `hump.timer` everywhere for blinks, breathing, mouth shapes. Playtime has no tweening system. Smallest fix: drop in `hump.timer` (or similar) under `vendor/` and expose a lightweight `tweenVars` field on character instances. Drives eyesOpen, mouthOpen, mouthWide, lookAt.
2. **Root-lib shims for character construction.** Puppet-maker2's DNA pipeline goes through `lib.dna`, `lib.box2dGuyCreation`, `lib.mainPhysics`. All have playtime equivalents but not plug-compatible. A port needs a thin adapter layer inside the scene.
3. **Idle-behavior runtime.** Periodic blinks, breath, subtle shrug — not a timer problem per se but a scheduler-of-behaviors that doesn't exist yet. Tiny loop in `scene.update()` can do it once the tween layer is in place.

### Smallest viable rebuild

**Option A — "Puppet Showcase" scene (~2 days).**
1. Add `vendor/hump-timer.lua` (or similar) to playtime.
2. Extend character instances with a `tweenVars` field: `eyesOpen`, `mouthOpen`, `mouthWide`, `lookAtX`, `lookAtY`, etc.
3. In the Mipo rendering path, read those fields when drawing eyes/mouth/pupils.
4. A new scene `scripts/puppet-showcase.playtime.lua` loads 3–5 saved characters, positions them, schedules random blinks + breathing in `scene.update(dt)`.
5. No editing UI in this scene — editor stays in the main tool panels.

**Option B — full "Puppet Editor Scene" (~4–5 days).**
Wrap Mipo editor inside a scene, add category sidebar + camera zoom-to-part, port the 5-character carousel. Only makes sense if you want puppet-maker2's UX in-product; otherwise Option A is fine.

---

## Cross-cutting observations

- **Neither port needs new engine-level work.** Both gaps (procedural terrain, tween system) are scene-level additions. Nothing in `src/` architecture blocks this.
- **`scripts/*.playtime.lua` is the right surface for both.** Playtime's per-scene Lua scripts are already the intended extension point.
- **Root-lib dependency handling is the same for both.** Neither can be copy-pasted — the APIs differ from playtime's self-contained equivalents. Plan ~20–30% of porting time on shimming.
- **Port order, if doing both:** `puppet-maker2 → showcase` first. Fewer gaps, most of the work is already done (per MIPO-EDITOR-TODO.md), and it validates the "load N saved characters, run behaviors" pattern that a downhill bike would also use.

## What would block a port

- `physics-testbed`: streaming terrain can't be deferred forever. If the target is the actual downhill feel, it has to be solved.
- `puppet-maker2`: deciding whether breathing/blinks need to be *physics-driven* (impulses) or just *visual* (tweened scale). The latter is way simpler and probably enough for the storybook use cases playtime serves.
