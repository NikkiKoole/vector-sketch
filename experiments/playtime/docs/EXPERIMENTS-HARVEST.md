# Experiments harvest — what's in `experiments/` that Playtime could use

**Written:** 2026-10-29 (playtime-ef). **Status:** survey only, nothing ported.

**Question:** over the years ~70 prototypes piled up in `experiments/`. Which of them
hold things Playtime should take in for world building for Mipos, for gameplay
(rooms and doors, pick a puppet and play, contraptions, toys) and for the ideas around it?

**How it was done:** four read-only agents each took a group (world, gameplay/physics,
characters, sound/tools + the main vector-sketch app) and reported what each experiment does,
how finished it is, and file:line pointers. The key "Playtime doesn't have this" claims were
spot-checked against `src/`. The other line numbers are from the agents: check before porting.

**Not covered here (other docs own them):**
- Grass, ground skins, sky, clouds, terrain, outside scenes: `WORLD-BUILDING.md` (G1–G8, §1d has the finds from this survey).
- `~/Projects/navkit` (simulation: logic, power, water, fire) and `~/Projects/dreamengine`
  (world gen, faces, gestures, particles): surveyed by the grass/world session in `HARVEST-NAVKIT-DREAMENGINE.md`.
- Puppetmaker 2's sound: `PUPPETMAKER-SOUND.md`.

---

## The short version

Playtime has already eaten most of the character work (DNA, OMP, face, blink, gaze, mouth,
breathe, DQS, sound). What the experiments still have that Playtime lacks is mostly **the feel
and flow around the Mipos**: a tween layer, a camera that follows, transitions, a
"pick your Mipo" start, vehicles to ride, playground toys, and events that make toys respond.
Several of those are small and unblock a lot of open items in `DOLL-PLAY.md` and
`WORLDS-AND-DOORS.md`.

**Close at hand:** `timer.lua` (hump), `flux.lua` and `tween.lua` sit in the vector-sketch root
`vendor/` (plus `lib/tween.lua`). Playtime's `package.path` doesn't reach the root, so DOLL-PLAY F3
(tween layer) is: copy one into `playtime/vendor/` and wire it up. No porting.

---

## 1. Do first: small, and they unblock the most

