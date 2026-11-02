# The drum jam

status: active

A drum-machine groove that never ends, played like a live set rather than a composed song, and steered by
the game: calm play thins it out, a burst of play brings the next layer in or drops the beat.
Next to the composed styles (src/music-plan.lua plans an intro, A, B, outro), not instead of them.

Not the same thing as `music.style = 'set'`, which already exists and means "play the styles in turn".
The jam is one style (`loop = 'jam'`) whose arrangement happens live.

## Why it's its own thing
Every style today is a song: it has a form, it starts, it ends, and the play level only decides whether
the band is in (`bandPlays()`). A live set has no form. It's a loop that changes in phrases, and the
changes are the music:
- **Layers** come in and drop out one at a time on phrase boundaries (8 bars): kick, hats, snare/clap,
  percussion, a bass line, later a stab.
- **Fills** close a phrase: the snare runs up its last steps, the hats let go before the one.
- **Breakdown and drop**: the kick leaves for a phrase, everything comes back at once, with a crash.
- **Variation without a new song**: the pattern moves to the next variant of its group, or mutates (hat
  density, a ghost note), every few phrases.

What steers it is the play level (`M.activity`, decaying with `D.activityHalfLife`, the same number
`music.bump()` raises), not a score. So the jam is the one style where the game *is* the arranger.

