# Music analysis: taking songs apart to learn from them

status: active

A working notebook. We take a recording apart into its parts, listen to what each part plays (jabs, fills, held notes), and work out how to make each piece with dreamengine. Findings go here so they aren't lost. Style ideas that come out of it go to `MUSIC-IDEAS.md`, and the styles themselves to `src/music-styles.lua`.

## How (the pipeline)

1. **Stems:** `python3 -m demucs -n htdemucs_6s -d cpu -o stems song.mp3` splits a song into guitar, piano, bass, drums, vocals and other. Use `-d cpu`, since the GPU path (`mps`) fails on this model. A 5-minute song takes about 10 minutes. demucs 4.1.0 was installed with pip on 2026-10-30.
2. **Per-part report:** `python3 -I claudetools/stem-report.py stems/htdemucs_6s/<song>` shows when each part plays (one character per 5 s), its note shape (attack and decay), brightness, pitch range, most-used notes, stereo width and amplitude wobble.
3. **Pieces:** `python3 -I claudetools/stem-pieces.py <stem.wav> <out dir>` cuts a stem into note events and groups them: jab or ring, note/dyad/chord, low/mid/high. It writes the cleanest example of each group as a wav.
4. **Chords and feel:** `python3 -I claudetools/chords-from-audio.py <clip>` gives tempo, key, swing and a chord per half bar.
5. **How to make it:** dreamengine's patch-match turns a sample into patches. Build it with `bash tools/patch-match/build.sh tools/patch-match/pm.c build/pm`, then run `./build/pm piece.wav --jobs 6` from the dreamengine root (design doc: `docs/design/patch-matching.md` there). `--stage1` stops after the engine race, about 100 s: you get a ranking of which of the 18 engines it sounds like. A full run takes 3–7 minutes and gives 8 candidate patches as `instrument()` blocks plus an effects fit, with a wav per candidate to compare.
6. **Effect numbers:** dreamengine's `tools/wav-modrate.js` reads tremolo/vibrato rate and depth, `wav-envelope.js` shows the attack/brightness shape over time, and `harmonic-spec.js` the harmonic levels.

**Limits so far:**
- Old recordings run off pitch (King Rollo is about a quarter tone flat). The pitch tools correct for it with `estimate_tuning`, but the 1-bin-per-semitone CQT still smears notes into neighbours. A group listed as "A#3 B3 C4" is really one or two notes, not a cluster. Use a finer CQT (36 bins per octave) or a real transcriber (basic-pitch) before trusting chord spellings.
- demucs bleeds: a jab in the guitar stem can carry some piano.
- patch-match is built for single, steady notes. Feed it the cleanest single note of a piece, not a chord.

## Song 1: King Rollo — The Tree (2026-10-30)

Source: an mp3 Nikki dropped in (5:02). The working files (stems, pieces, patch-match runs) are in the session scratchpad and are gone after the session. Rerun the pipeline above to get them back.

**The whole recording:**
- **Mono:** every stem has stereo width ≈ 0.04 and is centred. So stereo tricks are not part of this sound.
- **Tempo:** 117 BPM in the 1:50 passage. The drums-based estimate over the whole song says 136, so check per section.
- **Feel:** straight eighths, no swing (off-beat at 0.51).
- **Key:** it moves around. The 1:50–2:05 passage is in **F♯ major**.

