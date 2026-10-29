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
`s` smooth edge, `d` debug, `x` clear.

How it's built: ~28 small circle bodies along the smoothed outline (inset so their edge is the
outline), distance-joint spokes to a centre sensor body, rigid links between neighbours, and gas
pressure (an outward push per rim edge, from `jelly.c`). One fan mesh per blob with a centre
vertex; each rim vertex keeps the UV of its rest spot on the outline.

Findings (`--check`, 5 blobs, drop + kick):
- without pressure, two of five collapsed for good after the kick (area 0): rim points end
  up on the wrong side of the centre and distance joints can't tell. Pressure 1 fixes that:
  area dips to 66-88% at impact, settles at 94-99%, rim within 3-11% of its rest shape.
