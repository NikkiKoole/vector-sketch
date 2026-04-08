# Texture Deformation Research

Research notes for the Knut mini-game: deforming a single scanned body image via a Box2D physics skeleton.

## The Goal

Take a scanned illustration (torso + limbs as one image, no head), attach a Box2D skeleton to it, and have the image deform naturally as the skeleton moves. The skeleton is built in the playtime editor (bodies + revolute joints), then an image gets mapped onto it.

## Editor Workflow (how it should feel)

1. Build the skeleton in playtime: bodies for torso, upper arm, forearm, thigh, shin, etc., connected by revolute joints
2. Load/assign a scanned image to the skeleton
3. The system auto-generates a grid mesh over the image and computes bone weights per vertex
4. Physics drives the skeleton, the image deforms in real-time

The key insight: **Box2D shape first, then attach image** — not the other way around. The physics rig is the source of truth.

---

## What Already Exists In This Project

### 1. `experiments/deform/` — Working bone skinning math

Multiple iterations (mainA.lua through mainH.lua). Implements:
- Bone class reading position/angle from Box2D bodies
- Bind-pose and inverse-bind-pose matrices (3x3 affine)
- Per-vertex bone weights (up to 3 bones, smoothstep blending)
- Classic skinning formula: `finalPos = sum(weight * boneWorld * boneBindInv * bindPos)`
- Currently draws polylines only — **needs textured mesh rendering**

### 2. `meshusert` subtype in playtime (half-shipped)

Located in `src/physics/box2d-draw-textured.lua` lines ~1306-1430:
- `deformWorldVerts()` does weighted vertex blending from Box2D anchors/joints
- Distance-based influence weights, serialization in `io.lua`
- **Problems:** no UI to set up, UV mapping bugs, deformation in draw loop (slow), OMP textures don't compose with per-vertex deformation

### 3. Connected-texture bezier ribbons

Works well for individual limbs (arms, tail, tentacles) but can't handle a whole-body scan — it's a 1D ribbon, not a 2D mesh.

### 4. `vendor/loveblobs/` — soft body physics (disabled)

Spring-based blob deformation. Wrong tool for skeletal skinning.

---

## Key External References

### RNavega/2DMeshAnimation-Love

- **URL:** https://github.com/RNavega/2DMeshAnimation-Love
- **License:** Unlicense (public domain) — free to copy, modify, use commercially
- **LOVE version:** 11.x compatible

The most relevant reference. Provides **two complete implementations**:

**CPU skinning (`model-cpu.lua`):**
- Uses LuaJIT FFI for fast vertex buffer updates
- Mesh with `"stream"` usage mode, calls `mesh:setVertices(ByteData)` each frame
- Bone weights in flat FFI arrays for speed
- Per frame: compute `frameTransform * inverseBindPose` per bone, then weighted sum per vertex
- Supports frame interpolation and shape keys (morph targets)

**GPU skinning (`model-gpu.lua`):**
- Custom vertex format with `BoneIndices` (vec4) + `BoneWeights` (vec4) attributes
- GLSL vertex shader does all the skinning — mesh is `"static"`, deformation on GPU
- Bone transforms sent as uniform mat4 array (max 16 bones)
- ~10x faster than CPU approach
- No per-vertex CPU work at all

**Blender exporter** included (Python add-on) — exports mesh, bone weights, baked transforms, shape keys to a single `asset.lua` file. We won't use the Blender pipeline but the data format is instructive.

**Key code patterns to borrow:**
- Custom vertex format with bone indices/weights
- The skinning vertex shader
- FFI-based vertex buffer for CPU path
- Shape key support (useful for facial expressions later?)

### DragonBones

- **URL:** https://dragonbones.github.io/en/animation.html
- **License:** Free editor, MIT runtime
- **No official LOVE/Lua runtime** — only through andross (archived, no mesh deform)

DragonBones is a free 2D animation editor with mesh deformation, FFD (free-form deformation), bone constraints, and IK. The editor itself is polished. The problem is the LOVE integration gap — we'd need to write our own runtime or port one.

**Potentially useful for:** authoring bone weights visually if we need a GUI tool for that. But for Knut, auto-computed distance-based weights from Box2D bodies should be sufficient.

---

## Recommended Approach

### Phase 1: Grid mesh + bone skinning experiment

New experiment (e.g. `experiments/deform-textured/`):

1. **Set up Box2D skeleton** — a few bodies connected by revolute joints (simplified Knut: torso, 2 arms, 2 legs)
2. **Load a test image** (scanned illustration)
3. **Subdivide image into grid mesh** — NxM quads (each split into 2 triangles), UV coords mapping to image pixels
4. **Compute bone weights** per vertex — for each grid vertex, find nearby Box2D bodies, assign weights by inverse distance with smoothstep falloff (reuse math from `experiments/deform/`)
5. **GPU skinning** — write the GLSL vertex shader following RNavega's pattern, send bone transforms as uniforms each frame
6. **Render** — draw the deformed textured mesh

