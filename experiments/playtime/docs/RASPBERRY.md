# Raspberry — a Mipo sticks its tongue out and blows

status: parked — kept as a spike in its own scene, `raspberry` (tried 2026-11-04: placeholder tongue and sound, waiting for a drawing and a recording)

**Started:** 2026-11-04, Nikki: "i like the idea of them blowing rasperries". A spike: the tongue
and the sound are placeholders, made in code, until there's a drawing and a recording.

How it works (`src/mipo-raspberry.lua`): `raspberry.blow(instance)` first closes the mouth (the
lips pressed onto a line through its corners), then slides the tongue out from under the teeth
(the lips part a little in the middle to let it through; the teeth are drawn again over the
tongue), a beat, the lips shake against each other while a pbbbbt plays, the tongue goes back
in and the mouth opens again (Nikki: close first, then the tongue, then the rasps).
Every raspberry rolls its own: how far the tongue comes out (`reach`), how quick it comes, a
short, medium or long buzz (`buzzKinds`), and now and then a slow pull back in (`slowIn`); the
pbbbbt is one long sound faded out where that buzz ends. It runs on the
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
