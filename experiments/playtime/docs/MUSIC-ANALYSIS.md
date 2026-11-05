# Music analysis: taking songs apart to learn from them

status: active

A working notebook. We take a recording apart into its parts, listen to what each part plays (jabs, fills, held notes), and work out how to make each piece with dreamengine. Findings go here so they aren't lost. Style ideas that come out of it go to `MUSIC-IDEAS.md`, and the styles themselves to `src/music-styles.lua`. The musical concepts the generator uses, by name, are in `MUSIC-CONCEPTS.md`.

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

## Song 2: Open Studio — Ride the Wave (2026-11-03)

Source: [youtube hDkdyKOsJCg](https://www.youtube.com/watch?v=hDkdyKOsJCg), Peter Martin (piano), Kaleb Kirby (drums), Bob DeBoo (bass), 74 s. It's an "all 12 keys in 30 seconds" practice tip. Fetched with `python3 -m yt_dlp` (pip `--user`); the captions give the chord names, and `chords-from-audio.py` on 0:32–1:14 plus the demucs piano and bass stems give the rest.

- **The two shapes:** A maj9 and D sus (9sus4: a C triad over D, with a B on top now and then). From the piano stem: Amaj9 voiced A2 | G♯3 C♯4 E4 G♯4 B4 C♯5 (the left hand's root, the right hand's 7 3 5 9), and Dsus voiced D3 | B3 C4 E4 G4 B4 D5.
- **The cycle:** one chord a bar, ~96 BPM, straight 8ths (off-beat 0.52). The shapes are stated twice (A D A D), then the bass walks up in fourths, one root a bar: A D G C F B♭ E♭ A♭ D♭ G♭ B E A (12 bars, ~30 s), with maj9 and sus taking turns.
- **What it really is:** each sus is the next maj9's V (Dsus → Gmaj9), so the home chord drops a whole step every two bars. The bass touches all 12 roots, but the maj9 lands on only six (A G F E♭ D♭ B, a whole-tone scale). Going round a second time with the roles swapped (sus first) puts maj9 on the other six.
- **The hands:** demucs smears the piano too much to tell which hand plays what. The voicings above fit the left hand taking the root and the right hand the shape.
- **In Playtime:** the style `wave` (`src/music-styles.lua`, `D.waveForms`). A is the lap, B is the lap with the roles swapped, the figure is `split` (root, then the shape an 8th later), it pushes into each maj9, and the lounge kit keeps it straight. The usual tune is off: its scale and ladder belong to one key, and this moves key every two bars.
- **Extras, off unless turned up in the music panel's idea rows** (Nikki 2026-11-03: "not always all the notes at once, some strum, and a melody that's more like picking some of the keys you're going to play anyway, in some order"):
  - `figures`: one comp figure per song. `split` (the root, then the shape), `arp`, `strum` (45 ms a note, up on a stab in the bar's first half and down in its second) or `broken` (bottom, top, middle, top in 8ths). `strum` and `broken` are new and work for any style that lists them.
  - `picks`: a line made from the comp's own voicing (`bookPicks`, the patterns in `D.picks`). Per song it keeps one rhythm and one order, counted down from the voicing's top note. The voicings move to the nearest notes, so the order makes a sequence that follows the cycle, and it needs no key. Phrases are four bars, the fourth breathing after two notes.

## Song 3: Electric Relaxation and its bass loop, Mystic Brew (2026-11-05)

Sources: A Tribe Called Quest "Electric Relaxation" ([youtube HbPf6G1DJlY](https://www.youtube.com/watch?v=HbPf6G1DJlY)) and the record it loops, Ronnie Foster "Mystic Brew" ([youtube 5nj1HWC-dQs](https://www.youtube.com/watch?v=5nj1HWC-dQs)). The song also samples Brethren "Outside Love" (not looked at yet). The bass first; the aim is NoteOpts numbers for a humanized bass.

**How the loop was made:**
- ER's drums are a 4/4 bar of 2.44 s (98.2 BPM). The bass loop is 7.33 s, **exactly 3 bars**, so the bass line comes round only every three drum bars.
- In Mystic Brew the same riff is 12 beats at ~112 BPM. The loop is the record **slowed ~2 semitones** (tempo and pitch together; the tuning lands on 0 cents in both). The chop starts on Ronnie's G♯ pickup, which becomes ER's beat 1.
- Mystic Brew plays the exact riff only 3 times, in the first 20 s (the intro vamp). After that the bass goes into the tune with the same rhythmic cell: a short 8th, then a long note on the "and".

**The riff** (Mystic Brew key; ER is all of it 2 semitones down: F♯ A♯1 F D♯ …). Short = an 8th, damped; long = held to just before the next note:

```
bar 1:  G#2 (1, short)   C2 (1&, long 1.4)   G2 (3, 0.8)   F2 (4, 0.9)
bar 2:  C2  (1, short)   A#2 (1&, long 1.3)  D#2 (3, short)  G2 (3&, short)  G#2 (4, 0.7)
bar 3:  D#2 (1, short)   F#2 (1&, long 1.3)  C2 (3&, short)  C#2 (4, 0.8, loudest)
```

**How Ronnie plays it** (3 live passes, measured per note against his own pulse in each pass; tools: scratchpad `bass-notes.py`, `fold.py`, `fit.py`, gone after the session):

| what | measured | NoteOpts |
|---|---|---|
| feel, the same every pass | notes on the beat land **early** (−4 to −25 ms), the long notes on the "and" **late** (+13 to +30 ms). The short→long pair stretches to ~57:43, a light swing only there; other 8ths are near straight | a fixed per-slot offset, not random |
| random timing | sd 14 ms (median 10, 90% within 25) | booking time jitter |
| tempo | rushes: 108.6 → 109.9 → 112.2 BPM over the 3 passes, ~110 → 117 over the first 80 s | slow tempo drift up |
| loudness | random sd ~1.4 dB a note. Accents: the long "and" notes +2 dB, the last C♯ +2.6 (it leads back round), the A♯ −3, pickups ~−1 | `gain` per slot + jitter |
| short notes | 0.50–0.56 beats, decay −50 to −83 dB/s: **stopped by the hand**, legato into the next | `damp` ~0.5+, `dur_ms` = full 8th |
| long notes | 1.26–1.39 beats, ring −12 to −28 dB/s, let go ~0.1 beat before the next | `release_ms` short, own ring |
| pitch | no scoops (0±5 c), no vibrato, no slides; intonation sd ~10 c (one G♯ +23 c); one pass drops the A♯ an octave | `cents` ±10, rare octave swap |
| tone | attack centroid 200–900 Hz, closes 0.6–1.5 octaves in 200 ms, more on higher and accented notes | SHP_CUTOFF pluck closing ~−1 oct/200 ms |
| extras | ~1 quiet note a pass (−5 dB) off the riff | rare ghost, `damp` 1, low gain |

- ER's loop is rigid, so its per-note spread (±40 ms) is the **measuring noise** on a busy-mix stem; its per-slot means agree with Mystic Brew's feel above (beat notes early, "and" notes late).
- **Engine race** (C2 long note): FM 0.29, PIPE 0.38, SQUARE 0.40 … GUITAR and PLUCK last, as with King Rollo's bass: a low-passed demucs stem favours sustained engines. Upright or electric is for the ear, not the tool.
- **Nikki listened** to the long C2: "has a bass".
- **The drums are Brethren's "Outside Love"** ([youtube c1kqX1WnULc](https://www.youtube.com/watch?v=c1kqX1WnULc)): ER's drum bar against Outside Love's drum stem scores 0.80 by mel-spectrogram cross-correlation (Mystic Brew's drums, the control, 0.52), at several places in the record (1, 4, 13, 28, 88 s), so it's the band's steady groove, not one break. Outside Love is at ~79.5 BPM; Q-Tip **sped it up ×1.235, about +3.7 semitones**, to 98.2. So the beat is two records pulled to meet in the middle: the 80 BPM drums pushed up, the 112 BPM riff pulled down 2 semitones.
- **In Playtime: the style `brew`** (`src/music-brew.lua`): the riff on `hUpright` with the table above, over a rigid sampler kit (the bass alone two passes, the kit, the bass alone to end); the panel's humanize row plays it on the grid. The riff moves to the song's key always downwards (Nikki: in Ab, 3 up, it sat too high; F as Mystic Brew, Eb as ER, Bb 7 down, Ab 9 down). Checked by running a render back through the same tools: the feel per note comes back within ~10 ms of Ronnie's (G♯ −30, C +32, A♯ +35, D♯ −28, F♯ +16), jitter 11 ms, loudness 1.1 dB, the tone closing 0.6–1.0 oct. `damp` is steep on this patch: 0.35–0.5 hardly stops a note (−20 dB/s), 0.6 gives −30, 0.75+ −70 to −140; 0.7–0.8 lands on Ronnie's −40 to −65.

## The score pieces next to our styles (2026-11-02)

Why does Gershwin's Prelude II (`gershwin2`) sound so much richer than our own styles? To answer that, the notes themselves get analysed, not a recording.

**The tools:**
- **One piece:** `python3 -I claudetools/score-analysis.py src/music-scores/<name>.lua [--form A:1-30,B:31-44,A:45-61] [--bars] [--json out.json]` prints an analysis sheet. It shows:
  - the key per section, with "blue third" when both thirds sound
  - a chord per bar, as a Roman numeral
  - which bars bring back earlier ones
  - a loudness line
  - per part: notes per beat, range, and steps/leaps/holds
  - the lines that move by step, and the tune's 3-note cells
  - Plain Python, nothing to install.
- **A generated song:** `NOTES=song.lua NOTES_ONLY=1 luajit claudetools/render-music.lua /dev/null 400 <style> auto 20 <seed>` records the first song's notes in the same format (0.03 s, no sound). Leave out NOTES_ONLY to get the wav too.
- **Everything at once:** `python3 -I claudetools/style-report.py [--seeds 5] [--styles bossa,lofi]` runs every style × seeds and every score piece, then prints one table (about 30 s).

- **Checking a change by ear and by number** (2026-11-02; each tool's header has its usage):
  - `luajit claudetools/music-rubs.lua song.lua [bars]`: half-step rubs in a recorded song (keys against the tune or bass), per bar, or each one in detail. Compare before and after; a maj7 over its root or a V7b9 is meant to bite.
  - `luajit claudetools/music-harmony.lua <style> [approach:lots,...]`: chord changes per 8 bars and roots outside the key, from the songs' plans (sees half-bar chords, as HookTheory counts).
  - `IDEAS=... luajit claudetools/music-when.lua <style> <seed> <from> <to>`: what plays between two seconds of a render, with the bars' chords. For "a weird note at 50 s".
  - `luajit claudetools/music-answer-check.lua <style> [songs]`: answer notes in neither the key nor their chord.

**Checks that it reads right:**
- On the Prelude it finds what is really there:
  - the line cliché G♯3–A3–A♯3–B3–C4 in bars 13–14, 27–28 and 55–56
  - the C♯ blue third
  - the F♯ middle section
  - bars 21–24 bringing back 7–10
- The score styles recorded through the generator give the same numbers as their pieces, so the recording is faithful.
- It also caught two labelling bugs in gershwin2, both fixed:
  - music21's grace notes never ended, so bars 11–19 of the tune counted as keys. `score-from-text.py` now writes its own grace notes.
  - The tune under a held C♯4 (bars 15–16, 29–30, 57–58) counted as keys. `score-from-midi.py --low-lead` fixes that.

**What the table says** (5 seeds per style):

| | our styles | the real pieces |
|---|---|---|
| keys re-strike the chord they just played (hold) | 50–80% (bossa 76, herbs 80) | 8–28% (Bach 60 and Gnossienne 88 are built that way) |
| step lines per 8 bars | 0–0.5 (buymode 3.3, supermarket 1.8, citypop 1.7) | 3–5 |
| keys moving by step | 7–27% | 29–54% |
| span from the lowest bass to the highest tune | 3–4 octaves | 4–6.6 (Gershwin 6.6, Bethena 5.3) |
| loudness spread | 0–8 | 9–19 (a different velocity scale; a rough comparison) |
| tune notes per beat | about 0.4 | about 1 |

The tunes are not the problem: they move by step as often as the pieces do (40–50%). The thinness is in the middle of the band:
- the keys strike block chords over and over
- almost no inner line moves
- the range is narrow
- the loudness hardly moves

These numbers are what to aim at when a style is changed, and the report shows whether a change helped.

**Reference material, for learning only (2026-11-02):** copyrighted songs can be analysed for numbers, but they stay outside the repo in `~/music-reference/`. Only general patterns come into the docs and styles, never a song's notes, riff or voicings.
- `hooktheory/Hooktheory.json.gz`: the Sheet Sage release of HookTheory's TheoryTabs (github.com/chrisdonahue/sheetsage-data, CC BY-NC-SA 3.0, sha256 917b7cd5…). It has 26,175 song sections (15,213 songs, 6,079 artists), each with melody, chords (root + intervals + inversion), key and meter, in beats. It has no voicings, bass or inner parts. Close to our styles: Getz/Gilberto, Jobim, Sergio Mendes, Gilberto Gil, Tatsuro Yamashita, Mariya Takeuchi, Casiopea, Nujabes, Guaraldi, Ellington. NC: fine for learning numbers; don't ship anything derived note for note.
- `bossa/`: MuseScore arrangements Nikki downloads (MusicXML preferred: it keeps the parts and chord symbols).
- **Reading it:**
  - `python3 -I claudetools/hooktheory-report.py ~/music-reference/hooktheory/Hooktheory.json.gz [--compare <style-report out dir>] [--progressions]` gives per family (bossa, citypop, jazz, lofi, game, kids, all) how the chords move and what the tunes do, and our styles' same numbers below them.
  - `~/.venvs/scores/bin/python -I claudetools/score-from-xml.py in.mxl out.lua` turns a MusicXML download into a score. `style-report.py --reference ~/music-reference` converts and analyses a whole folder, as `ref:` rows.
  - Every analysis now ends with a quality line (key fit, notes off the grid, missing parts), and a doubtful file gets a `?` in the report.

**First HookTheory findings** (2026-11-02; small families: bossa is 9 songs, citypop 11; chords as the TheoryTab users heard them):
- **The tune is sparse:** real tunes play about 1 note a beat in every family; ours play 0.2–0.5.
- **The tune sits on chord tones:** real tunes have 70–79% of their notes in the chord under them, ours 80–95%. Ours have fewer passing notes and tensions.
- **Chords change less often:** bossa changes chord about 9.5 times per 8 bars, our bossa 4.8 (ours can change at most once a bar, so 8).
- **Borrowed chords are rarer:** bossa has 18% of its chords outside the key, citypop 11%, ours 0–7% (jingle, buymode and vibesnight are 16–21%).
- **Typical progressions:**
  - bossa: minor iv–v–bVI–bVII loops, and iii–VI–ii–V
  - citypop: iv7–bVII7–v7–i7, and I–vi–ii–V with 7ths everywhere
  - lofi (Nujabes): ii7–V7–I7–VI7

- `chordonomicon/chordonomicon_v2.csv`: Chordonomicon (huggingface.co/datasets/ailsntua/Chordonomicon, CC BY-NC 4.0; the search listing said MIT, the card says NC). It has 680k songs' chords in order, by section, with Spotify genre tags, but no tune, chord lengths or key. Its chords come from guitar-tab sites, so they are simpler than played. `python3 -I claudetools/chordonomicon-report.py ~/music-reference/chordonomicon/chordonomicon_v2.csv [--compare <style-report out>] [--progressions] [--json out]` takes about 2 minutes. It gives per family (bossa 927 songs, citypop via yacht rock 1,885, lofi 151, jazz 1,775, lounge 1,776, soul 2,839, game 325, against pop) the chords per song, colour, borrowed chords, root motion, form (sections, bridges, verse/chorus length, key changes), the most used progressions, and the *typical* ones (in more of the family's songs than of pop's).
- **Tables computed from this data may go into the game** (Nikki, 2026-11-02): a progression table or transition probabilities computed over many songs, e.g. "grey of grey of grey resulting in white, not black: good enough for our logic". A single song's notes or progression still never go in.

**First Chordonomicon findings:**
- **Typical progressions:**
  - bossa: II7–V7–I (the major II, a secondary dominant), vi7–II7–V7–I7, ii7–V7–i7–IV7
  - jazz: I7–VI7–II7–V7 (a chain of dominants), the backdoor IV7–iv7–bVII7–bIII7
  - lounge: II7–ii7–V7–I7, I7–VI7–ii7–V7
  - game: minor-key i–bVI–bVII–IV loops with V–i
- **Form:**
  - bridges in 7% (bossa) to 26–28% (soul, game, pop) of songs
  - verse/chorus about 15–18 chords long
  - a section in another key in 8% (bossa, pop) to 17% (citypop/yacht rock) of songs
- **Our bossa already plays the backdoor** iv7–bVII9–Imaj7, a real bossa and city pop move. What it lacks is the secondary dominants (II7, VI7) that real bossa and jazz lean on.
- `score-analysis.py` now prefers the file's own key when it fits nearly as well. Rich chords had pulled our bossa in F to D minor.

**Related work** (the same idea, done before; worth borrowing from before building more):
- **Feature extractors:** jSymbolic (Java, hundreds of features from MIDI), music21's `features` module (part of jSymbolic, in Python), and musif (Python on music21, 2023, with a benchmark of all three).
- **Datasets:**
  - Chordonomicon: 666k songs' chords with genre tags, listed as MIT, scraped from user sites
  - the iRealPro jazz corpus (Shanahan, Broze) and the Jazz Harmony Treebank
  - the Weimar Jazz Database (expert jazz solo transcriptions)
  - POP909 (pop piano arrangements)
  - the Lakh MIDI Dataset (large, messy)
- What none of them has: our "middle of the band" numbers (re-struck chords, inner lines, span), and a comparison against a generator's own output. That is what is ours.

## What we learned, and the working list (2026-11-02)

What the analysis of real music says about our styles, in one place. The numbers and how they were
measured are in the sections above. The concepts by name are in `MUSIC-CONCEPTS.md`.

**What we learned:**
- **The thinness is in the middle of the band.** The tunes move by step as often as real tunes do (40–50%). What's different (our styles vs the 8 score pieces):

  | | ours | real |
  |---|---|---|
  | keys re-strike the chord they just played | 50–80% | 8–28% |
  | inner step lines per 8 bars | 0–0.5 | 3–5 |
  | keys moving by step | 7–27% | 29–54% |
  | span, lowest bass to highest tune | 3–4 octaves | 4–6.6 |
  | loudness spread | 0–8 | 9–19 |

- **The tune is absent more than it is plain.**
  - It plays in ~38% of the bars, against 90–100%.
  - While it plays: 0.7 notes a beat, against 1.0–1.2.
  - Its rhythm is the same in every style for a given seed (`D.motifs` is shared).
- **The tune sits on chord tones too much** (HookTheory): 80–95% of its notes are in the chord, against 70–79% in real songs. Too few tensions and passing notes.
- **The harmony moves slowly and stays in the key** (HookTheory, Chordonomicon).
  - Bossa changes chord 4.8 times per 8 bars, real bossa ~9.5.
  - Chords from outside the key: ours 0–7%, real bossa 18%, city pop 11%.
  - Typical progressions:
    - bossa, jazz, lounge: secondary dominants (II7–V–I, VI7–II7–V7–I) and the backdoor (IV7–iv7–bVII7–I)
    - game: i–bVI–bVII–IV with V–i
- **Form** (Chordonomicon): bridges in 7% of bossa songs, 26–28% of pop and game songs. Verses and choruses run ~15–18 chords. A section in another key in 8–17% of songs.

**The working list**, in the order we'd do it (each new idea goes into a style's `ideas`, so spice and the panel can turn it down; measure with the style report before and after):
- [x] R0. Bossa: the walks (the line cliché) and the flute answer (call and response), settable as ideas with spice (2026-11-02; Nikki on the answer: "sounds pretty good")
- [x] R1. Dynamics: phrases that swell and fall, a section that lifts. Built 2026-11-02 (section levels, A swells; the idea `dynamics` in every song style): loudness spread 0–9 to 10–17. Nikki: "sounds good"
- [x] R2. Walks and answers in other styles: guaraldi, citypop (the answer on a horn), lofi (the flute), vibesnight (the felt piano). Built 2026-11-02 (`MUSIC-CONCEPTS.md`: the walks, the answer): step lines up in all four, rubs about the same. Nikki heard the answer slide out of the key in guaraldi (fixed: the answer's first note was searched only downward). Nikki: "nice"
- [x] R3. Fewer re-struck chords: a repeated stab changes its voicing (an inversion, a moving top note) instead of hitting the same block (bossa's keys are at 67%). Built 2026-11-02 as the idea `revoice`: down 3–9 points per style. Nikki: "I like the slightly different voicings"
- [x] R3b. Comp figures: broken chords, arpeggios and stride in place of some block stabs, per style (lofi's Rhodes arpeggio, a stride for guaraldi and sesame). The pieces' low re-strike numbers come from their texture, not from re-voicing. Built 2026-11-02 as the idea `figures` (arp, split): lofi 62 to 33%, vibesnight 44 to 28%. Nikki: "sounds pretty good", and wants both, with and without: every idea row now goes from never through less, some songs, always to lots
- [x] R4. A tune with more colour: tensions (9ths, 13ths) on long notes, approach tones, down to ~75% chord tones; motif banks per style (the rhythm differs per style). Built 2026-11-02 (the idea `colour`; `style.motifs` for bossa, guaraldi, vibesnight, citypop, lofi): chord tones ~82%, 75–79% at lots; off-beat share now differs per style. Nikki: "this sounds nicer!"
- [x] R5. A wider span: the bass drops an octave in places, the tune climbs at its peaks. Built 2026-11-02 as the idea `range`: 3.1–4.2 octaves to 3.9–4.7 (lots 4.2–4.9), rubs the same. Nikki: "nice advancements"
- [x] R6. Faster harmony and borrowed chords: chords lasting one or two bars (`chordBars { 1, 2 }`), chord banks that include the typical progressions. Built 2026-11-02 as the idea `approach` (dom, ii–V, tritone sub): bossa 6.4 to 7.2 changes per 8 bars (8.2 at lots), roots outside the key 7 to 10%. Nikki: "really like the approach setting, makes it feel so much more bossa!" (not as the default: every idea starts at never, the music as before)
- [x] R6b. Borrowed chords: some chords swapped for the parallel minor's bVI, bVII or bIII (real bossa has 18% of its roots outside the key, ours ~10%). Built 2026-11-02 as the idea `borrow`: bossa 7% to 12% (17% at lots). Nikki: "sounds good" (sesame included)
- [ ] R7. Reference material for voicings: Nikki's MuseScore bossa downloads into `~/music-reference/bossa/`, through `style-report.py --reference`

## Next steps

- [x] Engine race on the clean guitar pieces (ring-chord-mid, jab-chord-mid), piano, bass ring
- [ ] Listen to the cut pieces (`other-ring-note-high`, `piano-ring-dyad-high`, `guitar-jab-chord-mid`) and write down what they really are
- [ ] Full patch-match (voice + effects) on the winners; save the patches here
- [ ] Measure the `other` wobble with wav-modrate (vibrato rate and depth)
- [ ] A finer CQT or basic-pitch for real note names and voicings of the jabs
- [ ] Section map with chords for the whole song (where the key moves)
- [ ] Vocals: narration or melody?
- [x] Electric Relaxation's bass as a humanized part: the style `brew` (2026-11-05)
- [ ] Nikki listens to `brew`, humanized against plain; then the Outside Love sample and the keys loop

- [x] Turn the 1:53 jab pattern into a picking mode (`picking = 'jabs'`) on the electric guitar, kept sparse, as background. Built 2026-10-30 as the style **rollo**:
  - `jabGuitar`: the guitar, choked, with the tape on
  - `pickBass`: a picked electric bass, as Nikki heard it
  - `parts.bookJabs`
- [x] Nikki listens to rollo in the game; tune from there (2026-11-02: "liking this rollo stuff"; the flute's run now and then goes up, the idea `runup`, and lingers on its last note, humanized)
- [x] The flute's downward run in rollo (2026-10-30):
  - **The patch:** `flute`, built on PIPE with dreamengine's pipe.c flute preset, a 4.4 Hz vibrato and the tape. It stays at A5 or below.
  - **The run:** `bookFluteRun` runs down the chord's notes, 70 ms apart, and holds the last one up to the second stab.
  - **When:** in a phrase's 2nd bar on beat 3, 40% of the time in A and 70% in B; the melody switch turns it off.
  - **How much:** about 5 runs a minute, just under the guitar.
- [x] Score analysis and the style report (2026-11-02, see "The score pieces next to our styles")
- [ ] Nikki listens to gershwin2 again (the tune labelling is fixed) and checks the `??` bars (10, 16, 25, 33, 36, 38, 39, 49, 59 in `claudetools/scores/gershwin-prelude2.txt`)
- [ ] One style made richer by the numbers: inner step lines in the keys, fewer re-struck chords, a wider span, moving loudness; measured with the style report before and after
  - [x] Bossa's walks (2026-11-02): a two-bar chord walks one inner voice: the minor line cliché, V9 to b9 only into a chord a fifth below (on the backdoor bVII7 it grated), 6/9 to maj9 (`walks`, `planWalks`). Over 8 songs, step lines per 8 bars went from 0.8 to 1.9 and keys hold from 76% to 67%. Nikki: "sounds better, no very wrong rubs".
  - [ ] To try by ear: bossa without the V9-to-b9 walk (only the minor and major walks), if the b9 still sounds too sharp. It's the idea `flat9` now: set it to never in the music panel.
  - [x] The ideas made settable (2026-11-02): a spice slider (0 plain to 2) and a row per idea (some songs / always / never), live (`MUSIC-CONCEPTS.md`, "Ideas and spice")
  - [x] Bossa's answer (2026-11-02; Nikki: "sounds pretty good"): the flute answers where the tune is silent (`bookAnswer`). While the band plays, the tune or the answer fills 18 of 20 bars (the tune alone 14). Our tunes were silent in ~60% of all bars, the real pieces ~5%; while it plays, our tune is 0.7 notes a beat against 1.0–1.2.
  - The next steps are the working list above (R1–R7)
