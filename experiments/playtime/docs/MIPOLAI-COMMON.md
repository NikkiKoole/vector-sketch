# Mipolai shared — the cross-app template

The studio-level tech and mechanics that **every Mipolai app should inherit**,
so each new app harvests rather than re-implements. Drafted in conversation
2026-05-28 from the Bathhouse pre-build review.

This is a **catalog**, not a plan. Each item names: *what it is, where it
lives now, and what's missing to make it reusable.* Concrete build-out is
done per-item, on demand, when an app needs it.

Strategy backdrop: `STUDIO-STRATEGY.md`. First consumer: `APP-1-BATHHOUSE-PLAN.md`.

---

## Runtime / engine primitives

### Camera system (intra-scene viewport — follow / zoom / pan)

- **State:** partial, not extracted.
- **Lives in:** `experiments/puppet-maker2/scenes/editGuy.lua` (camera control
  inside a scene — pan/zoom on the active view); also pieces in
  `experiments/physics-testbed/scenes/`.
- **Gap:** no shared library. Each app re-implements follow / zoom-to-object /
  pan-and-ease primitives.
- **Reusable shape (when extracted):** `lib/camera-stack.lua` (or similar) with
  `followBody(b, lag)`, `zoomTo(target, duration)`, `panTo(x, y, ease)`,
  `shake(intensity, dur)`. Built on top of `vendor/brady` (the existing
  camera) — additive, not a replacement. *Inter-scene* transitions are
  handled by the Scene manager (below), not here.

### Game state machine — the spine of every app

- **State:** **BUILT** 2026-05-28. `src/statemachine.lua` (~100 lines) + 18
  passing specs in `spec/statemachine_spec.lua`. Predecessor: `vendor/SceneMgr.lua`
  used by `puppet-maker2` (same intent, fewer footguns — real `leave` hook,
  data threaded through transitions, push/pop overlays, history, inspectability).
- **What it is:** a game is its top-level state machine; this makes that
  explicit. Each state has `enter / update / draw / leave / resume` hooks.
  Navigation: `transition(to, data)` for linear flow, `push/pop` for overlays,
  `back(data)` for back-navigation via history, `clear()` as an escape hatch.
  Data is threaded through every navigation op — `app:transition('gallery',
  { highlight = mipo })` is received by `gallery.enter(data)`. App-scope state
  lives as plain locals at the top of the app's script.
- **Canonical use** (Bathhouse-shaped). Scene scripts get `statemachine` in
  their sandbox env (see `src/script.lua` `scriptEnv`) — no `require` needed:

  ```lua
  local app = statemachine.new()
  local discovered = {}   -- app-scope state, just locals

  app:state('splash', {
      enter  = function()    worldState.paused = true end,
      update = function(dt)  if pressed then app:transition('bath') end end,
  })

  app:state('bath', {
      enter  = function()    spawnCluster(); currentMipo = pickMipo() end,
      update = function(dt)  if mudFullyClean() then app:transition('reveal') end end,
      leave  = function()    table.insert(discovered, currentMipo) end,
  })

  app:state('gallery', {
      enter = function(data) highlighted = data and data.highlight end,
  })

  function s.onStart()  app:transition('splash') end
  function s.update(dt) app:update(dt) end
  function s.draw()     app:draw() end
  ```

- **Folder convention:** when an app has 2+ scene JSONs, group under
  `scripts/<app>/`. Single-scene apps stay flat. The folder is the *signal*
  "this is an app, not a one-off mechanic demo." First app to use this:
  Bathhouse — adopt the folder when the second scene JSON arrives.
- **Pairs with:** the visual transitions entry below (the state machine
  handles *logic*, scene manager handles the *visual* fade/slide/iris between
  states).

### Scene manager — visual transitions between states (fade / slide / iris)

- **State:** partial, not extracted. The logical navigation is now handled by
  the Game state machine above; what's still missing is the *visual* part —
  the fade / slide / iris primitives the state machine can invoke during a
  transition to make it feel like a transition, not a snap.
