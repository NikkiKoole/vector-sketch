# Scenes — what's in scripts/, what works, what we might not need

status: reference

**Checked 2026-10-31.** Every scene loads and runs: `spec/scenes-smoke_spec.lua` loads each one the
way the editor's scenes tab does (`src/scene-catalog.lua`), runs a second of frames (physics, the
script's update, all drawing, its UI panel in play mode) and presses every key its script listens
for. 52 of 52 pass. The only one that was broken, the catapult (`thing.fixture`, gone since 2024),
is fixed. The spec stays in the suite, so a scene that breaks shows up there.

What it doesn't check: things you do by hand (dragging, throwing), and whether a scene still does
what it was for. "Runs" here means no errors, not "good".

**Leave alone:** scenes loaded by name by a spec or tool (marked *spec*), and `meta` (the
shape8 outline sheet, below). `draw-cache_spec` and
`claudetools/snapshots` also draw every scene in `scripts/` and `scripts/tech` as test material:
removing one costs a little coverage, nothing breaks.

**Archived 2026-10-31** (Nikki agreed to the drop list): 20 scenes moved to `archive/scenes/`
(`archive/README.md`): the scratch scenes, ten Knut scenes, puppet, torso, straight, stapel. The
three Knut scenes worth keeping moved to `scripts/tech/`. UVUSERT lives on in `tech/resources` and
`tech/uvs`, MESHUSERT in `tech/hoop` and `tech/workmoreclean`.

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
| meta | the shape8 outline sheet, and a round-trip scene | source of `src/shape8-dict.lua`; don't archive (below) |
| shape8-check | a shape8 outline in the game next to another one, two Mipos per case | trying a trace before it goes in the dict (meta, below) |
| feet-check | every foot picture on a Mipo of its own, ankles against their stop marked | how each foot stands; *spec* feet-stand checks the same |
| breeds | a litter of six Mipos of one breed; a panel picks the breed | the MIPO-BREEDS spike: breeds as tables in the script |
| vanilla | one plain Mipo (the humanoid template, not randomized) on a floor | tweaking a Mipo by hand in the Mipo editor (n: a fresh one) |
| tech/connected, multi, resources, uvs | one engine piece each | test material; resources and uvs: the UVUSERT scenes (UV-BACKDROP-FRAGILITY) |
| tech/hoop, tech/workmoreclean | from Knut | *spec* (meshusert-bind, resource-link): the MESHUSERT (skinning) and resource scenes |
| tech/knutjump | from Knut | WORLD-BUILDING's tile-repeat grass example |
| catapult | a catapult toy | works again, a fun room toy |
| burrow, fabuland, hair, tufts | today's and yesterday's spikes | parked plans point at them |

## Might not need (Nikki decides)

The "drop" rows were archived (above). Left to decide:

| scene | last change | what | thought |
|---|---|---|---|
| water | 2025-04 | floating in water: drag, density sliders | **maybe**: an older water than kitchen's; floating could come back for a bath (WATER, parked) |
| elasto | 2025-04 | an elastic band between two points | **maybe**: a room toy (slingshot, trampoline) |
| planets | 2025-04 | planets that pull | **maybe**: the sky experiment's moon pull (WORLD-BUILDING G5) |
| platforms | 2025-04 | platforms you jump up through | **keep**: its one-way floors are the top of a back-layer block (`DEPTH-LAYERS.md`) and stacked rooms (R5) |
| mudready | 2026-05 | the Bathhouse mud | **keep while Bathhouse is parked**, drop if it's let go |
| stapelaar | 2026-05 | stone balancing | **maybe**: fun, unrelated to the plans |

## meta — the shape outlines

`scripts/meta.playtime.json` is the sheet the Mipo part pictures were traced on. The
save/load specs load it with every other scene in `scripts/`. **Don't archive or delete
it.** No spec names it, so an archive pass that only keeps scenes a spec names would take
it, and the traces with it.