## What it reuses
- **The patterns**: dreamengine's `tools/drum-patterns.json`, 565 named 16-step patterns in 92 groups,
  one grid per role: BD SD CPS (clap) CH OH CY RS CB LT MT HT TB, plus AC (accent). A step is `x` (a hit),
  `f` (a flam) or `.`. The jam plays FAMILIES, not single patterns: the variants of one groove (`ELECTRO 1
  - A` / `- B`, `AMEN BREAK - A..D`, a book group's Measure A / B) and, where the source wrote one, its
  fill (the book groups' Break, played as the phrase's last bar). `claudetools/jam-patterns.py` picks them
  into `src/music-jam-patterns.lua` (generated; rerun it, don't edit the output).
  Provenance is uneven, and dreamengine's `runtime/drumpat.h` says so: converted from the maker's own
  drum-patterns.lua, whose header cites "Drum Machine - 260 Patterns" for its core set and nothing for
  the later groups. Fine for us, but don't call a pattern "the real X" from this data.
- **The pick** (2026-11-02, Nikki: "the ones with variations"), from an analysis of all 92 groups:

  | genre (bpm) | families | why |
  |---|---|---|
  | Electro (118-128) | ELECTRO 1, ELECTRO 3 (A/B) | the drum-machine core; 13 sections but only 8 distinct, 2 families with a B |
  | Hip Hop (86-94) | HIP HOP 1-4 (A/B) | boom-bap with variations (the BoomBAP group is one pattern) |
  | Breaks (96-108) | AMEN BREAK, CISSY STRUT (B-SECTION), HOOK AND SLING, KISSING MY LOVE (A-D) | four variants each: the richest families in the library |
  | Disco (116-124) | Disco 1-5 (A/B + Break) | four on the floor with a written fill |
  | Funk (96-106) | Funk 1, 3, 6, 7, 11, 12 (A/B + Break) | the book's structure, a looser groove |

  Out: BoomBAP (1 pattern) and CR78 (2 in 4/4, the rest waltzes) have no variations; Drum and Bass and
  Dubstep are too fast or half-time for background music; House and Miami Bass have one family with a B.
- **Accents and flams**: an accent row books the hit with `accent` (dreamengine-studio#47, SOUND-SYNTH.md);
  a flam is two hits ~15 ms apart.
- **The 303** (the acid style's patterns and booking, `af5b6232`) as one of the layers.

## The open question: the kit
Playtime's drums are general patches (`bapKick`, `snare`, `clap`, `shaker`, `tamb`, `djembe`). A drum jam
wants a drum MACHINE's voices: an 808's long kick and cowbell, a 909's hats. dreamengine has faithful banks
(`runtime/tr808.h`, `runtime/tr909.h`, and `runtime/morphdrum.h` between them), but they're C headers for
carts, and each voice is a recipe of several layered notes. Two ways in, decided at J4:
- **Port the recipes to Lua patches** in synth.lua (each voice = one or a few patches + how to fire them).
  Stays inside the existing patch / slot pool machinery; costs slots (48 are already full, J4 must budget).
- **Expose the banks through `native/desound/desound.c`** (a C call per hit: `tr808_fire(role, …)`).
  Faithful by construction and no slots spent in Lua, but new C surface on every platform (dylib, iOS, web).
Until then the jam plays the general patches; that's enough to hear whether the arrangement works.

## Steps
- [ ] **J1. The arrangement engine.** `loop = 'jam'`, in its own file (`src/music-jam.lua`: plan + book).
  A phrase clock (8 bars), layers moving one step per phrase toward a target set by the play level, a fill
  on each phrase's last bar, a breakdown and a drop every few phrases when the jam is busy. A genre and
  one of its families per song (the pick above), the family's written fill where it has one; the general
  patches. Done when: rendered with the play level stepped up and
  down (`render-music.lua`'s busyFrom), the layers can be heard coming in and going, and the drop lands.
- [ ] **J2. The vocabulary.** Variants rotate within the family already (J1); still to do: moving
  between a genre's families over a long jam (more genres only if wanted: a line in jam-patterns.py), mutations (hat density, ghost snares), flams. A jam picks its group per
  song, or moves between related ones.
- [ ] **J3. The 303 as a layer.** The acid style's pattern code shared, not copied: the 303 enters as a
  layer, its filter sweep tied to the phrase (open into the drop).
- [ ] **J4. The kit.** Decide port vs desound.c (above), then an 808 and a 909 kit, picked per group.
- [ ] **J7. The auto-accompaniment bass** (Nikki: "bass loops that change root, transposed every n
  bars"). The organ boxes' one-finger chord, in the jam: a `bass` layer (second in, after the kick)
  plays a 16-step loop written in DEGREES (`R` root, `3`, `5`, `7`, `8`, `L` the fifth below, `-` hold,
  `.` rest; two per genre, moving with the drum variants) over a ROOT that walks on its own clock:
  every 2, 4 or 8 bars along a walk rolled per song (I IV V I, I IV I V, I bVII I IV, around the
  fourths). Calm play holds the root; the drop lands back home; impacts follow it (`remember` on the
  root). The round bass first (`lib.BASS`). Built 2026-11-02 (`music-jam.lua`): Disco's octave loop
  walks F Bb Eb Ab Db Gb a move every 4 bars, bass and kick within 1.3 dB rms.
  Then (Nikki: "more interesting loops, a simpler rhythm with brushes, the upright"): the walks gained the
  progressions that sound best, 1 5 6 4 (never settles, loops forever), 1 6 4 5 (doo-wop), 2 5 1 (the
  jazz arrival), next to 1 4 5 1; the loops an APPROACH note (`A`: a half step under the next bar's root,
  so a change is walked into) and the sixth / second / octave, no major third (it clashes on the 6's
  minor chord); a hand-written BRUSHES genre (`lib.EXTRA`: a soft kick on 1 and 3, a sweep, the brush's
  tap and the hi-hat foot on 2 and 4, swung 62%, 84-96 bpm; the library has no brush kit); and the bass
  is the upright now (`musicBass`). Levels: Brushes mix -35 dB with bass and tap level; in Disco the
  upright sits ~7 dB under the club kick (its patch level is shared with the score styles). A walk can
  carry its own lengths too (`bars = { ... }`, one per step), and a loop needn't be a bar long. `N` in a
  loop is the PUSH: the next bar's root itself, early (on the and-of-4), the funk way to transpose.
  Focus (Nikki, 2026-11-02): the ROOT MOVING is the point, so the loops want 1-3 notes, not riffs;
  candidates rendered over 1 4 5 1 on Funk drums: the one, the push, octave pop, root-octave-b7,
  approach. Root-octave-b7 (Nikki's favourite) is every genre's main figure. The paces are 2 or 4 bars (8
  was too slow to hear the walk). PICKING (settings -> music, while the jam plays): 'jam walk', 'jam bass'
  (the figure) and 'jam pace', each 'auto' = rolled per song; live (a walk from its next change, starting at
  its first step), saved in setups (state.musicSettings.jam). Next: the sourced
  timings (`rhythmbox.h`'s Hammond-patent BASS lanes alternating root and fifth, the SGS M254/M255
  FIFTH and CHORD TRIGGER lanes), and the CHORD stabs those lanes gate (J6 overlaps).
- [ ] **J6. The organ-era rhythm box** (Nikki: "the truly whimsical ones"). dreamengine has a sourced
  library of them: `runtime/rhythmbox.h` (101 preset rhythms read off the Ace Tone FR-2L, Roland TR-77
  and SGS chip manuals and a 1969 Hammond patent; generated from its `docs/design/rhythm-box-patterns.md`),
  played by its `autorhythm` cart with `runtime/sideman.h`'s Wurlitzer Side Man tube voices (the `sideman`
  cart). Not drum-patterns.json's 16-step grid: 24 or 48 counts a bar, divided per rhythm (a waltz by
  three), counts a rhythm skips, held (gated) lanes, and lanes that gate a CHORD or a BASS: the auto-
  accompaniment. Probably its own loop style rather than a jam genre (no layers, a waltz, a bass + chord
  from the rhythm itself), and it needs the Side Man voices as patches. To decide with Nikki.
- [ ] **J5. In the game.** In the `set` rotation or not, what a room/scene can ask of it (a calmer jam
  for a quiet room), and whether the Mipos dance to its kick (`music.onNote`).

## Notes
- Another session works on the composed styles (MUSIC-ANALYSIS.md's R-list) in music-plan / music-parts /
  music-styles. The jam keeps to its own files; the shared ones get one registration line each.
