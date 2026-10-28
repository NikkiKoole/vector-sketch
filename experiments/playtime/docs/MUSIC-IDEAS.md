# Music & sound ideas

Notes to pick up now and then, with no deadline. The music lives in `src/music.lua` and the patches in `src/synth.lua`. The engine is dreamengine, through `native/desound/`.

## Where it is now
- **Planned, not rolled** (2026-10-28), after dreamengine's lofi.c (its `docs/design/radio-arranger-lessons.md` is the why). Each song gets a form (intro, A, A, B, A, outro, or intro, A, B, A, B, outro), an A and a B progression (B is its own move or A with a ii-V turnaround) and a comping taste. Every bar is planned knowing the next: the push (the next chord comped early), fills into B, the bass letting go when the next chord comes in early.
- **A tune that comes back.** The melody is seeded by its place in the form, so every A sings the same tune and B its own. The motif is groups of notes, stated over two bars, a breath in bar 3, an answer in bar 4. Strong beats land on chord tones, passing tones fill the thirds, long notes keep off the chord's semitones, and the tune sits above the chord (67..86).
- **A live set** (`music.style = 'set'`, the default): bossa, guaraldi, island, dumont, supermarket, herbs, in turn. Each song ends ringing on home, takes a bar's breath, and the next one starts in a related key (F, Bb, Eb and Ab are a fourth apart).
- **Bossa**: the Rhodes on the clave, the left hand on root and fifth; drums: kick, shaker, and the rim on the clave in B. The lydian #11 and the half-step side-step are still there.
- **Guaraldi**: swung at 62%, 132 bpm, a felt grand (`piano` plus `pianoLead` for the tune), open fifths bouncing in the left hand with a half-step walk into the next root, Charleston and anticipation comps, 6/9 and 9sus chords; cocktail.c's brushes: hat on 2 and 4, a sweep, a feathered kick, the ride (ding ding-ga ding) in B.
- The first A has no tune (the band plays the changes once), and intro and outro have no drums.
- Measured with a stub synth, 3 seeds × 6 min: rubs a minute (semitone or b9 between two sounding notes) are keys-lead ≤ 1.2, bass-keys ≤ 1, keys-keys ≤ 0.8. For comparison, loficity's are 2.7 / 4.0 / 13.9. Stem levels are balanced on renders against the Rhodes.
- The upright bass is still off (`upright = false`).

## Directions to try (one at a time)
- [x] **Vince Guaraldi**: Peanuts piano jazz. Bouncy, childlike, with open fifths in the left hand. First version done 2026-10-28; waiting on an ear pass.
- [x] **MF DOOM, Special Herbs**: dusty boom-bap instrumentals. Laid-back swung drums (~90 bpm, a lazy kick and a late snare), a short looped keys or jazz sample feel, a bass that walks under it, and a filter that breathes. lofi.c's grooves are the closest thing in dreamengine. It would be a third style for the set: a beat under the same arranger. First version is the `herbs` style (2026-10-28): 88 bpm, swing 0.6, minor loops one or two bars a chord (B is the switch-up), the Rhodes chopped like a sample (held chunks retriggered on the 16ths), a triangle sub on the kick (`boom`), a hard kick (`bapKick`), a snare (noise over the kick tuned up) laid back by the swing drag, swung hats, a sparse looping piano phrase, vinyl crackle. Waiting on an ear pass.
- [x] **Animal Crossing**: hourly-music feel. Short loops, cozy, a little odd, plinky. First version is the `island` style (2026-10-28): one-bar chords, a seeded marimba riff over the voicing (`lib.riffs`), the Rhodes only holding, a bouncy root and fifth, a kalimba tune, a kick, a rim on 2 and 4, a shaker. Waiting on an ear pass.
- [x] **Domenique Dumont** (Comme Ça, 2015, Antinote): funky, pastel synth-pop on a homemade drum machine. First version 2026-10-28 was too slow and dreary (100 bpm), and its breathy PIPE tune sounded like 1996 General MIDI (Nikki: not a fan). Now 116 bpm, slight shuffle: dorian vamps (one or two bars a chord), a busy syncopated triangle bass (`funk`: ghosts, octave pops), a marimba riff on the off-beats (`lib.dumontRiffs`), the tune on a steel pan in short notes, 16th saw stabs with a dotted-8th echo clipped to the chord, a flammed clap, 16th hats, a conga. No push here (it clashed with the echoes and the riff). Waiting on an ear pass. **Lesson:** a held wind/pipe lead reads as GM-MIDI. Mallets and plucks hold up better as the tune. The engine has a real echo insert (FX_ECHO), but every insert takes one of the 7 aux FX buses and 6 are used, so the echo is booked notes for now.
- [ ] **Old Sesame Street jazz**: a 70s small band, warm and playful, with a walking bass.
- [ ] **Dominique Dumont**: lo-fi French bedroom pop. Toy drum machine, wobbly keys, a sleepy hum.
- [ ] **Library music**: 60s/70s production music (KPM, De Wolfe). Short, clear moods, a lot of character on a small budget.
- [x] **Supermarket music**: muzak and easy listening. Soft, smooth, never in the way, slightly uncanny. Concrete model (asked 2026-10-28): Karl Jenkins' *Mr. Lucky* (*Sounds for the Supermarket*, library music) as the model. Hooktheory (theorytab karl-jenkins/mr-lucky): C major, 89 bpm, 4/4, a **ii7 – V11 vamp** (Dm7 – G11) all verse; the tune runs mostly by step over a wide range (G3–C6), short notes (~0.6 beat), punchy syncopation, 'bright, unexpected'. Plan: a `supermarket` style on that vamp (the `sus` quality is V11), straight time, bouncy, whimsical voices. **Use the chords and the feel, not the melody.** Chords aren't protected, the tune is, and these apps are sold, so the planner writes its own syncopated stepwise hook. Whimsy to try: wide leaps between phrases, a toy-ish lead, staccato stabs, a cheeky chromatic approach note. First version is the `supermarket` style (2026-10-28): the ii7–V11 vamp plus a secondary-dominant loop (ii V11 iii VI7), 89 bpm straight, staccato Rhodes stabs, the Rhodes left hand on root and fifth, a marimba tune over 62–88 in short notes (`staccato = 2`), a light kit (kick 1 and 3, rim 2 and 4, hats). The comping is **shared by name**: `lib.comps.bounce`, and a style sets `comps = 'bounce'`, so another song can reuse how the chords are played. The bounce cells are a guess at 70s library comping, because Hooktheory gives only the progression. Match them to the record by ear. Waiting on an ear pass.
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