| # | What | From | Effort | Unblocks |
|---|---|---|---|---|
| 1 | **Tween/timer in the script env.** Copy one into `playtime/vendor/` (hump `timer.lua` does tweens *and* `after`/`every`), expose it in `script.lua` baseEnv, update it in the loop. | vector-sketch root `vendor/` | S | DOLL-PLAY F3: head turns, reactions, smooth camera, birth animation, door zoom (W4), all of §2 |
| 2 | **Follow camera.** Free / follow-Mipo modes, look-ahead from rolling-average velocity, clamped to ¼ screen, distance-scaled lerp. `src/camera.lua` is 63 lines and only has `centerCameraOnPosition`. | `physics-testbed/scenes/downhill.lua` `getTargetPositionBeforeMe` ~:1491, lerp ~:1960–2002, mode button :1426 | S–M | wide overworld (WORLDS-AND-DOORS), "pick a puppet and play", vehicles |
| 3 | **Pan by touch.** Edge-pan while dragging something near the screen edge; fling empty space to pan with inertia. | edge-pan `scrolling-world/src/pointer-interactions.lua:250-262`; fling `lib/gesture.lua:83` (vector-sketch root) | S | DOLL-PLAY "Camera and world size": drag to pan, drag empty space |
| 4 | **Screen wipes.** Circle/rect stencil wipes; iris closes on the door, opens on the Mipo. Today `doors.lua` fades to black. | vector-sketch root `lib/screen-transitions.lua:51-153` (also used by puppet-maker and scrolling-world's world→cave door) | S | doors feel like a storybook; also the pick-a-Mipo → play transition |
| 5 | **Playground toys.** Seesaw (revolute ±45°), carousel (kinematic spinner), elastic band, balloon. ~15 lines each, into `props.lua` + toy box, wireable to signals (a plate starts the carousel). | `vehicles-vegetation/main.lua` `makeSeeSaw` :739, `makeCarousell` :671, `makeSnappyElastic` :512, `makeBalloon` :696 | S | DOLL-PLAY contraption ideas (seesaw/lever is already on the idea list) |
| 6 | **Carry through the floor.** Disable contacts between a held body and static ground while dragging. Worth testing against the `mipoJointGuard.unstick` problem: it may prevent the "pushed through a thin wall" cases instead of repairing them. | `puppet-maker2/main.lua:255-330`; `vehicles-vegetation/main.lua:207 contactShouldBeDisabled` | S | DOLL-PLAY handling; possibly retires a guard |

## 2. Play depth: medium, the actual gameplay

**7. Vehicles a Mipo rides** (M–L). `physics-testbed/vehicle-creator.lua` has pedal bike :195,
scooter :312, rollerblades :398, skateboard :444, bus :79, a geared bike :503 (gear joint :576).
`downhill.lua` has mount/dismount (`connectMipoAndVehicle` :904 / `disconnectMipoAndVehicle` :802:
butt to seat, feet to pedals, temporary gravity scale), pedalling as an angular impulse
(`cycleStep` :330), hop, and auto-righting (:1738). `vehicles-vegetation/main.lua:814 makeVehicle`
adds ground sensors for "airborne" and a pedal wheel turning at ⅓ speed.
*Port as:* seat + pedal snap points (Playtime's snap replaced the old `connect` lib), vehicles as
saved prefabs rather than code, pedal/hop as the first "control your Mipo" input. Gives the
overworld a way to travel.

**8. Pick a puppet, and a birth** (M). `puppet-maker/scenes/fiveGuys.lua`: a lineup of 5 on a
ground plane, pixel-precise picking from the part's mask (:83-125), tap → circle wipe into the
editor (:135). `puppet-maker/src/systems/BipedSystem.lua:202 birthGuy`: the body pops in with an
elastic scale and wobble, then head, arms, hands, legs, feet in turn. Pairs with DOLL-PLAY F4
(load *your* Mipo) and puppet-maker2's `dna5.txt` save of all five (`main.lua:172-250`).
Needs #1 and #4. Do the birth as a draw-scale tween, not a physics rescale.

**9. Toys that answer: contact events → signals** (M). `downhill.lua` `beginContact` :1102 detects
wheelies, loopings, turbo pickups and wine-gum pickups; `organicMusic.lua` maps game events to
music clips and tempo; `frameAnimParticle.lua` does one-shot sprite particles ("wheelie!").
*Port as:* signals emitted on contact (`pickup`, `airborne`, `landed`, `flipped`) via
`signals.lua`, scene scripts and `music.lua` react. Cheap add-on: impact sound pitched by speed
and panned by contact normal (`box2d/main.lua:169`); check overlap with `mipo-voice` plonks.

**10. Mipomi phrase engine** (M). `mipomi-lang/main.lua` :421-1000: `parseInput` with inline
`{personality=…}` blocks, per-speaker say queue, pitch curves, stutter, `randomSayableString`.
This is DOLL-PLAY V2/V6 (already planned), listed so it isn't forgotten.

**11. Rooms with a goal, and a front screen** (M). Nothing in Playtime says "you did it".
`mipo-minipops/games/thief-vs-police/entry.lua`: level table with a difficulty ramp (:214),
win/lose checks (:373), timed retry. `mipo-minipops/main.lua`: a hub of cover images with
greyed-out drafts ("add a new game within a day"). The hub fits as the picker for rooms or
mini-games once there are several. Keep the Sago rule in mind: goals are optional, per room.

**12. Idle wandering** (M). `little-computer-people/steer.lua` :14-234: seek, arrive, separate,
wall-avoid; `mainSteer.lua:57` wander. These give *where* a Mipo wants to go and keep them from
bunching up; they don't give legs. Applied as gentle torso forces, or as targets for a future walk.

**13. Rail ride** (M). `achtbaan` (2025, polished, not Box2D): draw a track, flag points as
accelerate / brake / chain-lift / flip, carts follow by arc length (`Track:getPointOnTrack` :214,
`Cart:update` :338). As a kinematic cart a Mipo snaps into: a roller coaster or a little train.

## 3. The look of the world

| What | From | Effort | Note |
|---|---|---|---|
| **Parallax depth layers** | vector-sketch root `lib/camera.lua:31`, used by scrolling-world (depth → per-layer scale, far 0.4 to near 1.0); brady `addLayer` is vendored but unused | M | handed to `WORLD-BUILDING.md` G4 |
| **Hand-drawn outline** for plain polygons: Catmull-Rom, evenly resampled, random width per segment | vector-sketch `lib/border-mesh.lua:124 makeBorderMesh`, `lib/polyline.lua:299-307` | S–M | makes greybox props and ground look drawn without texture work; fits "art comes last" |
| **Soft drop shadows** under props and Mipos | `shadow/main.lua` ~:75 + `polyfun/main.lua:350` (CPU blur, slow); `Gaussian/main.lua` 9-tap blur shader | S–M | cache per shape, blur on GPU |
| **Keyframe blend shapes** for art: lerp 2 poses, or 4–5 for a joystick blend | vector-sketch `lib/render.lua:40-176` | M | flowers that open, doors, breathing props; driven by tweens or signals |
| **Textured soft bodies** + push/rotate/move helpers | `loveblobs2/loveblobs/softbody.lua:192`, `loveblobs2/main.lua:135-297`; Playtime's vendored loveblobs has no texture code | S | jelly toys, pillows, a blob Mipo |
| **Perspective ground plane** | `scrolling-world/src/groundplane.lua:51`, `puppet-maker/scenes/fiveGuys.lua:363` | S | for the lineup (#8) and outside scenes |
| **Sculpt terrain** with marching squares | `tiled-polygons-01/tiled-polygons.lua:126` | M–L | output must become one ChainShape, not a body per tile |
| **Trees from an L-system** | `lsystem-master/l-system.lua` | S | low priority |

## 4. Music toys and polish

- **Paint-a-melody / xylophone toy** (M): melody-paint's grid or singing-tomatoes' bars as a
  DOLL-PLAY toy whose notes the Mipos sing through `mipo-band`, quantized to `music.chordNotes`.
  Only the UI and the toy body are new.
- **Humanize** (S): per-part push/pull and jitter on `scheduleAt` (kick late, hat early). Write-up in
  `melody-paint/TODO.md`, delay code in `jizzjazztoo/lib/jizzjazz-audiothread.lua` :404-514.
- **Drum pattern library** (S): `jizzjazztoo/drum-patterns.lua` (6383 lines, ~750 named 16-step
  patterns) and `260.lua`. Against "songs sound alike" in `MUSIC-IDEAS.md`. These come from published
  pattern books: check the terms before shipping them.
- `jizzjazztoo/wordsmith.lua`: silly song titles for `nowPlaying` (S, charm only).

## 5. Pipeline, memory, tools

- [x] **Bake OMP at half size** (2026-10-29): `shrinkFactor` 2 in `box2d-draw-textured.lua`.
  Measured in `experiments/omp-bench` on the dollhouse Mipos: 4.5 → 1.1 MB per Mipo
  (50 Mipos: 225 → 56 MB baked, plus 31 MB of shared sources), bakes 28 → 17 ms per Mipo,
  no frame-time change on the Mac; only close up the grain is a little softer. Patches stay
  put (`--patch-check`). Still open from the lab: release-on-rebake (small: +7 → +0.6 MB while
  randomizing), r8 sources (the fixed 31 MB), shader compositing, markings.
- **R8 masks** (S–M): `r8/main.lua:247 makeR8Image` stores masks single-channel, ¼ the VRAM, for the
  ~290 OMP textures and the "caches grow" known issue. Has a bug (`a * 255` on a byte, inverted
  alpha): fix before use.
- **Draw only what's on screen, share caches between identical Mipos**: `mipoworld/main.lua:41-46`,
  `addMipos.lua:56`. Relevant once the overworld holds many Mipos.
- **alpha-padder** (S): offline step that bleeds RGB into transparent pixels, kills dark fringes on
  filtered textures. A script for `textures/`, not runtime code.
- **Auto weights + weight painting for MESHUSERT** (M): `deform-textured/main.lua` :551
  `hasOpaquePath` (no weight across transparent gaps), :570 `computeBoneWeights`, :1043 `paintWeights`.
  Fixes skin bleeding between limbs on whole-body textures.
- **Soft-root single-chain bind**: `spine-humanoid-sandbox/spine-mesh.lua:102`, `limb.lua:95` (S).
- **Mipo codes**: `randomDNAPicker` + `MIPO-CODE-IDEA.md` (shareable characters, S–M).
- **Polygon art as physics bodies**: `polyfun` `mergeAdjacentConvexPolygons` :98, `getBox2dAndVectorSketchPair` :210.
  An import path for vector-sketch `.polygons` art, which Playtime doesn't have.
- App-store bits for later: `fastlane-experiments` (screenshot flags), `apperdeflap` (in-app purchase).

---

## 6. Gaps: what your ideas need and no experiment has

- **Moods and needs.** `emotion-html` is only a concept (Sims-style bars, "Soul of the Sims" notes,
  empty `main.js`). DOLL-PLAY's "moods that stick" needs a small design of its own first.
- **Walking.** Mipos can be dragged, thrown and ridden, but nothing makes one walk somewhere on its
  own. Steering (#12) gives the target, not the gait.
- **Water.** `liquid` (grid water, buggy) and `buoyancy` (one force on contact) are dead ends.
  A bathtub or pond needs per-frame buoyancy by submerged area: new work.
- **Room persistence** (W2) and **carrying what's connected** (W3): no experiment did this; the
  plan in `WORLDS-AND-DOORS.md` stands.
- **Plants you push through.** `vehicles-vegetation` `makeGrassThing` :794 (dynamic plant on a
  revolute joint, springs back upright) is the only start, and it's switched off. Handed to the grass session.

## 7. Dead ends (checked, nothing to take)

phys2 (empty), beebot, tricycle-race, mathjoy, herman, pixelperfect, ascii, chatgpt, forumrhythm,
singlecycle (dreamengine supersedes it), love-peeker / video-maker (Peeker is already in
`vendor/peeker.lua`), world-maker and level-ed (taxonomy/checklist only; useful as library
categories), scrolling-world-ecs, handdrawn(-ecs) and rubberhose (CONNECTED_TEXTURE supersedes them),
deform (DQS supersedes it), shader (already the OMP shader), emotion-machine (moved to mipomi-lang),
paletteorganizer, nikki-commander (Playtime has its library tab), add-remove, minimal-example,
blup, eindbaas, revoluteJoint (joint handlers cover it), drawing_renaissance (two trunk PNGs).

**Security:** `discord-experiment/main.lua` has a Discord bot token committed in plain text
(since 29e7c8f9). Reset it in the Discord developer portal; deleting the line doesn't remove it
from git history.

---

## Suggested order

Tween wiring (#1) → follow camera + pan (#2, #3) → wipes (#4) → playground toys (#5) are all
small and each one is visible in the dollhouse. Then pick one bigger thread:
**vehicles** (#7, contraptions and travel) or **pick a puppet** (#8, the start of the game).
Both lean on #1–#4.
