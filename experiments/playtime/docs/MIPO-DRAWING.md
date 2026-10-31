# Drawing Mipos — what it costs and how to make it cheaper

status: parked — measured on the iPhone SE 2 2026-10-31 (MEASURING M10): ~20 Mipos a room is comfortable without L2; on the phone L2 (atlas, merged meshes, even laid in C) saves ~nothing: our per-part Lua is ~80% of the draw

How a Mipo is drawn now, from the crowd measurements of 2026-10-30 (MEASURING.md: 20 to 200 Mipos,
Apple M1) and a read of `physics/box2d-draw-textured.lua` and `src/render/`.

## How a Mipo is drawn now

About **30 drawables and 30 draw calls per Mipo, ~0.6 ms of drawing each** (all of it rebuilt every frame):

| part | per Mipo | how | ms per Mipo |
|---|---|---|---|
| texfixtures (torso bands, head, ears, hands, feet, bodyhair) | ~10 | an OMP picture on a fan mesh (`drawSquishableHairOver`); spine torsos and ears a bent grid (`spineSkin.drawGrid`) | 0.13 |
| ribbons (arm and leg skin and hair, neck) | 8 | a Bezier through the joint anchors, the strip mesh rewritten (`texturedCurve`) | 0.11 |
| decals (eyes, pupils, nose) | ~5 | `love.graphics.draw(img)` | 0.013 |
| brows | 2 | a Bezier strip each | 0.03 |
| mouth | 3-4 | backdrop and teeth through a **stencil**, two lip strips | 0.04 |
| haircut | 1 | trace-vertices mesh, kept until the outline changes | 0.006 |
| the list | — | `createDrawables` builds ~30 small tables per Mipo every frame, then sorts them all | 0.08 |

## What the read turned up

- **Nothing is culled.** Every registered sfixture is drawn, on screen or not: a Mipo out of view
  costs as much as one in it.
- **Texfixture fans are rebuilt every frame though they never change.** Their vertices are fixed in the
  body's frame (the body's position and angle go to `love.graphics.draw`), yet every frame makes a
  scaled copy, ~10 small UV tables (`makeSquishableUVsFromPoints`: 9% of the Lua time at 200 Mipos) and
  re-uploads the mesh (`setVertices`). Fans are pooled per picture and vertex count, which is why they
  get rewritten.
- **Ribbons are recomputed every frame** even when their anchors haven't moved. The lips already skip
  that (`stripHolds`); ribbons and brows don't. Idle Mipos only breathe every 3-4.5 s, and when paused
  or asleep nothing moves at all.
- **The draw list is rebuilt and sorted every frame** (`createDrawables` is the biggest Lua cost: 32% of
  the Lua time with 20 Mipos), though it only changes when something is added, removed or re-layered.
- **Every part has its own texture** (the bake makes one picture per part), so LÖVE can't batch them:
  each is a draw call, and each Mipo is ~30.
- **The mouth uses the stencil** twice (backdrop, teeth): a state change that also breaks batching.
- All this garbage (~0.6 MB a frame at 20 Mipos, 4.8 MB at 200) is what the collector's growing share
  comes from (1.3% -> 5.4% of the time).

## The day in numbers (2026-10-30, evening)

This morning's code (just before L0/L1, 09f2a551) against L0+L1+L1b+L1c (b9671c18), the same machine,
two rounds in swapped order (morning, now, now, morning; the machine got busier in round two):

| | morning | now |
|---|---|---|
| 20 Mipos moving, editor: draw | 11.9 / 13.7 ms | 10.5 / 11.5 ms |
| ... garbage a frame | 613 / 644 KB | 289 / 302 KB |
| 100 Mipos all on screen (play, paused): draw | 56.3 / 67.7 ms | 27.0 / 35.1 ms |
| ... garbage a frame | 2.6 MB | 0.47-0.49 MB |
| 100 Mipos, normal camera: draw | 62.0 / 67.6 ms | 6.1 / 8.5 ms |
| ... update (paused: GC work) | 12.0 / 18.5 ms | 3.9 / 4.6 ms |

Untouched: the update while Mipos move (physics, behaviour): 6-9 ms either way.

## Levels

Each level keeps what you see the same (`claudetools/snapshot.sh` proves it for L0-L2) and is measured
before and after with `claudetools/frame-profile.lua`. Gains are estimates until measured.

