# Steiner-Point Ownership Refactor — Plan

Path B from `CODEBASE-CLEANUP.md` item #8-ish. Move authored Steiner points from `ud.extra.extraSteiner` on RESOURCE sfixtures (authoring-world coords) to `thing.extraSteiner` on the body (body-local coords). Make the body-level overlay POC actually drive downstream triangulation.

## Current state

- Body-level POC shipped (commit `f29cb96c`). User can click-to-place Steiners on any polygon body via the `PLACE_STEINER` mode + body-editor button. Data lives at `thing.extraSteiner` in **body-local** coords.
- Legacy location still in use: `ud.extra.extraSteiner` on RESOURCE sfixtures (**authoring-world** coords), written by the MESHUSERT "split selected" button, read by `cdt.computeResourceMesh`. Old saved scenes carry their data there.
- Overlay in `editor-render.lua:renderSteinerPOC` is preview-only — nothing downstream reads the body-level Steiners yet. Collision fixtures, fill draw, RESOURCE triangulation all ignore them.

## The frame-of-reference issue (critical)

Three coordinate frames live alongside each other in a polygon body:

| Frame | Description | Used by |
|---|---|---|
| authoring-world | Absolute coords at body-creation time | `thing.vertices`, old `ud.extra.extraSteiner` |
| body-local | Relative to body origin + rotation, via `body:getLocalPoint()` | POC's `thing.extraSteiner`, Box2D collision shapes (modulo centroid) |
| polygon-centroid-relative | `vert - centroid(thing.vertices)` | Box2D collision shape points, `box2d-draw-textured.lua` after `makePolygonRelativeToCenter` |

For bodies that have never moved since creation, **body-local ≈ polygon-centroid-relative** (body pos = centroid at creation). For moved bodies they diverge.

**Decision:** all authored Steiner data lives in **body-local** on `thing.extraSteiner`. Matches the POC, matches how Box2D fixtures were conceptually created, and follows the body under motion naturally via `body:getWorldPoint`.

Migration path: authoring-world → body-local = subtract `centroid(thing.vertices)`. Only accurate for un-moved bodies, which is the state every saved scene is in at load time. Good enough.

## Phase 1 — Ownership move + RESOURCE integration

Goal: RESOURCE triangulation reads from `thing.extraSteiner`. Old scenes load with their data migrated. MESHUSERT split-selected writes to the new location.

### TDD tests (add to `spec/io_spec.lua`)
- `migrateExtraSteinerToBody(data)` in `io._test`:
  - moves authoring-world extraSteiner to body-local on the thing
  - clears the old location on the RESOURCE after migrating
  - concatenates lists across multiple RESOURCEs on the same body
  - idempotent
  - leaves existing `thing.extraSteiner` alone when no RESOURCE has old data
  - no-op on nil / empty / bodies without vertices

### Code changes

1. **`src/io.lua`** — add local `migrateExtraSteinerToBody(saveData)`. Walk `saveData.bodies[].fixtures[]`; for each RESOURCE with `extra.extraSteiner`, subtract `centroid(body.vertices)` and append to `body.extraSteiner`. Clear the RESOURCE's copy. Call at the top of `lib.load`, right after `json.decode` + version check. Export via `lib._test`.
2. **`src/cdt.lua:computeResourceMesh`** — read `bodyUD.thing.extraSteiner` instead of `ud.extra.extraSteiner`. Convert polygon verts to body-local (`origVerts - centroid`), pass alongside body-local Steiners to `triangulatePolyWithSteiner`. Fix UV calculation to use body-local→world (not `vert - centX` → world; now meshVerts is already body-local).
3. **`src/ui/sfixture-editor.lua`** — MESHUSERT "split selected" writes body-local to `thing.extraSteiner`. Convert triangle centroid via `body:getLocalPoint` before appending. "Clear splits" + footer "clear splits (N)" buttons clear `thing.extraSteiner` instead of `ud.extra.extraSteiner`.
4. **`src/editor-render.lua:renderSteinerPOC`** — still works; no change needed (it already reads `thing.extraSteiner` in body-local).

### Verification
- Full spec suite green.
- Load an old scene with `ud.extra.extraSteiner` — Steiners end up on `thing.extraSteiner`; re-save is clean.
- Click "split selected" in MESHUSERT panel — new Steiner appears on the body's overlay dot list (body-editor view also shows it).
- MESHUSERT renders with the expected triangulation (visually unchanged from today).

### Risks
- Coord-frame mistake on migration (e.g. forgetting centroid offset) — caught by the numeric test.
- `meshVertices` frame change — `box2d-draw-textured.lua` already `makePolygonRelativeToCenter`s them, so idempotent. Spot-check one real scene to be sure.
- `ud.extra.meshVertices` stored in old saves is authoring-world; after re-save it'll be body-local. Box2D draw path centers whatever it receives, so both work. No loader migration needed for `meshVertices` itself.

## Phase 2 — MESHUSERT panel UX parity

Goal: user doesn't have to navigate to the body panel to place Steiners while working on a MESHUSERT.

