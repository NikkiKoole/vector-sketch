# Drawing Mipos — what it costs and how to make it cheaper

status: parked — L0 and L1 done (2026-10-30); measure on the iPad before L2

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
- [ ] **L1b. The rest of the draw: scans of the whole world every frame.** Measured 2026-10-30 with 100
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
- [ ] **L2. One texture per Mipo, a few draw calls.** Pack a Mipo's baked part pictures into one atlas at
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
