# Music & sound ideas

Notes to pick up now and then, with no deadline. The music lives in `src/music.lua` and the patches in `src/synth.lua`. The engine is dreamengine, through `native/desound/`.

## Where it is now
- **Planned, not rolled** (2026-10-28), after dreamengine's lofi.c (its `docs/design/radio-arranger-lessons.md` is the why). Each song gets a form (intro, A, A, B, A, outro, or intro, A, B, A, B, outro), an A and a B progression (B is its own move or A with a ii-V turnaround) and a comping taste. Every bar is planned knowing the next: the push (the next chord comped early), fills into B, the bass letting go when the next chord comes in early.
- **A tune that comes back.** The melody is seeded by its place in the form, so every A sings the same tune and B its own. The motif is groups of notes, stated over two bars, a breath in bar 3, an answer in bar 4. Strong beats land on chord tones, passing tones fill the thirds, long notes keep off the chord's semitones, and the tune sits above the chord (67..86).
- **A live set** (`music.style = 'set'`, the default): bossa, then guaraldi, then bossa, and so on. Each song ends ringing on home, takes a bar's breath, and the next one starts in a related key (F, Bb, Eb and Ab are a fourth apart).
- **Bossa**: the Rhodes on the clave, the left hand on root and fifth; drums: kick, shaker, and the rim on the clave in B. The lydian #11 and the half-step side-step are still there.
- **Guaraldi**: swung at 62%, 132 bpm, a felt grand (`piano` plus `pianoLead` for the tune), open fifths bouncing in the left hand with a half-step walk into the next root, Charleston and anticipation comps, 6/9 and 9sus chords; cocktail.c's brushes: hat on 2 and 4, a sweep, a feathered kick, the ride (ding ding-ga ding) in B.
- The first A has no tune (the band plays the changes once), and intro and outro have no drums.
- Measured with a stub synth, 3 seeds × 6 min: rubs a minute (semitone or b9 between two sounding notes) are keys-lead ≤ 1.2, bass-keys ≤ 1, keys-keys ≤ 0.8. For comparison, loficity's are 2.7 / 4.0 / 13.9. Stem levels are balanced on renders against the Rhodes.
- The upright bass is still off (`upright = false`).

## Directions to try (one at a time)
- [x] **Vince Guaraldi**: Peanuts piano jazz. Bouncy, childlike, with open fifths in the left hand. First version done 2026-10-28; waiting on an ear pass.
- [ ] **MF DOOM, Special Herbs**: dusty boom-bap instrumentals. Laid-back swung drums (~90 bpm, a lazy kick and a late snare), a short looped keys or jazz sample feel, a bass that walks under it, and a filter that breathes. lofi.c's grooves are the closest thing in dreamengine. It would be a third style for the set: a beat under the same arranger.
- [ ] **Animal Crossing**: hourly-music feel. Short loops, cozy, a little odd, plinky.
- [ ] **Old Sesame Street jazz**: a 70s small band, warm and playful, with a walking bass.
- [ ] **Dominique Dumont**: lo-fi French bedroom pop. Toy drum machine, wobbly keys, a sleepy hum.
- [ ] **Library music**: 60s/70s production music (KPM, De Wolfe). Short, clear moods, a lot of character on a small budget.
- [ ] **Supermarket music**: muzak and easy listening. Soft, smooth, never in the way, slightly uncanny.
- [ ] **Jazz quartet**: piano, bass, drums and one horn or vibes. Room to breathe, trading solos.

## Small ideas
- [ ] Melody voices to revisit: kalimba A (mallet) and kalimba B (wavescan + low-pass gate). Both exist as patches already.
- [ ] Slide sound: the whistle was too synthetic and got annoying. Try a softer or less pitched voice for sliding.
- [ ] Gesture sounds: throw, drop, stretch, wash and squish, each tied to the music's scale.

## How to listen without the app
`luajit claudetools/render-music.lua out.wav 40 set auto 16 3` renders the real music.lua offline (args: seconds, style, rhythm, busy-from seconds, seed). `MELODY=<patch>` swaps the tune's voice, and `SOLO=piano,ride` renders a stem and prints its rms while it sounds (use that to balance a new patch). It needs `native/desound/build.sh` to have been run.

## Lessons from dreamengine (radio-arranger-lessons.md), in short
- Plan the song and the bar, then play the plan. Coin flips while playing make parts flicker instead of commit.
- Seed the tune by its place in the form. That's what makes a hook.
- Count rubs by register, part pair by part pair, before tuning by ear. A chord tone can still sit a semitone from a note the chord holds, for example the root an octave over a maj7.
- On a swung grid, lengths have to be measured on the grid. Straight 16th lengths ring into the next downbeat.
- The sound was half the gap: no tape saturation on the keys, not too dark, and balance the stems by measuring.
