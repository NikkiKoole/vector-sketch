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

Ideas to weigh (dreamengine-8e looks at the engine side):
- **Group buses instead of per-instrument ones.** A band's tape wobble is the RECORDING's, not one
  instrument's (lofi, dusk): one "band" bus with the tape and phaser, the instruments feeding it, costs
  one bus instead of three and sounds more like one tape. The engine has the routing for reverb tanks
  (`reverb_bus_into`, issue #47); a general "slot into group bus" would be the piece.
- **A bus that can be given back** (`fx_bus_release(slot)` or re-pointing a bus to another slot), so a
  pool doesn't have to keep effect slots apart, and I4 can cover the fx patches too.
- **Which effects need a bus at all.** Autopan is a pan LFO; if it could live on the voice (like the
  vibrato LFOs), it would take no bus. Same question for the fx filter.
- **Say when it overflows.** `fx_bus_overflow` exists in the engine; Playtime's `./playtime.sh audio`
  could show it, so a dry patch isn't a mystery.
- **What a bus costs per frame** (each insert runs every sample, whether a note sounds or not?): a
  measure before choosing; on the iPhone SE 2 the synth thread is the budget.
