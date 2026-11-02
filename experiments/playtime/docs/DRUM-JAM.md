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
- **The patterns**: dreamengine's `tools/drum-patterns.json`, 565 named 16-step patterns in 92 groups.
  The jam uses three (Nikki's pick): **Electro** (13), **BoomBAP** (1) and **CR78** (4, the Roland preset rhythms),
  one grid per role: BD SD CPS (clap) CH OH CY RS CB LT MT HT TB, plus AC (accent). A step is `x` (a hit),
  `f` (a flam) or `.`. `claudetools/jam-patterns.py` turns the groups the jam uses into
  `src/music-jam-patterns.lua` (generated; rerun it, don't edit the output).
  Provenance is uneven, and dreamengine's `runtime/drumpat.h` says so: converted from the maker's own
  drum-patterns.lua, whose header cites "Drum Machine - 260 Patterns" for its core set and nothing for
  the later groups. Fine for us, but don't call a pattern "the real X" from this data.
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
  on each phrase's last bar, a breakdown and a drop every few phrases when the jam is busy. The three
  groups from the library (Electro, BoomBAP, CR78), one picked per song; the general patches. Done when: rendered with the play level stepped up and
  down (`render-music.lua`'s busyFrom), the layers can be heard coming in and going, and the drop lands.
- [ ] **J2. The vocabulary.** The group's variants rotated every few phrases (more groups only if
  wanted: a line in jam-patterns.py), mutations (hat density, ghost snares), flams. A jam picks its group per
  song, or moves between related ones.
- [ ] **J3. The 303 as a layer.** The acid style's pattern code shared, not copied: the 303 enters as a
  layer, its filter sweep tied to the phrase (open into the drop).
- [ ] **J4. The kit.** Decide port vs desound.c (above), then an 808 and a 909 kit, picked per group.
- [ ] **J5. In the game.** In the `set` rotation or not, what a room/scene can ask of it (a calmer jam
  for a quiet room), and whether the Mipos dance to its kick (`music.onNote`).

## Notes
- Another session works on the composed styles (MUSIC-ANALYSIS.md's R-list) in music-plan / music-parts /
  music-styles. The jam keeps to its own files; the shared ones get one registration line each.
