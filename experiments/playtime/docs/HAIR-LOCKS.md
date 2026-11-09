# Hair locks — long hair that swings

status: active — picked up again 2026-11-09: fixed, haircuts and pijpenkrullen ("those look great!"); now its cost. (2026-10-31 it was parked for the tufts route, below)

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
- [ ] H4. Measure on the phone (`./playtime.sh bench device`)

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
