# Puppetmaker sound — how Mipo Puppetmaker 2 sounds, and bringing it here

**Started:** 2026-10-28. **Status:** P1–P5 and P7 built (2026-10-29); P8 (voice size on the synth) next.

**Goal:** Mipos that feel as alive as in Puppetmaker: the hmpfs when you touch
or change them, the mi… po… chatter, and a band they sing along with and move to.

**How to use this doc:** part 1 is what Puppetmaker 2 does (source:
`../puppet-maker2`, `../../lib/melody-paint-audio-*.lua`). Part 2 is what
Playtime already has. Part 3 is the order to build the rest; tick it there.
Related: `DOLL-PLAY.md` "Voice" (V1–V6), `SOUND-SYNTH.md` (the synth, its slot map and gotchas, the
music's onNote / stepAt; the puppetmaker and strum styles there and in `MUSIC-IDEAS.md`),
`src/mipo-voice.lua`, `src/music.lua`.

**After pulling (or on a new machine): rebuild the synth.** `native/desound/libdesound.dylib`
is gitignored, so a pull doesn't update it. Playtime's code needs dreamengine `2572e0e5` or later
(INSTR_SING, `sample_formant`). An old dylib fails without an error: the voice lab breaks on the first
missing function. The Mipos' own voices (`assets/voices/`, plain LÖVE audio) still play without it.
Check: `nm -gU native/desound/libdesound.dylib | grep sample_formant` prints nothing → rebuild:

```sh
git -C ~/Projects/dreamengine pull
./playtime.sh stop && native/desound/build.sh && ./playtime.sh start   # stop first: the app holds the dylib
```

---

## 1. What Puppetmaker 2 does

Three separate systems: a sample **band** whose notes drive the Mipos, one
**growl** function (the hmpfs), and **physics** knocks.

### 1a. The band, and Mipos that react to it

A melody-paint sequencer on its own thread (`lib/melody-paint-audio-thread.lua`)
plays one song, `assets/mipo4.melodypaint.txt`. 60 bpm in 16ths, so a 16-step
bar loops every 4 s, swing 52. Every note has a **chance** (%), some have
**rnd** (a random note from the scale instead of their own). The song has two
pages, one per screen:

| Voice | **Page 1: outside** (all five Mipos) | **Page 2: editor** (one Mipo) |
|---|---|---|
| CR-78 conga low | steps 1, 5 (50%), 9, 13 (60%) | — |
| CR-78 bongo low | 2, 7, 10 (80%), 3, 6, 11 (60%), 14, 15 (90%) | — |
| CR-78 bongo high | 1, 5, 10, 14 (80%), 3, 7 (50%), 9 (40%), 12 (70%) | 11, 13 (20%) |
| CR-78 tamb 1 | 1, 10, 13 (100%), 3, 4, 15, 16 (80%), 12 (70%), 8 (30%) | 3, 15 (10%), 7 (20%), 12 (30%) |
| CR-78 guiro 1 | 8 (50%) | 7 (20%, rnd) |
| Triangles 101 / 103 | 5 (60%), 13 (80%) / 6 (60%), 14 (40%) | 3 (10%), 15 (20%, rnd) / 14 (20%, rnd) |
| babirhodes rhodes2 | 9 (50%, rnd) | 8 (10%, rnd) |
| **mipo pi** | **4, 12 (50%), 14 (90%, rnd)** | — |
| **mipo po3** | **2, 10 (20%, rnd), 16 (30%, rnd)** | — |
| babirhodes ba / bi / biep2 / biep3 | 8 / 12 / 16 / 3, all 5%, rnd | — |
| mp7 Quijada | — | 10 (20%) |

The thread reports every note it plays back to the main thread (`played`, with the sample
path, the pitch and the source). On the outside screen `scene.handleAudioMessage`
(`scenes/outside.lua`) turns those into the Mipos' movement:
- `pi` / `po3`: a random Mipo of the five opens its mouth (`mouthSay`) for the
  length of the sample at that pitch. **The singing belongs to the band; the Mipos lip-sync to it.**
- Triangles: `breathBody`, a small upward push on that Mipo's torso (-1000).
- rhodes2: `doinkBody`, a hard downward push (+10000), a little squash.
- `JUST_ONE_GUY` (false) would send all of it to the picked Mipo. The editor's handler is empty.

**A crowd versus one Mipo:** outside, the groove is dense, the band sings and random
Mipos mouth along, breathe and bounce. In the editor the music is sparse and nobody sings:
the one Mipo only makes sounds when you touch it or change it (1c).

#### The band's samples, measured (2026-10-29), and how the synth could play them

The song file has no scale, so it's **chromatic**: a note marked rnd lands on any of the 12
semitones. Together with the sparse chances, that's the feel: a dry, swung CR-78 hand-percussion
loop with a dreamy chord that floats in at an unrelated pitch every few bars, and nothing
resolves. No bass, no tune, no chord changes.

| Sample | What it is (measured) | Synth recipe (we have these: `src/synth.lua`) |
|---|---|---|
| `babirhodes/rhodes2` (3.0 s) | **Not a lick: one rolled chord.** Six notes: E♭3 B♭3 G4 B♭4 C5 E♭5, root + 0, 7, 16, 19, 21, 24 (an E♭6 with the octave on top; the E♭5 is played, not an overtone). A hand's up-strum: +29, +23, +23, +76, +40 ms (quick, then a lag before the top two), swelling for ~0.5 s, ringing past 3 s. (First read as five notes 60 ms apart; re-measured by the music side, 2026-10-29) | EPIANO (`rhodes` slot), those six notes and gaps, root moved by the rnd semitone: what the puppetmaker style plays. **The same voicing every time, only the pitch moves** |
| `babirhodes/ba` (0.4 s), `bi` (0.2 s) | single voiced notes, ~E4 / ~F♯4 | EPIANO single notes, or `INSTR_VOICE` with a b-consonant (a/i vowel): synthetic "ba"/"bi" backing vocals |
| `babirhodes/biep2/3` | no clear onset or pitch: bends or blips | a short gliding note (`instrument_glide`), or a VOICE "biep" |
| Triangles 101 (0.09 s) / 103 (1.8 s) | metallic, partials ~5.5 kHz and ~8.4 kHz; a choked hit and a ringing one | METAL (or a high MALLET), short release vs long ring |
| CR-78 conga low, bongo low/high | short hand drums (0.42 / 0.14 / 0.13 s) | MEMBRANE (`conga`, `tabla` patches exist) |
| CR-78 tamb 1 (0.29 s) | jingle burst | NOISE, highpassed, short (like `shaker`) |
| CR-78 guiro 1 (0.44 s) | a scrape | NOISE with a fast amplitude LFO (~25–35 Hz), bandpassed |
| mp7 Quijada (0.8 s) | a decaying rattle | NOISE or METAL with a fast amplitude LFO, long decay |
| mipo pi / po3 | the singing (P4) | keep as samples (`assets/voices/puppetmaker`): the voices are the characters |

The groove: 60 bpm in 16ths (one bar = 4 s), swing 52, and every hit has its chance from the
table in 1a. Page 1 (a crowd) is the dense one; page 2 (one Mipo) is the same kit at 10–20%.

### 1b. The intro: mi… po…

- The logo spells out MI, then PO, each with a spoken sample, pitched 0.7–1.2.
  A MI is `mi` 80%, `mi2` 16%, `mo` 4%; a PO is `po` 80%, `po2` 16%, `pi` 4%.
- The last state loops `makeRandomMipoSound`: wait 0.2–2.2 s, one random Mipo
  says MI; wait 0.2–1.2 s, another one says PO; both flap their mouths. "Another"
  was meant to differ from the first, but the check is `index2 == index2` (always
  true), so it rerolls once and can still land on the same Mipo.
- Music: `mipolailoop` on the splash, `introloop` (volume 0.5, looped) in the intro.
  The editor fades both out (×0.9 per frame).

### 1c. `growl()`: the hmpfs (`main.lua`)

- **Pool:** humup1–3, blah1–3, huh, huh2, tsk, tsk2. Not humup4, no humdowns.
- At double volume. **One growl in the whole app at a time** (a new one stops the
  last), and it flaps the picked Mipo's mouth.
- **Triggers:**
  - Pressing a Mipo: pitch 1. Outside, that also picks the Mipo and makes it jump (-5000).
  - Every edit in the editor (`src/editguy-ui.lua`): picking a part, toggles, sliders: pitch 1–1.2.
  - The +/- steppers set the pitch from the value: min…max → pitch 1…3.
    **Making something bigger raises its voice.**

### 1d. Other sounds

- **Winegum kisses:** a winegum hit with normal impulse over 60 (and tangent over 3). Pitch 2 → 0.25,
  volume 0.2 → 1 as the hit gets harder.
- **Rubber plonks:** head/torso/feet against the border, body-body, head-head,
  hand-head, hand-body; normal impulse over 300 (tangent over 50). Pitch 2 → 1 (min 0.5), volume 0.2 → 1.
  The same pair of fixtures plays at most once per 0.5 s.
- **UI:** `BD-perc` ticks while a list scrolls, the Casio MT70 bass drum on clicks, Quijada on the dice.
- `rubber-stretch1-2` are loaded but never played.
- Blinks (each Mipo, every 0–5 s) and looking at the press aren't tied to sound.

### 1e. The sample files (and the naming mess)

Puppetmaker keeps the same takes twice: `assets/sounds/{mi,mi2,mo,po,po2,pi}.wav`
(intro) are byte-identical to `assets/instruments/mipo/` (the band), which adds
`mi3`, `po3` and `blah1-3`. The blahs are the same files as `sounds/fx/blah1-3`.
They are **different recordings** from the mipomi `nikki` syllables (other lengths).

---

## 2. What Playtime has

- **In our repo now (2026-10-28), all ogg:**

  | Puppetmaker 2 | Playtime |
  |---|---|
  | mipo takes mi, mi2, mi3, mo, pi, po, po2, po3 | `assets/voices/puppetmaker/` |
  | growl pool + humup4 + humdown1-4 | `assets/voices/fx/` (already there) |
  | rubber plonks, winegum kisses | `assets/sounds/` (already there) |
  | rubber stretches, BD-perc, Quijada | `assets/sounds/` |
  | CR-78 conga low, bongo low/high, tamb 1, guiro 1 | `assets/sounds/cr78/` |
  | Triangles 101/103 | `assets/sounds/triangles/` |
  | babirhodes rhodes2, ba, bi, biep2, biep3 | `assets/sounds/babirhodes/` |
  | Casio MT70 bass drum, hat+clave | `assets/sounds/casio-mt70/` (already there, same files) |
  | music: mipolailoop, introloop | `assets/music/` |

  Not copied: the unused fx (BD-lofi, BD-SNARE-TOM, HiHat Accent/Metal, blah4), introloopOld,
  the rest of the CR-78 kit. Licenses are in `assets/sounds/README.md` (some sources unknown).
- **`src/mipo-voice.lua`** (DOLL-PLAY V3/V3b):
  - The growl pool, as `pickup` on grab. It's **per Mipo** (its own voice pitch, a cooldown)
    instead of one growl for the whole app.
  - The mouth flap, plonks, kisses and the hop on grab.
  - `oof` from the humdowns, which Puppetmaker never used.
- **`src/music.lua`** synthesizes the music live (`src/synth.lua`), not a sample
  sequencer, so nothing can say "this note just played" yet.
- **Missing:** the hmpf on editing, the band's singing, moving to the music, the mi… po… chatter.

---

## 3. Order to bring the rest in

- [x] **P1. Hmpf on editing** (2026-10-29). `src/ui/mipo-editor.lua` draws through a
  small `ui` wrapper: every slider change, checkbox, thumbnail pick and colour makes the Mipo
  hmpf (`mipoVoice.edited`, the `pickup` pool). Sliders set the pitch from where the value
  sits in its range (min…max → 1…3, `mipoVoice.editPitchMax`); picks and toggles 1…1.2.
  While a slider drags, the next hmpf waits for the last to finish (no stutter).
  Randomize / mutate play the Quijada rattle plus a hmpf (`mipoVoice.dice`).
**Who builds what (2026-10-29):** the music session builds the band as `style = 'puppetmaker'`
in `music.lua` (its patches in synth slots 40–44; 45–47 are free for the sound-effects side, ask first)
and the hook: `music.onNote(name, fn)`, fn(part, patch, midi, vol, durMs, t, step), nil removes it.
It's a function call, not a field on the module (hot reload). `t` is booked ~0.3 s ahead: compare with
`synth.audioTime()`. `music.nowPlaying()` gets `stepTime` + `stepLen` for the swung grid. P3/P4
start once that lands.

- [x] **P2. A "note played" event from `music.lua`** (2026-10-29, by the music side: `music.onNote`). Report the instrument, step and length,
  e.g. `music.onNote(fn)`. Everything below needs it.
- [x] **P3. Mipos move to the music** (2026-10-29, `src/mipo-band.lua`: triangle → a breath, the rolled chord → a doink, on a random free Mipo). A breath on a soft beat, a doink on a
  chord hit, only for Mipos that aren't held or dazed.
- [x] **P4. A Mipo voice in the band** (2026-10-29: the music books `sample:pi` / `sample:po3` on Puppetmaker's steps and odds, dense page only; `src/mipo-band.lua` has a free on-stage Mipo sing them in its own voice, two or more needed; ba/bi/biep play as the band's samples. `spec/mipo-band_spec.lua`). A sparse mi/po part, Puppetmaker-style chances and
  rnd, using `assets/voices/puppetmaker/`, pitched into the song's key. A Mipo on stage mouths each note:
  - with several Mipos, a random one sings;
  - with one Mipo you're editing, nobody sings (the page 2 rule).
- [x] **P5. Idle mi… po… chatter** (2026-10-29). `src/mipo-chatter.lua`: every 6–15 s
  (`gap`) a Mipo says MI and a *different* one answers PO 0.2–1.2 s later, with
  puppet-maker2's odds, from `assets/voices/puppetmaker`, at each Mipo's own voice pitch
  ×0.8–1.2 (`mipoVoice.say`). Only Mipos in view, not held, dazed or talking; two
  needed; not while paused. Spec: `spec/mipo-chatter_spec.lua`. Off: `mipoChatter.enabled`.
- [ ] **P6. Voice in DNA** (= DOLL-PLAY V5). The singing and chatter use each Mipo's own voice set and pitch.

- [x] **P7. A voice per Mipo** (2026-10-29). `mipoVoice.voiceFor` spreads each Mipo over
  pitch 0.6–1.7 (`pitchRange`, evenly in octaves) and a tone (`toneRange`, a LÖVE lowpass
  on the source) that follows the pitch: deep Mipos are dark, high ones clear. Every Mipo sound uses it.
- [ ] **P8. Voice size, not just speed.** Playback rate moves pitch and formants together
  (slow tape vs chipmunk). A real "big vs tiny" voice needs a formant shift on samples:
  dreamengine issue NikkiKoole/dreamengine-studio#44 (`sample_formant`). After that: a few
  shared voice types through desound (8 sample slots, a limited number of effect chains, shared
  with `music.lua`; coordinate first).
  **Built in dreamengine (2026-10-29, master d1ae370d, not pushed):** `sample_formant(slot, semis)`
  (offline, ±7 best) and `INSTR_SING` (38): one syllable sings any note as the same speaker.
  Size (`timbre`/`note_timbre`) and inflection (`harmonics`/`note_harmonics`, 0.5 = the take's own
  melody) are per voice, so Mipos can share one slot and one sample with their own size. Tested on
  our takes (po3, mi, mo, huh, humup2): in tune within ~7 cents, keep a Mipo within ~±7 st of its
  take. Gotchas: `assets/voices/puppetmaker/*.ogg` are 48 kHz, so resample to 44.1k before
  `sample_load`; "huh" has a voiced part and gets pitched (ears: maybe keep grunts as plain samples).
  Bindings + rebuild done (c906eaee). **Voice lab** (2026-10-29, `src/voice-lab.lua`, settings →
  voice lab): one take, speed (the chipmunk: rate) + shift (pitch, length kept) + size (throat)
  mixed, played as 'now' (LÖVE, today's sound), 'synth' (shift/size baked in, played at speed) or
  'sing' (INSTR_SING). Sample slot 7, instrument slots 45/46. Listen there first (clicks, noise,
  the grunts), then decide what the Mipos get.
  Lab findings (2026-10-29): 'synth' at all zeros = 'now' in pitch and length (measured, 0.00 st);
  it was ~15 dB quieter at level 1 (it sounded lower), so the lab plays it at level 4, note vol 7
  (`spec/voice-lab_spec.lua`). Size + is a bigger throat (centroid 1258 -> 1042 Hz at +6 on po3); a
  big Mipo is size + with the pitch down. Nikki prefers 'synth' over 'sing' (keep both).
  **INSTR_SING is not a one-shot** (to hand to dreamengine): it sounds only while held, plus its
  release (released at once: ~0.1 s, the word cut off; "release finishes the word" doesn't happen),
  and it sustains the held vowel by repeating it, which sounds loopy. The lab holds it for the
  take's length. Ask: a one-shot mode, NikkiKoole/dreamengine-studio#46. **Landed** (dreamengine
  2572e0e5, pushed): `instrument_mode(slot, 0, 1)`,
  the take once through at its own length whatever the note's length; the lab's 'sing' uses it
  (`spec/voice-lab_spec.lua` checks it).

**Listen before P4:**
- The Puppetmaker takes vs the mipomi `nikki` syllables. `po3` (0.69 s) sounds like the sung one.
- `babirhodes` ba/bi/biep are voice-like too: maybe the band's "backing vocals".
- Whether the CR-78/triangle samples are worth a sample layer next to the synth music,
  or whether `music.lua` gets its own percussion instead.