**Who plays when** (one character = 5 s, from 0:00 to 5:00; # loud, + audible, . faint):

```
guitar  |.++  ...   .     +#+++....++#++++. ++.+#+++++++++     ....++ |
piano   |   .                     +#.#+..++ +..                       |
bass    |+. +#+#++++#+.++.                         .           +##++  |
drums   |  + ....   ..... .+.      ..........  ...+++..           ..  |
vocals  |        ..+ +++.+ .+.++. ...  +.++        .. .++++++++.  ..  |
other   |+++.++++++.++.+++.+   .++        .  .+#.#. .#+        ++.++. |
```

- **First 1:20:** bass and the high "other" instrument carry it, with the guitar barely there.
- **1:25–3:00:** the guitar's section. The piano only plays from about 2:05 to 3:10.
- **The end** brings the bass back.
- **Drums** are light throughout.
- **Vocals** are probably narration or singing; not looked at yet.

**The parts:**

| part | range | note shape | brightness | the pieces it plays (from stem-pieces) |
|---|---|---|---|---|
| guitar | D♯2–C5 | attack ~46 ms, half-decay ~90 ms | 880 Hz (dark-ish) | mostly **short mid chord jabs** (303), then ringing mid chords (112), high jabs (52), low jabs (45). 5 onsets a second while it plays |
| "piano" = **synth/organ** | D5–C6 | half-decay ~70 ms | 1040 Hz | almost only **high chord jabs** (117 of 151), right-hand stabs up top |
| bass | B1–D4 | half-decay ~210 ms, rings longest | 260 Hz | half **ringing roots** (112), half short (73) |
| other = **flute** | C♯5–G♯6 | half-decay ~80 ms | 1090–2100 Hz | **high jabs and dyads** (386), plus a repeated single **B6** (18). Its 4.4 Hz amplitude wobble is twice the beat, so it's likely vibrato or tremolo, not rhythm |

**The 1:50–2:05 electric guitar passage:**
- **1:50.3:** one strong hit.
- **1:51.5:** a fill of three fast eighth-note strums, high (C♯5/F♯5).
- **1:53–2:00, the pattern:** F♯ (I) and C♯ (V) only. A held root on beats 1 and 3, and short choked high stabs (F♯5 over C♯5) on the **"and" of 2 and the "and" of 4**. Silence in between.
- **2:00–2:04:** one low F♯ left to ring, fading about 25 dB over 4 s, with high C♯/F♯ overtones.
- **2:04.7:** the next phrase starts.

**patch-match engine races** (lower = closer):
- `other`, the single high note at 0:11.3: BRASS 0.41, REED 0.43, FM 0.50, PIPE 0.60, BOWED 0.63 … MALLET 1.30, PIANO 1.63, GUITAR 1.97, PLUCK 2.00. So **a blown/sustained voice, not struck**. The 4.4 Hz wobble fits too (vibrato).
  **Nikki listened (2026-10-30): it's a flute,** running down from a high note like a strum, clean, with a cassette sound. So the "other" part is a flute playing quick downward runs; its many "high jabs" are the notes of those runs. The cassette sound is what our `tape` pedal does (wow, flutter, saturation). dreamengine's flute-like engine is PIPE, 4th in the race at 0.60. Mind the earlier "no pipe leads" note in MUSIC-IDEAS: as a short downward run now and then (an ornament) it's a different job than a melody lead.
- The other pieces (top three, score):

  | piece | 1st | 2nd | 3rd |
  |---|---|---|---|
  | guitar jab, mid chord (3:50.6) | **EPIANO** 0.46 | FM 0.51 | MALLET 0.53 |
  | guitar ringing chord, mid (4:57.9) | FM 0.44 | VOICE 0.47 | PIPE 0.48 |
  | guitar ringing dyad, mid (3:01.1) | PD 0.36 | VOICE 0.39 | BOWED 0.43 |
  | "piano" ringing dyad, high (3:00.2) | **SAW** 0.28 | FM 0.32 | PIPE 0.34 |
  | bass ringing root, low (0:42.7) | **FM** 0.32 | PIPE 0.40 | SAW 0.41 |

  How to read it:
  - **Not the guitar engine:** GUITAR and PLUCK never make the top 8 for the guitar pieces. They model one plucked string, and these are chords cut from a bleeding stem, so they lose to sustained engines that can fake a blend. What does carry over: the **jab** sounds like a struck, fast-decaying tine (EPIANO/MALLET), which is a clean electric guitar played short and choked. That's our `guitar` patch with a short release, not a new instrument. **Nikki listened to `guitar-jab-chord-mid`:** it sounds like an electric bass guitar of sorts, and nice. So the mid "jabs" are at least partly a picked electric bass: short, plucked, not a round sine.
  - **The "piano" may not be a piano:** it lands closest to **SAW**, ahead of PIANO, which isn't even in its top 8. It could be a string synth, an organ or a harpsichord-ish keyboard of the period. **Nikki listened:** the cut is poor quality (demucs struggled), but it sounds like **some kind of synth or organ**, which agrees with SAW.
  - **The bass** fits FM best: a round synth or electric bass, not an upright.
  - **Weak evidence overall:** the scores sit close together (0.3–0.6) and the targets are chords. A full run on single clean notes is the next step for any of these.

## Next steps

- [x] Engine race on the clean guitar pieces (ring-chord-mid, jab-chord-mid), piano, bass ring
- [ ] Listen to the cut pieces (`other-ring-note-high`, `piano-ring-dyad-high`, `guitar-jab-chord-mid`) and write down what they really are
- [ ] Full patch-match (voice + effects) on the winners; save the patches here
- [ ] Measure the `other` wobble with wav-modrate (vibrato rate and depth)
- [ ] A finer CQT or basic-pitch for real note names and voicings of the jabs
- [ ] Section map with chords for the whole song (where the key moves)
- [ ] Vocals: narration or melody?
- [x] Turn the 1:53 jab pattern into a picking mode (`picking = 'jabs'`) on the electric guitar, kept sparse, as background. Built 2026-10-30 as the style **rollo**:
  - `jabGuitar`: the guitar, choked, with the tape on
  - `pickBass`: a picked electric bass, as Nikki heard it
  - `parts.bookJabs`
- [ ] Nikki listens to rollo in the game; tune from there
- [x] The flute's downward run in rollo (2026-10-30):
  - **The patch:** `flute`, built on PIPE with dreamengine's pipe.c flute preset, a 4.4 Hz vibrato and the tape. It stays at A5 or below.
  - **The run:** `bookFluteRun` runs down the chord's notes, 70 ms apart, and holds the last one up to the second stab.
  - **When:** in a phrase's 2nd bar on beat 3, 40% of the time in A and 70% in B; the melody switch turns it off.
  - **How much:** about 5 runs a minute, just under the guitar.
