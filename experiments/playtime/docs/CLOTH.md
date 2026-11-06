# Cloth — curtains, flags, sheets

status: active

A spike (2026-11-06): cloth as a grid of points on a verlet step of its own (not Box2D), held by
distance constraints and drawn as one textured `love.graphics.newMesh`. `src/cloth.lua`, scene
`cloth` (`scripts/spikes/cloth.playtime.lua`): a striped curtain on a rail in a doorway, in front
of the Mipos; a flag on a pole hinged at its foot (a motor rights it); a gingham sheet on a
clothesline. Panel in play mode; keys r w t c f d h m (top of the script).

An older cloth sim with a mesh existed somewhere, but it wasn't found in this repo, its history or
`~/Projects` (searched 2026-11-06), so this one is built fresh.

How it works:
- In C (`native/desound/cloth.c`, in the synth's library; `native/desound/build.sh`): one call a
  cloth a frame does every substep, and C writes the mesh's vertices, its triangles after a tear
  and the outline as joined lines. Lua only gathers the Box2D shapes over the cloth and pushes
  the bodies back. Without the library (the web, specs, a desktop that hasn't built it) the same
  in Lua (`cloth.useNative = false` forces it, to compare). Measured on the desktop, a frame:
  curtain (784 points) 11.5 ms in Lua, 0.9 ms in C; sheet 4.6 → 0.26; flag 1.2 → 0.07. Drawing
  the curtain 0.35 → 0.05 ms.
- Constraints: structural (sides), shear (diagonals, `shear`), bend (skip-one, `bend`: felt vs
  silk). Only the sides tear (`tear` × rest length); a cell goes when one of its sides does.
- Small steps: `substeps` a frame with one constraint pass each, not one step with many passes.
  That's stiffer for the same cost and stops fast things passing through ("small steps",
  Macklin & Müller; tip found 2026-11-06).
- Calm (Nikki 2026-11-06: "too jumpy and tense"): `slack` (rest lengths 5% longer than the grid,
  so it hangs loose and folds), `stretch` (the sides give a little: 0.6), `flutter` (the gusts move
  at half speed), 3 substeps, damping 0.97 (more air), softer wind (160, gust 0.4).
- **3D** (Nikki 2026-11-06, after "still feels like sticky tape with weird gravity and glitchy":
  "much better"). The points move in 3D and the cloth is drawn flat, lit by its 3D normals, after
  Müller's Ten Minute Physics #14 ("the secret of cloth simulation": 15 substeps, sides that
  don't stretch, soft bending, no damping). Kept in the screen's plane, a face-on curtain could
  only bunch up flat: that was the sticky tape. The damping (0.97-0.99 a frame) braked its fall:
  the weird gravity. Now damping 0.999, and the air does the calming: `drag` against motion along
  the cloth, `lift` against its face (a sheet falls slowly flat, fast edge-on), and wind pushes
  the face too, which is what makes flags flap. Moving bodies are slabs `bodyDepth` thick in z, so
  a Mipo pushes the curtain forward over itself; the ground is endless in z. Presets 1-4: silk,
  cotton (default), heavy, storm.
- Fluid (Nikki 2026-11-06: "still not too fluid" after the calm try): the calm try's stretchy sides
  (`stretch` 0.6) and 3 substeps made it rubbery: it sprang back along its length like elastic.
  Real cloth hardly stretches, it folds. Presets on keys 1-4 and the panel to feel side by side:
  silk (10 substeps × 2 passes, damping 0.995, almost no bend), cotton (8 × 2, 0.99; the default),
  heavy (stiffer folds, gravity 1.3, slow wind), rubbery (the calm try). Contact friction is per
  1/60 now, the same however many substeps. Cost with cotton, desktop: curtain 1.9 ms a frame,
  sheet 0.7, flag 0.17.
- Settling (Nikki 2026-11-06: "doesn't smoothly recover and get to rest, it feels jumpy").
  Measured with the wind off: the flag (touching nothing) came to rest, the curtain and sheet
  didn't; points jumped up to 34 px a step. All three causes were the contacts, now fixed:
  - a point deep in a shape was put out through its nearest side in one go (sometimes the far
    side): now out at most 3 px a step
  - each contact kept half the point's speed into the surface, so the hem on the floor bounced:
    now the speed into a surface stops, and 30% of the speed along it goes (friction)
  - the cloth pushed bodies with its own weight, the Mipo's balance pushed back, a loop: now it
    only drags against a body's motion through it (`push` is the drag), never pushes
  - a point in several overlapping shapes (a hand over a leg) ping-ponged between them: now the
    pushes from all of them are averaged and applied once
  After: the curtain with a Mipo standing in it settles to ~0.01 px a step; a Mipo thrown through
  it at 900 px/s moves it at most ~6 px a step, and it's calm again in ~1.5 s.
- Pins: `top`, `corners`, `left` (a flag), `ring` (every Nth top point), `rail` (the top row slides
  between the rail's ends: a curtain you push open). `pinBody`: pins ride on a body (the flag pole).
- Collision: points are pushed out of the circles and polygons they're in, with some of the
  surface's motion (friction); the body gets a small push back (`push`). Fixtures are gathered once
  a frame.
- Look: fabrics are made on a canvas (stripes, gingham, dots, velvet, banner) or come from
  `textures/pat` (tiled) or any picture path (stretched once). Folds: where the cloth is bunched
  sideways it's darker (`shade`). The outline is drawn along every edge with a cell on one side
  only, so tears get an outline too.

Steps:
- [ ] C1. Nikki plays with it: curtain, flag, sheet. Keep, change or park?
- [ ] C2. Cost on the phone (`./playtime.sh bench device`): curtain 784 points, sheet 315, flag 104;
      the C path should be in the iPhone build (build-ios.sh has cloth.c, device.sh `-u`-links the CDEF)
- [ ] C3. A Mipo inside a face-on curtain pushes its points sideways into each other, so the mesh
      folds over itself (it reads as shards). Try: no collision for points behind the Mipo's
      middle, only the edge slides over, or a curtain made of strips (a bead curtain) instead
- [ ] C4. Nikki's drawn fabrics (a scan as the picture, an OMP outline + mask)
- [ ] C5. Places: a door's curtain (WORLDS-AND-DOORS), a blanket on a Mipo bed, a cape on a Mipo
