# Worlds and doors — rooms you walk a Mipo into

status: active

**Started:** 2026-10-28 (brainstorm).

**Goal:** a world, not a level. A wide overworld (a horizon, and in theory up and
down too) with doors here and there. Put a Mipo at a door, go in, and you're
in another scene with that Mipo and whatever it was holding. Go out again, and
the overworld is how you left it. Everything stays where you put it (Toca /
Sago Mini style). Fits the doll-play direction (`DOLL-PLAY.md`).

**How to use this doc:** the slices go in order; each one ends playable. Tick
them here when done. The open questions at the bottom are decided as we go.

---

## The idea in pieces

**Rooms.** Every `.playtime.json` scene is a room. The overworld is just a room
too: very wide (and maybe tall), the camera pans over it.

**Doors.** A door is a thing on a body: a new attach kind `door` (rail → attach),
with `to` (the room) and `arrive` (the door you come out of over there). Doors
come in pairs: overworld `bakery` ↔ bakery `front`. Going back out lands you at
the door you came in through.

**Going through (Nikki, 2026-10-28):**
1. Tap a door: it **opens** and you see the **inside** (a peek of the room).
2. Put your Mipo on the open door (drop it there).
3. Tap the visible inside: you **go in**. A short zoom into the door, the room
   loads, the Mipo steps out of the arrival door.

A deliberate act on purpose: a Mipo that tumbles past a door doesn't teleport.
The peek is a picture of the room as you last left it (a small canvas render on
save), or the template's thumbnail the first time.

**What goes along: everything connected.** Start at the Mipo's parts and follow
joints: the toy in its hand, a Mipo holding its hand, the cart it's snapped to,
what's snapped to that. That connected group travels together.
This is nearly `library.save` + `library.place` (a prefab made on the fly), but:
- it's a **move**, not a copy: keep ids and signal names (no `renewIds`, no
  `signals.renameForCopy`), the bodies are removed from the room you leave;
- Mipos should keep their **pose** (the library regrows them from DNA in T-pose).

**Persistence, two layers.**
- **Templates:** the rooms you build in the editor (`scripts/*.playtime.json`).
  Play never changes them.
- **The save:** each room's state as you left it, `save/<room>.playtime.json` in
  the save directory (`sceneIO.gatherSaveData`), written when you leave a room
  and when the app quits. Entering a room loads its save if there is one, else
  the template (`sceneIO.buildWorld`).

Rooms you're not in are **frozen**: nothing runs off-screen.

**Mipos as individuals (later, keep in mind).** Mipos don't live anywhere yet.
Design so they can: a stable Mipo id that survives save/load and travel, and
one place that knows which room each Mipo is in. Then "your" Mipo can have a
home, and the Puppetmaker Mipo (DOLL-PLAY F4) can move in.

---

## Slices

- [x] **W1. Two rooms, one door each, in memory** (built 2026-10-28; Nikki played it 2026-10-30: "works kinda ok"). A door is a DOOR *behavior* (door, to,
  arrive), not an attach kind: behaviors already save and get inspector rows. `src/doors.lua`
  (tap / open / go, split the Mipo off the room, enter, fade), `sceneLoader.loadSceneData`,
  `state.scene.id` = the room you're in. Test rooms from `claudetools/make-door-rooms.lua`:
  `overworld` (two doors, a Mipo), `bakery`, `treehouse`. Spec: `spec/doors_spec.lua`.
  Start with `./playtime.sh start overworld`.
- [ ] **W2. Persistence.** `save/<room>.json` on leave + on quit; enter loads save
  else template. A 'reset world' button in settings (deletes the saves).
- [ ] **W3. Carry what's connected.** The joint graph from the Mipo; move it as
  a group, ids kept, Mipo pose kept.
- [ ] **W4. The peek and the zoom.** The open door shows the inside (a picture
  saved with the room); going in zooms into the door.
- [ ] **W5. Mipos with a home.** Stable ids, a who-is-where table, Mipos can be
  left in a room and found there again.

---

## Open questions

- **Holding something with the mouse while going in?** Probably: it comes along
  if it's connected, the pointer joint is dropped.
- **Scene scripts per room:** `onStart` every time you enter, or only the first
  time (and something like `onEnter` each time)?
- **Signals across rooms** (a button outside opens something inside): no, not
  for now.
- **The overworld's size:** Box2D is fine with a wide world, but camera bounds,
  the backdrop and the on-stage list need a look once it's big.
- **Sago rule check** (`feedback_sago_rule`): this is a world, not one verb. The
  verb here is "go through a door with your Mipo"; each room can be its own
  small toy. W1 alone should already be fun, or we rethink.

## Reuse

- `src/library.lua`: save things + their joints, place them elsewhere (W3).
- `src/io.lua`: `gatherSaveData`, `buildWorld` (with `additive`), `prepareLoaded` (W1, W2).
- `src/scene-loader.lua`: `loadScene` (W1).
- `src/physics/snap.lua`: sensor contacts, as a model for "Mipo is on the door" (W1).
- `src/ui/tool-rail.lua`: attach group gets `door` (W1).
