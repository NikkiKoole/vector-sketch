# Kinds — the things made of bodies

status: idea

Nikki 2026-11-12, cleaning up the editor with a Mipo selected: "we have a box2d editor + sfixtures that do
stuff, but we also have this higher abstract things, like a mipo (but could also be a vehicle, eatable,
etc lots of things) then we get a higher abstraction ui, with a dissolve somewhere, there is some api that
can be used on it too". Half a thought; this doc is where it gets finished before anything is built.

## Three layers

1. **The workshop**: bodies, joints, sfixtures, behaviors. Uniform: a behavior declares `params`, the
   inspector (`src/ui/inspector.lua`) draws them, everything selects, edits and saves the same way.
2. **Things made of bodies**: a Mipo, a skateboard, a fabuland window, a cake. This layer has no
   shape of its own yet (below).
3. **The scene's settings**: light, sky, water look, feelings (`src/systems.lua`). Not this doc.

## What layer 2 is today (2026-11-12)

Six things live there, each its own way:

| Kind | How a body knows it belongs | Kept after making | Panel / API |
|---|---|---|---|
| Mipo | `thing.mipoId` / `mipoPartName` + an instance in `mipoRegistry` | all: DNA, 🎲, saved as a Mipo | `mipo-editor`; `mipo-actions` (jump, flip, ragdoll, lookAt, pointAt), `mipo-walk` |
| Toys / props | nothing: `src/props.lua` recipes return bodies and forget | nothing | none |
| Fabuland parts | label string `'fab:<part>:<set>'` (`fabuland.partOf`) | part + colour set | none |
| Prefabs | nothing: `library.clone` copies frozen bodies | nothing | none |
| Tracks | `thing.shapeType` | the drawn line | own edit handles |
| Wearables, rail carts | a behavior on one body / the item's table | partly | none |

Only the Mipo is a whole. Even so, "a part stands for its Mipo" is decided again in each place:
`src/input-manager.lua:247`, `src/playtime-ui.lua:145`, `src/ui/selection-bar.lua`, `src/ui/on-stage.lua`.
**Dissolve** (`src/ui/mipo/body-panel.lua:508`) clears `mipoId` on the parts and unregisters: a whole
back to plain bodies. Only Mipos have it.

What that costs: the editor speaks the workshop's language. A selected Mipo is a selected body with its
Mipo looked up afterwards, so every part fills orange. A skateboard can't be selected as one. The
selection bar (EDITOR-ARRANGE EA2, parked) had 🎲 and ••• only for Mipos, maybe why it didn't land. 🎲 for
props (EA3) is blocked because a placed prop no longer knows its recipe.

## The idea

A **kind** declares, like a behavior declares `params`:

- **make(settings)**: builds its bodies
- **settings**: rows for its short panel (the ••• in the bar), drawn by the same inspector
- **🎲**: what "another one of the same kind" changes (a Mipo's DNA, a candy's colour, a stone's material)
- **actions**: its API, the same for scripts, the panel and the bar (a Mipo jumps, a cart goes, a food gets eaten)
- **save / load**: the kind and its settings go into the scene, beside the bodies
- **dissolve**: for every kind: forget it, keep the bodies, they're the workshop's now

A placed one is an instance: `{ id, kind, settings, bodies }`. A click selects the instance; its parts are
the workshop's business (dissolve, or the workshop toggle, EA5).

**The rule: the bodies stay the truth.** Save writes the bodies as now, plus "these are a skateboard, made
with these settings". So dissolve is free (drop the label), old scenes load (no labels yet), a kind whose
code changed or went away doesn't break a scene (plain bodies), and the workshop works on anything. Only 🎲
or a changed setting rebuilds from the recipe, as sizing already rebuilds a body.

**Grow it from two real kinds, not as a framework first.** Nesting and patching bodies in place are the
questions that eat weeks; they wait for a real case.

## Steps, smallest first

- [ ] **KD1. Decide the open questions** below with Nikki (at least the name and the Mipo route).
- [ ] **KD2. The layer, with the Mipo through a thin adapter.** `mipoRegistry` stays, DNA and actions stay;
  the layer only asks "your bodies, roll again, dissolve, your panel". The four places that look up a
  Mipo from a body ask the layer instead. Checked by the scenes snapshot before/after (nothing changes).
- [x] **KD3. Select the whole.** A click on any part selects the instance: one quiet outline round it, not
  orange over every part, and its panel. The editor cleanup Nikki started from.
  **The panel half, 2026-11-12** (Nikki: "i like your plan, as long as we can get to every part"): the Mipo
  panel in that order (`src/ui/mipo/kind-panel.lua`): breed < > with roll and undo, the actions, copy and
  delete; proportions (was positioners, with mutate sizes) and build (was creation); then the part row,
  < name > stepping head to feet through every part, a press on the name lists all of them; the part's
  sections and its randomize; the workshop folded (parts, scale, dissolve). Left: the outline on stage.
  The same day (Nikki: "a bespoke body skeleton ui and face ui for selecting these parts"): the part list is a
  default Mipo skeleton to tap (`src/ui/mipo/part-map.lua`, the parts this Mipo has: necks, bands, lobes,
  noses, no head on a potato), and the face section a default face (brows, eyes, nose, mouth) that opens one
  feature's rows at a time, no header rows. Both always shown, side by side under the part row (Nikki: "make the
  head and body selectors always visible"); a feature picked with an arm selected selects the face's part.
  Then each setting moved to the part it changes: leg stance and the ears' height, angle and over-the-head
  to a 'place' tab on the upper legs and ears, face size to the face, mutate beside roll; the build
  section split up: the torso's (potato head, segments, spine, lobes, jiggle) a 'body' tab on the torso,
  the neck and the nose their own sections, picked on the skeleton even when off (a faint neck or nose).
  Copy and delete in the panel's top row. Which sections are open is kept on `state` (`state.mipoPanelOpen`):
  a hot swap of widgets.lua forked the table and the tabs stopped opening anything.
  **The stage half, 2026-11-12**: the box round the whole Mipo was there already (src/editor-render.lua);
  the orange over every part was the sfixtures' fills, now off unless turned on (world settings
  'sfixtures', 'sfixture lines'). The clicked part gets a thin outline inside the box. Done.
