# Riso, photocopy, watercolour, woodcut, CMYK, gouache, cut paper — the textures and the world, printed or painted

status: parked — kept as a spike (Nikki 2026-11-11: "like the look of all of them and want to keep them in that spike"); the next step when it comes back is below

Nikki (2026-11-11): "initially when i started the mipos i was about 'hand draw everything' now with the
shaders and materials and light i see more options, i still dont like us to use some random textures but
sometimes its ok, anyway my idea can we look at a riso-print shader, im wondering what that would do with
some of the cc0 textures we use now, for soil etc, i hope it might end up looking more handmade".

Not tried before (`tried` riso / halftone / dither: nothing). Nearest: MATERIALS' CMYK offsets (each plate
a little off; tried 2026-11-06 in material-check, taken out: "a drawing style, for later, maybe as a
picture pass").

## The spike (2026-11-11, scene `riso`)

`scripts/spikes/riso.playtime.lua`, one shader:
- **Inks**: up to three spot inks from the riso drum colours (black, federal blue, medium blue, blue, aqua,
  teal, green, hunter green, yellow, orange, bright red, fluorescent pink, burgundy, brown, mint, light
  grey), six pairings to start from, on cream, white or kraft paper.
- **Separation**: inks multiply on paper, so in log space a colour is a sum of inks. Each pixel's
  `-log(colour / paper)` is split into ink densities by least squares for the chosen inks (a 3x3 made on
  the CPU). 'ink' scales how much each plate carries, 'contrast' the picture before it.
- **Screening**: per ink, 'grain' (riso's stochastic dots: a threshold per dot cell, clumping a little) or
  'dots' (round halftone dots at 15 / 45 / 75 degrees); 'dot size' in screen pixels.
- **Print faults**: each plate a little off ('misregister', px), the ink uneven over the drum, paper tooth
  ('grain').
- **Views**: 'textures' (soil, earth, moss, grass, plaster, planks, concrete, bark side by side) and 'scene'
  (the world drawn into a canvas and printed, the Mipo too; the backdrop prints as bare paper). Space shows
  the original.

Checked in a test window: it runs, both views, no errors. Not judged.

**Photocopy, 2026-11-11** (Nikki: "can we do a photocopier one next?"): a second process in the same scene
('riso | photocopy'). Black (or blue, sepia) toner on white, recycled, pink, yellow or blue copy paper. A
steep curve that loses the greys, the threshold jittering per pixel ('grit'); 'copies' makes a copy of a
copy (blurrier, steeper, darker, dustier); the toner patchy, 'streaks' down the page from the drum, 'dust'
on the glass and pinholes in solid black (both still on the screen, as on the glass). 'detail' copies
each spot against its surroundings (a wide blur) with the tone softened, so a dark photo (the soil) keeps
its clods instead of going solid black; 0 is the plain picture as a real copier takes it. First look: the
Mipo reads as a photocopied drawing (black outline, gritty shading); the first 'detail' (a mix to grey)
turned flat white into 50% grit, now edges are added on top of the softened tone.

**Watercolour, 2026-11-11** (Nikki: "can we do a watercolor one?"): the third process, after Bousseau et al.
2006 (interactive watercolor rendering) and Curtis 1997. The picture simplified into washes ('soften', a
disc blur), their edges wandering like a hand ('wobble', noise on where it samples), wet-in-wet here and
there ('bleed', a wider blur where a slow noise says wet), pigment collecting where a wash ends ('edges'),
uneven over a wash ('pigment'), settled in the paper's dips ('granulation', the paper's tooth as noise),
lighter and transparent ('water'; multiplied onto white, cream or toned paper). Density darkens as pigment
does: C' = C - (C - C^2)(d - 1). First look: the soil a soft brown wash with granulation, the Mipo's
outlines softened and darker at the edges, the blocks pale washes.

**Woodcut / linocut, 2026-11-11** (Nikki: "can we now do a woodblock / gutsen one?"; gutsen: the gouges):
the fourth process. The key block: the tone as carved lines, each as wide as the tone is dark (solid where
very dark, carved away where light), bending with the picture ('bend': a wide blur pushes them) and
wandering, broken along their length like gouge cuts in the mid tones ('gouge'), edges left standing
('outline'); wood grain and the baren's uneven rub in the ink. Optional colour blocks under it: the
picture's colours flattened to 2-6 levels, a little off register ('colour', 'colours', 'off register'), as
in a Japanese woodblock print. Washi, white or kraft paper; black, indigo, red or brown ink. First look:
earth, planks and bark read as carved prints; the first version had gouge dashes all over the white
(the breaks reached into the light tones; now mid tones only) and soil solid black (darkness 0.5 -> 0.38).
'outline' picks up a photo's noise as specks (moss).

