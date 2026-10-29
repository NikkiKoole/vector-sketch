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

- [x] **F1. Play scene** `scripts/dollhouse.playtime.json` + `.lua` (2026-10-27): ribbon
  floor/walls and 2 Mipos, built in the editor. The default for `./playtime.sh start`.
  No props yet. The Mipos start high and drop to the floor.
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
- [x] **F5. Per-Mipo gaze target** (2026-10-27): `mipoActions.lookAt(mipo, target)` / `stopLooking`.
  Without one: what it points at, else the cursor/finger within 1000, else it looks around
  every 1.5-4s. Pupils read `thing.gazeX/Y` on the face part; the head tilts up to 20 deg
  toward the gaze. Original note: (the "aware" part): right now the pupils follow the
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
- [x] **Mipos collide with each other** (fixed 2026-10-27): the group-index counter
  restarted every session, so a Mipo loaded from a scene and a new one shared
  group -1 and passed through each other. Allocation now skips indices in use,
  and loading repairs duplicates. The same applies to `zGroupOffset` (texture interleaving).
- [ ] **Pick up / carry**: the grab already works. Tune it so a held Mipo hangs
  nicely (a stiffer joint on torso grabs, softer on limbs) and doesn't jitter.
- [ ] **Throw**: on release, keep the velocity but clamp it (and maybe boost it a
  little) so a flick feels good and doesn't fling things off-screen. Hook point:
  `handlePointerReleased` already returns the released bodies.
- [ ] **Gentle drop / land**: a small squash and an "oof" face on a hard landing,
  using the contact callback's impact speed.
- [ ] **Multi-finger**: two kids, two Mipos. The pointer IDs already support it,
  it just needs testing on iPad.