- **Lives in:** ad-hoc tweens scattered across `experiments/puppet-maker2/`
  scenes (e.g. `splash.lua` uses `Timer.tween` on a `fluxObject` with
  `out-bounce` easing and `Timer.after` to chain into the next `SM.load`).
  No shared library — each scene rolls its own fade.
- **Reusable shape (when extracted):** `lib/transitions.lua` with
  `play(kind, duration, onMidpoint)` for one-shot visual effects driven from
  a state's `leave` (call it, then on midpoint do the actual `app:transition`,
  finishing the visual on the other side). Kinds: `cut / fade / slide / iris
  / wipe` — the studio's visual vocabulary. Frame-accurate, runs over a
  full-screen canvas so it's scene-agnostic.
- **Engine change still pending** (gated on an app actually needing it):
  `sceneLoader.loadScene(path, { keepScript = true })` — when a state's
  `enter` brings in a *different* scene JSON, the script must not be cleared
  by the lifecycle fix from earlier. Two-line opt-in, default behavior
  (full teardown) stays safe. Most Bathhouse-shaped apps probably stay on
  one scene JSON and never need this.

### Mipo sounds + speech (mipomi-lang)

- **State:** real experiment, partially integrated.
- **Lives in:** `experiments/mipomi-lang/` — `grammar.txt`, `glossary.txt`,
  `mouth/` (15 phoneme shapes), voice samples (`samples-nikki`, `samples-theo`,
  `samples-herman`). Playtime's editor already uses *"15 mouth shape presets
  (from mipomi-lang phoneme system)"* — see `MIPO-EDITOR-TODO.md` §1 Mouth.
- **Gap:** the runtime bridge isn't wired. There's no API like
  `mipo:say(utterance)` that picks phonemes → samples → lipsync tween targets.
- **Reusable shape:** one module that owns *utterance → (phoneme stream + audio
  cues + mouth tween schedule)*, consumable by any app that has a Mipo on
  screen.

### Emotion → body parts + sounds

- **State:** tween targets exist; the emotion layer above them does not.
- **Lives in:** `tweenVars` table on a character instance — `eyesOpen`,
  `mouthOpen`, `mouthWide`, `lookAtPosX/Y`, `lookAtCounter` (see
  `MIPO-EDITOR-TODO.md` §1 Pupils / Mouth). Phase 3 animation (eye blink,
  pupil look-at polish, mouth open/close tween) is the remaining bucket.
- **Gap:** an *emotion layer* — `setEmotion('curious')` → resolves to the
  tween targets + a chosen utterance/phoneme set + bodyhair/brow biases.
  Without it, every app would dial tweens directly.
- **Reusable shape:** `lib/mipo-emotion.lua` with named states
  (happy / curious / sleepy / startled / sad / blank). Each state maps to tween
  targets + phoneme bias + a sound cue tag.

### Physical actions (named behaviors for a Mipo)

- **State:** building blocks exist; the abstraction does not.
- **Lives in:** `src/character-manager.lua` (DNA, body parts, positioners) and
  the mipo editor in playtime. Individual physical setups are scattered in
  scene scripts (`scripts/*.playtime.lua`).
- **Gap:** an *action* abstraction — `mipo:do('wave')`, `mipo:do('walk')`,
  `mipo:do('react-to', other)`, `mipo:do('float-up')`. Currently each scene
  re-codes these from primitives.
- **Reusable shape:** `lib/mipo-actions.lua` — a small registry of named
  procedural actions that apply forces / set joint targets / drive
  `tweenVars`. Composes with the emotion layer (an action can imply an
  emotion).

### Tuning-slider debug panel

- **State:** one good live example, not extracted.
- **Lives in:** `scripts/mudready.playtime.lua:672` (`s.drawUI`) — density /
  drag / ang.damp / water level / shower pos sliders backed by `local`
  tuning constants. Hot-reloaded.
