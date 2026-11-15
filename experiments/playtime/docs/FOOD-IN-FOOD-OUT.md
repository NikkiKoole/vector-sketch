# Food in, food out — eating, drinking, peeing, pooping

status: active

Nikki (2026-11-11): "i have a feeling on 'eating/drinking' and well pissing pooping". Not tried before
(`./playtime.sh tried` eat / drink / poop / pee / potty: nothing). Small kids love it, and the Sago / Toca
kind of app leans on it. Most of the pieces already exist in the engine or a spike.

## The idea

- **In: eating.** A piece of food dragged near a Mipo: the mouth opens as it comes close (the mouth
  shapes, `src/mouth-shapes.lua`), it bites (a chomp, a crumb or two), chews with full cheeks, swallows.
  Big food takes a few bites, and each bite takes a piece off the food.
- **In: drinking.** A cup of real water (`src/liquid.lua`) tipped at the mouth: the level goes down,
  gulp sounds, sometimes a drip down the chin.
- **Inside.** A belly that fills: the soft torso lobes (`src/torso-lobes.lua`, SOFT-TORSO) a little rounder
  and wobblier with each bite. After a while it needs to go: a wiggle, crossed legs, a look ("hmm",
  the voicebox grunts), the face from `src/mipo-emotion.lua`.
- **Out.** Poop as a soft physics blob (`src/blob.lua`, the softbody sfixture), pee as a small stream of
  water (seaside's pouring / `src/fluid.lua`). A potty or a bush for it, relief on the face and an "ahh",
  the belly back to normal. What's left can be picked up, flushed or buried (one of these, not all).
- **Tastes.** Food a Mipo likes and food it doesn't: a happy squeak, or a "blah" and spitting it out
  (EMOTIONS EMO2, feelings from play).

## Steps

- [x] **FO1. The spike** (2026-11-16): `scripts/spikes/food.playtime.lua` (`./playtime.sh start food`). One
  Mipo (0.6, soft torso on), a table with an apple, a cookie, two berries and a sprout, a cup, a potty.
  - Eating: a food near the mouth opens it (A_I, a little wider, by nearness; 'opens at' slider), and food
    near a face passes in front of it (the Mipo's collision group) so it can reach the mouth. At the mouth:
    snap shut, a crunch, crumbs, a piece off the food (the same body, smaller, so a drag carries on; gone
    on its last bite), chew with full cheeks (mmm, stretched across, three munches a second), gulp, happy
    and a hum. The sprout: one chew, "blah", angry, the bite spat out (gone after 6 s).
  - Drinking: a cup with water near the mouth makes an O; tipped, what spills over the rim near the mouth
    is drunk instead of poured (new `state.liquidDrinkHook` in `src/liquid.lua`), so the cup empties as fast
    as it's tipped, with gulps.
  - The belly: what's in pushes the lower torso lobes out and down (a force on each lobe against its
    springs, the torso pushed back as hard, so it can't tip the Mipo), gliding in. Lengthening the springs
    instead hardly showed, and a sudden full belly that way tipped a Mipo over.
  - Out: what's in turns into poop and pee (digest slider; a full belly ~30 s). Needing to go: a wiggle,
    a worried face, a hum every few seconds. Put on the potty: a stream of drops, then a brown blob
    (`props.makeBlob`) into the potty, a plop, happy, "ahh". `c` clears it away, `f` fills it up to try.
  - The mouth is the scene's while eating: `instance.mouthTakenBy`, which `src/mipo-emotion.lua` and the
    voice's mouth flap now leave alone (the hook FO3 needs anyway). Sounds made in the scene (crunch,
    munch, gulp, plop), nothing loaded.
  - Not done: it stands on the potty, doesn't sit; the food is drawn by the scene over a greybox circle,
    bites shrink it rather than take a notch; drinking stops when the cup's water has gone below the rim.
  Tried by bridge only (a second game on port 8002), not by hand.
- [ ] **FO2. Nikki plays with it**: keep, change or park.
- [ ] **FO3. Into the engine** (ENGINE-MERGE EM8 / a behavior): food as shelf things that can be eaten,
  a Mipo's belly and need in the Mipo itself, not in a scene script.

## Not in this plan

- Breasts and genitals that jiggle (Nikki asked 2026-11-11, "cutesy, like lobes"). Claude's advice: not
  in an app for small kids. Jiggle on those is what reads as sexual whatever the intent, and the App
  Store's Kids category would turn it down. The same lobes on bellies, bums and cheeks give the squishy
  feel; the belly that fills (above) is one. Nikki's call, not decided.

## Where it touches

- `SOFT-TORSO.md`: the lobes, the belly
- `EMOTIONS.md`: the faces, feelings from play (EMO2)
- `VOICEBOX.md`: grunts, a chomp or gulp could be made on the voice
- `WATER.md`, `SEASIDE.md`: the cup, pouring
- `PLANTS.md`: Mipos eating a berry was already an idea there
