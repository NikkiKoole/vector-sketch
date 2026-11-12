# Mipo motor — walking, hopping, jumping by themselves

status: active

Mipos stood like dolls: they turned and stepped only when a hand dragged them (MIPO-FACING MF5).
Now they can go by themselves (Nikki 2026-11-11: "spike out motoring skills for our mipos, now they
are like static dolls, sort of. can we make them face a direction and walk, hop, jump").
Spike: `scripts/spikes/motor` (`./playtime.sh play motor`).

## How

- `mipoWalk.drive(inst, speed, mode)` (`src/mipo-walk.lua`): speed in leg lengths a second (+ right,
  - left; nil stands), mode `'walk'` or `'hop'`. It turns to face its way (the normal keyed turn,
  `lib.turnTo`), going at `turningPace` of its speed until it does.
- **Honest push** (as the garden critters, `feedback: critters honest physics`): the feet push the torso
  toward the speed it wants, at most `driveAccel` leg lengths/s², and only while a foot or shin touches
  something. Nothing holds it up or carries it in the air: picked up it's a doll again (a hand wins),
  knocked over it's knocked over. Told to stop, the feet brake `brakeFor` s.
- **Walk**: the legs are the dragged walk's gait (`stepLegs`, shared with MF5): thighs swing in turn,
  the knee bends on the swing forward, feet flat, hips with room behind. Off the ground a while
  (a jump, a fall) the legs tuck.
- **Hop**: both feet together: crouch `hopCrouch` s, spring `hopHeight` leg lengths up and to the
  speed it wants, legs tucked in the air, soft knees on landing, `hopRest` s, again.
- **Jump**: `mipoActions.jump(inst, forward)`, the old crouch-and-jump with a forward speed added
  (the spike: the way it faces). Walking or hopping, its own speed carries on through it.
- All the numbers are switches on the module (back to defaults on a scene load); the spike's panel
  has sliders for them.

## Spike

Three random Mipos on a long floor with a wall at each end; the camera follows them.
Keys: left/right held walk (or hop) that way, up jumps, g walk / hop, w wander by themselves (stand,
walk or hop a way, sometimes a jump; away from the walls), r new Mipos, n one more, h panel.
Spec `spec/mipo-motor_spec.lua` (8 Mipos: walk right then left, upright, stop; hop forward; a jump
the way it's told). Numbers (2026-11-11): ~3 leg lengths in 4 s at 1.5 legs/s, 4-8 hops in 5 s,
torso tilt 5-25° for most.

tried 2026-11-11: a torso KEEP_ANGLE while walking (`upright`, 20: rocked more, left 0); the push
spread over every part by mass (`pushAll`: no different from all on the torso).

## Open

Methods from games and robotics for these (SIMBICON, capture point, Raibert, foot IK):
`docs/MIPO-LOCOMOTION.md`.

- [x] **MM1. Drive, walk, hop, jump** — the spike (2026-11-11).
- [x] **MM2. Nikki plays with it.** Kept (2026-11-11: "i like it"); jumps went high easily (the jump is
  a fixed speed, so small Mipos jump many times their height: a jump in leg lengths, as the hop, next);
  one-go buttons asked for and added; then the weighty walk (MM8).
- [ ] **MM3. Tall Mipos rock.** A long-legged one (spec seed 42) rocks ~60° forward and back as it
  walks: its torso lurches with each step (torso speed 350 <-> 800 px/s at 450). Not the push's
  strength nor a torso muscle; next try: stride by the leg's length, or the stance foot's grip.
- [ ] **MM4. Turning on the spot.** Reversing is a brake, a keyed turn and a slow start; a little
  turn-step (or a hop round) may read better.
- [ ] **MM5. Steps and slopes.** Only flat floors so far; a step up wants a higher swing or a hop.
- [ ] **MM6. Goals instead of directions**: walk to a point / a Mipo / a door (DOORS, worlds).
- [ ] **MM8. A weighty walk** (Nikki 2026-11-12: "more weighty, as in animation, that i feel the
  weight shifting and that it's a nice walk cycle"). Built 2026-11-12 (`lib.weighty`, the weight
  panel): the standing knee gives after contact (`give`), the push surges at push-off (`pulse`), the
  arms swing against the legs (`armSwing`, on mipoActions' arm hang: soft, so they lag a little).
  Measured (torso height averaged by where it is in the step, 6 Mipos): the bob in time with the
  steps is ~3% of a leg, lost in an irregular bounce of ~25%; the knee give and pulse didn't make it
  more rhythmic. A gripping standing foot (`stanceGrip` 2) with a gentle push (`driveAccel` 1) is
  the calmest (71% of the bounce in step, tilt 10 against 15) but a third slower; the legs alone
  hardly move it (0.7 against 3.6 legs). Next: firmer, keyed leg poses while walking, or the bob drawn.
  Keyed + motors (Nikki: "lets try 1 but i might want both", 2026-11-12): the legs go through keyed
  poses (`WALK_KEYS`: contact, down, passing, push-off, toe-off, the lifted swing, reaching; a smooth
  curve through them, the spacing the timing) and hip and knee motors hold them against the body's
  weight while it walks (`legMotors`; the KEEP_ANGLE muscles set spin once a frame between substeps,
  so poses smeared; a motor is solved with the joint, as mipo-stance's knees). With the foot gripping
  (`stanceGrip` 2) and a gentler push (`driveAccel` 1.5, now the defaults): 77% of the bounce in step
  (sine 35%), 4.5 legs against 3.6 (the legs carry it now), tilt 18; the tall seed 42 39° (was 56).
  Stronger motors (0.9-1.2) bob deeper but tilt more (22-26). The in-step bob is still small (±2-4%
  of a leg). Weight panel: poses keyed / sine, motors on / off.
- [ ] **MM9. The bob drawn** too, if the physical one isn't enough (Nikki: "i might want both"):
  torso and head drawn lower at the down pose and a little behind.
- [ ] **MM7. On the phone** (`./playtime.sh bench device`): a few Mipos wandering.
