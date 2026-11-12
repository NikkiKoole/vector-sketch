# Bespoke UI — widgets that look like the thing they set

status: active

Nikki (2026-11-12): "in our recent voice experiment you made a custom ui element to show which vowel
was playing, this got me thinking, we have our ui here built from the little parts, any places that
could be improved by having a more bespoke ui?"

The vowel chart in the voicebox spike works because it's a map of the thing itself (the mouth, front
to back, open to closed), not two sliders for its two numbers: you see where you are, where the other
vowels are, and you move between them. The UI is otherwise built from small general parts (`src/ui/all.lua`:
buttons, sliders with a number box, checkboxes, panels), which is right for most settings and wrong where
a row of sliders is really describing a place, a shape or a mix.

Two kinds come up again and again:

- **A pad** (`src/ui/pad.lua`): a 2D map with labelled spots and a dot you press and drag. For anything
  with two numbers that mean a place on a map: vowels, moods, wind, the sun.
- **Handles on a preview**: the thing drawn small, with handles on its parts to move and size them. For
  shapes and proportions: a face, a body.

## The pad

`pad.draw(id, x, y, w, h, opts)` -> `changed, u, v` (0..1, v down). `opts`: `value`, `spots`
(`{u, v, label}`), `edges` / `corners` (words on the sides or in the corners), `lit` (the dot big and
warm: sounding, held). `pad.pressed(id)`: the press began this frame (start a note). `pad.weights(spots,
u, v, reach)`: how close to each spot (1 on it, 0 at reach and past, smooth), for blends. A press is the
pad's only if it starts on it; a drag carries on outside it. In scene scripts as `pad`.

## Steps

- [x] **BU1. The pad**, out of the vowel chart (2026-11-12); the voicebox's chart is now the pad.
- [ ] **BU2. Feelings on a pad** (emotions spike, built 2026-11-12, Nikki to try): pleasant to the right,
      excited at the top (valence and arousal, a mood map); happy, surprised, scared, angry, sad, sleepy,
      shy on it, neutral in the middle. Dragging sets the feelings by how close the dot is to each spot
      (reach 0.32): on a spot that feeling, between two both (halfway between happy and shy: 0.45 each),
      near the middle hardly any. The buttons move the dot to their spot. The spots' places are a first
      guess (`FEEL_SPOTS` in the scene); the words for the axes overlapped the spots' names, left out.
- [ ] **BU3. Face handles**: the Mipo editor's face panel is 27 sliders (eye spacing, height, size,
      pupils, brows, nose, mouth, teeth). A small face to drag the eyes on (move: spacing and height;
      a corner: size), the same for brows, nose and mouth. The biggest one, and the Puppetmaker way.
- [ ] **BU4. Body handles**: the body panel's 21 sliders as handles on a silhouette.
- [ ] **BU5. The clouds' air as a chart**: height against temperature; drag the air's line and the lid's
      bump, the cloud base and the take-off height show where the lines cross (CLOUDS.md CG1's six sliders).
- [ ] **BU6. The sun**: drag it along its arc, or a clock dial for the time of day (SKY).
- [ ] **BU7. Wind**: one arrow to drag, direction and strength.
- [ ] **BU8. Weather**: rain, storm, fog, snow, wind and heat are blended by amount (WEATHER.md): a pad or
      wheel to point at a mix.

Where it doesn't fit: settings with one number and no picture (a speed, a count) stay sliders.
