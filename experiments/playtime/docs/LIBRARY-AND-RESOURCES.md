# Library & Resource Concept — Plan

The current "backdrop" system conflates three roles into one type: reference image for tracing, scene background for decoration, texture source for UV mapping. Cleaning this up unblocks a bigger idea: a proper **Library** of reusable assets (textures, character rigs, props, behaviors), in the spirit of Flash's Library panel. Scenes become compositions of library references instead of blobs of raw data, and building new scenes gets dramatically more pleasant.

This doc is the plan; the sibling doc `UV-BACKDROP-FRAGILITY.md` is the catalog of current symptoms.

## Why this matters

- **Authoring cost compounds.** Every new character or scene redraws/rebinds/rerigs from scratch today. With a library, a Knut rig gets built once and dropped wherever.
- **UV mapping is bizarre.** Placing a texture image into the physical world and aligning your mesh over it is a workaround, not a model. It should be a name-based reference with a projection choice.
- **Backdrop fragility has 7 documented issues.** Most of them disappear under a split-and-rename refactor rather than being patched in place.
- **Downstream tasks benefit.** Both `REBUILD-IN-PLAYTIME.md` ports (puppet-showcase and downhill bike) would be much cleaner if a library of saved characters/props already existed.

## Mental model — Flash Library

Flash had a typed, named, reusable asset store:
- Stable ID per symbol (name).
- Typed (MovieClip, Graphic, Button, Bitmap).
- Intrinsic data (artwork, timeline, nested symbols).
- **Instances** on the stage were just `library_id + transform` — lightweight references.
- Edit the master, instances update (with caveats).
- Symbols nest.
- Libraries sharable across files.

Playtime should lean on this model. Not literally — we don't need timelines — but the shape of it: browsable typed assets, cheap instancing, stable identity.

## Phase 1 — Split the backdrop concept

The prerequisite for everything else. Three roles currently collapsed into `state.backdrops[]`:

| Role today | Becomes | Lives in | Visible in published game |
|---|---|---|---|
| Reference image for tracing | **Reference image** | scene (per scene) | no |
| UV source for meshes | **Texture asset** | library | no (consumed by meshes) |
| Scene decoration | **Scene background** | scene (per scene) | yes |

### Concrete changes

