# Hair locks — long hair that swings

status: parked — Nikki 2026-11-09: "we are good with the hair" (tried 2026-11-09: locks that hang and swing, haircuts, ringlets, body hair, fur, a coat, the box); the phone (H4, H8): ~0.06 ms a Mipo with the hair in C (was ~0.3 in Lua)

A spike: locks of hair as chains of points rooted on the head, moved by a small verlet step of
their own (not Box2D) and drawn as ribbons with the hair pictures. `src/hair-locks.lua`, the scene
`hair` (a copy of spine-test) and `scripts/spikes/hair.playtime.lua` with a panel of sliders in play mode
(count, length, stiffness, droop, curl, wild, damping, width, spread, picture, front locks, bangs).

What it does: back locks drape over the head (an oval its size) and hang behind the Mipo; the
outermost ones and short bangs draw over the face. Stiffness acts at the root and fades to nothing
at the tip, and each lock leans toward its own side, so hair falls instead of balancing on top.

Why parked: with the existing hair pictures (thick black outlines) a dozen locks read as a black
mass, not hair, and long hair mostly hides behind the body. Left open if it comes back:

- Own lock pictures: straight, thin outline, tapered tip, no drawn-in light (OMP: lockN + mask)
- The locks in the Mipo's own z-layers (now: back under everything, the floor too; front over
  everything, other Mipos too)
- Locks lying on the torso and arms, not only the head
- Its cost on the phone (not measured; guess 1–1.5 ms for 20 Mipos with 10 locks each)
- Dreadlocks: fewer, thicker, stiffer locks are probably where this fits best

## 2026-11-09: fixed, haircuts, ringlets

Why the locks spun instead of hanging, three causes: the step followed the frame time (uneven
frames flung points: now fixed 1/120 s steps); curl pulled each segment relative to the chain's
current one, a one-sided pull that wound the locks round (now a rest shape fixed on the head);
and follow-the-leader counts each length fix as speed, so the tips whipped ("an aggressive
octopus": DFTL, Müller 2012, gives half of it back to the point before). Gravity on the hair is
`weight` (3): at 1 the stiffness held the locks out like a fountain.

New sliders: `stand`, `curly` (a wave held tip to root by both-way pulls between points two
apart), the haircut (`cut`: a blunt line below the head; `lenMiddle` / `lenSides`; `part`), and
pijpenkrullen: `ringlets` (radius), `ringletPitch`, `springy`. A ringlet is its axis simulated as
a springy chain and a corkscrew drawn around it, the back of each turn darker; the turns follow
the rest length, so a stretched ringlet opens up. Big radius, long pitch, thin strand and fewer
locks read best (r 16-20, pitch 45-60, width 0.03-0.04, 8-10 locks).

Locks are drawn as strips of their own (Catmull-Rom through the points) instead of the ribbon's
one Bezier, which smoothed curls away. Cost per Mipo on the Mac: simulate 0.1-0.35 ms; draw 1.4 ms
(17 locks + 10 bangs), 3.4 ms (tight ringlets), against 0.09 ms for the old ribbon in C.

- [x] H1. Build each strip once, draw it twice (fill, line) with the picture swapped
- [x] H2. Fewer samples: more only where a lock bends or turns (1 a segment straight, up to 5 in a bend; ~10 a ringlet turn)
- [x] H3. The strip in C, like the ribbon's native strip: `native/desound/hair.c` via
  `src/hair-native.lua`, the Lua path kept for the web and stale libraries (`spec/hair-native_spec.lua`:
  both the same). Per Mipo on the Mac, simulate + draw: plain 1.6 -> 0.80 (H1+H2) -> 0.46 ms (C);
  tight ringlets 4.0 -> 2.2 -> 0.44 ms; loose ringlets 1.5 -> 0.88 -> 0.29 ms. About 0.2 ms of
  that is the simulation, still Lua
- [x] H5. Asleep: settled hair on a head that holds still isn't simulated nor built again (0.006 ms
  a Mipo, from 0.35). Rarely asleep in practice: an idle Mipo shuffles and sways (its head 3-34 px/s
  in the hair scene), so it's for Mipos lying, sitting or held. "settled" is measured from where the
  points were a frame before: points - prev isn't the move, DFTL writes into prev
- [x] H6. One mesh a layer of a Mipo (back, front), the locks joined by repeated vertices: 4 draws
  instead of 54. Awake per Mipo: plain 0.35 ms, loose ringlets 0.23, tight 0.37, curly 0.32
- [x] H7. curly is drawn, not simulated: a wave across the lock (16 px at 1, one every 5 segments),
  like the ringlets. Held by the physics (pulls between points two apart) it fought the rest shape
  and the tips never stopped moving, 7 px a frame on a still head. Now every setting comes to rest
- [x] H9. No more jumping (Nikki: "a bit like retriangulating or jumping", with thick locks): H2's
  samples-by-the-bend changed a lock's sample count as it moved and its picture slid along it. Now 4
  a segment fixed (ringlets / waves as before), the picture's v by the rest length along the lock,
  and the width clamped in tight bends like the limb ribbons (a 78 px wide lock folded on its
  inside). Her defaults: 0.26 ms a Mipo awake on the Mac
