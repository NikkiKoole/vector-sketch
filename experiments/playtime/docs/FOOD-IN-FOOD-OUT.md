# Food in, food out — eating, drinking, peeing, pooping

status: idea

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

- [ ] **FO1. The spike**: one scene, one Mipo, a few foods, a cup, a potty. Eat, drink, belly, go.
  Read first: the mouth (MOUTH-* docs), SOFT-TORSO, `src/blob.lua`, `src/liquid.lua`, seaside's pour.
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
