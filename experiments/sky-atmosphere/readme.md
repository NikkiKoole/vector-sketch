# sky-atmosphere

Can one sky hold the horizon, day and night colours, and black space, all the way up to the moon?
A test before it goes into Playtime (`playtime/docs/WORLD-BUILDING.md` G5).

- `palettes.lua`: the sky as colour stops over altitude, one palette per time of day (night, dawn,
  day, dusk) sharing the same stop positions, plus the day's timeline. Edit it, press `r`.
- The sky is a shader: each pixel takes its altitude from the camera and looks up its colour.
  Palettes blend stop by stop in linear RGB, the same idea as `../skies/SkyGradient.lua`.
- Stars fade in with the night and with altitude, so space is starry at noon too.
- Gravity fades out above the atmosphere. Near the moon, the moon pulls.
- The moon is small in the sky from the ground, and slides into the real (physical) one as you climb.

Run: `love .` here. `love . --selftest` sweeps the day and flies the Mipo up, then prints and quits.
Keys: drag anything up (hold near the top of the window to keep climbing), left/right = time,
t = let time run, 1-4 = night/dawn/day/dusk, wheel = zoom, space = Mipo back down, r = reload palettes.
