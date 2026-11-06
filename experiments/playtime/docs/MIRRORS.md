# Mirrors — mirrors in the garden and a pond that reflects

status: parked — kept as a spike: "nice good spike!" (tried 2026-11-06, scene `mirrors`)

Nikki (2026-11-06): the reflective side of water. A scene with mirrors and water surfaces, plus
ways to break up a rippling reflection. Scene `mirrors` (`scripts/spikes/mirrors.playtime.lua`),
a spike. Separate from the fluid work (`seaside`, `waterjar`).

## How it's made

- **Layers.** The background (sky, hills, the wall, the ground) goes into one canvas, the bodies
  and Mipos into another. Together they're what the mirrors see. The mirror faces draw onto the
  background, then the bodies go over them, so a Mipo stands *in front of* the wall mirror. That
  whole picture is what the pond sees, so the pond reflects the mirrors too.
- **Mirrors** flip what's around them across their long axis. `zoom` makes one convex (the wall
  mirror shows a bit more than itself, the hand mirror more). The gazing ball's `fish` grows
  towards the rim (the whole garden in a ball). The funhouse mirror bends in and out along its
  length. Frames are rings, not panels, so a mirror doesn't show its own back. Off the screen
  there's nothing to reflect, so you get plain silver.
  The wall mirror, gazing ball and funhouse mirror are decor. The standing mirror and the hand
  mirror (`g`) are bodies: tip them, throw them, float them in the pond.
- **The pond** is the 2D-game kind of water mirror: depth d under the surface shows what's d above
  it, fading with depth (`fade`) into the see-through water (what's in it, bent and tinted).
- **Breaking it up**, three ways that add together:
  - wave columns: the surface line itself moves (splashes, stirring, bobbing things);
  - rings: one squashed circle per hit (seen at a slant, so they spread sideways more than down),
    a short wave train at the front. Splashes, skimming stones, pebbles, rain and dragging on the
    water all make them (at most 24 at a time);
  - wind: a choppy surface smears the reflection (several samples spread by the chop) and
    ruffles the line.
- Floating is the sea spike's (`float`, the clip under the surface line).

Keys in play mode: drag on the water to stir it, `k` skim a stone (from the mouse towards the
pond), `d` drop a pebble, `n` rain on/off, `m` a Mipo, `o` a ball, `g` a hand mirror, `r` reset,
`h` the panel (reflect, fade, ripples, wind, rain, clarity, zoom, wobble).

Gotcha: batched shapes (rectangle, circle, polygon) reach the vertex shader with their corners
already in screen pixels (LÖVE transforms them on the CPU), so a `wpos = vp.xy` varying is wrong
for them. The mirror and sky shaders work out the world point from `love_PixelCoord`, the view's
origin and the scale. Meshes (the water) keep world positions.

- [x] **MR1.** Nikki plays with it (2026-11-06): "nice good spike!", kept as a spike.
- [ ] **MR2.** Cost on the phone: three full-screen canvases and four reflection samples a pixel.
- [ ] **MR3.** Ideas, if it stays: a puddle that reflects (after rain), a Mipo that notices itself
      in a mirror (MIPO-FACING), a mirror in a room's back wall (WORLDS-AND-DOORS).
