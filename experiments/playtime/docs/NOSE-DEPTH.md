# Nose depth — a nose that sticks out

status: active — N1-N3 done 2026-11-11 (Nikki: "i like it"); N4, N5 open

Nikki (2026-11-11): "is there some way where we can make the nose more 3d, not just with bumpmap but
really? so it sticks out". Today the nose is lit as a dome (clay shader, its roundness baked from its
mask, LS28), and it turns with the face like every other feature: `src/mipo-facing.lua` `applyFace` puts
eyes, brows, nose and mouth on one cylinder the head's half-width wide, turned 30° (`faceTurn`). So the
nose moves exactly as the eyes do, which is part of why it reads flat.

## Steps

The first three together (all work with what's there: the face turn, part shadows, the nose's mask);
then N4 at a full side turn; N5 only if those aren't enough.

- [x] **N1. The nose turns further than the eyes (parallax).** Done 2026-11-11, liked: `mipo-facing`
  `lib.noseOut` 1.35 (the nose's cylinder that much wider than the head's); a Mipo built or turned after it. In `applyFace`, the nose on a bigger
  cylinder than the face (its tip stands out in front: ~1.3x the head's half-width, a setting), so on a
  turn it moves further towards the turn than the eyes and overlaps the near cheek. A few lines, free per
  frame, works with the keyed head turn (MIPO-FACING MF10).
- [x] **N2. The nose casts a shadow on the face.** Done 2026-11-11, liked: it had one already (LS28's
  `drawNoseShadow`: one hard copy of the nose, 22%, away from the light); now three layers growing evenly
  round it, fainter outward (a soft edge), `box2d-draw-textured` `lib.noseShadow` 0.22. Drawn at the nose's
  depth, so it falls on the eyes too. The plan as written: `src/part-shadows.lua` (LS20) already shadows part on
  part, but face decals are on the no-shadow list (`shadow-silhouettes` NO_SHADOW). Let the nose cast (only
  the nose: eyes and mouth stay flat) and its soft shadow falls beside it, away from the light. Maybe a
  darker contact shadow right under its base too. Cheap: the pass already runs when part shadows are on.
- [x] **N3. A soft dark ring where it meets the face (ambient occlusion).** Done 2026-11-11, liked:
  three layers round the nose, a touch low, `lib.noseRing` 0.14 (0 off). The plan as written: The face a little darker round
  the nose's base, from the drawn shape's mask (one extra soft pass under it). Seats it in the face.
- [ ] **N4. It breaks the head's outline in a side view.** Facing a side, a profile nose sticks out past
  the head's edge. Check the nose isn't clipped to the head's shape; with N1 it then pushes past the cheek
  line at a full turn. See whether Nikki's nose drawings hold up there; a drawn profile nose is a new
  drawing (THINGS-TO-DRAW) if not.
- [ ] **N5. Real 3D, if wanted:** the nose as a small raised mesh, its baked roundness as vertex heights,
  lit and drawn in perspective as the head turns. Most "real", most work, and it risks the "Toy Story 1"
  look (SHADER-LOOKS: hand-drawn first, shaders for moments).