- [x] **L0. Cull what's off screen.** Skip a Mipo (or any drawable) whose box is outside the camera.
  *Cost:* small (a box per Mipo, kept as it moves). *Gain:* nothing in the crowd (all on screen); in
  the overworld or a long room most of the draw. *Risk:* low (a margin for hair and ribbons sticking out).
- [x] **L1. Don't redo what didn't change.** Build each texfixture fan once per fixture (rebuild when
  its picture or shape changes); rewrite a ribbon or brow strip only when its anchors moved (like
  `stripHolds`); keep the draw list and its order until a sfixture is added, removed or re-layered;
  reuse tables. Same ~30 draw calls. *Cost:* 1-2 days. *Gain:* most of the Lua side of drawing and
  most of the garbage; maybe a third of the draw time (to measure). *Risk:* low-medium: a stale cache
  shows as a part not following (the snapshots and the editor test catch most).
  **L0 + L1 done 2026-10-30.** Culling: per Mipo, its part bodies' box grown by how far its pictures
  reach (the furthest fixture corner from its body's centre, measured when the list is built, + 200 for
  ribbon and hair width; a Mipo's `scale` doesn't say how big it is: heads stuck out 318 at scale 0.3).
  Kept: the draw list (rebuilt when `registry.sfixtureVersion` moves or an sfixture's fixture, userData,
  subtype, z or the fields it's built from change), a fan per texfixture layer, a strip per ribbon, brow
  and lip (`ribbon.ownStrip`, laid again only when its control points change; ribbon and lip curves are
  read by the drawers now). Pictures and Mipos identical (snapshots); `spec/draw-cache_spec.lua`: a frame
  after moves, z changes, a Mipo added and removed looks like the same frame drawn from scratch, and
  culling changes no pixel (it caught a too-small margin; mutation-tested).
  Measured (crowd, Apple M1): textured draw 8.6 -> 6.7 ms moving, 4.6 ms paused; garbage 610 -> 335 KB a
  frame. 200 Mipos paused, all on screen: 90.6 -> 53.6 ms; the normal camera (~13 visible): 11.4 ms. While
  Mipos move, ribbons cost what they did (their curve changes every frame). Draw calls unchanged (L2).
  Found: outside the textured draw ~33 ms at 200 Mipos in the editor (box2d-draw's outlines of every
  body, not culled) and ~22 ms in play mode; the paused update (26 ms at 200) is untouched by this.
- [x] **L1b. The rest of the draw: scans of the whole world every frame.** Measured 2026-10-30 with 100
  Mipos (frame-profile times every love.draw step now). Play mode, normal camera (most Mipos off screen):
  draw 12.6 ms, of which the Mipo pictures 3.7 ms and three steps that draw almost nothing 9 ms:
  - **body outlines** (`box2d-draw.drawWorld`) 5.4 ms, 490 KB garbage (10 ms in the editor): every body
    fetched and asked for its fixtures each frame, bodies under a picture skipped only after that. Cull
    off-screen bodies (as L0) and keep `coveredBodies` until the world changes.
  - **rebake check** (`makeCombinedImages`, called from love.draw) 2.4 ms, 180 KB: walks every fixture of
    every body to find the few dirty pictures. Walk only the sfixtures, or keep a list of dirty ones.
  - **doors** (`doors.draw` + `drawBehind`) 1.1 ms: the doors looked up every frame. Keep the list until
    the world changes (src/doors.lua: playtime-fc's).
  - editor only: signal wires 0.6 ms (the same kind of scan).
  All on screen (100 Mipos): Mipo pictures 25-26 ms, outlines 6-10 ms, rebake 2.4-2.8, doors 1.2-1.4.
  **Done 2026-10-30:** outlines cull off-screen bodies (centre + how far its fixtures reach, `view.bodyReach`,
  + 100) before asking anything else of them, and `coveredBodies` is kept (until an sfixture comes or goes,
  at most 30 calls); the rebake check walks a kept list of sfixtures (`spec`: every baked picture in every
  scene is on one); doors keep their list (playtime-fc, doors.lua). `src/render/view.lua` holds the screen
  rectangle for both cullers. Measured, 100 Mipos paused: play mode, normal camera 12.6 -> 5.0 ms (outlines
  5.4 -> 0.8, rebake 2.4 -> 1.1, doors 1.1 -> 0.03; garbage 820 -> 123 KB); all on screen 36.4 -> 28.4 ms;
  the editor's outlines 10 -> 0.75 ms. Left: the rebake check still asks each sfixture for its userData
  (1.1 ms); the editor's signal wires (0.9 ms) scan the same way.
- [x] **L1c. Our own per-part Lua.** The sampler (100 Mipos on screen, paused, 2026-10-30): Lua 46% of the
  time, and of that `ribbonPoints` 21% + `doubleControlPoints` 15% (every ribbon's control points worked
  out every frame, then found unchanged), `earBend.bonesOf` 9% (is this an ear: asked every frame for
  every 4-corner picture), the drawers 11%, GC 10%. **Done:** ribbons first compare their raw node
  positions (and nodes, grow length, bendiness) with last frame's and reuse the points; `bonesOf`
  remembers its answer per body (an ear's while its joint lives and its corners are the same);
  `doubleControlPoints` writes by index. A/B in one running process (the machine was busy, so not
  against older numbers): draw 25.3 / 26.6 -> 24.0 / 22.2 ms, texfixtures 6.5 -> 5.5, ribbons 4.1-5.0 ->
  3.5-3.9. Left: each ribbon still asks its joints where they are every frame.
  **The tests didn't draw OMP pictures until now:** they never baked (love.draw does, before drawing), so
  most texfixtures and every ribbon were left out of the pixel checks; baking inside the test's canvas
  left no canvas set. Fixed (bake first, then set the canvas), the mouse pinned (eyes follow it), and
  checked again: scenes identical from before L1 to now with OMP drawn; draw-cache_spec's 9 pass and
  catch the mutations. The Mipo snapshot has no pixels any more: a fresh Mipo's picture differs between
  runs (random ids order equal-z parts, and more), its bodies, fixtures, joints and DNA are compared.
- [ ] **L2a. One texture per Mipo, parts drawn as now.** `claudetools/drawcall-bench` (2026-10-30, Apple M1,
  100 Mipos x 30 parts as 10-vertex fans): 3000 meshes with 3000 textures (as today) 9.3 ms a frame; the
  same 3000 meshes on one texture 4.2 ms; one mesh per Mipo on an atlas 0.5 ms, but with its vertices
  rewritten from Lua every frame 14.0 ms (worse than today: JIT off). So a draw is ~3 us here, about half
  of it the texture switch. An atlas per Mipo, each part keeping its own mesh and transform with its UVs
  pointing into the atlas, takes the switches away without any new per-frame Lua: maybe ~5 of the ~24 ms
  the pictures take with 100 Mipos on screen (the rest is our own per-part Lua). The shaders are no risk:
  no scene turns `plasticine` or `hairs` on (2026-10-30). Run the bench on the iPad before choosing.
  **On the iPhone SE 2 (2026-10-31,** `LOVE_DIR=claudetools/drawcall-bench native/ios/device.sh`):
  a draw is **1.9 us** of CPU, and **the texture switch costs nothing** there (A 5.8 ms = D 5.9 ms
  for 3000 draws); B 1.0 ms, C 14.4 ms; the GPU kept every case at 60 fps. So on the phone L2a
  gains nothing: what a Mipo's ~30 draws cost is their number (~0.06 ms a Mipo, ~1.2 ms for the
  crowd's ~600), not their textures. Fewer draws only pays as one mesh per Mipo whose vertices
  aren't laid in Lua (B: as L3, L4, or laid in C like the ribbons, `native/desound/ribbon.c`).
  (The bench times only the draws: on iOS the frame's first graphics call waits for vsync.)
  **The "laid in C" spike (2026-10-31):** case E, one mesh per Mipo whose vertices C moves to
  its 16 Box2D bodies each frame (`native/desound/place.c`: 16 body reads, 1 C call, 1
  setVertices, 1 draw), against A2, today's draw per part at its body, both with the JIT off.
  Mac M1: E 0.89 ms against A2 8.55 ms for 100 Mipos. **iPhone SE 2: E 5.32 ms against A2
  6.20** (B, the same meshes static, 0.91): on the phone the per-frame upload is what costs
  (~45 of E's 53 us a Mipo), not the draw calls. So L2 saves ~0.01 ms a Mipo there: not worth
  its weeks. What is: a Mipo draws in ~0.3 ms on the phone but its draws, bodies read, are
  ~0.06 ms of it: ~80% is our own Lua per part (drawer, transforms, colours, caches, face).
  Slimming that hot path is the next draw win, no atlas needed.
  **Where the texfixture drawer goes on the phone** (the crowd, play mode, 2026-10-31; timing
  probes in the drawer, not kept: LuaJIT's sampler hangs the game on iOS). 190 texfixtures a
  frame, 2.06 ms: the **38 bent pictures** (spine torsos and ears, `spineSkin.drawGrid`) take
  **1.13 ms, ~30 us each**: 55% of it for 20% of the parts. The 114 plain OMP pictures ~6.5 us
  each (the draw call 1.3, the fan cache check 0.7, the bones lookup 0.8, shader, colour, body
  each 0.1-0.3), the 38 bg/fg pictures ~4.9 us. drawGrid every frame: a 4 x 13 grid bent onto the
  bones with 3 C calls a point (getWorldPoint twice, getLocalPoint: ~156 a picture), 52 vertex
  tables, setVertices of tables. The ribbons' disease: next, read each bone's transform once and
  bend in plain maths, or lay the grid in C into a ByteData (as `native/desound/ribbon.c`):
  ~30 -> ~5 us, ~1 ms a frame back. Face parts riding a spine torso (`spineSkin.transformAt`)
  call deform too; measure them with it.
  **Done the same day, in C** (`native/desound/grid.c`, `spineSkin.useNative`): each bone's
  transform read once, the grid bent and written into a ByteData. Live A/B on the phone: the
  texfixture drawer 1.65 -> 0.98 ms a frame, all textured drawing 4.5 -> 3.85; the crowd now
  draws in 4.7 ms (was 6.0), ~9 of the 16.7 ms a frame used. spec/grid-native_spec.lua: the
  same points as Lua's deform for spines and ears; the spine room pixel-identical.
- [ ] **L2. One texture per Mipo, a few draw calls.**
  (Bench: merged meshes only pay off if their vertices aren't rewritten from Lua each frame, so for
  Mipos standing still (as L3) or with the GPU placing the parts (as L4).) Pack a Mipo's baked part pictures into one atlas at
  bake time, and draw its rigid parts (texfixtures, decals) as one mesh per Mipo, the part vertices
  moved on the CPU each frame; ribbons too if their strips use the atlas. The mouth (stencil) stays
  apart. ~30 -> ~4 draw calls per Mipo. *Cost:* 1-2 weeks. *Gain:* the C/driver side of drawing (the
  89% of the time that is C). *Risk:* medium: atlas seams (bleeding, mipmaps), rebake on every look
  change, per-part tints and the plasticine/hairs shaders (per-part settings would have to become
  vertex data), spine-bent face parts. Z order holds: a Mipo's parts are one z group.
- [ ] **L3. A still Mipo as one picture.** When a Mipo hasn't moved (asleep, paused, between breaths),
  draw its last rendering from a canvas: 1 draw call (+ eyes on top to keep blinking). Redraw when it
  moves or its face changes. *Cost:* ~1 week. *Gain:* large for crowds standing still (an audience),
  none for Mipos in play. *Risk:* canvas memory (~2 MB a Mipo at full size: 200 Mipos 400 MB, so cap it
  or use it only zoomed out), softness when zoomed, getting the "has it changed" check right.
- [ ] **L4. GPU skinning.** Each Mipo one mesh built once per look; a vertex shader moves it with its
  bodies (~20 bone transforms sent each frame), ribbons as skinned strips. 1-3 draw calls and almost no
  Lua per Mipo. *Cost:* weeks to a month: the Mipo renderer rewritten (OMP, ribbons' Bezier bends, mouth,
  plasticine). *Gain:* the most. *Risk:* high; the editor's live tweaks need a rebuild per change; the
  web build (WebGL 1) limits what a shader can take.

**Suggested order:** L0 and L1 (cheap, safe, measurable), then measure on the iPad. L2 only if the
iPad needs it; L3 for audience-type scenes; L4 only if many Mipos at once becomes the game.