41 pictures: a hand (`hand3r`), seven feet (`feet2r`, `feet3xr`, `feet5xr`, `feet6r`,
`feet7r`, `feet7xr`, `feet8r`), sixteen ears (`earx1r` through `earx16r`), and the body and
head shapes (`shapeA1` through `shapeA4`, `shapes1` through `shapes13`). Each body is one
static rectangle (dynamic until 2026-11-01: pressing play dropped the whole sheet). The
picture sits on a texfixture (`bgURL`). The outline is an 8-point sensor labelled `meta8`:
its `extra.vertices`, point 1 first, origin at the centre of the rectangle, y down.
`points` on the same fixture is Box2D's hull and can drop a point.

`src/shape8-dict.lua` is the copy the game reads: the same 41 names, each with `dimensions`
(the rectangle's width and height), `vertices` (the 8 points) and, for ears, `root`. The
sheet and the dict agree exactly. `spec/shape8-dict_spec.lua` (and
`lua claudetools/shape8-from-meta.lua`) fails on any difference: a name on one side only, a
point or a size that isn't the same, a picture missing from the catalogs, an ear without a
root.

Parts are built from the dict: the collision polygon and the joint points
(`mipo-build.lua`, `character-topology.lua`), the picture's size and the body-hair outline
(`mipo-textures.lua`), a spine torso cut into bands (`spine-skin.lua`), a blob's rest shape
(`blob.lua`). Which of those pictures the editor and the randomizer offer is a second list,
`src/shape-catalogs.lua`.

Ear `root` is not on the sheet. It is where the drawing meets the head, measured from the
mask (the middle of the bottom fifth; earx9r's two legs by hand, 2026-10-30). The other
parts have no root. `dimensions` is the rectangle on the sheet, the size the picture is
stretched to. Many of the pngs were scaled down later (2026-05), so a file's pixel size is
often smaller, but the shape (width to height) must be the png's, or the picture is squashed
(the spec checks it).

History, 2026-11-01: until then the dict was copied by hand from a log line, and the two
had drifted: hand3r, earx3r, feet3xr and shapeA3 had been retuned in the dict only, and
feet3xr and earx2r had other widths on the sheet. The dict's versions were kept (compared
in `shape8-check`) and the sheet now has them. shapes9 (520x468) and earx13r (225x336) had
two digits swapped against their pngs (520x648, 225x366) and were squashed in the game; they
have the png's size now, the outline stretched along. shapes1 and shapeA4's pictures sat
2px off centre on the sheet.

### Seeing an outline in the game

`scripts/shape8-check` puts two Mipos side by side per case: the dict's outline on the
left, another one for the same picture on the right (a dict entry with `picture` set
borrows the original's png), the collision outline in red. Left/right steps through the
cases. Add a case to try a new trace before pasting it.

### Adding or changing a picture

1. Add `textures/<name>.png` and `textures/<name>-mask.png`.
2. On the meta scene, add a rectangle of the picture's size (or its shape, scaled), put the
   picture on it, and add a texfixture sensor with corners 8, labelled `meta8`. Points in
   order: 1 at the top, then clockwise (2 upper right, 5 at the bottom, 8 upper left). The
   editor draws a line between opposites (1-5, 2-8, 3-7, 4-6), so a scrambled order shows.
   Joints use these indices.
3. Select the `meta8` sensor and press **copy dict entry** (position section). It puts the
   line for `src/shape8-dict.lua` on the clipboard. Paste it (replacing the old line when
   you retraced). For an ear, add `root` yourself.
4. A new picture: add the name, without `.png`, to the right list in
   `src/shape-catalogs.lua`: `torsoHeadShapes`, `earShapes`, `feetShapes` or `handShapes`.
   The feet pictures are listed as hands too. Without a list entry the editor and the
   randomizer never offer it.
5. Save the scene, then `busted spec/shape8-dict_spec.lua`. It tells you what doesn't match.
