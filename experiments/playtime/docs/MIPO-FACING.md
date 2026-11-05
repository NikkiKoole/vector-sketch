# Mipo facing — left, front, right

status: idea

A Mipo can face left or right instead of front: `dna.facing` = `'left'` / `'right'` (nil or
`'front'` = as always), `src/mipo-facing.lua`. After puppet-maker2's `facingVars.legs`
(`lib/box2dGuyCreation.lua`, `lib/texturedBox2d.lua` at the repo root; used by puppet-maker2,
physics-testbed's downhill bike and mipoworld). Spike: `scripts/spikes/facing` (one Mipo three
times, left / front / right; `s` sits them on stools, `a` arms follow on/off, `r` a new Mipo).

tried 2026-11-05: built as a spike, both views read as a Mipo, standing and sitting.

## What facing a side does

- **One side's limbs, twice.** The other side's legs, feet and arms are built with this side's
  joint limits, foot angle and foot picture: both hips swing forward, both knees bend back, both
  feet point the way it faces. The part names are screen sides (`l*` hang on the left).
- **Draw order.** The far arm, hand, leg and foot draw behind the torso, the far arm and hand
  under the far leg; the near arm and hand stay over the near leg (Nikki 2026-11-05).
- **The face turns** (2026-11-05): eyes, pupils, brows, nose and mouth move as if drawn on a
  cylinder the head's width turned 30° (`faceTurn`): a feature at x goes to R sin(asin(x/R) + 30°)
  and narrows by the cosine, so the far eye squeezes by itself. The ears' attach points turn the
  same way (character-topology `outline`); the ear at the back of the head comes over it (z 205),
  turned only 8° (`backEarTurn`) and not tucked in: at 30° it sat too far toward the face (Nikki);
  the other stays behind. The idle gaze looks around a spot ahead (`gazeAhead`), so the pupils and
  the head tilt follow the facing; the cursor still wins.
- **Torso stays front-on**, as in puppet-maker2.

## Sitting

Only a side view can sit: front-on, the hips only swing outward (a thigh pointing at the camera
can't be drawn in 2D). Facing a side, a sitting pose is just the limits: thighs forward (90°),
shins down. The spike sets the leg KEEP_ANGLE targets (degrees) and puts the Mipo on the stool
already folded; swinging straight legs forward in the air pushed it off the back of the seat.

## Open

- [x] **MF1. The face.** Turned toward the facing side: gaze ahead, features on a turned
  cylinder, the back ear over the head. A drawn profile head is the step after, if wanted.
- [ ] **MF2. Hips closer** facing a side (both legs hang from one point in a side view).
- [ ] **MF3. Turning live.** Tried 2026-11-05 in the spike (arrows a step, `t` back and forth):
  the face turns a little every frame (`instance._turnAngle`, `applyFace` from each decal's
  front-on place), the body switches by a rebuild when its own angle passes 15° (left -> right is
  two rebuilds, over front). Body and head turn separately (Nikki): the body quickly (120°/s),
  the head slowly after it (30°/s, so the eyes pass through every place); `,` `.` turn only the
  head. The idle gaze follows the head's angle.
  Smoother body switch (2026-11-05): first a little hop, the swap once the feet are off the
  ground (`j`, now off: Nikki wanted the in-place switch first). Then in place:
  `characterManager.switchFacing(instance, facing)` (mipo-build) keeps torso, head, legs and
  arms (their bodies and motion), sets the limbs' joint limits live, remakes only the foot that
  turns (one per step: front -> right turns only the left foot) and the ears (`updatePart`), that
  foot straight to its new rest angle, and redraws the textures (draw
  order with them). `b` in the spike compares with the whole rebuild.
  The arms switch at their own moment (Nikki: better timing for the arms): `dna.armFacing`
  (nil follows the body), `characterManager.switchArms` sets their limits and draw order; the
  spike moves them to the body's facing once the head is `armAt` of the way (slider, 0.6 to
  start; 0 = with the body, 1 = when the head arrives).
  The turning foot leans round instead of flipping (Nikki: "flip flip flip"; liked 2026-11-06):
  it pivots on its heel, toes up half way to pointing up, is swapped there for the new side's
  foot leaning as far the other way, which comes down to rest (0.12 s + 0.16 s). Only the picture
  leans (`extra.leanAngle` about the ankle, box2d-draw-textured): tipping the foot body itself
  fought the floor it stands on (tried: a motor toes-down got 9 of 63 degrees). `f` compares with
  the flip. Next if wanted: stagger
  feet / arms / ears, or swing the feet round instead of remaking them. Feet, limits, draw order and ears change in those two steps. Open: does
  the pop show, and a turn that's not a rebuild (feet swung, z swapped in place).
- [ ] **MF4. A facing pick** in the Mipo editor (MIPO-EDITOR-LEFTOVERS E2).
