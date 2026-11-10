# Mipo facing — left, front, right

status: active

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
- [x] **MF3. Turning live.** Tried 2026-11-05 in the spike (arrows a step, `t` back and forth):
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
  the flip. Feet, limits, draw order and ears
  change in those two steps. Into every scene with MF6 (2026-11-10); what's left is MF7.
- [x] **MF6. Promote turning + autowalk out of the spike** (Nikki 2026-11-06: "we might want to
  promote this soon"; into the engine, Nikki 2026-11-10, LANDING-2026-11.md, before hair and hats).
  Done 2026-11-10: `src/mipo-walk.lua`, run for every Mipo by `src/systems.lua` (in a fixed order: a
  switch remakes bodies). The spike's code as it was, its defaults kept (head 30°/s, body 120°/s,
  arms at 0.6, the turn pull 0.7 leg lengths over 0.3 s, grips 0.05 / 0.5). Walking can be switched
  off per scene (Nikki: "we also need to be able to toggle this"): settings panel, section 'mipos',
  'walk when dragged', on by default, saved with the scene only when off (`mipos = { walk = false }`).
  Not while a Mipo is a ragdoll, flipped or dazed, nor one a scene holds off (`mipoWalk.hold(inst,
  true)`: the facing spike's sitting). The spike's comparison switches (lean / flip, hop, rebuild
  whole, turning by itself, arms at) are the module's options, back to their defaults on every scene
  load (left on, they rebuilt the tracks riders out of their carts in the next scene). A scene keeps
  dna.facing; a turn or walk under way starts over. The spike is its panel now (760 -> 330 lines).
  Spec `mipo-walk_spec.lua` (dragged by a finger: turns right and steps, let go back to front; off:
  neither; held: neither; the setting saved only when off); snapshot mipos identical; full suite green.
- [x] **MF10. The head turns with weight, and turns go back home** (Nikki 2026-11-11: "I don't like
  the slow way the face just rotates, can we have weight, keyframe feel"; "better like this").
  The head no longer drifts at 30°/s: a keyed move (`lib.headKeys`), an ease-in-out with a pull back
  first and an overshoot after (`lib.headBack` 1.7, ~9% of a step each), 0.3 s a step (`lib.headTime`;
  left -> right ~0.42 s, a relaxed turn 1.6x). The head now leads and the body follows (before: the
  body quick, the head slow after it). Any turn this module makes (arrows, a scene's `turn`, a walk)
  goes back to the facing it had before (`inst._home`, front for nearly all) once the Mipo has stood
  `lib.relaxAfter` (3 s) not held, walking or held off; facing a scene sets itself is left alone.
  The facing panel: head keyed / slow drift, head time, overshoot, back home after, blink on turn.
  Blink on turn (Nikki 2026-11-11: "do the blink on turn, sometimes"; "feels right"): half the keyed
  head turns blink as they set off (`lib.turnBlink` 0.5), shut through the quick middle
  (`mipoFace.blink(thing, hold)`, hold half the turn less the closing).
- [ ] **MF4. A facing pick** in the Mipo editor (MIPO-EDITOR-LEFTOVERS E2).
- [x] **MF5. Autowalk.** Tried 2026-11-06 in the spike (`w`), "pretty good": a Mipo faces front;
  dragged sideways near the floor (a foot touched in the last 0.3 s, faster than 0.25 leg
  lengths a second) it turns that way and its leg muscles step (KEEP_ANGLE targets: thighs swing
  in turn, the knee bends on the swing forward), the steps going by how far it's dragged, at
  most 2.5 a second (faster: longer strides, up to 48 degrees). While walking the swinging foot
  hardly grips (0.05) and the standing one half (0.5): with full grip the feet held the legs
  back, trailing, and tipped the torso into the drag. 1.2 s after it stops it turns back to front
  (only a turn the walk made). Then ("much better", 2026-11-06): the feet held flat by a muscle
  with free ankles while walking (on their ±22 degrees they turned with the shins, toes into the
  floor, and a shin stuck 80 degrees off its target), and the hips 35 degrees of room behind (facing
  a side they only swing forward, for sitting; a walking thigh needs to swing back).
  Turning round takes a real pull (Nikki: no fidgety switching when just pressing it down):
  dragged one way 0.7 leg lengths in all for 0.3 s at least (back the other way starts over,
  held still it fades), the body then turning at 0.6 of its speed, the head slow as always;
  relaxing back to front the same. "A great experiment" (2026-11-06).
  Muscles only, no forces: the hand moves it. A turn waits only
  while a part it remakes (foot, ear) is held. Into every scene with MF6 (2026-11-10); what's left
  is MF8.
- [x] **MF7. A smoother turn: staggered** (Nikki 2026-11-11: "y try the stagger"; "reads better").
  The switch spread over three moments instead of one frame (`lib.stagger`): the ears go with the
  head as it passes `lib.earAt` (0.5) of a step (`dna.earFacing`, `characterManager.switchEars`),
  the body and feet when the body switches, the arms `lib.armLag` (0.1 s) after (with the keyed head
  the arms' `armAt` had them switch on the body's frame). Front -> right: ears ~0.15 s, body ~0.25 s,
  arms ~0.35 s. Scenes that set facing themselves keep their ears with the body. Panel: staggered /
  all at once, ears at, arms after. Not tried: swinging the feet round and swapping z in place
  instead of remaking them.
- [ ] **MF8. Walking, the leftovers.** It still tips into the drag (pulled high, feet on the floor:
  a broom by its handle), next try pulling at the hips while walking; walking held by a foot (that
  foot can't step).
- [ ] **MF9. Riders held.** Scenes that seat Mipos themselves (tracks, soapbox, rides) don't
  `mipoWalk.hold` their riders yet (checked 2026-11-11: only the facing spike does): a rider
  dragged with its feet on the cart could start stepping against the scene's pose.
- Used by the tracks spike's riders (TRACKS.md TR4b): facing and the face's turn taken from their
  cart's 3D direction, front where the cart is end-on (2026-11-06).

## Standing, and piles of Mipos (2026-11-10)

Found once Mipos walked everywhere; built straight into the engine, no spike.
- **On their soles** (`src/mipo-stance.lua`, a system): an ankle motor holds each foot square to
  its shin, and facing a side a knee motor holds the bend the leg muscles ask for. Before, Mipos
  landed on a heel or a toe tip, and stubby or side-facing ones did the splits. Rests while
  walking, ragdoll, flipped, limp, and for legs a scene poses. Stubby Mipos get wider leg shapes
  (mipo-build `fitLegWidth`). Spec `feet-hop_spec.lua`: 96 of 720 landings not flat -> 8.
  tried 2026-11-10: pulling the foot level with the world (levered the shins; dropped); drawn-width
  legs for every Mipo (piles knotted twice as often; dropped).
- **Knots of three or more untangle as a group** (`mipo-joint-guard` knotGroup: they pass through
  each other and drift apart, no hop). Nikki's pit (19 Mipos in a bowl) knotted for good when
  untangled pair by pair. Spec `mipo-untangle_spec.lua` with `spec/fixtures/pit-knot.playtime.json`.
- **Legs pass other Mipos** (settings, 'mipos'; `state.legsPassMipos`, off, not saved). tried
  2026-11-10 against knots in piles: fewer untangles, but left off since the wider-legs fix stopped
  the pit knotting.
