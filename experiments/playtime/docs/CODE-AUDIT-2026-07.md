# Code Audit — July 2026 (third pass)

Full-codebase audit after ~6 weeks away (last commit 2026-05-28). Follows up
on `DEEPER-ISSUES.md` (second pass) — nothing here duplicates that doc; these
are **new** findings. Three parallel review passes (core data layer, UI/input,
rendering/scripting/tests) plus tooling checks.

**Verification status**: items marked ✅ were verified against the source by
hand. Unmarked items are review findings with file:line — spot-check when
picking them up.

## State of the repo (2026-07-10)

- Git tree clean, 20 TODOs, no FIXMEs.
- Tests: **665 pass, 0 fail, 4 errors** — all 4 errors in
  `statemachine_integration_spec.lua` (see A1).
- Luacheck: 0 global leaks still holds. **61 style warnings** crept back
  (docs claimed 0) — mostly in `mipo-editor`, `sfixture-editor`,
  `box2d-draw-textured`, `character-manager` (shadowing, long lines,
  unused vars).
- `CLAUDE.md` numbers are stale: says 8 spec files / 367 tests / 42 src files
  / 0 warnings; reality is 17 / 669 / 62 / 61.

Overall: healthy. The May cleanup phases stuck. New code (mipo-editor,
statemachine, character work) outgrew the guardrails; the real bugs live in
the untested corners.

## A. Broken right now — fix first

1. ~~**`spec/statemachine_integration_spec.lua` — all 4 tests error in a
   fresh `love . --specs` run.**~~ **FIXED 2026-07-10** — spec now creates
   its own world when none is live (`ownWorld` flag), destroys it in
   teardown, and still restores the displaced scene when run via the bridge.
   Suite: 668 pass / 0 fail / 0 errors.
2. ~~**Every scene script executes twice per load.**~~ **FIXED 2026-07-10** —
   `script.loadScript` now returns the executed chunk's result; callsite no
   longer calls `()`. Verified live: an exec-counting script returns 1.
3. ~~**Saving corrupts the live snap system.**~~ **FIXED 2026-07-10** —
   `io.lua` now deepCopies the snap userData first and converts `at`/`to` on
   the copy. Verified live: a live body ref survives `gatherSaveData`.
4. ~~**Shape edits silently reset restitution/friction.**~~ **FIXED
   2026-07-10** — `recreateThingFromBody` now reads them from the first
   collision fixture (nil userData). Verified live: 0.7/0.15 survive a
   recreate on a body with an sfixture.
5. ~~**UUIDs are deterministic every launch.**~~ **FIXED 2026-07-10** —
   `uuid.lua` uses a private `love.math.newRandomGenerator` seeded from
   `os.time`/`os.clock`; the constant global seed stays intact for replay.
   Verified: different id sequences across two app restarts.
6. ~~**Numeric text fields bypass all clamping.**~~ **FIXED 2026-07-10** —
   `sliderWithInput` clamps typed values to [min, max] and ignores
   garbage/NaN input.
7. ~~**`snap.lua:47` offsetB in wrong frame.**~~ **FIXED 2026-07-10** — now
   `body2:getLocalPoint(x2, y2)`.

## B. Risks — worth one focused pass

**ALL FIXED 2026-07-10** (one pass; suite green, app verified live via the
bridge — sandbox isolation, 4-scene round-trip, no bridge errors). Notes on
the non-obvious ones: recorder replay now uses per-layer cursors firing
everything due up to `currentTime`; `registry.beginBatch()/endBatch()`
defer the snap rebuild only during `buildWorld` (synchronous semantics kept
everywhere else — specs rely on it); recreate recovers sfixtures by scan
when the ordering invariant is broken instead of dropping them. Original
findings kept below for reference.

- **Recorder replay**: events dispatch on exact float equality
  (`recorder.lua:69`), then the mouse joint is dereffed unguarded (`:200`) —
  a skipped `mousejoint-start` crashes replay. Fix: `>=` cursor dispatch
  (the unused `replayIndices` was meant for this) + nil-guard.
- **Script sandbox leaks between scenes**: `scriptEnv` in `script.lua:35-73`
  is one shared module-level table; un-`local` globals in one scene script
  persist into the next. Fix: fresh env per load in `loadAndRunScript`.
