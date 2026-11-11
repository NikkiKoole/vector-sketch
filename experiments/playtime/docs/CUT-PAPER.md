# Cut paper — every drawn part a piece of painted paper, in draw order

status: parked — kept as a spike (Nikki 2026-11-11: "like the look of all of them and want to keep them in that spike"); the next step when it comes back is below

Nikki (2026-11-11): "the cutpaper not great, like your idea to see if run on draw order changes it, can we
spike that?". The riso spike's cut paper (RISO.md) worked on the finished picture: busy textures broke into
confetti, and the Mipo's parts had no edges of their own. Earlier: MATERIALS' collage row (2026-11-04:
"patches clipped to the shape, the torn edge from above with a white under-layer"; its lesson: real scans
of torn paper beat noise).

## The spike (2026-11-11, scene `cutpaper`)

- **Engine hook** (`src/physics/box2d-draw-textured.lua`): `state.drawableWrap = function(d, draw)`, when
  set, is handed each drawable and its drawer instead of drawing it; the scene calls `draw(d)` as often as
  it likes. One line in the loop; nil (every other scene) changes nothing.
- **Each part drawn three times**, in the world's draw order: its **shadow** (the shape, dark, offset;
  'shadow', 'shadow dark'), a **white fringe** (the shape grown a few screen px, unevenly and in patches:
  torn paper's white core; 'white fringe', 'tear'), then the **piece** (its colours, the drawing's lines
  kept as much as 'drawn lines' says, strokes and dabs of a painted sheet at the piece's own angle, 'paint';
  its edge torn inward a little). A part's shadow falls on the parts laid before it, so the layering is the
  draw order.
- **simplify** (px): the cut shape smoothed before cutting, thin strands (hair, fur strokes) one piece in
  their average colour; without it every hair got its own white fringe and heads went white and fuzzy.
- The uv per screen pixel comes from the shader derivatives (`dFdx(uv)`), so growing and smoothing work
  on pictures, ribbons and meshes alike. While wrapping, `state.drawingOutlines` is on so the engine's
  material shaders (hair, plasticine) stand back.
- Paper white, cream, board or blue under everything; boil; space shows the original.

First look: the Mipos as layered paper pieces, each with its shadow on what's under it and a torn white
edge; faces, hands and feet read as cut shapes; with simplify the hair is one piece, the body's fur strokes
little paper strips each.

Known: a drawer that sets its own shader (the leg cut, some face stencils) draws that part plain; the
fringe can't grow past a picture's own transparent margin.

## Steps

- [x] **CP1. Nikki plays with it**: keep, change or park.
  Kept 2026-11-11 (Nikki 2026-11-11: "like the look of all of them and want to keep them in that spike"): liked, kept as a spike.
- [ ] **CP2. Real torn paper**: scans of torn paper edges and painted sheets (scan2tex) instead of noise,
  as MATERIALS learnt.
- [ ] **CP3. If kept**: a look per Mipo or per scene (a setting, not a scene script), the background as
  cut paper too, and its cost on the phone (each part drawn three times).
