# Next steps — post-audit, July 2026

Written 2026-07-10, right after closing out `CODE-AUDIT-2026-07.md` (all A/B/C/D
items done, 726 tests, luacheck 0/0). This doc answers: *given the goal — make
Mipos, play/build their world, sometimes carve a piece out as an app, with
visual continuity from puppet-maker2 — what now, and what code needs
strengthening?*

---

## Where you stand

The audit worked. The engine is in the best shape it's ever been: every
"broken right now" item fixed, every listed risk fixed, cleanup done, the
riskiest untested modules now have specs. What remains open is *known and
parked*, not lurking: Phase 7d (DNA topology-as-data), Phase 8 (perf/memory/UV
hardening), and a handful of clone-pipeline soft spots.

Against the three goals:

1. **Make Mipos** — ✅ mostly done. The Mipo editor has feature parity with
   puppet-maker2 (per `MIPO-EDITOR-TODO.md`), DNA + randomize + face
   gaze/blink work. The deferred polish list (eyelashes, hand/foot images,
   DNA boundaries, hair dedup, patches, breeds) was explicitly moved to
   "app #2 polish" — leave it there.
2. **Play with them / build their world** — 🟡 the scene layer is real
   (`.playtime.json` + sandboxed script, statemachine spine, `sm-demo` proves
   a full splash→bath→reveal flow) but the *Mipo-as-actor* layer is missing:
   no tween lib, no emotion layer, no named actions, no shelf/payoff. That's
   the `MIPOLAI-COMMON.md` gap list, and it's accurate.
3. **Carve a scene out as an app** — 🔴 the one structural hole. There is no
   play-only mode. Editor UI, editor input branches, and editor overlays run
   unconditionally every frame. Everything else about shipping (fixed-timestep
   loop, touch events, asset bundling logic in `webtest/build-web.sh`,
   appelflap iOS fork) already exists.

**Visual continuity with puppet-maker2: you already have it.** Playtime *is*
the successor — same Box2D-ragdoll-plus-DNA lineage, and 234 of the part PNGs
in `textures/` are the exact files from puppet-maker2's `assets/parts`
(same `-mask` fg convention, same bg/fg/line layering idea). Nothing needs
porting for the *look*. The only assets that live solely in puppet-maker2 are
the polygon `.txt` geometry files (readAndParse format) and the melodypaint
audio system — grab those on demand, not preemptively.

---

## Recommended order