- **Silent sfixture loss**: `object-manager.lua:578` discards the `ok` flag
  from `hasFixturesWithUserDataAtBeginning`; when the invariant is violated,
  `offset == -1` and all sfixtures are silently dropped on recreate. Bail or
  repair instead.
- **Stale-body derefs** (recurring failure mode): `snap.checkForSnaps`
  (`snap.lua:113-130` — the TODO at `:120` already records the crash),
  `keep-angle.lua:52` (drives `ud.thing.body` instead of the iterated live
  registry body; also no `ud` nil-guard at `:34`), SET_OFFSET handlers
  (`input-manager.lua:78-92` — no destroyed-joint guard).
- **Pulley create is broken**: `joint-handlers.lua:129-146` mixes body-center
  coords into ground anchors and hardcodes `collideConnected = false`. Also
  clone-extract writes `groundAnchor1 = {x1,y1}` (array) while save writes
  `{x=,y=}` (keyed) — two shapes for the same field.
- **Revolute limits**: `joint-handlers.lua:50-53` calls
  `setLimits(lower, upper)` when *either* is set; one nil errors.
- **Load validation**: `io.lua:303,436` — JSON missing `bodies`/`joints`
  crashes on `ipairs(nil)`. Same class: `scene-loader.lua:35,101`
  unguarded `getFiledata(name):getString()` on a missing file.
- **O(N²) load**: `registry.lua:59-69` rebuilds snap fixtures on *every*
  register/unregister; batch once after `buildWorld`.
- **Clone shape-count assumption**: `io.lua:1288` indexes
  `newShapeList[i - offset]` — nil if polygon decomposition yields fewer
  shapes than the original.
- **Recording panel**: `recording-panel.lua:55-57` — checkpoint label table
  has 6 entries; a 7th checkpoint passes nil to `printf` and crashes. Also
  `:46` calls `sceneScript.onStart()` directly and unguarded (route through
  `script.call(SE.ON_START)`).
- **Torso sliders**: `body-editor.lua:289-314` read `thing.width2/…/height4`
  with no `or` fallback (trapezium path at `:352` has them); missing fields
  crash `sliderWithInput`.
- **Texture load in draw path**: `sfixture-editor.lua:397` bare
  `love.graphics.newImage` — missing file crashes at render; wrap in pcall
  like `mipo-editor.lua:126`.
- **Image cache ignores wrap settings on hit**:
  `box2d-draw-textured.lua:297-322` — first load without settings poisons the
  cache for later `repeat`/`mirroredrepeat` callers.

## C. One boring cleanup session

**ALL DONE 2026-07-10.** Luacheck: 0 warnings / 0 errors across 62 files.
Dead `if false` blocks, commented-out relics, stray prints, duplicate
requires, and dead data fields (`registry.groups`, `thing.fixture`,
`thing.zOffset`, the doubled joint button) all removed. Verified: suite
green, app boots and renders the mipo scene with zero bridge errors.
Original list kept below for reference.

- Luacheck back to 0 (61 warnings; run
  `luacheck src/ main.lua --std "lua51+love"`).
- Delete dead `if false` blocks: `editor-render.lua:60` (RESOURCE outline,
  would nil-deref if enabled), `joint-update.lua:231-262` (offset numpad +
  now-dead `updateOffsetA`). Delete the commented-out
  `createSimpleFixedTimestepRun` in `game-loop.lua:122-167` and the
  commented duplicate block in `object-manager.lua:297-335`.
- Leftover `print()`s: `game-loop.lua:80` (`'did panic!'` — fires every frame
  under sustained load, exactly when the app is struggling),
  `input-manager.lua:82,215`, `world-settings.lua:136` (every frame while
  profiling), `sfixture-editor.lua:1793`, `object-manager.lua:771,883`.
- Duplicate `require 'src.subtypes'` in `input-manager.lua:19,56`; hoist the
  stray requires at `:57-59`. Hoist the per-frame `require`s in
  `spine-mesh.lua:153-155`.
- Doubled button draw in `body-editor.lua:593-611` (same button rendered
  twice at identical coords — keep the `clicked/isHover` call).