**CMYK misprint, 2026-11-11** (Nikki: "can you do a dither misprint cmyk one"): the fifth process. The
picture split into cyan, magenta, yellow and black plates (black from under the colours: 'black'), each
plate screened on its own: ordered dither (Bayer 8x8, each plate's matrix shifted), noise dither, or
halftone dots at the printers' angles (C 15, M 75, Y 0, K 45); 'pixel' the cell. Misprinted: plates out of
register ('misregister'), slipping across the sheet ('slip'), a faint second hit ('ghost'), ink running
out in bands ('ink runs out'), dot gain; newsprint, white or kraft. First look (Bayer): the Mipo with
colour fringes on its edges, the soil a dithered brown. The process buttons now read riso, copy, water,
wood, cmyk.

**What we were forgetting, 2026-11-11** (Nikki: "given the options we have now in the spike what others are
there we are forgetting that might be good for us too"; then "y" to the first four):
- **Boil**, for every process ('boil (fps)', 0 off): the grain, dots, strokes and paper drawn anew a few
  times a second (a jump of the noise's coordinates every 1/fps s), as hand-made animation is.
- **The paper moves with the world** (on by default, scene view): the patterns sit on the world (the world's
  0,0 on the screen, `cam:getScreenCoordinates`), not on the screen, where they stayed still while the
  world moved under them: a filter on glass. Not the photocopy: its dust is on the copier's glass.
- **Gouache**: flat, opaque, matte poster paint (the 70s picture books, Childcraft, King Rollo). A Kuwahara
  filter (of the four quarters around a point the calmest gives the colour; 'patches'), flattened toward a
  few values ('flat'), chalky ('chalk'), brush strokes with one direction per patch of the sheet ('brush';
  a direction turning smoothly over the screen bent them into marbling), dry strokes showing the paper
  ('dry'), wobbly edges; bare paper stays bare. First look: the Mipo reads as painted.
- **Cut paper** (the Eric Carle kind of collage): the picture softened (two rings of samples, 'soften') and
  snapped to a box of 12 painted papers ('papers'; per channel levels gave 64 colours and the photo noise
  flickered between them: confetti), each piece cut from a painted sheet (strokes at its own angle, dabs,
  'paint'), the cut wandering and torn ('tear'), a white fringe at torn edges ('fringe'), a lighter piece
  on a darker one casting a shadow ('shadow'). First look: the Mipo in big pieces (blue face, purple body,
  brown ears); busy photo textures still break up. A real cut-paper look may want the shapes themselves
  (each Mipo part is one) cut, not the picture: a renderer job, not a pass.
- Not built (the list): screen print (opaque flat layers, light ink on dark paper), crayon / oil pastel on
  the paper's tooth (matching the Mipos' crayon outlines), cyanotype, stencil / spray, felt-tip marker;
  Nikki's own scans (paper, crayon grain, a carved block, MT8's hatching) instead of noise; a process per
  depth layer (EM8): the back painted, the Mipos crisp.

## Steps

- [x] **RI1. Nikki plays with it**: riso, photocopy, watercolour, woodcut, CMYK, gouache or cut paper, on the textures only or the whole picture? Which inks,
  grain or dots, which paper?
  Keep, change or park.
  Kept 2026-11-11 (Nikki 2026-11-11: "like the look of all of them and want to keep them in that spike"): liked, kept as a spike.
- [ ] **RI2. If kept, where it goes**: on the textures only (a riso look baked into the tile-repeat and wall
  pictures, so the hand-drawn Mipos stay as drawn), or a picture pass over a whole scene (SHADER-LOOKS
  SH3's effects stack; the water look's canvas, `src/water-look.lua`, is the same shape). Inks per scene
  or per room.
- [ ] **RI3. Cost on the phone** if it's a whole-picture pass (one full-screen pass, three plate samples
  per pixel).
