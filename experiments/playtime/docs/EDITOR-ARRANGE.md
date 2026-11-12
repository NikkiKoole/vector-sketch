# The editor as an arranging table

status: idea

How the editor gets used now (Nikki, 2026-11-06): generate a scene from some settings, add
Mipos, mix and match mostly ready-made things, then tweak a few: select something and
randomize it, or make it bigger and turn it. The UI was built for the other job, making
things from scratch (draw a shape, joints, sfixtures, density): a **workshop**. Most clicks now
are **arranging**. "Our UI feels cluttered."

Not decided yet; this is the thinking so far.

## The idea

Two screens: the arranging table by default, the workshop (today's editor) behind a toggle.

- **A shelf of ready-made things** to drag onto the stage, as pictures: toys, props, library
  prefabs, Mipos (later breeds). Takes over from the shape/draw/joint/attach tools as the way
  things get in. The toys shelf (`src/toys.lua`, library tab) is the start of it.
- **The stage does the rest.** Move, turn, size on the thing itself. A small bar beside the
  selection: 🎲 · copy · flip · front/back · delete · …
- **🎲 means "another one of the same kind"**, for everything: a Mipo its DNA, a candy its
  colour, a stone its material and shape, a fence its length. Each recipe says what it varies.
- **"…" opens a short panel with that thing's own settings** (its recipe's or DNA's: colour,
  material, pattern), only when asked. Physics fields (density, damping, sensor, group, bullet)
  live in the workshop.
- **The scene too:** its generator settings as sliders and toggles in a panel, 🎲 for a whole
  new scene.

Why it might be right: it matches the clicks that happen; it's close to what a kid would do
(DOLL-PLAY R2, one "place" primitive), so it could grow into the kids' screen; each step works
on its own.

## Steps, smallest first

- [x] **EA1. Turn and size on the stage.** A knob above a selected body turns it (shift: 15°),
  a square at its corner sizes it evenly (`src/transform-handles.lua`,
  `objectManager.scaleThing`). Not on Mipo parts or blobs. Done 2026-11-06, liked.
- [ ] **EA2. The selection bar.** 🎲 (Mipos: it exists, at the bottom of their panel), copy,
  flip, delete, "…". The properties panel stops opening by itself.
  **Parked, switched off: tried 2026-11-11**, Nikki "not sold on the bar (yet)", "lets leave the bar disabled";
  `state.selectionBar = true` shows it (`src/ui/selection-bar.lua`): a bar under the selection (above it
  near the screen's bottom). A Mipo: dice (randomize all, undo in its panel), copy (the whole Mipo, the
  copy's same part selected), flip (left <-> right facing), delete (the whole Mipo). A thing: copy, flip
  (x), delete. A box selection: copy, delete. ••• opens the properties tab. Not yet: dice for props (EA3);
  the properties panel still shows when its tab is open (the column has no closed state yet).
- [ ] **EA3. 🎲 for props.** First look at what each `src/props.lua` recipe varies today.
- [ ] **EA4. The shelf** as a strip of pictures, for placing things.
- [ ] **EA5. The workshop toggle**: tool rail and full inspector behind it.

The layer underneath (2026-11-12): KINDS.md. The bar, 🎲 and ••• need every placed thing to know what it
is (a Mipo does; a prop forgets its recipe), so EA2/EA3 wait on its KD2-KD4.

## Open questions

- Does a turned body get a turned selection box (the handles sit off the straight one)?
- Sizing grows the outline, not a material's grain: a stone at ×3 has the same grain. Wanted?
- A scene script that holds on to a `body` loses it when that body is sized (it's rebuilt).
  The materials spike follows its things now (`follow` in its script); more scenes doing it
  would want a "rebuilt" notice from `recreateThingFromBody` instead.
- Mipos: a size handle too (`instance.scale`), or only the bar?
