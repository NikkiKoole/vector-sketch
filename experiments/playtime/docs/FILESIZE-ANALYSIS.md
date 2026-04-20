# Save-File Size Analysis

Scene `.playtime.json` files have grown large (hoop.playtime.json = 826 KB). Most of the bloat is in one field; a handful of cheap fixes could drop the file ~60%.

## Measurement

Sample: `scripts/hoop.playtime.json` — 826,240 bytes, 7 bodies, 43 fixtures, multiple MESHUSERT sfixtures with bind data.

Top field-size contributors (as % of total file size):

```
46.1%  sfixture.extra.influences   (381 KB)
 2.3%  sfixture.extra.uvs          ( 19 KB)
 2.3%  sfixture.extra.bindVerts    ( 19 KB)
 2.1%  sfixture.extra.meshVertices ( 17 KB)
 1.7%  sfixture.extra.triangles    ( 14 KB)
 0.4%  sfixture.extra.triangleBones
 0.3%  fixture.points
 0.2%  body.vertices
```

Measurement script (ad-hoc, for reproduction): walk `data.bodies[].fixtures[].userData.extra.*`, `json.dumps` each field, sum by key. See conversation log for the one-liner.

## Why `influences` is 46% of the file

Each vertex has a list of bone influences. Each influence entry looks like:

```json
{
  "w": 0.5,
  "nodeType": "anchor",
  "nodeId": "1MasSO",
  "nodeIndex": 3,
  "offx": 5.578,
  "offy": 91.511,
  "dx": -86.814,
  "dy": -135.966,
  "dist": 161.318,
  "bindAngle": 0.3665,
  "side": "B"     // only on joint type
}
```

One entry ≈ 700 bytes serialized. Multiplied by per-vertex × per-bone × per-fixture, the bulk accumulates fast.

Specific bloat sources in this structure:

1. **Number precision.** Values like `91.511001586914` have 13 significant digits. For rigging at ~1000px scale, 4 decimal places is sub-pixel. ~8 chars saved per float.
2. **Denormalized bone metadata.** `nodeType`, `nodeId`, `nodeIndex`, `bindAngle` are the same for every influence pointing at the same bone. Should live in a per-mesh bone table, referenced by index in each influence entry.
3. **Derived fields stored.** `dist = sqrt(dx² + dy²)` is pure overhead; recompute on load. `offx`/`offy` may be a rotated version of `dx`/`dy` and similarly derivable.
4. **Zero-weight entries kept.** Some `w: 0` influences persist in saves. Prune at serialise time.
5. **Verbose keys.** `nodeType` / `nodeIndex` / `bindAngle` could be `nt` / `ni` / `ba` without losing any semantics.

## Estimated savings

| Change | Effort | Risk | Estimated saving |
|--------|--------|------|------------------|
| Round floats to 4 decimals on save | tiny (one serialiser patch) | low | ~20% of total file |
| Drop derived fields (`dist`, possibly `offx`/`offy`) | small (ensure recompute on load) | low/med | ~100 KB |
| Normalize bone metadata out of per-influence entries | medium (format change, load path) | med | ~150 KB |
| Drop zero-weight entries | tiny | low | ~10–30 KB |
| Shorter keys | tiny (find/replace in serialiser + loader) | low | ~5–10% |

Cumulative: `hoop.playtime.json` 826 KB → ~350 KB without changing any runtime behaviour.

## Secondary fields

- **`meshVertices` (17 KB).** Only needed in CDT mode (includes Steiner points). The recent `src/cdt.lua:computeResourceMesh` change sets it to `nil` for `basic` and `strip` modes. Verify on re-save of existing scenes — legacy data may still carry it.
- **`bindVerts` (19 KB).** Legitimate per-vert bind-pose positions. Precision reduction still applies.
- **`uvs` (19 KB).** Per-vert floats. Precision reduction applies.
- **`triangles` (14 KB).** Small integers, already tight. Nothing to do.

## Where to make changes

Serialization lives in `src/io.lua`. Look for the `save` / `toJSON` path and the field-by-field copy that builds the per-body / per-fixture table passed to `dkjson.encode`. Number precision can be clamped at that boundary, either by overriding how `dkjson` formats floats or by pre-rounding every number before encoding.

Loader is the same file, the `load` / `fromJSON` path. Any field rename (`nt` ↔ `nodeType`) needs a compat shim for old saves — read either key, write only the new one.

## Recommended order

1. **Float precision on save.** Smallest change, biggest compound win. Touches one function. No data-shape change, so loader compat is automatic.
2. **Drop `dist` field on save, recompute on load.** Trivially safe.
3. **Prune zero-weight influences on save.** Just a filter in the serialiser.
4. **Bone-table normalization.** Real format change. Do last, with a compat shim in the loader.
