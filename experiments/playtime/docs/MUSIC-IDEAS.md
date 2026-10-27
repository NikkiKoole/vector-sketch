# Music & sound ideas

Notes to pick up now and then, with no deadline. The music lives in `src/music.lua` and the patches in `src/synth.lua`. The engine is dreamengine, through `native/desound/`.

## Where it is now
- Bossa on the Rhodes: played chords (the notes drift in), a left-hand bass, and drums that join when play gets busy.
- Dreamier chords: lydian #11 and half-step side-steps.
- A melody on top, on the Rhodes up high (`melodyPatch = 'rhodesLead'`). It's good enough for now, but not yet the music we're after.
- The upright bass is off (`upright = false`).
- Impacts, boxes and snap clicks take their notes from the chord that is playing.

## Directions to try (one at a time)
- [ ] **Vince Guaraldi**: Peanuts piano jazz. Bouncy, childlike, with open fifths in the left hand.
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
`luajit claudetools/render-music.lua out.wav 40 bossa auto 16 3` renders the real music.lua offline (args: seconds, style, rhythm, busy-from seconds, seed), and `MELODY=<patch>` swaps the tune's voice. It needs `native/desound/build.sh` to have been run.
