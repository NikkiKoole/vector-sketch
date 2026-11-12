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
- [ ] **LO2. Gravity compensation**, so the motors can be soft and the bob deeper (MM8).
- [ ] **LO3. Steps by distance, the stride by leg length** (MM3's "stride by the leg's length").
- [ ] **LO4. Capture point**: stop in a step, turn round (MM4), a recovery step when bumped.
- [ ] **LO5. Raibert hop**: hops even and steerable, landing where it means to.
- [ ] **LO6. Foot IK on the ground**: steps and slopes (MM5).