1. **Add a new `textures` library** folder and a small loader. Each texture asset has a stable ID, URL, intrinsic size, and optional default projection.
2. **RESOURCE sfixture stops referencing `selectedBGIndex` / `selectedBGURL`**; instead it references a texture asset by ID. (During migration, a URL → texture-asset resolver makes old scenes load.)
3. **Reference images become their own subtype** (not a RESOURCE mapper) with toggle-visible, dimmable opacity, locked position. Artist-facing tool only; not rendered in shipped game.
4. **Scene backgrounds** keep the existing per-scene semantics (we're mostly renaming), and later can gain parallax layers (Phase 6).
5. **UV capture** becomes a scoped operation: pick a texture asset, pick a projection mode:
   - `fit-bbox` — mesh bounding box → texture 0..1.
   - `manual-align` — temporarily place the texture asset in the world, align, capture UVs, unplace it.
   - `from-reference-image` — the legacy workflow, kept as an opt-in alignment tool rather than the default.

### Wins from Phase 1 alone

- Fragility #1 (index coupling) — gone: reference by ID.
- #2 (pre-persistence stale defaults) — gone: no shared session-global.
- #3 (UV pin to backdrop position) — gone: capture is explicit, not per-frame.
- #4 (the xy-confused lookup loop) — gone: UVs are vertex-indexed by construction.
- #5 (label uniqueness) — mostly gone: label collisions collapse when the linkage is ID-based.
- #6 (UV count coupled to vertex count) — unchanged, needs separate fix (invalidate on polygon edit).
- #7 (lazy image loading) — gone: texture assets preload at scene load.

## Phase 2 — Library foundation

A folder, a loader, and a UI panel. Start with textures only; extend.

### Storage layout (strawman)

```
playtime/
  library/
    textures/
      knut-torso.png
      knut-torso.meta.json       # { id, name, defaultProjection, anchor, tags }
      cliff-rock.png
    characters/
      knut.rig.json              # bodies + joints + binds, stable ID at top
      mipo-default.rig.json
    props/
      bike.prop.json
      swing.prop.json
    behaviors/
      follow-cam.lua             # scene-script snippet with documented params
    scenes/
      mountain-starter.scene.json   # partial scene fragments, drop-inable
```

Each library item is a self-contained file with a **stable ID** (UUID or slug) separate from its filename. Scenes reference items by ID.

### Minimum viable library

- A loader that walks `library/textures/` at startup and indexes by ID.
- A `lib.library:get(id)` API returning the asset data.
- A migration that resolves existing `selectedBGURL` entries against the library on scene load.
- No UI yet — references work from saved scenes only.

At this point RESOURCE sfixtures are clean but the UX is unchanged (no library panel).

## Phase 3 — Insertion UX

The library panel, drag-drop, keyboard shortcut.

- **Panel** — tabs by type (textures, characters, props, behaviors, scenes). Thumbnail grid. Search box.
- **Insert** — double-click or drag into the world. For characters/props: instantiate at cursor. For textures: open texture picker on the currently-selected RESOURCE.
- **Keyboard** — `L` to toggle, arrows + enter to insert.
- **"Show references"** — on hover, highlight scenes (later: show count; later still: list).

## Phase 4 — Save-to-library

The reverse direction: turn current selection into a library item.

- Reuses `src/io.lua:cloneSelection` machinery (already knows how to snapshot bodies + joints with cross-body joint remapping).
- Dialog: pick type (character/prop/scene fragment), name it, optional tags.
- Writes to `library/<type>/<name>.<ext>` with a generated stable ID.
- Original scene continues to have the live instance; future scenes can drop the saved one.

## Phase 5 — Instancing model

The tricky design decision. Options:

**A. Template copy** — inserting from the library *copies* data into the scene. Later library edits don't propagate. Safest; simplest.

**B. True Flash-style instancing** — inserts a reference; editing the library master updates all scenes. Powerful but dangerous (tweak drift, silent breakage).

**C. Hybrid (recommended)** — template copy by default, but each instance remembers `sourceId + sourceVersion`. A later opt-in action "update this instance to latest" per-instance makes propagation explicit.

Start with A. Add C when it becomes obviously needed (e.g. you're maintaining 20 scenes that share a Knut rig and want to push a fix everywhere).

## Phase 6 — Background parallax

Orthogonal to library but worth noting: once scene backgrounds are their own thing, adding layers + parallax scroll is a small feature rather than a format negotiation. Relevant for the downhill bike port and any side-scrolling Knut scene.

## Library item types, in priority order

1. **Textures** — enables Phase 1. Highest payoff.
2. **Character rigs** — bodies + joints + binds + textures. "Drop a Knut into this scene."
3. **Props** — bike, ladder, swing, tree. Pre-tuned physics.
4. **Joint-chain presets** — skeleton topologies without art (arm, leg, tail, tentacle).
5. **Behavior snippets** — scene-script pieces (follow-cam, parallax, weather).
6. **Scene fragments** — half-built set pieces (mountain-starter, house-interior).
7. **Animation clips** — from the recorder, replayable.

## Hard questions to settle

- **Where do library files live in a shipped build?** Two directories probably: a core library that ships with the tool (read-only for end users) and a per-project library the user can edit. Merge at load; user items shadow core items.
- **Missing-reference behaviour.** Placeholder sprite with a visible warning (like Flash's pink box), NOT a silent fail or a crash.
- **Versioning.** Stable IDs (UUID or slug) decoupled from filenames. Renaming a file doesn't break scenes.
- **Rig granularity.** "Knut rig" — skeleton only? skinned? full character with default behaviors? Probably three tiers with explicit names (`knut.skeleton`, `knut.skinned`, `knut.full`).
- **Per-scene vs global overrides.** If an instance gets tweaked in a scene (e.g. "this Knut is smaller"), is that allowed? (Yes.) Does it survive a library update? (Under hybrid model: yes, with optional "reset from source.")

## Suggested implementation order

1. **Backdrop split** (Phase 1) — the unblocker. Fixes 5 of the 7 fragilities in `UV-BACKDROP-FRAGILITY.md`.
2. **Texture library** (Phase 2) — minimum wiring, no UI. Proves the reference-by-ID flow.
3. **Migration path for existing scenes** — URL-based resolve to new texture IDs. `scripts/*.playtime.json` continues to open.
4. **Library panel UI** (Phase 3) for textures.
5. **Save-to-library** (Phase 4) for textures → characters → props. In that order.
6. **Instancing model** (Phase 5) — Option A to start.
7. **Extend to other types** (joint-chains, behaviors, scene fragments).
8. **True instance/master propagation** (Phase 5 → C) if real need emerges.
9. **Parallax for scene backgrounds** (Phase 6) — optional, triggered by downhill bike port.

## What stays out of scope

- Real-time collaboration on library items.
- Network-shared libraries.
- Symbol timelines (Flash-specific, not useful here).
- A full asset pipeline with import dialogs, format conversion, etc. — start with "drop files into `library/`, loader picks them up."

## Cross-references

- `UV-BACKDROP-FRAGILITY.md` — the symptom catalog Phase 1 fixes.
- `REBUILD-IN-PLAYTIME.md` — puppet-showcase and downhill bike both benefit from a working library.
- `MIPO-EDITOR-TODO.md` — Mipo characters are the most obvious first library-of-characters.
- `DEEPER-ISSUES.md` — the "backdrop conceptual conflation" note is the seed for this plan.