- **Gap:** every scene re-writes the same `ui.sliderWithInput` boilerplate.
- **Reusable shape:** `lib/tune.lua` with `tune.add(name, ref, min, max)` that
  collects sliders into a draggable panel. Optional: persist values back into
  source via a flag (dev-time only).

---

## Studio-shared mechanics (cross-app behavior, not engine code)

### Mipo breeds + portable code (cross-app identity)

- **State:** drafted, being extended.
- **Lives in:** `docs/MIPO-CODE-IDEA.md` (the canonical spec — 6 breeds
  drafted, format `SPUD-XKBMR-TVQZN`) + `src/character-manager.lua:599`
  `randomizeMipoConstrained` (the function being extended to dispatch per
  kind).
- **Gap:** 10 breeds locked + per-breed constraint tables + the bidirectional
  code (`dnaToCode` / `codeToDna` / `spawnFromCode`). See MIPO-CODE-IDEA §"What
  needs to be built."
- **Why studio-shared:** a SPUD in app #1 is the same SPUD family in any
  future app that knows the kind definitions. The breeds are the stable IP
  unit across the portfolio.

### Shelf + paywall

- **State:** not built.
- **Why every app needs it:** per `STUDIO-STRATEGY.md`, the standard Mipolai
  monetization is **free until N discoveries, then a one-time ~€2.99 unlock,
  no ads / no IAP / no subs.** Every app has a gallery of discovered things;
  the gallery *is* the paywall surface; the gallery *is* also the footage
  source for marketing.
- **Reusable shape:** `lib/shelf.lua` — persistent discovered-item store +
  gallery-view UI primitive + paywall gate at configurable N.

### Completion payoff beat

- **State:** not extracted.
- **Why:** every Mipolai app has the same emotional shape — detect-completion
  → name-reveal card → happy chime → settle. (Bathhouse reveal, Puppet Maker
  "you made one," and every app after.)
- **Reusable shape:** `lib/payoff.lua` with `payoff.play(name, kind?)` that
  composes name-card UI + chime + a settle tween hook.

### In-app footage capture

- **State:** not built.
- **Why:** the strategy doc treats clips as a byproduct of play; every payoff
  is a 10–20s shareable moment. The app should record them, not require a
  separate screen-recording session.
- **Reusable shape:** `lib/clip.lua` that captures the N seconds *around* a
  triggered moment (ring buffer) and writes a small video/gif.

### Wordless onboarding (house style)

- **State:** mental rule, not codified.
- **Why:** Mipolai apps don't write "tap here." Gesture, sound, animated hint
  — never copy. Worth a one-page house-style note someday so it stays
  enforced across apps.
- **Where it'd live:** future `docs/HOUSE-STYLE.md` (not yet) — or absorb into
  `MANIFESTO.md`.

---

## Recurring design forks (decision aids, not todos)

Every Mipolai app will hit these. Worth a studio-level stance instead of
re-deciding per app:

- **Fixed roster vs procedural Mipos** — *Lean: fixed* for named-character
  apps (Bathhouse, future story apps); procedural for player-built apps
  (Puppet Maker side).
- **Endless stream vs N-per-session** — needs a stance.
- **The Sago Rule** (one verb, 4–6 weeks, no "and also") and the manifesto
  ("ambient physics props ≠ a second verb") — already discipline; this is the
  catalog of places they bite.

---

## Cross-refs

- `STUDIO-STRATEGY.md` — the *why* (positioning, sequencing, monetization).
- `APP-1-BATHHOUSE-PLAN.md` — first consumer of this template.
- `MIPO-CODE-IDEA.md` — breed system / portable Mipo code (the IP layer).
- `MIPO-EDITOR-TODO.md` — face/animation gaps backing the emotion layer.
- `MANIFESTO.md` (project root) — the Sago Rule.
