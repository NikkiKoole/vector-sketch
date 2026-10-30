# Harvest: navkit and dreamengine — what Playtime could take

status: reference

**Written:** 2026-10-29 (a read-only survey; nothing ported yet).

**What this is:** two of Nikki's other repos read for systems and ideas that fit Playtime's
doll-play world: `~/Projects/navkit` (a Dwarf-Fortress-like colony sim in C) and
`~/Projects/dreamengine` (Nikki's C engine; Playtime already uses its synth, see
`SOUND-SYNTH.md`). For each find: where it is, how it works, and what it could become here.
Navkit is a top-down grid and Playtime is side-view Box2D, so the grid sims need adapting
(per body, per container, or particles).
Related: `WORLD-BUILDING.md` (grass, sky, terrain; finds from experiments/), `DOLL-PLAY.md`
(toys, signals, liveliness), `EXPERIMENTS-HARVEST.md` (the playtime-ef session's survey of
experiments/, planned).

**How to use it:** part 3 is the suggested order. When something gets picked up, move it into
the doc that plans it (DOLL-PLAY, WORLD-BUILDING, …) and mark it here.

---

## 1. navkit (`~/Projects/navkit`)

The main game's grid sims live in `src/simulation/`. Each has water levels 0–7, a "stable" flag
to skip settled cells, and timers driven by game time. Logic and electricity are **not** in the
main game. They're in a separate 32×32 prototype, `experiments/mechanisms/` (`mechanisms.c`
1716 lines, `mechanisms.h`, `demo.c`), which doesn't depend on the game world, so it's the
easiest thing here to port.

### 1a. Signals, gates, processor (`experiments/mechanisms`)
- **Data:** per cell `type, facing, state, signalIn/Out, setting, timer, delayBuf[4]`
  (`mechanisms.h:131`). There are about 40 types: switch, button, light, wire, NOT/AND/OR/XOR/NOR,
  latch, clock, repeater, pulse, dial, comparator, display, plus fluid, belt and mechanical parts.
- **Algorithm:** `MechUpdateSignals` (`mechanisms.c:331`) keeps two signal buffers. Gates read the
  *previous* tick, a one-tick delay that makes latches and clocks stable. A BFS then spreads the
  max value through each wire network (`:505`). Values are **analog 0–15**: a dial sends a level,
  and a comparator turns it into 0/1 at a threshold.
- **Processor:** `Processor{regs[4], pc, flag, program[16]}`, with ops READ/WRITE/SET/ADD/CMP/JIF,
  talking to the world through ports (`:565-640`). Presets: NOT, AND, blinker, NOR latch, half
  adder, pump loop, clock tower, sorting factory (`:1391+`).
- **Design docs:** `docs/vision/far future /mechanisms-and-signals.md`, `gates-and-processors.md`.
  - Layer 1 is event links ("lever → door"), which cost nothing per tick.
  - Layer 2 is gate propagation, layer 3 the processor.
  - Pressure plates trigger on weight.
- **For Playtime:** `src/signals.lua` already does layer 1. Take the one-tick gate delay, analog
  levels on wires (a dimmer knob → lamp brightness), and clock, pulse and latch toys. A pressure
  plate could read Box2D contact weight, so a heavy toy holds a door open.

### 1b. Mechanical power (`MechUpdateMechanical`, `mechanisms.c:1149`)
- A BFS groups connected shafts into networks. Each network sums torque (cranks, springs), load
  and inertia (flywheels), then shares one speed. Clutches cut networks apart.
- **For Playtime:** electricity as a network. A battery or crank is the source, lamps and motors
  are loads, and one shared level means too many lamps glow dim.

### 1c. Water and pressure (`src/simulation/water.c`, 874 lines; `docs/done/environmental/water-system.md`)
- **Algorithm:** a DF-style cellular automaton with levels 1–7. Each tick:
  - fall (`TryFall`, `:277`);
  - spread half the difference to lower neighbours (`:334`);
  - pressure (`TryPressure`, `:416`): water landing on a full cell starts a BFS through full cells
    that pushes 1 unit to the nearest non-full cell, no higher than `sourceZ-1`, so it rises
    like a U-tube.
  - Plus sources and drains, evaporation, freezing and thawing (`:716-800`), and rain.
- **Simpler model:** the mechanisms experiment has pipes and tanks (`MechUpdateFluids`, `:677`). It
  moves `diff/(n+1)` between neighbours, has valves gated by signals and pumps, and a pressure
  light that turns a level into a 0–15 signal.
- **For Playtime:** the side view suits falling water and U-tubes. Start with one fill level per
  container body (cup, bath, kettle) that pours into another container when they overlap or tip.
  A float switch turns the level into a signal.

### 1d. Fire (`src/simulation/fire.c`, 606 lines; `fire-system.md`)
- **Per cell:** `level` and `fuel`, with fuel taken from the material table. Burnt cells are flagged
  and tinted charred.
