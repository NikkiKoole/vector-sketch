# Mipo locomotion — how games and robots walk, for the motor spike

status: active

The motor spike (`docs/MIPO-MOTOR.md`, `src/mipo-walk.lua`, `./playtime.sh play motor`) walks a Mipo
by keyed leg poses held by hip and knee motors, and an "honest push": an outside force on the torso
while a foot touches the floor. What's left there: tall Mipos rock (MM3), the bob is small and
irregular (MM8), reversing is a slow brake (MM4), only flat floors (MM5).

A force on the torso while the feet grip tips the body over its feet with every surge: part of the
rocking is the push itself. The methods below move the body through the legs instead (Nikki
2026-11-12: "look for industry ways of locomotion that would improve it"; the old puppet-maker
`BipedSystem.lua` turned out to be a rig and a birth animation, not a walk).

Each step is a switch on `mipoWalk` (on the spike's weight panel), compared on / off with
`spec/mipo-motor_spec.lua`'s numbers: legs walked, worst tilt, bob, end drift
(`MOTOR_SET='key=value,…' love . --specs spec/mipo-motor_spec.lua`).
Baseline 2026-11-12 (before LO1): tilt 9-25°, seed 42 39°; seed 9 walks 1.4 legs left (fails the
1.5 asked) and "hops once and stops" fails, both on master already.

## The methods

- **SIMBICON** (Yin, Loken & van de Panne 2007; the usual one for 2D physics walkers). (a) The torso
  is held at a *world* angle by the standing hip: the torque on the torso is matched by the opposite
  on the standing thigh, so nothing comes from outside. (b) Balance by where the foot lands: the
  swing hip aims `base + cd·d + cv·v` (d: the body's centre ahead of the standing ankle, v: its
  speed); too fast, it steps further ahead and slows itself.
- **Capture point** (Pratt; Euphoria-style ragdolls): a foot set down at `x + v·√(h/g)` stops the
  body in one step. Stopping, turning round, a recovery step when bumped.
- **Raibert hopper** (MIT 1980s): the hop's forward speed only from where the foot lands,
  `x_foot = v·T/2 + k(v − v_target)` (T: time on the ground).
- **Gravity compensation**: the standing knee and hip get the torque that holds the weight up
  (weight × lever) before the motors chase the pose, so the motors can be soft.
- **Steps by distance** (David Rosen, *Animation Bootcamp*, GDC 2014, Overgrowth): the cycle moves on by
  distance / stride, the stride by leg length; few poses plus springs, the bob drawn on top (MM9).
- **Foot IK on the ground**: a ray down where the swing foot will land, a two-bone IK for hip and
  knee, the keyed pose blended over it. Steps and slopes.
- **Active-ragdoll tricks** (Gang Beasts, Human Fall Flat, TABS): a damped world-space upright torque,
  a "head up" force, extra grip on the standing foot. Only if the honest ones aren't enough.
- Not for us: motion matching, DeepMimic and other learned controllers (data and training, for
  Mipos of every size out of DNA).

## Steps

- [x] **LO1. SIMBICON: the torso upright through the standing hip, the foot placed for balance.**
  Built 2026-11-12. Kept, now the default (Nikki: "it looks better, but still a far way from great");
  the spike's weight panel has a `simbicon` button (on / off as before) and sliders for torso by
  hip, foot placement, lean.
  - `lib.torsoHold`: the standing hip's *motor* aims the torso at its world angle (`walkLean`)
    instead of the thigh at its pose (`torsoByHip`); that thigh's muscle off.
  - `lib.placeV` / `placeD`: the swinging thigh aims further forward by the speed error and by how far
    the centre is ahead of the standing ankle.
  - Sweep (8 seeds, `MOTOR_SET`; right / left legs walked, mean / worst tilt):
    off 3.8 / 2.5, 19° / 39°; placeV 0.5 3.3 / 2.5, 17° / 34°;
    torsoHold 0.5 + driveAccel 2.5 + placeV 0.5 (the button) 2.8 / 2.4, 16° / 28°. The hold alone is
    steadier but slower (the standing hip used to drive it forward), hence the firmer push.
  - tried 2026-11-12: the hold as torques on torso and standing thigh (`torsoByMotor` false, SIMBICON
    as written): the light thigh whips forward to -98° instead of the torso turning, tilt up to 108°.
    With the hip motor left on the torques do nothing (the motor takes them). torsoDamp 0.5: no better.
    placeD 0.3-0.5 with placeV: worse than placeV alone. walkLean 12: no better.
- [x] **LO1b. The skate.** Nikki 2026-11-12: "it looks skating, it looks like the legs rotate the wrong
  way around". Measured (`spec/mipo-skate_spec.lua`, 5 seeds): with the hip holding only the torso,
  the standing thigh turned *forward* most frames and the foot slid 141% of the body's speed. Now the
  standing hip holds the thigh's pose too, the torso's correction on top (`stancePose` 1): it sweeps
  back. The push dragged the feet along: slide 66% at driveAccel 2.5, 43% at 1.5, 13% at 1 with
  hipStrength 1 (the defaults now; tilt mean 18°, worst 28°, seed 42 21°; a bit slower, 2.9 / 2.1
  legs). tried 2026-11-12: stanceGrip 3 (more slide, not less).
- [x] **LO7. The feet roll through the step** (Nikki 2026-11-12: "the feet aren't rotated while
  walking … keep the same angle between shin and foot, maybe some anticipation and plant"). Before,
  a muscle held them flat (toes 12° up on the swing). Now `FOOT_KEYS`: heel strike (toes up
  `heelStrike` 18), plant flat, flat while the body passes, heel off over the toes (`toeOff` 30),
  toes trailing, toes up before contact. Measured (left foot, by tenth of the step from contact):
  +10 0 0 0 -2 -19 -15 -2 +4 +14. Every motor spec passes (19), walks a bit further (4.2 / 2.9 legs).
  `footFollow` turns the swinging foot with its shin: 1 put the toes into the floor mid swing (the
  foot turned 100-125°, snagging); 0.4 visible, but one Mipo didn't stop and two walked short; 0 the
  default for now. Weight panel: foot roll on / off, heel strike, toe off, foot with shin.
  Kept (Nikki 2026-11-12: "very nice").
- [x] **LO8. The jump as animation** (Nikki 2026-11-12: "before a jump we have anticipation, you
  squat a little and then POING, jump!, learn from animation"). Before: legs limp 0.1 s, one impulse
  on the torso at a fixed speed (small Mipos jumped many times their height, MM2). Now
  `mipoWalk.jump` (`mipoActions.jump` hands over while the walk runs, `animJump`):
  anticipation (squat eased into its lowest point over `jumpCrouch` 0.24 s, torso leaning in, arms
  back, held `jumpHold`), the push (`jumpPush` 0.08 s: hip and knee motors snap the legs straight,
  heels up over the toes, arms up; the lift spread over it, measured on the whole Mipo's centre, to
  `jumpHeight` 1.3 leg lengths), follow-through (stretched, then knees tucked), landing (knees give
  quickly, come up slower, `jumpLand`). Facing front: a frog squat (thighs out, shins in; the front
  hips only open outward). `spec/mipo-jump_spec.lua` (8 Mipos facing right and front): dips 0.06-0.27
  legs, torso up 0.5-1.1 legs, all land and stand (end tilt ≤ 12°). Panels: jump height, squat (s),
  jump animated / old, squat depth. tried 2026-11-12: the lift by the torso's own speed (0.3-0.6 legs
  of 1.3: the torso runs ahead of the legs it drags). Kept (Nikki 2026-11-12: "ok pretty good").
- [ ] **LO2. Gravity compensation**, so the motors can be soft and the bob deeper (MM8).
- [ ] **LO3. Steps by distance, the stride by leg length** (MM3's "stride by the leg's length").
  Tried 2026-11-12. The stride was already by leg length (2·L·sin 28°). Measured with a new count in
  `spec/mipo-skate_spec.lua` (PLANT: how far the standing foot moves between landing and lifting,
  against how far the body goes; a planted foot is 0%): 27% on average, 9-53% by Mipo. Its likely
  cause: the keyed stance's spacing (contact, down, passing, push-off) isn't even in distance, so
  the thigh's sweep and the body's way don't match through the stance.
  - Kept: the steps follow the body's own speed more closely (`gaitFloor` 0.2, `gaitCap` 1; were 0.6
    and 1.3). Drift the same (26%), tilt less (mean 18° -> 14°, worst 27° -> 22°), stops shorter
    (0.19 legs, still in 0.9 s), every spec passing.
  - tried 2026-11-12, off (`footLock`, a button on the weight panel): the standing leg aimed by IK at
    where its foot landed, the hip taken a moment ahead (`footLead`; aimed at the body as it is, the
    motors held the leg stiff and the body pushed the foot along: 99%). Drift 17%, but a third
    slower and more tilt: the legs don't drive the body. With a firmer push the foot drags again
    (40%); handing back to the keyed push-off late in the stance (`lockUntil`): 25-31%; the hip led
    by the speed it wants (`leadByWant`) with a gentler push: half as far.
  - Next, if the skate still shows: the legs driving the body (stronger hip motors, or the push
    only through the standing foot), or the keyed stance respaced evenly in distance.
- [x] **LO4. Capture point**: stop in a step, turn round (MM4), a recovery step when bumped.
  Built 2026-11-12 (stopping and turning; the recovery step not yet, LO4b). Told to stop, a walking
  Mipo facing a side takes the stopping step (`stopStep`): the leg that isn't standing steps to the
  capture point (x + v·√(h/g), at most `stopReach` 0.75 legs ahead), lifted mid-way and heel first,
  the torso leaning back a touch, the feet braking from the start (`stopBrake` 4); then the back
  foot steps up beside the front one (`closeTime`: lifted, not slid), then the settle (knees give,
  torso on past upright and back, arms swing, `settleTime`). Told to go the other way: the stopping
  step, then it turns on the spot and dips (`setOff`) before it sets off (`turnFirst`, walking only).
  Facing front: the old brake. `spec/mipo-stop_spec.lua` (8 Mipos): goes 0.45 legs after the stop
  (old 0.33), still after 1.5 s (old 1.3), going the other way after 1.1 s (old 0.9), no moonwalk.
  Weight panel: jump anim / old, stop step / old, turn first / old.
  tried 2026-11-12: braking only once the foot was down (went 0.8 legs); no brake, the planted leg
  alone (0.9 legs, 1.8 s); sliding the feet together in the settle (both skidded, so the closing
  step); firmer grip while stopping (1 to 6: no difference). The spec's 'feet skid' counts a foot
  rocking on its heel or toe too (a standing Mipo shows it): compare it, don't read it alone.
  The step-turn (Nikki 2026-11-12: "when turning sometimes the feet quickly turn twice"): right ->
  left goes over front, two switches, and each flipped a foot in place (the foot picture's lean).
  Now, turning on the spot, each foot lifts as it turns and comes down facing the new way
  (`stepTurn`, `stepTurnTime` 0.15 s a half, `stepTurnLift`), and it sets off once the second foot
  is down. Found on the way: a runaway walk (the steps went at the body's speed, faster legs sped
  the body, seed 42 walked left at 3x its speed and didn't stop); the steps are capped at `gaitCap`
  1.3 times the speed it wants. With both: stop 0.29 legs after, still in 0.8 s; every motor, stop,
  jump, skate and feet-hop spec passes. tried: stepTurnTime 0.2 (3 of 8 swayed long after a stop),
  gaitCap 1.6 (seed 42 still ran 6.3 legs).
  Still flapping (Nikki: "the foot facing me flaps twice very quickly"): the foot picture's lean
  (toes up 45°, swapped, down) ran at both switches, and the first foot's turn began a frame before
  the step-turn flag was set. Now a step-turn's foot turns in the air without the lean, and a Mipo
  walking by itself always turns its feet as steps (checked live: both feet `step`, two turns).
  Kept (Nikki 2026-11-12: "ok great"). The recovery step is LO4b.
- [ ] **LO4b. The recovery step**: a standing Mipo pushed or bumped steps toward its capture point
  instead of tipping over. Built 2026-11-12 (`recoverStep`): standing a moment (`recoverCalm` 0.4 s;
  rising from a squat set it off), moving over `recoverSpeed` 0.6 legs/s with its capture point past
  its feet, it steps there (facing a side the further foot, past the other; facing front the leg on
  that side, out sideways, the front hips only open outward), arms out, the feet braking once it's
  down (`recoverBrake` 4); the other foot follows in as far apart as they stood; it settles.
  `spec/mipo-recover_spec.lua` (8 Mipos facing right and front, shoved 1.5 / 3 / 4.5 legs/s): the
  finding is that bumped Mipos don't fall, with or without it; they slide on planted feet (0.36 /
  1.4 / 4.1 legs). With the step they step about twice and go 0.47 / 1.67 / 3.25 legs: further from a
  soft shove, less from a hard one. So it's a look: a stumble against a glide. tried: no braking
  (0.78 legs from a soft shove), a slower step (0.22 s, further), a wider margin (the same).
  Spike: `b` shoves them. For Nikki to look at.
- [ ] **LO9. The squat** (Nikki 2026-11-12: "can we get the down button to make them squat"): held
  (`mipoWalk.squat(inst, true)`, the spike's down key), it sinks into a squat over `squatTime` 0.25 s
  (torso in, arms forward; facing front a frog squat), let go it comes up; up from a squat jumps
  without the jump's own crouch (it's down already). Spec: down 0.24 legs facing a side, 0.13 front,
  standing again after. Checked live (down ~80 px and back). For Nikki to try.
- [ ] **LO5. Raibert hop**: hops even and steerable, landing where it means to.
- [ ] **LO6. Foot IK on the ground**: steps and slopes (MM5).
