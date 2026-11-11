# Fur from shells — Mipos with fur past their outline

status: active

Nikki (2026-11-11): "another sort of effect, fur, i know we have sort of this material but can we play with it
here too, might get better". The fur material (MATERIALS MT7, 2026-11-06) draws inside the shape only; its
"not yet": tufts past the outline, shell layers, the direction following the body. HAIR-LOCKS (parked,
"we are good with the hair") did hair and a coat as strands with bodies; this is the other way: the parts
themselves furry.

## The spike (2026-11-11, scene `fur`)

On the cutpaper spike's hook (`state.drawableWrap`, CUT-PAPER.md): each Mipo part (texfixtures, feet, the
connected-texture ribbons; not the face: eyes, mouth, brows stay as drawn) is drawn
- once as the **root**: the whole part, darkened ('root dark');
- then as **shells** ('shells', default 10): copies pushed a little further out from the part's centre each
  (scaled about its body, so the fur goes past the outline wherever it is: 'length' in screen px), drooping
  more toward the tips ('droop'), swaying in the wind ('wind'). Each shell keeps only the strands long enough
  to reach it: strands are cells in the picture's own space ('strand gap'), so a strand moves out with its
  shell and grows past the outline; their length random, with clumps of neighbours long together
  ('clumps'); thinner toward the tip ('thickness'), lighter at the tips ('tips light'). Boil re-picks them.
- While wrapping, `state.drawingOutlines` is on so the engine's own material shaders stand back.

First look: hands, feet and torso like plush or terry cloth, a soft fuzzy edge instead of the crisp outline,
the colours and patterns of the drawing kept.

Known: each part drawn 11 times when live (see the cost below); pushed out from the body's centre, so a long part (an arm ribbon) grows more at its ends than its
sides; a part whose picture sits off its body's centre
grows lopsided.

## The cost (2026-11-11; Nikki: "can you measure the cost of fur, say we dont do feet and hands just torso and
head?", then "sounds heavy" to each part drawn 11 times)

Two switches: **torso+head** or all parts, and **baked** or live. Baked: a part's fur drawn once into its
own canvas (the part's own frame, the screen's resolution) and then drawn as one picture a frame; baked
again when the settings or the zoom change, the part turns more than 1.2 rad (0.35 at first: limbs turn all
the time, 94 bakes a second), or every 1/rebake s for wind and boil.

Measured on the Mac (10 Mipos, `src/frame-bench.lua`, 3-5 s each; the frame is vsync's 16.7 ms throughout,
so the CPU's draw time and the draw calls tell the difference; the phone not measured: the iPhone SE was
not on the cable, the iPad Pro is much faster than the SE floor):

| | draw calls | draw ms (CPU, mean / p95) | bakes a second |
|---|---|---|---|
| fur off | 306 | 3.9 / 4.7 | |
| live, torso+head | 478 | 4.7 / 5.8 | |
| live, all parts | 1258 | 8.8 / 11.1 (4 frames over 20 ms) | |
| baked, torso+head | 311 | 2.6 / 3.2 | 0 when still |
| baked, all parts | 307 | 1.9 / 2.4 | 20 |

Baked costs what no fur costs, in draw calls and CPU (a little less: one canvas instead of the part's own
drawing). Its price is memory, a canvas per furry part: estimated ~0.5 MB a part at zoom 1, so torso+head
for 20 Mipos ~20 MB, all parts ~150 MB (too much for the phone). And each bake is a live frame's work for
that part, so many turning parts at once (all parts) can still stutter. Torso+head baked is the cheap one.

Zoomed in, a bake bigger than 1024 px was cut off at the canvas's edge: empty bands where the fur should be
(Nikki, 2026-11-11). Now a part too big for 1024 px is baked at less and drawn stretched; very close up the
strand cells show as a grid.

## The re-bake pop (2026-11-11; Nikki: "when dragging around the mipo sometimes his belly is retextured,
rebaked i suppose", then "looks very nice", and to write it down for the next time we look at fur)

Baked fur snaps when a part is re-baked: dragging a Mipo turns its belly past REBAKE_TURN (1.2 rad), and
the fur is redrawn in one frame with the droop pointing down again. The strands stay (they live in the
picture's own space); what jumps is the droop's direction and the root-to-tip shading with it. A re-bake
for a zoom change pops the same way, smaller. (Nikki spots pops: blend, never switch.) The counter
`state.furSpike.why` says why a part baked (new / turn / zoom / settings / timer); the endless bakes seen
in a test window were the camera still zooming in at the start (0 a second once it settled).

The ways out, the third the recommendation:
1. **No droop**: fur straight out like plush; turning never needs a bake, so never a pop. Loses the hang.
2. **Crossfade**: keep the old bake and fade to the new over ~0.2 s. No pop, but two pictures a part while
   it fades, and turning still bakes.
3. **The fur baked without droop, the droop a live shift**: bake the fur shells as their own layer (no
   droop), draw the part's dark root under it, and every frame shift the fur layer a few px toward the real
   ground. The droop always points down whichever way the part turns, never a bake for a turn; wind is the
   same shift, swaying. One draw more a furry part (root + fur). Unlike the shells' own droop the whole
   layer moves together (the tips don't hang more than the roots); at these lengths likely not seen.
   Zoom still bakes: crossfade it, or bake only once the zoom has settled.
Also open: a part whose picture changes (a re-randomized Mipo, a recolour, clothes) keeps its old bake;
a check for that before fur goes into the engine.

## Steps

- [ ] **FS1. Nikki plays with it**: keep, change or park. Plush, shaggy, or none?
- [ ] **FS3. No re-bake pops**: the fur baked without droop and the droop a live shift (above, way 3), zoom
  bakes crossfaded or after the zoom settles, a bake again when the part's picture changes.
  **Built 2026-11-11** (Nikki: "show me your recommendation"): mode 'shift' (now the default; 'baked' and
  'live' kept to compare). The shells baked without droop or sway as their own layer; the part's dark root
  drawn live under it (one draw); the layer moved every frame toward the real ground ('droop') and side to
  side ('wind'), so a turn never bakes. A zoom past 20% or a slider change bakes, and the new bake fades in
  over 0.25 s from the old one (both drawn while it fades). Zooming continuously bakes once a 20% step.
  **Bake once** (Nikki: "can we just also have a way to bake it at some scale, and then just dont do anything
  anymore? only after changing sliders?"): in shift, 'bake once' bakes at 'at' px per world unit (0.5, the
  scenes' usual zoom) and never again but for a slider (zooming 0.3 -> 1.0 -> 0.4: no bakes). The fur's
  length is then the world's: it zooms with the Mipo. Zoomed in past the bake scale it's drawn stretched.
  Open: the picture-change check.
- [ ] **FS2. If kept**: fur per Mipo in the DNA (a breed's coat), shells pushed along the outline's normal
  instead of from the centre, the cost on the phone, then into the engine (ENGINE-MERGE).
