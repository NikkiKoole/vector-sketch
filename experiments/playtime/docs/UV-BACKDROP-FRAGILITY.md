# Backdrops-as-UV-textures: fragility notes

Briefing compiled for future agents working with the RESOURCE/MESHUSERT/UVUSERT
+ backdrop system. Read this before touching the UV/texture path for meshes.

## Context

In `experiments/playtime/`, the RESOURCE sfixture subtype is used as a "mapper"
that pairs a physics-body polygon with a texture source for UV-mapped mesh
rendering. The texture source is a **backdrop** — a sprite in the
session-global `state.backdrops[]` array. The reference is stored as an array
index (`ud.extra.selectedBGIndex`), not a stable identifier.

The concept is sound; the implementation has several duct-tape seams.
Recent patches made it more robust (URL fallback, nil guards), but core
architectural issues remain and are summarised here.

## How the system is wired

Three sfixture subtypes interact:

1. **RESOURCE** (the "mapper") — stores `selectedBGIndex`, `uvs[]`, and a label string
2. **MESHUSERT** drawables — consume a RESOURCE mapper by matching label
3. **UVUSERT** drawables — same, different code path

### Rendering path — `src/physics/box2d-draw-textured.lua:1500-1712`

- Find the RESOURCE sfixture with matching label via linear scan over `registry.sfixtures`
- Pull `data.selectedBGIndex`, look it up in `state.backdrops`, grab `.image`
- Call `mesh:setTexture(bd.image)`

### UV computation — `src/ui/sfixture-editor.lua:929-987`

- UVs are recomputed every UI frame while a RESOURCE sfixture is selected
- Formula: `u = (vx - bd.x) / bd.w`, projecting polygon vertices onto the backdrop's world-space rectangle
- Result stored in `ud.extra.uvs` (array of `{u1,v1,u2,v2,...}` with 2× polygon vertex count)

## Fragilities

### 1. Index coupling to global array

`selectedBGIndex: N` binds to whatever is at position N in `state.backdrops`.
Any insertion/deletion/reorder before N silently remaps the reference to a
different image. There is no stable identity.

**Partial mitigation (done):** `selectedBGURL` is stored alongside
`selectedBGIndex` on save (`src/io.lua` `gatherSaveData`) and a URL → index
resolve on load (`src/io.lua` `buildWorld`, after `subtypes.migrate`). A scene
saved today re-resolves its mapper correctly even if the backdrop array order
changes across sessions. But the in-memory identity during a session is still
index-based.

### 2. Pre-persistence scenes rely on stale defaults

Prior to recent changes, `state.lua:112-131` hardcoded 3 default backdrops
(eye1, eye2, Kaptein-Knut) loaded on every app start. Scenes in `scripts/` —
`beginmesh`, `resources`, `bettert`, `test`, `uvs` — reference these by index
(selectedBGIndex: 0-3). The defaults were cleared to `{}`.

**Consequence:** those legacy scenes now open with no backdrops →
`state.backdrops[0]` is nil. Mitigated by nil guards at
`src/physics/box2d-draw-textured.lua:1606, 1705` — the mesh renders untextured
instead of crashing. Textures stay gone until the scenes are re-saved with
`selectedBGURL`, which only happens on explicit open-and-save.

### 3. UV normalization pins to backdrop position at compute time

`src/ui/sfixture-editor.lua:974`: `u = (vx - rect.x) / rect.w`. Recomputed every
frame while the RESOURCE is UI-selected. If you select a RESOURCE, move its
backdrop, deselect → UVs are now stale and will map to the wrong image region
on next render. There's no invalidation signal or recompute hook tied to
backdrop mutation.

### 4. The UV lookup loop is buggy

`src/physics/box2d-draw-textured.lua:1584-1592`:

```lua
for l = 1, #verts do
    if math.abs(vx - verts[l]) < 0.001 then u = data.uvs[l] end
    if math.abs(vy - verts[l]) < 0.001 then v = data.uvs[l] end
end
```

