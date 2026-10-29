# Mipo spine: one torso picture over 2-3 bones

Tall torsos (P4re5) are one rigid body with one static picture. A spine splits the torso
into 2-3 bones that bend a little against each other, and the one picture bends with them.
Optional per Mipo, like potato head and neck segments.

## What's there already

- `creation.torsoSegments` (1-5, slider in the Mipo editor) makes torso1..N, chained
  (`src/character-topology.lua`: legs on torso1, arms and neck on the top one). But each
  segment is a full torso shape with its own copy of the picture: a stack, not a spine.
  The topology is exactly what a spine needs, and joint guard, daze/flip (`corePartNames`),
  balanceMasses already handle torso1..N.
- Skinning one mesh over several bodies: MESHUSERT's DQS (`deformWorldVertsDQS` in
  `src/physics/box2d-draw-textured.lua`, built for Knut). It works on an editor-authored
  mesh with hand-made influences; a Mipo needs the same math with influences made by code.
- A muscle-like joint spring: `mipoActions.steerJointToward` (equal and opposite torques,
  bounded), what keeps arms hanging.

## Plan

**DNA**: `creation.torsoSpine = true` changes what torsoSegments means: the segments are
slices of one torso shape, drawn as one picture. Off (default) = today's stack. Editor: a
'spine' checkbox next to the torso segments slider; saved with the creation like the rest.

**S1 Physics: slice the torso** (one session)
- Cut torso1's outline (its shape8) into N horizontal bands at even heights
  (`mathutils.slicePolygon`); band i is torso_i. Each band needs an 8-point outline in the
  shape8 order, since attaching arms/legs/neck reads those points (`ownAttach` `topEdge`):
  resample each band's outline to 8 points. The fiddly part.
- Joint between bands at the middle of the cut: revolute, limits about ±15 degrees, plus a
  spring toward straight (steerJointToward pattern). It bends when it lands or is dragged,
  then straightens. KEEP_ANGLE only on torso1; the upper bones ride on the spring.
- Spec: a spined Mipo stands as still as one without a spine (standing_spec), bends less
  than the limit, is straight again within a second after a drop, no explosions in a pile.

**S2 Drawing: one picture over the bones** (one session)
- Draw torso1's OMP picture as a grid mesh (about 3 x 8) over the whole torso at rest; the
  other segments draw no picture of their own.
- Weights by height: each vertex follows its own bone, blended over a band around each cut
  (no crease). Rest pose and weights made once when the Mipo is built (bindVerts,
  bindAngle), deformed every frame with the DQS math: one Mesh kept and setVertices'd,
  not a new mesh per frame.

**S3 What sits on the torso** (half a session to one)
- Skin patches: each follows the bone it's over (rigid). Bodyhair (drawn around the
  outline points): outline points skinned with the same weights. Potato head face and
  haircut: on the top bone.
- If that still looks stiff: draw the torso's layers into one canvas and skin that
  (perfect bend), but check the z-order against arms and legs first.

**S4 Editor and tuning** (small)
- Checkbox, `rebuildFromCreation`; sliders for spineBend and spineSway (see Settings), a
  stiffness knob `lib.spineStiffness` to tune by hand. The per-segment torso controls in the editor already loop over all
  segments for skin and bodyhair; shape and size must too (a spine has one shape).
- Randomize keeps it off; maybe later on for tall torsos only.

## Settings (decided 2026-10-29)

All per Mipo, in the creation DNA, with sliders in the Mipo editor next to the checkbox:
- bones: torsoSegments with the spine on, 2 by default (2-3)
- `creation.spineBend`: how far each joint bends, 15 degrees by default
- `creation.spineSway`: a little idle sway with the breath, small by default (0 = off)
