# Doll play — the Puppetmaker follow-up

**Started:** 2026-10-27. **Status:** menu, nothing built yet.

**Goal:** the same Mipo as Puppetmaker (or a bit better), but in a world where you
play with them like dolls. Think Sago Mini / Fiete World: several characters
who notice your finger and look at what you're doing. You can pick them up,
drag, throw and drop them, throw things around, put things in containers, and
drag a character to pan the world.

**How to use this doc:** the Foundation goes first, because everything else
plugs into it. After that the Menu is pick-and-choose. Each item is small, works
on its own and can be seen running in the play scene. Work on one at a time and
tick it here when it's done.

---

## Foundation (do first, about a week)

- [ ] **F1. Play scene** `scripts/dollhouse.playtime.lua`: a floor, 2 or 3 Mipos,
  a few props. This is the one scene where every menu item gets tried.
- [ ] **F2. Play mode** `--play <scene>`: no editor chrome, overlays or editor
  input. Gate `drawUI` / editor overlays in `main.lua`, take the play path
  straight away in `input-manager.lua` `handlePointer`, and remove the
  `x > w-300` checks. Details are in `NEXT-STEPS-2026-07.md` §1.
- [ ] **F3. Tween/timer layer**: put `hump.timer` in `vendor/` and expose it in the
  script sandbox (`script.lua` baseEnv). Head turns, blinks, reactions and
  smooth camera moves all need it.
- [ ] **F4. Load *your* Mipo**: spawn characters from saved DNA/JSON
  (`characterManager.createCharacterFromJustDNA`). Puppetmaker-style continuity:
  the Mipo you made shows up in the world.
- [ ] **F5. Per-Mipo gaze target** (the "aware" part): right now the pupils follow the
  **mouse**, and that's hardwired in the renderer
  (`box2d-draw-textured.lua` ~3096, `love.mouse.getPosition()`). Change this to
  `instance.gazeTarget = {x, y}` (or nil). Then a small "attention" function
  picks the target each frame: the pointer, a thrown object, another Mipo, or
  idle wander. Touch has no hover, so on iPad "pointer" means the last touch
  point or the object being dragged.

Already there: multi-touch pointer joints (`src/physics/box2d-pointerjoints.lua`),
priority-based grab (picks the best fixture under the finger), the fixed
timestep, touch callbacks, scene-script hooks, snap fixtures (`src/physics/snap.lua`).

---

## Menu: pick and choose

### Handling (how it feels in your hand)
- [ ] **Pick up / carry**: the grab already works. Tune it so a held Mipo hangs
  nicely (a stiffer joint on torso grabs, softer on limbs) and doesn't jitter.
- [ ] **Throw**: on release, keep the velocity but clamp it (and maybe boost it a
  little) so a flick feels good and doesn't fling things off-screen. Hook point:
  `handlePointerReleased` already returns the released bodies.
- [ ] **Gentle drop / land**: a small squash and an "oof" face on a hard landing,
  using the contact callback's impact speed.
- [ ] **Multi-finger**: two kids, two Mipos. The pointer IDs already support it,
  it just needs testing on iPad.

### Awareness and reactions (feels alive)
- [ ] **Head turn** toward the gaze target (a small torque on the head and neck, not only the pupils).
- [ ] **Look at what's moving**: a thrown object or a falling friend steals attention for a moment.
- [ ] **Look at each other** when idle and nearby. Cheap, and very "alive".
- [ ] **Tap reactions**: poke the belly to giggle, poke the head to blink, poke a foot for a ticklish kick.
- [ ] **Picked-up face**: surprised/happy while held, dizzy after a big throw.
- [ ] **Idle loop**: blink, breathe, shift weight, small look-arounds (puppet-maker2 `breathBody` / `eyeBlink`).

### World
- [ ] **Throwable props**: ball, block, fruit, hat. They're just bodies, so mostly art.
- [ ] **Containers**: box, bed, bathtub, cupboard. A sensor area that "holds" what's
  dropped in (dampens it, maybe closes a lid). Kids love putting things in things.
- [ ] **Seats / slots**: chair, swing, bed. Use **snap fixtures** so a Mipo
  dropped near one snaps into a sitting/lying pose.