- `verts[]` is interleaved `{x1,y1,x2,y2,...}`, but the comparison treats
  every slot as a potential match for both `vx` and `vy`
- No `break` — last match wins
- A polygon with an x-coord equal to some y-coord elsewhere gets its UV wires
  crossed
- Works on scenes that have been tuned around it (symmetric coord collisions
  avoided by accident), but it's "accidental correctness"

Same buggy loop is duplicated at lines 1680-1688 in the UVUSERT path.

### 5. Label-based mapper lookup has no uniqueness guarantee

`src/physics/box2d-draw-textured.lua:1497-1506, 1624-1630`: linear scan for
any RESOURCE sfixture with a matching label — if two RESOURCEs share a label,
whichever `pairs()` yields first wins. Unordered.

### 6. UVs array length coupled to polygon vertex count

`uvs` has 2× polygon vertex count. If the user edits the polygon
(add/remove vertices), the existing UV array becomes misaligned. No
validation.

### 7. Backdrop images are lazy-loaded in the draw loop

`main.lua:346-350` creates `love.graphics.newImage(b.url)` on first draw. If
the URL is missing or invalid, the draw crashes at image-creation time, not
scene-load time — so scene "load success" doesn't mean "scene will render."

## What's NOT broken

- The overall concept (polygon + UVs + texture source) is sound.
- The save/load roundtrip is URL-based and resilient to backdrop reordering
  across sessions (for scenes saved with the URL-backup changes).
- Rendering nil-guards prevent crashes on missing backdrops.

## Recommended hardening

In rough priority order:

1. **Replace the UV lookup loop** (fragility #4) with a vertex-index-based
   mapping — UVs would be keyed by vertex index, not by numeric-equality
   search. Bug-fix, not just hardening.
2. **Invalidate UVs on backdrop move** (fragility #3) — backdrop edits should
   dirty any RESOURCE sfixtures that reference them.
3. **Replace `selectedBGIndex` with `selectedBGURL`** (fragility #1) in the hot
   path — don't maintain two keys; the URL is the stable one. Keep index as a
   cached lookup.
4. **Deduplicate the label lookup** (fragility #5) — enforce uniqueness at
   creation time, or use an id/uuid instead of a label.
5. **Pre-load backdrop images at scene load** (fragility #7) and surface errors
   rather than deferring to first draw.
6. Consider: is `state.backdrops` the right home? It's session-global, but the
   thing referencing it (RESOURCE sfixture) is per-scene. A per-scene backdrop
   list would eliminate cross-scene pollution entirely. The URL-backup
   persistence patch moved in that direction (scenes replace `state.backdrops`
   wholesale on load) but didn't finish the refactor.

## Operational rules (if not yet hardened)

For anyone actively rigging in the current system:

- **Pick a unique label per character** — label collisions silently win by
  `pairs()` order
- **Don't move the backdrop after UVs are computed** — UVs are stale until you
  re-select the RESOURCE
- **Don't edit the polygon after binding** — adding/removing vertices
  invalidates both UVs (coupled to vertex count) and MESHUSERT influences
  (indexed by vertex)
- **Save early** — the URL backup only helps on scenes that have been saved
  at least once with the current IO code

## Files to read first

- `src/physics/box2d-draw-textured.lua:1480-1712` — render path for MESHUSERT + UVUSERT
- `src/ui/sfixture-editor.lua:929-1005` — RESOURCE editor, UV compute
- `src/io.lua:105-225` (`buildWorld`), `~436-470` (`gatherSaveData`),
  `574-622` (fixture userData save), around the `subtypes.migrate` call — URL backup logic
- `main.lua:311-400` — draw loop, backdrop rendering, pre-world / post-world passes
- `scripts/uvs.playtime.json`, `scripts/resources.playtime.json`,
  `scripts/beginmesh.playtime.json` — real-world example scenes using the system
