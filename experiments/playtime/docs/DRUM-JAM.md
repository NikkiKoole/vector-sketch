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
The jam plays Playtime's own drum patches, played the way its other kits play them (`lib.VOICES`: kick =
`bapKick`, snare, clap, both hats = `hat`, cymbal = `ride`, rimshot = `rim`, toms = `tom`, cowbell = `wood`,
tambourine = `tamb`; Brushes its own). The first cut used stand-ins (a shaker for the hats, a djembe for rim
and toms) and the music panel's drum rows, which list by patch, named the stand-ins: Nikki "the drum
voices don't align with what I hear" (fixed 2026-11-02, `d26fd89c`). A drum jam still wants a drum
MACHINE's voices: an 808's long kick and cowbell, a 909's hats. dreamengine has faithful banks
(`runtime/tr808.h`, `runtime/tr909.h`, and `runtime/morphdrum.h` between them), but they're C headers for
carts, and each voice is a recipe of several layered notes. Two ways in, decided at J4:
- **Port the recipes to Lua patches** in synth.lua (each voice = one or a few patches + how to fire them).
  Stays inside the existing patch / slot pool machinery; costs slots (48 are already full, J4 must budget).
  Cheaper since dreamengine 409701fd: a booked note picks its own filter TYPE (`opts.filter` = 'high' /
  'band' / 'low' / 'off', in synth.scheduleAt; checked in the game 2026-11-04), next to cutoff (octaves),
  release, damp and gain. So a kit's noise voices (hats high-passed, clap band-passed, hiss low-passed) can
  share ONE noise slot; only the decay stays the slot's, so they get re-voiced, not copied. The same for a
  funk guitar layer (muted scratches thin, stabs band-passed: dreamengine's wahhand, 6 slots for 18).
- **Expose the banks through `native/desound/desound.c`** (a C call per hit: `tr808_fire(role, …)`).
  Faithful by construction, but new C surface on every platform (dylib, iOS, web). And it spends slots
  just the same: `tr808_build` claims 16 of the engine's slots, `tr909_build` 13, and `tr808_fire` times
  its hits in ms from now (`schedule_hit`), not on the audio clock the music books on.

  DECIDED 2026-11-04 (Nikki): port to Lua, and dreamengine raises `SOUND_INSTR_SLOTS` 48 -> 128 for
  everyone (about 34 KB more; asked of dreamengine-a2, with the choke mask widened: a uint32 per slot,
  so chokes on slots 32-47 were already broken). The 808 goes in slots 48-63 (`tr808_build` /
  `tr808_fire` copied into patches + a fire recipe per voice), the 909 after it. Watch polyphony
  (`SOUND_VOICES` 32): a clap is 4 hits, the three-band cymbal up to 9.
  The 808 is in (2026-11-04): patches `tr808*` in synth.lua (slots 48-61, dreamengine 9f2b18dd), its
  voices in `src/drum-machines.lua` (tr808_fire at the neutral knobs; the volume-0 hits left out), played
  by the genres in `lib.KITS` of music-jam.lua: Electro and Hip Hop. Kit level 0.4 puts the jam where the
  old drums had it (rendered, within 0.1 dB). Voices: a busy jam (every layer) peaks at 13 of 32, the old
  kit 11-13. To listen: `JAM='layers=all' luajit claudetools/render-music.lua out.wav 40 jam auto 0 5`
  (seed 5 = Electro, 2 = Hip Hop). Next: Nikki listens; then the 909, and a panel pick for the kit.
  First listen (2026-11-04): the jam's Rhodes PAD (the 'pad' chord figure) was a "tooter" covering
  everything. SOLVED the same day (Nikki: "much better, the tooter is gone!"): the pad has its own patch,
  `jamPad` (slot 62): no auto-pan / phaser / tape (the shared `rhodes` wobbled at 4 Hz on a held chord),
  2-3 dB under the bass (the shared one rendered ~15 dB over), and above all it FADES (decay 2 s to
  sustain 1): at full sustain a chord held a whole bar stayed flat, an organ. Still open: maybe the 808
  snare's body tones (F#3 + E4) alone on the quiet hits (tried: quiet hits as noise only, not decided;
  the "octave up toot" heard then may well have been the pad); ELECTRO 3 has no hats at all.
