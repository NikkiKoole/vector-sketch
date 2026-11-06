# Soft torso — lobes on every torso shape, with the spine

status: active

Torsos were one rigid shape (or a spine of rigid bands). Nikki (2026-11-06), looking at the
upside-down heart torso: its two big bottoms should move on their own, "like the segmented torso
but the horizontal difference is relevant too".

Two ways were built and compared on the heart in `vanilla`:
- **Jiggle, drawn** (`src/torso-jiggle.lua`, `creation.torsoJiggle`): springy points ride torso1,
  no bodies; the picture's grid and the face move with them. "Pretty nice" once made subtler
  (amount 0.4, head share 0.25). Costs nothing: the fallback for crowds.
- **Lobes, physical** (`src/torso-lobes.lua`, `creation.torsoLobes`): "the physical ones win".
  Round bodies on a V of two springy distance joints plus a rope (the slack), so they give in
  every direction, squash on a landing and push back on the torso. The torso's collision is cut
  where they start; legs, arms and ears still hang from the whole outline. The torso picture is
  a finer grid (8 x 12) whose points near a lobe move with it; the face rides along
  (`spineSkin.torsoBones` / `transformAt`).

Not the softbody (`src/blob.lua`): a squishy rim makes the points the limbs hang from wander,
and it's many more bodies per Mipo, against ~20 Mipos a room on the phone.

Why not Lua forces for the springs: the physics runs several substeps a frame
(`gameLoop.physicsSteps`) and a force set from Lua only acts in the first; Box2D's soft weld (the
ears) only springs in rotation. Two distance joints in a V are real springs in both directions.

## Steps

- [x] **ST1. Lobes from the outline, any torso.** Each end gets two lobes at its corners when it's
  wide (corners more than 0.45 of the width apart, off the middle, near the end) or one in the
  middle when it's narrow: the heart 3 (bumps and tip), box-like shapes 4 (7, 8, 9, 13, 18), one
  shape 2. Parts `lobe1..lobe4` (DNA made by `torsoLobes.apply`, the topology gets the list from
  the build); a torso swap that changes the count rebuilds the Mipo. Editor: creation → lobes,
  depth (rebuilds), spring Hz and damping (live). The jiggle uses the same points.
- [x] **ST2. Lobes with the spine.** Each lobe hangs from the band it sits in, each band's
  collision is cut, an end's lobes take at most about one band; the picture bends with the spine
  first, then the lobes push (their offset measured from where their band carries their rest).
  Heart on 2 and 3 bands: stands, bends ~17° on a landing, straight again.
- [x] **ST3. Phone cost.** The crowd (20 Mipos) with lobes on all of them, iPhone SE 2 (2026-11-06):
  62 more bodies, 186 more joints; 60 fps, no frame over 20 ms. Update 3.9 -> 4.2 ms, draw
  5.3 -> 7.4 ms. First try was draw 11.4 (4.4% of frames over 20 ms); ProFi on the phone showed
  why, and the fixes: the lobe bodies were drawn by the plain physics draw (no picture of their
  own; `box2d-draw` showsBody now skips them), every face part asked `torsoBones` again (~400 a
  frame; kept for the frame, `spineSkin.newFrame`, lobes measured once), and the lobed grid
  went through Lua tables (C lays it now, the pushes added into its buffer, weights kept per
  grid). Physics itself costs ~0.3 ms.
- [ ] **ST4. DNA traits.** Softness in randomize and as a breed trait (MIPO-BREEDS.md): a jelly
  breed and a firm one.

Open: on a hard landing the lobes go as far as the rope lets them (~24 px at scale 0.3); more
slack if that reads as a stop. The drawn jiggle doesn't combine with a spine. Placements judged by
numbers only for shapes 2 and 16.