- [ ] **KD4. Vehicles as the second kind** (Nikki 2026-11-12: "maybe we do vehicles next to get the
  meta-object built from physics parts under our belt"; before: props). The rides spike's four (kart, car,
  skateboard, banana car; RIDES.md, parked "i think vehicles is done") are raw Box2D bodies in one scene
  script: not selectable, not saved, nowhere else. As a kind they're made of ordinary things (objectManager
  bodies, joints), so the workshop, save and dissolve work on them as on anything. Slices:
  - **KD4a. The layer, as small as it can be, and a kart.** `src/kinds.lua`: register a kind, make one, which
    instance a body belongs to (a `kindId` on each body's thing, saved beside it as `mipoId` is), the
    instances' kind and settings saved in the scene, dissolve. The kart from `objectManager` bodies and
    joints, on the library's toys shelf; selected as a whole (the Mipo's box); saved and loaded; dissolved
    to plain bodies. No driving yet: it rolls when pushed.
    **Done 2026-11-12**: `src/kinds.lua` (make, ofBody, things/bodies, dissolve, remove, save/load,
    entriesFor; instances on `state.kindInstances`), `src/vehicles.lua` (the kart: a U tray as one custom
    body, two wheels on wheel joints), 'kart' on the toys shelf, the box round the whole kart, a small panel
    (`src/ui/kind-editor.lua`: name, copy, delete, the part, dissolve). Saved: `kindId` / `kindPart` on each
    body, `kinds` in the scene; library copies and prefabs bring the whole instance with new ids.
    spec/kinds_spec.lua (made, saved and loaded, copied, dissolved, removed, rolls). Not yet: the on-stage
    list shows its parts as separate bodies.
  - **KD4b. Its panel**, the Mipo panel's shape: the kind's row (type kart / car / skateboard / banana,
    roll, copy, delete), its settings as inspector rows (colour, size), the parts picked on a picture of it
    (frame, wheels), the workshop folded.
  - **KD4c. What it does**, from the spike into an engine system (`src/vehicles.lua`, through
    src/physics-units.lua): a Mipo dropped on the seat gets in (two kinds side by side, joined by
    joints), tap to drive, pick up kept upright, wind up; actions in the panel (drive, turn round, throw
    out the rider).
  - **KD4d. The other three types**; the rides spike builds its street and places the engine's vehicles.
- [ ] **KD4p. Prop recipes as a kind** (was KD4): a placed prop keeps its recipe name and settings (saved),
  🎲 rebuilds it (EDITOR-ARRANGE EA3), dissolve leaves plain bodies. Each recipe says what 🎲 varies.
- [ ] **KD5. The bar again** (EA2): with 🎲 and ••• meaning something for everything selected, Nikki looks
  at it once more.
- [ ] **KD6. The rest move over**, one at a time, once two kinds have held: fabuland parts (the label
  becomes a kind), prefabs (a saved group as a kind?), wearables, rail carts, tracks.
- [ ] **KD7. New kinds** from the spikes as they're kept (ENGINE-MERGE EM2, EM4): planks, cloth, critters,
  something to eat (FOOD-IN-FOOD-OUT.md).

## Open questions

- **The name.** `thing` is taken (each body's property bag). "Kind" for the recipe; the one on stage a
  "piece", a "made thing", or just "instance"?
- **Mipos:** move into the layer, or stay as they are with the layer shaped to match them (the adapter, KD2)?
- **A changed setting:** rebuild the bodies (simple; how sizing works now) or each kind patches in place?
  A scene script holding a body loses it on a rebuild (EDITOR-ARRANGE's open question): a "rebuilt" notice?
- **Kinds in kinds:** a Mipo on a skateboard, a house of fabuland parts. For now two kinds side by side,
  joined by a joint.
- **Dissolve back?** A dissolved skateboard edited in the workshop: save it as a new kind (a prefab with
  settings), or is that the library's job?
- **Where actions show:** the bar, the panel, a right-click, play mode for kids? One list per kind, drawn
  wherever.

Related: EDITOR-ARRANGE.md (the arranging table, the bar, the shelf), ENGINE-MERGE.md (EM2, EM4: things on
the shelf), DOLL-PLAY.md (one "place" primitive).