Until then the jam plays Playtime's drum patches; enough to hear whether the arrangement works.

## Steps
- [x] **J1. The arrangement engine.** (2026-11-02; played by Nikki in the app) `loop = 'jam'`, in its own file (`src/music-jam.lua`: plan + book).
  A phrase clock (8 bars), layers moving one step per phrase toward a target set by the play level, a fill
  on each phrase's last bar, a breakdown and a drop every few phrases when the jam is busy. A genre and
  one of its families per song (the pick above), the family's written fill where it has one. The music
  panel lists every drum sound of the song from its start (so each can be swapped or switched off before
  its layer comes in) and has the jam's picks (walk / bass figure / pace, J7). Done when: rendered with the play level stepped up and
  down (`render-music.lua`'s busyFrom), the layers can be heard coming in and going, and the drop lands.
- [ ] **J2. The vocabulary.** Variants rotate within the family already (J1); still to do: moving
  between a genre's families over a long jam (more genres only if wanted: a line in jam-patterns.py), mutations (hat density, ghost snares), flams. A jam picks its group per
  song, or moves between related ones.
- [ ] **J3. The 303 as a layer.** The acid style's pattern code shared, not copied: the 303 enters as a
  layer, its filter sweep tied to the phrase (open into the drop).
- [ ] **J4. The kit.** Decide port vs desound.c (above), then an 808 and a 909 kit, picked per group.
- [x] **J7. The auto-accompaniment bass** (2026-11-03: the walk is done; riffs go on in J8) (Nikki: "bass loops that change root, transposed every n
  bars"; the idea from Aaron Batzdorff's one-note synth bass trick (TikTok and YouTube @aaronbatzdorff): a Keystep
  Pro transposing a one-note sequence on a Model D, also dreamengine's `onenote.c` cart). The organ
  boxes' one-finger chord, in the jam: a `bass` layer (second in, after the kick) plays a 16-step loop written in DEGREES (`R` root, `3`, `5`, `7`, `8`, `L` the fifth below, `-` hold,
  `.` rest; two per genre, moving with the drum variants) over a ROOT that walks on its own clock:
  every 2, 4 or 8 bars along a walk rolled per song (I IV V I, I IV I V, I bVII I IV, around the
  fourths). Calm play slows the walk (a step lasts twice as long; it used to hold the root, which froze the jam in
  the editor, where nothing bumps the play level), a panel pick is never slowed; the drop lands back home; impacts follow it (`remember` on the
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
  was too slow to hear the walk). PICKING (settings -> music, while the jam plays): 'jam progression' (was 'jam walk'), 'jam bass'
  (the figure) and 'jam pace', each 'auto' = rolled per song; live (a walk from its next change, starting at
  its first step), saved in setups (state.musicSettings.jam). Next: the sourced
  timings (`rhythmbox.h`'s Hammond-patent BASS lanes alternating root and fifth, the SGS M254/M255
  FIFTH and CHORD TRIGGER lanes), and the CHORD stabs those lanes gate (J6 overlaps).
- [ ] **J8. Bass riffs.** (Nikki 2026-11-03: "more bass riffs... real bass riffs are small phrases,
  adjusted a little per phrase to make longer pieces of a few bars"). `src/music-riffs.lua`: a riff is a
  PHRASE (16 steps in the jam's degrees), VARIATIONS (16-step overlays: a space keeps the phrase's step)
  and a FORM (`AAAB`, `ABAC`) lined up with the END of the root's step, so the last bar leads into the
  change (a 2-bar step plays the tail, `AB`). A SCALE per riff, an option: pentatonic (minor) by default,
  the one that sits on any root of a chordless walk; blues (+ b5), dorian, mixolydian are defined.
  Off-16ths and A / N may leave the scale (passing notes); `riffs.check` finds the rest.
  - [x] J8a. The format + four pentatonic riffs (pocket, climb, call and answer, low and high), in the
    panel's 'jam bass' row as `riff: <name>` (2026-11-03). Render one:
    `JAM='figure=riff: climb;walk=1 4 5 1;pace=4' luajit claudetools/render-music.lua out.wav 40 jam`
    (the same `JAM=` for `music-when.lua`). To listen.
  - [ ] J8b. The play level thins a riff: calm = its skeleton (root, octave, b7), busy = all of it and the
    variations, so a riff grows with play the way the drum layers do (and calm keeps J7's point: the root
    moving is heard).
  - [x] J8c. Riffs follow the walk's chords (J9): moved to J9.
  - [ ] J8d. A bass lab: a scene with a grid (16 steps x the scale's rows), the four bars below (edit A,
    then only the steps a variation changes), a walk picker, save to a riff file the jam lists. Only if
    writing riffs as strings gets tedious.
  The dreamengine session works on the same thing (2026-11-03, `tools/carts/rootwalk.c`, GitHub #48);
  Playtime owns the format, rootwalk.c follows it. Tell it when letters or riffs change.
- [ ] **J9. Chord progressions** (Nikki 2026-11-03: "two parts, riffs/phrases and chord progressions").
  - [x] J9a. Changes decided ONE BAR EARLY (2026-11-03): the next phrase on a phrase's last bar, the next
    root on a step's last bar (or the bar before a drop, home). Before, the bass aimed at the next root
    and the bar line decided again, and the play level could move in between, so an ending could lean
    into a root that never came. `spec/music-jam_spec.lua` checks it over 20 seeds, play level jumping.
  - [x] J9b. The walks are progressions: `kinds` per step (M major, m minor, 7 dominant): 1 5 6 4 = MMmM,
    2 5 1 = m7M, round the fourths all dominant. Impacts play the chord's pentatonic now.
  - [x] J9c. Pentatonic riffs FOLLOW THE CHORD: written in the minor pentatonic, each note plays in its
    place on the chord's own (major: R m 4 5 7 -> R 2 3 5 6; dominant: R 2 3 5 b7). `follow = false`, or a
    scale of its own (blues, dorian), keeps a riff's notes. The jam's figures (root-octave-b7 ...) don't
    follow. To listen: `JAM='figure=riff: climb;walk=1 5 6 4;pace=2'`.
  - [x] J9d. A chord part, first cut (2026-11-03): a soft Rhodes PAD (`lib.KEYS`), the chord struck on
    each bar's one and held, voiced close to the last (theory.voiceChord, E3..D5), its own layer after the
    bass (`keys`: kick, bass, keys, hats, snare, perc); it plays through the breakdown. Chords per kind:
    M = 1 3 5 9 (no major 7th: the figures play a b7), m = m7, 7 = dom7. About 3 dB under the bass.
    Then the ways to play it (`lib.CHORD_FIGURES`, 16 steps of x / - / ., each on its own instrument):
    pad (Rhodes), disco stabs (the off-beat 8ths, `stab`), funk stabs (`clav`, syncopated), skank (2 and
    4, `jabGuitar`, high), strum (3+3+2, `guitar`, rolled). Picked in the panel's 'jam chords' row;
    'auto' = the genre's (Disco: disco stabs; Funk, Breaks: funk stabs; the rest the pad), coming in as
    the third layer with the play level; a figure PICKED plays from the next bar (Nikki: it took super long
    to hear the funk stabs: a calm room never asks for layer 3). Each about
    3 dB under the bass (rendered SOLO).
  - [x] J9f. The wave (2026-11-03, playtime-9c's style, Peter Martin's maj9 / 9sus cycle; Nikki said yes):
    walks 'the wave' and 'the wave B' (9sus first), roots up a fourth through all twelve; kinds J = maj9
    (bass: major pentatonic; pad 1 3 7 9) and s = 9sus (bass 1 2 4 5 b7; pad 1 4 b7 9), the same chars in
    rootwalk.c. The plain figures' 7 plays the major 7th over the maj9 (it rubbed a half step under the pad's;
    2026-11-03), the b7 everywhere else; the riffs follow it.
  - [x] 'jam layers' (now 'jam build') in the music panel (2026-11-03): auto, or all = every layer from the next bar, whatever
    the play level (for listening; the breakdown and the drop still come round).
  - [x] J9e. The panel's 'jam walk' row as 'jam progression' (2026-11-03), with the tidy: 'jam layers' is
    'jam build' (it read as the room layer presets), and the jam's rows, 'jam impacts' too, sit together
    under a 'drum jam:' header, shown while the jam plays. Saved keys unchanged (walk, layers, ...).
  - [ ] J9g. More progressions, minor-key ones: 1m b7 b6 b7, 1m 4m 5m.
- [ ] **J10. The drums play the song** (Nikki 2026-11-03: "solo, fill, maybe pattern switch"; the list:
  lean into changes, more fills, spotlights, pattern moves with play, the game driving it). Each move a
  music-panel row, auto / always / never.
  - [x] J10a. LEANING IN: the bar before a chord change (known a bar early, J9a) the drums go with the
    bass: an open hat on the and-of-4, a kick pickup on the last 16th, or a one-beat snare fill, rolled
    per change from the drums that are playing; 6 in 10 changes on auto ('jam lean-in'). Not on a
    phrase's last bar (the fill has it).
  - [x] J10b. FILLS: the snare run-up grows with the play level (a beat, half a bar at 3 layers' worth);
    Funk and Breaks roll down the toms on the last beat a third of the time; a family's own written fill
    plays two phrase ends in three, the jam's run-up the third (every Funk family has a written fill, so
    Funk never rolled its toms: caught by dreamengine-4d's spec); the bar before a drop is
    the BUILD (snare 16ths over the whole bar, louder toward the one) and ends in THE GAP: every part
    silent on beat 4, then the crash ('jam gap'; always = at every phrase end, for listening).
    `spec/music-jam_spec.lua` checks the gap.
  - [x] J10c. SPOTLIGHTS (2026-11-03): a groove phrase's last 4 bars given to one part: the DRUM BREAK
    (drums alone, the breakdown's opposite), the BASS FEATURE (a riff's variations in turn, A B A C, the
    chords out; a riff rolled if a plain figure is picked) or TRADING (2 bars of bass alone, 2 of drums).
    Auto: a busy groove phrase halfway between breakdowns, half the time; 'jam spotlight' can name one
    (then every groove phrase) or say never.
  - [x] J10d. VARIATIONS with play ('jam variations'): ghost snares (one of three masks per song,
    barely there) and the TURNAROUND (a phrase's second-to-last bar on the other variant, into the fill)
    once play is busy (2 layers' worth); the hats doubled to 16ths at 3 (not Brushes). Still J2: a
    related family after a fill.
  - [x] J10e. The game drives it (J5; 2026-11-03): a big impact = a crash or a quick fill on the next beat. Built as
    WORLD-AND-MUSIC.md's MW1 (the hooks for all of it live there).
- [ ] **J6. The organ-era rhythm box** (Nikki: "the truly whimsical ones"). dreamengine has a sourced
  library of them: `runtime/rhythmbox.h` (101 preset rhythms read off the Ace Tone FR-2L, Roland TR-77
  and SGS chip manuals and a 1969 Hammond patent; generated from its `docs/design/rhythm-box-patterns.md`),
  played by its `autorhythm` cart with `runtime/sideman.h`'s Wurlitzer Side Man tube voices (the `sideman`
  cart). Not drum-patterns.json's 16-step grid: 24 or 48 counts a bar, divided per rhythm (a waltz by
  three), counts a rhythm skips, held (gated) lanes, and lanes that gate a CHORD or a BASS: the auto-
  accompaniment. Probably its own loop style rather than a jam genre (no layers, a waltz, a bass + chord
  from the rhythm itself), and it needs the Side Man voices as patches. To decide with Nikki.
- [ ] **J5. In the game.** In the `set` rotation or not, what a room/scene can ask of it (a calmer jam
  for a quiet room), and whether the Mipos dance to its kick (`music.onNote`; WORLD-AND-MUSIC MW3).
  Where it stands (2026-11-03): the game drives it through the play level and the world's moments
  (impacts J10e; snaps, doors and the rest in drums, STINGERS S4a), but it's not in the set and no room
  or zone cues it, so it's only heard when picked. As background music it hasn't been listened to over a
  long session: fatigue, busy play masking the sound effects, handoffs to and from the composed styles.
  The dreamengine port (rootwalk) gets its additions subtractive first (J8b's thinning, a busyness cap).

## Notes
- Another session works on the composed styles (MUSIC-ANALYSIS.md's R-list) in music-plan / music-parts /
  music-styles. The jam keeps to its own files; the shared ones get one registration line each.
