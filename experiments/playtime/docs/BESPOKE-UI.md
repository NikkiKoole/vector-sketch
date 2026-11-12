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
- [x] **BU2. Feelings on a pad** (emotions spike, built 2026-11-12; kept, Nikki: "work nice"): pleasant to the right,
      excited at the top (valence and arousal, a mood map); happy, surprised, scared, angry, sad, sleepy,
      shy on it, neutral in the middle. Dragging sets the feelings by how close the dot is to each spot
      (reach 0.32): on a spot that feeling, between two both (halfway between happy and shy: 0.45 each),
      near the middle hardly any. The buttons move the dot to their spot. The spots' places are a first
      guess (`FEEL_SPOTS` in the scene); the words for the axes overlapped the spots' names, left out.
- [ ] **BU3. Face handles**: the Mipo editor's face panel is 27 sliders (eye spacing, height, size,
      pupils, brows, nose, mouth, teeth). A small face to drag the eyes on (move: spacing and height;
      a corner: size), the same for brows, nose and mouth. The biggest one, and the Puppetmaker way.
      **Built 2026-11-12, Nikki to try** — on the Mipo itself rather than a small copy
      (`src/ui/mipo/face-handles.lua`): while the editor's face section is open, each eye, brow, the
      nose and the mouth get a frame, a dot in the middle (drag: move; eyes: spacing and height
      together, both eyes as one; brows, nose, mouth: up and down) and a square on the corner (drag:
      size). The same values the sliders set, so they follow. Where the features are comes from
      `mipo-textures.faceLayout` (the face box taken out of addFaceDecals, so the handles sit where the
      pictures are: checked on a live Mipo, eye, brow and nose to the decimal). A press on a handle is
      the handle's (ui.overPanel), not a drag of the head. Seen in a screenshot, the drag not tried by
      Claude (no mouse over the bridge). Not yet: pupils, rotation, teeth.
- [ ] **BU4. Body handles**: the body panel's 21 sliders as handles on a silhouette.
- [ ] **BU5. The clouds' air as a chart**: height against temperature; drag the air's line and the lid's
      bump, the cloud base and the take-off height show where the lines cross (CLOUDS.md CG1's six sliders).
- [ ] **BU6. The sun**: drag it along its arc, or a clock dial for the time of day (SKY).
- [ ] **BU7. Wind**: one arrow to drag, direction and strength.
- [ ] **BU8. Weather**: rain, storm, fog, snow, wind and heat are blended by amount (WEATHER.md): a pad or
      wheel to point at a mix.

- [ ] **BU9. The arrangement grid** (music panel, earth; Nikki with the earth session 2026-11-12: "an arrangement
      grid for earth (a BPM slider + passes x parts toggles)"). **Built 2026-11-12, Nikki to try** —
      `src/ui/music-arrange.lua`, above the music rows while earth plays: a column per pass (10 of the 4-bar
      loop), a row per part (vibes, bass, drums, solo); click a cell: that part on/off in that pass, the solo
      rest -> A (call) -> B (answer); click a part's name: the whole row off, again: back to the record's. The
      pass you hear is lit and fills as its bars go (from the audio clock, not the booked bar); a name gets a
      dot while it sounds. bpm slider: from the next bar line. 'the record's arrangement' clears it. Kept in
      `state.musicSettings.arrange[style]`, saved by setups; earth reads it per bar (music-earth.lua, the earth
      session's hook). Seen in a screenshot, clicks not tried by Claude. Next: brew and neige (the same loop
      shape, their own role names), if wanted.
      **Every other style, 2026-11-12** (Nikki: "how does this translate to all our other songs"): their songs
      are rolled fresh, so a column is a kind of section (intro, A, B, break, outro ...: "no drums in any
      break"), which holds across songs; rows are the parts the style has played. Takes notes away only.
      Kinds and parts appear as the style first plays them (`state.musicArrangeSeen`), so drums that haven't
      come in yet (band 'auto', calm play) have no row yet. Kept in `arrange[style].kinds[kind][part] = false`,
      read in music-parts.lua's voiceOf (the music session's hook, a9927282; drums are one part, not per sound).
      Drawn off-screen for bossa (intro A B outro, A lit); clicks not tried by Claude.
      **The one place for all three, 2026-11-12** (Nikki: "i feel there is a connection between the arrange
      grid and the full quiet cellar rhythm etc thing"): a part unticked in the band fold ('off') or switched
      off by the layers ('cellar' ...) is a dimmed row with the reason across it. The layers are a strip on
      top of the grid (lit as they play, a room's too); a click is music.layers, as a room does it (from the
      next bar, the band fold's ticks untouched; the old layer buttons ticked those, gone). A dimmed 'off'
      row's name clicked ticks it back on. Later, if wanted: layers as saved grids (a room picks an
      arrangement, not only parts off) — the music session's side too.
- [ ] **BU13. The music panel in folds** (Nikki 2026-11-12: "it has too much all at once in the panel, could
      use some accordion?"; groups from the music session's read). Built, Nikki to try: on top, unfolded, the
      status line, music on/off, music volume, style; then folds arrange (open: the grid with the layers on top, setups),
      band (the part and sound rows, band auto/on/off), feel (humanize, spice, the ideas, tune), sound (all
      sound and fx volume, effects, the pedal lines), world (the jam's rows, impacts, stingers, events' rows),
      info (song ideas, events, the play level). The stinger rows past 'stingers' only while they're on; no
      '+ more' any more. In the inspector: `kind = 'section'` (a fold up to the next one, open state on
      `state.inspectorFolds`, hidden with nothing under it) and `kind = 'custom'` (draws itself, its own
      height), for light, sky and the rest later. Drawn off-screen, clicks not tried by Claude.
- [ ] **BU10. The band on a stage**, **BU11. styles on a pad**, **BU12. ideas as a fader bank**: the other
      music panel ideas (2026-11-12), not started.

Where it doesn't fit: settings with one number and no picture (a speed, a count) stay sliders.

## Where we left it (2026-11-12)

BU1 (the pad) and BU2 (feelings on it) done and kept. BU3 (face handles) built, Nikki to try: select a
Mipo's head in the editor, open 'head face'. Then: pupils, rotation and teeth handles if wanted, or
BU4 (body handles) / BU5 (the clouds' air chart). The voicebox's vowel chart moved onto the pad and
hasn't been opened since: check it still sounds and moves as before.
