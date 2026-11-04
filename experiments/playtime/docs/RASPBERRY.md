# Raspberry — a Mipo sticks its tongue out and blows

status: parked — kept as a spike in its own scene, `raspberry` (tried 2026-11-04: placeholder tongue and sound, waiting for a drawing and a recording)

**Started:** 2026-11-04, Nikki: "i like the idea of them blowing rasperries". A spike: the tongue
and the sound are placeholders, made in code, until there's a drawing and a recording.

How it works (`src/mipo-raspberry.lua`): `raspberry.blow(instance)` presses the lips together
(a line through the mouth's corners, a small gap in the middle), slides the tongue out, shakes
the lips against each other while a pbbbbt plays, then pulls the tongue back in. It runs on the
face's thing like the voice's mouth flap (`mouthShapeVec`, plus `tongueOut` and `tongueBuzz`),
so nothing is saved. The tongue is a `mouth-tongue` drawable from the lower lip decal, over the
lower lip and under the upper one (`src/render/mouth.lua` drawTongue). The Mipo editor's
actions have a raspberry button, and scene scripts get `mipoRaspberry`.

The scene `raspberry` (`scripts/spikes/`, `./playtime.sh play raspberry`): three Mipos on a
floor; space: all of them one after another, 1-3: one, r: new Mipos, tap a Mipo: it blows.

- [x] **R1. The spike.** Lips, placeholder tongue, generated pbbbbt, editor button (2026-11-04).
- [ ] **R2. The tongue picture.** Nikki's drawing in place of the code one (THINGS-TO-DRAW A9).
- [ ] **R3. A recorded raspberry.** In place of the generated sound; a few, picked at random,
  pitched per Mipo like the squeaks (`assets/voices/fx`?).
- [ ] **R4. When they do it.** Something that asks for it in play: a poke in the belly, an idle
  now and then, at another Mipo. Not a key (scene scripts use most of them).
- [ ] **R5. Spit.** A few drops off the tongue at the end.
