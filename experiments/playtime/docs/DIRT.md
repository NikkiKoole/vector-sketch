# Dirt — Mipos getting dirty and clean again, by shader

status: active — a spike: paint baths, drips and prints on the floor added 2026-11-14 (Nikki: "a drip, footprints/markings, another color paint bath ... can it mix, can you use mipo as paintbrush"); kept as a spike before that (2026-11-13)

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
- Keys: x sponge, m all muddy, c all clean, g wipe the floor, space the original, n a new Mipo, h panel.

### Paint, drips, prints (2026-11-14)

- **Paint pots**: red, yellow, blue, between the mud and the tub. A mask is now two canvases: the pigment as
  *absorbance* (premultiplied, /4 to fit 8 bits) and its amount; and wet + how much of it is paint. Dipping
  blends the bath's absorbance over what's there by how long, so paints mix the way paint does (yellow then a
  short blue: green; red and yellow: orange; all three: brown), not to grey as plain colours would. Mud is
  a pigment too (the panel's pick), so paint over mud goes dirty. Paint looks smoother than mud: less grain,
  no cracks, a broad gloss while wet.
- **Drips** (`scripts/spikes/paint-marks.lua`): a part just out of a bath drips for 2.5 s, fewer and fewer,
  from its lowest point, in its colour (clear water drops too); drops splat on the floor or vanish in a bath.
- **Prints**: the floor is a strip canvas along the ground's top. A wet, dirty part touching it leaves a mark
  as wide as the part (feet: footprints); dragged along it, a mark every 'smear step' px, so a Mipo is a
  brush. Each print wipes paint off the sole (a wash pass below the floor line, on the mask and the CPU copy),
  so footprints fade out over the steps and a stroke runs dry. Dry mud doesn't print.
- The CPU keeps a rough copy per mask (load, absorbance, paint share) for the drips' and prints' colour.
- Side view: the floor is seen edge-on, so prints are a band along the ground's front, not a painting you
  look down on.
- The face gets dirty too (nose, lips, brows, cheek decals), all but the eyes and pupils. Left clean: the inside
  of the mouth (its backdrop sets a shader of its own, which would smear the paint; teeth, tongue) and face patches
  (their own shader too).
- Head hair: the strip along the head's outline (`trace-vertices`) has its own UVs, so it's a part like the rest.
  Hair locks (`src/hair-locks.lua`) are one strip for all of a Mipo's locks sharing one picture's UVs, so they
  get one mask per haircut instead: a square around the head in the head's own space, painted by a quad, read by
  where each strand is drawn. Through a hook there, `state.hairWrap` (as `state.drawableWrap` for parts).
- A Mipo part's mask is keyed by name (Mipo id, part, subtype, label, rank by zOffset), not by its `extra`
  table: turning round (`switchFacing`, all the time while dragged) makes every part's `extra` anew, and the
  Mipo came out completely clean (Nikki 2026-11-13). zOffset alone isn't stable either: it changes with the facing.

`src/wet.lua` (MATERIALS MT6) is the older wet: up to 12 wet spots and a waterline, in screen space, for
the plasticine shader. It doesn't stick to a limb. This one does, per part.

## Next

- [x] D1. Nikki plays with it: kept as a spike, parked (2026-11-13)
- [x] D2. The face and head hair dirty too, the eyes clean (Nikki 2026-11-13)
- [x] D3. Drops falling off a part fresh out of a bath (2026-11-14); still open: wet mud running *down* a part
- [ ] D4. The water getting dirty as Mipos rinse in it (the tub's colour from the dirt washed off)
- [x] D6. Paint pots that mix, footprints, a Mipo as a brush on the floor (2026-11-14)
- [ ] D7. Nikki plays with the paint: mixing too quick (a dip covers what's there in ~1 s: 'soak')? prints
  readable edge-on, or a sheet to paint on (a wall, an easel) instead?
- [x] D5. Cost on the phone (`./playtime.sh bench device`): masks are 128² each, a paint pass per part in a
  liquid per frame
  Measured 2026-11-15 (Nikki: "y measure d5 on the phone"; iPhone SE 2, dirty, 20 Mipos, play mode, A-B-A): drawing
  through the masks is about free (20 clean or muddy, masks on or off: the same draw, ~14 ms as the phone warmed;
  520 masks, two 128² canvases each, ~65 MB). Painting is the cost: every part of every Mipo is painted into its
  mask every frame (~470 paintPart a frame), ~44 ms of the scene's update: 15 fps with five in the mud bath. (A
  first run said 4 fps: 'm' fills every mask for two frames counted in update, and with the world paused that
  never ran out.) Found on the way: the builds didn't pack a scene's helper modules (fixed, 1ba83735).
- [ ] D8. Paint only what changes, before it can land: parts in a bath or under the sponge, and the drying ones;
  the rest keep their masks (D5: painting every part every frame is ~2 ms a Mipo on the phone).
