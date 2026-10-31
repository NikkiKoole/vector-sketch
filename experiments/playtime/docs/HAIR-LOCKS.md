# Hair locks — long hair that swings

status: parked — "i dont really like this after all", kept as an experiment for dreadlocks or the like (2026-10-31)

A spike: locks of hair as chains of points rooted on the head, moved by a small verlet step of
their own (not Box2D) and drawn as ribbons with the hair pictures. `src/hair-locks.lua`, the scene
`hair` (a copy of spine-test) and `scripts/hair.playtime.lua` with a panel of sliders in play mode
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

## Hair bounce (also parked)

The other try the same day: the haircut strip as it is, its outer edge on a spring
(`src/hair-bounce.lua`, settings → hair bounce, off by default). Pushed by the head's
acceleration, sagging when tilted, pinned at the ends with the wobble in the middle (`focus`).
"this isnt it really either": too loose, and a whole haircut moving as one sheet. Costs nothing
when off (one call per haircut a frame).
