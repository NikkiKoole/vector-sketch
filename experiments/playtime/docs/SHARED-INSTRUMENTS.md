# Shared instruments: dreamengine's sounds, Playtime's game

status: active

Nikki (2026-11-03): "a smooth interop: dreamengine has all the goods and we use it, but some parts are
so game dependent that we need to call into it". Playtime's 57 patches (`src/synth.lua`, `lib.patches`)
are already data, but many are hand-copies of dreamengine carts ("the epiano cart's suitcase", "after
upright.c") and drift, the same drift dreamengine's `docs/guides/instrument-presets.md` describes between
its own carts. Worked out with dreamengine-8e.

## The split

- **dreamengine owns the SOUND**: a preset is engine, ADSR, filter, macros (harmonics / timbre / morph),
  modes, envelopes, glide, under the catalog's names (`epiano/suitcase`, `bowed/upright-pizz`).
- **Playtime owns the GAME side**: which slot, the level in its mix, the reverb send, its own names
  (`musicBass` = `bowed/upright-pizz`) and local overrides; the play level, events, rooms.
- Shared the way the drum patterns are: dreamengine writes `presets.json`, a Playtime generator turns
  it into a Lua file (`jam-patterns.py`'s route), so iOS and web builds and hot reload need nothing new.

What dreamengine has today (dreamengine-8e): the catalog has 147 names but the recipes are prose
shorthand; `tools/patch-match/pmpatch.h` is real data but 0..1 normalized, for the optimizer, unnamed.
So a named preset as data doesn't exist yet.

Format rules (dreamengine-8e): constants BY NAME, never numbers (`"FILTER_LP"`, `"MODE_BOW_PIZZ"`), so a
renumbered enum can't cross-wire; `modes` as `{ name = value }` (MODE_* are per engine); units as
`studio.h` has them (a/d/r ms, sustain 0..7); `requires` = the API functions a preset uses, so
Playtime warns when its dylib lacks one. No level, no reverb send, no FX buses in a preset (yet).

## Steps

- [ ] **I1. Decide the route** (Nikki): dreamengine EXPORT-ONLY first (a generator writes presets.json
  from one source of truth; dreamengine-8e's lean), or carts READ it at runtime (`preset_apply(slot,
  name)`: an engine API change and every cart that adopts it; later, if at all). And whether a preset
  may span slots: the 303 (`acid303.h`) and the drum kits (`drumkit.h`, `tr808.h`) are several slots
  plus logic, and the first slice meets them.
  Nikki (2026-11-03), not decided: "we still want a way to model an instrument just here, but at the
  same time we might just want a big ass library of instruments in dreamengine that just works(tm);
  also might need a cart in dreamengine that allows us to listen to all of them, at the same time
  this conflicts with the 1 cart for a game thing". One way it could fit (an option, not picked):
  - The library is DATA, not a cart: dreamengine's `presets.json`, read by every cart and game.
  - The listening cart is a TOOL cart (like the probe carts, patch-match), not a game, so maybe not
    against one-cart-per-game; check with dreamengine-8e what the rule covers.
  - Or listen in Playtime: a preset browser in the voice lab once I3 reads them, heard through
    Playtime's own mix and reverb (the sound the game has). Then the dreamengine cart is optional.
  - Instruments made here: a `presets-local` in the same format; a Playtime patch is either a named
    preset + Playtime's slot / level / reverb, or a whole preset of its own. Local wins over
    dreamengine's; a good local one gets promoted into dreamengine's file and the copy goes.
    Nothing has to start in dreamengine.
  Still open with it: presets spanning slots (the 303, the kits), and export-only vs read at runtime.
- [ ] **I2. The first slice, ~10 presets**: the ones Playtime already copies, so they stop drifting:
  epiano/suitcase, the upright pizz (rootwalk uses it too), vibes, kalimba, the 303, 3-4 drum skins.
  Written by hand at first; for more, a probe cart per preset that dumps the slot's real state (DE_TRACE).
- [ ] **I3. Playtime reads them**: the generator, and `lib.patches` entries that name a preset plus
  Playtime's own slot / level / reverb / overrides. Checked: each converted patch renders the same as
  before (offline render, compare).
- [ ] **I4. Every patch borrows a slot** (Nikki: "we don't need 48+ instruments at once, but we might
  use more in a game in total"). The 48 slots (`SOUND_INSTR_SLOTS`; 0-4 the raw waves) become a cache:
  a note's patch loads into a slot when needed, into the one quiet longest. Today only 8 pool slots work
  that way (`lib.poolSlots`, `claim`) and the rest are fixed. The limit becomes ~43 SOUNDING AT ONCE,
  not 43 in the game. Care: a slot is busy from booking (up to a bar ahead) to its release's end;
  loading costs a few engine calls, so keep the latest; the sounds that must be instant (impacts,
  squeaks, clicks) may keep fixed slots. Playtime-only, no engine change.
- [ ] **I5. Effects: easier, sturdier, cheaper** (Nikki: "take a good look", with dreamengine).
  Below.

## I5: effects, what we found

How it works now: the engine has 8 buses, the master plus 7 aux (`SOUND_FX_BUSES`, ~82 KB of buffers).
A slot's FIRST per-slot effect (tape, chorus, flanger, phaser, autopan, ringmod, fx filter) claims an aux
bus for good (`fx_bus_for`); when the 7 are gone, the next slot asking stays DRY, silently
(`fx_bus_overflow` counts it). Playtime works around it: 14 patches with pedals (`fx = true`: rhodes,
pianos, feltKeys, guitars, flute, junoPad, ...) share 5 effect slots (`lib.fxSlots`), switching the
last patch's pedals off on load.

What dreamengine-8e found in the engine (2026-11-03, measured on this Mac; read-only, nothing changed):
- **Group buses exist** (#47, 2026-11-02): `instrument_group(slot, lead)` plays `slot` through `lead`'s
  bus, `reverb_bus_into(tank, lead)` folds a reverb into it, `instrument_fx_filter(lead, ...)` filters the
  group and its room as one record. A note keeps the bus it started with. Playtime's dylib (2026-11-03)
  and CDEF already have `instrument_group`.
- **No release**: buses go out 1..7 in order, back only at an engine reset. But a pool works TODAY: a few
  BUS-HOLDER slots own the buses, set up once; a patch's slot points at one with `instrument_group`
  (again to re-point). Missing: a way to wipe a bus's effects for reuse (`instrument_fx_clear(slot)`).
- **No bus needed**: autopan has a per-voice twin (`instrument_lfo(slot, n, LFO_PAN, ...)`; each note sweeps
  on its own, the same on a pad, not on a strum), tremolo too (LFO_VOLUME), and `instrument_filter` is
  per voice: `instrument_fx_filter` only earns its bus on a group.
- **Cost**, in voices (one held saw note ~0.09% of an M-series core; a phone 2-4x slower, the ratios
  hold): leslie 2.9, tape 2.5, phaser 1.8, fx_filter 1.75, chorus 1.4, flanger 1.3, crush 0.7, tremolo
  0.65, LFO_PAN 0.55 a note, eq 0.3, bus autopan 0.25, width 0.2; tape + phaser + chorus + autopan ~4.8.
- **A bus runs every sample, silent or not** (no idle skip): a pedal patch parked on a quiet slot costs
  its full price.
- **"Off" wasn't uniform**: phaser, tremolo and autopan stopped at mix/depth 0, chorus and flanger kept
  running. Playtime's `definePatch` "switches off the last patch's pedals" on an fx slot by setting them
  to 0, so every fx slot paid for a silent chorus (~1.1 voices) and flanger (~1.25): ~12 voices for the 5
  (measured on Playtime's own calls; a zeroed tape was already near free). Fixed in the engine (I5d1).

Steps, cheapest first:
- [ ] I5a. Playtime: on an fx slot, call only the pedals the patch has. Tidiness only since I5d1 (the
  zeroed ones cost nothing now).
- [ ] I5b. Playtime: `./playtime.sh audio` shows the engine's "FX bus pool exhausted" warning (stdout
  grep), so a dry patch isn't a mystery; later a real getter (`fx_buses_free()`, engine).
- [ ] I5c. Playtime: autopan and tremolo as per-voice LFOs on the patches that hold one voice (pads,
  held keys): no bus. The fx filter → `instrument_filter` where no group needs it.
- [ ] I5d. Engine (Nikki picks, dreamengine-8e builds).
  - [x] I5d1. Chorus and flanger at mix 0 skip their work (dreamengine `e0fb8df5`, 2026-11-03; output
    bit-identical over every cart; the chorus's LFO keeps running so riding it back up is the same, a
    flanger switched back on starts from a clean line). Playtime's dylib rebuilt from it the same day
    (`native/desound/build.sh`), the game restarted, the synth playing. No Lua change.
  - [ ] I5d2. An idle skip (a bus silent past its tail stops running) and `instrument_fx_clear(slot)`.
    Not picked yet.
- [ ] I5e. Playtime: a band bus per style (lofi, dusk: one tape and phaser for the band via
  `instrument_group`, the reverb folded in), bus holders instead of fx slots, so I4's cache covers the fx
  patches. Measured before and after (`./playtime.sh bench`, the phone).
