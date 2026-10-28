# Puppetmaker sound — how Mipo Puppetmaker 2 sounds, and bringing it here

**Started:** 2026-10-28. **Status:** analysis done, samples copied in, nothing built yet.

**Goal:** Mipos that feel as alive as in Puppetmaker: the hmpfs when you touch
or change them, the mi… po… chatter, and a band they sing along with and move to.

**How to use this doc:** part 1 is what Puppetmaker 2 does (source:
`../puppet-maker2`, `../../lib/melody-paint-audio-*.lua`). Part 2 is what
Playtime already has. Part 3 is the order to build the rest; tick it there.
Related: `DOLL-PLAY.md` "Voice" (V1–V6), `SOUND-SYNTH.md`, `src/mipo-voice.lua`, `src/music.lua`.

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

- [ ] **P1. Hmpf on editing.** Every change in the Mipo editor makes that Mipo
  hmpf (the `pickup` pool, through `mipoVoice.squeak`); sliders and steppers set the pitch
  from the value, min…max → 1…3. Smallest step, clearest win.
- [ ] **P2. A "note played" event from `music.lua`.** Report the instrument, step and length,
  e.g. `music.onNote(fn)`. Everything below needs it.
- [ ] **P3. Mipos move to the music.** A breath on a soft beat, a doink on a
  chord hit, only for Mipos that aren't held or dazed.
- [ ] **P4. A Mipo voice in the band.** A sparse mi/po part, Puppetmaker-style chances and
  rnd, using `assets/voices/puppetmaker/`, pitched into the song's key. A Mipo on stage mouths each note:
  - with several Mipos, a random one sings;
  - with one Mipo you're editing, nobody sings (the page 2 rule).
- [ ] **P5. Idle mi… po… chatter.** With two or more Mipos standing around, one says MI and
  a different one (actually check this time) answers PO, at 0.2–2.2 s and 0.2–1.2 s gaps.
- [ ] **P6. Voice in DNA** (= DOLL-PLAY V5). The singing and chatter use each Mipo's own voice set and pitch.

**Listen before P4:**
- The Puppetmaker takes vs the mipomi `nikki` syllables. `po3` (0.69 s) sounds like the sung one.
- `babirhodes` ba/bi/biep are voice-like too: maybe the band's "backing vocals".
- Whether the CR-78/triangle samples are worth a sample layer next to the synth music,
  or whether `music.lua` gets its own percussion instead.
