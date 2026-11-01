# Mipo editor leftovers

status: parked — small extras from the Puppetmaker 2 comparison; pick one up when a Mipo needs it

What's still open after `MIPO-EDITOR-TODO.md` (the Puppetmaker 2 vs Playtime comparison, done)
and `FACE-SYSTEM-PLAN.md` (gaze, blink, brows done). Checked against the code 2026-10-30.

- [ ] **E1. Hair tension/spacing sliders.** trace-vertices already read `extra.tension` (default
  0.02) and `extra.spacing` (default 5); the Mipo editor has no slider for them.
- [ ] **E2. Leg facing.** A creation option 'left' / 'right' / 'front' that sets the foot stance angles.
- [ ] **E3. Speaking mouth.** The mouth flaps while a squeak plays (`src/mipo-voice.lua`, 2026-10-29),
  but the 15 phoneme shapes in `src/mouth-shapes.lua` aren't driven by anything (`mouthOpen` /
  `mouthWide`).
- [ ] **E4. Procedural texture controls** per part: `texScale`, `texRot`, `fgAlpha`, and
  bg/fg/line alpha on the face patches.
- [ ] **E5. Smarter randomize.** Prefer middle values, avoid extremes (puppet-maker2's
  `randValue(min, max, step, preferMiddle)`).
- [ ] **E6. Screenshot export** of a Mipo at a few sizes.
- [ ] **E7. Pupil look-at polish**: how the movement feels, masking pupils by the eye shape.
- [ ] **E8. Feet that bend.** A foot in two shapes, heel and toes, on a springy joint, so it
  rolls over its toes and lands softer instead of a stiff plank (idea, 2026-11-01; not for now).
  The feet hang from their ankle point (`ankle` in `src/shape8-dict.lua`) and rest on their
  sole (`spec/feet-stand_spec.lua`, `scripts/feet-check`); a split would need a second point.

Covered elsewhere since: saving a Mipo's DNA is the library (a Mipo saved there grows fresh from
its DNA); hair colour is shared by all hair parts when randomizing (`randomizeTextures`).
