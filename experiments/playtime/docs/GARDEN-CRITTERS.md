# Garden critters — simple animals next to the Mipos

status: parked — kept as a spike: "happytime!" (tried 2026-11-05, scene `garden`); fish and turtle still to do

Critters much simpler than Mipos: a handful of bodies, one way of moving, eyes that follow you.
All in one scene script, `scripts/spikes/garden.playtime.lua` (`./playtime.sh play garden`): a
lawn, four flowers, a Mipo, and a spawn bar (`+ worm`, `+ bee`, … in two rows; keys 1–9, 0 at the
mouse; everything drops in from up high). `h` shows a panel of sliders for every number below.

## The critters and what they're made of

| | bodies | moves by | looks |
|---|---|---|---|
| **worm** | 10 circles on soft distance joints | a squeeze wave + grip against sliding back; rears up to look, rears over to turn | Mipo leg-05 (the ringed one) laid along the chain; pupils |
| **snake** | the worm's code, 18 tapering segments | the same (snakes concertina), quicker; rears like a cobra; a forked tongue | Mipo leg-02 in green with a scribble |
| **bee** | 1 circle, no gravity | steering to flowers and to you; thrown it flies off and catches itself; the body leans with its flight | OMP patch-01, yellow, `bee-stripes.png`; chesthair-01 fuzz behind; Mipo ear wings (`w` cycles); Mipo pupils |
| **butterfly** | 1 circle, gravity on | each flap a kick towards its flower; sits on flower heads; flies off when you come close | front view, ear-04 wings widened, 4 colourings; body-14 body, patch-01 head, Mipo pupils |
| **ladybird** | 1 dome | sticks to what's under it (walks up walls, onto Mipo feet); on its back it kicks and flips; flies off | OMP body-16, `ladybird-spots.png`; drawn legs. Nikki: "a bit too fine and detailed" |
| **spider** | round body + 6 legs (thigh + shin each) | a standing spring, feet pulled to spots, two tripods; freezes when you come close, then scuttles | OMP patch-01; legs Mipo leg-01; size of a Mipo head |
| **dog, cat, giraffe** | two torso halves on a waist hinge, 4 legs, a Mipo head, ears, a tail chain; the giraffe a neck chain | muscles only: hip motors hold the legs straight (it stands like a table) and swing them in diagonal pairs; KEEP_ANGLE on the halves; a gentle push while a foot is down | the garden Mipo's head, skin and real face (`mipoTextures.addFaceDecals`); one body picture bent over both halves; tail = rope in the Mipo's arm colours; giraffe: own yellow skin with the ladybird spots, horns |
| **walker** | a Mipo head on two rope legs (thigh + shin) | hip and knee muscles, legs in turn; KEEP_ANGLE on the head; walks either way, no turning | the Mipo head and face; legs the rope in the Mipo's leg colours |
| **chicken** | the walker's legs under a round body, a head on a neck joint | the walker's walk; pecks (the neck muscle swings the head down) | OMP body-03 white, orange leg-02 legs with toes, comb, wattle, beak, a wing; facing is drawing only |

## What Nikki liked and didn't (2026-11-05)

- **No magic on the ones with bodies.** The dog's turn-round (rebuilt mirrored with a hop) and its
  standing spring (it floated down when dropped) went: "just let it be physics object". Muscles
  (joint motors) and KEEP_ANGLE are fine. The bee's somersault after a throw was "too fake"; a
  lean with its flight was better. Catapulting the bee across the garden: too much.
- Mipo pieces instead of drawn shapes: the Mipo pupils, ear pictures as wings, leg pictures as
  skins and tails, the Mipo head on animals.
- The ladybird felt too fine; the worm and the bigger, simpler ones felt better.

## Things to know

- A scene script has no `type` or `select` (the dog's first turn-round died on `select`).
- Mipo masks keep their shape in red, not alpha: bake them (`ompBake.makeTexturedCanvas`, from
  update, never from draw) before drawing them yourself.
- OMP patterns don't repeat: turned or scaled up past 1 they clamp to the picture's edge (the bee's
  first stripes vanished). Bake upright patterns; scale them below 1.
- A Box2D contact keeps the friction it began with: after `setFriction` call `contact:resetFriction()`.
- leg-01 is one solid stroke: as a skin it comes out all outline (near black). leg-02 shows the fill.
- Dogs, cats, giraffes and walkers have a head labelled `head` (so src/mipo-face.lua blinks it);
  they're found for cleaning up by their collision group (`sweepKind`), not by label.

## Still to do

- [ ] **GC1. Fish** — needs water: a pond in the garden, or in the sea / boat scenes.
- [ ] **GC2. Turtle** — the four-legged kit with a dome shell; tap it and it pulls in.
- More from the brainstorm: hedgehog, crab, mouse, bird, caterpillar, frog, snail, jelly-floater,
  balloon critter, pebble-stackers.