- Doubled `if #bodyFixtures >= 1` nesting in `io.lua:940-941`.
- Dead data: `registry.groups` (`registry.lua:14`, never used, never reset),
  `thing.fixture` written on load but never read (`io.lua:421`),
  `thing.zOffset = 0` vestigial (`object-manager.lua:449` — real z lives on
  fixture `extra.zOffset`), `joints.lua:96` dead `or {x=0,y=0}` fallback
  (middle operand always truthy; also crashes if `data.p1` nil).
- ~~**Update `CLAUDE.md`** test/warning/file counts.~~ **DONE 2026-07-10.**

## D. Highest-leverage tests to add

**TOP FOUR DONE 2026-07-10** — new specs (41 tests, suite now 709):
`spine-mesh_spec.lua` (bind/evaluate round-trip incl. overshoot + bent
chains, multi-chain assignment/fallback, chain splitting),
`recorder_spec.lua` (record→replay round-trip, inexact-dt dispatch,
cursor no-refire, orphaned-update guard), `script-loading_spec.lua`
(exec-once, sandbox isolation, env injection, error paths),
`joints-recreate_spec.lua` (id/limit/offset/body continuity, overrides,
rope maxLength, destroyed-joint nil).

**ITEM 5 ALSO DONE 2026-07-10** — `snap_spec.lua` (snap within distance,
cooldowns, onlyConnectWhenInteracted, stale-body skip, force break +
cooldown, onSceneLoaded relink; note: break tests must stress with
opposing velocities — teleports are absorbed by the position solver and
report ~zero reaction force) and `pointerjoints_spec.lua` (press/release
lifecycle, sensor-only miss, dead-ref cleanup). Suite: 726.

In order of value:

1. **`spine-mesh`** — zero coverage, pure deterministic math
   (`bind`/`evaluate` round-trip, `closestOnPolyline`), trivial to test,
   easy to break silently.
2. **Recorder record→replay round-trip** — would have caught B's float
   dispatch bug.
3. **Scene-script load test** (`script.lua` / `scene-loader.lua`, zero
   coverage) — would have caught A2's double execution and B's sandbox leak.
4. **`joints.recreateJoint`** — the destroy-and-rebuild path DEEPER-ISSUES
   already flags as fragile; specs only exercise `createJoint`.
5. `snap.lua` core (`checkForSnaps`/`checkForJointBreaks`/`onSceneLoaded`) and
   `box2d-pointerjoints` lifecycle — the stale-ref failure mode's home turf.

## Perf notes (behind correctness for an editor)

**ALL DONE 2026-07-10** — debug draw caches `ud`/`shape` once per fixture;
`debugIds` allocates lazily; drawTexturedWorld's nine per-frame closures
(incl. the DQS/LBS deform ones, re-created per DRAWABLE) hoisted to module
scope and the drawables array is reused across frames (per-frame sort
kept — see DEEPER-ISSUES §3 for the stable-sort question); toolbar is a
flowing layout (`toolbarButton` cursor) instead of absolute x literals;
the three duplicated geometry blocks are now shared helpers:
`fixtures.makeMeshVertexMapper`, `findClosestNode` (input-manager),
`drawVertexHandles` (editor-render). Original notes below.

- `box2d-draw.lua:158-193` — up to 6 `fixture:getUserData()` FFI calls per
  fixture per frame in debug draw; cache once per fixture.
- `box2d-draw-textured.lua:1670-1912` — fresh drawables array + one table per
  drawable rebuilt and re-sorted every frame; helper closures re-created per
  `drawTexturedWorld` call. Hoist closures, keep a persistent dirty-flagged
  list. (Unstable-sort flicker already in DEEPER-ISSUES §3.)
- `box2d-draw.lua:122` — `debugIds` table allocated every call even with
  `showDebugIds` off.
- UI toolbar uses absolute x positions (`playtime-ui.lua:260-306`, x=20…970)
  — breaks at narrow windows; the right-side panels do it correctly with
  `w - panelWidth`.
- Duplicated geometry helpers worth extracting when next touched: MESHUSERT
  local→world transform (`input-manager.lua:708` ≈ `editor-render.lua:335`),
  nearest-node search (`input-manager.lua:107` ≈ `:604`), vertex-handle draw
  loop (`editor-render.lua:187` ≈ `:226`).

## Suggested order

1. C's CLAUDE.md fix + A1 (restore trust in suite + docs) — minutes.
2. A2–A7 — each is a small, contained fix.
3. B pass — one session, guards and validation.
4. C cleanup session.
5. D tests, top two at least.
