# Sea — realistic water in the hand-drawn world

status: parked — kept as a spike: "looking pretty good" (tried 2026-11-03: realistic water around drawn Mipos)

**Nikki's favourites** (2026-11-04): of all the spikes (sea, clouds, burrow, materials, cellophane), the sea, the burrow and the clouds inspired her most. Hand-drawn assets come first from now on; these are where a shader earns its place.

The question (2026-11-03): what if water in Mipo's world isn't hand-drawn but looks real, a
photographic sea around drawn Mipos and props? The spike is `scripts/spikes/sea.playtime.lua`
(scene `sea`): a lagoon seen from the side, beaches at both ends.

How it's made:
- **The world draws into a canvas** (from `drawBelow` to `draw`), then the water draws over the
  part under the surface with one shader: what's under it is bent (refraction), red goes first
  and then green with depth (Beer-Lambert), caustics light the things in it (and the sand),
  slanted light shafts, a sheen and a bright line just under the surface, foam where it's stirred.
- **The surface** is 280 columns with the wave equation (splashes run out and come back off the
  beaches), plus a swell of three travelling waves at deep-water speeds, with a bit of the second
  harmonic so crests are sharper than troughs. The swell fades out over the shallows.
- **Floating**: each fixture is clipped by the surface line under it; the push is mass-relative
  (works at any size, see the light-Mipos note) and goes in at the middle of the wet part, so a
  boat rights itself. Drag goes against the water's own up and down, so floaters ride the swell.
  Props float lighter than Mipos (`LIGHTER`).
- **Behind the surface** a band of far sea up to the horizon, with streaks and the sun's glitter;
  a sky with sun and clouds in a shader. Sand and kelp are drawn in the canvas, so they're
  bent, tinted and lit like everything else.
- Splash drops going in and out, bubbles going in.
- Round two: a silvery underside to the surface mirroring what's below, depth blur, red and
  blue bending apart (desktop only), specks in the water, sun glints along the surface line.
  The far sea stops at the surface line now: running 80 under it, the water showed it as a
  pale strip with a blue edge (Nikki didn't like it), and the bending never pulls from above.

Panel sliders: swell, density, drag, clarity, refraction, caustics, rays, mirror, blur, specks.
A second desktop game next to a running one: `PLAYTIME_BRIDGE_PORT=8002 love . --bridge --play sea`.

Not done / open:
- [x] On the phone (iPhone SE 2, 2026-11-03): 60 fps, frame p95 17.4 ms, none over 20 ms, with
      the two starting Mipos (`PHONE` in the script: one caustic sample, no colour fringes).
- [ ] The seam: a lazy texture bake during the world draw (a new Mipo) resets the canvas for a
      frame (`omp-bake` calls `setCanvas()`); restore the caller's canvas there if it shows.
- [ ] Sand below the water's bottom edge is drawn plain (a cut-away look); decide if that's right.
- [ ] Mipos have no swimming; they stand in the water at density 1.6 or hang at 1.

## The drawn sea (tried 2026-11-04): this sea with `boat`'s drawn one, "looking promising"

`scripts/spikes/drawn-sea.playtime.lua` (scene `drawn-sea`): the best of this spike and the
`boat` scene's sea (walter-boat's flat bands, `BOAT.md`), with boat2's plank boat on it.
- From here: the wave columns and swell, real floating (wet part of each fixture, at its middle),
  splashes, drops, bubbles, and the water shader (bending, depth tint, caustics, shafts, specks,
  the silvery underside); the world goes into a canvas from `drawBelow` to `draw`.
- From `boat`: flat drawn bands in layers (far ones with only the swell, the water just behind the
  boat), the world flowing past with the speed (the columns are moved along, so a splash or a Mipo
  overboard drifts behind), an engine holding the boat in place so speeding up makes it surge.
  `o` switches the shader off for the drawn bands (a see-through near band, a deep band).
- New: the boat floats by its wet *area*, not its mass (it has ballast: heavy bottom rows, light
  planks above; mass-based floating lifted the ballast out and it rode on its keel; without
  ballast it capsized), sized to sit about 40% deep. Far bands stop at the near surface under the
  shader (running under it, the caustics lit them up like a wall).
- The waterline: a smooth glassy line with a glow and a foam sheen that fades down; Nikki's crayon
  line on `c` (it looked weird over the shader: beads of foam and a crayon stroke). Drops are
  see-through, stretched along their flight; the black-rimmed drawn drops didn't work.
- Left: no seabed (the depths go dark), fish swim deep and come out small; not on the phone yet.

