# Weather — rain, storm, fog, snow, wind, heat, and the air in between

status: parked — Nikki parked it right after the spike was built, not played with yet (tried 2026-11-06: rain, storm, fog, snow, wind, heat over one hillside, scene `weather`)

Weather as one state that the whole scene reads: the sky, the light, what falls, what blows, and
how far you can see. Started 2026-11-06 (Nikki: "atmospheric shader stuff for weather etc", "also
heat", and haze by depth "especially here" on the tracks' layer change).

## What's there already

- **Clouds** (`CLOUDS.md`, parked, "pretty good"): shader clouds, the real kinds at their heights,
  weathers on `w` (fair, mackerel, grey, storm), shake one and it rains, near ones shade the grass.
- **Sky** (`../sky-atmosphere/`, WORLD-BUILDING G5): one sky from the ground to space, night, dawn,
  day and dusk blended.
- **Day and night** (LIGHT-AND-SHADOW LS10, in `light-grass-check`); LS21 cloud shadows and LS13
  light as a scene setting are open there.
- **Haze by depth**: `tracks` (`hazed()` toward one fixed colour per layer), `depth`.
- **Wet** (`src/wet.lua`, MATERIALS MT6): wet spots on a body that dry; the plasticine shader shows them.
- **dreamengine `weather.c`** (`HARVEST-NAVKIT-DREAMENGINE.md` 1h): a 7-state weather machine with
  weighted moves, a wind that eases between targets, and effects that come out of state (rain makes
  things wet). Surveyed, nothing taken yet.

## The idea

- **Amounts, not states.** Rain, snow, fog, wind, heat, clouds and storm are each 0..1 and ease
  toward a target; a "weather" is just a set of targets. Fog with a bit of rain is fine, and a change
  is a slow blend, never a cut (`feedback: smooth blends`). A weather machine after `weather.c` picks
  the next targets now and then.
- **Drawn first, a shader only where it earns it** (SHADER-LOOKS): rain streaks, snowflakes, leaves,
  wind swirls, fog banks, are drawn. Heat shimmer is the exception: bending what's behind needs the
  scene in a canvas, as the sea does (SH3, the effects stack).
- **Effects out of state**: rain wets the ground, Mipos and puddles; heat dries them and melts snow;
  snow settles round the Mipos' feet; wind pushes light things (Mipos, leaves, grass) more than heavy ones.
- **The air is one colour and one thickness.** Haze by depth, the fog between layers and heat's pale
  distance are the same thing: things further back fade toward the air's colour, more in fog, a
  little in heat, dark at night. One `haze(colour, depth)` that every depth spike asks (tracks, depth,
  the hills here) instead of each its own constant. In tracks it slots into `hazed()` (already per
  point; the colour steps Nikki saw on the curve into layer B were the drive tints, blended since TR5d).

## The weathers

- **Rain**: slanted streaks by the wind, some behind the Mipos and some in front; splashes; the
  ground darkens; puddles fill and ripple; wet spots on Mipos.
- **Storm**: rain at full, dark sky, gusts, lightning (a flash and a bolt).
- **Fog / mist**: veils between the depth layers, drifting banks low over the ground in front.
- **Snow**: flakes that wobble down and drift; a layer that grows on the ground round the feet, melts in heat.
- **Wind**: gusts that bend the grass, carry leaves and push light bodies; swirl lines in a gust.
- **Heat**: the air shimmers, most just above the ground; a mirage strip on the ground (the sky
  mirrored, the "water on the road"); the distance pales; grass yellows; puddles dry, snow melts.

## Steps

- [x] **WE1. The spike** (2026-11-06): `scripts/spikes/weather.playtime.lua` (scene `weather`), all
      of them over one hillside, a panel of amounts (they ease over `blend` seconds), keys 1-7 for
      the weathers, `a` the machine. Rain and snow in two depths (behind and in front of the Mipos),
      splashes, puddles that fill, ripple and dry, the ground darkening; snow settling round the
      feet; leaves, swirl lines and grass in the wind, which drags on bodies by their size (`push`;
      walls at the world's ends); fog as veils between the hills and drifting banks; lightning;
      heat as the one shader (the scene in a canvas, shimmer strongest just above the ground, a
      mirage strip under the ground line). The light (darker in rain, warm in heat) is a multiply
      over everything, Mipos too. Wet spots on Mipos in rain go through `src/wet.lua` and only show
      on lit Mipos. 60 fps on the desktop in a storm.
- [ ] **WE2. Nikki plays with it**: keep, change or park, per weather.
- [ ] **WE3. Haze by depth as one thing**: a `haze(colour, depth)` from the weather, used by
      tracks and depth; smooth across a layer change.
- [ ] **WE4. Cost on the phone** (`./playtime.sh bench device`): the heat canvas, rain and snow counts.
- [ ] **WE5. Sound**: rain, wind, thunder from the synth's noise.
- [ ] **WE6. Weather as a scene setting**, with LS13 (light) and the clouds and sky as its looks.

## Open questions

- Per scene, or a world weather the rooms share (indoors you hear it on the window)?
- Does the music follow it (WORLD-AND-MUSIC)?
- Play: what can a kid do with it? Drag a cloud to rain (CLOUDS), blow, a thermometer to turn?
