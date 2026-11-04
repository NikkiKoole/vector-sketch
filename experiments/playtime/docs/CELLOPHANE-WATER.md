# Cellophane water — crumpled plastic wrap as the sea

status: parked — "feels a bit Toy Story 1, synthesized": Nikki will work more with hand-drawn assets, shaders only for moments (tried 2026-11-04: one flat-shaded crumpled sheet, then overlapping see-through shards, scene `cellophane`)

Take two after the materials spike (MATERIALS.md, tried 2026-11-04: the Voronoi cellophane looked
like broken glass). The look to get is in Nikki's mood pictures: `docs/inspiration/ai-materials/`
12 (the boat on a cellophane sea), 14 (the island's blue wrap), 07 (the jar: clear wrap over a scene).

## What the pictures do, and what the spike got wrong

| in the pictures | the spike |
|---|---|
| **Rows of crests**, back to front, the boat sits *between* rows | one flat band |
| **Sharp peaks** along the top edge: the wrap folds up into points, jagged | a smooth sine |
| **Long thin facets** (triangles, slivers) along the folds, many sizes | round cells, all one size: stained glass |
| **Bright thin lines only on some fold ridges**, the ones facing the light | white on every cell border |
| **The top edge is pale/white**: thin plastic seen edge-on | no rim |
| Most facets **see-through tinted**, a few **lit and opaque** | everything half see-through |
| **Further rows paler and greyer**, front rows saturated (12); deep navy with cyan glints (14) | one colour ramp |
| **Clear wrap** (07): long thin white wrinkle streaks, everything behind shows almost fully | — |

So it's a crumpled *sheet*, not a pattern: geometry with folds, lit facet by facet.

## The approach: a real crumpled sheet, as a mesh

- **Each crest row is a triangle mesh**, a strip a few facets high. Its vertices are jittered,
  stretched wide (facets longer than tall, slanted), and each gets a random height out of the
  sheet: that's the crumple. The top row of vertices pokes up into peaks.
- **Flat shading**: every triangle has its own vertices, so it gets one colour from its own normal
  (the cross product of its three corners, with the heights). Facets come out of the geometry, and
  folds are where neighbouring triangles turn away from each other.
- **Fold lines**: the edges between two triangles whose normals differ a lot, and that face the
  light, drawn as thin bright lines (some, not all). The top edge gets a pale rim line.
- **Colour and see-through per facet**: tint from a small palette (pale cyan, cyan, blue, navy) by
  how it faces; alpha low for most, high for the lit ones. A palette per scene: "light" (12) or
  "deep" (14).
- **Layers**: 3–5 rows; back rows paler, smaller, slower; the front row in front of the Mipos,
  the others behind, so a boat or a Mipo sits in the sea, not on top of it.
- **Movement**: the heights drift slowly (noise over time), so facets catch and lose the light, the
  way wrap glints when it's touched. The rows bob on the sea's wave columns (`sea.playtime.lua`
  `surfaceAt`), so splashes and floating still work.
- **Cheap**: a few hundred triangles with vertex colours, rebuilt each frame (a stream mesh), a
  plain shader at most for the glint. Good on the phone; nothing per pixel like the sea's water.

## Steps

- [ ] **CW1. One crumpled row, standing still.** A flat-shaded mesh strip with peaks, in a test
      scene, next to picture 12 at the same framing (a screenshot side by side). Tune facet size,
      stretch, height jitter until it reads as wrap.
- [ ] **CW2. Fold lines and the rim.** Bright lines on some ridges facing the light; the pale top edge.
- [ ] **CW3. Rows and depth.** 3–5 rows, paler towards the back; the front one in front of the
      Mipos. The two palettes (light, deep).
- [ ] **CW4. Movement.** Heights drifting; the rows riding the sea's columns. Drop a Mipo in.
- [ ] **CW5. As the sea spike's skin.** A switch in `sea`: realistic water or cellophane, both on
      the same waves and floating. Cellophane needs no caustic, so the borrowed one isn't needed there.
- [ ] **CW6. Clear wrap (picture 07).** Long thin tapered white streaks over things, for a jar,
      a window, rain on glass. Maybe its own look later.
- [ ] **CW7. On the phone.** `./playtime.sh bench device` with a full screen of rows.

Open: is it the sea everywhere, or the look of one toy-like place (the island, the bath)? And does
it stay at its own size when the camera zooms (facets bigger close up, as real wrap would be)?

## Tried (2026-11-04), and why it stopped

CW1 in `scripts/spikes/cellophane.playtime.lua` (scene `cellophane`): first one crumpled sheet as a
flat-shaded mesh (read as low-poly terrain), then many overlapping see-through shards with light
edges, in rows of crests (read as an icy field). Nikki: "it feels a bit Toy Story 1 like,
synthesized"; she'll work more with hand-drawn assets, and use a shader where a moment asks for one.
