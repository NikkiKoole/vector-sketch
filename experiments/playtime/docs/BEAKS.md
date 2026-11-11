# Beaks — an upper and a lower half that open, in 3D, from a finch to a stork

status: active — built 2026-11-11, Nikki to try (BE1)

Nikki (2026-11-11): "i used to have 1 texture, sort of upper beak of donald duck, but can we approach this
spike more honestly, use some beak like images you need, we can handdraw them later, i want an upper lower
part, no teeth, some hole, it works in '3d', be able to open and close, and have very different sizes?
stork and duck?"

Before it: the duck beak was an upper lip picture (`upperlip-04`), out since 2026-10-29: a landscape picture
drawn in less than half of it, it sat and sized unlike the other lips (shape-catalogs.lua).

Scene `beaks` (`scripts/spikes/beaks.playtime.lua`), the beak in `scripts/spikes/beak.lua`.

## How it works

- **Three pictures a beak**, `textures/beak/<name>-upper.png`, `-lower.png`, `-top.png`: 512x512, the beak
  pointing right, the hinge (the corner of the mouth) at the left edge, the mouth line at row 256, 512 px =
  the beak's length. Upper and lower from the side, the whole beak from above. Fill only: the outline is
  drawn. The five now (duck, stork, finch, parrot, toucan) are placeholders from
  `claudetools/beak-pictures.py`; a hand-drawn one replaces them on the same canvas.
- **Built in 3D from them**: each half is rings along its length; the side picture gives a ring's height
  and where its rim (the cutting edge) is, the top picture its width. Outside, a half ellipse with the
  side picture laid on it as seen from the side (each point takes the pixel where it lies in the side view,
  kept 1.5 px in from the drawn edge), so drawn strokes and grain stay; the panel's 'drawn picture' off
  shows the first version (the picture's colours only at the rings' points). Inside, a shallower hollow
  in the mouth's dark red. The parrot's hook is just its upper picture curving down.
- **Open and shut**: the lower half swings down round the hinge, the upper lifts a little (`lift`, the
  parrot most). Between them at the hinge, the hole: the throat across the back and the mouth's corners.
- **In 3D**: turned with the head (`mipoFacing.angle`, the same turn as the face), seen a little from above
  (`view`), so a beak pointing at you still shows (a stork's then hangs long down the front). Shaded by a
  light from up left, rings sorted back to front, the outline a fatter dark copy drawn first; nostrils
  where they face you.
- **Sizes**: `length` in head widths per beak (finch 0.42 … stork 2.3), plus the panel's size / width / height.
- **On the Mipo**: no nose, no teeth (DNA, rebuilt), the lips kept but not drawn (where the mouth is; the
  face turn moves them). It talks: while a squeak plays the beak chatters open and shut.
- **Panel**: a beak for every Mipo or the touched one; from above, turn (to see it side-on), size, width,
  height, open, up/down, outline. Keys: t talk, o open, k clack (not space or c: the editor pauses on space and saves a screenshot on c), b next beak, left/right turn, r new
  Mipos, h panel.

Editing `beak.lua` shows only when the scene script reloads (it loads it with `love.filesystem.load`):
save the scene script too, or reload the scene.

## Next

- [ ] **BE1. Nikki plays with it**: do the halves, the hole and the turn read? Which sizes? Keep or park.
- [ ] **BE2. Hand-drawn pictures**: draw a duck and a stork on the canvas above (fill, a little texture);
  the shape follows the drawing.
- [ ] **BE3. Its place in the draw order**: drawn after the world now, so it lies over hands and arms in
  front of the face. A drawable at the face's z in box2d-draw-textured instead.
- [ ] **BE4. Into the DNA**: `face.beak = { name, size, ... }` instead of the mouth, saved with the Mipo,
  a choice in the Mipo editor; the voice's mouth flap driving it (not only the scene's).
- [ ] **BE5. Pecks and bites**: a beak that grabs (a joint at the tip while shut), if wanted.
