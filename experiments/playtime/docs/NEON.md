# Neon — Mipos that give off light

status: active

Nikki (2026-11-11): "seeing how we are doing these materials, i was outside and thinking, a neon, or light
emitting material?". Not tried before (`tried` neon / glow / emissive: nothing; the campfire has a real
flickering light, CAMPFIRE.md; scene lights are LIGHT sfixtures, LIGHT-AND-SHADOW).

## The spike (2026-11-11, scene `neon`)

`scripts/spikes/neon.playtime.lua`, on the drawing hook (`state.drawableWrap`, CUT-PAPER.md), a step further
than the others: the Mipos' drawables are held back from the world pass and drawn after it (`s.draw`), so
they can shine over a night:
- **night**: the world drawn so far darkened (a dark blue over it, 'night').
- **light pool**: a soft round glow added on what's around each Mipo, in its light's colour ('light pool',
  'pool size'): the wall and ground lit by it. Not a real scene light (a LIGHT sfixture would light lit
  parts properly, but it would be darkened by the night drawn over it too).
- **neon**: the drawing's own dark lines become the tubes, white-hot in the middle, coloured at the edge;
  the rest of the part dark glass ('glass').
- **glow**: the whole part shines, its light parts whitest.
- **halo**: soft glow past the outline: the part drawn again as copies a little bigger each, fading, added
  ('halo', 'halo size', 'halo layers').
- **hum / flicker**: a fast hum, and in neon now and then a stutter.
- Colours: the part's own (its colour at full brightness), pink, cyan, lime, orange, violet. The face drawn as
  it is, dimmed with the night.

First look: neon pink, a neon sign of a Mipo, its strokes as tubes, the wall behind pink; glow cyan, a ghostly
shining Mipo, a cyan pool on the wall.

Known: held back from the world pass, the Mipos are drawn over everything else (fine here, not in a room
with things in front of them); a potato head's face bend is lost in the held drawing; each glowing part is
drawn 7 times (6 halo copies + the part), not baked, phone not measured.

## Steps

- [x] **NE1. The spike**: neon and glow, halo, flicker, night, the light pool.
- [ ] **NE2. Nikki plays with it**: keep, change or park.
- [ ] **NE3. If kept**: a real light from a glowing part (a LIGHT sfixture that lights the lit Mipos and
  walls, with the scene's own day and night instead of the drawn-over night), glow as a material on one
  part (a glowing belly, a lantern nose), the halo baked like the fur.
