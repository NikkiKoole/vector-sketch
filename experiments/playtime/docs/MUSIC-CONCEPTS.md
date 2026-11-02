# Music concepts: the named ideas behind the generated songs

status: reference

Every musical idea the generator uses, or that we've tried, by its usual name, so we can talk about
it, look it up, and see what it did. One entry each: what it is, where it lives, what happened.
Measurements come from `claudetools/style-report.py` and the other analysis tools (`MUSIC-ANALYSIS.md`).
Add a concept here when it goes into the code or gets tried. Write `tried <date>:` when one is dropped.

## Ideas and spice: how much of it a song takes

The tried concepts (the walks, the answer) are **ideas** a style can have (`style.ideas` in `src/music-styles.lua`). Each idea has two numbers:
- **`songs`:** the share of songs that use it at all, rolled per song (`planIdeas`, `src/music-plan.lua`).
- **`odds`:** how often a song that uses it takes its chances (the chords that walk, the free bars answered).

The music panel has these controls (also on `render-music.lua` as `SPICE=` and `IDEAS=`):
- **spice:** scales every idea's odds. 0 is plain (bossa as before the walks), 1 as designed, 2 twice as often.
- **A row per idea:** `some songs` (the style's share), `always` or `never`.
- **this song:** the line that shows which ideas the playing song uses.

Both act at the next bar. Saved setups keep them, and reset puts them back.
- Bossa's ideas: `walks` (the minor and major walks), `flat9` (the dominant's 9 to b9), `answer`.
- Measured over 8 songs: at spice 0 step lines are 0.8 per 8 bars and keys hold 76%. At 0.5: 1.3 and 72%. At 1: 2.0 and 67%. At 2: 2.1 and 63%.
- A new idea: give it a name in `style.ideas`, read its odds from `song.ideaOdds[name]`, and add its name to `IDEAS` in `src/music-params.lua`.

## Harmony: which chords

- **Chord bank:** each style has a few hand-picked progressions to choose from, one for the A section and one for B (`A`, `B` in `src/music-styles.lua`, picked in `planChords`, `src/music-plan.lua`).
- **ii–V–I:** the jazz cadence; the turnaround and most banks are built on it.
- **Turnaround:** the last bar of B becomes a ii–V back to the top (`progTurnaround`, `src/music-theory.lua`).
- **Secondary dominant:** a dominant 7th that points at a chord other than I. Examples: II7 → V (Ipanema), VI7 → ii. Chordonomicon finds these the most typical of bossa, jazz and lounge. Bossa's bank has some (II7, VI7).
- **Backdoor progression:** iv7 → bVII7 → I. Our bossa already plays it; it's typical of jazz and city pop.
- **Borrowed chord (modal mixture):** a chord from the parallel minor in a major key, like iv, bVI or bVII (bossa's "I ivm I bVII7"; jingle's `jbVII`, `jbIII` per song via `song.flavor`). Real bossa has 18% of its chords outside the key, ours 0–7%.
- **Lydian colour:** the tonic maj9 voiced with a #11 (`lydianChance`, `qualityOf`).
- **Key change, the lift:** a section moves up a half step, the "truck driver's" modulation (`lift` in a form, `applyLift`; buymode).
- **Half-step float:** I → bII maj9 and back (a bossa B bank).

## Voicing: how a chord is played

