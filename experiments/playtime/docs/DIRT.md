# Dirt — Mipos getting dirty and clean again, by shader

status: parked — kept as a spike (Nikki 2026-11-13: "ok keep as spike"); the next steps when it comes back are below

Nikki (2026-11-13): Mipos getting dirty, not like the Bathhouse's mud balls (APP-1-BATHHOUSE-PLAN.md,
`mudready`) but with shaders: each limb dirty on its own, and parts of a limb too. Put a Mipo in dirty water
and you should see how high it went in. And it can be cleaned.

## The spike (2026-11-13, scene `dirty`)

`scripts/spikes/dirt-look.lua` is the look (a module from the start, its sliders in `lib.tuning`);
`scripts/spikes/dirty.playtime.lua` is the scene: soil, a mud bath (left), a tub of clean water (right),
three Mipos.

- **A dirt mask per part, in the part's own picture space (its UVs).** That's why the dirt stays on the
  part: a leg dipped in mud keeps its mud line where it was, tilted with the leg when it swings. One 128²
  canvas per part: red = how dirty, green = how wet. Works the same for pictures (torso, feet), ribbon limbs
  (arms, legs, hair) and anything else drawn with its own UVs.
- **Painting** draws the part again, into its mask, through a shader that lays it out flat by its UVs
  (each vertex goes to its UV) but still knows where each pixel is in the world. So "below the mud's
  surface" (with a wobble along the line) or "under the sponge" is decided in the world and written where
  that pixel lives on the part. Done in update, outside the frame: switching canvases in the middle of
  drawing (the frame goes into water-look's canvas) cost ~15 fps.
- **Mud** soaks in below the surface ('soak'), and the part is wet. **Clean water** rinses ('rinse').
  **The sponge** (hold x, or 'sponge on the mouse') scrubs where you rub ('scrub', 'sponge size').
- **The look**: mud in splotches where it's thin, covering everything where it's thick ('splotchy'); grainy
  and clumpy ('grain', 'grain size'); a darker tide mark where it ends ('tide mark'); wet mud is dark and
  glints ('wet shine'), and it dries lighter and cracked over 'dry in (s)' ('dry cracks'). The drawing's dark
  lines still show through ('drawn lines'). Four muds: mud, clay, peat, paint.
- The engine draws every bath as see-through water (`src/water-look.lua`, which ignores the liquid's colour),
  so the scene takes the mud bath out of that list and draws it opaque itself.
- Keys: x sponge, m all muddy, c all clean, space the original, n a new Mipo, h panel.
- The face gets dirty too (nose, lips, brows, cheek decals), all but the eyes and pupils. Left clean: the inside
  of the mouth (its backdrop sets a shader of its own, which would smear the paint; teeth, tongue) and face patches
  (their own shader too).
- Head hair: the strip along the head's outline (`trace-vertices`) has its own UVs, so it's a part like the rest.
  Hair locks (`src/hair-locks.lua`) are one strip for all of a Mipo's locks sharing one picture's UVs, so they
  get one mask per haircut instead: a square around the head in the head's own space, painted by a quad, read by
  where each strand is drawn. Through a hook there, `state.hairWrap` (as `state.drawableWrap` for parts).

`src/wet.lua` (MATERIALS MT6) is the older wet: up to 12 wet spots and a waterline, in screen space, for
the plasticine shader. It doesn't stick to a limb. This one does, per part.

## Next

- [x] D1. Nikki plays with it: kept as a spike, parked (2026-11-13)
- [x] D2. The face and head hair dirty too, the eyes clean (Nikki 2026-11-13)
- [ ] D3. Drips: wet mud running down a part, and drops falling off it
- [ ] D4. The water getting dirty as Mipos rinse in it (the tub's colour from the dirt washed off)
- [ ] D5. Cost on the phone (`./playtime.sh bench device`): masks are 128² each, a paint pass per part in a
  liquid per frame
