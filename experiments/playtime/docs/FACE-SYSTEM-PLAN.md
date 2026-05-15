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

### Step A — Port the tween/controller variables (~2 dev days)

Puppetmaker2's `main.lua` lines 177–206 maintain these per-character:
- `eyesOpen` (0–1, blink amplitude)
- `mouthWide` (>1 surprised)
- `mouthOpen` (0–1.25+ open)
- `blinkCounter` (frames-until-next-blink)
- `lookAtPosX`, `lookAtPosY`, `lookAtCounter`

Grep across `src/` confirms **none of these strings exist anywhere in playtime.** Plain numbers with simple defaults — no rig changes needed.

**Action:** add the fields to the character instance struct in `character-manager.lua`. Initialize defaults on character creation.

### Step B — Wire the game-loop tick (~1 dev day)

Puppetmaker2 ticks blink/look-at counters each frame, fires `eyeBlink()` / `mouthSay()` to tween values when timers expire.

**Action:** add a per-character face-tick in `src/game-loop.lua` (or a dedicated `face-animator.lua`). Decrement timers, fire blink/look-at tweens. No tween library is required — simple math (lerp, sine, exponential decay) is enough; `lume.lua` is available in `vendor/` if a helper is wanted.

### Polish budget (~0.5–1 dev day)

After A and B land, expect to tune blink rhythm, look-at responsiveness, and mouth-state transitions to feel right. Bake this into the estimate before claiming "done."

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
