# CRT — the world on an old cathode-ray TV

status: parked — kept as a spike (Nikki 2026-11-12: "commit both, keep them in the spike, park"); the next step when it comes back is below

Nikki (2026-11-12): "can we do a noise/tv/interlaced light, cathode ray". A picture over the whole screen
(like the riso spike's scene view, RISO.md), not per part.

## The spike (2026-11-12, scene `crt`)

`scripts/spikes/crt.playtime.lua`: the world drawn into a canvas (drawBelow / draw), laid over a history
canvas that fades (the phosphor's **afterglow**: moving Mipos leave a short trail), then shown through a CRT
shader:
- the **screen curved**, black past its edge, **dark corners**;
- **scanlines** (dark between the lines, the beam fatter where it's bright; 'line size'), **interlaced**
  (every other line dimmer, the two fields swapping each frame);
- a **phosphor mask**: an aperture grille (RGB stripes) or a dot mask, or none;
- **glow** round the bright parts, **colour fringes** toward the edges, **colour bleed** (the colour smeared
  sideways, the light kept sharp, as a TV's chroma);
- the signal: **snow**, a **hum bar** rolling up, lines **jittering** sideways, now and then a **static
  burst** (snow and a big jitter for a moment);
- sets: colour, black and white, green phosphor, amber.

First look (colour, grille): the curved screen, the scanlines and the colour fringes on the Mipo read as an old
TV; the white plaster wall came out too bright with the glow (brightness 1.15 -> 1.0). One full-screen pass,
~25 samples a pixel, a canvas copy for the afterglow; phone not measured.

Nikki (2026-11-12), seeing it: "this is beautiful".

## Steps

- [x] **TV1. The spike**: screen, scanlines, interlace, mask, glow, fringes, bleed, afterglow, snow, hum bar,
  jitter, static, the four sets.
- [x] **TV2. Nikki plays with it**: keep, change or park.
  Kept 2026-11-12 (Nikki 2026-11-12: "commit both, keep them in the spike, park"): kept as a spike, parked.
- [ ] **TV3. If kept**: a TV as a thing in a room (the CRT look on a screen-shaped part showing another view of
  the world: a camera in the room), or as a scene setting (a whole room seen on TV), the cost on the phone.
