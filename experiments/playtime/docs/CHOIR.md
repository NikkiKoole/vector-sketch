# Choir — Mipo voices tuned and singing

status: parked — kept as a spike: "I like the work here about the tuning and singing already" (tried 2026-11-04). The engine side waits: Nikki wants a fuller picture of more voices and instruments first, so one shape fits all of them (instruments and sampled voices)

The spike is `scripts/spikes/choir.playtime.lua` (scene `choir`, `./playtime.sh play choir`). Three
Mipos sing public-domain songs in mipomi syllables from Theo's, Herman's and Nikki's recordings
(`assets/voices/`): Frère Jacques and Row Your Boat as rounds, Ode to Joy together an octave apart,
Twinkle Twinkle solo. Keys and the panel are in the script's header; from the bridge
`require('src.script').call('sing')` / `call('hush')` work in the editor too.

How it's made:
- **The pitch of every syllable** (`python3 -I claudetools/voice-pitch.py`, writes `src/voice-pitch-data.lua`):
  pYIN over the voiced part, the median of the vowel's steady middle as its note, plus the glide, the
  wobble, where the vowel starts and the peak. Takes pYIN can't read (most of Nikki's: octave-jumping)
  fall back to plain YIN's steadiest stretch, folded to the octave of the speaker's clean readings, and
  are marked `rough`. Theo sits around D4, Herman G3, Nikki E♭3.
- **Tuned per syllable**: a note plays its take at `2^((note - measured) / 12)` (LÖVE setPitch, so a
  resample: pitch and length together). Each voice sings near its own middle (Herman and Nikki an
  octave down). The take starts early by its consonant, so the vowel lands on the beat. Rough takes
  are swapped for the clean one that needs the smallest shift (not in a solo: one voice stays one voice).
- **Feel**: `jitter` (dice per note: timing, detune, scoop, vibrato, loudness) or `singer`, a model
  of the singer whose state carries from note to note: breath that empties and refills (snatched
  breaths come in late, the Mipo heaves), a push towards the phrase's top note and a ritard into its
  last, bigger scoops on leaps up, tiring over the song, a personality per Mipo. Scoop and vibrato
  ride the source's pitch every frame.
- **Vowel filter**: LÖVE's EFX equalizer on a send, its two mid bands at the vowel's F1/F2 (u o a e i),
  the dry path turned down: a 2-band talkbox, with a wobble (wah).

## What we learned

With the humanized-playing spikes in dreamengine (dreamengine-a2, 2026-11-04: `tools/carts/strumhand.c`
guitar, `breathflute` flute, `tablahand.c` tabla):

- **Measure before humanizing.** Untuned, the takes sang 3-9 semitones off; tuned per syllable, 88% of
  Theo's notes land within half a semitone (offline render, pYIN on the output). Per speaker isn't
  enough: one person's syllables spread over a fifth or more. The recording matters most: Nikki's takes
  are rough and no tuning fixes that (re-record steadier if they're to sing).
- **A model of the player, not dice per note.** Slow state that carries over (breath, phrase, fatigue;
  for the guitar stroke energy and a grip, the flute's air, the tabla's two hands and wrist) is what
  reads as a person. All four spikes landed on this independently.
- **Each instrument is humanized in its own place**: the guitar at the attack, the flute during the
  note, the tabla in which stroke, the voice in its tuning and then during the note.
- **An A/B switch, and layers you can turn off one by one**, in every spike, to hear what matters.
- **Where the sound plays limits what you can shape.** A note booked on the synth can only be shaped
  at its onset (hit in all three dreamengine spikes); LÖVE sources can be ridden every frame but have
  no formant tools; the synth has them (`sample_formant`, `INSTR_SING`, FX_FORMANT) but its slots and
  FX buses are full on the Playtime side.
- **The engine change that would serve them all** (agreed with dreamengine-a2, not built): booked notes
  that carry short curves: pitch (scoop + settle, vibrato depth/rate/fade-in, a slow sag), gain (swell,
  fade), per-note timbre/size (for INSTR_SING), maybe a macro curve (the tabla's palm). The consonant
  lead stays a booking offset in Playtime. **On hold**: Nikki wants more voices and instruments first,
  so the shape fits all of them before anything is built.

## Left open

- Nobody has judged the singer feel by ear yet; the personalities (push, steady, lean, lung) are guesses.
- Size (a bigger or smaller throat at the same pitch) needs the synth route (`sample_formant` / INSTR_SING).
- `src/mipo-band.lua` sings pi/po without per-syllable tuning; it could read `voice-pitch-data.lua`.
