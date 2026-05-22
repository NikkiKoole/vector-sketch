# melody-paint — things to think about

Notes only, not a plan. Written 2026-05-22.

Anchor files:
- `main.lua` — sample table, UI, voice setup
- `lib/melody-paint-audio-helper.lua` — channel plumbing, song/page model
- `lib/melody-paint-audio-thread.lua` — the actual sequencer; 96 ticks per beat

---

## 1. Dilla timing

**What it is:** off-grid timing that gives a beat its "drunk MPC" feel. Three flavors, can be combined:
- **Per-voice push/pull** — kick a hair late, hat a hair early, snare way late. Constant offset per voice.
- **Per-step micro-offset** — individual notes nudged forward/back in ticks (the "swung 16th that isn't quite swung").
- **Humanize** — small random tick jitter per hit so it doesn't sound mechanical.

**Where it plugs in:** `melody-paint-audio-thread.lua:212` already computes `tickOffset` (swing + note-repeat spread). Extend it to add `voices[v].timingOffset` + `pattern[index][i].timingOffset` + optional random jitter. Tick budget is generous (96/beat → ~6.5 ms per tick at 90 bpm), so even ±20 ticks is musical.

**Why current swing isn't enough:** line 206–208 only swings even beats by one global amount. Dilla feel is non-uniform across voices.

**Open question:** UI surface. Two paths:
- Global "Dilla amount" knob → procedurally derives per-voice offsets from sample type (kicks late, hats early). One knob, opinionated.
- Per-voice timing strip in the voice editor. More expressive, more UI.

I'd start with the one-knob version. Cheaper, demos faster, and the "wrong" answer still sounds good.

---

## 2. Icons / better communicating samples

**Current state:** `sample_data` in `main.lua:223` pairs each sample with an arbitrary animal sprite (zebra=mipo/mi, octopus=mipo/po, …). Banks are colored via `spriteBackgroundMap` (`main.lua:369`). The animals are charming but say nothing about what the sample *does* — is it a kick, a lead, a vocal? Bass or hat? Pitched or one-shot?

**What's missing communicatively:**
- Function (kick / snare / hat / bass / lead / pad / perc / vocal)
- Pitched vs one-shot (does dragging up the column even do anything musically?)
- Pitch range hint (this sample's "natural" octave)

**Options:**
- **Tag samples with a role** in the sample_data table (e.g. `{ 'zebra', 'mipo/mi', role='vocal' }`) and overlay a small role glyph on the animal sprite. Animals stay as identity; glyph carries function. Cheapest, keeps the cute.
- **Replace animals with role-first icons** entirely. Loses charm but reads instantly. Probably wrong vibe for melody-paint.
- **Sort/group by role in the sample bank** instead of by bank. Less visual change, more cognitive change.

Likely best: tag + small glyph + keep bank-color backgrounds. Three signals (bank color / animal identity / role glyph) without redesigning anything.

**Side question:** the animal-to-sample mapping has obvious duplicates (3 zebras, several bats, hamster used for ~8 totally different things). Is that intentional aesthetic, or just leftover? If you ever want function-readability, those dupes have to go.

---

## 3. Per-instrument / per-voice settings

**What already exists:** `voices[v]` carries `voiceIndex`, `voiceTuning`, `voiceVolume` (used in `audio-thread.lua:143-146`). Pattern cells carry `noteVelocity`, `noteRepeat`, `notePitchRandomizer`, `chance`, `octave`, `semitone`.

**What's missing (the wishlist for a per-voice editor):**
- pan
- timing offset (see Dilla above)
- pitch-jitter range (the `// todo parametrize micropitch randomizer` comment at line 193 is already pointing at this)
- choke group (the function exists at line 66 but is never called — useful for closed/open hat pairs)
- amp envelope: attack/decay, or just a length cutoff
- per-voice swing amount (override global)
- per-voice filter (LP cutoff) for darkening
- per-voice tape/LFO depth (see §4)

**Where it plugs in:** the voices table is already shipped to the audio thread via `{type='voices', data=voices}` (`main.lua:517`). Adding fields is free; the work is UI.

**UI question:** the current voice picker is a flat strip. A long-press → voice editor panel is the natural pattern. Could borrow from the puppet-maker2 slider UI (`src/editguy-ui.lua` `draw_slider_with_2_buttons`).

**Why this matters:** without per-voice anything, every sample plays at the same loudness, same length, same straight grid. Adding even 2–3 of these (pan, length, pitch-jitter) makes arrangements stop sounding flat.

---

## 4. Tape / wobble / warble / LFO

**What it is:** slow pitch modulation (wow ~0.5–2 Hz, flutter ~5–10 Hz), often with a touch of noise on the rate. Optionally a high-cut to take the digital edge off. Classic cheap "this came off a cassette" sound.

**Two ways to do it in LÖVE:**

- **Offline / baked:** pre-render each sample through a wobble pass and ship the wobbled copy. Zero runtime cost, no realtime modulation. Loses per-note variation — same sample sounds the same every time.
- **Realtime:** the audio thread already tracks live sources in the `sources` table (line 64) and loops fast (~5 ms). Add an LFO per source (random phase at note start) and call `source:setPitch(basePitch * (1 + lfoDepth * sin(phase)))` each loop iteration. Cheap. Per-note phase → no sync artifacts. For high-cut, `source:setFilter({type='lowpass', volume=1, highgain=x})`.

Realtime is the right call here — it's the same trick you already use for note pitching, just modulated over time instead of static.

**Knobs to expose:**
- depth (cents of pitch modulation, e.g. 0–30)
- rate (Hz)
- rate jitter (0–1; how much noise on the rate)
- high-cut (filter cutoff)

**Scope:** global "tape" toggle first. Per-voice depth later (and it stacks naturally with §3).

**Gotcha:** `setPitch` is non-zero-crossing, so heavy modulation on long sustained samples can sound chirpy. Keep depth small (under ~20 cents) for the tape feel; bigger values become chorus/vibrato.

---

## Order I'd attack these in

1. **Per-voice editor with 2–3 fields** (volume, pan, timing offset). Unblocks both Dilla and tape.
2. **Tape global** — single toggle, one good preset. Immediate vibe upgrade, low risk.
3. **Dilla timing** — one-knob version using the voice timing-offset from step 1.
4. **Icon clarity** — last, because it's UX polish and doesn't affect what songs are possible.

Each one is its own session. None of them are "and also" each other.
