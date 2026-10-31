# Scenes — what's in scripts/, what works, what we might not need

status: reference

**Checked 2026-10-31.** Every scene loads and runs: `spec/scenes-smoke_spec.lua` loads each one the
way the editor's scenes tab does (`src/scene-catalog.lua`), runs a second of frames (physics, the
script's update, all drawing, its UI panel in play mode) and presses every key its script listens
for. 52 of 52 pass. The only one that was broken, the catapult (`thing.fixture`, gone since 2024),
is fixed. The spec stays in the suite, so a scene that breaks shows up there.

What it doesn't check: things you do by hand (dragging, throwing), and whether a scene still does
what it was for. "Runs" here means no errors, not "good".

**Leave alone:** scenes loaded by name by a spec or tool (marked *spec*). `draw-cache_spec` and
`claudetools/snapshots` also draw every scene in `scripts/`, `scripts/knut` and `scripts/tech` as
test material: removing one costs a little coverage, nothing breaks.

## Keep

| scene | what | why |
|---|---|---|
| dollhouse | the doll-play test room | the focus plan's room; *spec* |
| kitchen | water test room: cups, a bath | WATER W1; *spec* |
| overworld, bakery, treehouse | the overworld and rooms behind doors | WORLDS-AND-DOORS; overworld *spec* |
| miposhader | the start scene | `main.lua` starts in it; *spec* |
| spine-test | one Mipo on a floor | the quick test scene; *spec* |
| spine | Mipos with spine torsos | MIPO-SPINE |
| crowd | twenty Mipos | the phone measurement (MEASURING M10) |
| snap, tech/snap2, tech/snapstatic | snap points and old snap joints | *spec* (snap-scenes) |
| sm-demo | the state-machine helper example | *spec* |
| meta | the save/load round-trip scene | round-trip tests |
| tech/connected, multi, resources, uvs | one engine piece each | test material; resources/uvs in UV-BACKDROP-FRAGILITY |
| knut/hoop, knut/workmoreclean | Knut scenes | *spec* (meshusert-bind, resource-link): skinning and resources. Move to `tech/` if Knut goes |
| catapult | a catapult toy | works again, a fun room toy |
| burrow, fabuland, hair, tufts | today's and yesterday's spikes | parked plans point at them |

## Might not need (Nikki decides)

| scene | last change | what | thought |
|---|---|---|---|
| scratch/empty, empty2, ding2, grow, lekker, beginmesh | 2026-05 | scratch files, 1–4 kB | **drop**: leftovers (beginmesh is only named in an old note) |
| knut/beach3, bettert, cliff, ding, knut, maan, smaller2, soemwhere7, test, work | 2026-05 | the Knut commission | **drop or archive**: fizzled 2026-04-22; ~900 kB. knut/knutjump is WORLD-BUILDING's tile-repeat grass example: keep that one if it's still wanted as one |
| puppet | 2025-01 | an early jointed puppet, empty script | **drop**: the Mipo editor made it |
| torso | 2025-01 | torso shape sliders | **drop**: the Mipo editor has these |
| straight | 2025-09 | bodies keeping themselves upright, with sliders | **drop?** keep-angle in the game does this now |
| stapel | 2026-05 | stone balancing (space, c) | **drop**: stapelaar is the same and more (b: a stone at the base) |
| water | 2025-04 | floating in water: drag, density sliders | **maybe**: an older water than kitchen's; floating could come back for a bath (WATER, parked) |
| elasto | 2025-04 | an elastic band between two points | **maybe**: a room toy (slingshot, trampoline) |
| planets | 2025-04 | planets that pull | **maybe**: the sky experiment's moon pull (WORLD-BUILDING G5) |
| platforms | 2025-04 | platforms you jump up through | **maybe**: a one-way floor is useful for stacked rooms (R5) |
| mudready | 2026-05 | the Bathhouse mud | **keep while Bathhouse is parked**, drop if it's let go |
| stapelaar | 2026-05 | stone balancing | **maybe**: fun, unrelated to the plans |

Dropping the "drop" rows: 20 scenes, ~1 MB. Nothing loads them; the scenes tab gets shorter.