Start with CPU skinning for debuggability, then switch to GPU for performance.

### Phase 2: Integrate into playtime editor

The playtime workflow would be:

1. User builds a skeleton (bodies + joints) as they normally do
2. User adds a new sfixture type (e.g. `"skinned-texture"`) to the root body
3. User assigns an image file to it
4. System auto-generates grid mesh covering the image bounds
5. System computes bone weights from the skeleton's bodies/anchors
6. At runtime: read body transforms from Box2D, send to skinning shader, draw deformed mesh

**New sfixture subtype:** `skinned-texture`
```lua
extra = {
    url = "textures/knut/body-scan.png",
    gridW = 20,            -- grid subdivisions
    gridH = 30,
    bones = { bodyId1, bodyId2, ... },  -- which bodies influence the mesh
    -- weights computed automatically, cached
    -- bind pose captured when weights are computed
}
```

**Editor controls needed:**
- Image picker
- Grid resolution sliders
- "Compute weights" button (recomputes from current pose = bind pose)
- Debug overlay: show grid, color-code by dominant bone
- Per-vertex weight painting (stretch goal — auto weights may be good enough)

### Phase 3: Polish

- Seam hiding at joint boundaries (slight overlap or blending)
- Masking: alpha-cut the grid mesh to the character silhouette (don't render grid cells outside the character outline)
- Performance: GPU path for production, CPU path for debug visualization
- Multiple skinned textures per skeleton (front layer, back layer)

---

## Open Questions

1. **Grid resolution vs quality** — how fine does the grid need to be for smooth bending at joints? Probably 1-2 grid cells per joint width minimum. Need to experiment.

2. **Weight computation** — pure inverse-distance, or something smarter? The deform experiment uses smoothstep which gives nice falloff. Could also try heat-map diffusion for more organic weights.

3. **Bind pose** — when the user clicks "compute weights", the current skeleton pose becomes the bind pose. Need to make this clear in the UI (maybe a "set bind pose" button).

4. **Alpha masking** — the scanned image has a character shape on a background. Need to either: (a) use a pre-cut-out PNG with transparency, or (b) add a mask/silhouette step. Pre-cut PNG is simpler.

5. **Head attachment** — head is separate (not part of the body scan). It attaches to a specific body and follows it rigidly (just a texfixture on the head body). Already works.

6. **Multiple layers** — some characters might need front/back layering (e.g. far arm behind torso, near arm in front). Could use z-ordering that already exists in playtime.

---

## Standalone Experiment: `experiments/deform-textured/`

A working prototype was built at `../../deform-textured/` implementing most of the above. Key features:

- **CPU skinning** with both Linear Blend Skinning (LBS) and Dual Quaternion Skinning (DQS) toggle
- **Bodies = bones** — Box2D body rectangles auto-generate bone segments along their long axis
- **Per-endpoint influence radii** (radiusA, radiusM, radiusB) — 3 control points per bone, scroll to adjust
- **Transparent cell culling** — grid cells with no image content are skipped
- **Alpha-aware auto-weights** — bone influence doesn't leak through transparent gaps
- **Adaptive grid density** — more vertices near joints, fewer in flat areas
- **Edit mode** (E) — drag bodies, joint anchors, bone endpoints; W/H/T+scroll to resize/rotate
- **Weight paint mode** (W) — brush-based per-bone weight painting
- **Save/load** (Cmd+S) — Lua table serialization, auto-load on startup
- **Drag-drop** images to swap characters
- **Gravity toggle** (F) for ragdoll testing

### Learnings to bring back to playtime:
- DQS skinning preserves volume at joints much better than LBS
- Per-endpoint radii give much finer control than a single radius per bone
- Alpha-aware weights (checking opaque path between vertex and bone) prevent cross-body bleed
- Adaptive grid near joints is essential for smooth bending on coarse grids
- The "body IS the bone" concept aligns well with playtime's existing anchor/joint system

See also: `docs/KNUT-TOOLKIT-TODO.md` for the Knut character assembly plan.

---

## Other Knut Mini-Game Tech Needs

These are simpler but still need solutions:

### Scene Transitions
- Fade to black, crossfade, wipe, slide
- A transition manager that handles: current scene teardown, transition animation, new scene setup
- Could be a simple state machine: `playing -> transitioning -> playing`

### Parallax Scrolling
- Multiple background layers scrolling at different speeds relative to camera
- LOVE makes this easy: draw each layer with `love.graphics.translate(camX * layerSpeed, camY * layerSpeed)`
- Need: layer definitions (image, scroll factor, y-offset), draw order

### Sound FX
- `love.audio.newSource()` for loading sounds
- Need: a simple sound manager that preloads assets, plays by name, handles overlap/cooldown
- Music: `love.audio.newSource(path, "stream")` for background music
- SFX: `love.audio.newSource(path, "static")` for short effects