- **Spread** (`FireTrySpread`, `:279`): to 4 neighbours plus the cell above, in shuffled order.
  - The chance is `base + level*perLevel - ignitionResistance`, adjusted by wind (+15%
    downwind, -10% upwind).
  - Nearby water lowers it. Damp cuts it 50%, wet 90%, and soaked blocks it.
  - Fire makes smoke and heat and syncs light sources (`:585`).
- **For Playtime:** per body `flammable, fuel, ignitionResistance, wetness`. A burning body sets
  touching or nearby bodies alight by chance, burns down, and leaves a charred sprite. Water or a
  wet sponge puts it out. Toys: candle, fireplace, toast.

### 1e. Smoke and steam (`smoke.c` 569 lines, `steam.c` 456; `docs/vision/entropy-and-simulation/steam-system.md`)
- **Smoke:** a gas that rises 1 a tick (`TryRise`, `smoke.c:167`), spreads sideways when blocked,
  fills downward under pressure (`:315`), dissipates, and drifts with the wind.
- **Steam:** the same, but water at 100 °C or more boils into steam, and steam condenses back into
  falling water (`SteamTryCondense`, `steam.c:306`). Mass is conserved.
- **For Playtime:** particles rather than a grid, with upward drift, wind and a lifetime. A kettle
  lid rattles, steam drips on a cold window, smoke gathers under a ceiling and clears when a door
  or window opens.

### 1f. Temperature (`temperature.c`, 539 lines; `temperature-system.md`)
- Per-cell heat moves between neighbours at a rate set by each material's insulation, and decays
  toward an ambient value. There are heat and cold sources (`:351`), and fire adds heat.
- The dollhouse slice gives items a temperature with Newton cooling (`FOOD_COOLING_RATE`). Fresh
  food is 80 °C and gives a HOT_MEAL moodlet.
- **For Playtime:** each body has a temperature that eases toward its room's. Soup steams until
  it's cold, an ice cube melts in a hot cup, the oven glows.

### 1g. Lighting (`lighting.c`, 406 lines; `docs/done/lighting-system.md`)
- Two channels:
  - sky light comes down open columns and spreads with falloff (`:87-160`), coloured by time of day;
  - block light floods out of coloured sources by BFS (`:183`), adding up.
- The final light is the max of the two, with a minimum floor.
- **For Playtime:** a day/night tint plus coloured lamp glows; a lamp switched on through signals.

### 1h. Weather, seasons, wind (`weather.c`, 789 lines; `docs/done/weather-and-seasons.md`)
- A 7-state weather machine with season-weighted transitions (`:93`), and a global wind vector
  that eases between targets (`:340`).
- Rain wets cells under open sky (`IsExposedToSky`, `:269`), and mud forms. Also snow, wind chill,
  and seasonal dawn and dusk.
- The design rule is that effects come out of state: rain makes things wet, and wet things burn worse.
- **For Playtime:** rain wets toys left outside and fills puddles; wind pushes leaves and kites.
  This belongs with `WORLD-BUILDING.md` G5 (sky).

### 1i. Plants, ground wear, dirt
- `plants.c` (growth stages × season rate) and `trees.c` (sapling → young → full).
- `groundwear.c`: grass trampled into a path, which recovers.
- `floordirt.c` (`docs/done/environmental/floor-dirt-tracking-cleaning.md`): mud carried indoors, then cleaned.
- **For Playtime:** a watered pot plant that grows; muddy Mipo footprints and a broom toy.

### 1j. Other valuable pieces
- **Material table** (`src/world/material.c:25`): flags, fuel, ignition resistance, insulation, and
  what each material burns into. A template for per-body materials (see part 3).
- **Item flags** (`src/entities/item_defs.h:9-28`): EDIBLE, SPOILS, FUEL, CONTAINER, DRINKABLE, plus
  weight, nutrition and spoilage.
- **Moods** (`src/simulation/mood.c`, `mood.h:20-53`): timed moodlets (HOT_MEAL, NICE_ROOM, COLD,
  NO_PRIVACY…), changed by traits and summed into one mood.
- **Needs** (`needs.c`, 1061 lines): hunger, thirst, bladder, rest and warmth, each with an
  "options ladder" (toilet > bush > accident).
- **Rooms** (`rooms.c:151`): rooms found by flood fill, with a quality score from size, furniture,
  light, windows and dirt.
- **The dollhouse slice** (`docs/todo/dollhouse-domestic-life.md`): navkit's own Sims-style
  toy-house plan.
  - Kitchen stations that need nearby capabilities (a stove needs a counter).
  - Food temperature and bathroom routines.
  - Action queues (walk to a chair → sit → eat) and daily schedules.
  - **The most relevant design doc for Playtime's doll play.** Read it first.

## 2. dreamengine (`~/Projects/dreamengine`)

The material is in the carts, `tools/carts/*.c` (about 650), not in `apps/`, which only holds
packaging. Two names are traps: `runtime/face.h` is a UI layout grammar, not faces, and
`runtime/pmbreed.h` mutates synth patches, not Mipo breeds. Ranked for doll play:

