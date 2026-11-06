# Bike — a Mipo riding down a hill, a knikkerbaan to watch

status: idea

A Mipo on a bike rolling down a hill by itself: the child just watches it go, like a
knikkerbaan (marble run). No buttons in the game (Nikki 2026-11-06: "def no in game buttons
like I had in the downhill experiment"). Spike: `scripts/spikes/bike` (`r` a new Mipo).
After physics-testbed's downhill (`experiments/physics-testbed`, `docs/REBUILD-IN-PLAYTIME.md`).

## What's there (2026-11-06)

- **A real physics bike**, two wheels and a frame (heavy: a big-bodied rider tipped a light
  one over), sized from the Mipo's height: wheels 0.2 of it, wheelbase 0.7 (sized from the legs
  alone it was "way too small", at 0.3 / 1.0 too big). A little linear damping as air: without
  it the bike reached ~2900 a second at the bottom.
- **The rider** faces right (docs/MIPO-FACING.md: facing a side, hips swing forward, knees bend
  back), held at the saddle (soft weld), hands on the bars, torso kept upright on the bike (its
  KEEP_ANGLE aims at the frame's angle).
- **Pedals drawn, legs by muscle**: the crank turns with the back wheel (half its speed); each
  frame the knee is placed where a thigh and a shin of the Mipo's lengths meet between hip and
  pedal (knee forward), and the leg KEEP_ANGLEs aim there; feet held flat, hips 35 degrees of
  room behind. The legs follow within ~3 degrees.
- **Drawn**: tires as a ribbon of the rider's own composed leg picture (its middle part,
  mirrored back and forth: the rounded ends left gaps), spokes, a tube frame, the course line.
- **The course**: one long downhill with humps, a rise at the end to run out on; at the bottom
  the bike is put back at the top (for now).

## Tried

- tried 2026-11-06: **feet pinned to physical pedals.** Hip, knee and pedal make a closed loop
  with a dead spot: geared to the back wheel the jammed legs locked the wheels (it slid down);
  with a pedal motor instead, the pedals stalled or, turning, pushed the bike over backwards.
  Sizes from the knee's reach (90 degree stop) helped but stayed fragile with every Mipo build.
- tried 2026-11-06: **a balance bike** (feet on footrests): rode stably; pedals wanted back.

## Next

- [ ] **K1. The lift.** At the bottom a lift carries bike and rider up to the start again, so the
  knikkerbaan runs on its own (instead of being put back).
- [ ] **K2. The course as a knikkerbaan**: pieces, drops, a jump; more than one rider.
- [ ] **K3. The look**: a drawn bike (Nikki's drawing), the ground and sky (WORLD-BUILDING).