- **Voice leading, least movement:** each chord is voiced as close as possible to the one before (rotations and drop-2 voicings in every octave; `voiceChord`, after lofi.c's `lead_to4`).
- **Shell voicing:** only the 3rd, the 7th and one colour, as a bossa guitarist or a comping pianist plays it (`shellOf`, `song.comping = 'shell'`).
- **Guide tones:** the 3rd and 7th. They say which chord it is, and they move by step from one chord to the next (`src/music-guide.lua`).
- **Avoid note:** a scale note a half step above a chord tone; it rubs on a long note (`isAvoid`, `rubs`).
- **Line cliché, the walks:** one inner voice moves by half steps while a chord is held. Minor: root, maj7, b7, 6 (Cm, Cm(maj7), Cm7, Cm6). Major: 6/9 opening to maj9. Dominant: 9 falling to b9.
  - Where: `walks`, `planWalks` (marks and rolls the chords), `barChords` (plays the walk when its idea's odds allow). Ideas `walks` and `flat9`.
  - Bossa, 2026-11-02: step lines went from 0.8 to 1.9 per 8 bars. Nikki: "sounds better".
- **Altered dominant (b9) only into a fifth below:** a b9 belongs on a dominant resolving down a fifth (V7b9 → I). On the backdoor bVII7 it grated (heard 2026-11-02; `fifthDown` on a walk). It is its own idea, `flat9`, so it can be set to never.

## Rhythm and comping

- **Comp cells, clave comping:** the keys' rhythm per bar from a style's cells (bossa: the clave and its cousins; `comps`).
- **Steady groove:** a style decides once per song what the others roll per bar (the cell, the push habit, shells or full chords), so a song holds its groove (`steady`, `planSteady`).
- **Push, anticipation:** the next chord arrives early, on the and-of-4 (`pushOdds`, `keysHits`).
- **Side-step:** the bar's last stab is the next chord a half step high, sliding into it (`sidestepOdds`).
- **Swing:** the off-beat eighths late (`swing`; 0.5 = straight).
- **Humanize:** a few ms of human timing on every note (`humanize`).

## Melody: the tune

- **Motif and development:** a short rhythm-and-contour cell stated in bars 1–2 and moved over the next chords (`D.motifs`, `planTune`, `buildPhrase`).
- **Phrase as statement, breath, answer:** a 4-bar phrase; bar 3 breathes, bar 4 answers (`buildPhrase`).
- **Chord-tone melody (guide-tone lines):** strong and long notes on chord tones, the notes between walking the chord's scale, a new chord arrived at by step (`src/music-guide.lua`, the default tune).
- **Passing tone:** a third with room is filled by the scale step between.
- **Grace note, a flick:** a quick neighbour just before a long note.
- **Pentatonic ladder:** the tune picks from the key's pentatonic in its range (`song.ladder`).
- **Call and response, the answer:** where the tune is silent, another instrument answers with a short falling line under it. It starts on a guide tone, walks down the scale skipping the avoid notes, and ends on a chord tone.
  - Where: the `answer` part, `bookAnswer` (`src/music-parts.lua`), `style.answer` (its instrument and range), idea `answer`.
  - Bossa, the flute, 2026-11-02: while the band plays, the tune or the answer now fills 18 of 20 bars (it was 14). The real pieces fill 90–100%.
- **Fill run:** rollo's flute runs down the chord's notes in a phrase's 2nd bar (`bookFluteRun`).

## Dynamics: how loud

- **Terraced dynamics, section levels:** each section has its own level, a volume step apart. The intro and the first A (the band alone, before the tune) sit a step down, B a step up, and the outro fades over its last two bars.
- **Swell, a phrase arc:** an A section rises a step through its middle and settles back for its last bar. B doesn't swell on top of its lift; that made the songs louder overall.
- Where: `planDynamics` and `dynamicAt` (`src/music-plan.lua`). The step for each bar is set in `bookBar` (`M.dynamic`) and added to every note in `play()` (`src/music-parts.lua`), drums included. A soft note stays audible.
- It is an idea that every song style shares (`D.commonIdeas`, `D.ideasOf` in `src/music-styles.lua`), so spice and its panel row control it. The loops and the score styles keep their own loudness.
- Measured 2026-11-02, loudness spread over 5 songs per style: 0–9 before, 10–17 after (the real pieces: 9–19). The average level comes out ~1.1–1.7 dB higher (the RMS weighs loud bars more).

## Form and arrangement

- **AABA, ABAB:** the song forms (`D.forms`; style forms like `jingleForms`).
- **The band plays the changes first:** the first A has no tune (`sectionRoles`).
- **Intro, break, outro:** each with its own roles per part.
- **Layers (iMUSE):** parts switched on and off by the room, one tune in many arrangements (`music.layers`).
- **Handoff:** a style change on the bar line, the old song's light parts carrying over (`src/music.lua`).
- **Band joins and leaves with activity:** the rhythm section comes in when the room gets busy (`bandPlays`).

## Ideas waiting (measured gaps, see `MUSIC-ANALYSIS.md`)

- **Fewer re-struck chords:** re-voice or rest some stabs. Bossa's keys still re-strike 67% of the time; the real pieces do it 8–28%.
- **A wider register span (orchestration by range):** spread the bass and the tune further apart. Ours span 3–4 octaves, the real pieces 4–6.6.
- **Faster harmonic rhythm:** bossa's chords last 2 bars; real bossa changes about once a bar.
- **More secondary dominants and borrowed chords**, from the Chordonomicon "typical progressions".
- **Walks and answers in other styles:** guaraldi, citypop and lofi first.
