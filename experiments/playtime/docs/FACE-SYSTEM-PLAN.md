# Face System — Gap Analysis & Plan

**Verdict:** 2–3 dev days (~1–2 calendar weeks part-time). Not a port, not a rebuild. Verified against the live codebase 2026-05-14.

The face *rendering* pipeline in playtime is already complete and active — `appearance.face` is being created, decals are rendering live in the test scene. The gap is exclusively the *animation/controller* layer that drives blink, look-at, and mouth-state changes. The rendering reads tween values that nothing currently writes.

Closing this gap unblocks shipping the first small kids' app — currently scoped as **Mipo's Bathhouse** (see `APP-1-BATHHOUSE-PLAN.md`). The face system is the reaction-shot pipeline for the moment a mud blob is scrubbed clean and reveals a Mipo. Without working faces, the reveal lands flat. This is the manifesto-shaped pre-app-#1 work.

---

## Verified status (2026-05-14)

Live-codebase verification narrowed the gap considerably. The agent's biggest worry (Step 1 in the original plan: `appearance.face` not being initialized) is **not a worry** — the code already handles it.

**✓ Already done in code:**
- `appearance.face` IS initialized on torso1 + head at `src/character-manager.lua:708` and `:743` via `utils.deepCopy(D.face)`.
- A live test scene exists: `scripts/miposhader.playtime.json` renders **10 face decals** on the visible Mipo (verified via the claude-bridge).
- Face rendering pipeline is wired in `src/physics/box2d-draw-textured.lua` (note: lives under `src/physics/`, not `src/` root).
- 96 face textures in `textures/` (eyes, pupils, brows, noses, teeth, upper/lower lips with masks).
- DNA structure complete: `src/dna-defaults.lua` defines nested face appearance + positioners. Mouth uses 16-point normalized bezier shapes with 15 phoneme variants in `src/mouth-shapes.lua`.
- `addFaceDecals()` exists at `src/character-manager.lua:1447`, invoked at `:1808` when `k2 == 'face'`.

**✗ Remaining work (the actual gap):**

### ✓ Step A — Gaze system (done, in renderer)

**Reference point fix:** each pupil previously computed its angle from its own eye socket (`body:getWorldPoint(ox, oy)`), causing wall-eye divergence. Fixed to use `body:getPosition()` (head center) — both pupils share one angle. Lives in `src/physics/box2d-draw-textured.lua`.

**Distance-based blend:** `t = max(0, 1 - dist / gazeRadius)`. Cursor within `gazeRadius = 1000` world units → tracking; outside → pupils centered. Smooth lerp between the two. No state machine needed.

**Walleye:** shelved. May revisit as an occasional expression beat later.

### ✓ Step B — Blink system (done, in renderer)

Implemented as a module-level ticker (`tickBlink`) called at the top of `drawTexturedWorld`. Uses wall-clock time (`love.timer.getTime()`) so it's framerate-independent.

- Blink interval: 2–6 seconds (randomized per character)
- Close: 80ms, open: 120ms
- Drives `thing.eyesOpen` (0–1) on the body's userData thing
- Renderer reads `extra.isEye` on decals and multiplies `dh * eyesOpen` — squishes both eye bg and pupil decals together
- `isEye = true` is now set in `character-manager.lua` on both eye bg and pupil decals at creation

### ✓ Step C — Auto-init (done)

`initFaceDecals(body)` runs on first blink tick for any head body — sets `lookAtMouse = true` and `isEye = true` on the correct decals automatically. No manual bridge patching needed on load. `lookAtMouse` default also changed to `true` in `src/dna-defaults.lua` for newly created characters.

### ✓ Step D — Brow expressions (done)

Brows fully animated — position and shape both tween smoothly. All state lives on `thing`, driven by `tickBrowLerp` in `tickBlink`.

**Position:** `thing.lbrowYOffset` / `thing.rbrowYOffset` — left and right independently. Range ±20px feels good. Negative = raised, positive = lowered.

**Shape:** `thing.lbrowVec` / `thing.rbrowVec` — stored as `{p1, p2, p3}` floats, lerped directly. 10 named presets in `browBendVecs` table. Useful ones: 1=flat, 2=outer corners down, 4=raised both ends, 5=lowered both ends.

**Tween:** 0.1s duration, wall-clock time (`love.timer.getTime()`), framerate-independent. `setBrows(thing, lY, rY, bendIdx)` is the API — stores from/target and fires the tween.

**Click to randomize:** clicking within 200 world units of a head calls `randomizeBrows()` — random ±20px per brow, random bend from weighted options (biased toward flat/neutral).

**z-order:** brows at zOffset=252, above eyes (250) and pupils (251).

### Remaining — mouth animation

`mouthOpen` / `mouthWide` still not wired. The mouth shape system (15 bezier phoneme variants in `src/mouth-shapes.lua`) is built but nothing drives it yet. Lower priority than gaze+blink for the Bathhouse app — Mipo's reaction beat is mostly visual (eyes wide, brief expression), not speech.

---

## Reference Files

**Playtime:**
- `src/dna-defaults.lua` — face DNA structure
- `src/character-manager.lua:708, 743` — `appearance.face` initialization (verified)
- `src/character-manager.lua:1447` — `addFaceDecals()` definition
- `src/character-manager.lua:1808` — invocation point (gated on `k2 == 'face'`)
- `src/physics/box2d-draw-textured.lua` — face rendering pipeline (decals, brow curves, mouth stencil, look-at-mouse hook reads `extra.lookAtMouse`)
- `src/mouth-shapes.lua` — 15 bezier phoneme shapes
- `src/game-loop.lua` — where the face tick should live
- `scripts/miposhader.playtime.json` — existing test scene with active faces (no new scene needed)

**Puppetmaker2 (reference for controller logic only):**
- `experiments/puppetmaker2/main.lua:177–206` — tween vars (the thing to port)
- `experiments/puppetmaker2/dna.lua` — DNA structure (different shape, don't lift wholesale)

---

## Video Sequel Notes (mipo_club YouTube)

The face work is a natural sequel to the existing language/mouth video. Same layered-reveal format. Shoot **after** the engineering is done; demos must be real, not mocked.

**Beat structure (mirror the language video):**
1. Hook: "We have a mouth that talks. But the rest of Mipo is just staring."
2. Eyes appear (decals reveal — visible structural change)
3. Blink loop (timer-driven, charming)
4. Look-at-mouse (interactive — viewer feels the demo)
5. Brow expression (neutral → curious → angry → surprised; same Mipo, different read)
6. Combine with speech — Mipo speaks the language *and* emotes
7. Finale: a sentence in mipomi-lang with full face expression, ideally a callback to "Hola liko sobisibo"

**Format reminders:**
- ~4 minutes, screen capture + voiceover, warm + self-aware tone
- Layered reveal is the format — don't compress
- Real demos at every step
- Close with bilingual sign-off (rotate the phrase if you can; build the recurring bit)

**Cross-post (free distribution):**
- Same source footage → cut a wordless 30-second blink+look+brow highlight for Instagram Reels / TikTok
- One shoot, two edits

**CTA:**
- Mipo Puppet Maker (still free) is the safe pitch
- Tease "the next Mipo app" only if the title and ship window are ~80% locked when you film. Otherwise leave it ambiguous.

**Strategic note:** the video earns itself from the engineering work; do not flip it. If you find yourself adding a face feature *because it would look good on YouTube*, that's the trap — same Sago Rule violation, different door.