### Changes
- In `src/ui/sfixture-editor.lua` MESHUSERT branch, add the same **place steiner** toggle + **clear steiner (N)** button that body-editor has. It operates on the MESHUSERT's body (`fixture:getBody()`), writing to `body:getUserData().thing.extraSteiner`.
- Same `modes.PLACE_STEINER` mode. The existing input handler already looks up the selected body via `state.selection.selectedObj`; need to either (a) set `selectedObj` when a MESHUSERT is selected, or (b) teach input-manager to fall back to `selectedSFixture:getBody():getUserData().thing`.
  - (a) is surgical but may collide with selection semantics.
  - (b) is cleaner: `local thing = state.selection.selectedObj or (state.selection.selectedSFixture and state.selection.selectedSFixture:getBody():getUserData().thing)`. Prefer (b).

### Verification
- Toggle **place steiner** from MESHUSERT panel → click in world → new Steiner appears in overlay, body-editor's "clear steiner (N)" count increments.
- Same Steiner visible from both panels (one source of truth).

## Phase 3 — Body fill-draw honors `thing.extraSteiner`

Goal: the visible body fill reflects the authored triangulation. Solves the fan artifact the user saw on the torso screenshot.

### Approach
- In `src/physics/box2d-draw.lua` body loop: before iterating fixtures, check if body has `thing.extraSteiner` non-empty.
- If so:
  - Compute CDT triangulation of `thing.vertices` (converted to body-local) + `thing.extraSteiner` once.
  - Fill each triangle in body-local, transformed via body world transform. Body color as fill.
  - Skip the per-fixture polygon fill below (set a `drewCDTOverride = true` flag).
  - Outline: draw the polygon's OUTER boundary (thing.vertices) as one line loop, not per-triangle edges. Kills the fan-line artifact.
- Collision fixtures stay untouched. Only the render changes.

### Decision needed
- **Show triangulation lines or not?** Two options:
  - Solid: single-color fill, one outline. Clean look, hides triangulation.
  - Debug: faint triangle-edge lines on top. Lets artist see what they authored without opening another panel.
  - Probably: hide by default, toggleable via `state.world.drawTriangulation` or similar.

### Risks
- CDT call per body per frame — cache the result on `thing._cachedTriangulation` keyed by a `thing.extraSteinerDirty` flag. Invalidate on Steiner add/remove, polygon edit, or body re-creation.
- Non-custom shapes (rectangle, circle, etc.) — just skip the override; they don't have meaningful `thing.vertices` for CDT. Gate on `thing.shapeType == 'custom'` (and maybe `'ribbon'`? Ribbon already has a nice strip topology — probably skip the override there too).

### Verification
- Add a Steiner to a CUSTOM polygon body → body fill visibly redraws with more triangles.
- No performance regression on scenes with no Steiners (guarded by non-empty check).
- Remove all Steiners → body falls back to Box2D fixture fill as before.

## Execution order

1. **Phase 1 first.** It's the core ownership move. Without it, Phase 2 and 3 don't have a single source of truth to read from.
2. **Phase 2 second.** Small UX win, low risk. Validates that the body-level data works from multiple authoring surfaces.
3. **Phase 3 last.** Biggest visual change, touches the most-trafficked draw path. Defer until the data pipeline is solid.

Each phase is one commit. TDD where it makes sense (Phase 1 migration especially).

## Open decisions

- **Polygon-edit invalidation.** If the user drags a vertex of the polygon, existing Steiners may end up outside. Options: drop Steiners when polygon changes (simplest), or clamp/preserve them (more work). Simplest is fine — the user can re-add them. Decide before Phase 1 if we want the drop to happen automatically.
- **CDT mode integration.** Today `computeResourceMesh` picks from `basic` / `cdt` / `refined` / `strip` modes. Steiners are only honored in `cdt` and `refined`. If a user places Steiners while the mode is `basic`, should we auto-upgrade to `cdt`, warn, or silently ignore? Probably auto-upgrade — matches the user's intent.
- **Save-size impact.** Each Steiner adds 2 floats to `thing.extraSteiner`. With `roundFloats` at save time, ~20 bytes per point. Negligible for tens of Steiners per body.

## What this doesn't do

- Doesn't rebuild Box2D collision fixtures to match the authored triangulation. Collision stays as-is (the current fan-of-triangles from creation time). If we ever want collision-accurate-to-visual, that's Phase 4+.
- Doesn't introduce constrained edges / edge-flip authoring (options C/D from the earlier brainstorm). Those remain future work.
- Doesn't touch UVUSERT, DECAL, or other subtypes. They don't use Steiners.

## Files that will change

- `src/io.lua` — migration function + call site in `lib.load`
- `src/cdt.lua` — `computeResourceMesh` reads body-local Steiners
- `src/ui/sfixture-editor.lua` — "split selected" + "clear splits" write to body; new "place steiner" button on MESHUSERT panel
- `src/input-manager.lua` — fallback to selected-sfixture's body (Phase 2)
- `src/physics/box2d-draw.lua` — CDT-fill override (Phase 3)
- `spec/io_spec.lua` — migration tests (Phase 1)

## Rollback plan

Each phase is self-contained; can be reverted individually. Phase 1 is the only one with a data-format implication — if rolled back after scenes have been re-saved in the new format, old RESOURCE Steiners won't come back (they got cleared by migration). Mitigation: before pushing Phase 1, save a test scene through the old code path so we have a known-good fallback file.