The Bathhouse build phase is already underway (at step 3 — DNA-procedural
Mipo inside the mud cluster, per the plan's status block) and the spike
verdict was "go." Don't invent a new project — but slot one engine task in
front, because it changes how every scene after it feels.

### 1. Play mode (~1–2 days) — the keystone

A `--play <scene>` launch mode: load one scene, start unpaused, skip all
editor chrome. This is the literal mechanism for "sometimes decide certain
parts are an app" — every scene becomes instantly previewable as its shipped
self, and the Bathhouse build steps ("end each step with the app launchable")
get honest. Concretely:

- `main.lua` — parse `--play`, and in `love.draw` gate
  `playtimeui.drawUI()` (main.lua:417), `renderActiveEditorThings()` /
  `renderSteinerOverlay()` (main.lua:404-405) and the FPS/recording HUD
  behind `not state.playMode`. Scene `draw`/`drawUI` hooks keep running.
- `input-manager.lua` — `handlePointer` (line 238) interleaves editor
  selection/vertex-edit/mode logic with the actual play path (pointer-joint
  grab + `onPressed`/`onReleased`, lines 366-414). In play mode, jump straight
  to the play path. Kill the hardcoded `x > w - 300` panel reservations
  (lines 179, 307) — on an iPad those silently eat the right edge of the
  screen.
- Keep spacebar/`u`/etc. editor keys gated too.

This is deliberately *not* a separate runtime entry point yet — a flag is
enough until an actual App Store build (Bathhouse step 9) forces the full
strip/bundle pass, and `build-web.sh` already knows how to do selective
asset copying when that day comes.

### 2. Tween/timer layer (~0.5 day) — the most-referenced missing piece

`REBUILD-IN-PLAYTIME.md`, `MIPOLAI-COMMON.md` (emotion layer, transitions,
idle behaviors) and the puppet-showcase port all bottom out at "playtime has
no tween library." Drop `hump.timer` (or flux) into `vendor/`, expose it in
the script sandbox (`script.lua` `baseEnv`), and the blink/breathe/look-at
idle loop, visual state transitions, and emotion layer all become scene-level
work instead of engine work.

### 3. Bathhouse build phase (currently at step 3)

Back to `APP-1-BATHHOUSE-PLAN.md` as written — the DNA-procedural Mipo
inside the mud cluster ("when this lands, you have a playable game"), then
the reveal beat and blob lifecycle. Note the plan has evolved: no separate
attendant Mipo (the player is the attendant), and the wash verb now has
three affordances (sponge, soapbar, showerhead). With play mode from step 1
above, every one of these milestones is viewable as "the app," which is the
dopamine loop the plan's ordering principle asks for.

### 4. Harvest MIPOLAI-COMMON items only when Bathhouse pulls them

Emotion layer, `mipo:do('wave')` actions, shelf+paywall, payoff beat — the
catalog is right that these are per-item, on-demand. Shelf+paywall is the
first one Bathhouse will genuinely need (the gallery *is* the paywall
surface). Resist extracting the rest speculatively.

### 5. Puppet-showcase scene (optional, ~2 days, after tweens)

The Option A port from `REBUILD-IN-PLAYTIME.md` — 3–5 saved Mipos idling in a
scene. Worth doing not for nostalgia but because it exercises exactly the
"load N characters, run behaviors" pattern Bathhouse's attendant needs, and
it's the visual-continuity proof: puppet-maker2's world, running in playtime.

---

## Code that needs strengthening (file-level, ranked)

**Blockers-in-waiting for shipping an app:**

- `input-manager.lua:238` `handlePointer` — split editor vs play concerns
  (part of play mode above). Same for the `x > w-300` gates.
- **Touch camera** — no pinch-zoom / two-finger pan; camera is wheel + right-drag
  only (`main.lua:447`, `input-manager.lua:786`). Bathhouse is one fixed
  screen so it's not step-1 work, but any pannable world-scene app needs it.
- **Keyboard-driven scene scripts** — `stapel`/`sm-demo` advance on keys that
  don't exist on iOS. House rule going forward: scenes destined for export
  use `onPressed`/tap, `onKeyPress` is dev-only.
- **Appelflap IAP bugs** — `APPELFLAP-ISSUES.md` lists three one-line bugs
  (first purchase silently lost; restore wipes entitlements first; observer
  registered late). ⚠️ Note a doc conflict: `APP-1-BATHHOUSE-PLAN.md` says
  "paid app, no IAP needed → non-blocking," but `STUDIO-STRATEGY.md` (and the
  standing plan) says **free + one-time €2.99 unlock — which requires IAP.**
  If free+unlock is the model, these three bugs are launch blockers and each
  is a one-liner; fix them during the step-9 iOS window at the latest.
- `conf.lua` — `highdpi=false`, fixed 1000×800; needs highdpi + aspect/safe-area
  handling in the iOS pass.

**Engine health (Phase 8 subset that matters for a kid app left running an hour):**

- **Image/OMP/canvas caches never cleared** (`DEEPER-ISSUES.md`). For a
  long-running toddler app this is the one memory risk that bites in the
  field. An LRU or scene-unload purge on the image cache is the 80% fix.
- **Stable z-sort tiebreaker** — same-z flicker is exactly the kind of visual
  glitch a reveal moment can't afford. Trivial fix (sort key = z + insertion
  index).
- **UV hardening #1** from `UV-BACKDROP-FRAGILITY.md` — replace the UV lookup
  loop with vertex-index-based mapping. The rest of that doc's list can wait.
- **Load-boundary error handling** — "zero asserts, log-and-continue" is fine
  in the editor, wrong in a shipped app. Minimum: `io.buildWorld` and
  scene-script load wrapped so a bad scene fails loudly in dev and safely
  (skip + message) in play mode.

**Parked deliberately (don't touch now):**

- Phase 7d DNA topology-as-data — big, and Bathhouse doesn't need it.
- Clone-pipeline soft spots (OMP dirty flag, influence remap nils, disabled
  UUID collision checks) — all clone-time, editor-side; revisit with the
  Phase 8 OMP cache.
- `state.currentMode` multi-writer — `modes.lua` dispatch already took the
  edge off; a full state machine is refactor-for-its-own-sake right now.
- Behaviors-system stub / LIMB_HUB — superseded in spirit by the
  MIPOLAI-COMMON actions layer; build that instead when needed.

---

## The one-paragraph version

The engine audit is done and nothing structural blocks the goal. The single
missing piece between "playground" and "app factory" is a play-only mode
(~1–2 days), and the single most-referenced missing engine feature is a tween
layer (~0.5 day). Do those two, then continue the Bathhouse build phase
(already at step 3) as `APP-1-BATHHOUSE-PLAN.md` prescribes — it is simultaneously app #2
and the proving ground for the scene-to-app pipeline every future Mipolai app
will use. Puppet-maker2 continuity is already achieved through shared assets
and the DNA lineage; honor it with a puppet-showcase scene when the tween
layer lands, not with a port. Resolve the pricing conflict (paid vs
free+unlock) before step 9, because free+unlock makes the three appelflap
IAP one-liners launch blockers.
