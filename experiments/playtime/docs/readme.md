# Playtime docs — index

These docs are written for **future Claude sessions** joining the project, not
for regular human reading. Arrive cold, find the right doc fast, don't
re-derive what's already known. The top-level `experiments/playtime/CLAUDE.md`
is the entry point; it points here.

Each entry below is annotated with *what it is* and *when to consult it*.

---

## Start here (active — currently driving work)

- **`APP-1-BATHHOUSE-PLAN.md`** — *canonical* plan for the first app (Mipo's
  Bathhouse). The status block at the top is the source of truth for "where am
  I?". Includes the spike verdict (DONE, **go**), build-phase steps with
  dev-day estimates, two fallback plans, asset list, out-of-scope guardrails,
  and cross-refs. **Read first.** (Note: an earlier session created a
  duplicate `BATHHOUSE-PLAN.md` — since deleted; this is the canonical doc.)
- **`STUDIO-STRATEGY.md`** — Mipolai-the-studio framing: studio (not company),
  format sequencing (video → book → YouTube), monetization (free + ~€2.99
  unlock), launch plan. The *why* behind Bathhouse and everything after.
- **`MIPOLAI-COMMON.md`** — the cross-app template: studio-shared engine
  primitives (camera, mipomi-lang speech, emotion layer, physical actions,
  tuning panel) and studio-shared mechanics (breeds, shelf+paywall, payoff
  beat, footage capture). Catalog with file pointers + gap analysis per item.
  Read this whenever a new app is being planned.
- **`MIPO-CODE-IDEA.md`** — Mipo breeds (BLOB / SPUD / TALL / TWIG / CHUNK /
  WIDE, more TBD) + a portable cross-app code format (`KIND-XXXXX-YYYYY`).
  The breed system is the studio-level shared IP mechanism. Being extended to
  10 breeds via per-kind `randomizeMipoConstrained` (see
  `src/character-manager.lua:599`).
- **`MIPO-EDITOR-TODO.md`** — gap analysis between playtime's mipo editor and
  the original `puppet-maker2`. Mostly complete; Phase 3 animation (eye blink
  / pupil look-at / mouth tween) is the remaining bucket.
- **`FACE-SYSTEM-PLAN.md`** — face animation system. Prerequisite for the
  Bathhouse reveal beat; per the Bathhouse status the face gap is closed.
- **`FLIP-MIPO-PLAN.md`** — Mipo flip/orientation handling.
- **`MARKETING.md`** — marketing notes.

## Studio / product context

- **`APPELFLAP-ISSUES.md`** — StoreKit 1 IAP fork (`appelflap`) known bugs.
  Non-blocking for paid apps without IAP, but the iOS bundle path runs through
  it.

## Architecture & reference (consult when touching the area)

- **`CLAUDE-BRIDGE.md`** — bridge HTTP API reference (summarised in
  `CLAUDE.md`).
- **`MODULE-ANALYSIS.md`** — module inventory + dependency map.
- **`BLIND-SPOTS.md`** — undocumented systems (`thing` structure, fixture
  subtypes, OMP pipeline).
- **`DEEPER-ISSUES.md`** — known bugs and architectural risks.
- **`DEEP-DIVE-NOTES.md`** — DNA/character + texture deformation + UI flow
  analysis.
- **`UV-BACKDROP-FRAGILITY.md`** — RESOURCE/backdrop/UV duct-tape seams. Read
  before touching that path.
- **`TEXTURE-DEFORMATION-RESEARCH.md`** — skeletal-mesh deformation research +
  integration plan.
- **`LIBRARY-AND-RESOURCES.md`** — vendor library references.
- **`TOOLING-SETUP.md`** — luacheck/busted setup, profiling.
- **`TOOLING-IDEAS.md`** — proposed observability tools (not yet implemented).
- **`FRICTION-AUDIT.md`** — friction audit notes.

## Older plans (likely complete or paused — kept for history)

Most of these were active Feb–April 2026 and the work has landed in code or
been superseded. Read only if you're touching the relevant subsystem; don't
treat them as current plans.

- `PLAN-OF-ATTACK.md` — earlier master plan with phase status.
- `AI-COLLABORATION-PLAN.md` — strategy + completed phases (per CLAUDE.md).
- `CODEBASE-CLEANUP.md`, `FILESIZE-ANALYSIS.md`
- `REBUILD-IN-PLAYTIME.md` — the rebuild-from-vector-sketch-into-playtime plan.
- Mesh / spine / steiner work (mostly landed):
  - `MESH-DEFORM-PLAN.md`
  - `MESHUSERT-SPINE-BIND-PLAN.md`
  - `SPINE-MESH-PLAN.md`
  - `STEINER-OWNERSHIP-PLAN.md`
  - `SCENEGRAPH-PHYSICS-ROOT.md`
- `CLAYMATION-SHADER-PLAN.md`
- `WEB-EXPORT-LOVEJS.md`

## Subfolders

- **`done/`** — finished work preserved for history (`PROJECT.md`,
  `BUSINESS-STRATEGY-PRE-PIVOT.md`, `TODO-BRIDGE.md`, `TODO-MAGIC-STRINGS.md`).
- **`knut/`** — Knut-specific notes. The Knut mini-game commission fizzled
  (memory: `project_knut_minigame.md`); the rigging pipeline is still useful
  reference. Contains `BLOCKOUTS.md`, `SCENES.md`, `KNUT-TOOLKIT-TODO.md`.
- **`notes/`** — research notes and drafts (IK research, marketing-question
  draft, level ideas).

## Conventions worth knowing

- The `MANIFESTO.md` (project root, not docs/) sets the studio rules
  (Sago Rule: one verb, 4–6 weeks, no "and also"). Cited from
  `APP-1-BATHHOUSE-PLAN.md`.
- Bathhouse plan's `## Current status` block is updated each working session.
  When picking up a session, read it first.
- AI memory lives at `~/.claude/projects/.../memory/MEMORY.md` (linked into
  each session's context). Useful project facts are there; don't re-derive
  what's already memorised.