1. **`juice.c`**: five impact effects: shake, squash, flash, hit-stop, dust. Pure maths. The standard
   feedback for every drop, bonk and placement.
2. **`peteyes.c`** (169 lines): an eye's shape (who it is) is kept separate from the emotion levers
   (openness, squint, lid tilt, pupil). Lids are painted in face colour, so nothing needs clipping,
   and a ∩ arc reads as laughing. Happy, scared and dizzy Mipos; fits DOLL-PLAY-MENU's "picked-up face".
3. **`jelly.c` + `runtime/physics.h`**: a tiny verlet kit (points, sticks, springs, grab and throw at
   mouse speed). Jelly blobs are rim links plus gas pressure (shoelace area restore) and stack.
   `boxjelly.c` mixes them with Box2D crates in one world. Toys: pudding, slime, balloons.
4. **`waterjar.c` / `ripple.c` / `sand.c`**:
   - waterjar: position-based fluid particles drawn as dithered metaballs, which pour and stir;
     heavy, so fewer particles or a shader;
   - ripple: a height-field wave tank;
   - sand: cellular powder.
   - Ripple and sand are cheap in Lua. Toys: a bath to stir, a sandbox, a fishbowl.
5. **`needs.c` / `sims.c` / `pet.c`**: utility AI. Needs drain, the most urgent wins, and
   personality weights make a glutton or a loner. One distance map per resource. `pet.c`
   fast-forwards the time that passed while the app was closed. Idle Mipos wander to the fridge or bed.
6. **`petkit.c` / `acidpets.c`**: a "squishy" shape style: a hand-jittered outline, candy bevel,
   dithered fill, with every shape drawn as a polygon. A house style for toys, plus a squash when touched.
7. **`galerijflat.c` / `dutchsky.c`**: the palette is tinted by time of day while five light-source
   colours stay vivid, so windows glow at night; dutchsky is a keyframed day/night sky. For
   `WORLD-BUILDING.md` G5 (a shader or LUT in LÖVE).
8. **Input** (`runtime/pointer.h`, `gestures.h`, `ui.h`): a pool of fingers, each gesture judged
   per finger on lift (one finger's drag isn't killed by another's tap), pinch, and fat-finger hit
   pads (`finger_px()`). Fits DOLL-PLAY-MENU's multi-finger item.
9. **Generators:**
   - `lsystem.c` (L-system plants);
   - `interiors.c` (a fill language that generates house and shop floor plans in a footprint);
   - `wfc.c` (wave function collapse terrain);
   - `isoroom` / `polyroom` (rotating iso rooms from voxel-baked sprites);
   - `menigte.c` (10,000 townspeople, each position a function of identity and time of day,
     so no pathfinding).
10. **Small pieces:**
    - `glyphpup.c` (heart and ring confetti on events);
    - `tweenlab.c` (GSAP-style eases), which is F3 in DOLL-PLAY;
    - `runtime/endcard.h` (an eased dither curtain plus a card that pops in with overshoot);
    - `facegen.c` (faces from rolled genes, made for a GTA-style world, but the gene bag is reusable).
11. **Sound, not wired up yet:** `acoustics.c` has footsteps that sound different per floor
    material (tile, carpet, wood, grass) and reverb per room. Mipos walking over different floors.
12. Lower value: `wildfire` / `doomfire` (a heat-grid fire rule), `citygen.h` / `roadkit.h` (a city
    generator; too much here), `runtime/shadermath.h` (SDF shapes and a cosine palette, for GLSL).

**Already in Playtime (checked 2026-10-29):**
- `boxlab.c`, the puppet that keeps itself upright, came *from* Playtime (`keep-angle.lua`,
  `src/mipo-joint-guard.lua`); at most its gain values are new.
- The MEMBRANE and MALLET instruments are used: the box drums and the click (`src/synth.lua`).
- `boxhuman.c` (five body types from one rig table) and `boxskin.c` / `runtime/boxrig.h`
  (a convex hull from sprite alpha, a mesh weighted over two bones) overlap with Playtime's own
  DNA and DQS skinning. Compare before taking anything.

## 3. Suggested order

1. **Read navkit's dollhouse doc** against `DOLL-PLAY.md`, and lift what fits.
2. **Materials per body** (navkit `material.c` as the template): wood, cloth, metal, food… with
   fuel, ignition resistance, insulation and wetness. Fire, wetness and temperature all hang off it.
3. **Analog signals plus a clock**, on top of `src/signals.lua` (navkit 1a): a dimmer, a blinker,
   a weight-based pressure plate. Later, power as a network (1b).
4. **`juice.c` feedback** on impacts: cheap, can be done any time.
5. **Containers with a fill level**, pouring water (1c), and then a stirrable bath (ripple).
6. **Fire, then smoke and steam** as particles (1d, 1e), once materials exist.
7. **Eyes** (peteyes) for the "picked-up face" and idle liveliness.
8. **Temperature, moods and needs**: when Mipos should have an inner life.