- [x] H4. Measure on the phone (`./playtime.sh bench device`). 2026-11-10, iPhone SE 2, the `hair` scene
  + 19 Mipos (LIGHT-AND-SHADOW LS29's setup), each given the scene Mipo's locks (21 a Mipo), zoomed
  out to the room. Paused: drawing them +0.3 ms (11.9 -> 12.2), lit or flat the same. Running: the
  Mipos never sleep (breathing; 355 of 355 bodies awake), so no haircut sleeps either: update 7.2 ->
  15.0 ms (script.call 0.7 -> 11.3, the hair's step: ~0.5 ms a Mipo, twice the Mac's 0.26), draw 11.9
  -> 15.0 (the strips rebuilt every frame), 46 -> 31 fps. So 20 Mipos with long hair don't fit;
  a few do (~0.65 ms each).
- [x] H8. The simulation in C (~0.5 ms a Mipo awake on the phone, H4, all Lua). Or: hair small on
  screen not simulated (LS30's rule), fewer locks in a crowd
  2026-11-10, step 1: `hair_step` in native/desound/hair.c, the same maths as stepLock (all of a lock's
  steps in one call; the head's transform as cos/sin instead of getWorldPoint), via hairNative.step;
  state.hairStepLua = true: Lua. spec/hair-native_spec.lua: C and Lua within 0.05 px over 20 frames
  (hanging, springy + stiff, a bang, on the floor). (Its declaration has to be in hair-native's
  `local CDEF = [[` block: device.sh keeps only those functions on iOS, the linker strips the rest.)
  Phone, 20 Mipos x 21 locks, running, alternated twice: hairLocks.update 4.55 -> 3.1 ms. The C maths
  is cheap; the 441 calls a frame each copy the lock's points into FFI buffers and back, and with the
  JIT off every FFI element access is slow: that copying is most of the 2.6 ms left in the step.
  The hair's drawing is as much again (~4.5 ms: script.call ~9 ms in all): layerMesh copies each
  lock's points into C for its strip, and joins the strips vertex by vertex (copyVertex).
  Next: the points live in C, not in Lua tables: one FFI buffer per haircut (every lock's points and
  previous points), one C call a frame steps all its locks, one builds each layer's joined strip
  straight from it, and the settle check reads it there. Lua keeps the per-lock settings, the roots
  (bendRoots) and the Lua path for the web.
  Step 2, done the same day: a haircut's points live in C (hairNative.newCut: FFI buffers for every
  lock's points, previous points, settings and bends; hair.c hair_cut_step / hair_cut_settled /
  hair_cut_strip, sharing the per-lock step_core and strip_core). Made on a haircut's first update;
  state.hairStepLua = true copies the points back into the lock tables (Lua again), and reset makes
  the cut again. bendRoots writes the moved roots into it. Specs 14/14: the cut steps exactly as its
  locks one by one, its layer strip within 0.01 px of the per-lock strips joined.
  Phone, 20 Mipos x 21 locks, running, alternated twice (hairLocks.update / .draw timed): update
  4.1 -> 0.6 ms, drawing 1.8-2.2 -> 0.6 ms: the hair ~6 -> ~1.2 ms a frame for 20 Mipos (~0.06 a Mipo).
  (H4's "drawing as much again" was an estimate; timed, the strips were ~2 ms.)

## Hair bounce (also parked)

The other try the same day: the haircut strip as it is, its outer edge on a spring
(`src/hair-bounce.lua`, settings → hair bounce, off by default). Pushed by the head's
acceleration, sagging when tilted, pinned at the ends with the wobble in the middle (`focus`).
"this isnt it really either": too loose, and a whole haircut moving as one sheet. Costs nothing
when off (one call per haircut a frame).

## Hair tufts — the route

**When hair comes back, start here** (Nikki, 2026-10-31: "definitely leaning this direction";
needs more work).

The third try: a few tufts on top of the head as real Box2D bodies, short chains soft-welded like
the ears (`src/hair-tufts.lua`, `scripts/spikes/tufts.playtime.lua`: run it on a scene with Mipos, panel
in play mode). They collide with nothing (category 16, masked against all), are light (a share of
the head's density) and are drawn as ribbons through the chain, over the faces for now.
"still not a great success but the most promising": the motion is the ears' motion, which works.
Open:

- Drawn with the Mipo's own baked ear picture (`ear` 1, the default): the fuzzy ear (`earx2r`)
  reads as hair, in the Mipo's colours. Tuft pictures of their own can come from a drawing session
- Haircuts (`lib.haircuts`, the `style` slider): each tuft's place on the head and the angle it
  springs back to. spiky, mohawk, swept, pigtails, cowlick, fringe: first guesses, to tune
- Its place in the Mipo's z-layers (now over everything)
- In the DNA and the Mipo editor, saved and rebuilt like the ears (now only the script makes them)
- The cost: 2 bodies and 2 joints a tuft in Box2D (3 tufts: +6 bodies a Mipo)