- [x] **Ragdoll stays sane under rough handling** (2026-10-27). Found with the flight
  recorder (`src/flight-recorder.lua`, `claudetools/flight-*.py`): fast circles pulled the
  torso at Box2D's 12000/s cap, tore joints up to 1055 units apart and wound a shoulder
  ~6 turns past its limit. There are three switchable fixes, all kept after play-testing:
  - `mipoJointGuard.unwind`: un-twist joints wound whole turns past their limits.
  - `mipoJointGuard.heal`: torn joints (> 40 apart) snap the limb subtree back.
  - `box2dPointerJoints.maxMipoDragSpeed`: a cap on how fast a grabbed Mipo follows the
    pointer. 3000 at first (grab saturation dropped from 52-72% of frames to 5%), now
    switched off (`false`), since unwind + heal cope and the cap felt laggy.
  - Noticed: physics slowed (30s of steps took 42s) with 3-4 Mipos on screen. Check on iPad.
  - `mipoJointGuard.unstick` (2026-10-28): a part on the wrong side of a wall or floor. A
    hard drag beats a thin wall for a moment and pushes a small end part through; the joint
    then holds it against the far side forever. Seen as something static and solid across
    the limb (parent centre -> joint -> child centre); the smaller side becomes a ghost
    (sensor), is pulled back, solid again once clear. In the dollhouse: 25 cases in one
    session, all while held, all through the thin ribbon walls/floor, mostly ears, then
    hands and lower arms, once a leg and a foot; none visible in play. Logged as
    `[unstick] <part> through <body>, <gap> apart, held|not held`. Not needed yet: a softer
    drag while a held Mipo touches something static (the prevention, if it ever looks jumpy).
  - `mipoActions.knotRescue` (2026-10-29): arm knots, the upper arm straight up, the forearm
    folded and hanging. 5 of 9 dollhouse Mipos had one. An arm flung up ends 2-3 deg past
    vertical over the head (limits give a little) and the hand, five times the forearm's
    mass, holds the shoulder against its limit. Tighter limits and lighter hands barely
    helped (tested). The hang spring was scaled for the upper arm alone. Now a Mipo with an
    arm up for 1.5 s pulls it down with a whole-arm pull until it hangs (max 2.5 s, then a
    2 s rest). The pull must finish (let go halfway, the hand pulls the arm back up), and it
    can't be always on: on arms pinned in a pile it pumped energy in until Mipos flew out of
    the box (and the elbow can't get it: its push-back flings the light upper arm).
    `spec/mipo-arm-knot_spec.lua`: without it 11 of 12 knotted arms stay up, with it 0-2.
  - `mipoJointGuard.untangle` (2026-10-29): two Mipos knotted together after a hard drag
    (the pointer joint forces limbs through each other; a free throw rarely does). A knot
    = a hook: another Mipo's part across a limb's path (parent centre -> joint -> child
    centre, `lib.hooks()`). A Mipo sitting on another has none, so stacks stay. Knotted 2 s,
    neither held: the upper one hops up and away, and the two pass through each other
    (preSolve) until nothing crosses or overlaps (max 4 s), then the pair rests 3 s. What
    didn't work: passing through alone (they stayed deep inside each other, re-hooking), a
    sideways drift (grippy feet, the room's wall). The test knot is a real one saved from
    the dollhouse (9 hooks): `spec/fixtures/tangled-mipos.playtime.json`,
    `spec/mipo-untangle_spec.lua`. Logged `[untangle] a and b`.

- [x] **Design rule: hands never reach the floor** (2026-10-27): arm (upper + forearm + hand reach)
  <= torso (shoulder->hip) + leg (hip->knee->ankle), measured on the built joints
  (`characterManager.armReach` / `limitArmReach`). Both randomizers enforce it: they shorten the
  arms, down to 40%, then shrink the hand. 19 of 30 random Mipos needed it. Editor sliders stay free.

### Awareness and reactions (feels alive)
- [ ] **Head turn** toward the gaze target (a small torque on the head and neck, not only the pupils).
- [ ] **Look at what's moving**: a thrown object or a falling friend steals attention for a moment.
- [ ] **Look at each other** when idle and nearby. Cheap, and very "alive".
- [ ] **Tap reactions**: poke the belly to giggle, poke the head to blink, poke a foot for a ticklish kick.
- [ ] **Picked-up face**: surprised/happy while held, dizzy after a big throw.
- [ ] **Idle loop**: blink, breathe, shift weight, small look-arounds (puppet-maker2 `breathBody` / `eyeBlink`).

- [x] **Actions module** `src/mipo-actions.lua` (2026-10-27): breathe / jump / ragdoll / flip,
  moved out of the Mipo editor so scenes can call them (`mipoActions` in the script env).
- [x] **Dazed after a hard landing** (2026-10-27): impact > `dazeSpeed` (2000) makes the Mipo limp
  for 1-2.5s (harder hits last longer), then it straightens and stands up. A ragdoll switched
  on by hand is never undone.
- [x] **Held limb goes limp** (2026-10-27): holding a hand/foot/limb part makes that whole limb
  slack (`thing.limp`, honoured by keep-angle), and the rest keeps its pose. It recovers on release.
- [x] **Idle relaxing** (2026-10-27): untouched for 1.5s, a Mipo breathes (tiny lift every 3-4.5s)
  and every 45-90s slumps (knees slack 0.5s plus a push, ~30 deg dip), then straightens.
  Not while held, dazed, ragdolled, flipped or jumping.
- [x] **Arms hang on their own side** (2026-10-27): real shoulder/elbow ranges (the DNA ones were
  T-pose relative and only allowed the upper half) plus a soft spring toward hanging.
- [x] **Pointing** (2026-10-27): `mipoActions.pointAt(mipo, target)`, where target is `{x,y}`,
  `'cursor'`, a body or a function, and `stopPointing`. Editor: "point at cursor". The arm on
  the target's side gets KEEP_ANGLE on upper arm + forearm + hand. Aim is ~25 deg off on average
  (heavy hands droop). Lessons: own torques/velocities on the arm flung the Mipo around;
  KEEP_ANGLE (spin only) is the stable way.

### World
- [x] **Toys** `src/props.lua` (2026-10-27): `props.makeBall(x, y, r, {squishy})`,
  `makeSkateboard(x, y, scale)` (deck + 2 wheel joints with suspension), `makeSlide(x, floorY, scale)`
  (static ladder, platform and curved ribbon chute). Greybox. 3 balls, a skateboard and a slide are
  saved in the dollhouse. `props` is in the script env.
- [ ] **More throwables**: block, fruit, hat.
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

Puppetmaker 2's whole sound setup (band, growl, chatter) and the plan to bring the rest in: `PUPPETMAKER-SOUND.md`.

Source repo: `~/Projects/love/mipomi-lang` (GitHub private). It stays the lab where
recording and tuning happen; playtime gets a copy of the engine and the cut samples.

- [x] **V1. Samples in** (2026-10-27): copy the cut syllables to `assets/voices/{nikki,theo,herman}/`
  and the fx to `assets/voices/fx/` (about 1.2 MB). Skip the raw takes (`*-uncut*`,
  root `*.ogg`, `blah4`). Note: mipomi's `main.lua` only ever loads
  `samples-nikki`. The other two voices are recorded but have never been used in code.
- [ ] **V2. `src/mipomi.lua`**: extract the *engine* half of mipomi `main.lua`
  (`parseInput`, per-speaker `sayQueue`, `playSyllable`/`playSFX`,
  pitch curves, personalities, stutter) into a module with no globals and no
  draw/keypress code. A speaker is created per Mipo.
- [x] **V3. `mipo:squeak(emotion)`** (2026-10-27): `src/mipo-voice.lua`. Grab → `pickup`
  (puppet-maker2's growl pool), hard impact → `oof` (threshold measured live),
  `mipoVoice` in the script env.: one syllable or fx with a pitch shift. This is
  the cheap 80%; hook it to poke, pick-up and land reactions.
- [x] **V3b. From puppet-maker2** (2026-10-27), in `src/mipo-voice.lua`:
  - *Mouth flap*: every squeak opens the mouth (random open shape + width) for
    the sound's length via `thing.mouthShapeVec`, then restores it (`flapMouth`).
  - *Rubber plonks*: Mipo-part impacts play `assets/sounds/rubber-plonk1-3.ogg`.
    Harder hits are lower and louder (speed 400 to 4000), and each body pair is deduped for 0.5s.
  - *Winegum kisses*: bodies with the new `SQUISHY` behavior (body editor, then "add
    behavior") kiss on impact.
  - *Hop on grab*: `input-manager.lua` `hopMipo`, a torso impulse scaled by the Mipo's
    total mass (`mipoHopSpeed` 500, about 200 units high).
  - Impact sounds only fire on the first solve of a *new* contact that approaches
    faster than 350, and plonks are capped per Mipo. Tangled Mipos used to plonk nonstop.
    Re-touches are quiet too (2026-10-29): two bodies that touched within 1.5 s only sound
    again at 3000+ (a leg resting on a head jittered off and on, a 'new' contact every half
    second; a still pile went from 1-3 plonks/s to ~0.5; `spec/mipo-crowd-sound_spec.lua`).
  - *Mouths rest closed* (2026-10-29): most Mipos had their mouths open. A click near a
    face (grabbing one by the head too) pulled a random face that stayed until the next
    click; now it lasts 2 s and goes back to the Mipo's own mouth. Randomize picks rest
    mouths from `mouthShapes.restShapes` (closed, M_B_P, mmm, smile, frown; it picked from
    all 15, mostly open speaking shapes). Mouth flaps live on state (a hot reload froze
    them open). `spec/mipo-mouth_spec.lua`.
  - More in `PUPPETMAKER-SOUND.md`: hmpf on editing, mi-po chatter, a voice per Mipo, the
    band's singing, the voice lab.
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

### Sound library (in `assets/sounds/`, see its README for sources)

- In use: rubber plonks + Minipops `tom1/tom2/wood1` mixed as the impact pool.
- Waiting for an interaction: Minipops `bd1-3` (heavy thud on big landings?), `sd1-3`,
  `hihat1-2`; Casio MT70 drums, `hat-clave`/`snare-clave` (switches, buttons?),
  `vibraphone hi/mid/low` (2s tones for a reveal or a happy moment).
- Before shipping: confirm the Minipops source and the Legowelt terms.

### Contraption kit (puzzle-like things built from joints)

Wiring is `src/signals.lua`: triggers send a named signal, receivers listening to that name
act on it. Both are behaviors (`SIGNAL_BUTTON`, `SIGNAL_GATE`, ...), so they save with the
scene and can be added in the editor. Pieces live in `src/props.lua`.

- [x] **Button + gate** (2026-10-27): `makeButton(x, floorY, height, signal)`, a block on a post;
  tapping it plays a Casio clave and sends the signal. `makeGate(baseBody, x, surfaceY, signal)`
  is a bar on a prismatic joint with a motor: closed it stands up, open it sinks into its base.
  Gates are driven to their saved state after a scene load.
- [x] **Slide with starting deck**: 1000-long deck at 3 deg into a smoothstep chute (one ribbon).
  Dollhouse: skateboard parked against the gate, button beside the ladder. Put a Mipo on the
  board and tap the button.
- [x] **Wiring in the editor** (2026-10-27): body editor, then behaviors, then `SIGNAL_BUTTON` /
  `SIGNAL_GATE`. New ones start on signal `signal1`. Their panel has a signal-name field, plus
  "send now" (button) or an open/closed toggle (gate). While paused, wires are drawn from every
  trigger to the receivers on the same signal, with the name halfway; the selected body's wires
  are thicker.
- [x] **Editor-made gates work** (2026-10-27): a gate opens toward world-down along its prismatic axis
  (either way it was drawn), and an 'add joint' prismatic (limits 0..0) gets a range of the
  gate's height.
- [x] **Toy box** (2026-10-27): add shape, then **toys**: ball, skateboard, slide, button, gate. Press to
  spawn at the mouse, drag to place, release. Button and gate start on `signal1`, so a fresh
  pair is wired already.
- [x] **Pressure plate** (2026-10-27): `props.makePlate(x, floorY, signal, mode)`, `SIGNAL_PLATE`. Anything
  that isn't fixed resting on it sends the signal (with a click). Mode 'hold' sends again when it's
  free (gate closes); 'toggle' only on presses. Release is debounced for 15 frames so a bouncing
  ball doesn't chatter; something already on it at load doesn't fire. In the toy box, and the mode
  is switchable in the behavior panel.
- [x] **Snap, cleaned up** (2026-10-27): the snap joint is the single source of truth (`scriptmeta = { type = 'snap', a, b }`).
- [x] **Hands grab** (2026-10-27): Mipo hands are snap points (no fixture; id = the hand part's id). They grab
  holds, snap blocks and other Mipos' hands (holding hands), never their own Mipo. A hand grabs what it
  touches (centres within both reach radii + `handMargin` 30; a fixed 70 was less than a hand's own
  ~110 radius, so solid hands never got close enough) and holds on where it touches.
  `handBreakThreshold` 40000 (a firm pull lets go). Snap points: `snapDistance` 40 (was 140). Snapping only happens
  while a Mipo is held, counted per Mipo, so dragging by the torso lets the hands grab. Pairing is
  nearest first.
- [x] **Climbing wall + snap blocks** (2026-10-27): `props.makeClimbingWall` (sensor board + 28 holds with
  snap points), `props.makeSnapBlock` (snap points on 4 sides). Both are in the toy box.
- [ ] **Hats**: a snap point on the head, and a hat that clicks on.
- [x] **Snap as a trigger**: a socket that sends a signal when something snaps in.
  `SIGNAL_SOCKET` behavior (`signal`, `mode` hold/toggle, `accepts` = label, empty = anything);
  Mipo hands don't count. Toys: `socket` + `key` (`props.makeSocket` / `props.makeKey`).
- [x] **Snap-together cart**: toys `wheel` (snap point at its centre: the snap joint is a free
  axle) + `plank` (2 axle points underneath, 1 at each end to hook carts into a train).
  Crashing never breaks it (snap joints only break while dragged). Carrying by the plank,
  measured on the wheel joints vs the 100k break threshold: held still 19k, slow circles
  52k, hard shaking 128k -> the wheels pop off. spec/snap-cart_spec.lua.
- [ ] Ideas: elevator (prismatic + motor), seesaw / lever / trapdoor (revolute + limits),
  counterweight lift (pulley), swing / rope bridge (rope / distance), breakable glue (weld).

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
