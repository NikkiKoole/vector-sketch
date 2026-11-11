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

- [x] **MM1. Drive, walk, hop, jump** — the spike (2026-11-11).
- [ ] **MM2. Nikki plays with it.** Walk, hop, wander: keep, change or park?
- [ ] **MM3. Tall Mipos rock.** A long-legged one (spec seed 42) rocks ~60° forward and back as it
  walks: its torso lurches with each step (torso speed 350 <-> 800 px/s at 450). Not the push's
  strength nor a torso muscle; next try: stride by the leg's length, or the stance foot's grip.
- [ ] **MM4. Turning on the spot.** Reversing is a brake, a keyed turn and a slow start; a little
  turn-step (or a hop round) may read better.
- [ ] **MM5. Steps and slopes.** Only flat floors so far; a step up wants a higher swing or a hop.
- [ ] **MM6. Goals instead of directions**: walk to a point / a Mipo / a door (DOORS, worlds).
- [ ] **MM7. On the phone** (`./playtime.sh bench device`): a few Mipos wandering.
