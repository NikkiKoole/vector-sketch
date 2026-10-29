# Blob spike

Step 1 of `../playtime/docs/BLOBS.md`: a soft body in the shape of a Mipo head/body outline
(`shape8Dict`), wearing a real baked OMP texture from the dollhouse, squashing with it.
`src`, `vendor`, `textures`, `scripts` are symlinks into `../playtime`.

```bash
cd experiments/blob-spike
/Applications/love115.app/Contents/MacOS/love .            # play
/Applications/love115.app/Contents/MacOS/love . --check    # drop, kick, settle; print shape stats
#   --pressure=0 / --hz=8 to compare settings
```

Keys: drag to grab (a rim point squashes, the middle carries), right-click drops a new blob,
`n` next look, `[ ]` spokes softer/stiffer, `, .` pressure, `'` rim rigid/springy, `k` kick,
`s` smooth edge, `m` mesh (mvc/fan), `b` bend springs, `d` debug (folded triangles in red), `x` clear.

How it's built:
- physics: ~28 small circle bodies along the smoothed outline (inset so their edge is the
  outline), distance-joint spokes to a centre sensor body, rigid links between neighbours,
  soft bend springs (each point to the one two along), and gas pressure (an outward push per
  rim edge, from `jelly.c`);
- drawing: the rim positions are Taubin-smoothed (drawing only), pushed out by the circle
  radius along the winding normal, and Catmull-Rom midpoints added. The triangles are fixed at
  rest (middle, 3 inner rings, rim); each frame the inner vertices are rebuilt from the rim with
  mean value coordinates. Every vertex keeps the UV of its rest spot, so the picture squashes
  with the rim.

Findings (`--check`, 5 blobs, drop + kick):
- without pressure, two of five collapsed for good after the kick (area 0): rim points end
  up on the wrong side of the centre and distance joints can't tell. Pressure 1 fixes that:
  area dips to 66-88% at impact, settles at 94-99%, rim within 3-11% of its rest shape.
- flickering triangles (folded, wound the wrong way; on/off from frame to frame). Counted per
  frame over drop + kick + settle (seeded):

  | | folded frames | flicker (on/off) | shape off at the end |
  |---|---|---|---|
  | first version: fan around the centre body, "away from the centre" normals | 1749 | 214 | 7-15% |
  | now: mvc mesh, winding normals, bend 3 Hz, draw smoothing 4 | 173 | 31 | 3-5% |

  What it was, in order of effect: the physics rim kinks where a floor or another blob
  presses one point in (half of all frames had a kinked rim); a kinked rim folds the
  triangles next to it whatever fills the inside. Draw-only smoothing hides the kinks, soft
  bend springs halve them (stiff ones, 10 Hz+, made one blob cave in). The edge normals
  flipped sign in dents (rim vertices jumping by a circle's width): winding normals fixed it.
  A fan from one middle point folds as soon as part of the rim is hidden from it: the mvc
  mesh bends its inside along. What's left happens during hard impacts.