- [ ] **Wearables**: drop a hat on a head and it snaps on (snap again).
- [ ] **Food**: bring food to the mouth and it opens and chomps (sensor near the mouth + a mouth tween).
- [ ] **Switches**: lamp on/off, day/night, a tap that runs water. Tiny cause-and-effect wins.

### Camera and world size
- [ ] **Drag to pan**: dragging a Mipo near the screen edge scrolls the world
  (Fiete-style). Smooth follow with tweens.
- [ ] **Drag empty space to pan** (one finger on the background).
- [ ] **Pinch zoom** (maybe never; Sago mostly doesn't zoom).
- [ ] **Rooms**: a wide world built from rooms (house, garden, bathroom), or
  doors that slide to the next room.

---

### Voice (mipomi-lang → playtime)

Source repo: `~/Projects/love/mipomi-lang` (GitHub private). It stays the lab where
recording and tuning happen; playtime gets a copy of the engine and the cut samples.

- [ ] **V1. Samples in**: copy the cut syllables to `assets/voices/{nikki,theo,herman}/`
  and the fx to `assets/voices/fx/` (about 1.2 MB). Skip the raw takes (`*-uncut*`,
  root `*.ogg`, `blah4`). Note: mipomi's `main.lua` only ever loads
  `samples-nikki`. The other two voices are recorded but have never been used in code.
- [ ] **V2. `src/mipomi.lua`**: extract the *engine* half of mipomi `main.lua`
  (`parseInput`, per-speaker `sayQueue`, `playSyllable`/`playSFX`,
  pitch curves, personalities, stutter) into a module with no globals and no
  draw/keypress code. A speaker is created per Mipo.
- [ ] **V3. `mipo:squeak(emotion)`**: one syllable or fx with a pitch shift. This is
  the cheap 80%; hook it to poke, pick-up and land reactions.
- [ ] **V4. Lipsync**: don't port mipomi's `mouth/mouth.lua`. Playtime already
  has the same 15 shapes (`src/mouth-shapes.lua`), and the renderer reads
  the lip decals' `extra.curvePoints` every frame
  (`box2d-draw-textured.lua` ~2050). So the voice module only reports
  "current phoneme + blend t", and a small adapter lerps the normalized shapes
  into `curvePoints` (scaled by the decal's `mouthScaleX/Y`, `mouthX/Y`).
  Restore the DNA's own mouth shape when it falls silent.
- [ ] **V5. Voice in DNA**: `voice = { set = 'theo', root = 'c5', personality = 'party' }`.
  It's saved with the Mipo, picked by randomize and shown in the Mipo editor.
- [ ] **V6. `mipo:say("mi mo jo")`**: full phrases plus the script-sandbox API. The
  glossary (`MI` = I, `MO` = love, `JO` = you) makes the babble mean something.

## Other ideas (shooting, not committing)

- **Carry-over from Puppetmaker**: a "made in Puppetmaker" import code (see
  MIPOLAI-COMMON "breeds + portable code"). Your Mipo moves into the house.
- **Mipomi voice**: every reaction gets a squeak or syllable. The material is
  ready in `~/Projects/love/mipomi-lang` (separate repo, NOT in vector-sketch):
  3 voices (`samples-nikki/theo/herman`, about 40 CV syllables each), 16 grunts/hums in
  `samples-fx`, speaker personalities, stutter, pitch curves, a mouth/lipsync
  module, plus `glossary.txt`/`grammar.txt` (the 13×3 CV-root language).
  Start small: one `mipo:squeak(emotion)` that plays a random syllable from that
  Mipo's voice with a pitch shift. Full `mipo:say()` + lipsync comes later.
  Sound is half of what makes Sago feel alive.
- **Puppet theatre**: `recorder.lua` already records and plays back. Record
  30 seconds of play, then play it back as a little show. That fits the King Rollo
  shorts idea and gives kids something to share.
- **Moods that stick**: a Mipo that was thrown a lot gets grumpy for a bit, and
  one that was fed is happy. Very light state, but it gives the world memory.
- **Bathhouse becomes a room**: the wash mechanic ends up as one room in the
  doll world instead of its own app.

## Guardrails

- One menu item in progress at a time. Finish it, see it in the play scene, tick it.
- Art comes last. Use greybox props until the feel is right.
- Watch for "and also": a new idea goes into *Other ideas*, not into the item in progress.
